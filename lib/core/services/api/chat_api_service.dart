import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import '../../providers/settings_provider.dart';
import '../../providers/model_provider.dart';
import '../../models/token_usage.dart';
import '../../../utils/sandbox_path_resolver.dart';
import '../../../utils/app_directories.dart';
import '../../utils/openai_model_compat.dart';
import '../network/dio_http_client.dart';
import 'google_service_account_auth.dart';
import '../../services/api_key_manager.dart';
import 'package:Kelivo/secrets/fallback.dart';
import '../../../utils/markdown_media_sanitizer.dart';
import '../../../utils/unicode_sanitizer.dart';
import 'builtin_tools.dart';
import 'gemini_tool_config.dart';
import '../logging/flutter_logger.dart';
import '../model_override_resolver.dart';
import '../model_override_payload_parser.dart';
import 'provider_request_headers.dart';
import '../../utils/multimodal_input_utils.dart';

part 'chat_api_service_shims.dart';
part 'providers/openai_common.dart';
part 'providers/openai_chat_completions.dart';
part 'providers/openai_responses.dart';
part 'providers/google_common.dart';
part 'providers/google_gemini.dart';
part 'providers/google_vertex.dart';
part 'providers/claude_official.dart';

class ChatApiService {
  static const String _aihubmixAppCode = 'ZKRT3588';
  static final Map<String, CancelToken> _activeCancelTokens =
      <String, CancelToken>{};

  static void cancelRequest(String requestId) {
    final key = requestId.trim();
    if (key.isEmpty) return;
    final token = _activeCancelTokens.remove(key);
    if (token == null) return;
    try {
      if (!token.isCancelled) token.cancel('cancelled');
    } catch (_) {}
  }

  /// Resolve the upstream/vendor model id for a given logical model key.
  /// When per-instance overrides specify `apiModelId`, that value is used for
  /// outbound HTTP requests and vendor-specific heuristics. Otherwise the
  /// logical `modelId` key is treated as the upstream id (backwards compatible).
  static String _apiModelId(ProviderConfig cfg, String modelId) {
    try {
      final ov = _modelOverride(cfg, modelId);
      return resolveApiModelIdOverride(ov, modelId);
    } catch (_) {}
    return modelId;
  }

  static String _apiKeyForRequest(ProviderConfig cfg, String modelId) {
    final orig = _effectiveApiKey(cfg).trim();
    if (orig.isNotEmpty) return orig;
    if ((cfg.id) == 'SiliconFlow') {
      final host = Uri.tryParse(cfg.baseUrl)?.host.toLowerCase() ?? '';
      if (!host.contains('siliconflow')) return orig;
      final m = _apiModelId(cfg, modelId).toLowerCase();
      final allowed = m == 'thudm/glm-4-9b-0414' || m == 'qwen/qwen3-8b';
      final fallback = siliconflowFallbackKey.trim();
      if (allowed && fallback.isNotEmpty) {
        return fallback;
      }
    }
    return orig;
  }

  static String _effectiveApiKey(ProviderConfig cfg) {
    try {
      if (cfg.multiKeyEnabled == true && (cfg.apiKeys?.isNotEmpty == true)) {
        final sel = ApiKeyManager().selectForProvider(cfg);
        if (sel.key != null) return sel.key!.key;
      }
    } catch (_) {}
    return cfg.apiKey;
  }

  // Read built-in tools configured per model (e.g., ['search', 'url_context']).
  // Stored under ProviderConfig.modelOverrides[modelId].builtInTools.
  static Set<String> _builtInTools(ProviderConfig cfg, String modelId) {
    try {
      return BuiltInToolNames.parseFromOverride(cfg.modelOverrides[modelId]);
    } catch (_) {}
    return const <String>{};
  }

  // Helpers to read per-model overrides (headers/body) from ProviderConfig
  static Map<String, dynamic> _modelOverride(
    ProviderConfig cfg,
    String modelId,
  ) {
    return ModelOverridePayloadParser.modelOverride(
      cfg.modelOverrides,
      modelId,
    );
  }

