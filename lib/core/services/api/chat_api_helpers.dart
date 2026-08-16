import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/secrets/fallback.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

import '../../providers/model_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/api_key_manager.dart';
import '../../utils/multimodal_input_utils.dart';
import '../../utils/openai_model_compat.dart';
import '../../../utils/sandbox_path_resolver.dart';
import '../logging/flutter_logger.dart';
import '../model_override_payload_parser.dart';
import '../model_override_resolver.dart';
import '../custom_request_merger.dart';
import 'builtin_tools.dart';
import 'provider_request_headers.dart';

typedef ToolCallHandler =
    Future<String> Function(
      String name,
      Map<String, dynamic> args, {
      String? toolCallId,
    });

String effectiveToolCallId(dynamic rawId, String fallbackPrefix, Object index) {
  final id = rawId?.toString().trim() ?? '';
  if (id.isNotEmpty) return id;
  return '${fallbackPrefix}_${DateTime.now().microsecondsSinceEpoch}_$index';
}

Future<String> decodeUtf8Stream(
  http.ByteStream stream, {
  bool allowMalformed = true,
}) async {
  return utf8.decode(await stream.toBytes(), allowMalformed: allowMalformed);
}

const String _aihubmixAppCode = 'ZKRT3588';

/// Resolve the upstream/vendor model id for a given logical model key.
/// When per-instance overrides specify `apiModelId`, that value is used for
/// outbound HTTP requests and vendor-specific heuristics. Otherwise the
/// logical `modelId` key is treated as the upstream id (backwards compatible).
String apiModelId(ProviderConfig cfg, String modelId) {
  try {
    final ov = _modelOverride(cfg, modelId);
    return resolveApiModelIdOverride(ov, modelId);
  } catch (_) {}
  return modelId;
}

String apiKeyForRequest(ProviderConfig cfg, String modelId) {
  final orig = effectiveApiKey(cfg).trim();
  if (orig.isNotEmpty) return orig;
  if ((cfg.id) == 'SiliconFlow') {
    final host = Uri.tryParse(cfg.baseUrl)?.host.toLowerCase() ?? '';
    if (!host.contains('siliconflow')) return orig;
    final m = apiModelId(cfg, modelId).toLowerCase();
    final allowed = m == 'thudm/glm-4-9b-0414' || m == 'qwen/qwen3-8b';
    final fallback = siliconflowFallbackKey.trim();
    if (allowed && fallback.isNotEmpty) {
      return fallback;
    }
  }
  return orig;
}

