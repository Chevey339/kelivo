import '../auth/provider_oauth_service.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import '../../providers/settings_provider.dart';
import '../../providers/model_provider.dart';
import '../network/provider_http_client.dart';
import '../../../utils/unicode_sanitizer.dart';
import '../../models/model_spec.dart';
import '../../utils/multimodal_input_utils.dart';
import 'generation/text_generation_result.dart';
import 'generation/tool_loop_runner.dart';
import 'stream/stream_chunk.dart';
import 'stream/stream_chunk_handler.dart';

import '../../models/auto_retry_options.dart';
import '../../models/reasoning_request.dart';
import '../model_spec/model_spec_resolver.dart';
import 'chat_api_helpers.dart';
import 'provider_request_headers.dart';
import 'providers/claude_official.dart';
import 'providers/google_gemini.dart';
import 'providers/google_vertex.dart';
import 'providers/openai_chat_completions.dart';
import 'providers/openai_images.dart';
import 'providers/openai_responses.dart';
import 'providers/zhipu_layout_parsing.dart';
import 'retry_policy.dart';
import 'tool_call_cancellation.dart';
import 'stream/retrying_stream.dart';
import 'stream/stream_chunk_emit.dart';

export 'chat_api_helpers.dart' show ToolCallHandler;
export 'generation/text_generation_result.dart';
export 'generation/tool_loop_runner.dart';
export 'stream/stream_chunk_emit.dart';

class ChatApiService {
  static final Map<String, CancelToken> _activeCancelTokens =
      <String, CancelToken>{};

  @visibleForTesting
  static bool shouldAttachVertexMediaAuthForTest(Uri uri) =>
      shouldAttachVertexMediaAuth(uri);

  @visibleForTesting
  static String normalizeClaudeImageMimeForTest(String mime) =>
      normalizeClaudeImageMime(mime);

  static bool supportsOpenAIImagesApiRouting(
    ProviderConfig config,
    String modelId,
  ) {
    final kind = ProviderConfig.classify(
      config.id,
      explicitType: config.providerType,
    );
    return kind == ProviderKind.openai &&
        shouldUseOpenAIImagesApi(config, modelId);
  }

  static void cancelRequest(String requestId) {
    final key = requestId.trim();
    if (key.isEmpty) return;
    final token = _activeCancelTokens.remove(key);
    if (token == null) return;
    try {
      if (!token.isCancelled) token.cancel('cancelled');
    } catch (_) {}
  }

  static Future<String> _stripImageMarkersFromText(String raw) async {
    final parsed = await parseTextAndImages(
      raw,
      allowRemoteImages: false,
      allowLocalImages: false,
      allowDataImages: false,
      // Remote links are plain text to a text-only model; only the
      // payload-carrying data:/local forms are dropped.
      keepRemoteMarkdownText: true,
      keepDisallowedImageText: false,
    );
    return parsed.text;
  }

  static Future<dynamic> _stripImageInputsFromContent(dynamic content) async {
    if (content is String) return _stripImageMarkersFromText(content);
    if (content is List) {
      return _stripImageMarkersFromText(textFromContentParts(content));
    }
    if (content is Map) {
      return _stripImageMarkersFromText(textFromContentParts([content]));
    }
    return content;
  }

  static ModelSpec _stripSpecForRequest({
    required ModelSpec spec,
    required bool keepImages,
  }) {
    if (!keepImages || spec.supportsImageInput) return spec;
    return spec.copyWith(input: [...spec.input, Modality.image]);
  }

  static String _mediaRefMime(InternalMediaRef ref) {
    final explicit = ref.mime?.trim() ?? '';
    if (explicit.isNotEmpty) return explicit;
    return inferMediaMimeFromSource(ref.uri);
  }

  static bool _specAcceptsMime(ModelSpec spec, String mime) {
    if (isImageMime(mime)) return spec.supportsImageInput;
    if (isAudioMime(mime)) return spec.supportsAudioInput;
    if (isVideoMime(mime)) return spec.supportsVideoInput;
    return true;
  }

  static bool _specAcceptsMediaPath(ModelSpec spec, String path) {
    final mime = inferMediaMimeFromSource(path);
    if (mime.isEmpty) return spec.supportsImageInput;
    return _specAcceptsMime(spec, mime);
  }

  static List<String> _filterUserMediaPaths(
    List<String> paths,
    ModelSpec spec,
  ) {
    return [
      for (final path in paths)
        if (_specAcceptsMediaPath(spec, path)) path,
    ];
  }