  static Map<String, String> _customHeaders(
    ProviderConfig cfg,
    String modelId,
  ) {
    final ov = _modelOverride(cfg, modelId);
    final out = <String, String>{
      ...providerDefaultHeaders(cfg),
      ...ModelOverridePayloadParser.customHeaders(ov),
    };
    // AIhubmix promo header (opt-in per-provider)
    if (_isAihubmix(cfg) && cfg.aihubmixAppCodeEnabled == true) {
      out.putIfAbsent('APP-Code', () => _aihubmixAppCode);
    }
    return out;
  }

  static dynamic _parseOverrideValue(String v) {
    return ModelOverridePayloadParser.parseOverrideValue(v);
  }

  static Map<String, dynamic> _customBody(ProviderConfig cfg, String modelId) {
    final ov = _modelOverride(cfg, modelId);
    return ModelOverridePayloadParser.customBody(ov);
  }

  static bool _isAihubmix(ProviderConfig cfg) {
    final base = cfg.baseUrl.toLowerCase();
    return base.contains('aihubmix.com');
  }

  // Resolve effective model info by respecting per-model overrides; fallback to inference
  static ModelInfo _effectiveModelInfo(ProviderConfig cfg, String modelId) {
    final upstreamId = _apiModelId(cfg, modelId);
    final base = ModelRegistry.infer(
      ModelInfo(id: upstreamId, displayName: upstreamId),
    );
    final ov = _modelOverride(cfg, modelId);
    if (ov.isEmpty) return base;
    try {
      return ModelOverrideResolver.applyModelOverride(base, ov);
    } catch (e, st) {
      FlutterLogger.log(
        '[ModelOverride] applyModelOverride failed: $e\n$st',
        tag: 'ModelOverride',
      );
      return base;
    }
  }

  static String _mimeFromPath(String path) {
    return inferMediaMimeFromSource(path, fallbackMime: 'image/png');
  }

  static String _mimeFromDataUrl(String dataUrl) {
    try {
      final start = dataUrl.indexOf(':');
      final semi = dataUrl.indexOf(';');
      if (start >= 0 && semi > start) {
        return dataUrl.substring(start + 1, semi);
      }
    } catch (_) {}
    return 'image/png';
  }

