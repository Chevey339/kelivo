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
import '../network/dio_http_client.dart';
import 'google_service_account_auth.dart';
import '../../services/api_key_manager.dart';
import 'package:Kelivo/secrets/fallback.dart';
import '../../../utils/markdown_media_sanitizer.dart';
import '../../../utils/unicode_sanitizer.dart';
import 'builtin_tools.dart';

class ChatApiService {
  static const String _aihubmixAppCode = 'ZKRT3588';
  static final Map<String, CancelToken> _activeCancelTokens = <String, CancelToken>{};

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
      final ov = cfg.modelOverrides[modelId];
      if (ov is Map<String, dynamic>) {
        final raw = (ov['apiModelId'] ?? ov['api_model_id'])?.toString().trim();
        if (raw != null && raw.isNotEmpty) return raw;
      }
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
      final ov = cfg.modelOverrides[modelId];
      if (ov is Map<String, dynamic>) {
        final raw = ov['builtInTools'];
        if (raw is List) {
          return BuiltInToolNames.parseAndNormalize(raw);
        }
      }
    } catch (_) {}
    return const <String>{};
  }
  // Helpers to read per-model overrides (headers/body) from ProviderConfig
  static Map<String, dynamic> _modelOverride(ProviderConfig cfg, String modelId) {
    final ov = cfg.modelOverrides[modelId];
    if (ov is Map<String, dynamic>) return ov;
    return const <String, dynamic>{};
  }

  static Map<String, String> _customHeaders(ProviderConfig cfg, String modelId) {
    final ov = _modelOverride(cfg, modelId);
    final list = (ov['headers'] as List?) ?? const <dynamic>[];
    final out = <String, String>{};
    // AIhubmix promo header (opt-in per-provider)
    if (_isAihubmix(cfg) && cfg.aihubmixAppCodeEnabled == true) {
      out.putIfAbsent('APP-Code', () => _aihubmixAppCode);
    }
    for (final e in list) {
      if (e is Map) {
        final name = (e['name'] ?? e['key'] ?? '').toString().trim();
        final value = (e['value'] ?? '').toString();
        if (name.isNotEmpty) out[name] = value;
      }
    }
    return out;
  }

  static dynamic _parseOverrideValue(String v) {
    final s = v.trim();
    if (s.isEmpty) return s;
    if (s == 'true') return true;
    if (s == 'false') return false;
    if (s == 'null') return null;
    final i = int.tryParse(s);
    if (i != null) return i;
    final d = double.tryParse(s);
    if (d != null) return d;
    if ((s.startsWith('{') && s.endsWith('}')) || (s.startsWith('[') && s.endsWith(']'))) {
      try {
        return jsonDecode(s);
      } catch (_) {}
    }
    return v;
  }

  static Map<String, dynamic> _customBody(ProviderConfig cfg, String modelId) {
    final ov = _modelOverride(cfg, modelId);
    final list = (ov['body'] as List?) ?? const <dynamic>[];
    final out = <String, dynamic>{};
    for (final e in list) {
      if (e is Map) {
        final key = (e['key'] ?? e['name'] ?? '').toString().trim();
        final val = (e['value'] ?? '').toString();
        if (key.isNotEmpty) out[key] = _parseOverrideValue(val);
      }
    }
    return out;
  }

  static bool _isAihubmix(ProviderConfig cfg) {
    final base = cfg.baseUrl.toLowerCase();
    return base.contains('aihubmix.com');
  }

  // Resolve effective model info by respecting per-model overrides; fallback to inference
  static ModelInfo _effectiveModelInfo(ProviderConfig cfg, String modelId) {
    final upstreamId = _apiModelId(cfg, modelId);
    final base = ModelRegistry.infer(ModelInfo(id: upstreamId, displayName: upstreamId));
    final ov = _modelOverride(cfg, modelId);
    ModelType? type;
    final t = (ov['type'] as String?) ?? '';
    if (t == 'embedding') type = ModelType.embedding; else if (t == 'chat') type = ModelType.chat;
    List<Modality>? input;
    if (ov['input'] is List) {
      input = [for (final e in (ov['input'] as List)) (e.toString() == 'image' ? Modality.image : Modality.text)];
    }
    List<Modality>? output;
    if (ov['output'] is List) {
      output = [for (final e in (ov['output'] as List)) (e.toString() == 'image' ? Modality.image : Modality.text)];
    }
    List<ModelAbility>? abilities;
    if (ov['abilities'] is List) {
      abilities = [for (final e in (ov['abilities'] as List)) (e.toString() == 'reasoning' ? ModelAbility.reasoning : ModelAbility.tool)];
    }
    return base.copyWith(
      type: type ?? base.type,
      input: input ?? base.input,
      output: output ?? base.output,
      abilities: abilities ?? base.abilities,
    );
  }
  static String _mimeFromPath(String path) {
    final lower = path.toLowerCase();
    // Images
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    // Video
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.mpeg') || lower.endsWith('.mpg')) return 'video/mpeg';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.avi')) return 'video/x-msvideo';
    if (lower.endsWith('.mkv')) return 'video/x-matroska';
    if (lower.endsWith('.flv')) return 'video/x-flv';
    if (lower.endsWith('.wmv')) return 'video/x-ms-wmv';
    if (lower.endsWith('.webm')) return 'video/webm';
    if (lower.endsWith('.3gp') || lower.endsWith('.3gpp')) return 'video/3gpp';
    return 'image/png';
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

  static const String _geminiThoughtSigTag = 'gemini_thought_signatures';
  static final RegExp _geminiThoughtSigComment = RegExp(
    r'<!--\s*gemini_thought_signatures:(.*?)-->',
    dotAll: true,
  );

  // YouTube URL regex: watch, shorts, embed, youtu.be (with optional timestamps)
  static final RegExp _youtubeUrlRegex = RegExp(
    r'(https?://(?:www\.)?(?:youtube\.com/(?:watch\?v=|shorts/|embed/)|youtu\.be/)[a-zA-Z0-9_-]+(?:[?&][^\s<>()]*)?)',
    caseSensitive: false,
  );

  static List<String> _extractYouTubeUrls(String text) {
    final out = <String>[];
    final seen = <String>{};
    for (final m in _youtubeUrlRegex.allMatches(text)) {
      var url = (m.group(1) ?? '').trim();
      if (url.isEmpty) continue;
      // Trim common trailing punctuation from markdown/parentheses
      while (url.isNotEmpty && '.,;:!?)"]}'.contains(url[url.length - 1])) {
        url = url.substring(0, url.length - 1);
      }
      if (url.isEmpty) continue;
      if (seen.add(url)) out.add(url);
    }
    return out;
  }

  static _GeminiSignatureMeta _extractGeminiThoughtMeta(String raw) {
    try {
      final m = _geminiThoughtSigComment.firstMatch(raw);
      if (m == null) return _GeminiSignatureMeta(cleanedText: raw);
      final payloadRaw = (m.group(1) ?? '').trim();
      Map<String, dynamic> data = const <String, dynamic>{};
      try {
        data = (jsonDecode(payloadRaw) as Map).cast<String, dynamic>();
      } catch (_) {}
      String? textKey;
      dynamic textVal;
      final text = data['text'];
      if (text is Map) {
        textKey = (text['k'] ?? text['key'])?.toString();
        textVal = text['v'] ?? text['val'];
        if (textKey != null && textKey.trim().isEmpty) {
          textKey = null;
        }
      }
      final images = <Map<String, dynamic>>[];
      final imgList = data['images'];
      if (imgList is List) {
        for (final e in imgList) {
          if (e is! Map) continue;
          final k = (e['k'] ?? e['key'])?.toString() ?? '';
          final v = e['v'] ?? e['val'];
          if (k.isEmpty || v == null) continue;
          images.add({'k': k, 'v': v});
        }
      }
      final cleaned = raw.replaceRange(m.start, m.end, '').trimRight();
      return _GeminiSignatureMeta(cleanedText: cleaned, textKey: textKey, textValue: textVal, images: images);
    } catch (_) {
      return _GeminiSignatureMeta(cleanedText: raw);
    }
  }

  static String _buildGeminiThoughtSigComment({
    String? textKey,
    dynamic textValue,
    List<Map<String, dynamic>> imageSigs = const <Map<String, dynamic>>[],
  }) {
    final imgs = imageSigs.where((e) => (e['k'] ?? '').toString().isNotEmpty && e.containsKey('v')).toList();
    final hasText = (textKey ?? '').isNotEmpty && textValue != null;
    if (!hasText && imgs.isEmpty) return '';
    final payload = <String, dynamic>{};
    if (hasText) payload['text'] = {'k': textKey, 'v': textValue};
    if (imgs.isNotEmpty) payload['images'] = imgs;
    return '\n<!-- $_geminiThoughtSigTag:${jsonEncode(payload)} -->';
  }

  static void _applyGeminiThoughtSignatures(_GeminiSignatureMeta meta, List<Map<String, dynamic>> parts, {bool attachDummyWhenMissing = false}) {
    if (meta.hasAny) {
      if (meta.hasText) {
        for (final part in parts) {
          if (part.containsKey('text')) {
            part[meta.textKey!] = meta.textValue;
            break;
          }
        }
      }
      if (meta.hasImages) {
        int idx = 0;
        for (final part in parts) {
          if (idx >= meta.images.length) break;
          if (part.containsKey('inline_data') || part.containsKey('inlineData')) {
            final sig = meta.images[idx];
            final k = (sig['k'] ?? '').toString();
            final v = sig['v'];
            if (k.isNotEmpty && v != null) {
              part[k] = v;
            }
            idx++;
          }
        }
      }
    } else if (attachDummyWhenMissing) {
      const dummy = 'context_engineering_is_the_way_to_go';
      bool inlineFound = false;
      bool textTagged = false;
      for (final part in parts) {
        final hasText = part.containsKey('text');
        final hasInline = part.containsKey('inline_data') || part.containsKey('inlineData');
        if (hasInline) {
          inlineFound = true;
          part.putIfAbsent('thoughtSignature', () => dummy);
        }
        if (hasText && hasInline && !textTagged) {
          part.putIfAbsent('thoughtSignature', () => dummy);
          textTagged = true;
        }
      }
      if (inlineFound && !textTagged) {
        for (final part in parts) {
          if (part.containsKey('text')) {
            part.putIfAbsent('thoughtSignature', () => dummy);
            break;
          }
        }
      }
    }
  }

  static String _collectThoughtSigCommentFromParts(List<dynamic> parts) {
    String? textKey;
    dynamic textVal;
    final images = <Map<String, dynamic>>[];
    for (final p in parts) {
      if (p is! Map) continue;
      String? sigKey;
      dynamic sigVal;
      if (p.containsKey('thoughtSignature')) {
        sigKey = 'thoughtSignature';
        sigVal = p['thoughtSignature'];
      } else if (p.containsKey('thought_signature')) {
        sigKey = 'thought_signature';
        sigVal = p['thought_signature'];
      }
      final hasText = ((p['text'] ?? '') as String? ?? '').isNotEmpty;
      final hasInline = p['inlineData'] is Map || p['inline_data'] is Map || p['fileData'] is Map || p['file_data'] is Map;
      if (hasText && sigKey != null && textKey == null) {
        textKey = sigKey;
        textVal = sigVal;
      }
      if (hasInline && sigKey != null && sigVal != null) {
        images.add({'k': sigKey, 'v': sigVal});
      }
    }
    return _buildGeminiThoughtSigComment(textKey: textKey, textValue: textVal, imageSigs: images);
  }

  // Simple container for parsed text + image refs
  static Future<bool> _isValidRemoteImageUrl(String url) async {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) return false;
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

  static Future<String> _encodeBase64File(String path, {bool withPrefix = false}) async {
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
    final kind = ProviderConfig.classify(config.id, explicitType: config.providerType);
    final cancelToken = CancelToken();
    final rid = (requestId ?? '').trim();
    if (rid.isNotEmpty) {
      final prev = _activeCancelTokens.remove(rid);
      try { prev?.cancel('replaced'); } catch (_) {}
      _activeCancelTokens[rid] = cancelToken;
    }
    final safeMessages = _sanitizeMessages(messages);
    final client = _clientFor(config, cancelToken);

    try {
      if (kind == ProviderKind.openai) {
        yield* _sendOpenAIStream(
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
        yield* _sendGoogleStream(
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
    final kind = ProviderConfig.classify(config.id, explicitType: config.providerType);
    final client = _clientFor(config, CancelToken());
    final upstreamModelId = _apiModelId(config, modelId);
    final safePrompt = UnicodeSanitizer.sanitize(prompt);
    try {
      if (kind == ProviderKind.openai) {
        final base = config.baseUrl.endsWith('/')
            ? config.baseUrl.substring(0, config.baseUrl.length - 1)
            : config.baseUrl;
        final path = (config.useResponseApi == true) ? '/responses' : (config.chatPath ?? '/chat/completions');
        final url = Uri.parse('$base$path');
        Map<String, dynamic> body;
        final effectiveInfo = _effectiveModelInfo(config, modelId);
        final isReasoning = effectiveInfo.abilities.contains(ModelAbility.reasoning);
        final effort = _effortForBudget(thinkingBudget);
        final host = Uri.tryParse(config.baseUrl)?.host.toLowerCase() ?? '';
        final modelLower = upstreamModelId.toLowerCase();
        final bool isMimo = host.contains('xiaomimimo') || modelLower.startsWith('mimo-') || modelLower.contains('/mimo-');
        if (config.useResponseApi == true) {
          // Inject built-in web_search tool when enabled and supported
          final toolsList = <Map<String, dynamic>>[];
          bool _isResponsesWebSearchSupported(String id) {
            final m = id.toLowerCase();
            if (m.startsWith('gpt-4o')) return true;
            if (m == 'gpt-4.1' || m == 'gpt-4.1-mini') return true;
            if (m.startsWith('o4-mini')) return true;
            if (m == 'o3' || m.startsWith('o3-')) return true;
            if (m.startsWith('gpt-5')) return true;
            return false;
          }
          if (_isResponsesWebSearchSupported(upstreamModelId)) {
            final builtIns = _builtInTools(config, modelId);
            if (builtIns.contains(BuiltInToolNames.search)) {
              Map<String, dynamic> ws = const <String, dynamic>{};
              try {
                final ov = config.modelOverrides[modelId];
                if (ov is Map && ov['webSearch'] is Map) ws = (ov['webSearch'] as Map).cast<String, dynamic>();
              } catch (_) {}
              final usePreview = (ws['preview'] == true) || ((ws['tool'] ?? '').toString() == 'preview');
              final entry = <String, dynamic>{'type': usePreview ? 'web_search_preview' : 'web_search'};
              if (ws['allowed_domains'] is List && (ws['allowed_domains'] as List).isNotEmpty) {
                entry['filters'] = {'allowed_domains': List<String>.from((ws['allowed_domains'] as List).map((e) => e.toString()))};
              }
              if (ws['user_location'] is Map) entry['user_location'] = (ws['user_location'] as Map).cast<String, dynamic>();
              if (usePreview && ws['search_context_size'] is String) entry['search_context_size'] = ws['search_context_size'];
              toolsList.add(entry);
            }
          }
          body = {
            'model': upstreamModelId,
            'input': [
              {'role': 'user', 'content': safePrompt}
            ],
            if (toolsList.isNotEmpty) 'tools': _toResponsesToolsFormat(toolsList),
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
              {'role': 'user', 'content': safePrompt}
            ],
            'temperature': 0.3,
            if (isReasoning && effort != 'off' && effort != 'auto') 'reasoning_effort': effort,
          };
        }
        final headers = <String, String>{
          'Authorization': 'Bearer ${_apiKeyForRequest(config, modelId)}',
          'Content-Type': 'application/json',
        };
        headers.addAll(_customHeaders(config, modelId));
        if (extraHeaders != null && extraHeaders.isNotEmpty) headers.addAll(extraHeaders);
        final extra = _customBody(config, modelId);
        if (extra.isNotEmpty) (body as Map<String, dynamic>).addAll(extra);
        if (extraBody != null && extraBody.isNotEmpty) {
          (extraBody).forEach((k, v) {
            (body as Map<String, dynamic>)[k] = (v is String) ? _parseOverrideValue(v) : v;
          });
        }
        // Vendor-specific reasoning knobs for chat-completions compatible hosts (non-streaming)
        if (config.useResponseApi != true) {
          final off = _isOff(thinkingBudget);
          if (host.contains('open.bigmodel.cn') || host.contains('bigmodel') || isMimo) {
            // Zhipu BigModel / Xiaomi MiMo: thinking: { type: enabled|disabled }
            if (isReasoning) {
              (body as Map<String, dynamic>)['thinking'] = {'type': off ? 'disabled' : 'enabled'};
            } else {
              (body as Map<String, dynamic>).remove('thinking');
            }
            (body as Map<String, dynamic>).remove('reasoning_effort');
          }
        }
        // Ensure Responses tools use the flattened schema even if supplied via overrides
        try {
          if (config.useResponseApi == true && (body as Map<String, dynamic>)['tools'] is List) {
            final raw = ((body as Map<String, dynamic>)['tools'] as List).cast<dynamic>();
            (body as Map<String, dynamic>)['tools'] = _toResponsesToolsFormat(
              raw.map((e) => (e as Map).cast<String, dynamic>()).toList(),
            );
          }
        } catch (_) {}
        final resp = await client.post(url, headers: headers, body: jsonEncode(body));
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
                  if (c is Map && (c['type'] == 'output_text') && (c['text'] is String)) {
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
        final body = {
          'model': upstreamModelId,
          'max_tokens': 512,
          'temperature': 0.3,
          'messages': [
            {'role': 'user', 'content': safePrompt}
          ],
        };
        final headers = <String, String>{
          'x-api-key': _apiKeyForRequest(config, modelId),
          'anthropic-version': '2023-06-01',
          'Content-Type': 'application/json',
        };
        headers.addAll(_customHeaders(config, modelId));
        if (extraHeaders != null && extraHeaders.isNotEmpty) headers.addAll(extraHeaders);
        final extra = _customBody(config, modelId);
        if (extra.isNotEmpty) (body as Map<String, dynamic>).addAll(extra);
        if (extraBody != null && extraBody.isNotEmpty) {
          (extraBody).forEach((k, v) {
            (body as Map<String, dynamic>)[k] = (v is String) ? _parseOverrideValue(v) : v;
          });
        }
        final resp = await client.post(url, headers: headers, body: jsonEncode(body));
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
        String url;
        if (config.vertexAI == true && (config.location?.isNotEmpty == true) && (config.projectId?.isNotEmpty == true)) {
          final loc = config.location!;
          final proj = config.projectId!;
          url = 'https://aiplatform.googleapis.com/v1/projects/$proj/locations/$loc/publishers/google/models/$upstreamModelId:generateContent';
        } else {
          final base = config.baseUrl.endsWith('/')
              ? config.baseUrl.substring(0, config.baseUrl.length - 1)
              : config.baseUrl;
          url = '$base/models/$upstreamModelId:generateContent';
        }
        final body = {
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': safePrompt}
              ]
            }
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
            (body as Map<String, dynamic>)['tools'] = toolsArr;
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
        if (extraHeaders != null && extraHeaders.isNotEmpty) headers.addAll(extraHeaders);
        final extra = _customBody(config, modelId);
        if (extra.isNotEmpty) (body as Map<String, dynamic>).addAll(extra);
        if (extraBody != null && extraBody.isNotEmpty) {
          (extraBody).forEach((k, v) {
            (body as Map<String, dynamic>)[k] = (v is String) ? _parseOverrideValue(v) : v;
          });
        }
        final resp = await client.post(Uri.parse(url), headers: headers, body: jsonEncode(body));
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

  static List<Map<String, dynamic>> _sanitizeMessages(List<Map<String, dynamic>> messages) {
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

  // Build a follow-up transcript for OpenAI-style Chat Completions tool-calls.
  //
  // Important: tool messages must preserve `tool_call_id`, and assistant messages must
  // preserve `tool_calls`, otherwise OpenRouter->Anthropic translation will fail with
  // `tool_result.tool_use_id: Field required` on subsequent tool rounds.
  static Map<String, dynamic> _copyChatCompletionMessage(Map<String, dynamic> m) {
    final role = (m['role'] ?? 'user').toString();
    final out = <String, dynamic>{
      'role': role,
      'content': m.containsKey('content') ? (m['content'] ?? '') : '',
    };

    // Preserve optional name (some providers support it on non-tool roles).
    final name = m['name'];
    if (role != 'tool' && name != null && name.toString().isNotEmpty) {
      out['name'] = name;
    }

    // Preserve assistant tool_calls + vendor reasoning echoes (when present).
    if (role == 'assistant') {
      final toolCalls = m['tool_calls'];
      if (toolCalls is List && toolCalls.isNotEmpty) {
        out['tool_calls'] = toolCalls;
      }
      final functionCall = m['function_call'];
      if (functionCall != null) {
        out['function_call'] = functionCall;
      }
      if (m['reasoning_content'] != null) {
        out['reasoning_content'] = m['reasoning_content'];
      }
      if (m['reasoning_details'] != null) {
        out['reasoning_details'] = m['reasoning_details'];
      }
    }

    // Preserve tool linkage fields.
    if (role == 'tool') {
      final toolCallId = m['tool_call_id'];
      if (toolCallId != null && toolCallId.toString().isNotEmpty) {
        out['tool_call_id'] = toolCallId;
      }
      if (name != null && name.toString().isNotEmpty) {
        out['name'] = name;
      }
    }

    return out;
  }

  static bool _isOff(int? budget) => (budget != null && budget != -1 && budget < 1024);
  static String _effortForBudget(int? budget) {
    if (budget == null || budget == -1) return 'auto';
    if (_isOff(budget)) return 'off';
    if (budget <= 2000) return 'low';
    if (budget <= 20000) return 'medium';
    return 'high';
  }

  // Clean JSON Schema for Google Gemini API strict validation
  // Google requires array types to have 'items' field
  static Map<String, dynamic> _cleanSchemaForGemini(Map<String, dynamic> schema) {
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
          final propMap = Map<String, dynamic>.from(value as Map);
          // print('[ChatApi/Schema] Property $key: type=${propMap['type']}, hasItems=${propMap.containsKey('items')}');
          // If type is array but items is missing, add a permissive items schema
          if (propMap['type'] == 'array' && !propMap.containsKey('items')) {
            // print('[ChatApi/Schema] Adding items to array property: $key');
            propMap['items'] = {'type': 'string'}; // Default to string array
          }
          // Recursively clean nested objects
          if (propMap['type'] == 'object' && propMap.containsKey('properties')) {
            propMap['properties'] = _cleanSchemaForGemini({'properties': propMap['properties']})['properties'];
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
            props[name] = {'type': 'string'}; // Fallback to a simple string field
          }
        }
      }
      result['properties'] = props;
    }

    // Handle array items recursively
    if (result['items'] is Map) {
      result['items'] = _cleanSchemaForGemini(result['items'] as Map<String, dynamic>);
    }

    return result;
  }

  // Clean OpenAI-format tools for compatibility with strict backends (like Gemini via NewAPI)
  static List<Map<String, dynamic>> _cleanToolsForCompatibility(List<Map<String, dynamic>> tools) {
    final cleaned = tools.map((tool) {
      final result = Map<String, dynamic>.from(tool);
      final fn = result['function'];
      if (fn is Map) {
        final fnMap = Map<String, dynamic>.from(fn as Map);
        final params = fnMap['parameters'];
        if (params is Map) {
          fnMap['parameters'] = _cleanSchemaForGemini(params as Map<String, dynamic>);
        }
        result['function'] = fnMap;
      }
      return result;
    }).toList();
    // print('[ChatApi/Tools] Cleaned ${cleaned.length} tools: ${jsonEncode(cleaned)}');
    return cleaned;
  }

  // Convert Chat Completions style tools to Responses API style
  // { type: 'function', name, description?, parameters?, strict? }
  static List<Map<String, dynamic>> _toResponsesToolsFormat(List<Map<String, dynamic>> tools) {
    return tools.map((tool) {
      // Keep non-function tools (e.g., web_search) unchanged
      if ((tool['type'] ?? '').toString() != 'function') {
        return Map<String, dynamic>.from(tool);
      }

      // If already flattened (no nested 'function'), return as-is
      if (tool['function'] is! Map) {
        return Map<String, dynamic>.from(tool);
      }

      final fn = Map<String, dynamic>.from(tool['function'] as Map);
      final out = <String, dynamic>{
        'type': 'function',
        if (fn['name'] != null) 'name': fn['name'],
        if (fn['description'] != null) 'description': fn['description'],
      };
      final params = fn['parameters'];
      if (params is Map<String, dynamic>) {
        // Ensure parameters stays as-is (schema)
        out['parameters'] = params;
      }
      // Preserve strict flag if present (either at tool-level or function-level)
      final strict = (tool['strict'] ?? fn['strict']);
      if (strict is bool) {
        out['strict'] = strict;
      }
      return out;
    }).toList();
  }

  static Stream<ChatStreamChunk> _sendOpenAIStream(
      http.Client client,
      ProviderConfig config,
      String modelId,
      List<Map<String, dynamic>> messages,
      {List<String>? userImagePaths, int? thinkingBudget, double? temperature, double? topP, int? maxTokens, List<Map<String, dynamic>>? tools, Future<String> Function(String, Map<String, dynamic>)? onToolCall, Map<String, String>? extraHeaders, Map<String, dynamic>? extraBody, bool stream = true}
      ) async* {
    final upstreamModelId = _apiModelId(config, modelId);
    final base = config.baseUrl.endsWith('/')
        ? config.baseUrl.substring(0, config.baseUrl.length - 1)
        : config.baseUrl;
    final path = (config.useResponseApi == true)
        ? '/responses'
        : (config.chatPath ?? '/chat/completions');
    final url = Uri.parse('$base$path');

    final effectiveInfo = _effectiveModelInfo(config, modelId);
    final isReasoning = effectiveInfo.abilities.contains(ModelAbility.reasoning);
    final wantsImageOutput = effectiveInfo.output.contains(Modality.image);
    final bool canImageInput = effectiveInfo.input.contains(Modality.image);

    final effort = _effortForBudget(thinkingBudget);
    final host = Uri.tryParse(config.baseUrl)?.host.toLowerCase() ?? '';
    final modelLower = upstreamModelId.toLowerCase();
    final bool isAzureOpenAI = host.contains('openai.azure.com');
    final bool isMimoHost = host.contains('xiaomimimo');
    final bool isMimoModel = modelLower.startsWith('mimo-') || modelLower.contains('/mimo-');
    final bool isMimo = isMimoHost || isMimoModel;
    final bool needsReasoningEcho = (host.contains('deepseek') || modelLower.contains('deepseek') || isMimo) && isReasoning;
    // OpenRouter reasoning models require preserving `reasoning_details` across tool-calling turns.
    final bool preserveReasoningDetails = host.contains('openrouter.ai') && isReasoning;
    final String completionTokensKey = (isAzureOpenAI || isMimo) ? 'max_completion_tokens' : 'max_tokens';
    void _setMaxTokens(Map<String, dynamic> map) {
      if (maxTokens != null) map[completionTokensKey] = maxTokens;
    }
    Map<String, dynamic> body;
    // Keep initial Responses request context so we can perform follow-up requests when tools are called
    List<Map<String, dynamic>> responsesInitialInput = const <Map<String, dynamic>>[];
    List<Map<String, dynamic>> responsesToolsSpec = const <Map<String, dynamic>>[];
    String responsesInstructions = '';
    List<dynamic>? responsesIncludeParam;
    if (config.useResponseApi == true) {
      final input = <Map<String, dynamic>>[];
      // Extract system messages into `instructions` (Responses API best practice)
      String instructions = '';
      // Prepare tools list for Responses path (may be augmented with built-in web search)
      final List<Map<String, dynamic>> toolList = [];
      if (tools != null && tools.isNotEmpty) {
        for (final t in tools) {
          if (t is Map<String, dynamic>) toolList.add(Map<String, dynamic>.from(t));
        }
      }

      final builtIns = _builtInTools(config, modelId);
      void addResponsesBuiltInTool(Map<String, dynamic> entry) {
        final type = (entry['type'] ?? '').toString();
        if (type.isEmpty) return;
        final exists = toolList.any((e) => (e['type'] ?? '').toString() == type);
        if (!exists) toolList.add(entry);
      }

      // OpenAI built-in tools (Responses API)
      if (builtIns.contains(BuiltInToolNames.codeInterpreter)) {
        addResponsesBuiltInTool({
          'type': 'code_interpreter',
          'container': {'type': 'auto', 'memory_limit': '4g'},
        });
      }
      if (builtIns.contains(BuiltInToolNames.imageGeneration)) {
        addResponsesBuiltInTool({'type': 'image_generation'});
      }

      // Built-in web search for Responses API when enabled on supported models
      bool _isResponsesWebSearchSupported(String id) {
        final m = id.toLowerCase();
        if (m.startsWith('gpt-4o')) return true; // gpt-4o, gpt-4o-mini
        if (m == 'gpt-4.1' || m == 'gpt-4.1-mini') return true;
        if (m.startsWith('o4-mini')) return true;
        if (m == 'o3' || m.startsWith('o3-')) return true;
        if (m.startsWith('gpt-5')) return true; // supports reasoning web search
        return false;
      }

      if (_isResponsesWebSearchSupported(upstreamModelId)) {
        if (builtIns.contains(BuiltInToolNames.search)) {
          // Optional per-model configuration under modelOverrides[modelId]['webSearch']
          Map<String, dynamic> ws = const <String, dynamic>{};
          try {
            final ov = config.modelOverrides[modelId];
            if (ov is Map && ov['webSearch'] is Map) {
              ws = (ov['webSearch'] as Map).cast<String, dynamic>();
            }
          } catch (_) {}
          final usePreview = (ws['preview'] == true) || ((ws['tool'] ?? '').toString() == 'preview');
          final entry = <String, dynamic>{'type': usePreview ? 'web_search_preview' : 'web_search'};
          // Domain filters
          if (ws['allowed_domains'] is List && (ws['allowed_domains'] as List).isNotEmpty) {
            entry['filters'] = {
              'allowed_domains': List<String>.from((ws['allowed_domains'] as List).map((e) => e.toString())),
            };
          }
          // User location
          if (ws['user_location'] is Map) {
            entry['user_location'] = (ws['user_location'] as Map).cast<String, dynamic>();
          }
          // Search context size (preview tool only)
          if (usePreview && ws['search_context_size'] is String) {
            entry['search_context_size'] = ws['search_context_size'];
          }
          addResponsesBuiltInTool(entry);
          // Optionally request sources in output
          if (ws['include_sources'] == true) {
            // Merge/append include array
            // We'll add this after input loop when building body
          }
        }
      }
      // Collect the last assistant image to attach to the new user message
      String? lastAssistantImageUrl;
      for (int i = 0; i < messages.length; i++) {
        final m = messages[i];
        final isLast = i == messages.length - 1;
        final raw = (m['content'] ?? '').toString();
        final roleRaw = (m['role'] ?? 'user').toString();

        // Responses API supports a top-level `instructions` field that has higher priority
        if (roleRaw == 'system') {
          if (raw.isNotEmpty) {
            instructions = instructions.isEmpty ? raw : (instructions + '\n\n' + raw);
          }
          continue;
        }

        // Handle tool result messages (role: 'tool') - convert to function_call_output format
        if (roleRaw == 'tool') {
          final toolCallId = (m['tool_call_id'] ?? '').toString();
          final content = (m['content'] ?? '').toString();
          if (toolCallId.isNotEmpty) {
            input.add({
              'type': 'function_call_output',
              'call_id': toolCallId,
              'output': content,
            });
          }
          continue;
        }

        final isAssistant = roleRaw == 'assistant';

        // Handle assistant messages with tool_calls - convert to function_call format
        if (isAssistant && m['tool_calls'] is List) {
          final toolCalls = m['tool_calls'] as List;
          for (final tc in toolCalls) {
            if (tc is! Map) continue;
            final callId = (tc['id'] ?? '').toString();
            final fn = tc['function'];
            if (fn is! Map) continue;
            final name = (fn['name'] ?? '').toString();
            final arguments = (fn['arguments'] ?? '{}').toString();
            if (callId.isNotEmpty && name.isNotEmpty) {
              input.add({
                'type': 'function_call',
                'call_id': callId,
                'name': name,
                'arguments': arguments,
              });
            }
          }
          // Skip adding the assistant message content if it only contains tool calls
          if (raw.trim().isEmpty || raw.trim() == '\n\n') continue;
        }

        // Only parse images if there are images to process
        final hasMarkdownImages = raw.contains('![') && raw.contains('](');
        final hasCustomImages = raw.contains('[image:');
        final hasAttachedImages = isLast && (userImagePaths?.isNotEmpty == true) && (m['role'] == 'user');
        // For the last user message, also attach the last assistant image if available
        final shouldAttachAssistantImage = isLast && (m['role'] == 'user') && lastAssistantImageUrl != null;

        if (hasMarkdownImages || hasCustomImages || hasAttachedImages || shouldAttachAssistantImage) {
          final parsed = await _parseTextAndImages(
            raw,
            allowRemoteImages: canImageInput,
            allowLocalImages: true,
            keepRemoteMarkdownText: true,
          );
          final parts = <Map<String, dynamic>>[];
          final seenImageSources = <String>{};
          final seenImageUrls = <String>{};
          String normalizeSrc(String src) {
            if (src.startsWith('http') || src.startsWith('data:')) return src;
            try {
              return SandboxPathResolver.fix(src);
            } catch (_) {
              return src;
            }
          }
          void addImage(String url) {
            if (url.isEmpty) return;
            if (seenImageUrls.add(url)) {
              parts.add({'type': 'input_image', 'image_url': url});
            }
          }
          if (parsed.text.isNotEmpty) {
            // Use output_text for assistant, input_text for user
            parts.add({'type': isAssistant ? 'output_text' : 'input_text', 'text': parsed.text});
          }
          // Images extracted from this message's text
          for (final ref in parsed.images) {
            final normalized = normalizeSrc(ref.src);
            if (!seenImageSources.add(normalized)) continue;
            String url;
            if (ref.kind == 'data') {
              url = ref.src;
            } else if (ref.kind == 'path') {
              url = await _encodeBase64File(ref.src, withPrefix: true);
            } else {
              url = ref.src; // http(s)
            }
            // For assistant messages, collect the last image; for user messages, add directly
            if (isAssistant) {
              lastAssistantImageUrl = url;
            } else {
              addImage(url);
            }
          }
          // Additional images explicitly attached to the last user message
          if (hasAttachedImages) {
            for (final p in userImagePaths!) {
              final normalized = normalizeSrc(p);
              if (!seenImageSources.add(normalized)) continue;
              final dataUrl = (p.startsWith('http') || p.startsWith('data:')) ? p : await _encodeBase64File(p, withPrefix: true);
              addImage(dataUrl);
            }
          }
          // Attach last assistant image to the last user message
          if (shouldAttachAssistantImage && lastAssistantImageUrl != null) {
            addImage(lastAssistantImageUrl);
          }
          // Use proper message object format for assistant messages
          if (isAssistant) {
            input.add({'type': 'message', 'role': 'assistant', 'status': 'completed', 'content': parts});
          } else {
            input.add({'role': roleRaw, 'content': parts});
          }
        } else {
          // No images
          if (isAssistant) {
            // Use proper message object format for assistant messages
            input.add({
              'type': 'message',
              'role': 'assistant',
              'status': 'completed',
              'content': [{'type': 'output_text', 'text': raw}]
            });
          } else {
            input.add({'role': roleRaw, 'content': raw});
          }
        }
      }
      body = {
        'model': upstreamModelId,
        'input': input,
        'stream': stream,
        if (instructions.isNotEmpty) 'instructions': instructions,
        if (temperature != null) 'temperature': temperature,
        if (topP != null) 'top_p': topP,
        if (maxTokens != null) 'max_output_tokens': maxTokens,
        if (toolList.isNotEmpty) 'tools': _toResponsesToolsFormat(toolList),
        if (toolList.isNotEmpty) 'tool_choice': 'auto',
        if (isReasoning && effort != 'off')
          'reasoning': {
            'summary': 'auto',
            if (effort != 'auto') 'effort': effort,
          },
      };
      // Append include parameter if we opted into sources via overrides
      try {
        final ov = config.modelOverrides[modelId];
        final ws = (ov is Map ? ov['webSearch'] : null);
        if (ws is Map && ws['include_sources'] == true) {
          (body as Map<String, dynamic>)['include'] = ['web_search_call.action.sources'];
        }
      } catch (_) {}
      // Save initial Responses context
      try {
        responsesInitialInput = List<Map<String, dynamic>>.from(((body as Map<String, dynamic>)['input'] as List).map((e) => (e as Map).cast<String, dynamic>()));
      } catch (_) {
        responsesInitialInput = const <Map<String, dynamic>>[];
      }
      try {
        if ((body as Map<String, dynamic>)['tools'] is List) {
          responsesToolsSpec = List<Map<String, dynamic>>.from(((body as Map<String, dynamic>)['tools'] as List).map((e) => (e as Map).cast<String, dynamic>()));
        }
      } catch (_) {
        responsesToolsSpec = const <Map<String, dynamic>>[];
      }
      try {
        responsesInstructions = ((body as Map<String, dynamic>)['instructions'] ?? '').toString();
      } catch (_) {
        responsesInstructions = '';
      }
      try {
        responsesIncludeParam = (body as Map<String, dynamic>)['include'] as List?;
      } catch (_) {
        responsesIncludeParam = null;
      }
    } else {
      final mm = <Map<String, dynamic>>[];
      for (int i = 0; i < messages.length; i++) {
        final m = messages[i];
        final isLast = i == messages.length - 1;
        final raw = (m['content'] ?? '').toString();
        final role = (m['role'] ?? 'user').toString();
        final outMsg = Map<String, dynamic>.from(m);
        outMsg['role'] = role;

        // System 消息保持为纯文本，不解析为图片
        if (role == 'system') {
          outMsg['content'] = raw;
          mm.add(outMsg);
          continue;
        }

        // Tool / tool_calls messages must preserve tool-specific fields (tool_call_id / tool_calls / name).
        // Also do not convert tool output to multimodal parts, as many OpenAI-compatible backends require tool content to be a string.
        if (role == 'tool' || (role == 'assistant' && outMsg['tool_calls'] is List && (outMsg['tool_calls'] as List).isNotEmpty)) {
          outMsg['content'] = raw;
          mm.add(outMsg);
          continue;
        }

        // Only parse images if there are images to process
        final hasMarkdownImages = raw.contains('![') && raw.contains('](');
        final hasCustomImages = raw.contains('[image:');
        final hasAttachedImages = isLast && (userImagePaths?.isNotEmpty == true) && (role == 'user');

        if (hasMarkdownImages || hasCustomImages || hasAttachedImages) {
          final parsed = await _parseTextAndImages(
            raw,
            allowRemoteImages: canImageInput,
            allowLocalImages: true,
            keepRemoteMarkdownText: true,
          );
          final parts = <Map<String, dynamic>>[];
          final seenSources = <String>{};
          final seenImageUrls = <String>{};
          final seenVideoUrls = <String>{};
          String normalizeSrc(String src) {
            if (src.startsWith('http') || src.startsWith('data:')) return src;
            try {
              return SandboxPathResolver.fix(src);
            } catch (_) {
              return src;
            }
          }
          void addImageUrl(String url) {
            if (url.isEmpty) return;
            if (seenImageUrls.add(url)) {
              parts.add({'type': 'image_url', 'image_url': {'url': url}});
            }
          }
          void addVideoUrl(String url) {
            if (url.isEmpty) return;
            if (seenVideoUrls.add(url)) {
              parts.add({'type': 'video_url', 'video_url': {'url': url}});
            }
          }
          if (parsed.text.isNotEmpty) {
            parts.add({'type': 'text', 'text': parsed.text});
          }
          for (final ref in parsed.images) {
            final normalized = normalizeSrc(ref.src);
            if (!seenSources.add(normalized)) continue;
            String url;
            if (ref.kind == 'data') {
              url = ref.src;
            } else if (ref.kind == 'path') {
              url = await _encodeBase64File(ref.src, withPrefix: true);
            } else {
              url = ref.src;
            }
            addImageUrl(url);
          }
          if (hasAttachedImages) {
            for (final p in userImagePaths!) {
              final normalized = normalizeSrc(p);
              if (!seenSources.add(normalized)) continue;
              final bool isInlineUrl = p.startsWith('http') || p.startsWith('data:');
              final String mime = isInlineUrl ? _mimeFromDataUrl(p) : _mimeFromPath(p);
              final bool isVideo = mime.toLowerCase().startsWith('video/');
              final String dataUrl = isInlineUrl ? p : await _encodeBase64File(p, withPrefix: true);
              if (isVideo) {
                addVideoUrl(dataUrl);
              } else {
                addImageUrl(dataUrl);
              }
            }
          }
          outMsg['content'] = parts;
          mm.add(outMsg);
        } else {
          // No images, use simple string content
          outMsg['content'] = raw;
          mm.add(outMsg);
        }
      }
      body = {
        'model': upstreamModelId,
        'messages': mm,
        'stream': stream,
        if (temperature != null) 'temperature': temperature,
        if (topP != null) 'top_p': topP,
        if (isReasoning && effort != 'off' && effort != 'auto') 'reasoning_effort': effort,
        if (tools != null && tools.isNotEmpty) 'tools': _cleanToolsForCompatibility(tools),
        if (tools != null && tools.isNotEmpty) 'tool_choice': 'auto',
      };
      _setMaxTokens(body);
    }

    // Vendor-specific reasoning knobs for chat-completions compatible hosts
    if (config.useResponseApi != true) {
      final off = _isOff(thinkingBudget);
      if (host.contains('openrouter.ai')) {
        if (isReasoning) {
          // OpenRouter uses `reasoning.enabled/max_tokens`
          if (off) {
            (body as Map<String, dynamic>)['reasoning'] = {'enabled': false};
          } else {
            final obj = <String, dynamic>{'enabled': true};
            if (thinkingBudget != null && thinkingBudget > 0) obj['max_tokens'] = thinkingBudget;
            (body as Map<String, dynamic>)['reasoning'] = obj;
          }
          (body as Map<String, dynamic>).remove('reasoning_effort');
        } else {
          (body as Map<String, dynamic>).remove('reasoning');
          (body as Map<String, dynamic>).remove('reasoning_effort');
        }
      } else if (host.contains('dashscope') || host.contains('aliyun')) {
        // Aliyun DashScope: enable_thinking + thinking_budget
        if (isReasoning) {
          (body as Map<String, dynamic>)['enable_thinking'] = !off;
          if (!off && thinkingBudget != null && thinkingBudget > 0) {
            (body as Map<String, dynamic>)['thinking_budget'] = thinkingBudget;
          } else {
            (body as Map<String, dynamic>).remove('thinking_budget');
          }
        } else {
          (body as Map<String, dynamic>).remove('enable_thinking');
          (body as Map<String, dynamic>).remove('thinking_budget');
        }
        (body as Map<String, dynamic>).remove('reasoning_effort');
      } else if (host.contains('open.bigmodel.cn') || host.contains('bigmodel') || isMimo) {
        // Zhipu (BigModel) / Xiaomi MiMo: thinking.type enabled/disabled
        if (isReasoning) {
          (body as Map<String, dynamic>)['thinking'] = {'type': off ? 'disabled' : 'enabled'};
        } else {
          (body as Map<String, dynamic>).remove('thinking');
        }
        (body as Map<String, dynamic>).remove('reasoning_effort');
      } else if (host.contains('ark.cn-beijing.volces.com') || host.contains('volc') || host.contains('ark')) {
        // Volc Ark: thinking: { type: enabled|disabled }
        if (isReasoning) {
          (body as Map<String, dynamic>)['thinking'] = {'type': off ? 'disabled' : 'enabled'};
        } else {
          (body as Map<String, dynamic>).remove('thinking');
        }
        (body as Map<String, dynamic>).remove('reasoning_effort');
      } else if (host.contains('intern-ai') || host.contains('intern') || host.contains('chat.intern-ai.org.cn')) {
        // InternLM (InternAI): thinking_mode boolean switch
        if (isReasoning) {
          (body as Map<String, dynamic>)['thinking_mode'] = !off;
        } else {
          (body as Map<String, dynamic>).remove('thinking_mode');
        }
        (body as Map<String, dynamic>).remove('reasoning_effort');
      } else if (host.contains('siliconflow')) {
        // SiliconFlow: OFF -> enable_thinking: false; otherwise omit
        if (isReasoning) {
          if (off) {
            (body as Map<String, dynamic>)['enable_thinking'] = false;
          } else {
            (body as Map<String, dynamic>).remove('enable_thinking');
          }
        } else {
          (body as Map<String, dynamic>).remove('enable_thinking');
        }
        (body as Map<String, dynamic>).remove('reasoning_effort');
      } else if (host.contains('deepseek') || upstreamModelId.toLowerCase().contains('deepseek')) {
        if (isReasoning) {
          if (off) {
            (body as Map<String, dynamic>)['reasoning_content'] = false;
            (body as Map<String, dynamic>).remove('reasoning_budget');
          } else {
            (body as Map<String, dynamic>)['reasoning_content'] = true;
            if (thinkingBudget != null && thinkingBudget > 0) {
              (body as Map<String, dynamic>)['reasoning_budget'] = thinkingBudget;
            } else {
              (body as Map<String, dynamic>).remove('reasoning_budget');
            }
          }
        } else {
          (body as Map<String, dynamic>).remove('reasoning_content');
          (body as Map<String, dynamic>).remove('reasoning_budget');
        }
      }
    }

    final request = http.Request('POST', url);
    final headers = <String, String>{
      'Authorization': 'Bearer ${_apiKeyForRequest(config, modelId)}',
      'Content-Type': 'application/json',
      'Accept': stream ? 'text/event-stream' : 'application/json',
    };
    // Merge custom headers (override takes precedence)
    headers.addAll(_customHeaders(config, modelId));
    if (extraHeaders != null && extraHeaders.isNotEmpty) headers.addAll(extraHeaders);
    request.headers.addAll(headers);
    // Ask for usage in streaming for chat-completions compatible hosts (when supported)
    if (stream && config.useResponseApi != true) {
      final h = Uri.tryParse(config.baseUrl)?.host.toLowerCase() ?? '';
      if (!h.contains('mistral.ai') && !h.contains('openrouter')) {
        (body as Map<String, dynamic>)['stream_options'] = {'include_usage': true};
      }
    }
    // Inject Grok built-in search if configured
    if (upstreamModelId.toLowerCase().contains('grok')) {
      final builtIns = _builtInTools(config, modelId);
      if (builtIns.contains(BuiltInToolNames.search)) {
        (body as Map<String, dynamic>)['search_parameters'] = {
          'mode': 'auto',
          'return_citations': true,
        };
      }
    }

    // Merge custom body keys (override takes precedence)
    final extraBodyCfg = _customBody(config, modelId);
    if (extraBodyCfg.isNotEmpty) {
      (body as Map<String, dynamic>).addAll(extraBodyCfg);
    }
    if (extraBody != null && extraBody.isNotEmpty) {
      extraBody.forEach((k, v) {
        (body as Map<String, dynamic>)[k] = (v is String) ? _parseOverrideValue(v) : v;
      });
    }
    request.body = jsonEncode(body);

    final response = await client.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errorBody = await response.stream.bytesToString();
      throw HttpException('HTTP ${response.statusCode}: $errorBody');
    }

    // Non-streaming path: parse one-shot JSON and optionally follow tool calls.
    if (!stream) {
      final txt = await response.stream.bytesToString();
      try {
        final obj = jsonDecode(txt);
        // Responses API non-stream
        if (config.useResponseApi == true) {
          String outText = '';
          try { outText = (obj['output_text'] ?? '').toString(); } catch (_) {}
          if (outText.isEmpty) {
            try { outText = (obj['response']?['output_text'] ?? '').toString(); } catch (_) {}
          }
          if (outText.isEmpty) {
            try {
              final out = obj['output'] as List?;
              if (out != null) {
                final buf = StringBuffer();
                for (final it in out) {
                  if (it is Map && it['type'] == 'output_text') {
                    final c = (it['content'] ?? '').toString();
                    if (c.isNotEmpty) buf.write(c);
                  } else if (it is Map && it['type'] == 'message') {
                    final content = it['content'] as List?;
                    if (content != null) {
                      for (final part in content) {
                        if (part is Map && (part['type'] == 'output_text' || part['type'] == 'text')) {
                          final t = (part['text'] ?? part['content'] ?? '').toString();
                          if (t.isNotEmpty) buf.write(t);
                        }
                      }
                    }
                  }
                }
                outText = buf.toString();
              }
            } catch (_) {}
          }
          TokenUsage? usage;
          try {
            final u = (obj['usage'] ?? obj['response']?['usage']) as Map?;
            if (u != null) {
              final prompt = (u['prompt_tokens'] ?? u['input_tokens'] ?? 0) as int? ?? 0;
              final completion = (u['completion_tokens'] ?? u['output_tokens'] ?? 0) as int? ?? 0;
              final cached = (u['prompt_tokens_details']?['cached_tokens'] ?? 0) as int? ?? 0;
              usage = TokenUsage(promptTokens: prompt, completionTokens: completion, cachedTokens: cached, totalTokens: prompt + completion);
            }
          } catch (_) {}
          yield ChatStreamChunk(content: outText, isDone: true, totalTokens: usage?.totalTokens ?? 0, usage: usage);
          return;
        }

        // Chat Completions non-stream with tool-calls follow-ups
        List<Map<String, dynamic>> currentMessages = List<Map<String, dynamic>>.from((body['messages'] as List?)?.map((e) => (e as Map).cast<String, dynamic>()) ?? const <Map<String, dynamic>>[]);
        TokenUsage? aggUsage;
        Map<String, dynamic> lastObj = (obj is Map)
            ? (obj as Map).cast<String, dynamic>()
            : <String, dynamic>{};
        while (true) {
          Map<String, dynamic>? c0;
          try {
            final choices = lastObj['choices'] as List?;
            if (choices != null && choices.isNotEmpty) c0 = (choices.first as Map).cast<String, dynamic>();
          } catch (_) {}
          if (c0 == null) {
            final s = (lastObj['output_text'] ?? '').toString();
            yield ChatStreamChunk(content: s, isDone: true, totalTokens: aggUsage?.totalTokens ?? 0, usage: aggUsage);
            return;
          }
          // usage
          try {
            final u = lastObj['usage'];
            if (u is Map) {
              final prompt = (u['prompt_tokens'] ?? 0) as int? ?? 0;
              final completion = (u['completion_tokens'] ?? 0) as int? ?? 0;
              final cached = (u['prompt_tokens_details']?['cached_tokens'] ?? 0) as int? ?? 0;
              final round = TokenUsage(promptTokens: prompt, completionTokens: completion, cachedTokens: cached, totalTokens: prompt + completion);
              aggUsage = (aggUsage ?? const TokenUsage()).merge(round);
            }
          } catch (_) {}

          final msg = (c0['message'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
          final reasoningForTools = (msg['reasoning_content'] ?? msg['reasoning'])?.toString() ?? '';
          final reasoningDetailsForTools = msg['reasoning_details'];
          final tcs = (msg['tool_calls'] as List?) ?? const <dynamic>[];
          if (tcs.isNotEmpty && onToolCall != null) {
            final calls = <Map<String, dynamic>>[];
            final callInfos = <ToolCallInfo>[];
            for (int i = 0; i < tcs.length; i++) {
              final t = (tcs[i] as Map).cast<String, dynamic>();
              final id = (t['id'] ?? 'call_$i').toString();
              final f = (t['function'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
              final name = (f['name'] ?? '').toString();
              Map<String, dynamic> args;
              try { args = (jsonDecode((f['arguments'] ?? '{}').toString()) as Map).cast<String, dynamic>(); } catch (_) { args = <String, dynamic>{}; }
              callInfos.add(ToolCallInfo(id: id, name: name, arguments: args));
              calls.add({'id': id, 'type': 'function', 'function': {'name': name, 'arguments': jsonEncode(args)}});
            }
            if (callInfos.isNotEmpty) {
              yield ChatStreamChunk(content: '', isDone: false, totalTokens: aggUsage?.totalTokens ?? 0, usage: aggUsage, toolCalls: callInfos);
            }
            final results = <Map<String, dynamic>>[];
            final resultsInfo = <ToolResultInfo>[];
            for (final c in callInfos) {
              final res = await onToolCall(c.name, c.arguments) ?? '';
              results.add({'tool_call_id': c.id, 'content': res});
              resultsInfo.add(ToolResultInfo(id: c.id, name: c.name, arguments: c.arguments, content: res));
            }
            if (resultsInfo.isNotEmpty) {
              yield ChatStreamChunk(content: '', isDone: false, totalTokens: aggUsage?.totalTokens ?? 0, usage: aggUsage, toolResults: resultsInfo);
            }
            // Follow-up request
            final req = http.Request('POST', url);
            final headers2 = <String, String>{
              'Authorization': 'Bearer ${_apiKeyForRequest(config, modelId)}',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            };
            headers2.addAll(_customHeaders(config, modelId));
            if (extraHeaders != null && extraHeaders.isNotEmpty) headers2.addAll(extraHeaders);
            req.headers.addAll(headers2);
            final next = <Map<String, dynamic>>[];
            for (final m in messages) {
              next.add(_copyChatCompletionMessage(m));
            }
            final assistantToolCallMsg = <String, dynamic>{'role': 'assistant', 'content': '\n\n', 'tool_calls': calls};
            if (needsReasoningEcho) {
              assistantToolCallMsg['reasoning_content'] = reasoningForTools;
            }
            if (preserveReasoningDetails && reasoningDetailsForTools is List && reasoningDetailsForTools.isNotEmpty) {
              assistantToolCallMsg['reasoning_details'] = reasoningDetailsForTools;
            }
            next.add(assistantToolCallMsg);
            for (final r in results) {
              final id = r['tool_call_id'];
              final name = calls.firstWhere((c) => c['id'] == id, orElse: () => const {'function': {'name': ''}})['function']['name'];
              next.add({'role': 'tool', 'tool_call_id': id, 'name': name, 'content': r['content']});
            }
            final reqBody = Map<String, dynamic>.from(body);
            reqBody['messages'] = next;
            reqBody.remove('stream');
            req.body = jsonEncode(reqBody);
            final resp2 = await client.send(req);
            if (resp2.statusCode < 200 || resp2.statusCode >= 300) {
              final errorBody = await resp2.stream.bytesToString();
              throw HttpException('HTTP ${resp2.statusCode}: $errorBody');
            }
            final txt2 = await resp2.stream.bytesToString();
            lastObj = jsonDecode(txt2) as Map<String, dynamic>;
            messages = next; // update transcript for next round
            continue;
          }

          // No tool calls -> final content
          String content = '';
          final cmsg = (c0['message'] as Map?)?.cast<String, dynamic>();
          if (cmsg != null) {
            final cc = cmsg['content'];
            if (cc is String) {
              content = cc;
            } else if (cc is List) {
              final buf = StringBuffer();
              for (final it in cc) {
                if (it is Map && (it['type'] == 'text')) {
                  final t = (it['text'] ?? '').toString();
                  if (t.isNotEmpty) buf.write(t);
                } else if (it is Map && (it['type'] == 'image_url' || it['type'] == 'image')) {
                  dynamic iu = it['image_url'];
                  String? url;
                  if (iu is String) { url = iu; } else if (iu is Map) { final u2 = iu['url']; if (u2 is String) url = u2; }
                  if (url != null && url.isNotEmpty) buf.write('\n\n![image](' + url + ')');
                }
              }
              content = buf.toString();
            }
          }
          yield ChatStreamChunk(content: content, isDone: true, totalTokens: aggUsage?.totalTokens ?? 0, usage: aggUsage);
          return;
        }
      } catch (e) {
        throw HttpException('Invalid JSON: $e');
      }
    }

    // Streaming path
    final sse = response.stream.transform(utf8.decoder);
    String buffer = '';
    int totalTokens = 0;
    TokenUsage? usage;
    // Fallback approx token calculation when provider doesn't include usage
    int _approxTokensFromChars(int chars) => (chars / 4).round();
    final int approxPromptChars = messages.fold<int>(0, (acc, m) => acc + ((m['content'] ?? '').toString().length));
    final int approxPromptTokens = _approxTokensFromChars(approxPromptChars);
    int approxCompletionChars = 0;
    String reasoningBuffer = '';
    dynamic reasoningDetailsBuffer;

    // Track potential tool calls (OpenAI Chat Completions)
    final Map<int, Map<String, String>> toolAcc = <int, Map<String, String>>{}; // index -> {id,name,args}
    // Track potential tool calls (OpenAI Responses API)
    final Map<String, Map<String, String>> toolAccResp = <String, Map<String, String>>{}; // id/name -> {name,args}
    // Responses API: track by output_index to capture call_id reliably
    final Map<int, Map<String, String>> respToolCallsByIndex = <int, Map<String, String>>{}; // index -> {call_id,name,args}
    List<Map<String, dynamic>> lastResponseOutputItems = const <Map<String, dynamic>>[];
    String? finishReason;

    await for (final chunk in sse) {
      buffer += chunk;
      final lines = buffer.split('\n');
      buffer = lines.last;

      for (int i = 0; i < lines.length - 1; i++) {
        final line = lines[i].trim();
        if (line.isEmpty || !line.startsWith('data:')) continue;

        final data = line.substring(5).trimLeft();
        if (data == '[DONE]') {
          // If model streamed tool_calls but didn't include finish_reason on prior chunks,
          // execute tool flow now and start follow-up request.
          if (onToolCall != null && toolAcc.isNotEmpty) {
            final calls = <Map<String, dynamic>>[];
            final callInfos = <ToolCallInfo>[];
            final toolMsgs = <Map<String, dynamic>>[];
            toolAcc.forEach((idx, m) {
              final id = (m['id'] ?? 'call_$idx');
              final name = (m['name'] ?? '');
              Map<String, dynamic> args;
              try { args = (jsonDecode(m['args'] ?? '{}') as Map).cast<String, dynamic>(); } catch (_) { args = <String, dynamic>{}; }
              callInfos.add(ToolCallInfo(id: id, name: name, arguments: args));
              calls.add({
                'id': id,
                'type': 'function',
                'function': {
                  'name': name,
                  'arguments': jsonEncode(args),
                },
              });
              toolMsgs.add({'__name': name, '__id': id, '__args': args});
            });

            if (callInfos.isNotEmpty) {
              final approxTotal = approxPromptTokens + _approxTokensFromChars(approxCompletionChars);
              yield ChatStreamChunk(content: '', isDone: false, totalTokens: usage?.totalTokens ?? approxTotal, usage: usage, toolCalls: callInfos);
            }

            // Execute tools and emit results
            final results = <Map<String, dynamic>>[];
            final resultsInfo = <ToolResultInfo>[];
            for (final m in toolMsgs) {
              final name = m['__name'] as String;
              final id = m['__id'] as String;
              final args = (m['__args'] as Map<String, dynamic>);
              final res = await onToolCall(name, args) ?? '';
              results.add({'tool_call_id': id, 'content': res});
              resultsInfo.add(ToolResultInfo(id: id, name: name, arguments: args, content: res));
            }
            if (resultsInfo.isNotEmpty) {
              yield ChatStreamChunk(content: '', isDone: false, totalTokens: usage?.totalTokens ?? 0, usage: usage, toolResults: resultsInfo);
            }

            // Build follow-up messages
            final mm2 = <Map<String, dynamic>>[];
            for (final m in messages) {
              mm2.add(_copyChatCompletionMessage(m));
            }
            final assistantToolCallMsg = <String, dynamic>{'role': 'assistant', 'content': '\n\n', 'tool_calls': calls};
            if (needsReasoningEcho) {
              assistantToolCallMsg['reasoning_content'] = reasoningBuffer;
            }
            if (preserveReasoningDetails && reasoningDetailsBuffer is List && reasoningDetailsBuffer.isNotEmpty) {
              assistantToolCallMsg['reasoning_details'] = reasoningDetailsBuffer;
            }
            mm2.add(assistantToolCallMsg);
            for (final r in results) {
              final id = r['tool_call_id'];
              final name = calls.firstWhere((c) => c['id'] == id, orElse: () => const {'function': {'name': ''}})['function']['name'];
              mm2.add({'role': 'tool', 'tool_call_id': id, 'name': name, 'content': r['content']});
            }

            // Follow-up request(s) with multi-round tool calls
            var currentMessages = mm2;
            while (true) {
              final Map<String, dynamic> body2 = {
                'model': upstreamModelId,
                'messages': currentMessages,
                'stream': true,
                if (temperature != null) 'temperature': temperature,
                if (topP != null) 'top_p': topP,
                if (isReasoning && effort != 'off' && effort != 'auto') 'reasoning_effort': effort,
                if (tools != null && tools.isNotEmpty) 'tools': _cleanToolsForCompatibility(tools),
                if (tools != null && tools.isNotEmpty) 'tool_choice': 'auto',
              };
              _setMaxTokens(body2);

              // Apply the same vendor-specific reasoning settings as the original request
              final off = _isOff(thinkingBudget);
              if (host.contains('openrouter.ai')) {
                if (isReasoning) {
                  if (off) {
                    body2['reasoning'] = {'enabled': false};
                  } else {
                    final obj = <String, dynamic>{'enabled': true};
                    if (thinkingBudget != null && thinkingBudget > 0) obj['max_tokens'] = thinkingBudget;
                    body2['reasoning'] = obj;
                  }
                  body2.remove('reasoning_effort');
                } else {
                  body2.remove('reasoning');
                  body2.remove('reasoning_effort');
                }
              } else if (host.contains('dashscope') || host.contains('aliyun')) {
                if (isReasoning) {
                  body2['enable_thinking'] = !off;
                  if (!off && thinkingBudget != null && thinkingBudget > 0) {
                    body2['thinking_budget'] = thinkingBudget;
                  } else {
                    body2.remove('thinking_budget');
                  }
                } else {
                  body2.remove('enable_thinking');
                  body2.remove('thinking_budget');
                }
                body2.remove('reasoning_effort');
              } else if (host.contains('open.bigmodel.cn') || host.contains('bigmodel') || isMimo) {
                if (isReasoning) {
                  body2['thinking'] = {'type': off ? 'disabled' : 'enabled'};
                } else {
                  body2.remove('thinking');
                }
                body2.remove('reasoning_effort');
              } else if (host.contains('ark.cn-beijing.volces.com') || host.contains('volc') || host.contains('ark')) {
                if (isReasoning) {
                  body2['thinking'] = {'type': off ? 'disabled' : 'enabled'};
                } else {
                  body2.remove('thinking');
                }
                body2.remove('reasoning_effort');
              } else if (host.contains('intern-ai') || host.contains('intern') || host.contains('chat.intern-ai.org.cn')) {
                if (isReasoning) {
                  body2['thinking_mode'] = !off;
                } else {
                  body2.remove('thinking_mode');
                }
                body2.remove('reasoning_effort');
              } else if (host.contains('siliconflow')) {
                if (isReasoning) {
                  if (off) {
                    body2['enable_thinking'] = false;
                  } else {
                    body2.remove('enable_thinking');
                  }
                } else {
                  body2.remove('enable_thinking');
                }
                body2.remove('reasoning_effort');
              } else if (host.contains('deepseek') || upstreamModelId.toLowerCase().contains('deepseek')) {
                if (isReasoning) {
                  if (off) {
                    body2['reasoning_content'] = false;
                    body2.remove('reasoning_budget');
                  } else {
                    body2['reasoning_content'] = true;
                    if (thinkingBudget != null && thinkingBudget > 0) {
                      body2['reasoning_budget'] = thinkingBudget;
                    } else {
                      body2.remove('reasoning_budget');
                    }
                  }
                } else {
                  body2.remove('reasoning_content');
                  body2.remove('reasoning_budget');
                }
              }

              // Ask for usage in streaming (when supported)
              if (!host.contains('mistral.ai') && !host.contains('openrouter')) {
                body2['stream_options'] = {'include_usage': true};
              }

              // Apply custom body overrides
              if (extraBodyCfg.isNotEmpty) {
                body2.addAll(extraBodyCfg);
              }
              if (extraBody != null && extraBody.isNotEmpty) {
                extraBody.forEach((k, v) {
                  body2[k] = (v is String) ? _parseOverrideValue(v) : v;
                });
              }

              final req2 = http.Request('POST', url);
              final headers2 = <String, String>{
                'Authorization': 'Bearer ${_apiKeyForRequest(config, modelId)}',
                'Content-Type': 'application/json',
                'Accept': 'text/event-stream',
              };
              // Apply custom headers
              headers2.addAll(_customHeaders(config, modelId));
              if (extraHeaders != null && extraHeaders.isNotEmpty) headers2.addAll(extraHeaders);
              req2.headers.addAll(headers2);
              req2.body = jsonEncode(body2);
              final resp2 = await client.send(req2);
              if (resp2.statusCode < 200 || resp2.statusCode >= 300) {
                final errorBody = await resp2.stream.bytesToString();
                throw HttpException('HTTP ${resp2.statusCode}: $errorBody');
              }
              final s2 = resp2.stream.transform(utf8.decoder);
              String buf2 = '';
              // Track potential subsequent tool calls
              final Map<int, Map<String, String>> toolAcc2 = <int, Map<String, String>>{};
              String? finishReason2;
              String contentAccum = ''; // Accumulate content for this round
              String reasoningAccum = '';
              dynamic reasoningDetailsAccum;
              await for (final ch in s2) {
                buf2 += ch;
                final lines2 = buf2.split('\n');
                buf2 = lines2.last;
                for (int j = 0; j < lines2.length - 1; j++) {
                  final l = lines2[j].trim();
                  if (l.isEmpty || !l.startsWith('data:')) continue;
                  final d = l.substring(5).trimLeft();
                  if (d == '[DONE]') {
                    // This round finished; handle below
                    continue;
                  }
                  try {
                    final o = jsonDecode(d);
                    if (o is Map && o['choices'] is List && (o['choices'] as List).isNotEmpty) {
                      final c0 = (o['choices'] as List).first;
                      finishReason2 = c0['finish_reason'] as String?;
                      final delta = c0['delta'] as Map?;
                      final message = c0['message'] as Map?;
                      final txt = delta?['content'];
                      final rc = delta?['reasoning_content'] ?? delta?['reasoning'];
                      final u = o['usage'];
                      if (u != null) {
                        final prompt = (u['prompt_tokens'] ?? 0) as int;
                        final completion = (u['completion_tokens'] ?? 0) as int;
                        final cached = (u['prompt_tokens_details']?['cached_tokens'] ?? 0) as int? ?? 0;
                        usage = (usage ?? const TokenUsage()).merge(TokenUsage(promptTokens: prompt, completionTokens: completion, cachedTokens: cached));
                        totalTokens = usage!.totalTokens;
                      }
                      // Capture Grok citations
                      final gCitations = o['citations'];
                      if (gCitations is List && gCitations.isNotEmpty) {
                        final items = <Map<String, dynamic>>[];
                        for (int k = 0; k < gCitations.length; k++) {
                          final u = gCitations[k].toString();
                          items.add({'index': k + 1, 'url': u, 'title': u});
                        }
                        if (items.isNotEmpty) {
                          final payload = jsonEncode({'items': items});
                          yield ChatStreamChunk(
                            content: '',
                            isDone: false,
                            totalTokens: usage?.totalTokens ?? 0,
                            usage: usage,
                            toolResults: [ToolResultInfo(id: 'builtin_search', name: 'search_web', arguments: const <String, dynamic>{}, content: payload)],
                          );
                        }
                      }
                      if (rc is String && rc.isNotEmpty) {
                        if (needsReasoningEcho) reasoningAccum += rc;
                        yield ChatStreamChunk(content: '', reasoning: rc, isDone: false, totalTokens: 0, usage: usage);
                      }
                      if (txt is String && txt.isNotEmpty) {
                        contentAccum += txt; // Accumulate content
                        yield ChatStreamChunk(content: txt, isDone: false, totalTokens: 0, usage: usage);
                      }
                      // Fallback/merge: message.content in same chunk (if any)
                      if (message != null && message['content'] != null) {
                        final mc = message['content'];
                        if (mc is String && mc.isNotEmpty) {
                          contentAccum += mc;
                          yield ChatStreamChunk(content: mc, isDone: false, totalTokens: 0, usage: usage);
                        }
                      }
                      if (message != null) {
                        final rcMsg = message['reasoning_content'] ?? message['reasoning'];
                        if (rcMsg is String && rcMsg.isNotEmpty && needsReasoningEcho) {
                          reasoningAccum += rcMsg;
                        }
                      }
                      if (preserveReasoningDetails) {
                        final rd = delta?['reasoning_details'];
                        if (rd is List && rd.isNotEmpty) reasoningDetailsAccum = rd;
                        final rdMsg = message?['reasoning_details'];
                        if (rdMsg is List && rdMsg.isNotEmpty) reasoningDetailsAccum = rdMsg;
                      }
                      // Handle image outputs from OpenRouter-style deltas
                      // Possible shapes:
                      // - delta['images']: [ { type: 'image_url', image_url: { url: 'data:...' }, index: 0 }, ... ]
                      // - delta['content']: [ { type: 'image_url', image_url: { url: '...' } }, { type: 'text', text: '...' } ]
                      // - delta['image_url'] directly (less common)
                      if (wantsImageOutput) {
                        final List<dynamic> imageItems = <dynamic>[];
                        final imgs = delta?['images'];
                        if (imgs is List) imageItems.addAll(imgs);
                        final contentArr = (txt is List) ? txt : (delta?['content'] as List?);
                        if (contentArr is List) {
                          for (final it in contentArr) {
                            if (it is Map && (it['type'] == 'image_url' || it['type'] == 'image')) {
                              imageItems.add(it);
                            }
                          }
                        }
                        final singleImage = delta?['image_url'];
                        if (singleImage is Map || singleImage is String) {
                          imageItems.add({'type': 'image_url', 'image_url': singleImage});
                        }
                        if (imageItems.isNotEmpty) {
                          final buf = StringBuffer();
                          for (final it in imageItems) {
                            if (it is! Map) continue;
                            dynamic iu = it['image_url'];
                            String? url;
                            if (iu is String) {
                              url = iu;
                            } else if (iu is Map) {
                              final u2 = iu['url'];
                              if (u2 is String) url = u2;
                            }
                            if (url != null && url.isNotEmpty) {
                              final md = '\n\n![image](' + url + ')';
                              buf.write(md);
                              contentAccum += md;
                            }
                          }
                          final out = buf.toString();
                          if (out.isNotEmpty) {
                            yield ChatStreamChunk(content: out, isDone: false, totalTokens: 0, usage: usage);
                          }
                        }
                      }
                      final tcs = delta?['tool_calls'] as List?;
                      if (tcs != null) {
                        for (final t in tcs) {
                          final idx = (t['index'] as int?) ?? 0;
                          final id = t['id'] as String?;
                          final func = t['function'] as Map<String, dynamic>?;
                          final name = func?['name'] as String?;
                          final argsDelta = func?['arguments'] as String?;
                          final entry = toolAcc2.putIfAbsent(idx, () => {'id': '', 'name': '', 'args': ''});
                          if (id != null) entry['id'] = id;
                          if (name != null && name.isNotEmpty) entry['name'] = name;
                          if (argsDelta != null && argsDelta.isNotEmpty) entry['args'] = (entry['args'] ?? '') + argsDelta;
                        }
                      }
                    }
                  } catch (_) {}
                }
              }

              // After this follow-up round finishes: if tool calls again, execute and loop
              if ((finishReason2 == 'tool_calls' || toolAcc2.isNotEmpty) && onToolCall != null) {
                final calls2 = <Map<String, dynamic>>[];
                final callInfos2 = <ToolCallInfo>[];
                final toolMsgs2 = <Map<String, dynamic>>[];
                toolAcc2.forEach((idx, m) {
                  final id = (m['id'] ?? 'call_$idx');
                  final name = (m['name'] ?? '');
                  Map<String, dynamic> args;
                  try { args = (jsonDecode(m['args'] ?? '{}') as Map).cast<String, dynamic>(); } catch (_) { args = <String, dynamic>{}; }
                  callInfos2.add(ToolCallInfo(id: id, name: name, arguments: args));
                  calls2.add({'id': id, 'type': 'function', 'function': {'name': name, 'arguments': jsonEncode(args)}});
                  toolMsgs2.add({'__name': name, '__id': id, '__args': args});
                });
                if (callInfos2.isNotEmpty) {
                  yield ChatStreamChunk(content: '', isDone: false, totalTokens: usage?.totalTokens ?? 0, usage: usage, toolCalls: callInfos2);
                }
                final results2 = <Map<String, dynamic>>[];
                final resultsInfo2 = <ToolResultInfo>[];
                for (final m in toolMsgs2) {
                  final name = m['__name'] as String;
                  final id = m['__id'] as String;
                  final args = (m['__args'] as Map<String, dynamic>);
                  final res = await onToolCall(name, args) ?? '';
                  results2.add({'tool_call_id': id, 'content': res});
                  resultsInfo2.add(ToolResultInfo(id: id, name: name, arguments: args, content: res));
                }
                if (resultsInfo2.isNotEmpty) {
                  yield ChatStreamChunk(content: '', isDone: false, totalTokens: usage?.totalTokens ?? 0, usage: usage, toolResults: resultsInfo2);
                }
                // Append for next loop - including any content accumulated in this round
                final nextAssistantToolCall = <String, dynamic>{'role': 'assistant', 'content': '\n\n', 'tool_calls': calls2};
                if (needsReasoningEcho) {
                  nextAssistantToolCall['reasoning_content'] = reasoningAccum;
                }
                if (preserveReasoningDetails && reasoningDetailsAccum is List && reasoningDetailsAccum.isNotEmpty) {
                  nextAssistantToolCall['reasoning_details'] = reasoningDetailsAccum;
                }
                currentMessages = [
                  ...currentMessages,
                  if (contentAccum.isNotEmpty) {'role': 'assistant', 'content': contentAccum},
                  nextAssistantToolCall,
                  for (final r in results2)
                    {
                      'role': 'tool',
                      'tool_call_id': r['tool_call_id'],
                      'name': calls2.firstWhere((c) => c['id'] == r['tool_call_id'], orElse: () => const {'function': {'name': ''}})['function']['name'],
                      'content': r['content'],
                    },
                ];
                // Continue loop
                continue;
              } else {
                // No further tool calls; finish
                final approxTotal = approxPromptTokens + _approxTokensFromChars(approxCompletionChars);
                yield ChatStreamChunk(content: '', isDone: true, totalTokens: usage?.totalTokens ?? approxTotal, usage: usage);
                return;
              }
            }
            // Should not reach here
            return;
          }

          final approxTotal = approxPromptTokens + _approxTokensFromChars(approxCompletionChars);
          yield ChatStreamChunk(
            content: '',
            isDone: true,
            totalTokens: usage?.totalTokens ?? approxTotal,
            usage: usage,
          );
          return;
        }

        try {
          final json = jsonDecode(data);
          String content = '';
          String? reasoning;

          if (config.useResponseApi == true) {
            // OpenAI /responses SSE types
            final type = json['type'];
            if (type == 'response.output_text.delta') {
              final delta = json['delta'];
              if (delta is String) {
                content = delta;
                approxCompletionChars += content.length;
              }
            } else if (type == 'response.reasoning_summary_text.delta') {
              final delta = json['delta'];
              if (delta is String) reasoning = delta;
            } else if (type == 'response.output_item.added') {
              try {
                final item = json['item'];
                final idx = (json['output_index'] ?? 0) as int;
                if (item is Map && (item['type'] ?? '') == 'function_call') {
                  final name = (item['name'] ?? '').toString();
                  final callId = (item['call_id'] ?? '').toString();
                  respToolCallsByIndex[idx] = {
                    'call_id': callId,
                    'name': name,
                    'args': '',
                  };
                }
              } catch (_) {}
            } else if (type == 'response.function_call_arguments.delta') {
              try {
                final idx = (json['output_index'] ?? 0) as int;
                final delta = (json['delta'] ?? '').toString();
                final entry = respToolCallsByIndex.putIfAbsent(idx, () => {'call_id': '', 'name': '', 'args': ''});
                if (delta.isNotEmpty) entry['args'] = (entry['args'] ?? '') + delta;
              } catch (_) {}
            } else if (type == 'response.output_item.done') {
              try {
                final item = json['item'];
                final idx = (json['output_index'] ?? 0) as int;
                if (item is Map && (item['type'] ?? '') == 'function_call') {
                  final args = (item['arguments'] ?? '').toString();
                  final entry = respToolCallsByIndex.putIfAbsent(idx, () => {
                        'call_id': (item['call_id'] ?? '').toString(),
                        'name': (item['name'] ?? '').toString(),
                        'args': ''
                      });
                  if (args.isNotEmpty) entry['args'] = args;
                }
              } catch (_) {}
            } else if (type is String && type.contains('function_call')) {
              // Accumulate function call args for Responses API
              final id = (json['id'] ?? json['call_id'] ?? '').toString();
              final name = (json['name'] ?? json['function']?['name'] ?? '').toString();
              final argsDelta = (json['arguments'] ?? json['arguments_delta'] ?? json['delta'] ?? '').toString();
              if (id.isNotEmpty || name.isNotEmpty) {
                final key = id.isNotEmpty ? id : name;
                final entry = toolAccResp.putIfAbsent(key, () => {'name': name, 'args': ''});
                if (name.isNotEmpty) entry['name'] = name;
                if (argsDelta.isNotEmpty) entry['args'] = (entry['args'] ?? '') + argsDelta;
              }
            } else if (type == 'response.completed') {
              final u = json['response']?['usage'];
              if (u != null) {
                final inTok = (u['input_tokens'] ?? 0) as int;
                final outTok = (u['output_tokens'] ?? 0) as int;
                usage = (usage ?? const TokenUsage()).merge(TokenUsage(promptTokens: inTok, completionTokens: outTok));
                totalTokens = usage!.totalTokens;
              }
              // Extract web search citations from final output (Responses API)
              try {
                final output = json['response']?['output'];
                final items = <Map<String, dynamic>>[];
                // Save output items for potential follow-up call input
                lastResponseOutputItems = const <Map<String, dynamic>>[];
                if (output is List) {
                  lastResponseOutputItems = [
                    for (final it in output)
                      if (it is Map) (it.cast<String, dynamic>())
                  ];
                }
                if (output is List) {
                  int idx = 1;
                  final seen = <String>{};
                  for (final it in output) {
                    if (it is! Map) continue;
                    if (it['type'] == 'message') {
                      final content = it['content'] as List? ?? const <dynamic>[];
                      for (final block in content) {
                        if (block is! Map) continue;
                        final anns = block['annotations'] as List? ?? const <dynamic>[];
                        for (final an in anns) {
                          if (an is! Map) continue;
                          if ((an['type'] ?? '') == 'url_citation') {
                            final url = (an['url'] ?? '').toString();
                            if (url.isEmpty || seen.contains(url)) continue;
                            final title = (an['title'] ?? '').toString();
                            items.add({'index': idx, 'url': url, if (title.isNotEmpty) 'title': title});
                            seen.add(url);
                            idx += 1;
                          }
                        }
                      }
                    } else if (it['type'] == 'image_generation_call') {
                      // Handle image generation output from OpenAI Responses API
                      // it['result'] is directly the base64 image data
                      final b64 = (it['result'] ?? '').toString();
                      if (b64.isNotEmpty) {
                        final savedPath = await AppDirectories.saveBase64Image('image/png', b64);
                        if (savedPath != null && savedPath.isNotEmpty) {
                          final mdImg = '\n![Generated Image]($savedPath)\n';
                          yield ChatStreamChunk(
                            content: mdImg,
                            isDone: false,
                            totalTokens: totalTokens,
                            usage: usage,
                          );
                        }
                      }
                    }
                  }
                }
                if (items.isNotEmpty) {
                  final payload = jsonEncode({'items': items});
                  yield ChatStreamChunk(
                    content: '',
                    isDone: false,
                    totalTokens: totalTokens,
                    usage: usage,
                    toolResults: [ToolResultInfo(id: 'builtin_search', name: 'search_web', arguments: const <String, dynamic>{}, content: payload)],
                  );
                }
              } catch (_) {}
              // Responses tool calling follow-up handling
              final bool hasRespCalls = respToolCallsByIndex.isNotEmpty || toolAccResp.isNotEmpty;
              if (onToolCall != null && hasRespCalls) {
                // Prefer the indexed calls (with call_id); fallback to toolAccResp
                final calls = <Map<String, dynamic>>[];
                final callInfos = <ToolCallInfo>[];
                final msgs = <Map<String, dynamic>>[]; // for executing tools
                if (respToolCallsByIndex.isNotEmpty) {
                  final sorted = respToolCallsByIndex.keys.toList()..sort();
                  for (final idx in sorted) {
                    final m = respToolCallsByIndex[idx]!;
                    final callId = (m['call_id'] ?? '').toString();
                    final name = (m['name'] ?? '').toString();
                    Map<String, dynamic> args;
                    try { args = (jsonDecode(m['args'] ?? '{}') as Map).cast<String, dynamic>(); } catch (_) { args = <String, dynamic>{}; }
                    callInfos.add(ToolCallInfo(id: callId.isNotEmpty ? callId : 'call_$idx', name: name, arguments: args));
                    msgs.add({'__id': callId.isNotEmpty ? callId : 'call_$idx', '__name': name, '__args': args});
                  }
                } else {
                  int idx = 0;
                  toolAccResp.forEach((key, m) {
                    Map<String, dynamic> args;
                    try { args = (jsonDecode(m['args'] ?? '{}') as Map).cast<String, dynamic>(); } catch (_) { args = <String, dynamic>{}; }
                    final id2 = key.isNotEmpty ? key : 'call_$idx';
                    callInfos.add(ToolCallInfo(id: id2, name: (m['name'] ?? ''), arguments: args));
                    msgs.add({'__id': id2, '__name': (m['name'] ?? ''), '__args': args});
                    idx += 1;
                  });
                }
                if (callInfos.isNotEmpty) {
                  final approxTotal = approxPromptTokens + _approxTokensFromChars(approxCompletionChars);
                  yield ChatStreamChunk(content: '', isDone: false, totalTokens: usage?.totalTokens ?? approxTotal, usage: usage, toolCalls: callInfos);
                }
                final resultsInfo = <ToolResultInfo>[];
                final followUpOutputs = <Map<String, dynamic>>[];
                for (final m in msgs) {
                  final nm = m['__name'] as String;
                  final id2 = m['__id'] as String;
                  final args = (m['__args'] as Map<String, dynamic>);
                  final res = await onToolCall(nm, args) ?? '';
                  resultsInfo.add(ToolResultInfo(id: id2, name: nm, arguments: args, content: res));
                  followUpOutputs.add({'type': 'function_call_output', 'call_id': id2, 'output': res});
                }
                if (resultsInfo.isNotEmpty) {
                  yield ChatStreamChunk(content: '', isDone: false, totalTokens: usage?.totalTokens ?? 0, usage: usage, toolResults: resultsInfo);
                }

                // Build follow-up Responses request input
                List<Map<String, dynamic>> currentInput = <Map<String, dynamic>>[...responsesInitialInput];
                if (lastResponseOutputItems.isNotEmpty) currentInput.addAll(lastResponseOutputItems);
                currentInput.addAll(followUpOutputs);

                // Iteratively request until no more tool calls
                for (int round = 0; round < 3; round++) {
                  final body2 = <String, dynamic>{
                    'model': upstreamModelId,
                    'input': currentInput,
                    'stream': true,
                    if (responsesToolsSpec.isNotEmpty) 'tools': responsesToolsSpec,
                    if (responsesToolsSpec.isNotEmpty) 'tool_choice': 'auto',
                    if (responsesInstructions.isNotEmpty) 'instructions': responsesInstructions,
                    if (temperature != null) 'temperature': temperature,
                    if (topP != null) 'top_p': topP,
                    if (maxTokens != null) 'max_output_tokens': maxTokens,
                    if (isReasoning && effort != 'off')
                      'reasoning': {
                        'summary': 'auto',
                        if (effort != 'auto') 'effort': effort,
                      },
                    if (responsesIncludeParam != null) 'include': responsesIncludeParam,
                  };

                  // Apply overrides
                  final extraCfg = _customBody(config, modelId);
                  if (extraCfg.isNotEmpty) body2.addAll(extraCfg);
                  if (extraBody != null && extraBody.isNotEmpty) {
                    extraBody.forEach((k, v) {
                      body2[k] = (v is String) ? _parseOverrideValue(v) : v;
                    });
                  }
                  // Ensure tools are flattened
                  try {
                    if (body2['tools'] is List) {
                      final raw = (body2['tools'] as List).cast<dynamic>();
                      body2['tools'] = _toResponsesToolsFormat(raw.map((e) => (e as Map).cast<String, dynamic>()).toList());
                    }
                  } catch (_) {}

                  final req2 = http.Request('POST', url);
                  final headers2 = <String, String>{
                    'Authorization': 'Bearer ${_apiKeyForRequest(config, modelId)}',
                    'Content-Type': 'application/json',
                    'Accept': 'text/event-stream',
                  };
                  headers2.addAll(_customHeaders(config, modelId));
                  if (extraHeaders != null && extraHeaders.isNotEmpty) headers2.addAll(extraHeaders);
                  req2.headers.addAll(headers2);
                  req2.body = jsonEncode(body2);
                  final resp2 = await client.send(req2);
                  if (resp2.statusCode < 200 || resp2.statusCode >= 300) {
                    final errorBody = await resp2.stream.bytesToString();
                    throw HttpException('HTTP ${resp2.statusCode}: $errorBody');
                  }
                  final s2 = resp2.stream.transform(utf8.decoder);
                  String buf2 = '';
                  final Map<int, Map<String, String>> respCalls2 = <int, Map<String, String>>{};
                  List<Map<String, dynamic>> outItems2 = const <Map<String, dynamic>>[];
                  await for (final ch in s2) {
                    buf2 += ch;
                    final lines2 = buf2.split('\n');
                    buf2 = lines2.last;
                    for (int j = 0; j < lines2.length - 1; j++) {
                      final l = lines2[j].trim();
                      if (l.isEmpty || !l.startsWith('data:')) continue;
                      final d = l.substring(5).trimLeft();
                      if (d == '[DONE]') continue;
                      try {
                        final o = jsonDecode(d);
                        if (o is Map && (o['type'] ?? '') == 'response.output_text.delta') {
                          final delta = (o['delta'] ?? '').toString();
                          if (delta.isNotEmpty) {
                            approxCompletionChars += delta.length;
                            yield ChatStreamChunk(content: delta, isDone: false, totalTokens: 0, usage: usage);
                          }
                        } else if (o is Map && (o['type'] ?? '') == 'response.output_item.added') {
                          final item = o['item'];
                          final idx2 = (o['output_index'] ?? 0) as int;
                          if (item is Map && (item['type'] ?? '') == 'function_call') {
                            respCalls2[idx2] = {
                              'call_id': (item['call_id'] ?? '').toString(),
                              'name': (item['name'] ?? '').toString(),
                              'args': ''
                            };
                          }
                        } else if (o is Map && (o['type'] ?? '') == 'response.function_call_arguments.delta') {
                          final idx2 = (o['output_index'] ?? 0) as int;
                          final delta = (o['delta'] ?? '').toString();
                          final entry = respCalls2.putIfAbsent(idx2, () => {'call_id': '', 'name': '', 'args': ''});
                          if (delta.isNotEmpty) entry['args'] = (entry['args'] ?? '') + delta;
                        } else if (o is Map && (o['type'] ?? '') == 'response.output_item.done') {
                          final item = o['item'];
                          final idx2 = (o['output_index'] ?? 0) as int;
                          if (item is Map && (item['type'] ?? '') == 'function_call') {
                            final args = (item['arguments'] ?? '').toString();
                            final entry = respCalls2.putIfAbsent(idx2, () => {
                                  'call_id': (item['call_id'] ?? '').toString(),
                                  'name': (item['name'] ?? '').toString(),
                                  'args': ''
                                });
                            if (args.isNotEmpty) entry['args'] = args;
                          }
                        } else if (o is Map && (o['type'] ?? '') == 'response.completed') {
                          // usage
                          final u2 = o['response']?['usage'];
                          if (u2 != null) {
                            final inTok = (u2['input_tokens'] ?? 0) as int;
                            final outTok = (u2['output_tokens'] ?? 0) as int;
                            usage = (usage ?? const TokenUsage()).merge(TokenUsage(promptTokens: inTok, completionTokens: outTok));
                            totalTokens = usage!.totalTokens;
                          }
                          // capture output items
                          final out2 = o['response']?['output'];
                          if (out2 is List) {
                            outItems2 = [
                              for (final it in out2)
                                if (it is Map) (it.cast<String, dynamic>())
                            ];
                          }
                        }
                      } catch (_) {}
                    }
                  }

                  if (respCalls2.isEmpty) {
                    // No further tool calls; finalize
                    final approxTotal2 = approxPromptTokens + _approxTokensFromChars(approxCompletionChars);
                    yield ChatStreamChunk(content: '', reasoning: null, isDone: true, totalTokens: usage?.totalTokens ?? approxTotal2, usage: usage);
                    return;
                  }

                  // Execute next round of tool calls
                  final callInfos2 = <ToolCallInfo>[];
                  final msgs2 = <Map<String, dynamic>>[];
                  final sorted2 = respCalls2.keys.toList()..sort();
                  for (final idx2 in sorted2) {
                    final m2 = respCalls2[idx2]!;
                    final callId2 = (m2['call_id'] ?? '').toString();
                    final name2 = (m2['name'] ?? '').toString();
                    Map<String, dynamic> args2;
                    try { args2 = (jsonDecode(m2['args'] ?? '{}') as Map).cast<String, dynamic>(); } catch (_) { args2 = <String, dynamic>{}; }
                    callInfos2.add(ToolCallInfo(id: callId2.isNotEmpty ? callId2 : 'call_$idx2', name: name2, arguments: args2));
                    msgs2.add({'__id': callId2.isNotEmpty ? callId2 : 'call_$idx2', '__name': name2, '__args': args2});
                  }
                  if (callInfos2.isNotEmpty) {
                    final approxTotal = approxPromptTokens + _approxTokensFromChars(approxCompletionChars);
                    yield ChatStreamChunk(content: '', isDone: false, totalTokens: usage?.totalTokens ?? approxTotal, usage: usage, toolCalls: callInfos2);
                  }
                  final resultsInfo2 = <ToolResultInfo>[];
                  final followUpOutputs2 = <Map<String, dynamic>>[];
                  for (final m in msgs2) {
                    final nm = m['__name'] as String;
                    final id2 = m['__id'] as String;
                    final args2 = (m['__args'] as Map<String, dynamic>);
                    final res2 = await onToolCall(nm, args2) ?? '';
                    resultsInfo2.add(ToolResultInfo(id: id2, name: nm, arguments: args2, content: res2));
                    followUpOutputs2.add({'type': 'function_call_output', 'call_id': id2, 'output': res2});
                  }
                  if (resultsInfo2.isNotEmpty) {
                    yield ChatStreamChunk(content: '', isDone: false, totalTokens: usage?.totalTokens ?? 0, usage: usage, toolResults: resultsInfo2);
                  }
                  // Extend current input with this round's model output and our outputs
                  if (outItems2.isNotEmpty) currentInput.addAll(outItems2);
                  currentInput.addAll(followUpOutputs2);
                }

                // Safety
                final approxTotal = approxPromptTokens + _approxTokensFromChars(approxCompletionChars);
                yield ChatStreamChunk(content: '', reasoning: null, isDone: true, totalTokens: usage?.totalTokens ?? approxTotal, usage: usage);
                return;
              }

              final approxTotal = approxPromptTokens + _approxTokensFromChars(approxCompletionChars);
              yield ChatStreamChunk(
                content: '',
                reasoning: null,
                isDone: true,
                totalTokens: usage?.totalTokens ?? approxTotal,
                usage: usage,
              );
              return;
            } else {
              // Fallback for providers that inline output
              final output = json['output'];
              if (output != null) {
                content = (output['content'] ?? '').toString();
                approxCompletionChars += content.length;
                final u = json['usage'];
                if (u != null) {
                  final inTok = (u['input_tokens'] ?? 0) as int;
                  final outTok = (u['output_tokens'] ?? 0) as int;
                  usage = (usage ?? const TokenUsage()).merge(TokenUsage(promptTokens: inTok, completionTokens: outTok));
                  totalTokens = usage!.totalTokens;
                }
              }
            }
          } else {
            // Handle standard OpenAI Chat Completions format
            final choices = json['choices'];
            if (choices != null && choices.isNotEmpty) {
              final c0 = choices[0];
              finishReason = c0['finish_reason'] as String?;
              // if (finishReason != null) {
              //   print('[ChatApi] Received finishReason from choices: $finishReason');
              // }

              // Some providers may include both delta and message.content in SSE chunks.
              // Prioritize delta, then fallback to message.content; merge if both present.
              final message = c0['message'];
              final delta = c0['delta'];

              // 1) Parse delta first
              if (delta != null) {
                // Streaming format: choices[0].delta.content
                final dc = delta['content'];
                String deltaContent = '';
                if (dc is String) {
                  deltaContent = dc;
                } else if (dc is List) {
                  final sb = StringBuffer();
                  for (final it in dc) {
                    if (it is Map) {
                      final t = (it['text'] ?? it['delta'] ?? '') as String? ?? '';
                      if (t.isNotEmpty && (it['type'] == null || it['type'] == 'text')) sb.write(t);
                    }
                  }
                  deltaContent = sb.toString();
                } else {
                  deltaContent = (dc ?? '') as String;
                }
                if (deltaContent.isNotEmpty) {
                  content += deltaContent;
                  approxCompletionChars += deltaContent.length;
                }

                // reasoning_content handling (unchanged)
                final rc = (delta['reasoning_content'] ?? delta['reasoning']) as String?;
                if (rc != null && rc.isNotEmpty) {
                  reasoning = rc;
                  if (needsReasoningEcho) reasoningBuffer += rc;
                }
                if (preserveReasoningDetails) {
                  final rd = delta['reasoning_details'];
                  if (rd is List && rd.isNotEmpty) reasoningDetailsBuffer = rd;
                }

                // images handling from delta (unchanged)
                if (wantsImageOutput) {
                  final List<dynamic> imageItems = <dynamic>[];
                  final imgs = delta['images'];
                  if (imgs is List) imageItems.addAll(imgs);
                  if (dc is List) {
                    for (final it in dc) {
                      if (it is Map && (it['type'] == 'image_url' || it['type'] == 'image')) imageItems.add(it);
                    }
                  }
                  final singleImage = delta['image_url'];
                  if (singleImage is Map || singleImage is String) {
                    imageItems.add({'type': 'image_url', 'image_url': singleImage});
                  }
                  if (imageItems.isNotEmpty) {
                    final buf = StringBuffer();
                    for (final it in imageItems) {
                      if (it is! Map) continue;
                      dynamic iu = it['image_url'];
                      String? url;
                      if (iu is String) {
                        url = iu;
                      } else if (iu is Map) {
                        final u2 = iu['url'];
                        if (u2 is String) url = u2;
                      }
                      if (url != null && url.isNotEmpty) buf.write('\n\n![image](' + url + ')');
                    }
                    if (buf.isNotEmpty) content = content + buf.toString();
                  }
                }

                // tool_calls handling from delta (unchanged)
                final tcs = delta['tool_calls'] as List?;
                if (tcs != null) {
                  for (final t in tcs) {
                    final idx = (t['index'] as int?) ?? 0;
                    final id = t['id'] as String?;
                    final func = t['function'] as Map<String, dynamic>?;
                    final name = func?['name'] as String?;
                    final argsDelta = func?['arguments'] as String?;
                    final entry = toolAcc.putIfAbsent(idx, () => {'id': '', 'name': '', 'args': ''});
                    if (id != null) entry['id'] = id;
                    if (name != null && name.isNotEmpty) entry['name'] = name;
                    if (argsDelta != null && argsDelta.isNotEmpty) entry['args'] = (entry['args'] ?? '') + argsDelta;
                  }
                }
              }

              if (preserveReasoningDetails && message != null) {
                final rdMsg = message['reasoning_details'];
                if (rdMsg is List && rdMsg.isNotEmpty) reasoningDetailsBuffer = rdMsg;
              }

              // 2) Fallback and merge: parse choices[0].message.content
              if (message != null && message['content'] != null) {
                final mc = message['content'];
                String messageContent = '';
                if (mc is String) {
                  messageContent = mc;
                } else if (mc is List) {
                  final sb = StringBuffer();
                  for (final it in mc) {
                    if (it is Map) {
                      final t = (it['text'] ?? '') as String? ?? '';
                      if (t.isNotEmpty && (it['type'] == null || it['type'] == 'text')) sb.write(t);
                    }
                  }
                  messageContent = sb.toString();
                } else {
                  messageContent = (mc ?? '').toString();
                }
                if (messageContent.isNotEmpty) {
                  content += messageContent;
                  approxCompletionChars += messageContent.length;
                }

                // Capture reasoning_content if only present on the message object
                if (message != null) {
                  final rcMsg = message['reasoning_content'] ?? message['reasoning'];
                  if (rcMsg is String && rcMsg.isNotEmpty) {
                    if (needsReasoningEcho) reasoningBuffer += rcMsg;
                    reasoning ??= rcMsg;
                  }
                }

                // images handling from message content (unchanged)
                if (wantsImageOutput && mc is List) {
                  final List<dynamic> imageItems = <dynamic>[];
                  for (final it in mc) {
                    if (it is Map && (it['type'] == 'image_url' || it['type'] == 'image')) imageItems.add(it);
                  }
                  if (imageItems.isNotEmpty) {
                    final buf = StringBuffer();
                    for (final it in imageItems) {
                      if (it is! Map) continue;
                      dynamic iu = it['image_url'];
                      String? url;
                      if (iu is String) {
                        url = iu;
                      } else if (iu is Map) {
                        final u2 = iu['url'];
                        if (u2 is String) url = u2;
                      }
                      if (url != null && url.isNotEmpty) buf.write('\n\n![image](' + url + ')');
                    }
                    if (buf.isNotEmpty) content = content + buf.toString();
                  }
                }
              }
            }
            // XinLiu (iflow.cn) compatibility: tool_calls at root level instead of delta
            final rootToolCalls = json['tool_calls'] as List?;
            if (rootToolCalls != null) {
              // print('[ChatApi/XinLiu] Detected root-level tool_calls, count: ${rootToolCalls.length}, original finishReason: $finishReason');
              // print('[ChatApi/XinLiu] Full JSON keys: ${json.keys.toList()}');
              // print('[ChatApi/XinLiu] Full JSON: ${jsonEncode(json)}');
              for (final t in rootToolCalls) {
                if (t is! Map) continue;
                final id = (t['id'] ?? '').toString();
                final type = (t['type'] ?? 'function').toString();
                if (type != 'function') continue;
                final func = t['function'] as Map<String, dynamic>?;
                if (func == null) continue;
                final name = (func['name'] ?? '').toString();
                final argsStr = (func['arguments'] ?? '').toString();
                if (name.isEmpty) continue;
                // print('[ChatApi/XinLiu] Tool call: id=$id, name=$name, args=${argsStr.length} chars');
                final idx = toolAcc.length;
                final entry = toolAcc.putIfAbsent(idx, () => {'id': id.isEmpty ? 'call_$idx' : id, 'name': name, 'args': argsStr});
                if (id.isNotEmpty) entry['id'] = id;
                entry['name'] = name;
                entry['args'] = argsStr;
              }
              // When root-level tool_calls are present, always treat as tool_calls finish reason
              // (override any other finish_reason from provider)
              if (rootToolCalls.isNotEmpty) {
                // print('[ChatApi/XinLiu] Overriding finishReason from "$finishReason" to "tool_calls"');
                finishReason = 'tool_calls';
              }
            }
            final u = json['usage'];
            if (u != null) {
              final prompt = (u['prompt_tokens'] ?? 0) as int;
              final completion = (u['completion_tokens'] ?? 0) as int;
              final cached = (u['prompt_tokens_details']?['cached_tokens'] ?? 0) as int? ?? 0;
              usage = (usage ?? const TokenUsage()).merge(TokenUsage(promptTokens: prompt, completionTokens: completion, cachedTokens: cached));
              totalTokens = usage!.totalTokens;
            }
          }

          if (content.isNotEmpty || (reasoning != null && reasoning!.isNotEmpty)) {
            final approxTotal = approxPromptTokens + _approxTokensFromChars(approxCompletionChars);
            yield ChatStreamChunk(
              content: content,
              reasoning: reasoning,
              isDone: false,
              totalTokens: totalTokens > 0 ? totalTokens : approxTotal,
              usage: usage,
            );
          }

          // Some providers (e.g., OpenRouter) may omit the [DONE] sentinel
          // and only send finish_reason on the last delta. If we see a
          // definitive finish that's not tool_calls, end the stream now so
          // the UI can persist the message.
          // XinLiu compatibility: Execute tools immediately if we have finish_reason='tool_calls' and accumulated calls
          if (config.useResponseApi != true && finishReason == 'tool_calls' && toolAcc.isNotEmpty && onToolCall != null) {
            // print('[ChatApi/XinLiu] Executing tools immediately (finishReason=tool_calls, toolAcc.size=${toolAcc.length})');
            // Some providers (like XinLiu) return tool_calls with finish_reason='tool_calls' but no [DONE]
            // Execute tools immediately in this case
            final calls = <Map<String, dynamic>>[];
            final callInfos = <ToolCallInfo>[];
            final toolMsgs = <Map<String, dynamic>>[];
            toolAcc.forEach((idx, m) {
              final id = (m['id'] ?? 'call_$idx');
              final name = (m['name'] ?? '');
              Map<String, dynamic> args;
              try { args = (jsonDecode(m['args'] ?? '{}') as Map).cast<String, dynamic>(); } catch (_) { args = <String, dynamic>{}; }
              callInfos.add(ToolCallInfo(id: id, name: name, arguments: args));
              calls.add({
                'id': id,
                'type': 'function',
                'function': {
                  'name': name,
                  'arguments': jsonEncode(args),
                },
              });
              toolMsgs.add({'__name': name, '__id': id, '__args': args});
            });
            if (callInfos.isNotEmpty) {
              final approxTotal = approxPromptTokens + _approxTokensFromChars(approxCompletionChars);
              yield ChatStreamChunk(content: '', isDone: false, totalTokens: usage?.totalTokens ?? approxTotal, usage: usage, toolCalls: callInfos);
            }
            // Execute tools and emit results
            final results = <Map<String, dynamic>>[];
            final resultsInfo = <ToolResultInfo>[];
            for (final m in toolMsgs) {
              final name = m['__name'] as String;
              final id = m['__id'] as String;
              final args = (m['__args'] as Map<String, dynamic>);
              final res = await onToolCall(name, args) ?? '';
              results.add({'tool_call_id': id, 'content': res});
              resultsInfo.add(ToolResultInfo(id: id, name: name, arguments: args, content: res));
            }
            if (resultsInfo.isNotEmpty) {
              yield ChatStreamChunk(content: '', isDone: false, totalTokens: usage?.totalTokens ?? 0, usage: usage, toolResults: resultsInfo);
            }
            // Build follow-up messages
            final mm2 = <Map<String, dynamic>>[];
            for (final m in messages) {
              mm2.add(_copyChatCompletionMessage(m));
            }
            final assistantToolCallMsg = <String, dynamic>{'role': 'assistant', 'content': '\n\n', 'tool_calls': calls};
            if (needsReasoningEcho) {
              assistantToolCallMsg['reasoning_content'] = reasoningBuffer;
            }
            if (preserveReasoningDetails && reasoningDetailsBuffer is List && reasoningDetailsBuffer.isNotEmpty) {
              assistantToolCallMsg['reasoning_details'] = reasoningDetailsBuffer;
            }
            mm2.add(assistantToolCallMsg);
            for (final r in results) {
              final id = r['tool_call_id'];
              final name = calls.firstWhere((c) => c['id'] == id, orElse: () => const {'function': {'name': ''}})['function']['name'];
              mm2.add({'role': 'tool', 'tool_call_id': id, 'name': name, 'content': r['content']});
            }
            // Continue streaming with follow-up request
            var currentMessages = mm2;
            while (true) {
              final Map<String, dynamic> body2 = {
                'model': upstreamModelId,
                'messages': currentMessages,
                'stream': true,
                if (temperature != null) 'temperature': temperature,
                if (topP != null) 'top_p': topP,
                if (isReasoning && effort != 'off' && effort != 'auto') 'reasoning_effort': effort,
                if (tools != null && tools.isNotEmpty) 'tools': _cleanToolsForCompatibility(tools),
                if (tools != null && tools.isNotEmpty) 'tool_choice': 'auto',
              };
              _setMaxTokens(body2);
              final off = _isOff(thinkingBudget);
              if (host.contains('openrouter.ai')) {
                if (isReasoning) {
                  if (off) {
                    body2['reasoning'] = {'enabled': false};
                  } else {
                    final obj = <String, dynamic>{'enabled': true};
                    if (thinkingBudget != null && thinkingBudget > 0) obj['max_tokens'] = thinkingBudget;
                    body2['reasoning'] = obj;
                  }
                  body2.remove('reasoning_effort');
                } else {
                  body2.remove('reasoning');
                  body2.remove('reasoning_effort');
                }
              } else if (host.contains('dashscope') || host.contains('aliyun')) {
                if (isReasoning) {
                  body2['enable_thinking'] = !off;
                  if (!off && thinkingBudget != null && thinkingBudget > 0) {
                    body2['thinking_budget'] = thinkingBudget;
                  } else {
                    body2.remove('thinking_budget');
                  }
                } else {
                  body2.remove('enable_thinking');
                  body2.remove('thinking_budget');
                }
                body2.remove('reasoning_effort');
              } else if (host.contains('open.bigmodel.cn') || host.contains('bigmodel') || isMimo) {
                if (isReasoning) {
                  body2['thinking'] = {'type': off ? 'disabled' : 'enabled'};
                } else {
                  body2.remove('thinking');
                }
                body2.remove('reasoning_effort');
              } else if (host.contains('ark.cn-beijing.volces.com') || host.contains('volc') || host.contains('ark')) {
                if (isReasoning) {
                  body2['thinking'] = {'type': off ? 'disabled' : 'enabled'};
                } else {
                  body2.remove('thinking');
                }
                body2.remove('reasoning_effort');
              } else if (host.contains('intern-ai') || host.contains('intern') || host.contains('chat.intern-ai.org.cn')) {
                if (isReasoning) {
                  body2['thinking_mode'] = !off;
                } else {
                  body2.remove('thinking_mode');
                }
                body2.remove('reasoning_effort');
              } else if (host.contains('siliconflow')) {
                if (isReasoning) {
                  if (off) {
                    body2['enable_thinking'] = false;
                  } else {
                    body2.remove('enable_thinking');
                  }
                } else {
                  body2.remove('enable_thinking');
                }
                body2.remove('reasoning_effort');
              } else if (host.contains('deepseek') || upstreamModelId.toLowerCase().contains('deepseek')) {
                if (isReasoning) {
                  if (off) {
                    body2['reasoning_content'] = false;
                    body2.remove('reasoning_budget');
                  } else {
                    body2['reasoning_content'] = true;
                    if (thinkingBudget != null && thinkingBudget > 0) {
                      body2['reasoning_budget'] = thinkingBudget;
                    } else {
                      body2.remove('reasoning_budget');
                    }
                  }
                } else {
                  body2.remove('reasoning_content');
                  body2.remove('reasoning_budget');
                }
              }
              if (!host.contains('mistral.ai') && !host.contains('openrouter')) {
                body2['stream_options'] = {'include_usage': true};
              }
              if (extraBodyCfg.isNotEmpty) {
                body2.addAll(extraBodyCfg);
              }
              if (extraBody != null && extraBody.isNotEmpty) {
                extraBody.forEach((k, v) {
                  body2[k] = (v is String) ? _parseOverrideValue(v) : v;
                });
              }
              final req2 = http.Request('POST', url);
              final headers2 = <String, String>{
                'Authorization': 'Bearer ${_effectiveApiKey(config)}',
                'Content-Type': 'application/json',
                'Accept': 'text/event-stream',
              };
              headers2.addAll(_customHeaders(config, modelId));
              if (extraHeaders != null && extraHeaders.isNotEmpty) headers2.addAll(extraHeaders);
              req2.headers.addAll(headers2);
              req2.body = jsonEncode(body2);
              final resp2 = await client.send(req2);
              if (resp2.statusCode < 200 || resp2.statusCode >= 300) {
                final errorBody = await resp2.stream.bytesToString();
                throw HttpException('HTTP ${resp2.statusCode}: $errorBody');
              }
              final s2 = resp2.stream.transform(utf8.decoder);
              String buf2 = '';
              final Map<int, Map<String, String>> toolAcc2 = <int, Map<String, String>>{};
              String? finishReason2;
              String contentAccum = '';
              String reasoningAccum = '';
              dynamic reasoningDetailsAccum;
              await for (final ch in s2) {
                buf2 += ch;
                final lines2 = buf2.split('\n');
                buf2 = lines2.last;
                for (int j = 0; j < lines2.length - 1; j++) {
                  final l = lines2[j].trim();
                  if (l.isEmpty || !l.startsWith('data:')) continue;
                  final d = l.substring(5).trimLeft();
                  if (d == '[DONE]') {
                    continue;
                  }
                  try {
                    final o = jsonDecode(d);
                    if (o is Map && o['choices'] is List && (o['choices'] as List).isNotEmpty) {
                      final c0 = (o['choices'] as List).first;
                      finishReason2 = c0['finish_reason'] as String?;
                      final delta = c0['delta'] as Map?;
                      final txt = delta?['content'];
                      final rc = delta?['reasoning_content'] ?? delta?['reasoning'];
                      final u = o['usage'];
                      if (u != null) {
                        final prompt = (u['prompt_tokens'] ?? 0) as int;
                        final completion = (u['completion_tokens'] ?? 0) as int;
                        final cached = (u['prompt_tokens_details']?['cached_tokens'] ?? 0) as int? ?? 0;
                        usage = (usage ?? const TokenUsage()).merge(TokenUsage(promptTokens: prompt, completionTokens: completion, cachedTokens: cached));
                        totalTokens = usage!.totalTokens;
                      }
                      // Capture Grok citations
                      final gCitations = o['citations'];
                      if (gCitations is List && gCitations.isNotEmpty) {
                        final items = <Map<String, dynamic>>[];
                        for (int k = 0; k < gCitations.length; k++) {
                          final u = gCitations[k].toString();
                          items.add({'index': k + 1, 'url': u, 'title': u});
                        }
                        if (items.isNotEmpty) {
                          final payload = jsonEncode({'items': items});
                          yield ChatStreamChunk(
                            content: '',
                            isDone: false,
                            totalTokens: usage?.totalTokens ?? 0,
                            usage: usage,
                            toolResults: [ToolResultInfo(id: 'builtin_search', name: 'search_web', arguments: const <String, dynamic>{}, content: payload)],
                          );
                        }
                      }
                      if (rc is String && rc.isNotEmpty) {
                        if (needsReasoningEcho) reasoningAccum += rc;
                        yield ChatStreamChunk(content: '', reasoning: rc, isDone: false, totalTokens: 0, usage: usage);
                      }
                      if (txt is String && txt.isNotEmpty) {
                        contentAccum += txt;
                        yield ChatStreamChunk(content: txt, isDone: false, totalTokens: 0, usage: usage);
                      }
                      if (wantsImageOutput) {
                        final List<dynamic> imageItems = <dynamic>[];
                        final imgs = delta?['images'];
                        if (imgs is List) imageItems.addAll(imgs);
                        final contentArr = (txt is List) ? txt : (delta?['content'] as List?);
                        if (contentArr is List) {
                          for (final it in contentArr) {
                            if (it is Map && (it['type'] == 'image_url' || it['type'] == 'image')) {
                              imageItems.add(it);
                            }
                          }
                        }
                        final singleImage = delta?['image_url'];
                        if (singleImage is Map || singleImage is String) {
                          imageItems.add({'type': 'image_url', 'image_url': singleImage});
                        }
                        if (imageItems.isNotEmpty) {
                          final buf = StringBuffer();
                          for (final it in imageItems) {
                            if (it is! Map) continue;
                            dynamic iu = it['image_url'];
                            String? url;
                            if (iu is String) {
                              url = iu;
                            } else if (iu is Map) {
                              final u2 = iu['url'];
                              if (u2 is String) url = u2;
                            }
                            if (url != null && url.isNotEmpty) {
                              final md = '\n\n![image](' + url + ')';
                              buf.write(md);
                              contentAccum += md;
                            }
                          }
                          final out = buf.toString();
                          if (out.isNotEmpty) {
                            yield ChatStreamChunk(content: out, isDone: false, totalTokens: 0, usage: usage);
                          }
                        }
                      }
                      final tcs = delta?['tool_calls'] as List?;
                      if (tcs != null) {
                        for (final t in tcs) {
                          final idx = (t['index'] as int?) ?? 0;
                          final id = t['id'] as String?;
                          final func = t['function'] as Map<String, dynamic>?;
                          final name = func?['name'] as String?;
                          final argsDelta = func?['arguments'] as String?;
                          final entry = toolAcc2.putIfAbsent(idx, () => {'id': '', 'name': '', 'args': ''});
                          if (id != null) entry['id'] = id;
                          if (name != null && name.isNotEmpty) entry['name'] = name;
                          if (argsDelta != null && argsDelta.isNotEmpty) entry['args'] = (entry['args'] ?? '') + argsDelta;
                        }
                      }

                      // Fallback/merge: message.content in same chunk (if any)
                      final message = c0['message'] as Map?;
                      if (message != null && message['content'] != null) {
                        final mc = message['content'];
                        if (mc is String && mc.isNotEmpty) {
                          contentAccum += mc;
                          yield ChatStreamChunk(content: mc, isDone: false, totalTokens: 0, usage: usage);
                        }
                      }
                      if (message != null) {
                        final rcMsg = message['reasoning_content'] ?? message['reasoning'];
                        if (rcMsg is String && rcMsg.isNotEmpty && needsReasoningEcho) {
                          reasoningAccum += rcMsg;
                        }
                      }
                      if (preserveReasoningDetails) {
                        final rd = delta?['reasoning_details'];
                        if (rd is List && rd.isNotEmpty) reasoningDetailsAccum = rd;
                        final rdMsg = message?['reasoning_details'];
                        if (rdMsg is List && rdMsg.isNotEmpty) reasoningDetailsAccum = rdMsg;
                      }
                    }
                    // XinLiu compatibility for follow-up requests too
                    final rootToolCalls2 = o['tool_calls'] as List?;
                    if (rootToolCalls2 != null) {
                      for (final t in rootToolCalls2) {
                        if (t is! Map) continue;
                        final id = (t['id'] ?? '').toString();
                        final type = (t['type'] ?? 'function').toString();
                        if (type != 'function') continue;
                        final func = t['function'] as Map<String, dynamic>?;
                        if (func == null) continue;
                        final name = (func['name'] ?? '').toString();
                        final argsStr = (func['arguments'] ?? '').toString();
                        if (name.isEmpty) continue;
                        final idx = toolAcc2.length;
                        final entry = toolAcc2.putIfAbsent(idx, () => {'id': id.isEmpty ? 'call_$idx' : id, 'name': name, 'args': argsStr});
                        if (id.isNotEmpty) entry['id'] = id;
                        entry['name'] = name;
                        entry['args'] = argsStr;
                      }
                      if (rootToolCalls2.isNotEmpty) {
                        finishReason2 = 'tool_calls';
                      }
                    }
                  } catch (_) {}
                }
              }
              if ((finishReason2 == 'tool_calls' || toolAcc2.isNotEmpty) && onToolCall != null) {
                final calls2 = <Map<String, dynamic>>[];
                final callInfos2 = <ToolCallInfo>[];
                final toolMsgs2 = <Map<String, dynamic>>[];
                toolAcc2.forEach((idx, m) {
                  final id = (m['id'] ?? 'call_$idx');
                  final name = (m['name'] ?? '');
                  Map<String, dynamic> args;
                  try { args = (jsonDecode(m['args'] ?? '{}') as Map).cast<String, dynamic>(); } catch (_) { args = <String, dynamic>{}; }
                  callInfos2.add(ToolCallInfo(id: id, name: name, arguments: args));
                  calls2.add({'id': id, 'type': 'function', 'function': {'name': name, 'arguments': jsonEncode(args)}});
                  toolMsgs2.add({'__name': name, '__id': id, '__args': args});
                });
                if (callInfos2.isNotEmpty) {
                  yield ChatStreamChunk(content: '', isDone: false, totalTokens: usage?.totalTokens ?? 0, usage: usage, toolCalls: callInfos2);
                }
                final results2 = <Map<String, dynamic>>[];
                final resultsInfo2 = <ToolResultInfo>[];
                for (final m in toolMsgs2) {
                  final name = m['__name'] as String;
                  final id = m['__id'] as String;
                  final args = (m['__args'] as Map<String, dynamic>);
                  final res = await onToolCall(name, args) ?? '';
                  results2.add({'tool_call_id': id, 'content': res});
                  resultsInfo2.add(ToolResultInfo(id: id, name: name, arguments: args, content: res));
                }
                if (resultsInfo2.isNotEmpty) {
                  yield ChatStreamChunk(content: '', isDone: false, totalTokens: usage?.totalTokens ?? 0, usage: usage, toolResults: resultsInfo2);
                }
                final nextAssistantToolCall = <String, dynamic>{'role': 'assistant', 'content': '\n\n', 'tool_calls': calls2};
                if (needsReasoningEcho) {
                  nextAssistantToolCall['reasoning_content'] = reasoningAccum;
                }
                if (preserveReasoningDetails && reasoningDetailsAccum is List && reasoningDetailsAccum.isNotEmpty) {
                  nextAssistantToolCall['reasoning_details'] = reasoningDetailsAccum;
                }
                currentMessages = [
                  ...currentMessages,
                  if (contentAccum.isNotEmpty) {'role': 'assistant', 'content': contentAccum},
                  nextAssistantToolCall,
                  for (final r in results2)
                    {
                      'role': 'tool',
                      'tool_call_id': r['tool_call_id'],
                      'name': calls2.firstWhere((c) => c['id'] == r['tool_call_id'], orElse: () => const {'function': {'name': ''}})['function']['name'],
                      'content': r['content'],
                    },
                ];
                continue;
              } else {
                final approxTotal = approxPromptTokens + _approxTokensFromChars(approxCompletionChars);
                yield ChatStreamChunk(content: '', isDone: true, totalTokens: usage?.totalTokens ?? approxTotal, usage: usage);
                return;
              }
            }
          }
          // XinLiu compatibility: Don't end early if we have accumulated tool calls
          if (config.useResponseApi != true && finishReason != null && finishReason != 'tool_calls') {
            final bool hasPendingToolCalls = toolAcc.isNotEmpty || toolAccResp.isNotEmpty;
            if (hasPendingToolCalls) {
              // Some providers (like XinLiu/iflow.cn) may return tool_calls with finish_reason='stop'
              // and may not send a [DONE] marker. Execute tools immediately in this case.
              if (onToolCall != null && toolAcc.isNotEmpty) {
                final calls = <Map<String, dynamic>>[];
                final callInfos = <ToolCallInfo>[];
                final toolMsgs = <Map<String, dynamic>>[];
                toolAcc.forEach((idx, m) {
                  final id = (m['id'] ?? 'call_$idx');
                  final name = (m['name'] ?? '');
                  Map<String, dynamic> args;
                  try { args = (jsonDecode(m['args'] ?? '{}') as Map).cast<String, dynamic>(); } catch (_) { args = <String, dynamic>{}; }
                  callInfos.add(ToolCallInfo(id: id, name: name, arguments: args));
                  calls.add({
                    'id': id,
                    'type': 'function',
                    'function': {
                      'name': name,
                      'arguments': jsonEncode(args),
                    },
                  });
                  toolMsgs.add({'__name': name, '__id': id, '__args': args});
                });
                if (callInfos.isNotEmpty) {
                  final approxTotal = approxPromptTokens + _approxTokensFromChars(approxCompletionChars);
                  yield ChatStreamChunk(content: '', isDone: false, totalTokens: usage?.totalTokens ?? approxTotal, usage: usage, toolCalls: callInfos);
                }
                // Execute tools and emit results
                final results = <Map<String, dynamic>>[];
                final resultsInfo = <ToolResultInfo>[];
                for (final m in toolMsgs) {
                  final name = m['__name'] as String;
                  final id = m['__id'] as String;
                  final args = (m['__args'] as Map<String, dynamic>);
                  final res = await onToolCall(name, args) ?? '';
                  results.add({'tool_call_id': id, 'content': res});
                  resultsInfo.add(ToolResultInfo(id: id, name: name, arguments: args, content: res));
                }
                if (resultsInfo.isNotEmpty) {
                  yield ChatStreamChunk(content: '', isDone: false, totalTokens: usage?.totalTokens ?? 0, usage: usage, toolResults: resultsInfo);
                }
                // Build follow-up messages
                final mm2 = <Map<String, dynamic>>[];
                for (final m in messages) {
                  mm2.add(_copyChatCompletionMessage(m));
                }
                final assistantToolCallMsg = <String, dynamic>{'role': 'assistant', 'content': '\n\n', 'tool_calls': calls};
                if (needsReasoningEcho) {
                  assistantToolCallMsg['reasoning_content'] = reasoningBuffer;
                }
                if (preserveReasoningDetails && reasoningDetailsBuffer is List && reasoningDetailsBuffer.isNotEmpty) {
                  assistantToolCallMsg['reasoning_details'] = reasoningDetailsBuffer;
                }
                mm2.add(assistantToolCallMsg);
                for (final r in results) {
                  final id = r['tool_call_id'];
                  final name = calls.firstWhere((c) => c['id'] == id, orElse: () => const {'function': {'name': ''}})['function']['name'];
                  mm2.add({'role': 'tool', 'tool_call_id': id, 'name': name, 'content': r['content']});
                }
                // Continue streaming with follow-up request - reuse existing multi-round logic from [DONE] handler
                var currentMessages = mm2;
                while (true) {
                  final Map<String, dynamic> body2 = {
                    'model': upstreamModelId,
                    'messages': currentMessages,
                    'stream': true,
                    if (temperature != null) 'temperature': temperature,
                    if (topP != null) 'top_p': topP,
                    if (isReasoning && effort != 'off' && effort != 'auto') 'reasoning_effort': effort,
                    if (tools != null && tools.isNotEmpty) 'tools': _cleanToolsForCompatibility(tools),
                    if (tools != null && tools.isNotEmpty) 'tool_choice': 'auto',
                  };
                  _setMaxTokens(body2);
                  final off = _isOff(thinkingBudget);
                  if (host.contains('openrouter.ai')) {
                    if (isReasoning) {
                      if (off) {
                        body2['reasoning'] = {'enabled': false};
                      } else {
                        final obj = <String, dynamic>{'enabled': true};
                        if (thinkingBudget != null && thinkingBudget > 0) obj['max_tokens'] = thinkingBudget;
                        body2['reasoning'] = obj;
                      }
                      body2.remove('reasoning_effort');
                    } else {
                      body2.remove('reasoning');
                      body2.remove('reasoning_effort');
                    }
                  } else if (host.contains('dashscope') || host.contains('aliyun')) {
                    if (isReasoning) {
                      body2['enable_thinking'] = !off;
                      if (!off && thinkingBudget != null && thinkingBudget > 0) {
                        body2['thinking_budget'] = thinkingBudget;
                      } else {
                        body2.remove('thinking_budget');
                      }
                    } else {
                      body2.remove('enable_thinking');
                      body2.remove('thinking_budget');
                    }
                    body2.remove('reasoning_effort');
                  } else if (host.contains('ark.cn-beijing.volces.com') || host.contains('volc') || host.contains('ark') || isMimo) {
                    if (isReasoning) {
                      body2['thinking'] = {'type': off ? 'disabled' : 'enabled'};
                    } else {
                      body2.remove('thinking');
                    }
                    body2.remove('reasoning_effort');
                  } else if (host.contains('intern-ai') || host.contains('intern') || host.contains('chat.intern-ai.org.cn')) {
                    if (isReasoning) {
                      body2['thinking_mode'] = !off;
                    } else {
                      body2.remove('thinking_mode');
                    }
                    body2.remove('reasoning_effort');
                  } else if (host.contains('siliconflow')) {
                    if (isReasoning) {
                      if (off) {
                        body2['enable_thinking'] = false;
                      } else {
                        body2.remove('enable_thinking');
                      }
                    } else {
                      body2.remove('enable_thinking');
                    }
                    body2.remove('reasoning_effort');
                  } else if (host.contains('deepseek') || upstreamModelId.toLowerCase().contains('deepseek')) {
                    if (isReasoning) {
                      if (off) {
                        body2['reasoning_content'] = false;
                        body2.remove('reasoning_budget');
                      } else {
                        body2['reasoning_content'] = true;
                        if (thinkingBudget != null && thinkingBudget > 0) {
                          body2['reasoning_budget'] = thinkingBudget;
                        } else {
                          body2.remove('reasoning_budget');
                        }
                      }
                    } else {
                      body2.remove('reasoning_content');
                      body2.remove('reasoning_budget');
                    }
                  }
                  if (!host.contains('mistral.ai') && !host.contains('openrouter')) {
                    body2['stream_options'] = {'include_usage': true};
                  }
                  if (extraBodyCfg.isNotEmpty) {
                    body2.addAll(extraBodyCfg);
                  }
                  if (extraBody != null && extraBody.isNotEmpty) {
                    extraBody.forEach((k, v) {
                      body2[k] = (v is String) ? _parseOverrideValue(v) : v;
                    });
                  }
                  final req2 = http.Request('POST', url);
                  final headers2 = <String, String>{
                    'Authorization': 'Bearer ${_effectiveApiKey(config)}',
                    'Content-Type': 'application/json',
                    'Accept': 'text/event-stream',
                  };
                  headers2.addAll(_customHeaders(config, modelId));
                  if (extraHeaders != null && extraHeaders.isNotEmpty) headers2.addAll(extraHeaders);
                  req2.headers.addAll(headers2);
                  req2.body = jsonEncode(body2);
                  final resp2 = await client.send(req2);
                  if (resp2.statusCode < 200 || resp2.statusCode >= 300) {
                    final errorBody = await resp2.stream.bytesToString();
                    throw HttpException('HTTP ${resp2.statusCode}: $errorBody');
                  }
                  final s2 = resp2.stream.transform(utf8.decoder);
                  String buf2 = '';
                  final Map<int, Map<String, String>> toolAcc2 = <int, Map<String, String>>{};
                  String? finishReason2;
                  String contentAccum = '';
                  String reasoningAccum = '';
                  dynamic reasoningDetailsAccum;
                  await for (final ch in s2) {
                    buf2 += ch;
                    final lines2 = buf2.split('\n');
                    buf2 = lines2.last;
                    for (int j = 0; j < lines2.length - 1; j++) {
                      final l = lines2[j].trim();
                      if (l.isEmpty || !l.startsWith('data:')) continue;
                      final d = l.substring(5).trimLeft();
                      if (d == '[DONE]') {
                        continue;
                      }
                      try {
                        final o = jsonDecode(d);
                        if (o is Map && o['choices'] is List && (o['choices'] as List).isNotEmpty) {
                          final c0 = (o['choices'] as List).first;
                          finishReason2 = c0['finish_reason'] as String?;
                          final delta = c0['delta'] as Map?;
                          final txt = delta?['content'];
                          final rc = delta?['reasoning_content'] ?? delta?['reasoning'];
                          final u = o['usage'];
                          if (u != null) {
                            final prompt = (u['prompt_tokens'] ?? 0) as int;
                            final completion = (u['completion_tokens'] ?? 0) as int;
                            final cached = (u['prompt_tokens_details']?['cached_tokens'] ?? 0) as int? ?? 0;
                            usage = (usage ?? const TokenUsage()).merge(TokenUsage(promptTokens: prompt, completionTokens: completion, cachedTokens: cached));
                            totalTokens = usage!.totalTokens;
                          }
                          if (rc is String && rc.isNotEmpty) {
                            if (needsReasoningEcho) reasoningAccum += rc;
                            yield ChatStreamChunk(content: '', reasoning: rc, isDone: false, totalTokens: 0, usage: usage);
                          }
                          if (txt is String && txt.isNotEmpty) {
                            contentAccum += txt;
                            yield ChatStreamChunk(content: txt, isDone: false, totalTokens: 0, usage: usage);
                          }
                          if (wantsImageOutput) {
                            final List<dynamic> imageItems = <dynamic>[];
                            final imgs = delta?['images'];
                            if (imgs is List) imageItems.addAll(imgs);
                            final contentArr = (txt is List) ? txt : (delta?['content'] as List?);
                            if (contentArr is List) {
                              for (final it in contentArr) {
                                if (it is Map && (it['type'] == 'image_url' || it['type'] == 'image')) {
                                  imageItems.add(it);
                                }
                              }
                            }
                            final singleImage = delta?['image_url'];
                            if (singleImage is Map || singleImage is String) {
                              imageItems.add({'type': 'image_url', 'image_url': singleImage});
                            }
                            if (imageItems.isNotEmpty) {
                              final buf = StringBuffer();
                              for (final it in imageItems) {
                                if (it is! Map) continue;
                                dynamic iu = it['image_url'];
                                String? url;
                                if (iu is String) {
                                  url = iu;
                                } else if (iu is Map) {
                                  final u2 = iu['url'];
                                  if (u2 is String) url = u2;
                                }
                                if (url != null && url.isNotEmpty) {
                                  final md = '\n\n![image](' + url + ')';
                                  buf.write(md);
                                  contentAccum += md;
                                }
                              }
                              final out = buf.toString();
                              if (out.isNotEmpty) {
                                yield ChatStreamChunk(content: out, isDone: false, totalTokens: 0, usage: usage);
                              }
                            }
                          }
                          final tcs = delta?['tool_calls'] as List?;
                          if (tcs != null) {
                            for (final t in tcs) {
                              final idx = (t['index'] as int?) ?? 0;
                              final id = t['id'] as String?;
                              final func = t['function'] as Map<String, dynamic>?;
                              final name = func?['name'] as String?;
                              final argsDelta = func?['arguments'] as String?;
                              final entry = toolAcc2.putIfAbsent(idx, () => {'id': '', 'name': '', 'args': ''});
                              if (id != null) entry['id'] = id;
                              if (name != null && name.isNotEmpty) entry['name'] = name;
                              if (argsDelta != null && argsDelta.isNotEmpty) entry['args'] = (entry['args'] ?? '') + argsDelta;
                            }
                          }

                          // Fallback/merge: message.content in same chunk (if any)
                          final message = c0['message'] as Map?;
                          if (message != null && message['content'] != null) {
                            final mc = message['content'];
                            if (mc is String && mc.isNotEmpty) {
                              contentAccum += mc;
                              yield ChatStreamChunk(content: mc, isDone: false, totalTokens: 0, usage: usage);
                            }
                          }
                          if (message != null) {
                            final rcMsg = message['reasoning_content'] ?? message['reasoning'];
                            if (rcMsg is String && rcMsg.isNotEmpty && needsReasoningEcho) {
                              reasoningAccum += rcMsg;
                            }
                          }
                          if (preserveReasoningDetails) {
                            final rd = delta?['reasoning_details'];
                            if (rd is List && rd.isNotEmpty) reasoningDetailsAccum = rd;
                            final rdMsg = message?['reasoning_details'];
                            if (rdMsg is List && rdMsg.isNotEmpty) reasoningDetailsAccum = rdMsg;
                          }
                        }
                        // XinLiu compatibility for follow-up requests too
                        final rootToolCalls2 = o['tool_calls'] as List?;
                        if (rootToolCalls2 != null) {
                          for (final t in rootToolCalls2) {
                            if (t is! Map) continue;
                            final id = (t['id'] ?? '').toString();
                            final type = (t['type'] ?? 'function').toString();
                            if (type != 'function') continue;
                            final func = t['function'] as Map<String, dynamic>?;
                            if (func == null) continue;
                            final name = (func['name'] ?? '').toString();
                            final argsStr = (func['arguments'] ?? '').toString();
                            if (name.isEmpty) continue;
                            final idx = toolAcc2.length;
                            final entry = toolAcc2.putIfAbsent(idx, () => {'id': id.isEmpty ? 'call_$idx' : id, 'name': name, 'args': argsStr});
                            if (id.isNotEmpty) entry['id'] = id;
                            entry['name'] = name;
                            entry['args'] = argsStr;
                          }
                          if (rootToolCalls2.isNotEmpty && finishReason2 == null) {
                            finishReason2 = 'tool_calls';
                          }
                        }
                      } catch (_) {}
                    }
                  }
                  if ((finishReason2 == 'tool_calls' || toolAcc2.isNotEmpty) && onToolCall != null) {
                    final calls2 = <Map<String, dynamic>>[];
                    final callInfos2 = <ToolCallInfo>[];
                    final toolMsgs2 = <Map<String, dynamic>>[];
                    toolAcc2.forEach((idx, m) {
                      final id = (m['id'] ?? 'call_$idx');
                      final name = (m['name'] ?? '');
                      Map<String, dynamic> args;
                      try { args = (jsonDecode(m['args'] ?? '{}') as Map).cast<String, dynamic>(); } catch (_) { args = <String, dynamic>{}; }
                      callInfos2.add(ToolCallInfo(id: id, name: name, arguments: args));
                      calls2.add({'id': id, 'type': 'function', 'function': {'name': name, 'arguments': jsonEncode(args)}});
                      toolMsgs2.add({'__name': name, '__id': id, '__args': args});
                    });
                    if (callInfos2.isNotEmpty) {
                      yield ChatStreamChunk(content: '', isDone: false, totalTokens: usage?.totalTokens ?? 0, usage: usage, toolCalls: callInfos2);
                    }
                    final results2 = <Map<String, dynamic>>[];
                    final resultsInfo2 = <ToolResultInfo>[];
                    for (final m in toolMsgs2) {
                      final name = m['__name'] as String;
                      final id = m['__id'] as String;
                      final args = (m['__args'] as Map<String, dynamic>);
                      final res = await onToolCall(name, args) ?? '';
                      results2.add({'tool_call_id': id, 'content': res});
                      resultsInfo2.add(ToolResultInfo(id: id, name: name, arguments: args, content: res));
                    }
                    if (resultsInfo2.isNotEmpty) {
                      yield ChatStreamChunk(content: '', isDone: false, totalTokens: usage?.totalTokens ?? 0, usage: usage, toolResults: resultsInfo2);
                    }
                    final nextAssistantToolCall = <String, dynamic>{'role': 'assistant', 'content': '\n\n', 'tool_calls': calls2};
                    if (needsReasoningEcho) {
                      nextAssistantToolCall['reasoning_content'] = reasoningAccum;
                    }
                    if (preserveReasoningDetails && reasoningDetailsAccum is List && reasoningDetailsAccum.isNotEmpty) {
                      nextAssistantToolCall['reasoning_details'] = reasoningDetailsAccum;
                    }
                    currentMessages = [
                      ...currentMessages,
                      if (contentAccum.isNotEmpty) {'role': 'assistant', 'content': contentAccum},
                      nextAssistantToolCall,
                      for (final r in results2)
                        {
                          'role': 'tool',
                          'tool_call_id': r['tool_call_id'],
                          'name': calls2.firstWhere((c) => c['id'] == r['tool_call_id'], orElse: () => const {'function': {'name': ''}})['function']['name'],
                          'content': r['content'],
                        },
                    ];
                    continue;
                  } else {
                    final approxTotal = approxPromptTokens + _approxTokensFromChars(approxCompletionChars);
                    yield ChatStreamChunk(content: '', isDone: true, totalTokens: usage?.totalTokens ?? approxTotal, usage: usage);
                    return;
                  }
                }
              }
            } else if (host.contains('openrouter.ai')) {
            } else {
              // final approxTotal = approxPromptTokens + _approxTokensFromChars(approxCompletionChars);
              // yield ChatStreamChunk(
              //   content: '',
              //   isDone: false,
              //   totalTokens: usage?.totalTokens ?? approxTotal,
              //   usage: usage,
              // );
              // return;
            }
          }

          // If model finished with tool_calls, execute them and follow-up
          if (false && config.useResponseApi != true && finishReason == 'tool_calls' && onToolCall != null) {
            // Build messages for follow-up
            final calls = <Map<String, dynamic>>[];
            // Emit UI tool call placeholders
            final callInfos = <ToolCallInfo>[];
            final toolMsgs = <Map<String, dynamic>>[];
            toolAcc.forEach((idx, m) {
              final id = (m['id'] ?? 'call_$idx');
              final name = (m['name'] ?? '');
              Map<String, dynamic> args;
              try {
                args = (jsonDecode(m['args'] ?? '{}') as Map).cast<String, dynamic>();
              } catch (_) {
                args = <String, dynamic>{};
              }
              callInfos.add(ToolCallInfo(id: id, name: name, arguments: args));
              calls.add({
                'id': id,
                'type': 'function',
                'function': {
                  'name': name,
                  'arguments': jsonEncode(args),
                },
              });
              toolMsgs.add({'__name': name, '__id': id, '__args': args});
            });

            if (callInfos.isNotEmpty) {
              yield ChatStreamChunk(content: '', isDone: false, totalTokens: usage?.totalTokens ?? 0, usage: usage, toolCalls: callInfos);
            }

            // Execute tools
            final results = <Map<String, dynamic>>[];
            final resultsInfo = <ToolResultInfo>[];
            for (final m in toolMsgs) {
              final name = m['__name'] as String;
              final id = m['__id'] as String;
              final args = (m['__args'] as Map<String, dynamic>);
              final res = await onToolCall(name, args) ?? '';
              results.add({'tool_call_id': id, 'content': res});
              resultsInfo.add(ToolResultInfo(id: id, name: name, arguments: args, content: res));
            }

            if (resultsInfo.isNotEmpty) {
              yield ChatStreamChunk(content: '', isDone: false, totalTokens: usage?.totalTokens ?? 0, usage: usage, toolResults: resultsInfo);
            }

            // Follow-up request with assistant tool_calls + tool messages
            final mm2 = <Map<String, dynamic>>[];
            for (final m in messages) {
              mm2.add(_copyChatCompletionMessage(m));
            }
            final assistantToolCallMsg = <String, dynamic>{'role': 'assistant', 'content': '\n\n', 'tool_calls': calls};
            if (needsReasoningEcho) {
              assistantToolCallMsg['reasoning_content'] = reasoningBuffer;
            }
            mm2.add(assistantToolCallMsg);
            for (final r in results) {
              final id = r['tool_call_id'];
              final name = calls.firstWhere((c) => c['id'] == id, orElse: () => const {'function': {'name': ''}})['function']['name'];
              mm2.add({'role': 'tool', 'tool_call_id': id, 'name': name, 'content': r['content']});
            }

            final Map<String, dynamic> body2 = {
              'model': upstreamModelId,
              'messages': mm2,
              'stream': true,
              if (tools != null && tools.isNotEmpty) 'tools': _cleanToolsForCompatibility(tools),
              if (tools != null && tools.isNotEmpty) 'tool_choice': 'auto',
            };

            final request2 = http.Request('POST', url);
            request2.headers.addAll({
              'Authorization': 'Bearer ${_apiKeyForRequest(config, modelId)}',
              'Content-Type': 'application/json',
              'Accept': 'text/event-stream',
            });
            request2.body = jsonEncode(body2);
            final resp2 = await client.send(request2);
            if (resp2.statusCode < 200 || resp2.statusCode >= 300) {
              final errorBody = await resp2.stream.bytesToString();
              throw HttpException('HTTP ${resp2.statusCode}: $errorBody');
            }
            final s2 = resp2.stream.transform(utf8.decoder);
            String buf2 = '';
            await for (final ch in s2) {
              buf2 += ch;
              final lines2 = buf2.split('\n');
              buf2 = lines2.last;
              for (int j = 0; j < lines2.length - 1; j++) {
                final l = lines2[j].trim();
                if (l.isEmpty || !l.startsWith('data:')) continue;
                final d = l.substring(5).trimLeft();
                if (d == '[DONE]') {
                  yield ChatStreamChunk(content: '', isDone: true, totalTokens: usage?.totalTokens ?? 0, usage: usage);
                  return;
                }
                try {
                  final o = jsonDecode(d);
                  if (o is Map && o['choices'] is List && (o['choices'] as List).isNotEmpty) {
                    final first = (o['choices'] as List).first as Map?;
                    final delta = first?['delta'] as Map?;
                    final message = first?['message'] as Map?;
                    final txt = delta?['content'];
                    final rc = delta?['reasoning_content'] ?? delta?['reasoning'];
                    if (rc is String && rc.isNotEmpty) {
                      yield ChatStreamChunk(content: '', reasoning: rc, isDone: false, totalTokens: 0, usage: usage);
                    }
                    if (txt is String && txt.isNotEmpty) {
                      yield ChatStreamChunk(content: txt, isDone: false, totalTokens: 0, usage: usage);
                    }
                    if (message != null && message['content'] is String && (message['content'] as String).isNotEmpty) {
                      yield ChatStreamChunk(content: message['content'] as String, isDone: false, totalTokens: 0, usage: usage);
                    }
                  }
                } catch (_) {}
              }
            }
            return;
          }
        } catch (e) {
          // Skip malformed JSON
        }
      }
    }

    // Fallback: provider closed SSE without sending [DONE]
    final approxTotal = usage?.totalTokens ?? (approxPromptTokens + _approxTokensFromChars(approxCompletionChars));
    yield ChatStreamChunk(content: '', isDone: true, totalTokens: approxTotal, usage: usage);
  }

  static Stream<ChatStreamChunk> _sendClaudeStream(
      http.Client client,
      ProviderConfig config,
      String modelId,
      List<Map<String, dynamic>> messages,
      {List<String>? userImagePaths, int? thinkingBudget, double? temperature, double? topP, int? maxTokens, List<Map<String, dynamic>>? tools, Future<String> Function(String, Map<String, dynamic>)? onToolCall, Map<String, String>? extraHeaders, Map<String, dynamic>? extraBody, bool stream = true}
      ) async* {
    final upstreamModelId = _apiModelId(config, modelId);
    // Endpoint and headers (constant across rounds)
    final base = config.baseUrl.endsWith('/')
        ? config.baseUrl.substring(0, config.baseUrl.length - 1)
        : config.baseUrl;
    final url = Uri.parse('$base/messages');

    final isReasoning = _effectiveModelInfo(config, modelId)
        .abilities
        .contains(ModelAbility.reasoning);

    // Extract system prompt (Anthropic uses top-level `system`)
    String systemPrompt = '';
    final nonSystemMessages = <Map<String, dynamic>>[];
    for (final m in messages) {
      final role = (m['role'] ?? '').toString();
      if (role == 'system') {
        final s = (m['content'] ?? '').toString();
        if (s.isNotEmpty) {
          systemPrompt = systemPrompt.isEmpty ? s : (systemPrompt + '\n\n' + s);
        }
        continue;
      }
      nonSystemMessages.add({'role': role.isEmpty ? 'user' : role, 'content': m['content'] ?? ''});
    }

    // Transform last user message to include images per Anthropic schema
    final initialMessages = <Map<String, dynamic>>[];
    for (int i = 0; i < nonSystemMessages.length; i++) {
      final m = nonSystemMessages[i];
      final isLast = i == nonSystemMessages.length - 1;
      if (isLast && (userImagePaths?.isNotEmpty == true) && (m['role'] == 'user')) {
        final parts = <Map<String, dynamic>>[];
        final text = (m['content'] ?? '').toString();
        if (text.isNotEmpty) parts.add({'type': 'text', 'text': text});
        for (final p in userImagePaths!) {
          if (p.startsWith('http') || p.startsWith('data:')) {
            parts.add({'type': 'text', 'text': p});
          } else {
            final mime = _mimeFromPath(p);
            final b64 = await _encodeBase64File(p, withPrefix: false);
            parts.add({
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': mime,
                'data': b64,
              }
            });
          }
        }
        initialMessages.add({'role': 'user', 'content': parts});
      } else {
        initialMessages.add({'role': m['role'] ?? 'user', 'content': m['content'] ?? ''});
      }
    }

    // Map OpenAI-style tools to Anthropic custom tools (client tools)
    List<Map<String, dynamic>>? anthropicTools;
    if (tools != null && tools.isNotEmpty) {
      anthropicTools = [];
      for (final t in tools) {
        final fn = (t['function'] as Map<String, dynamic>?);
        if (fn == null) continue;
        final name = (fn['name'] ?? '').toString();
        if (name.isEmpty) continue;
        final desc = (fn['description'] ?? '').toString();
        final params = (fn['parameters'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{'type': 'object'};
        anthropicTools.add({
          'name': name,
          if (desc.isNotEmpty) 'description': desc,
          'input_schema': params,
        });
      }
    }

    // Collect final tools list: client + server + built-in web_search
    final List<Map<String, dynamic>> allTools = [];
    if (anthropicTools != null && anthropicTools.isNotEmpty) allTools.addAll(anthropicTools);
    if (tools != null && tools.isNotEmpty) {
      for (final t in tools) {
        if (t is Map && t['type'] is String && (t['type'] as String).startsWith('web_search_')) {
          allTools.add(t);
        }
      }
    }
    final builtIns = _builtInTools(config, modelId);
    if (builtIns.contains(BuiltInToolNames.search)) {
      Map<String, dynamic> ws = const <String, dynamic>{};
      try {
        final ov = config.modelOverrides[modelId];
        if (ov is Map && ov['webSearch'] is Map) {
          ws = (ov['webSearch'] as Map).cast<String, dynamic>();
        }
      } catch (_) {}
      final entry = <String, dynamic>{
        'type': 'web_search_20250305',
        'name': 'web_search',
      };
      if (ws['max_uses'] is int && (ws['max_uses'] as int) > 0) entry['max_uses'] = ws['max_uses'];
      if (ws['allowed_domains'] is List) entry['allowed_domains'] = List<String>.from((ws['allowed_domains'] as List).map((e) => e.toString()));
      if (ws['blocked_domains'] is List) entry['blocked_domains'] = List<String>.from((ws['blocked_domains'] as List).map((e) => e.toString()));
      if (ws['user_location'] is Map) entry['user_location'] = (ws['user_location'] as Map).cast<String, dynamic>();
      allTools.add(entry);
    }

    // Headers (constant across rounds)
    final baseHeaders = <String, String>{
      'x-api-key': _effectiveApiKey(config),
      'anthropic-version': '2023-06-01',
      'Content-Type': 'application/json',
      'Accept': stream ? 'text/event-stream' : 'application/json',
    };
    baseHeaders.addAll(_customHeaders(config, modelId));
    if (extraHeaders != null && extraHeaders.isNotEmpty) baseHeaders.addAll(extraHeaders);

    // Running conversation across rounds
    List<Map<String, dynamic>> convo = List<Map<String, dynamic>>.from(initialMessages);
    TokenUsage? totalUsage;

    while (true) {
      // Prepare request body per round
      final body = <String, dynamic>{
        'model': upstreamModelId,
        'max_tokens': maxTokens ?? 64000,
        'messages': convo,
        'stream': stream,
        if (systemPrompt.isNotEmpty) 'system': systemPrompt,
        if (temperature != null) 'temperature': temperature,
        if (topP != null) 'top_p': topP,
        if (allTools.isNotEmpty) 'tools': allTools,
        if (allTools.isNotEmpty) 'tool_choice': {'type': 'auto'},
        if (isReasoning)
          'thinking': {
            'type': (thinkingBudget == 0) ? 'disabled' : 'enabled',
            if (thinkingBudget != null && thinkingBudget > 0)
              'budget_tokens': thinkingBudget,
          },
      };
      final extraClaude = _customBody(config, modelId);
      if (extraClaude.isNotEmpty) (body as Map<String, dynamic>).addAll(extraClaude);
      if (extraBody != null && extraBody.isNotEmpty) {
        extraBody.forEach((k, v) {
          (body as Map<String, dynamic>)[k] = (v is String) ? _parseOverrideValue(v) : v;
        });
      }

      final request = http.Request('POST', url);
      request.headers.addAll(baseHeaders);
      request.body = jsonEncode(body);

      final response = await client.send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final errorBody = await response.stream.bytesToString();
        throw HttpException('HTTP ${response.statusCode}: $errorBody');
      }

      // Non-streaming path: parse full JSON, handle tool_use, then continue loop if needed.
      if (!stream) {
        final txt = await response.stream.bytesToString();
        final obj = jsonDecode(txt) as Map;
        // Usage
        try {
          final u = (obj['usage'] as Map?)?.cast<String, dynamic>();
          if (u != null) {
            final inTok = (u['input_tokens'] ?? 0) as int? ?? 0;
            final outTok = (u['output_tokens'] ?? 0) as int? ?? 0;
            final round = TokenUsage(promptTokens: inTok, completionTokens: outTok, cachedTokens: 0, totalTokens: inTok + outTok);
            totalUsage = (totalUsage ?? const TokenUsage()).merge(round);
          }
        } catch (_) {}
        final content = (obj['content'] as List?) ?? const <dynamic>[];
        final List<Map<String, dynamic>> assistantBlocks = <Map<String, dynamic>>[];
        final Map<String, Map<String, dynamic>> toolUses = <String, Map<String, dynamic>>{}; // id -> {name,args}
        final buf = StringBuffer();
        for (final it in content) {
          if (it is! Map) continue;
          final type = (it['type'] ?? '').toString();
          if (type == 'text') {
            final t = (it['text'] ?? '').toString();
            if (t.isNotEmpty) { assistantBlocks.add({'type': 'text', 'text': t}); buf.write(t); }
          } else if (type == 'thinking' || type == 'redacted_thinking') {
            // Preserve thinking blocks unmodified for tool-use continuation.
            // When thinking is enabled, the next request must include the last assistant
            // message starting with a thinking/redacted_thinking block.
            try {
              assistantBlocks.add(Map<String, dynamic>.from(it.cast<String, dynamic>()));
            } catch (_) {}
          } else if (type == 'tool_use') {
            final id = (it['id'] ?? '').toString();
            final name = (it['name'] ?? '').toString();
            final args = (it['input'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
            if (id.isNotEmpty) {
              toolUses[id] = {'name': name, 'args': args};
              assistantBlocks.add({'type': 'tool_use', 'id': id, 'name': name, 'input': args});
            }
          }
        }
        if (toolUses.isNotEmpty && onToolCall != null) {
          final callInfos = <ToolCallInfo>[];
          for (final e in toolUses.entries) {
            callInfos.add(ToolCallInfo(id: e.key, name: (e.value['name'] ?? '').toString(), arguments: (e.value['args'] as Map<String, dynamic>)));
          }
          yield ChatStreamChunk(content: '', isDone: false, totalTokens: (totalUsage?.totalTokens ?? 0), usage: totalUsage, toolCalls: callInfos);
          final results = <Map<String, dynamic>>[];
          final resultsInfo = <ToolResultInfo>[];
          for (final e in toolUses.entries) {
            final name = (e.value['name'] ?? '').toString();
            final args = (e.value['args'] as Map<String, dynamic>);
            final res = await onToolCall(name, args) ?? '';
            results.add({'type': 'tool_result', 'tool_use_id': e.key, 'content': res});
            resultsInfo.add(ToolResultInfo(id: e.key, name: name, arguments: args, content: res));
          }
          if (resultsInfo.isNotEmpty) {
            yield ChatStreamChunk(content: '', isDone: false, totalTokens: (totalUsage?.totalTokens ?? 0), usage: totalUsage, toolResults: resultsInfo);
          }
          // Extend convo: assistant + user tool_result, loop
          final assistantMsg = {'role': 'assistant', 'content': assistantBlocks};
          final userToolMsg = {'role': 'user', 'content': results};
          convo = [...convo, assistantMsg, userToolMsg];
          continue; // next round
        }
        // No tool use -> return final text
        yield ChatStreamChunk(content: buf.toString(), isDone: true, totalTokens: (totalUsage?.totalTokens ?? 0), usage: totalUsage);
        return;
      }

      final sse = response.stream.transform(utf8.decoder);
      String buffer = '';
      int roundTokens = 0;
      TokenUsage? usage;
      String? _lastStopReason;

      // Per-round accumulation
      final Map<String, Map<String, dynamic>> _anthToolUse = <String, Map<String, dynamic>>{}; // id -> {name, args}
      final Map<int, String> _cliIndexToId = <int, String>{}; // client tool: index -> id
      final Map<String, String> _toolResultsContent = <String, String>{}; // id -> result text
      final List<Map<String, dynamic>> assistantBlocks = <Map<String, dynamic>>[];
      final StringBuffer textBuf = StringBuffer();

      // Track thinking blocks so they can be sent back for tool-use continuation.
      final Map<int, int> _thinkingIndexToAssistantBlock = <int, int>{};
      final Map<int, StringBuffer> _thinkingText = <int, StringBuffer>{};
      final Map<int, StringBuffer> _thinkingSig = <int, StringBuffer>{};
      final Map<int, int> _redactedThinkingIndexToAssistantBlock = <int, int>{};
      final Map<int, StringBuffer> _redactedThinkingData = <int, StringBuffer>{};

      int? _parseIndex(dynamic raw) {
        if (raw == null) return null;
        if (raw is int) return raw;
        return int.tryParse(raw.toString());
      }

      void _flushTextBlock() {
        final t = textBuf.toString();
        if (t.isNotEmpty) {
          assistantBlocks.add({'type': 'text', 'text': t});
          textBuf.clear();
        }
      }

      // Server tool helpers (web_search)
      final Map<int, String> _srvIndexToId = <int, String>{};
      final Map<String, String> _srvArgsStr = <String, String>{};
      final Map<String, Map<String, dynamic>> _srvArgs = <String, Map<String, dynamic>>{};

      bool messageStopped = false;

      await for (final chunk in sse) {
        buffer += chunk;
        final lines = buffer.split('\n');
        buffer = lines.last;

        for (int i = 0; i < lines.length - 1; i++) {
          final line = lines[i].trim();
          if (line.isEmpty || !line.startsWith('data:')) continue;

          final data = line.substring(5).trimLeft();
          try {
            final obj = jsonDecode(data);
            final type = obj['type'];

            if (type == 'content_block_start') {
              final cb = obj['content_block'];
              final idx = _parseIndex(obj['index']);
              if (cb is Map && (cb['type'] == 'thinking')) {
                // Preserve thinking blocks (with signature) for tool-use continuation.
                _flushTextBlock();
                if (idx != null) {
                  assistantBlocks.add({'type': 'thinking', 'thinking': '', 'signature': ''});
                  _thinkingIndexToAssistantBlock[idx] = assistantBlocks.length - 1;
                  _thinkingText[idx] = StringBuffer();
                  _thinkingSig[idx] = StringBuffer();
                }
              } else if (cb is Map && (cb['type'] == 'redacted_thinking')) {
                _flushTextBlock();
                if (idx != null) {
                  assistantBlocks.add({'type': 'redacted_thinking', 'data': ''});
                  _redactedThinkingIndexToAssistantBlock[idx] = assistantBlocks.length - 1;
                  _redactedThinkingData[idx] = StringBuffer();
                }
              } else if (cb is Map && (cb['type'] == 'tool_use')) {
                // Flush text block before tool_use
                _flushTextBlock();
                final id = (cb['id'] ?? '').toString();
                final name = (cb['name'] ?? '').toString();
                final idx2 = idx ?? -1;
                if (id.isNotEmpty) {
                  _anthToolUse.putIfAbsent(id, () => {'name': name, 'args': ''});
                  assistantBlocks.add({'type': 'tool_use', 'id': id, 'name': name, 'input': {}});
                  if (idx2 >= 0) _cliIndexToId[idx2] = id;
                  // Emit placeholder tool-call card immediately
                  yield ChatStreamChunk(
                    content: '',
                    isDone: false,
                    totalTokens: roundTokens,
                    usage: usage,
                    toolCalls: [ToolCallInfo(id: id, name: name, arguments: const <String, dynamic>{})],
                  );
                }
              } else if (cb is Map && (cb['type'] == 'server_tool_use')) {
                final id = (cb['id'] ?? '').toString();
                final idx2 = idx ?? -1;
                if (id.isNotEmpty && idx2 >= 0) {
                  _srvIndexToId[idx2] = id;
                  _srvArgsStr[id] = '';
                }
                // Emit placeholder for server tool to show card (e.g., built-in web_search)
                if (id.isNotEmpty) {
                  yield ChatStreamChunk(
                    content: '',
                    isDone: false,
                    totalTokens: roundTokens,
                    usage: usage,
                    toolCalls: [ToolCallInfo(id: id, name: 'search_web', arguments: const <String, dynamic>{})],
                  );
                }
              } else if (cb is Map && (cb['type'] == 'web_search_tool_result')) {
                // Emit simplified search results to UI
                final toolUseId = (cb['tool_use_id'] ?? '').toString();
                final contentBlock = cb['content'];
                final items = <Map<String, dynamic>>[];
                String? errorCode;
                if (contentBlock is List) {
                  for (int j = 0; j < contentBlock.length; j++) {
                    final it = contentBlock[j];
                    if (it is Map && (it['type'] == 'web_search_result')) {
                      items.add({
                        'index': j + 1,
                        'title': (it['title'] ?? '').toString(),
                        'url': (it['url'] ?? '').toString(),
                        if ((it['page_age'] ?? '').toString().isNotEmpty) 'page_age': (it['page_age'] ?? '').toString(),
                      });
                    }
                  }
                } else if (contentBlock is Map && (contentBlock['type'] == 'web_search_tool_result_error')) {
                  errorCode = (contentBlock['error_code'] ?? '').toString();
                }
                Map<String, dynamic> args = const <String, dynamic>{};
                if (_srvArgs.containsKey(toolUseId)) args = _srvArgs[toolUseId]!;
                final payload = jsonEncode({'items': items, if ((errorCode ?? '').isNotEmpty) 'error': errorCode});
                yield ChatStreamChunk(
                  content: '',
                  isDone: false,
                  totalTokens: roundTokens,
                  usage: usage,
                  toolResults: [ToolResultInfo(id: toolUseId.isEmpty ? 'builtin_search' : toolUseId, name: 'search_web', arguments: args, content: payload)],
                );
              }
            } else if (type == 'content_block_delta') {
              final delta = obj['delta'];
              if (delta != null) {
                if (delta['type'] == 'text_delta') {
                  final content = delta['text'] ?? '';
                  if (content is String && content.isNotEmpty) {
                    textBuf.write(content);
                    yield ChatStreamChunk(content: content, isDone: false, totalTokens: roundTokens);
                  }
                } else if (delta['type'] == 'thinking_delta') {
                  final idx = _parseIndex(obj['index']);
                  final thinking = (delta['thinking'] ?? delta['text'] ?? '') as String;
                  if (thinking.isNotEmpty) {
                    yield ChatStreamChunk(content: '', reasoning: thinking, isDone: false, totalTokens: roundTokens);
                    if (idx != null && _thinkingText.containsKey(idx)) {
                      _thinkingText[idx]!.write(thinking);
                    }
                  }
                } else if (delta['type'] == 'signature_delta') {
                  final idx = _parseIndex(obj['index']);
                  final sig = (delta['signature'] ?? '').toString();
                  if (sig.isNotEmpty && idx != null && _thinkingSig.containsKey(idx)) {
                    _thinkingSig[idx]!.write(sig);
                  }
                } else if (delta['type'] == 'redacted_thinking_delta') {
                  final idx = _parseIndex(obj['index']);
                  final data = (delta['data'] ?? '').toString();
                  if (data.isNotEmpty && idx != null && _redactedThinkingData.containsKey(idx)) {
                    _redactedThinkingData[idx]!.write(data);
                  }
                } else if (delta['type'] == 'tool_use_delta') {
                  // Client tool input fragments stream under the same content_block index
                  final idx = (obj['index'] is int) ? obj['index'] as int : int.tryParse((obj['index'] ?? '').toString());
                  final id = (idx != null && _cliIndexToId.containsKey(idx)) ? _cliIndexToId[idx]! : '';
                  if (id.isNotEmpty) {
                    final argsDelta = (delta['partial_json'] ?? delta['input'] ?? delta['text'] ?? '').toString();
                    final entry = _anthToolUse.putIfAbsent(id, () => {'name': '', 'args': ''});
                    if (argsDelta.isNotEmpty) entry['args'] = (entry['args'] ?? '') + argsDelta;
                  }
                } else if (delta['type'] == 'input_json_delta') {
                  final idxRaw = obj['index'];
                  final index = (idxRaw is int) ? idxRaw : int.tryParse((idxRaw ?? '').toString());
                  final part = (delta['partial_json'] ?? '').toString();
                  if (index != null && part.isNotEmpty) {
                    if (_cliIndexToId.containsKey(index)) {
                      final id = _cliIndexToId[index]!;
                      final entry = _anthToolUse.putIfAbsent(id, () => {'name': '', 'args': ''});
                      entry['args'] = (entry['args'] ?? '') + part;
                    } else if (_srvIndexToId.containsKey(index)) {
                      final id = _srvIndexToId[index]!;
                      _srvArgsStr[id] = (_srvArgsStr[id] ?? '') + part;
                    }
                  }
                }
              }
            } else if (type == 'content_block_stop') {
              final idx = _parseIndex(obj['index']);
              // Finalize thinking blocks so they can be sent back unmodified.
              if (idx != null && _thinkingIndexToAssistantBlock.containsKey(idx)) {
                final pos = _thinkingIndexToAssistantBlock.remove(idx)!;
                final t = _thinkingText.remove(idx)?.toString() ?? '';
                final sig = _thinkingSig.remove(idx)?.toString() ?? '';
                assistantBlocks[pos] = {'type': 'thinking', 'thinking': t, 'signature': sig};
              }
              if (idx != null && _redactedThinkingIndexToAssistantBlock.containsKey(idx)) {
                final pos = _redactedThinkingIndexToAssistantBlock.remove(idx)!;
                final data = _redactedThinkingData.remove(idx)?.toString() ?? '';
                assistantBlocks[pos] = {'type': 'redacted_thinking', 'data': data};
              }
              String id = (obj['content_block']?['id'] ?? obj['id'] ?? '').toString();
              if (id.isEmpty && idx != null && _cliIndexToId.containsKey(idx)) {
                id = _cliIndexToId[idx]!;
              }
              if (id.isNotEmpty && _anthToolUse.containsKey(id)) {
                final name = (_anthToolUse[id]!['name'] ?? '').toString();
                Map<String, dynamic> args;
                try { args = (jsonDecode((_anthToolUse[id]!['args'] ?? '{}') as String) as Map).cast<String, dynamic>(); } catch (_) { args = <String, dynamic>{}; }
                // Update last assistant tool_use block input
                for (int k = assistantBlocks.length - 1; k >= 0; k--) {
                  final b = assistantBlocks[k];
                  if (b['type'] == 'tool_use' && (b['id']?.toString() ?? '') == id) {
                    assistantBlocks[k] = {'type': 'tool_use', 'id': id, 'name': name, 'input': args};
                    break;
                  }
                }
                // Emit tool result to UI (placeholder was emitted at start)
                if (onToolCall != null) {
                  final res = await onToolCall(name, args) ?? '';
                  _toolResultsContent[id] = res;
                  yield ChatStreamChunk(content: '', isDone: false, totalTokens: roundTokens, toolResults: [ToolResultInfo(id: id, name: name, arguments: args, content: res)], usage: usage);
                }
              } else {
                if (idx != null && _srvIndexToId.containsKey(idx)) {
                  final sid = _srvIndexToId[idx]!;
                  Map<String, dynamic> args;
                  try { args = (jsonDecode((_srvArgsStr[sid] ?? '{}')) as Map).cast<String, dynamic>(); } catch (_) { args = <String, dynamic>{}; }
                  _srvArgs[sid] = args;
                  yield ChatStreamChunk(content: '', isDone: false, totalTokens: roundTokens, usage: usage, toolCalls: [ToolCallInfo(id: sid, name: 'search_web', arguments: args)]);
                }
              }
            } else if (type == 'message_delta') {
              final u = obj['usage'] ?? obj['message']?['usage'];
              if (u != null) {
                final inTok = (u['input_tokens'] ?? 0) as int;
                final outTok = (u['output_tokens'] ?? 0) as int;
                usage = (usage ?? const TokenUsage()).merge(TokenUsage(promptTokens: inTok, completionTokens: outTok));
                roundTokens = usage!.totalTokens;
              }
              // Capture stop reason to handle pause_turn for server tools
              try {
                final d = obj['delta'];
                final sr = (d is Map) ? (d['stop_reason'] ?? d['stopReason']) : null;
                if (sr is String && sr.isNotEmpty) {
                  _lastStopReason = sr;
                }
              } catch (_) {}
            } else if (type == 'message_stop') {
              // Flush remaining text
              final t = textBuf.toString();
              if (t.isNotEmpty) assistantBlocks.add({'type': 'text', 'text': t});
              messageStopped = true;
            }
          } catch (_) {
            // ignore malformed chunk
          }
        }
        if (messageStopped) break; // break await-for
      }

      // Merge usage across rounds for final token count
      if (usage != null) totalUsage = (totalUsage ?? const TokenUsage()).merge(usage!);

      // If no client tool calls, decide whether to continue (pause_turn/server tool) or finalize
      if (_anthToolUse.isEmpty) {
        final hadServerTool = assistantBlocks.any((b) => (b is Map) && (b['type'] == 'tool_use' || b['type'] == 'text')) && _srvIndexToId.isNotEmpty;
        final sr = _lastStopReason ?? '';
        if (sr == 'pause_turn' || hadServerTool) {
          // Continue this turn with assistant content only
          convo = [
            ...convo,
            {'role': 'assistant', 'content': assistantBlocks},
          ];
          // Loop to next round
          continue;
        } else {
          yield ChatStreamChunk(content: '', isDone: true, totalTokens: (totalUsage?.totalTokens ?? roundTokens), usage: totalUsage ?? usage);
          return;
        }
      }

      // Build tool_result blocks in a single user message (parallel-safe)
      final toolResultsBlocks = <Map<String, dynamic>>[];
      for (final entry in _anthToolUse.entries) {
        final id = entry.key;
        final name = (entry.value['name'] ?? '').toString();
        Map<String, dynamic> args;
        try { args = (jsonDecode((entry.value['args'] ?? '{}') as String) as Map).cast<String, dynamic>(); } catch (_) { args = <String, dynamic>{}; }
        String res = _toolResultsContent[id] ?? '';
        if (res.isEmpty && onToolCall != null) {
          res = await onToolCall(name, args) ?? '';
        }
        toolResultsBlocks.add({
          'type': 'tool_result',
          'tool_use_id': id,
          if (res.isNotEmpty) 'content': res,
        });
      }

      // Extend conversation: assistant content (with tool_use blocks) + user tool_results
      convo = [
        ...convo,
        {'role': 'assistant', 'content': assistantBlocks},
        {'role': 'user', 'content': toolResultsBlocks},
      ];
      // Loop to next round; the next response will stream more assistant content
    }
  }

  static Stream<ChatStreamChunk> _sendGoogleStream(
      http.Client client,
      ProviderConfig config,
      String modelId,
      List<Map<String, dynamic>> messages,
      {List<String>? userImagePaths, int? thinkingBudget, double? temperature, double? topP, int? maxTokens, List<Map<String, dynamic>>? tools, Future<String> Function(String, Map<String, dynamic>)? onToolCall, Map<String, String>? extraHeaders, Map<String, dynamic>? extraBody, bool stream = true}
      ) async* {
    final bool _persistGeminiThoughtSigs = modelId.toLowerCase().contains('gemini-3');
    final builtIns = _builtInTools(config, modelId);
    final enableYoutube = builtIns.contains(BuiltInToolNames.youtube);
    // Non-streaming path: use generateContent
    if (!stream) {
      final isVertex = config.vertexAI == true;
      final base = config.baseUrl.endsWith('/') ? config.baseUrl.substring(0, config.baseUrl.length - 1) : config.baseUrl;
      String url;
      if (isVertex && (config.projectId?.isNotEmpty == true) && (config.location?.isNotEmpty == true)) {
        url = 'https://aiplatform.googleapis.com/v1/projects/${config.projectId}/locations/${config.location}/publishers/google/models/$modelId:generateContent';
      } else {
        url = '$base/models/$modelId:generateContent';
      }

      // Convert messages to contents
      final contents = <Map<String, dynamic>>[];
      for (int i = 0; i < messages.length; i++) {
        final msg = messages[i];
        final role = msg['role'] == 'assistant' ? 'model' : 'user';
        final isLast = i == messages.length - 1;
        final parts = <Map<String, dynamic>>[];
        final meta = _extractGeminiThoughtMeta((msg['content'] ?? '').toString());
        final raw = meta.cleanedText;
        final seenSources = <String>{};
        String normalizeSrc(String src) {
          if (src.startsWith('http') || src.startsWith('data:')) return src;
          try {
            return SandboxPathResolver.fix(src);
          } catch (_) {
            return src;
          }
        }
        final hasMarkdownImages = raw.contains('![') && raw.contains('](');
        final hasCustomImages = raw.contains('[image:');
        final hasAttachedImages = isLast && role == 'user' && (userImagePaths?.isNotEmpty == true);
        if (hasMarkdownImages || hasCustomImages || hasAttachedImages) {
          final parsed = await _parseTextAndImages(
            raw,
            // Gemini API 目前无法直接拉取远程 http(s) 图片
            allowRemoteImages: false,
            allowLocalImages: true,
            keepRemoteMarkdownText: true,
          );
          if (parsed.text.isNotEmpty) parts.add({'text': parsed.text});
          for (final ref in parsed.images) {
            final normalized = normalizeSrc(ref.src);
            if (!seenSources.add(normalized)) continue;
            if (ref.kind == 'data') {
              final mime = _mimeFromDataUrl(ref.src);
              final idx = ref.src.indexOf('base64,');
              if (idx > 0) {
                final b64 = ref.src.substring(idx + 7);
                parts.add({'inline_data': {'mime_type': mime, 'data': b64}});
              } else {
                parts.add({'text': ref.src});
              }
            } else if (ref.kind == 'path') {
              final mime = _mimeFromPath(ref.src);
              final b64 = await _encodeBase64File(ref.src, withPrefix: false);
              parts.add({'inline_data': {'mime_type': mime, 'data': b64}});
            } else {
              parts.add({'text': '(image) ${ref.src}'});
            }
          }
          if (hasAttachedImages) {
            for (final p in userImagePaths!) {
              final normalized = normalizeSrc(p);
              if (!seenSources.add(normalized)) continue;
              if (p.startsWith('data:')) {
                final mime = _mimeFromDataUrl(p);
                final idx = p.indexOf('base64,');
                if (idx > 0) {
                  final b64 = p.substring(idx + 7);
                  parts.add({'inline_data': {'mime_type': mime, 'data': b64}});
                }
              } else if (!(p.startsWith('http://') || p.startsWith('https://'))) {
                final mime = _mimeFromPath(p);
                final b64 = await _encodeBase64File(p, withPrefix: false);
                parts.add({'inline_data': {'mime_type': mime, 'data': b64}});
              } else {
                parts.add({'text': '(image) ${p}'});
              }
            }
          }
        } else {
          if (raw.isNotEmpty) parts.add({'text': raw});
        }
        // YouTube URL ingestion as file_data parts (Gemini official API)
        // Only inject on the last user message of this request.
        if (role == 'user' && isLast && enableYoutube) {
          final urls = _extractYouTubeUrls(raw);
          for (final u in urls) {
            // Vertex AI requires mime_type for file_data
            if (isVertex) {
              parts.add({'file_data': {'file_uri': u, 'mime_type': 'video/*'}});
            } else {
              parts.add({'file_data': {'file_uri': u}});
            }
          }
        }
        if (role == 'model') {
          _applyGeminiThoughtSignatures(meta, parts, attachDummyWhenMissing: _persistGeminiThoughtSigs);
        }
        contents.add({'role': role, 'parts': parts});
      }

      final effective = _effectiveModelInfo(config, modelId);
      final isReasoning = effective.abilities.contains(ModelAbility.reasoning);

      // Map OpenAI-style tools to Gemini functionDeclarations (MCP)
      List<Map<String, dynamic>>? geminiTools;
      if (tools != null && tools.isNotEmpty) {
        final decls = <Map<String, dynamic>>[];
        for (final t in tools) {
          final fn = (t['function'] as Map<String, dynamic>?);
          if (fn == null) continue;
          final name = (fn['name'] ?? '').toString();
          if (name.isEmpty) continue;
          final desc = (fn['description'] ?? '').toString();
          final params = (fn['parameters'] as Map?)?.cast<String, dynamic>();
          final d = <String, dynamic>{'name': name, if (desc.isNotEmpty) 'description': desc};
          if (params != null) d['parameters'] = _cleanSchemaForGemini(params);
          decls.add(d);
        }
        if (decls.isNotEmpty) geminiTools = [{'function_declarations': decls}];
      }

      final headers = <String, String>{'Content-Type': 'application/json'};
      if (isVertex) {
        final token = await GoogleServiceAccountAuth.getAccessTokenFromJson(config.serviceAccountJson ?? '');
        headers['Authorization'] = 'Bearer $token';
      } else {
        final apiKey = _effectiveApiKey(config);
        if (apiKey.isNotEmpty) {
          headers['x-goog-api-key'] = apiKey;
        }
      }

      // Built-in tools and function_declarations (MCP) are mutually exclusive in Gemini API
      // code_execution = exclusive mode (cannot coexist with anything)
      // search/url_context = can coexist, but exclude MCP
      final toolsArr = <Map<String, dynamic>>[];
      if (builtIns.contains(BuiltInToolNames.codeExecution)) {
        toolsArr.add({'code_execution': {}});
      } else if (builtIns.contains(BuiltInToolNames.search) || builtIns.contains(BuiltInToolNames.urlContext)) {
        if (builtIns.contains(BuiltInToolNames.search)) toolsArr.add({'google_search': {}});
        if (builtIns.contains(BuiltInToolNames.urlContext)) toolsArr.add({'url_context': {}});
      } else if (geminiTools != null) {
        toolsArr.addAll(geminiTools);
      }

      Map<String, dynamic> baseBody = {
        'contents': contents,
        if (temperature != null) 'temperature': temperature,
        if (topP != null) 'topP': topP,
        if (maxTokens != null) 'generationConfig': {'maxOutputTokens': maxTokens},
        if (toolsArr.isNotEmpty) 'tools': toolsArr,
        if (toolsArr.isNotEmpty) 'toolConfig': {'function_calling_config': {'mode': 'AUTO'}},
      };
      final extraG = _customBody(config, modelId);
      if (extraG.isNotEmpty) baseBody.addAll(extraG);
      if (extraBody != null && extraBody.isNotEmpty) {
        extraBody.forEach((k, v) { baseBody[k] = (v is String) ? _parseOverrideValue(v) : v; });
      }

      TokenUsage? totalUsage;
      List<Map<String, dynamic>> currentContents = List<Map<String, dynamic>>.from(contents);
      while (true) {
        final req = http.Request('POST', Uri.parse(url));
        req.headers.addAll(headers);
        final body = Map<String, dynamic>.from(baseBody);
        body['contents'] = currentContents;
        req.body = jsonEncode(body);
        final resp = await client.send(req);
        if (resp.statusCode < 200 || resp.statusCode >= 300) {
          final errorBody = await resp.stream.bytesToString();
          throw HttpException('HTTP ${resp.statusCode}: $errorBody');
        }
        final txt = await resp.stream.bytesToString();
        final obj = jsonDecode(txt) as Map<String, dynamic>;
        try {
          final u = (obj['usageMetadata'] as Map?)?.cast<String, dynamic>();
          if (u != null) {
            final prompt = (u['promptTokenCount'] ?? 0) as int? ?? 0;
            final completion = (u['candidatesTokenCount'] ?? 0) as int? ?? 0;
            totalUsage = (totalUsage ?? const TokenUsage()).merge(TokenUsage(promptTokens: prompt, completionTokens: completion, cachedTokens: 0));
          }
        } catch (_) {}
        final candidates = (obj['candidates'] as List?) ?? const <dynamic>[];
        if (candidates.isEmpty) {
          yield ChatStreamChunk(content: '', isDone: true, totalTokens: totalUsage?.totalTokens ?? 0, usage: totalUsage);
          return;
        }
        final cand = (candidates.first as Map).cast<String, dynamic>();
        final parts = (cand['content']?['parts'] as List?) ?? const <dynamic>[];
        final fc = parts.firstWhere((e) => (e is Map) && e.containsKey('functionCall'), orElse: () => null);
        if (fc is Map && fc['functionCall'] is Map && onToolCall != null) {
          final call = (fc['functionCall'] as Map).cast<String, dynamic>();
          final name = (call['name'] ?? '').toString();
          final args = (call['args'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
          yield ChatStreamChunk(content: '', isDone: false, totalTokens: totalUsage?.totalTokens ?? 0, usage: totalUsage, toolCalls: [ToolCallInfo(id: 'fn_0', name: name, arguments: args)]);
          final res = await onToolCall(name, args) ?? '';
          yield ChatStreamChunk(content: '', isDone: false, totalTokens: totalUsage?.totalTokens ?? 0, usage: totalUsage, toolResults: [ToolResultInfo(id: 'fn_0', name: name, arguments: args, content: res)]);
          currentContents = [
            ...currentContents,
            {'role': 'model', 'parts': parts},
            {'role': 'user', 'parts': [ {'functionResponse': {'name': name, 'response': {'result': res}}} ]},
          ];
          continue;
        }
        final buf = StringBuffer();
        for (final p in parts) { if (p is Map && p['text'] is String) buf.write(p['text']); }
        var contentStr = buf.toString();
        if (_persistGeminiThoughtSigs) {
          final metaComment = _collectThoughtSigCommentFromParts(parts);
          if (metaComment.isNotEmpty) contentStr += metaComment;
        }
        yield ChatStreamChunk(content: contentStr, isDone: true, totalTokens: totalUsage?.totalTokens ?? 0, usage: totalUsage);
        return;
      }
    }

    // Implement SSE streaming via :streamGenerateContent with alt=sse
    // Build endpoint per Vertex vs Gemini
    String baseUrl;
    if (config.vertexAI == true && (config.location?.isNotEmpty == true) && (config.projectId?.isNotEmpty == true)) {
      final loc = config.location!.trim();
      final proj = config.projectId!.trim();
      baseUrl = 'https://aiplatform.googleapis.com/v1/projects/$proj/locations/$loc/publishers/google/models/$modelId:streamGenerateContent';
    } else {
      final base = config.baseUrl.endsWith('/')
          ? config.baseUrl.substring(0, config.baseUrl.length - 1)
          : config.baseUrl;
      baseUrl = '$base/models/$modelId:streamGenerateContent';
    }

    // Build query with alt=sse
    final uriBase = Uri.parse(baseUrl);
    final qp = Map<String, String>.from(uriBase.queryParameters);
    qp['alt'] = 'sse';
    final uri = uriBase.replace(queryParameters: qp);
    final isVertex = config.vertexAI == true;

    // Convert messages to Google contents format
    final contents = <Map<String, dynamic>>[];
    for (int i = 0; i < messages.length; i++) {
      final msg = messages[i];
      final role = msg['role'] == 'assistant' ? 'model' : 'user';
      final isLast = i == messages.length - 1;
      final parts = <Map<String, dynamic>>[];
      final meta = _extractGeminiThoughtMeta((msg['content'] ?? '').toString());
      final raw = meta.cleanedText;
      final seenSources = <String>{};
      String normalizeSrc(String src) {
        if (src.startsWith('http') || src.startsWith('data:')) return src;
        try {
          return SandboxPathResolver.fix(src);
        } catch (_) {
          return src;
        }
      }

      // Only parse images if there are images to process
      final hasMarkdownImages = raw.contains('![') && raw.contains('](');
      final hasCustomImages = raw.contains('[image:');
      final hasAttachedImages = isLast && role == 'user' && (userImagePaths?.isNotEmpty == true);

      if (hasMarkdownImages || hasCustomImages || hasAttachedImages) {
        final parsed = await _parseTextAndImages(
          raw,
          // Gemini API 目前无法直接拉取远程 http(s) 图片
          allowRemoteImages: false,
          allowLocalImages: true,
          keepRemoteMarkdownText: true,
        );
        if (parsed.text.isNotEmpty) parts.add({'text': parsed.text});
        // Images extracted from this message's text
        for (final ref in parsed.images) {
          final normalized = normalizeSrc(ref.src);
          if (!seenSources.add(normalized)) continue;
          if (ref.kind == 'data') {
            final mime = _mimeFromDataUrl(ref.src);
            final idx = ref.src.indexOf('base64,');
            if (idx > 0) {
              final b64 = ref.src.substring(idx + 7);
              parts.add({'inline_data': {'mime_type': mime, 'data': b64}});
            } else {
              // If malformed data URL, include as plain text fallback
              parts.add({'text': ref.src});
            }
          } else if (ref.kind == 'path') {
            final mime = _mimeFromPath(ref.src);
            final b64 = await _encodeBase64File(ref.src, withPrefix: false);
            parts.add({'inline_data': {'mime_type': mime, 'data': b64}});
          } else {
            // Remote URL: Gemini official API doesn't fetch http(s) here; keep short reference
            parts.add({'text': '(image) ${ref.src}'});
          }
        }
        if (hasAttachedImages) {
          for (final p in userImagePaths!) {
            final normalized = normalizeSrc(p);
            if (!seenSources.add(normalized)) continue;
            if (p.startsWith('data:')) {
              final mime = _mimeFromDataUrl(p);
              final idx = p.indexOf('base64,');
              if (idx > 0) {
                final b64 = p.substring(idx + 7);
                parts.add({'inline_data': {'mime_type': mime, 'data': b64}});
              }
            } else if (!(p.startsWith('http://') || p.startsWith('https://'))) {
              final mime = _mimeFromPath(p);
              final b64 = await _encodeBase64File(p, withPrefix: false);
              parts.add({'inline_data': {'mime_type': mime, 'data': b64}});
            } else {
              // http url fallback reference text
              parts.add({'text': '(image) ${p}'});
            }
          }
        }
      } else {
        // No images, use simple text content
        if (raw.isNotEmpty) parts.add({'text': raw});
      }
      // YouTube URL ingestion as file_data parts (Gemini official API)
      // Only inject on the last user message of this request.
      if (role == 'user' && isLast && enableYoutube) {
        final urls = _extractYouTubeUrls(raw);
        for (final u in urls) {
          // Vertex AI requires mime_type for file_data
          if (isVertex) {
            parts.add({'file_data': {'file_uri': u, 'mime_type': 'video/*'}});
          } else {
            parts.add({'file_data': {'file_uri': u}});
          }
        }
      }
      if (role == 'model') {
        _applyGeminiThoughtSignatures(meta, parts, attachDummyWhenMissing: _persistGeminiThoughtSigs);
      }
      contents.add({'role': role, 'parts': parts});
    }

    // Effective model features (includes user overrides)
    final effective = _effectiveModelInfo(config, modelId);
    final isReasoning = effective.abilities.contains(ModelAbility.reasoning);
    final wantsImageOutput = effective.output.contains(Modality.image);
    bool _expectImage = wantsImageOutput;
    bool _receivedImage = false;
    final off = _isOff(thinkingBudget);

    // Map OpenAI-style tools to Gemini functionDeclarations (MCP)
    List<Map<String, dynamic>>? geminiTools;
    if (tools != null && tools.isNotEmpty) {
      final decls = <Map<String, dynamic>>[];
      for (final t in tools) {
        final fn = (t['function'] as Map<String, dynamic>?);
        if (fn == null) continue;
        final name = (fn['name'] ?? '').toString();
        if (name.isEmpty) continue;
        final desc = (fn['description'] ?? '').toString();
        final params = (fn['parameters'] as Map?)?.cast<String, dynamic>();
        final d = <String, dynamic>{'name': name, if (desc.isNotEmpty) 'description': desc};
        if (params != null) {
          // Google Gemini requires strict JSON Schema compliance
          // Fix array properties that are missing 'items' field
          final cleanedParams = _cleanSchemaForGemini(params);
          d['parameters'] = cleanedParams;
        }
        decls.add(d);
      }
      if (decls.isNotEmpty) geminiTools = [{'function_declarations': decls}];
    }
    // Built-in tools and function_declarations (MCP) are mutually exclusive in Gemini API
    // code_execution = exclusive mode (cannot coexist with anything)
    // search/url_context = can coexist, but exclude MCP
    final toolsArr = <Map<String, dynamic>>[];
    if (builtIns.contains(BuiltInToolNames.codeExecution)) {
      toolsArr.add({'code_execution': {}});
    } else if (builtIns.contains(BuiltInToolNames.search) || builtIns.contains(BuiltInToolNames.urlContext)) {
      if (builtIns.contains(BuiltInToolNames.search)) toolsArr.add({'google_search': {}});
      if (builtIns.contains(BuiltInToolNames.urlContext)) toolsArr.add({'url_context': {}});
    } else if (geminiTools != null) {
      toolsArr.addAll(geminiTools);
    }

    // Maintain a rolling conversation for multi-round tool calls
    List<Map<String, dynamic>> convo = List<Map<String, dynamic>>.from(contents);
    TokenUsage? usage;
    int totalTokens = 0;

    // Accumulate built-in search citations across stream rounds
    final List<Map<String, dynamic>> _builtinCitations = <Map<String, dynamic>>[];

    List<Map<String, dynamic>> _parseCitations(dynamic gm) {
      final out = <Map<String, dynamic>>[];
      if (gm is! Map) return out;
      final chunks = gm['groundingChunks'] as List? ?? const <dynamic>[];
      int idx = 1;
      final seen = <String>{};
      for (final ch in chunks) {
        if (ch is! Map) continue;
        final web = ch['web'] as Map? ?? ch['webSite'] as Map? ?? ch['webPage'] as Map?;
        if (web is! Map) continue;
        final uri = (web['uri'] ?? web['url'] ?? '').toString();
        if (uri.isEmpty) continue;
        // Deduplicate by uri
        if (seen.contains(uri)) continue;
        seen.add(uri);
        final title = (web['title'] ?? web['name'] ?? uri).toString();
        final id = 'c${idx.toString().padLeft(2, '0')}';
        out.add({'id': id, 'index': idx, 'title': title, 'url': uri});
        idx++;
      }
      return out;
    }

    while (true) {
      final gen = <String, dynamic>{
        if (temperature != null) 'temperature': temperature,
        if (topP != null) 'topP': topP,
        if (maxTokens != null) 'maxOutputTokens': maxTokens,
        // Enable IMAGE+TEXT output modalities when model is configured to output images
        if (wantsImageOutput) 'responseModalities': ['TEXT', 'IMAGE'],
        if (isReasoning)
          'thinkingConfig': () {
            // Match gemini-3-pro or gemini-3-pro-preview (and similar variants)
            final isGemini3ProImage = modelId.contains(RegExp(r'gemini-3-pro-image(-preview)?', caseSensitive: false));
            final isGemini3Pro = modelId.contains(RegExp(r'gemini-3-pro(-preview)?', caseSensitive: false));
            final isGemini3Flash = modelId.contains(RegExp(r'gemini-3-flash(-preview)?', caseSensitive: false));
            if (isGemini3ProImage) {
              return {
                'includeThoughts': true,
                if (thinkingBudget != null && thinkingBudget >= 0)
                  'thinkingBudget': thinkingBudget,
              };
            }
            // Gemini 3 Pro: supports 'low' and 'high' only (no off)
            if (isGemini3Pro) {
              String level = 'high';
              if (off || (thinkingBudget != null && thinkingBudget > 0 && thinkingBudget < 8000)) {
                // Off or Light (1024) → low
                level = 'low';
              }
              return {'includeThoughts': true, 'thinkingLevel': level};
            }
            // Gemini 3 Flash: supports 'minimal', 'low', 'medium', 'high'
            if (isGemini3Flash) {
              String level = 'high';
              if (off) {
                level = 'minimal';
              } else if (thinkingBudget != null && thinkingBudget > 0) {
                // Light (1024) → low, Medium (16000) → medium, Heavy (32000) → high
                if (thinkingBudget < 8000) level = 'low';
                else if (thinkingBudget < 24000) level = 'medium';
              }
              return {'includeThoughts': true, 'thinkingLevel': level};
            }
            // Gemini 2.x and below: use thinkingBudget
            if (off) return {'includeThoughts': false};
            return {
              'includeThoughts': true,
              if (thinkingBudget != null && thinkingBudget >= 0)
                'thinkingBudget': thinkingBudget,
            };
          }(),
      };
      final body = <String, dynamic>{
        'contents': convo,
        if (gen.isNotEmpty) 'generationConfig': gen,
        if (toolsArr.isNotEmpty) 'tools': toolsArr,
        if (toolsArr.isNotEmpty) 'toolConfig': {'function_calling_config': {'mode': 'AUTO'}},
      };

      final request = http.Request('POST', uri);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
      };
      if (config.vertexAI == true) {
        final token = await _maybeVertexAccessToken(config);
        if (token != null && token.isNotEmpty) {
          headers['Authorization'] = 'Bearer $token';
        }
        final proj = (config.projectId ?? '').trim();
        if (proj.isNotEmpty) headers['X-Goog-User-Project'] = proj;
      } else {
        final apiKey = _effectiveApiKey(config);
        if (apiKey.isNotEmpty) {
          headers['x-goog-api-key'] = apiKey;
        }
      }
      headers.addAll(_customHeaders(config, modelId));
      if (extraHeaders != null && extraHeaders.isNotEmpty) headers.addAll(extraHeaders);
      request.headers.addAll(headers);
      final extra = _customBody(config, modelId);
      if (extra.isNotEmpty) (body as Map<String, dynamic>).addAll(extra);
      if (extraBody != null && extraBody.isNotEmpty) {
        extraBody.forEach((k, v) {
          (body as Map<String, dynamic>)[k] = (v is String) ? _parseOverrideValue(v) : v;
        });
      }
      request.body = jsonEncode(body);

      final resp = await client.send(request);
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        final errorBody = await resp.stream.bytesToString();
        throw HttpException('HTTP ${resp.statusCode}: $errorBody');
      }

      final sse = resp.stream.transform(utf8.decoder);
      String buffer = '';
      // Collect any function calls in this round
      final List<Map<String, dynamic>> calls = <Map<String, dynamic>>[]; // {id,name,args,res}
      
      // Track thought signature across chunks (Gemini 3 requirement)
      String? persistentThoughtSigKey;
      dynamic persistentThoughtSigVal;
      // Capture thought signatures for history (Gemini 3 image/editing)
      String? responseTextThoughtSigKey;
      dynamic responseTextThoughtSigVal;
      final List<Map<String, dynamic>> responseImageThoughtSigs = <Map<String, dynamic>>[];

      // Track a streaming inline image; buffer chunks and emit only the latest frame once finished
      String _imageMime = 'image/png';
      String _pendingImageData = '';
      String _pendingImageTrailingText = '';
      bool _bufferingInlineImage = false;

      bool _looksLikeImageStart(String data) {
        const prefixes = <String>[
          '/9j/', // jpeg
          'iVBOR', // png
          'R0lGOD', // gif
          'UklGR', // webp
          'Qk', // bmp variants
          'SUkq', // tiff
        ];
        for (final p in prefixes) {
          if (data.startsWith(p)) return true;
        }
        return false;
      }

      Future<String> _sanitizeTextIfNeeded(String input) async {
        if (input.isEmpty) return input;
        if (input.contains('data:image') && input.contains('base64,')) {
          try {
            return await MarkdownMediaSanitizer.replaceInlineBase64Images(input);
          } catch (_) {
            return input;
          }
        }
        return input;
      }

      void _bufferInlineImageChunk(String mime, String data) {
        _imageMime = mime.isNotEmpty ? mime : 'image/png';
        final hasExisting = _pendingImageData.isNotEmpty;
        // Gemini image-preview streams often send full preview frames instead of deltas.
        // If the previous chunk already looks complete (padding) or a new frame header appears, replace it.
        final prevLooksComplete = hasExisting && _pendingImageData.endsWith('=');
        final newFrame = hasExisting && _looksLikeImageStart(data);
        if (prevLooksComplete || newFrame) {
          _pendingImageData = data;
        } else {
          _pendingImageData += data;
        }
        _bufferingInlineImage = true;
        _receivedImage = true;
      }

      Future<String> _takeBufferedImageMarkdown() async {
        if (!_bufferingInlineImage || _pendingImageData.isEmpty) return '';
        final trailing = _pendingImageTrailingText;
        final path = await AppDirectories.saveBase64Image(_imageMime, _pendingImageData);
        _bufferingInlineImage = false;
        _pendingImageData = '';
        _pendingImageTrailingText = '';
        if (path == null || path.isEmpty) return '';
        final sb = StringBuffer()..write('\n\n![image](')..write(path)..write(')');
        if (trailing.isNotEmpty) {
          sb.write(trailing);
        }
        return sb.toString();
      }

      await for (final chunk in sse) {
        buffer += chunk;
        final lines = buffer.split('\n');
        buffer = lines.last; // keep incomplete line

        for (int i = 0; i < lines.length - 1; i++) {
          final line = lines[i].trim();
          if (line.isEmpty) continue;
          if (!line.startsWith('data:')) continue;
          final data = line.substring(5).trim(); // after 'data:'
          if (data.isEmpty) continue;
          try {
            final obj = jsonDecode(data) as Map<String, dynamic>;
            final um = obj['usageMetadata'];
            if (um is Map<String, dynamic>) {
              usage = (usage ?? const TokenUsage()).merge(TokenUsage(
                promptTokens: (um['promptTokenCount'] ?? 0) as int,
                completionTokens: (um['candidatesTokenCount'] ?? 0) as int,
                totalTokens: (um['totalTokenCount'] ?? 0) as int,
              ));
              totalTokens = usage!.totalTokens;
            }

            final candidates = obj['candidates'];
            if (candidates is List && candidates.isNotEmpty) {
              String textDelta = '';
              String reasoningDelta = '';
              String? finishReason; // detect stream completion from server
              for (final cand in candidates) {
                if (cand is! Map) continue;
                final content = cand['content'];
                if (content is! Map) continue;
                final parts = content['parts'];
                if (parts is! List) continue;
                for (final p in parts) {
                  if (p is! Map) continue;
                  String? partThoughtSigKey;
                  dynamic partThoughtSigVal;
                  if (p.containsKey('thoughtSignature')) {
                    partThoughtSigKey = 'thoughtSignature';
                    partThoughtSigVal = p['thoughtSignature'];
                  } else if (p.containsKey('thought_signature')) {
                    partThoughtSigKey = 'thought_signature';
                    partThoughtSigVal = p['thought_signature'];
                  }
                  final t = (p['text'] ?? '') as String? ?? '';
                  final thought = p['thought'] as bool? ?? false;

                  // Check for thought signature in this part and update persistence
                  if (partThoughtSigKey != null) {
                    persistentThoughtSigKey = partThoughtSigKey;
                    persistentThoughtSigVal = partThoughtSigVal;
                  }

                  // Capture thought signature for text part (Gemini 3 image/editing)
                  if (_persistGeminiThoughtSigs && !thought && partThoughtSigKey != null && partThoughtSigVal != null) {
                    if (t.isNotEmpty && responseTextThoughtSigKey == null) {
                      responseTextThoughtSigKey = partThoughtSigKey;
                      responseTextThoughtSigVal = partThoughtSigVal;
                    }
                  }

                  if (t.isNotEmpty) {
                    if (thought) {
                      reasoningDelta += t;
                    } else if (_bufferingInlineImage) {
                      _pendingImageTrailingText += t;
                    } else {
                      textDelta += t;
                    }
                  }
                  // Parse inline image data from Gemini (inlineData)
                  // Response shape: { inlineData: { mimeType: 'image/png', data: '...base64...' } }
                  final inline = (p['inlineData'] ?? p['inline_data']);
                  if (inline is Map) {
                    final mime = (inline['mimeType'] ?? inline['mime_type'] ?? 'image/png').toString();
                    final data = (inline['data'] ?? '').toString();
                    if (data.isNotEmpty) {
                      if (_persistGeminiThoughtSigs && partThoughtSigKey != null && partThoughtSigVal != null) {
                        final exists = responseImageThoughtSigs.any((e) => e['k'] == partThoughtSigKey && e['v'] == partThoughtSigVal);
                        if (!exists) responseImageThoughtSigs.add({'k': partThoughtSigKey, 'v': partThoughtSigVal});
                      }
                      _bufferInlineImageChunk(mime, data);
                    }
                  }
                  // Parse fileData: { fileUri: 'https://...', mimeType: 'image/png' }
                  final fileData = (p['fileData'] ?? p['file_data']);
                  if (fileData is Map) {
                    final mime = (fileData['mimeType'] ?? fileData['mime_type'] ?? 'image/png').toString();
                    final uri = (fileData['fileUri'] ?? fileData['file_uri'] ?? fileData['uri'] ?? '').toString();
                    if (uri.startsWith('http')) {
                      try {
                        final b64 = await _downloadRemoteAsBase64(client, config, uri);
                        if (_persistGeminiThoughtSigs && partThoughtSigKey != null && partThoughtSigVal != null) {
                          final exists = responseImageThoughtSigs.any((e) => e['k'] == partThoughtSigKey && e['v'] == partThoughtSigVal);
                          if (!exists) responseImageThoughtSigs.add({'k': partThoughtSigKey, 'v': partThoughtSigVal});
                        }
                        _bufferInlineImageChunk(mime, b64);
                      } catch (_) {}
                    }
                  }
                  final fc = p['functionCall'];
                  if (fc is Map) {
                    final name = (fc['name'] ?? '').toString();
                    Map<String, dynamic> args = const <String, dynamic>{};
                    final rawArgs = fc['args'];
                    if (rawArgs is Map) {
                      args = rawArgs.cast<String, dynamic>();
                    } else if (rawArgs is String && rawArgs.isNotEmpty) {
                      try { args = (jsonDecode(rawArgs) as Map).cast<String, dynamic>(); } catch (_) {}
                    }
                    final id = 'call_${DateTime.now().microsecondsSinceEpoch}';
                    
                    // Capture thought signature (Gemini 3 Pro requirement)
                    // Preserve exact key/value as received
                    String? thoughtSigKey;
                    dynamic thoughtSigVal;
                    if (p.containsKey('thoughtSignature')) {
                      thoughtSigKey = 'thoughtSignature';
                      thoughtSigVal = p['thoughtSignature'];
                    } else if (p.containsKey('thought_signature')) {
                      thoughtSigKey = 'thought_signature';
                      thoughtSigVal = p['thought_signature'];
                    }
                    
                    // Fallback to persistent signature if not found in this part
                    if (thoughtSigKey == null && persistentThoughtSigKey != null) {
                      thoughtSigKey = persistentThoughtSigKey;
                      thoughtSigVal = persistentThoughtSigVal;
                    }

                    // Emit placeholder immediately
                    yield ChatStreamChunk(content: '', isDone: false, totalTokens: totalTokens, usage: usage, toolCalls: [ToolCallInfo(id: id, name: name, arguments: args)]);
                    String resText = '';
                    if (onToolCall != null) {
                      resText = await onToolCall(name, args) ?? '';
                      yield ChatStreamChunk(content: '', isDone: false, totalTokens: totalTokens, usage: usage, toolResults: [ToolResultInfo(id: id, name: name, arguments: args, content: resText)]);
                    }
                    calls.add({
                      'id': id,
                      'name': name,
                      'args': args,
                      'result': resText,
                      'thoughtSigKey': thoughtSigKey,
                      'thoughtSigVal': thoughtSigVal,
                    });
                  }
                }
                // Capture explicit finish reason if present
                final fr = cand['finishReason'];
                if (fr is String && fr.isNotEmpty) finishReason = fr;

                // Parse grounding metadata for citations if present
                final gm = cand['groundingMetadata'] ?? obj['groundingMetadata'];
                final cite = _parseCitations(gm);
                if (cite.isNotEmpty) {
                  // merge unique by url
                  final existingUrls = _builtinCitations.map((e) => e['url']?.toString() ?? '').toSet();
                  for (final it in cite) {
                    final u = it['url']?.toString() ?? '';
                    if (u.isEmpty || existingUrls.contains(u)) continue;
                    _builtinCitations.add(it);
                    existingUrls.add(u);
                  }
                  // emit a tool result chunk so UI can render citations card
                  final payload = jsonEncode({'items': _builtinCitations});
                  yield ChatStreamChunk(
                    content: '',
                    isDone: false,
                    totalTokens: totalTokens,
                    usage: usage,
                    toolResults: [ToolResultInfo(id: 'builtin_search', name: 'builtin_search', arguments: const <String, dynamic>{}, content: payload)],
                  );
                }
              }

              // When finishing, emit any buffered inline image (and trailing text) in one batch to avoid partial base64 during streaming.
              if (finishReason != null) {
                final pendingImage = await _takeBufferedImageMarkdown();
                if (pendingImage.isNotEmpty) {
                  textDelta += pendingImage;
                }
              }

              if (reasoningDelta.isNotEmpty) {
                yield ChatStreamChunk(content: '', reasoning: reasoningDelta, isDone: false, totalTokens: totalTokens, usage: usage);
              }
              if (textDelta.isNotEmpty) {
                textDelta = await _sanitizeTextIfNeeded(textDelta);
                yield ChatStreamChunk(content: textDelta, isDone: false, totalTokens: totalTokens, usage: usage);
              }

              // If server signaled finish, end stream immediately
              if (finishReason != null && calls.isEmpty && (!_expectImage || _receivedImage)) {
                // Emit final citations if any not emitted
                if (_builtinCitations.isNotEmpty) {
                  final payload = jsonEncode({'items': _builtinCitations});
                  yield ChatStreamChunk(content: '', isDone: false, totalTokens: totalTokens, usage: usage, toolResults: [ToolResultInfo(id: 'builtin_search', name: 'builtin_search', arguments: const <String, dynamic>{}, content: payload)]);
                }
                if (_persistGeminiThoughtSigs) {
                  final metaComment = _buildGeminiThoughtSigComment(
                    textKey: responseTextThoughtSigKey,
                    textValue: responseTextThoughtSigVal,
                    imageSigs: responseImageThoughtSigs,
                  );
                  if (metaComment.isNotEmpty) {
                    yield ChatStreamChunk(content: metaComment, isDone: false, totalTokens: totalTokens, usage: usage);
                  }
                }
                yield ChatStreamChunk(content: '', isDone: true, totalTokens: totalTokens, usage: usage);
                return;
              }
            }
          } catch (_) {
            // ignore malformed chunk
          }
        }
      }

      // Flush any buffered inline image (e.g., when stream ends without explicit finishReason)
      final pendingImage = await _takeBufferedImageMarkdown();
      if (pendingImage.isNotEmpty) {
        final sanitized = await _sanitizeTextIfNeeded(pendingImage);
        yield ChatStreamChunk(content: sanitized, isDone: false, totalTokens: totalTokens, usage: usage);
      }

      if (calls.isEmpty) {
        // No tool calls; this round finished
        if (_persistGeminiThoughtSigs) {
          final metaComment = _buildGeminiThoughtSigComment(
            textKey: responseTextThoughtSigKey,
            textValue: responseTextThoughtSigVal,
            imageSigs: responseImageThoughtSigs,
          );
          if (metaComment.isNotEmpty) {
            yield ChatStreamChunk(content: metaComment, isDone: false, totalTokens: totalTokens, usage: usage);
          }
        }
        yield ChatStreamChunk(content: '', isDone: true, totalTokens: totalTokens, usage: usage);
        return;
      }

      // Append model functionCall(s) and user functionResponse(s) to conversation, then loop
      for (final c in calls) {
        final name = (c['name'] ?? '').toString();
        final args = (c['args'] as Map<String, dynamic>? ?? const <String, dynamic>{});
        final resText = (c['result'] ?? '').toString();
        final thoughtSigKey = c['thoughtSigKey'] as String?;
        final thoughtSigVal = c['thoughtSigVal'];

        // Add the model's functionCall turn
        final part = <String, dynamic>{
          'functionCall': {'name': name, 'args': args},
        };
        if (thoughtSigKey != null && thoughtSigVal != null) {
          part[thoughtSigKey] = thoughtSigVal;
        }

        convo.add({'role': 'model', 'parts': [part]});
        // Prepare JSON response object
        Map<String, dynamic> responseObj;
        try {
          responseObj = (jsonDecode(resText) as Map).cast<String, dynamic>();
        } catch (_) {
          // Wrap plain text result
          responseObj = {'result': resText};
        }
        // Add user's functionResponse turn
        convo.add({'role': 'user', 'parts': [
          {'functionResponse': {'name': name, 'response': responseObj}},
        ]});
      }
      // Continue while(true) for next round
    }
  }

  static Future<String> _downloadRemoteAsBase64(http.Client client, ProviderConfig config, String url) async {
    final req = http.Request('GET', Uri.parse(url));
    // Add Vertex auth if enabled
    if (config.vertexAI == true) {
      try {
        final token = await _maybeVertexAccessToken(config);
        if (token != null && token.isNotEmpty) req.headers['Authorization'] = 'Bearer $token';
      } catch (_) {}
      final proj = (config.projectId ?? '').trim();
      if (proj.isNotEmpty) req.headers['X-Goog-User-Project'] = proj;
    }
    final resp = await client.send(req);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final err = await resp.stream.bytesToString();
      throw HttpException('HTTP ${resp.statusCode}: $err');
    }
    final bytes = await resp.stream.fold<List<int>>(<int>[], (acc, b) { acc.addAll(b); return acc; });
    return base64Encode(bytes);
  }
  // Returns OAuth token for Vertex AI when serviceAccountJson is configured; otherwise null.
  static Future<String?> _maybeVertexAccessToken(ProviderConfig cfg) async {
    if (cfg.vertexAI == true) {
      final jsonStr = (cfg.serviceAccountJson ?? '').trim();
      if (jsonStr.isEmpty) {
        // Fallback: some users may paste a temporary OAuth token into apiKey
        if (cfg.apiKey.isNotEmpty) return cfg.apiKey;
        return null;
      }
      try {
        return await GoogleServiceAccountAuth.getAccessTokenFromJson(jsonStr);
      } catch (_) {
        // On failure, do not crash streaming; let server return 401 and surface error upstream
        return null;
      }
    }
    return null;
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
  ToolResultInfo({required this.id, required this.name, required this.arguments, required this.content});
}