  /// Drops image / audio / video the [spec] cannot accept. Documents stay.
  @visibleForTesting
  static Future<List<Map<String, dynamic>>> stripUnsupportedMediaFromMessages(
    List<Map<String, dynamic>> messages,
    ModelSpec spec,
  ) async {
    final keepImage = spec.supportsImageInput;
    final keepAudio = spec.supportsAudioInput;
    final keepVideo = spec.supportsVideoInput;
    if (keepImage && keepAudio && keepVideo) return messages;

    final out = <Map<String, dynamic>>[];
    for (final message in messages) {
      final copy = Map<String, dynamic>.from(message);
      if (copy.containsKey(multimodalInternalMediaPathsKey)) {
        final refs = parseInternalMediaRefs(
          copy[multimodalInternalMediaPathsKey],
          includeUnavailable: true,
        );
        final kept = [
          for (final ref in refs)
            if (_specAcceptsMime(spec, _mediaRefMime(ref))) ref,
        ];
        if (kept.isEmpty) {
          copy.remove(multimodalInternalMediaPathsKey);
        } else if (kept.length != refs.length) {
          copy[multimodalInternalMediaPathsKey] = encodeInternalMediaRefs(
            kept,
            includeUnavailable: true,
          );
        }
      }
      if (!keepImage && copy.containsKey('content')) {
        copy['content'] = await _stripImageInputsFromContent(copy['content']);
      }
      out.add(copy);
    }
    return out;
  }

  /// Apply request restrictions after resolving credentials. OAuth resolution
  /// reloads the stored provider, so a caller's filtered copy is not sufficient.
  static ProviderConfig _textOnlyConfig(ProviderConfig config, String modelId) {
    final raw = config.modelOverrides[modelId];
    final override = raw is Map ? raw : const <String, dynamic>{};
    return config.copyWith(
      customBody: const [],
      modelOverrides: {
        modelId: {
          for (final key in [
            'apiModelId',
            'api_model_id',
            'type',
            'headers',
            'abilities',
            'reasoning',
            'sampling',
            'contextWindow',
            'maxOutput',
            'oauthProtocol',
          ])
            if (override.containsKey(key)) key: override[key],
          'builtInTools': <String>[],
          'input': ['text'],
          'output': ['text'],
        },
      },
    );
  }

