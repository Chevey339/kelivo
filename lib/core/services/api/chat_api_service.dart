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
import 'stream/stream_chunk.dart';
import 'stream/stream_chunk_handler.dart';

import 'chat_api_helpers.dart';
import 'providers/claude_official.dart';
import 'providers/google_gemini.dart';
import 'providers/google_vertex.dart';
import 'providers/openai_chat_completions.dart';
import 'providers/openai/openai_vendor_compat.dart';
import 'providers/openai_images.dart';
import 'providers/openai_responses.dart';
import 'providers/zhipu_layout_parsing.dart';

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
    return (kind == ProviderKind.openai ||
            ProviderConfig.isZenMux(
              id: config.id,
              name: config.name,
              baseUrl: config.baseUrl,
            )) &&
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
      keepRemoteMarkdownText: false,
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
  }) async* {
    final kind = ProviderConfig.classify(
      config.id,
      explicitType: config.providerType,
    );
    final isZenMux = ProviderConfig.isZenMux(
      id: config.id,
      name: config.name,
      baseUrl: config.baseUrl,
    );
    final imageRequestConfig = isZenMux
        ? config.copyWith(
            providerType: ProviderKind.openai,
            baseUrl: ProviderConfig.zenMuxBaseUrlFor(ProviderKind.openai),
          )
        : config;
    final cancelToken = CancelToken();
    final rid = (requestId ?? '').trim();
    if (rid.isNotEmpty) {
      final prev = _activeCancelTokens.remove(rid);
      try {
        prev?.cancel('replaced');
      } catch (_) {}
      _activeCancelTokens[rid] = cancelToken;
    }
    final useOpenAIImagesApi =
        (kind == ProviderKind.openai || isZenMux) &&
        allowImagesApiRouting &&
        shouldUseOpenAIImagesApi(imageRequestConfig, modelId);
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
    final client = _clientFor(config, cancelToken);

    try {
      if (useOpenAIImagesApi) {
        yield* sendOpenAIImagesStream(
          client,
          imageRequestConfig,
          modelId,
          safeMessages,
          userImagePaths: safeUserImagePaths,
          extraHeaders: extraHeaders,
          extraBody: extraBody,
        );
      } else if (useZhipuLayoutParsing) {
        yield* sendZhipuLayoutParsingStream(
          client,
          config,
          modelId,
          safeMessages,
          userImagePaths: safeUserImagePaths,
          extraHeaders: extraHeaders,
        );
      } else if (kind == ProviderKind.openai) {
        if (config.useResponseApi == true) {
          yield* sendOpenAIResponsesStream(
            client,
            config,
            modelId,
            safeMessages,
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
            skipImageParsing: skipImageParsing,
          );
        } else {
          yield* sendOpenAIChatCompletionsStream(
            client,
            config,
            modelId,
            safeMessages,
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
            skipImageParsing: skipImageParsing,
          );
        }
      } else if (kind == ProviderKind.claude) {
        yield* sendClaudeStream(
          client,
          config,
          modelId,
          safeMessages,
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
          skipImageParsing: skipImageParsing,
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
            skipImageParsing: skipImageParsing,
          );
        } else if (isVertex) {
          yield* sendGoogleVertexStream(
            client,
            config,
            modelId,
            safeMessages,
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
            skipImageParsing: skipImageParsing,
          );
        } else {
          yield* sendGoogleGeminiStream(
            client,
            config,
            modelId,
            safeMessages,
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
            skipImageParsing: skipImageParsing,
          );
        }
      }
    } finally {
      client.close();
      if (rid.isNotEmpty) {
        final cur = _activeCancelTokens[rid];
        if (identical(cur, cancelToken)) {
          _activeCancelTokens.remove(rid);
        }
      }
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
  }) async {
    final handler = StreamChunkHandler();
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
    )) {
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