String effectiveApiKey(ProviderConfig cfg) {
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
Set<String> builtInTools(ProviderConfig cfg, String modelId) {
  try {
    return BuiltInToolNames.parseFromOverride(cfg.modelOverrides[modelId]);
  } catch (_) {}
  return const <String>{};
}

// Helpers to read per-model overrides (headers/body) from ProviderConfig
Map<String, dynamic> _modelOverride(ProviderConfig cfg, String modelId) {
  return ModelOverridePayloadParser.modelOverride(cfg.modelOverrides, modelId);
}

Map<String, String> customHeaders(
  ProviderConfig cfg,
  String modelId, {
  Map<String, String> baseHeaders = const <String, String>{},
  Map<String, String>? assistantHeaders,
}) {
  final ov = _modelOverride(cfg, modelId);
  final automatic = <String, String>{...providerDefaultHeaders(cfg)};
  // AIhubmix promo header (opt-in per-provider)
  if (_isAihubmix(cfg) && cfg.aihubmixAppCodeEnabled == true) {
    automatic.putIfAbsent('APP-Code', () => _aihubmixAppCode);
  }
  return CustomRequestMerger.mergeHeaders(
    base: baseHeaders,
    assistant: assistantHeaders,
    providerAutomatic: automatic,
    provider: ModelOverridePayloadParser.customHeadersFromRows(
      cfg.customHeaders,
    ),
    model: ModelOverridePayloadParser.customHeaders(ov),
  );
}

Map<String, dynamic> customBody(
  ProviderConfig cfg,
  String modelId, {
  Map<String, dynamic>? assistantBody,
}) {
  final ov = _modelOverride(cfg, modelId);
  return CustomRequestMerger.mergeBody(
    assistant: assistantBody,
    providerRows: cfg.customBody,
    model: ModelOverridePayloadParser.customBody(ov),
  );
}

bool _isAihubmix(ProviderConfig cfg) {
  final base = cfg.baseUrl.toLowerCase();
  return base.contains('aihubmix.com');
}

// Resolve effective model info by respecting per-model overrides; fallback to inference
ModelInfo effectiveModelInfo(ProviderConfig cfg, String modelId) {
  final upstreamId = apiModelId(cfg, modelId);
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

String mimeFromPath(String path) {
  return inferMediaMimeFromSource(path, fallbackMime: 'image/png');
}

String mimeFromDataUrl(String dataUrl) {
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
Future<bool> _isValidRemoteImageUrl(String url) async {
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
Future<ParsedTextAndImages> parseTextAndImages(
  String raw, {
  required bool allowRemoteImages,
  required bool allowLocalImages,
  bool allowDataImages = true,
  bool keepRemoteMarkdownText = true,
  bool keepDisallowedImageText = true,
}) async {
  if (raw.isEmpty) return const ParsedTextAndImages('', <ImageRef>[]);
  final mdImg = RegExp(r'!\[[^\]]*\]\(([^)]+)\)');
  // Custom attachment markers are intentionally not recognized here.
  // Attachments arrive via structured parts / media-path keys.
  final images = <ImageRef>[];
  final buf = StringBuffer();
  int i = 0;
  while (i < raw.length) {
    // Skip fenced code blocks (``` or ~~~): content inside is never an image.
    if ((raw.startsWith('```', i) || raw.startsWith('~~~', i)) &&
        (i == 0 || raw[i - 1] == '\n')) {
      final fence = raw.substring(i, i + 3);
      buf.write(fence);
      i += 3;
      // Skip the rest of the opening fence line (language tag, etc.)
      while (i < raw.length && raw[i] != '\n') {
        buf.write(raw[i]);
        i++;
      }
      // Advance until the matching closing fence at the start of a line.
      bool closed = false;
      while (i < raw.length) {
        if (raw[i] == '\n') {
          buf.write(raw[i]);
          i++;
          if (raw.startsWith(fence, i)) {
            buf.write(fence);
            i += 3;
            // Skip trailing content on the closing fence line.
            while (i < raw.length && raw[i] != '\n') {
              buf.write(raw[i]);
              i++;
            }
            closed = true;
            break;
          }
        } else {
          buf.write(raw[i]);
          i++;
        }
      }
      if (!closed) {
        // Unclosed fence: rest of text was written as-is already.
      }
      continue;
    }
    // Skip inline code spans (backtick sequences).
    if (raw[i] == '`') {
      // Determine the length of the opening backtick sequence.
      int tickLen = 0;
      while (i + tickLen < raw.length && raw[i + tickLen] == '`') {
        tickLen++;
      }
      final openTicks = raw.substring(i, i + tickLen);
      buf.write(openTicks);
      i += tickLen;
      // Advance until the matching closing backtick sequence.
      bool closedTick = false;
      while (i < raw.length) {
        if (raw.startsWith(openTicks, i)) {
          buf.write(openTicks);
          i += tickLen;
          closedTick = true;
          break;
        }
        buf.write(raw[i]);
        i++;
      }
      if (!closedTick) {
        // Unclosed inline code: content was already written.
      }
      continue;
    }

    final m1 = mdImg.matchAsPrefix(raw, i);
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
        if (allowDataImages) {
          images.add(ImageRef('data', url));
        } else if (keepDisallowedImageText) {
          buf.write(full);
        }
        i = m1.end;
        continue;
      }
      // Remote http(s) URLs
      if (url.startsWith('http://') || url.startsWith('https://')) {
        if (!allowRemoteImages) {
          // Model does not accept image input (or we intentionally skip http images):
          // keep original markdown so the model can see the template.
          if (keepDisallowedImageText) buf.write(full);
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
        images.add(ImageRef('url', url));
        if (keepRemoteMarkdownText) {
          // Keep markdown so the model can see template syntax and URL.
          buf.write(full);
        }
        i = m1.end;
        continue;
      }
      // Local / relative path: only treat as image when the file exists.
      if (!allowLocalImages) {
        if (keepDisallowedImageText) buf.write(full);
        i = m1.end;
        continue;
      }
      try {
        final resolved = SandboxPathResolver.resolveForIo(url);
        if (resolved == null) {
          buf.write(full);
          i = m1.end;
          continue;
        }
        final file = File(resolved);
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
      images.add(ImageRef('path', url));
      // For real local files we keep previous behavior: only attach as image, omit markdown from text.
      i = m1.end;
      continue;
    }
    buf.write(raw[i]);
    i++;
  }
  return ParsedTextAndImages(buf.toString().trim(), images);
}

Future<String> _encodeBase64File(String path, {bool withPrefix = false}) async {
  final resolved = SandboxPathResolver.resolveForIo(path);
  if (resolved == null) {
    throw FileSystemException('rejected local path', path);
  }
  final file = File(resolved);
  final bytes = await file.readAsBytes();
  final b64 = base64Encode(bytes);
  if (withPrefix) {
    final mime = mimeFromPath(resolved);
    return 'data:$mime;base64,$b64';
  }
  return b64;
}

/// Like [_encodeBase64File], but returns null for missing/unreadable files
/// so provider request builders can skip unavailable attachments.
Future<String?> tryEncodeBase64File(
  String path, {
  bool withPrefix = false,
}) async {
  try {
    final resolved = SandboxPathResolver.resolveForIo(path);
    if (resolved == null) return null;
    final file = File(resolved);
    if (!await file.exists()) return null;
    return _encodeBase64File(resolved, withPrefix: withPrefix);
  } catch (_) {
    return null;
  }
}

String textFromContentParts(dynamic content) {
  if (content is String) return content.trim();
  if (content is! List) return (content ?? '').toString().trim();

  final buffer = StringBuffer();
  for (final part in content) {
    if (part is String) {
      buffer.write(part);
      continue;
    }
    if (part is! Map) continue;
    final type = (part['type'] ?? '').toString();
    if (type.isNotEmpty &&
        type != 'text' &&
        type != 'input_text' &&
        type != 'output_text') {
      continue;
    }
    final text = (part['text'] ?? part['content'] ?? '').toString();
    if (text.isEmpty) continue;
    if (buffer.isNotEmpty) buffer.write('\n');
    buffer.write(text);
  }
  return buffer.toString().trim();
}

bool isOff(int? budget) => (budget != null && budget != -1 && budget < 1024);
String effortForBudget(int? budget) {
  if (budget == null || budget == -1) return 'auto';
  if (isOff(budget)) return 'off';
  if (budget <= 2000) return 'low';
  if (budget <= 20000) return 'medium';
  return 'high';
}

bool isClaudeReasoningEnabled(int? budget) => budget != 0;

bool _isDeepSeekClaudeCompatible(String modelId, {ProviderConfig? config}) {
  final lowerModelId = modelId.trim().toLowerCase();
  if (lowerModelId.contains('deepseek')) return true;
  if (config == null) return false;
  final baseUrl = config.baseUrl.trim().toLowerCase();
  final providerId = config.id.trim().toLowerCase();
  final providerName = config.name.trim().toLowerCase();
  return baseUrl.contains('api.deepseek.com') ||
      providerId.contains('deepseek') ||
      providerName.contains('deepseek');
}

bool _isClaude5AdaptiveThinkingModel(String modelId) {
  return RegExp(
    r'claude-(?:opus|sonnet)-5(?:$|[._:@/-])',
    caseSensitive: false,
  ).hasMatch(modelId.trim());
}

bool _supportsClaudeAdaptiveThinking(String modelId) {
  final lower = modelId.trim().toLowerCase();
  if (!lower.contains('claude-')) return false;
  if (lower.contains('fable') || lower.contains('mythos')) return true;
  if (_isClaude5AdaptiveThinkingModel(lower)) return true;
  final m = RegExp(
    r'claude-(opus|sonnet)-(\d+)[-.](\d+)',
    caseSensitive: false,
  ).firstMatch(lower);
  if (m != null) {
    final major = int.tryParse(m.group(2) ?? '');
    final minor = int.tryParse(m.group(3) ?? '');
    if (major != null && minor != null) {
      return major > 4 || (major == 4 && minor >= 6);
    }
  }
  return lower.contains('4-6') || lower.contains('4.6');
}

bool _isClaudeAdaptiveOnlyThinkingModel(String modelId) {
  final lower = modelId.trim().toLowerCase();
  if (!lower.contains('claude-')) return false;
  if (lower.contains('fable') || lower.contains('mythos')) return true;
  if (_isClaude5AdaptiveThinkingModel(lower)) return true;
  final m = RegExp(
    r'claude-(opus|sonnet)-(\d+)[-.](\d+)',
    caseSensitive: false,
  ).firstMatch(lower);
  if (m == null) {
    return lower.contains('4-7') ||
        lower.contains('4.7') ||
        lower.contains('4-8') ||
        lower.contains('4.8');
  }
  final family = (m.group(1) ?? '').toLowerCase();
  final major = int.tryParse(m.group(2) ?? '');
  final minor = int.tryParse(m.group(3) ?? '');
  if (major == null || minor == null) return false;
  if (major > 4) return true;
  if (major < 4) return false;
  if (family == 'opus' && minor >= 7) return true;
  return false;
}

bool _isClaudeThinkingAlwaysOnModel(String modelId) {
  final lower = modelId.trim().toLowerCase();
  return lower.contains('claude-fable') || lower.contains('claude-mythos');
}

String _claudeEffortForBudget(int? budget) {
  if (budget == null || budget == -1) return 'auto';
  if (isOff(budget)) return 'off';
  if (budget <= 2000) return 'low';
  if (budget <= 20000) return 'medium';
  if (budget <= 32000) return 'high';
  if (budget <= 64000) return 'xhigh';
  return 'max';
}

String _normalizeClaudeEffort(String effort, String modelId) {
  final normalizedEffort = effort.trim().toLowerCase();
  if (normalizedEffort.isEmpty) return effort;
  if (normalizedEffort == 'auto' || normalizedEffort == 'off') {
    return normalizedEffort;
  }

  final lower = modelId.trim().toLowerCase();
  final supportsXhigh =
      _isClaude5AdaptiveThinkingModel(lower) ||
      lower.contains('claude-opus-4-7') ||
      lower.contains('claude-opus-4.7') ||
      lower.contains('claude-opus-4-8') ||
      lower.contains('claude-opus-4.8') ||
      lower.contains('claude-fable') ||
      lower.contains('claude-mythos');
  final supportsMax =
      supportsXhigh ||
      lower.contains('claude-opus-4-6') ||
      lower.contains('claude-opus-4.6') ||
      lower.contains('claude-sonnet-4-6') ||
      lower.contains('claude-sonnet-4.6') ||
      lower.contains('mythos');

  switch (normalizedEffort) {
    case 'max':
      if (supportsMax) return 'max';
      return supportsXhigh ? 'xhigh' : 'high';
    case 'xhigh':
      if (supportsXhigh) return 'xhigh';
      if (supportsMax) return 'max';
      return 'high';
    case 'high':
    case 'medium':
    case 'low':
      return normalizedEffort;
    default:
      return normalizedEffort;
  }
}

Map<String, dynamic>? claudeThinkingConfig(
  String modelId,
  int? budget, {
  ProviderConfig? config,
}) {
  if (_isClaudeThinkingAlwaysOnModel(modelId)) {
    if (!isClaudeReasoningEnabled(budget)) return null;
    return <String, dynamic>{'type': 'adaptive', 'display': 'summarized'};
  }
  if (!isClaudeReasoningEnabled(budget)) {
    return <String, dynamic>{'type': 'disabled'};
  }
  if (_isDeepSeekClaudeCompatible(modelId, config: config)) {
    return <String, dynamic>{'type': 'enabled'};
  }
  if (_supportsClaudeAdaptiveThinking(modelId)) {
    return <String, dynamic>{'type': 'adaptive', 'display': 'summarized'};
  }
  if (budget != null && budget > 0) {
    return <String, dynamic>{'type': 'enabled', 'budget_tokens': budget};
  }
  return <String, dynamic>{'type': 'disabled'};
}

Map<String, dynamic>? claudeOutputConfig(
  String modelId,
  int? budget, {
  ProviderConfig? config,
}) {
  if (_isClaudeThinkingAlwaysOnModel(modelId)) {
    final effort = _normalizeClaudeEffort(
      _claudeEffortForBudget(budget),
      modelId,
    );
    if (effort == 'auto' || effort == 'off') return null;
    return <String, dynamic>{'effort': effort};
  }
  if (_isDeepSeekClaudeCompatible(modelId, config: config)) {
    if (!isClaudeReasoningEnabled(budget)) return null;
    final effort = _claudeEffortForBudget(budget);
    if (effort == 'auto' || effort == 'off') return null;
    return <String, dynamic>{
      'effort': (effort == 'xhigh' || effort == 'max') ? 'max' : 'high',
    };
  }
  if (!_supportsClaudeAdaptiveThinking(modelId) ||
      !isClaudeReasoningEnabled(budget)) {
    return null;
  }
  final effort = _normalizeClaudeEffort(
    _claudeEffortForBudget(budget),
    modelId,
  );
  if (effort == 'auto' || effort == 'off') return null;
  return <String, dynamic>{'effort': effort};
}

bool claudeShouldOmitSamplingParams(String modelId, int? budget) {
  if (_isClaudeThinkingAlwaysOnModel(modelId)) return true;
  final lower = modelId.trim().toLowerCase();
  if (_isClaude5AdaptiveThinkingModel(lower) ||
      lower.contains('claude-opus-4-8') ||
      lower.contains('claude-opus-4.8')) {
    return true;
  }
  return _isClaudeAdaptiveOnlyThinkingModel(modelId) &&
      isClaudeReasoningEnabled(budget);
}

double? claudeCompatibleTopP(String modelId, int? budget, double? topP) {
  if (topP == null) return null;
  if (claudeShouldOmitSamplingParams(modelId, budget)) {
    return null;
  }
  if (!isClaudeReasoningEnabled(budget)) {
    return topP;
  }
  if (topP < 0.95 || topP > 1.0) {
    FlutterLogger.log(
      '[ClaudeCompat] Omit top_p=$topP because thinking requires 0.95 <= top_p <= 1.0.',
      tag: 'ChatApiService',
    );
    return null;
  }
  return topP;
}

// Clean JSON Schema for Google Gemini API strict validation
// Google requires array types to have 'items' field
Map<String, dynamic> cleanSchemaForGemini(Map<String, dynamic> schema) {
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
        if (propMap['type'] == 'object' && propMap.containsKey('properties')) {
          propMap['properties'] = cleanSchemaForGemini({
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
          props[name] = {'type': 'string'}; // Fallback to a simple string field
        }
      }
    }
    result['properties'] = props;
  }

  // Handle array items recursively
  if (result['items'] is Map) {
    result['items'] = cleanSchemaForGemini(
      result['items'] as Map<String, dynamic>,
    );
  }

  return result;
}

class ImageRef {
  final String kind; // 'data' | 'path' | 'url'
  final String src;
  final String? mime;
  const ImageRef(this.kind, this.src, {this.mime});
}

class ParsedTextAndImages {
  final String text;
  final List<ImageRef> images;
  const ParsedTextAndImages(this.text, this.images);
}

String mimeForInternalMediaRef(InternalMediaRef ref) {
  final explicit = ref.mime?.trim() ?? '';
  if (explicit.isNotEmpty) return explicit;
  final path = ref.uri;
  if (path.startsWith('data:')) return mimeFromDataUrl(path);
  return mimeFromPath(path);
}

List<InternalMediaRef> supplementalMediaRefs({
  required dynamic internalRaw,
  List<String>? userPaths,
  bool includeUserPaths = false,
}) {
  final refs = List<InternalMediaRef>.of(parseInternalMediaRefs(internalRaw));
  if (!includeUserPaths || userPaths == null || userPaths.isEmpty) {
    return refs;
  }
  final seen = <String>{for (final ref in refs) ref.uri};
  for (final path in userPaths) {
    final trimmed = path.trim();
    if (trimmed.isEmpty || !seen.add(trimmed)) continue;
    refs.add((uri: trimmed, mime: null, unavailable: false));
  }
  return refs;
}

Future<String?> tryEncodeBase64DataUrl(
  String path, {
  String? explicitMime,
}) async {
  final b64 = await tryEncodeBase64File(path, withPrefix: false);
  if (b64 == null) return null;
  final mime = (explicitMime != null && explicitMime.trim().isNotEmpty)
      ? explicitMime.trim()
      : mimeFromPath(path);
  return 'data:$mime;base64,$b64';
}

void logImageFallback({
  required String provider,
  required String model,
  required String reason,
}) {
  final message = 'provider=$provider model=$model reason=$reason';
  debugPrint('[ImageFallback] $message');
  FlutterLogger.log(message, tag: 'ImageFallback');
}

/// Some providers (e.g. OpenRouter rate limits/moderation) report failures as
/// an in-band `{"error": ...}` frame on an otherwise 2xx stream. Surface those
/// as a stream error so truncated output is not persisted as a completion.
///
/// OpenRouter's documented mid-stream failure frame carries the top-level
/// `error` alongside a non-empty `choices` list whose entry has
/// `finish_reason: "error"`, so the presence of choices/candidates must not
/// mask a non-empty error payload. Healthy chunks either lack the `error` key
/// or carry a null/empty placeholder, which [_throwOnInBandStreamError]
/// ignores.
void throwIfInBandStreamError(String data) {
  final mayCarryError =
      data.contains('"error"') ||
      data.contains('response.failed') ||
      data.contains('response.incomplete');
  if (!mayCarryError) return;
  Object? decoded;
  try {
    decoded = jsonDecode(data);
  } catch (_) {
    return;
  }
  if (decoded is! Map) return;
  final type = (decoded['type'] ?? '').toString();
  if (type == 'error') {
    // `event: error` frames: Anthropic-style ones nest the payload under
    // `error`, while the Responses API puts code/message on the frame itself
    // ({"type":"error","code":...,"message":...}).
    final nested = decoded['error'];
    if (nested is Map && nested.isNotEmpty) {
      _throwOnInBandStreamError(nested);
    }
    _throwOnInBandStreamError(decoded);
  }
  if (type == 'response.failed' || type == 'response.incomplete') {
    // Responses API terminal failure events nest the error under `response`.
    final response = decoded['response'];
    if (response is Map) {
      _throwOnInBandStreamError(response['error']);
      final details = response['incomplete_details'];
      if (details is Map && details.isNotEmpty) {
        final reason = (details['reason'] ?? '').toString().trim();
        throw HttpException(
          reason.isEmpty
              ? 'Provider error: response incomplete'
              : 'Provider error: response incomplete ($reason)',
        );
      }
    }
    // A failure event without a parseable payload still must not fall
    // through and be treated as a normal finish.
    throw HttpException('Provider error: $type');
  }
  _throwOnInBandStreamError(decoded['error']);
}

/// Throws when [error] carries a provider error payload; no-op for the null or
/// empty placeholders some providers emit on healthy chunks.
void _throwOnInBandStreamError(Object? error) {
  if (error is Map && error.isNotEmpty) {
    final message = (error['message'] ?? '').toString().trim();
    final code = (error['code'] ?? error['type'] ?? '').toString().trim();
    final detail = message.isNotEmpty ? message : jsonEncode(error);
    throw HttpException(
      code.isEmpty
          ? 'Provider error: $detail'
          : 'Provider error ($code): $detail',
    );
  }
  if (error is String && error.trim().isNotEmpty) {
    throw HttpException('Provider error: ${error.trim()}');
  }
}