  static Stream<StreamChunk> sendMessageStream({
    required ProviderConfig config,
    required String modelId,
    required List<Map<String, dynamic>> messages,
    List<String>? userImagePaths,
    ReasoningRequest reasoning = ReasoningRequest.auto,
    double? temperature,
    double? topP,
    int? maxTokens,
    List<Map<String, dynamic>>? tools,
    ToolCallHandler? onToolCall,
    Map<String, String>? extraHeaders,
    Map<String, dynamic>? extraBody,
    bool stream = true,
    String? requestId,
    String? conversationId,
    bool allowImagesApiRouting = true,
    bool ocrActive = false,
    bool builtInSearchOnly = false,
    bool skipImageParsing = false,
    bool parseMarkdownImageLinks = true,
    // Disallow media, tools and body overrides for detached text generation.
    bool textOnly = false,
    AutoRetryOptions? retryOverride,
  }) async* {
    final sessionToken = CancelToken();
    final toolCancellation = ToolCallCancellation(
      isCancelled: () => sessionToken.isCancelled,
      cancelled: _whenCancelled(sessionToken),
    );
    final rid = (requestId ?? '').trim();
    if (rid.isNotEmpty) {
      final prev = _activeCancelTokens.remove(rid);
      try {
        prev?.cancel('replaced');
      } catch (_) {}
      _activeCancelTokens[rid] = sessionToken;
    }
    try {
      config = await Future.any<ProviderConfig>([
        ProviderOAuthService.instance.resolve(config),
        _whenCancelled(sessionToken).then(
          (_) => throw const ProviderOAuthException(
            ProviderOAuthFailure.cancelled,
          ),
        ),
      ]);
      if (sessionToken.isCancelled) return;
      if (textOnly) config = _textOnlyConfig(config, modelId);
      if (config.oauthProvider == OAuthProvider.chatgpt) stream = true;
      if (config.oauthProvider == OAuthProvider.kimi &&
          (config.modelOverrides[modelId] as Map?)?['oauthProtocol'] ==
              'anthropic') {
        config = config.copyWith(providerType: ProviderKind.claude);
      }
      final options = retryOverride ?? AutoRetryConfig.current;
      final sessionHeaders = providerSessionHeaders(
        config,
        conversationId: conversationId,
        extraHeaders: extraHeaders,
      );
      final kind = ProviderConfig.classify(
        config.id,
        explicitType: config.providerType,
      );
      final useOpenAIImagesApi =
          !textOnly &&
          kind == ProviderKind.openai &&
          allowImagesApiRouting &&
          shouldUseOpenAIImagesApi(config, modelId);
      final useZhipuLayoutParsing =
          !textOnly && shouldUseZhipuLayoutParsing(config, modelId);
      final unicodeSafeMessages = _sanitizeMessages(messages);
      final spec = _stripSpecForRequest(
        spec: ModelSpecResolver.instance.spec(config, modelId),
        keepImages:
            !textOnly &&
            (skipImageParsing ||
                ocrActive ||
                useOpenAIImagesApi ||
                useZhipuLayoutParsing),
      );
      final safeMessages = await stripUnsupportedMediaFromMessages(
        unicodeSafeMessages,
        spec,
      );
      final safeUserImagePaths = userImagePaths == null
          ? null
          : _filterUserMediaPaths(userImagePaths, spec);
      final toolHandler = textOnly ? null : onToolCall;

      final imageOutput = ModelSpecResolver.instance
          .spec(config, modelId)
          .output
          .contains(Modality.image);
      final retryNetworkErrors =
          !useOpenAIImagesApi && !useZhipuLayoutParsing && !imageOutput;
      final emitRetryUi = options.enabled && options.maxRetries > 0;
      Stream<StreamChunk> retryRound(Stream<StreamChunk> Function() sendRound) {
        return retryingStream<StreamChunk>(
          options: options,
          isCancelled: () => sessionToken.isCancelled,
          cancelled: _whenCancelled(sessionToken),
          shouldRetry: (error) => shouldRetryError(
            error,
            options,
            retryOnNetworkError: retryNetworkErrors ? null : false,
          ),
          retryEvent: emitRetryUi
              ? (attempt, delay, error) => RetryPending(
                  attempt: attempt + 1,
                  maxRetries: options.maxRetries,
                  delay: delay,
                  errorText: error.toString(),
                  retryAt: DateTime.now().add(delay),
                )
              : null,
          attemptStartEvent: emitRetryUi
              ? () => const RetryAttemptStart()
              : null,
          attempt: (_) => carrySplitSurrogates(sendRound()),
        );
      }

      yield* retryRound(
        () => _sendOnce(
          config: config,
          modelId: modelId,
          messages: safeMessages,
          userImagePaths: safeUserImagePaths,
          reasoning: reasoning,
          temperature: temperature,
          topP: topP,
          maxTokens: maxTokens,
          tools: textOnly ? null : tools,
          onToolCall: toolHandler == null
              ? null
              : (name, args, {toolCallId}) => toolCancellation.run(
                  () => toolHandler(name, args, toolCallId: toolCallId),
                ),
          extraHeaders: sessionHeaders,
          extraBody: textOnly ? null : extraBody,
          conversationId: conversationId,
          stream: stream,
          builtInSearchOnly: builtInSearchOnly,
          skipImageParsing:
              textOnly || skipImageParsing || !parseMarkdownImageLinks,
          kind: kind,
          useOpenAIImagesApi: useOpenAIImagesApi,
          useZhipuLayoutParsing: useZhipuLayoutParsing,
          sessionToken: sessionToken,
          retryRound: retryRound,
        ),
      );
    } finally {
      if (rid.isNotEmpty) {
        final cur = _activeCancelTokens[rid];
        if (identical(cur, sessionToken)) {
          _activeCancelTokens.remove(rid);
        }
      }
    }
  }

  static Future<void> _whenCancelled(CancelToken token) async {
    try {
      await token.whenCancel;
    } catch (_) {}
  }

  static void _bridgeCancel(CancelToken parent, CancelToken child) {
    if (parent.isCancelled) {
      if (!child.isCancelled) {
        try {
          child.cancel('cancelled');
        } catch (_) {}
      }
      return;
    }
    parent.whenCancel.then(
      (_) {
        if (!child.isCancelled) {
          try {
            child.cancel('cancelled');
          } catch (_) {}
        }
      },
      onError: (_) {
        if (!child.isCancelled) {
          try {
            child.cancel('cancelled');
          } catch (_) {}
        }
      },
    );
  }