  // Simple container for parsed text + image refs
  static Future<bool> _isValidRemoteImageUrl(String url) async {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
        return false;
      }
      final client = http.Client();
      try {
        final resp = await client.head(uri).timeout(const Duration(seconds: 5));
        // Treat standard success / redirect as valid; 4xx/5xx (e.g. 404) as invalid.
        final code = resp.statusCode;
        if (code >= 200 && code < 400) return true;
        // Some servers do not support HEAD and may return 405/501; treat them as indeterminate but valid.
        if (code == 405 || code == 501) return true;
        return false;
      } finally {
        client.close();
      }
    } catch (_) {
      // Network errors / timeouts → treat as invalid so we fall back to plain text.
      return false;
    }
  }

  // Simple container for parsed text + image refs
  static Future<_ParsedTextAndImages> _parseTextAndImages(
    String raw, {
    required bool allowRemoteImages,
    required bool allowLocalImages,
    bool keepRemoteMarkdownText = true,
  }) async {
    if (raw.isEmpty) return const _ParsedTextAndImages('', <_ImageRef>[]);
    final mdImg = RegExp(r'!\[[^\]]*\]\(([^)]+)\)');
    // Match custom inline image markers like: [image:/absolute/path.png]
    // Use a single backslash in a raw string to escape '[' and ']' in regex.
    final customImg = RegExp(r"\[image:(.+?)\]");
    final images = <_ImageRef>[];
    final buf = StringBuffer();
    int i = 0;
    while (i < raw.length) {
      final m1 = mdImg.matchAsPrefix(raw, i);
      final m2 = customImg.matchAsPrefix(raw, i);
      if (m1 != null) {
        final full = raw.substring(m1.start, m1.end);
        final url = (m1.group(1) ?? '').trim();
        if (url.isEmpty) {
          // Empty URL: treat as plain text, do not try to interpret as image.
          buf.write(full);
          i = m1.end;
          continue;
        }
        // Inline base64 / data URLs: always treat as image but keep them out of text.
        if (url.startsWith('data:')) {
          images.add(_ImageRef('data', url));
          i = m1.end;
          continue;
        }
        // Remote http(s) URLs
        if (url.startsWith('http://') || url.startsWith('https://')) {
          if (!allowRemoteImages) {
            // Model does not accept image input (or we intentionally skip http images):
            // keep original markdown so the model can see the template.
            buf.write(full);
            i = m1.end;
            continue;
          }
          final ok = await _isValidRemoteImageUrl(url);
          if (!ok) {
            // Invalid / unreachable image URL (e.g. 404) → keep as plain text.
            buf.write(full);
            i = m1.end;
            continue;
          }
          images.add(_ImageRef('url', url));
          if (keepRemoteMarkdownText) {
            // Keep markdown so the model can see template syntax and URL.
            buf.write(full);
          }
          i = m1.end;
          continue;
        }
        // Local / relative path: only treat as image when the file exists.
        if (!allowLocalImages) {
          buf.write(full);
          i = m1.end;
          continue;
        }
        try {
          final fixed = SandboxPathResolver.fix(url);
          final file = File(fixed);
          if (!file.existsSync()) {
            // Missing local file: do NOT treat as image; keep original markdown.
            buf.write(full);
            i = m1.end;
            continue;
          }
        } catch (_) {
          // Any error probing the file → fall back to plain text.
          buf.write(full);
          i = m1.end;
          continue;
        }
        images.add(_ImageRef('path', url));
        // For real local files we keep previous behavior: only attach as image, omit markdown from text.
        i = m1.end;
        continue;
      }
      if (m2 != null) {
        final p = (m2.group(1) ?? '').trim();
        if (p.isNotEmpty) images.add(_ImageRef('path', p));
        i = m2.end;
        continue;
      }
      buf.write(raw[i]);
      i++;
    }
    return _ParsedTextAndImages(buf.toString().trim(), images);
  }

  static Future<String> _encodeBase64File(
    String path, {
    bool withPrefix = false,
  }) async {
    final fixed = SandboxPathResolver.fix(path);
    final file = File(fixed);
    final bytes = await file.readAsBytes();
    final b64 = base64Encode(bytes);
    if (withPrefix) {
      final mime = _mimeFromPath(fixed);
      return 'data:$mime;base64,$b64';
    }
    return b64;
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

  static Stream<ChatStreamChunk> sendMessageStream({
    required ProviderConfig config,
    required String modelId,
    required List<Map<String, dynamic>> messages,
    List<String>? userImagePaths,
    int? thinkingBudget,
    double? temperature,
    double? topP,
    int? maxTokens,
    List<Map<String, dynamic>>? tools,
    Future<String> Function(String name, Map<String, dynamic> args)? onToolCall,
    Map<String, String>? extraHeaders,
    Map<String, dynamic>? extraBody,
    bool stream = true,
    String? requestId,
  }) async* {
    final kind = ProviderConfig.classify(
      config.id,
      explicitType: config.providerType,
    );
    final cancelToken = CancelToken();
    final rid = (requestId ?? '').trim();
    if (rid.isNotEmpty) {
      final prev = _activeCancelTokens.remove(rid);
      try {
        prev?.cancel('replaced');
      } catch (_) {}
      _activeCancelTokens[rid] = cancelToken;
    }
    final safeMessages = _sanitizeMessages(messages);
    final client = _clientFor(config, cancelToken);

    try {
      if (kind == ProviderKind.openai) {
        if (config.useResponseApi == true) {
          yield* _sendOpenAIResponsesStream(
            client,
            config,
            modelId,
            safeMessages,
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
          );
        } else {
          yield* _sendOpenAIChatCompletionsStream(
            client,
            config,
            modelId,
            safeMessages,
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
          );
        }
      } else if (kind == ProviderKind.claude) {
        yield* _sendClaudeStream(
          client,
          config,
          modelId,
          safeMessages,
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
        );
      } else if (kind == ProviderKind.google) {
        final isVertex = config.vertexAI == true;
        final isVertexClaude =
            isVertex && modelId.toLowerCase().startsWith('claude-');
        if (isVertexClaude) {
          yield* _sendGoogleVertexClaudeStream(
            client: client,
            config: config,
            modelId: modelId,
            messages: safeMessages,
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
          );
        } else if (isVertex) {
          yield* _sendGoogleVertexStream(
            client,
            config,
            modelId,
            safeMessages,
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
          );
        } else {
          yield* _sendGoogleGeminiStream(
            client,
            config,
            modelId,
            safeMessages,
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

  // Non-streaming text generation for utilities like title summarization
  static Future<String> generateText({
    required ProviderConfig config,
    required String modelId,
    required String prompt,
    Map<String, String>? extraHeaders,
    Map<String, dynamic>? extraBody,
    int? thinkingBudget,
  }) async {
    final kind = ProviderConfig.classify(
      config.id,
      explicitType: config.providerType,
    );
    final client = _clientFor(config, CancelToken());
    final upstreamModelId = _apiModelId(config, modelId);
    final safePrompt = UnicodeSanitizer.sanitize(prompt);
    try {
      if (kind == ProviderKind.openai) {
        final url = _openAICompatibleUrl(config);
        Map<String, dynamic> body;
        final effectiveInfo = _effectiveModelInfo(config, modelId);
        final isReasoning = effectiveInfo.abilities.contains(
          ModelAbility.reasoning,
        );
        final effort = _openAIEffortForBudget(thinkingBudget, upstreamModelId);
        final host = Uri.tryParse(config.baseUrl)?.host.toLowerCase() ?? '';
        final modelLower = upstreamModelId.toLowerCase();
        final bool isMimo =
            host.contains('xiaomimimo') ||
            modelLower.startsWith('mimo-') ||
            modelLower.contains('/mimo-');
        if (config.useResponseApi == true) {
          // Inject built-in web_search tool when enabled and supported
          final toolsList = <Map<String, dynamic>>[];
          bool isResponsesWebSearchSupported(String id) {
            if (BuiltInToolsHelper.isOpenAIResponsesBuiltInSearchSupportedModel(
              id,
            )) {
              return true;
            }
            if (BuiltInToolsHelper.isDashScopeProvider(config)) {
              return BuiltInToolsHelper.isDashScopeResponsesBuiltInSearchSupportedModel(
                id,
              );
            }
            return false;
          }

          if (isResponsesWebSearchSupported(upstreamModelId)) {
            final builtIns = _builtInTools(config, modelId);
            if (builtIns.contains(BuiltInToolNames.search)) {
              if (BuiltInToolsHelper.isDashScopeProvider(config)) {
                toolsList.add({'type': 'web_search'});
              } else {
                Map<String, dynamic> ws = const <String, dynamic>{};
                try {
                  final ov = config.modelOverrides[modelId];
                  if (ov is Map && ov['webSearch'] is Map) {
                    ws = (ov['webSearch'] as Map).cast<String, dynamic>();
                  }
                } catch (_) {}
                final usePreview =
                    (ws['preview'] == true) ||
                    ((ws['tool'] ?? '').toString() == 'preview');
                final entry = <String, dynamic>{
                  'type': usePreview ? 'web_search_preview' : 'web_search',
                };
                if (ws['allowed_domains'] is List &&
                    (ws['allowed_domains'] as List).isNotEmpty) {
                  entry['filters'] = {
                    'allowed_domains': List<String>.from(
                      (ws['allowed_domains'] as List).map((e) => e.toString()),
                    ),
                  };
                }
                if (ws['user_location'] is Map) {
                  entry['user_location'] = (ws['user_location'] as Map)
                      .cast<String, dynamic>();
                }
                if (usePreview && ws['search_context_size'] is String) {
                  entry['search_context_size'] = ws['search_context_size'];
                }
                toolsList.add(entry);
              }
            }
          }
          body = {
            'model': upstreamModelId,
            'input': [
              {'role': 'user', 'content': safePrompt},
            ],
            if (toolsList.isNotEmpty)
              'tools': _toResponsesToolsFormat(toolsList),
            if (toolsList.isNotEmpty) 'tool_choice': 'auto',
            if (isReasoning && effort != 'off')
              'reasoning': {
                'summary': 'auto',
                if (effort != 'auto') 'effort': effort,
              },
          };
        } else {
          body = {
            'model': upstreamModelId,
            'messages': [
              {'role': 'user', 'content': safePrompt},
            ],
            'temperature': 0.3,
            if (isReasoning && effort != 'off' && effort != 'auto')
              'reasoning_effort': effort,
          };
        }
        _applyCompatibleBuiltInSearch(
          body,
          config: config,
          modelId: modelId,
          upstreamModelId: upstreamModelId,
        );
        _applyCompatibleResponsesReasoning(
          body,
          config: config,
          modelId: modelId,
          upstreamModelId: upstreamModelId,
          isReasoning: isReasoning,
          thinkingBudget: thinkingBudget,
        );
        final headers = <String, String>{
          'Authorization': 'Bearer ${_apiKeyForRequest(config, modelId)}',
          'Content-Type': 'application/json',
        };
        headers.addAll(_customHeaders(config, modelId));
        if (extraHeaders != null && extraHeaders.isNotEmpty) {
          headers.addAll(extraHeaders);
        }
        final extra = _customBody(config, modelId);
        if (extra.isNotEmpty) body.addAll(extra);
        if (extraBody != null && extraBody.isNotEmpty) {
          (extraBody).forEach((k, v) {
            body[k] = (v is String) ? _parseOverrideValue(v) : v;
          });
        }
        // Vendor-specific reasoning knobs for chat-completions compatible hosts (non-streaming)
        if (config.useResponseApi != true) {
          final off = _isOff(thinkingBudget);
          if (host.contains('open.bigmodel.cn') ||
              host.contains('bigmodel') ||
              isMimo) {
            // Zhipu BigModel / Xiaomi MiMo: thinking: { type: enabled|disabled }
            if (isReasoning) {
              body['thinking'] = {'type': off ? 'disabled' : 'enabled'};
            } else {
              body.remove('thinking');
            }
            body.remove('reasoning_effort');
          }
        }
        // Ensure Responses tools use the flattened schema even if supplied via overrides
        try {
          if (config.useResponseApi == true && body['tools'] is List) {
            final raw = (body['tools'] as List).cast<dynamic>();
            body['tools'] = _toResponsesToolsFormat(
              raw.map((e) => (e as Map).cast<String, dynamic>()).toList(),
            );
          }
        } catch (_) {}
        _sanitizeOpenAIGpt5SamplingParams(
          body,
          upstreamModelId,
          fallbackEffort: effort,
        );
        final resp = await client.post(
          url,
          headers: headers,
          body: jsonEncode(body),
        );
        if (resp.statusCode < 200 || resp.statusCode >= 300) {
          throw HttpException('HTTP ${resp.statusCode}: ${resp.body}');
        }
        final data = jsonDecode(resp.body);
        if (config.useResponseApi == true) {
          // Prefer SDK-style convenience when present
          final ot = data['output_text'];
          if (ot is String && ot.isNotEmpty) return ot;
          // Aggregate text from `output` list of message blocks
          final out = data['output'];
          if (out is List) {
            final buf = StringBuffer();
            for (final item in out) {
              if (item is! Map) continue;
              final content = item['content'];
              if (content is List) {
                for (final c in content) {
                  if (c is Map &&
                      (c['type'] == 'output_text') &&
                      (c['text'] is String)) {
                    buf.write(c['text']);
                  }
                }
              }
            }
            final s = buf.toString();
            if (s.isNotEmpty) return s;
          }
          return '';
        } else {
          final choices = data['choices'] as List?;
          if (choices != null && choices.isNotEmpty) {
            final msg = choices.first['message'];
            return (msg?['content'] ?? '').toString();
          }
          return '';
        }
      } else if (kind == ProviderKind.claude) {
        final base = config.baseUrl.endsWith('/')
            ? config.baseUrl.substring(0, config.baseUrl.length - 1)
            : config.baseUrl;
        final url = Uri.parse('$base/messages');
        final body = <String, dynamic>{
          'model': upstreamModelId,
          'max_tokens': 512,
          'temperature': 0.3,
          'messages': [
            {'role': 'user', 'content': safePrompt},
          ],
        };
        final headers = <String, String>{
          'x-api-key': _apiKeyForRequest(config, modelId),
          'anthropic-version': '2023-06-01',
          'Content-Type': 'application/json',
        };
        headers.addAll(_customHeaders(config, modelId));
        if (extraHeaders != null && extraHeaders.isNotEmpty) {
          headers.addAll(extraHeaders);
        }
        final extra = _customBody(config, modelId);
        if (extra.isNotEmpty) body.addAll(extra);
        if (extraBody != null && extraBody.isNotEmpty) {
          (extraBody).forEach((k, v) {
            body[k] = (v is String) ? _parseOverrideValue(v) : v;
          });
        }
        final resp = await client.post(
          url,
          headers: headers,
          body: jsonEncode(body),
        );
        if (resp.statusCode < 200 || resp.statusCode >= 300) {
          throw HttpException('HTTP ${resp.statusCode}: ${resp.body}');
        }
        final data = jsonDecode(resp.body);
        final content = data['content'] as List?;
        if (content != null && content.isNotEmpty) {
          final text = content.first['text'];
          return (text ?? '').toString();
        }
        return '';
      } else {
        // Google
        // Check for Vertex AI Claude models (prefix "claude-")
        if ((config.vertexAI == true) &&
            modelId.toLowerCase().startsWith('claude-')) {
          // Reuse existing streaming method but buffer the output for non-streaming
          final stream = _sendGoogleVertexClaudeStream(
            client: client,
            config: config,
            modelId: modelId,
            messages: [
              {'role': 'user', 'content': prompt},
            ],
            extraHeaders: extraHeaders,
            extraBody: extraBody,
            thinkingBudget: thinkingBudget,
            stream: false,
          );
          final chunk = await stream.last;
          return chunk.content;
        }

        String url;
        if (config.vertexAI == true &&
            (config.location?.isNotEmpty == true) &&
            (config.projectId?.isNotEmpty == true)) {
          final loc = config.location!;
          final proj = config.projectId!;
          url =
              'https://aiplatform.googleapis.com/v1/projects/$proj/locations/$loc/publishers/google/models/$upstreamModelId:generateContent';
        } else {
          final base = config.baseUrl.endsWith('/')
              ? config.baseUrl.substring(0, config.baseUrl.length - 1)
              : config.baseUrl;
          url = '$base/models/$upstreamModelId:generateContent';
        }
        final body = <String, dynamic>{
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': safePrompt},
              ],
            },
          ],
          'generationConfig': {'temperature': 0.3},
        };

        // Inject Gemini built-in tools (now supported for both official API and Vertex)
        // code_execution is exclusive - cannot be used with other built-in tools
        final builtIns = _builtInTools(config, modelId);
        if (builtIns.isNotEmpty) {
          final toolsArr = <Map<String, dynamic>>[];
          if (builtIns.contains(BuiltInToolNames.codeExecution)) {
            toolsArr.add({'code_execution': {}});
          } else {
            if (builtIns.contains(BuiltInToolNames.search)) {
              toolsArr.add({'google_search': {}});
            }
            if (builtIns.contains(BuiltInToolNames.urlContext)) {
              toolsArr.add({'url_context': {}});
            }
          }
          if (toolsArr.isNotEmpty) {
            body['tools'] = toolsArr;
          }
        }
        final headers = <String, String>{'Content-Type': 'application/json'};
        // Add API Key header for non-Vertex
        if (!(config.vertexAI == true)) {
          final apiKey = _apiKeyForRequest(config, modelId);
          if (apiKey.isNotEmpty) {
            headers['x-goog-api-key'] = apiKey;
          }
        }
        // Add Bearer for Vertex via service account JSON
        if (config.vertexAI == true) {
          final token = await _maybeVertexAccessToken(config);
          if (token != null && token.isNotEmpty) {
            headers['Authorization'] = 'Bearer $token';
          }
          final proj = (config.projectId ?? '').trim();
          if (proj.isNotEmpty) headers['X-Goog-User-Project'] = proj;
        }
        headers.addAll(_customHeaders(config, modelId));
        if (extraHeaders != null && extraHeaders.isNotEmpty) {
          headers.addAll(extraHeaders);
        }
        final extra = _customBody(config, modelId);
        if (extra.isNotEmpty) body.addAll(extra);
        if (extraBody != null && extraBody.isNotEmpty) {
          (extraBody).forEach((k, v) {
            body[k] = (v is String) ? _parseOverrideValue(v) : v;
          });
        }
        final resp = await client.post(
          Uri.parse(url),
          headers: headers,
          body: jsonEncode(body),
        );
        if (resp.statusCode < 200 || resp.statusCode >= 300) {
          throw HttpException('HTTP ${resp.statusCode}: ${resp.body}');
        }
        final data = jsonDecode(resp.body);
        final candidates = data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final parts = candidates.first['content']?['parts'] as List?;
          if (parts != null && parts.isNotEmpty) {
            return (parts.first['text'] ?? '').toString();
          }
        }
        return '';
      }
    } finally {
      client.close();
    }
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

  static bool _isOff(int? budget) =>
      (budget != null && budget != -1 && budget < 1024);
  static String _effortForBudget(int? budget) {
    if (budget == null || budget == -1) return 'auto';
    if (_isOff(budget)) return 'off';
    if (budget <= 2000) return 'low';
    if (budget <= 20000) return 'medium';
    return 'high';
  }

  // Clean JSON Schema for Google Gemini API strict validation
  // Google requires array types to have 'items' field
  static Map<String, dynamic> _cleanSchemaForGemini(
    Map<String, dynamic> schema,
  ) {
    final result = Map<String, dynamic>.from(schema);

    // Recursively fix 'properties' if present
    Map<String, dynamic> props = const <String, dynamic>{};
    if (result['properties'] is Map) {
      props = Map<String, dynamic>.from(result['properties'] as Map);
    } else if ((result['type'] ?? '').toString() == 'object') {
      // Ensure objects always have a properties map for Gemini validation
      props = <String, dynamic>{};
    }
    if (props.isNotEmpty || result['type'] == 'object') {
      props.forEach((key, value) {
        if (value is Map) {
          final propMap = Map<String, dynamic>.from(value);
          // print('[ChatApi/Schema] Property $key: type=${propMap['type']}, hasItems=${propMap.containsKey('items')}');
          // If type is array but items is missing, add a permissive items schema
          if (propMap['type'] == 'array' && !propMap.containsKey('items')) {
            // print('[ChatApi/Schema] Adding items to array property: $key');
            propMap['items'] = {'type': 'string'}; // Default to string array
          }
          // Recursively clean nested objects
          if (propMap['type'] == 'object' &&
              propMap.containsKey('properties')) {
            propMap['properties'] = _cleanSchemaForGemini({
              'properties': propMap['properties'],
            })['properties'];
          }
          props[key] = propMap;
        }
      });

      // Gemini requires every entry in `required` to exist in `properties`
      final req = result['required'];
      if (req is List) {
        for (final r in req) {
          final name = r.toString();
          if (!props.containsKey(name)) {
            props[name] = {
              'type': 'string',
            }; // Fallback to a simple string field
          }
        }
      }
      result['properties'] = props;
    }

    // Handle array items recursively
    if (result['items'] is Map) {
      result['items'] = _cleanSchemaForGemini(
        result['items'] as Map<String, dynamic>,
      );
    }

    return result;
  }
}

class _ImageRef {
  final String kind; // 'data' | 'path' | 'url'
  final String src;
  const _ImageRef(this.kind, this.src);
}

class _ParsedTextAndImages {
  final String text;
  final List<_ImageRef> images;
  const _ParsedTextAndImages(this.text, this.images);
}

class _GeminiSignatureMeta {
  final String cleanedText;
  final String? textKey;
  final dynamic textValue;
  final List<Map<String, dynamic>> images;
  const _GeminiSignatureMeta({
    required this.cleanedText,
    this.textKey,
    this.textValue,
    this.images = const <Map<String, dynamic>>[],
  });

  bool get hasText => (textKey ?? '').isNotEmpty && textValue != null;
  bool get hasImages => images.isNotEmpty;
  bool get hasAny => hasText || hasImages;
}

class ChatStreamChunk {
  final String content;
  // Optional reasoning delta (when model supports reasoning)
  final String? reasoning;
  final bool isDone;
  final int totalTokens;
  final TokenUsage? usage;
  final List<ToolCallInfo>? toolCalls;
  final List<ToolResultInfo>? toolResults;

  ChatStreamChunk({
    required this.content,
    this.reasoning,
    required this.isDone,
    required this.totalTokens,
    this.usage,
    this.toolCalls,
    this.toolResults,
  });
}

class ToolCallInfo {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;
  ToolCallInfo({required this.id, required this.name, required this.arguments});
}

class ToolResultInfo {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;
  final String content;
  ToolResultInfo({
    required this.id,
    required this.name,
    required this.arguments,
    required this.content,
  });
}
