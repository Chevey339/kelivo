import 'dart:async';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import '../../providers/settings_provider.dart';
import '../../providers/model_provider.dart';
import '../network/dio_http_client.dart';
import '../../../utils/unicode_sanitizer.dart';
import '../logging/context_log_models.dart';
import '../../utils/multimodal_input_utils.dart';
import 'generation/text_generation_result.dart';
import 'generation/tool_loop_runner.dart';
import 'stream/stream_chunk.dart';
import 'stream/stream_chunk_handler.dart';

import '../../models/auto_retry_options.dart';
import 'chat_api_helpers.dart';
import 'providers/claude_official.dart';
import 'providers/google_gemini.dart';
import 'providers/google_vertex.dart';
import 'providers/openai_chat_completions.dart';
import 'providers/openai/openai_vendor_compat.dart';
import 'providers/openai_images.dart';
import 'providers/openai_responses.dart';
import 'providers/zhipu_layout_parsing.dart';
import 'retry_policy.dart';
import 'stream/retrying_stream.dart';

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

  @visibleForTesting
  static bool isLongCatHostForTest(String baseUrl) => isLongCatHost(baseUrl);

  @visibleForTesting
  static bool shouldIncludeStreamingUsageOptionsForTest(String host) =>
      shouldIncludeStreamingUsageOptions(host);

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

  static Future<List<Map<String, dynamic>>> _stripImageInputsFromMessages(
    List<Map<String, dynamic>> messages,
  ) async {
    final out = <Map<String, dynamic>>[];
    for (final message in messages) {
      final copy = Map<String, dynamic>.from(message);
      copy.remove(multimodalInternalMediaPathsKey);
      copy.remove(multimodalInternalRevisionIdKey);
      copy.remove(kelivoContextSegmentsKey);
      if (copy.containsKey('content')) {
        copy['content'] = await _stripImageInputsFromContent(copy['content']);
      }
      out.add(copy);
    }
    return out;
  }

  static bool _supportsImageInput(ProviderConfig config, String modelId) {
    return effectiveModelInfo(config, modelId).input.contains(Modality.image);
  }

  static http.Client _clientFor(ProviderConfig cfg, CancelToken cancelToken) {
    final enabled = cfg.proxyEnabled == true;
    final host = (cfg.proxyHost ?? '').trim();
    final portStr = (cfg.proxyPort ?? '').trim();
    final user = (cfg.proxyUsername ?? '').trim();
    final pass = (cfg.proxyPassword ?? '').trim();
    if (enabled && host.isNotEmpty && portStr.isNotEmpty) {
      final port = int.tryParse(portStr) ?? 8080;
      return DioHttpClient(
        proxy: NetworkProxyConfig(
          enabled: true,
          type: ProviderConfig.resolveProxyType(cfg.proxyType),
          host: host,
          port: port,
          username: user.isEmpty ? null : user,
          password: pass.isEmpty ? null : pass,
        ),
        cancelToken: cancelToken,
      );
    }
    return DioHttpClient(cancelToken: cancelToken);
  }

  static Stream<StreamChunk> sendMessageStream({
    required ProviderConfig config,
    required String modelId,
    required List<Map<String, dynamic>> messages,
    List<String>? userImagePaths,
    int? thinkingBudget,
    double? temperature,
    double? topP,
    int? maxTokens,
    List<Map<String, dynamic>>? tools,
    ToolCallHandler? onToolCall,
    Map<String, String>? extraHeaders,
    Map<String, dynamic>? extraBody,
    bool stream = true,
    String? requestId,
    bool allowImagesApiRouting = true,
    bool ocrActive = false,
    bool builtInSearchOnly = false,
    bool skipImageParsing = false,
    bool parseMarkdownImageLinks = true,
    AutoRetryOptions? retryOverride,
  }) async* {
    final options = retryOverride ?? AutoRetryConfig.current;
    final kind = ProviderConfig.classify(
      config.id,
      explicitType: config.providerType,
    );
    final sessionToken = CancelToken();
    final rid = (requestId ?? '').trim();
    if (rid.isNotEmpty) {
      final prev = _activeCancelTokens.remove(rid);
      try {
        prev?.cancel('replaced');
      } catch (_) {}
      _activeCancelTokens[rid] = sessionToken;
    }
    final useOpenAIImagesApi =
        kind == ProviderKind.openai &&
        allowImagesApiRouting &&
        shouldUseOpenAIImagesApi(config, modelId);
    final useZhipuLayoutParsing = shouldUseZhipuLayoutParsing(config, modelId);
    final unicodeSafeMessages = _sanitizeMessages(messages);
    final stripUnsupportedImageInputs =
        !skipImageParsing &&
        !ocrActive &&
        !useOpenAIImagesApi &&
        !useZhipuLayoutParsing &&
        !_supportsImageInput(config, modelId);
    final safeMessages = stripUnsupportedImageInputs
        ? await _stripImageInputsFromMessages(unicodeSafeMessages)
        : unicodeSafeMessages;
    final safeUserImagePaths = stripUnsupportedImageInputs
        ? const <String>[]
        : userImagePaths;

    final imageOutput = effectiveModelInfo(
      config,
      modelId,
    ).output.contains(Modality.image);
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
        attemptStartEvent: emitRetryUi ? () => const RetryAttemptStart() : null,
        attempt: (_) => sendRound(),
      );
    }

    try {
      yield* retryRound(
        () => _sendOnce(
          config: config,
          modelId: modelId,
          messages: safeMessages,
          userImagePaths: safeUserImagePaths,
          thinkingBudget: thinkingBudget,
          temperature: temperature,
          topP: topP,
          maxTokens: maxTokens,
          tools: tools,
          onToolCall: onToolCall,
          extraHeaders: extraHeaders,
          extraBody: extraBody,
          stream: stream,
          builtInSearchOnly: builtInSearchOnly,
          skipImageParsing: skipImageParsing || !parseMarkdownImageLinks,
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
    required String modelId,
    required List<Map<String, dynamic>> messages,
    List<String>? userImagePaths,
    int? thinkingBudget,
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
    final client = _clientFor(config, cancelToken);
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
            userImagePaths: userImagePaths,
            thinkingBudget: thinkingBudget,
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
            userImagePaths: userImagePaths,
            thinkingBudget: thinkingBudget,
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
          thinkingBudget: thinkingBudget,
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
            thinkingBudget: thinkingBudget,
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
            thinkingBudget: thinkingBudget,
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
            thinkingBudget: thinkingBudget,
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
    int? thinkingBudget,
    double? temperature,
    double? topP,
    int? maxTokens,
    List<Map<String, dynamic>>? tools,
    ToolCallHandler? onToolCall,
    Map<String, String>? extraHeaders,
    Map<String, dynamic>? extraBody,
    String? requestId,
    bool allowImagesApiRouting = true,
    bool ocrActive = false,
    bool builtInSearchOnly = false,
    bool skipImageParsing = false,
    bool parseMarkdownImageLinks = true,
    AutoRetryOptions? retryOverride,
    void Function(RetryPending? pending)? onRetry,
  }) async {
    final handler = StreamChunkHandler(
      onRetry: onRetry == null ? null : (pending) => onRetry(pending),
    );
    await for (final chunk in sendMessageStream(
      config: config,
      modelId: modelId,
      messages: messages,
      userImagePaths: userImagePaths,
      thinkingBudget: thinkingBudget,
      temperature: temperature,
      topP: topP,
      maxTokens: maxTokens,
      tools: tools,
      onToolCall: onToolCall,
      extraHeaders: extraHeaders,
      extraBody: extraBody,
      stream: false,
      requestId: requestId,
      allowImagesApiRouting: allowImagesApiRouting,
      ocrActive: ocrActive,
      builtInSearchOnly: builtInSearchOnly,
      skipImageParsing: skipImageParsing,
      parseMarkdownImageLinks: parseMarkdownImageLinks,
      retryOverride: retryOverride,
    )) {
      if (chunk is RetryAttemptStart) {
        onRetry?.call(null);
      }
      handler.handle(chunk);
    }
    return handler.toResult();
  }

  // Non-streaming text generation for utilities like title summarization
  static Future<String> generateText({
    required ProviderConfig config,
    required String modelId,
    required String prompt,
    Map<String, String>? extraHeaders,
    Map<String, dynamic>? extraBody,
    int? thinkingBudget,
    bool skipImageParsing = false,
  }) async {
    final result = await generateMessage(
      config: config,
      modelId: modelId,
      messages: [
        {'role': 'user', 'content': prompt},
      ],
      extraHeaders: extraHeaders,
      extraBody: extraBody,
      thinkingBudget: thinkingBudget,
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
