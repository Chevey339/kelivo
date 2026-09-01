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
    Future<Object?> Function(
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

/// Whether [raw] should be scanned for Markdown images.
///
/// Utility / text-only requests (compress, title, summary) pass
/// [skipImageParsing] so `![...](...)` stays literal text.
bool shouldParseMarkdownImages(String raw, {required bool skipImageParsing}) {
  if (skipImageParsing) return false;
  return raw.contains('![') && raw.contains('](');
}

Future<ParsedTextAndImages> parseTextAndImages(
  String raw, {
  required bool allowRemoteImages,
  required bool allowLocalImages,
  bool allowDataImages = true,
  // Whether `![alt](http…)` keeps its Markdown text — both when the image is
  // extracted and when [allowRemoteImages] is false. A remote link carries no
  // payload, so dropping it would silently delete part of the user's text.
  bool keepRemoteMarkdownText = true,
  // Whether disallowed data: URLs and local paths keep their Markdown text.
  // Those carry a payload a text-only request has no use for.
  bool keepDisallowedImageText = true,
  bool skipImageParsing = false,
}) async {
  if (raw.isEmpty) return const ParsedTextAndImages('', <ImageRef>[]);
  // Utility / text-only prompts (title, summary, compress) must keep
  // `![...](...)` as literal text and never walk the Markdown scanner.
  if (skipImageParsing || !raw.contains('![')) {
    return ParsedTextAndImages(raw.trim(), const <ImageRef>[]);
  }
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
      final openNl = raw.indexOf('\n', i);
      if (openNl < 0) {
        buf.write(raw.substring(i));
        i = raw.length;
        continue;
      }
      buf.write(raw.substring(i, openNl + 1));
      i = openNl + 1;
      while (i < raw.length) {
        if (raw.startsWith(fence, i)) {
          buf.write(fence);
          i += 3;
          final closeNl = raw.indexOf('\n', i);
          if (closeNl < 0) {
            buf.write(raw.substring(i));
            i = raw.length;
          } else {
            buf.write(raw.substring(i, closeNl));
            i = closeNl;
          }
          break;
        }
        final lineNl = raw.indexOf('\n', i);
        if (lineNl < 0) {
          buf.write(raw.substring(i));
          i = raw.length;
          break;
        }
        buf.write(raw.substring(i, lineNl + 1));
        i = lineNl + 1;
      }
      continue;
    }
    // Skip inline code spans (backtick sequences).
    if (raw[i] == '`') {
      int tickLen = 0;
      while (i + tickLen < raw.length && raw[i + tickLen] == '`') {
        tickLen++;
      }
      final openTicks = raw.substring(i, i + tickLen);
      buf.write(openTicks);
      i += tickLen;
      final close = raw.indexOf(openTicks, i);
      if (close < 0) {
        buf.write(raw.substring(i));
        i = raw.length;
      } else {
        buf.write(raw.substring(i, close + tickLen));
        i = close + tickLen;
      }
      continue;
    }

    if (i + 1 < raw.length &&
        raw.codeUnitAt(i) == 0x21 &&
        raw.codeUnitAt(i + 1) == 0x5B) {
      final m1 = mdImg.matchAsPrefix(raw, i);
      if (m1 != null) {
        final full = raw.substring(m1.start, m1.end);
        final url = (m1.group(1) ?? '').trim();
        if (url.isEmpty) {
          buf.write(full);
          i = m1.end;
          continue;
        }
        if (url.startsWith('data:')) {
          if (allowDataImages) {
            images.add(ImageRef('data', url));
          } else if (keepDisallowedImageText) {
            buf.write(full);
          }
          i = m1.end;
          continue;
        }
        if (url.startsWith('http://') || url.startsWith('https://')) {
          if (!allowRemoteImages) {
            if (keepRemoteMarkdownText) buf.write(full);
            i = m1.end;
            continue;
          }
          final ok = await _isValidRemoteImageUrl(url);
          if (!ok) {
            buf.write(full);
            i = m1.end;
            continue;
          }
          images.add(ImageRef('url', url));
          if (keepRemoteMarkdownText) {
            buf.write(full);
          }
          i = m1.end;
          continue;
        }
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
            buf.write(full);
            i = m1.end;
            continue;
          }
        } catch (_) {
          buf.write(full);
          i = m1.end;
          continue;
        }
        images.add(ImageRef('path', url));
        i = m1.end;
        continue;
      }
    }

    // Single-pass: walk forward to the next newline, backtick, or `![`.
    // Do not indexOf the remaining suffix on every line — that is O(n²)
    // when a Markdown image sits near the end of a long document.
    var j = i;
    while (j < raw.length) {
      final c = raw.codeUnitAt(j);
      if (c == 0x0A || c == 0x60) break;
      if (c == 0x21 && j + 1 < raw.length && raw.codeUnitAt(j + 1) == 0x5B) {
        break;
      }
      j++;
    }
    if (j == i) {
      buf.writeCharCode(raw.codeUnitAt(i));
      i++;
      continue;
    }
    buf.write(raw.substring(i, j));
    i = j;
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
  if (ProviderConfig.isDeepSeekClaudeCompatible(modelId, config: config)) {
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
  if (ProviderConfig.isDeepSeekClaudeCompatible(modelId, config: config)) {
    if (!isClaudeReasoningEnabled(budget)) return null;
    final effort = _claudeEffortForBudget(budget);
    if (effort == 'auto' || effort == 'off') return null;
    // Official Anthropic-format effort is low / high / max.
    // medium and xhigh map to high.
    // https://api-docs.deepseek.com/guides/thinking_mode
    final mapped = switch (effort) {
      'low' => 'low',
      'max' => 'max',
      _ => 'high',
    };
    return <String, dynamic>{'effort': mapped};
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
// Google requires array types to have 'items' field, and only accepts `enum`
// on string-typed schemas (values must be strings too).
Map<String, dynamic> cleanSchemaForGemini(
  Map<String, dynamic> schema, {
  bool stringEnumOnly = false,
}) {
  return _cleanSchemaNode(schema, stringEnumOnly) as Map<String, dynamic>;
}

/// JSON Schema scalar type of [value], or null when it is not a scalar.
String? _scalarTypeOf(dynamic value) {
  if (value is String) return 'string';
  if (value is bool) return 'boolean';
  if (value is int) return 'integer';
  if (value is num) return 'number';
  return null;
}

/// JSON Schema type of [value], including the composite and null kinds.
String? _jsonTypeOf(dynamic value) {
  if (value == null) return 'null'; // Gemini's Schema.type accepts NULL
  if (value is Map) return 'object';
  if (value is List) return 'array';
  return _scalarTypeOf(value);
}

/// Infer the JSON Schema scalar type shared by [values], or null when they are
/// mixed / empty. Used to type an `enum` that came without a `type`.
String? _inferScalarType(List<dynamic> values) {
  if (values.isEmpty) return null;
  String? type;
  for (final v in values) {
    final t = _scalarTypeOf(v);
    if (t == null) return null;
    if (type == null) {
      type = t;
    } else if (type != t) {
      // integer and number can coexist in one numeric enum
      if ((type == 'integer' && t == 'number') ||
          (type == 'number' && t == 'integer')) {
        type = 'number';
      } else {
        return null;
      }
    }
  }
  return type;
}

dynamic _cleanSchemaNode(dynamic node, bool stringEnumOnly) {
  if (node is! Map) return node;
  final result = Map<String, dynamic>.from(node);

  final declaredType = (result['type'] ?? '').toString();

  // Gemini only validates `enum` against TYPE_STRING; a boolean/number enum
  // (common in remote MCP schemas) is rejected outright.
  if (stringEnumOnly && result['enum'] is List) {
    final values = (result['enum'] as List);
    // An untyped enum still carries its type in the values: only stringify
    // when they really are strings, otherwise the tool would receive "true"
    // instead of true and fail the remote server's own validation.
    final inferred = declaredType.isNotEmpty ? null : _inferScalarType(values);
    if (declaredType == 'string' || inferred == 'string') {
      result['type'] = 'string';
      result['enum'] = values.map((e) => e?.toString() ?? '').toList();
    } else if (declaredType.isNotEmpty || inferred != null) {
      // A non-string enum cannot be expressed to Gemini; keep the type only.
      if (declaredType.isEmpty) result['type'] = inferred;
      result.remove('enum');
    } else {
      // Heterogeneous (or unrepresentable) values: fall back to a string enum,
      // but keep only the members that already were strings. Stringifying the
      // rest would advertise values the remote server is bound to reject.
      final strings = values.whereType<String>().toList();
      if (strings.isNotEmpty) {
        result['type'] = 'string';
        result['enum'] = strings;
      } else {
        // No string member at all: a string schema would be disjoint from every
        // accepted value, so keep a type that at least one member really has.
        // `type` is required by Gemini, so fall back to a composite kind rather
        // than leaving the node untyped.
        final fallback =
            values
                .map(_scalarTypeOf)
                .firstWhere((t) => t != null, orElse: () => null) ??
            values
                .map(_jsonTypeOf)
                .firstWhere((t) => t != null, orElse: () => null) ??
            'string';
        result['type'] = fallback;
        result.remove('enum');
      }
    }
  }

  // The enum handling above can settle a type on a previously untyped node.
  final type = (result['type'] ?? '').toString();

  // Recursively fix 'properties' if present
  Map<String, dynamic> props = const <String, dynamic>{};
  if (result['properties'] is Map) {
    props = Map<String, dynamic>.from(result['properties'] as Map);
  } else if (type == 'object') {
    // Ensure objects always have a properties map for Gemini validation
    props = <String, dynamic>{};
  }
  if (props.isNotEmpty || type == 'object') {
    props.updateAll((key, value) => _cleanSchemaNode(value, stringEnumOnly));

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

  // Handle array items recursively; arrays always need an items schema
  if (result['items'] is Map) {
    result['items'] = _cleanSchemaNode(result['items'], stringEnumOnly);
  } else if (type == 'array' && !result.containsKey('items')) {
    result['items'] = {'type': 'string'}; // Default to string array
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