  static Stream<StreamChunk> _sendOnce({
    required ProviderConfig config,
    String? conversationId,
    required String modelId,
    required List<Map<String, dynamic>> messages,
    List<String>? userImagePaths,
    ReasoningRequest reasoning = ReasoningRequest.auto,
    double? temperature,
    double? topP,
    int? maxTokens,
    List<Map<String, dynamic>>? tools,
    ToolCallHandler? onToolCall,
    Map<String, String>? extraHeaders,
    Map<String, dynamic>? extraBody,
    required bool stream,
    required bool builtInSearchOnly,
    required bool skipImageParsing,
    required ProviderKind kind,
    required bool useOpenAIImagesApi,
    required bool useZhipuLayoutParsing,
    required CancelToken sessionToken,
    required StreamRoundRunner retryRound,
  }) async* {
    if (sessionToken.isCancelled) {
      throw http.ClientException('cancelled');
    }
    final cancelToken = CancelToken();
    _bridgeCancel(sessionToken, cancelToken);
    final client = ProviderOAuthService.instance.authenticatedClient(
      providerHttpClient(config, cancelToken: cancelToken),
      config,
    );
    try {
      if (useZhipuLayoutParsing) {
        yield* sendZhipuLayoutParsingStream(
          client,
          config,
          modelId,
          messages,
          userImagePaths: userImagePaths,
          extraHeaders: extraHeaders,
        );
      } else if (kind == ProviderKind.openai) {
        if (useOpenAIImagesApi) {
          yield* sendOpenAIImagesStream(
            client,
            config,
            modelId,
            messages,
            userImagePaths: userImagePaths,
            extraHeaders: extraHeaders,
            extraBody: extraBody,
          );
        } else if (config.useResponseApi == true) {
          yield* sendOpenAIResponsesStream(
            client,
            config,
            modelId,
            messages,
            conversationId: conversationId,
            userImagePaths: userImagePaths,
            reasoning: reasoning,
            temperature: temperature,
            topP: topP,
            maxTokens: maxTokens,
            tools: tools,
            onToolCall: onToolCall,
            extraHeaders: extraHeaders,
            extraBody: extraBody,
            stream: stream,
            builtInSearchOnly: builtInSearchOnly,
            skipImageParsing: skipImageParsing,
            retryRound: retryRound,
          );
        } else {
          yield* sendOpenAIChatCompletionsStream(
            client,
            config,
            modelId,
            messages,
            conversationId: conversationId,
            userImagePaths: userImagePaths,
            reasoning: reasoning,
            temperature: temperature,
            topP: topP,
            maxTokens: maxTokens,
            tools: tools,
            onToolCall: onToolCall,
            extraHeaders: extraHeaders,
            extraBody: extraBody,
            stream: stream,
            builtInSearchOnly: builtInSearchOnly,
            skipImageParsing: skipImageParsing,
            retryRound: retryRound,
          );
        }
      } else if (kind == ProviderKind.claude) {
        yield* sendClaudeStream(
          client,
          config,
          modelId,
          messages,
          userImagePaths: userImagePaths,
          reasoning: reasoning,
          temperature: temperature,
          topP: topP,
          maxTokens: maxTokens,
          tools: tools,
          onToolCall: onToolCall,
          extraHeaders: extraHeaders,
          extraBody: extraBody,
          stream: stream,
          builtInSearchOnly: builtInSearchOnly,
          skipImageParsing: skipImageParsing,
          retryRound: retryRound,
        );
      } else if (kind == ProviderKind.google) {
        final isVertex = config.vertexAI == true;
        final isVertexClaude =
            isVertex && modelId.toLowerCase().startsWith('claude-');
        if (isVertexClaude) {
          yield* sendGoogleVertexClaudeStream(
            client: client,
            config: config,
            modelId: modelId,
            messages: messages,
            userImagePaths: userImagePaths,
            reasoning: reasoning,
            temperature: temperature,
            topP: topP,
            maxTokens: maxTokens,
            tools: tools,
            onToolCall: onToolCall,
            extraHeaders: extraHeaders,
            extraBody: extraBody,
            stream: stream,
            skipImageParsing: skipImageParsing,
            retryRound: retryRound,
          );
        } else if (isVertex) {
          yield* sendGoogleVertexStream(
            client,
            config,
            modelId,
            messages,
            userImagePaths: userImagePaths,
            reasoning: reasoning,
            temperature: temperature,
            topP: topP,
            maxTokens: maxTokens,
            tools: tools,
            onToolCall: onToolCall,
            extraHeaders: extraHeaders,
            extraBody: extraBody,
            stream: stream,
            skipImageParsing: skipImageParsing,
            retryRound: retryRound,
          );
        } else {
          yield* sendGoogleGeminiStream(
            client,
            config,
            modelId,
            messages,
            userImagePaths: userImagePaths,
            reasoning: reasoning,
            temperature: temperature,
            topP: topP,
            maxTokens: maxTokens,
            tools: tools,
            onToolCall: onToolCall,
            extraHeaders: extraHeaders,
            extraBody: extraBody,
            stream: stream,
            skipImageParsing: skipImageParsing,
            retryRound: retryRound,
          );
        }
      }
    } finally {
      client.close();
    }
  }

