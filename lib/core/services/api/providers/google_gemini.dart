import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../providers/settings_provider.dart';
import '../chat_api_helpers.dart';
import '../stream/stream_chunk.dart';

import 'google_common.dart';

export 'google/gemini_thought_signature.dart';

/// Placeholder thought signature the Gemini API accepts when the original is
/// unavailable (e.g. legacy history persisted before signatures were captured).
/// Google once documented this value and its own Gemini CLI still sends it;
/// the current docs no longer list it, but the API keeps accepting it.
const String geminiDummyThoughtSignature =
    'context_engineering_is_the_way_to_go';
final RegExp _geminiThoughtSigComment = RegExp(
  r'<!--\s*gemini_thought_signatures:(.*?)-->',
  dotAll: true,
);

// YouTube URL regex: watch, shorts, embed, youtu.be (with optional timestamps)
final RegExp _youtubeUrlRegex = RegExp(
  r'(https?://(?:www\.)?(?:youtube\.com/(?:watch\?v=|shorts/|embed/)|youtu\.be/)[a-zA-Z0-9_-]+(?:[?&][^\s<>()]*)?)',
  caseSensitive: false,
);

List<String> extractYouTubeUrls(String text) {
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

/// Encodes a turn's thought signatures as the artifact payload: a bare JSON
/// object `{"text": {"k", "v"}, "images": [{"k", "v"}]}`. Returns '' when
/// there is nothing to keep.
///
/// Payloads written before the artifact existed wrapped the same JSON in an
/// HTML comment that travelled inside the message text;
/// [decodeGeminiThoughtSignature] still reads those.
String encodeGeminiThoughtSignature({
  String? textKey,
  dynamic textValue,
  List<Map<String, dynamic>> imageSigs = const <Map<String, dynamic>>[],
}) {
  final imgs = imageSigs
      .where((e) => (e['k'] ?? '').toString().isNotEmpty && e.containsKey('v'))
      .toList();
  final hasText = (textKey ?? '').isNotEmpty && textValue != null;
  if (!hasText && imgs.isEmpty) return '';
  final payload = <String, dynamic>{};
  if (hasText) payload['text'] = {'k': textKey, 'v': textValue};
  if (imgs.isNotEmpty) payload['images'] = imgs;
  return jsonEncode(payload);
}

/// Decodes an artifact payload written by [encodeGeminiThoughtSignature] or
/// by the legacy comment format, paired with [cleanedText]. Null when
/// [payload] holds no signature.
GeminiSignatureMeta? decodeGeminiThoughtSignature(
  Object? payload, {
  String cleanedText = '',
}) {
  if (payload is! String) return null;
  final trimmed = payload.trim();
  if (trimmed.isEmpty) return null;
  String json = trimmed;
  if (!trimmed.startsWith('{')) {
    final legacy = _geminiThoughtSigComment.firstMatch(trimmed);
    if (legacy == null) return null;
    json = (legacy.group(1) ?? '').trim();
  }
  final meta = _geminiMetaFromJson(json, cleanedText: cleanedText);
  return meta.hasAny ? meta : null;
}

/// Splits a legacy message text that still carries the signature comment
/// into the clean text and the signatures.
GeminiSignatureMeta extractGeminiThoughtMeta(String raw) {
  final m = _geminiThoughtSigComment.firstMatch(raw);
  if (m == null) return GeminiSignatureMeta(cleanedText: raw);
  final cleaned = raw.replaceRange(m.start, m.end, '').trimRight();
  return _geminiMetaFromJson((m.group(1) ?? '').trim(), cleanedText: cleaned);
}

GeminiSignatureMeta _geminiMetaFromJson(
  String json, {
  required String cleanedText,
}) {
  Map<String, dynamic> data = const <String, dynamic>{};
  try {
    data = (jsonDecode(json) as Map).cast<String, dynamic>();
  } catch (_) {
    return GeminiSignatureMeta(cleanedText: cleanedText);
  }
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
  return GeminiSignatureMeta(
    cleanedText: cleanedText,
    textKey: textKey,
    textValue: textVal,
    images: images,
  );
}

void applyGeminiThoughtSignatures(
  GeminiSignatureMeta meta,
  List<Map<String, dynamic>> parts, {
  bool attachDummyWhenMissing = false,
}) {
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
    const dummy = geminiDummyThoughtSignature;
    bool inlineFound = false;
    bool textTagged = false;
    for (final part in parts) {
      final hasText = part.containsKey('text');
      final hasInline =
          part.containsKey('inline_data') || part.containsKey('inlineData');
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

/// The artifact payload for the signatures found on [parts], or ''.
String collectGeminiThoughtSignatureFromParts(List<dynamic> parts) {
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
    final hasInline =
        p['inlineData'] is Map ||
        p['inline_data'] is Map ||
        p['fileData'] is Map ||
        p['file_data'] is Map;
    final isText =
        !hasInline && p['thought'] != true && p['functionCall'] is! Map;
    if (isText && sigKey != null && sigVal != null && textKey == null) {
      textKey = sigKey;
      textVal = sigVal;
    }
    if (hasInline && sigKey != null && sigVal != null) {
      images.add({'k': sigKey, 'v': sigVal});
    }
  }
  return encodeGeminiThoughtSignature(
    textKey: textKey,
    textValue: textVal,
    imageSigs: images,
  );
}

Stream<StreamChunk> sendGoogleGeminiStream(
  http.Client client,
  ProviderConfig config,
  String modelId,
  List<Map<String, dynamic>> messages, {
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
  bool skipImageParsing = false,
}) {
  final cfg = config.copyWith(vertexAI: false);
  return sendGoogleStream(
    client,
    cfg,
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
  );
}

class GeminiSignatureMeta {
  final String cleanedText;
  final String? textKey;
  final dynamic textValue;
  final List<Map<String, dynamic>> images;
  const GeminiSignatureMeta({
    required this.cleanedText,
    this.textKey,
    this.textValue,
    this.images = const <Map<String, dynamic>>[],
  });

  bool get hasText => (textKey ?? '').isNotEmpty && textValue != null;
  bool get hasImages => images.isNotEmpty;
  bool get hasAny => hasText || hasImages;
}