  /// Non-stream generation folded through [StreamChunkHandler].
  static Future<TextGenerationResult> generateMessage({
    required ProviderConfig config,
    required String modelId,
    required List<Map<String, dynamic>> messages,
    List<String>? userImagePaths,
    ReasoningRequest reasoning = ReasoningRequest.auto,
    double? temperature,
    double? topP,
    int? maxTokens,
    List<Map<String, dynamic>>? tools,
    ToolCallHandler? onToolCall,
    Map<String, String>? extraHeaders,
    Map<String, dynamic>? extraBody,
    String? requestId,
    String? conversationId,
    bool allowImagesApiRouting = true,
    bool ocrActive = false,
    bool builtInSearchOnly = false,
    bool skipImageParsing = false,
    bool parseMarkdownImageLinks = true,
    bool textOnly = false,
    AutoRetryOptions? retryOverride,
    void Function(RetryPending? pending)? onRetry,
    void Function(Usage update)? onUsage,
  }) async {
    final handler = StreamChunkHandler(
      onRetry: onRetry == null ? null : (pending) => onRetry(pending),
    );
    await for (final chunk in sendMessageStream(
      config: config,
      modelId: modelId,
      messages: messages,
      userImagePaths: userImagePaths,
      reasoning: reasoning,
      temperature: temperature,
      topP: topP,
      maxTokens: maxTokens,
      tools: tools,
      onToolCall: onToolCall,
      extraHeaders: extraHeaders,
      extraBody: extraBody,
      stream: false,
      requestId: requestId,
      conversationId: conversationId,
      allowImagesApiRouting: allowImagesApiRouting,
      ocrActive: ocrActive,
      builtInSearchOnly: builtInSearchOnly,
      skipImageParsing: skipImageParsing,
      parseMarkdownImageLinks: parseMarkdownImageLinks,
      textOnly: textOnly,
      retryOverride: retryOverride,
    )) {
      if (chunk is RetryAttemptStart) {
        onRetry?.call(null);
      }
      handler.handle(chunk);
      if (chunk is Usage) onUsage?.call(chunk);
    }
    return handler.toResult();
  }

  // Non-streaming text generation for utilities like title summarization
  static Future<String> generateText({
    required ProviderConfig config,
    required String modelId,
    required String prompt,
    String? conversationId,
    Map<String, String>? extraHeaders,
    Map<String, dynamic>? extraBody,
    ReasoningRequest reasoning = ReasoningRequest.auto,
    bool skipImageParsing = false,
  }) async {
    final result = await generateMessage(
      config: config,
      modelId: modelId,
      conversationId: conversationId,
      messages: [
        {'role': 'user', 'content': prompt},
      ],
      extraHeaders: extraHeaders,
      extraBody: extraBody,
      reasoning: reasoning,
      // Utility calls only ever want search; never image generation or a
      // code interpreter.
      builtInSearchOnly: true,
      skipImageParsing: skipImageParsing,
      allowImagesApiRouting: !skipImageParsing,
    );
    return result.text;
  }

  static List<Map<String, dynamic>> _sanitizeMessages(
    List<Map<String, dynamic>> messages,
  ) {
    List<Map<String, dynamic>>? out;
    for (int i = 0; i < messages.length; i++) {
      final m = messages[i];
      final content = m['content'];
      if (content is String) {
        final cleaned = UnicodeSanitizer.sanitize(content);
        if (cleaned != content) {
          out ??= <Map<String, dynamic>>[
            for (int j = 0; j < i; j++) Map<String, dynamic>.from(messages[j]),
          ];
          final copy = Map<String, dynamic>.from(m);
          copy['content'] = cleaned;
          out.add(copy);
          continue;
        }
      }
      if (out != null) out.add(Map<String, dynamic>.from(m));
    }
    return out ?? messages;
  }
}
