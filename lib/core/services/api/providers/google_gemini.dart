part of '../chat_api_service.dart';

const String _geminiThoughtSigTag = 'gemini_thought_signatures';
final RegExp _geminiThoughtSigComment = RegExp(
  r'<!--\s*gemini_thought_signatures:(.*?)-->',
  dotAll: true,
);

// YouTube URL regex: watch, shorts, embed, youtu.be (with optional timestamps)
final RegExp _youtubeUrlRegex = RegExp(
  r'(https?://(?:www\.)?(?:youtube\.com/(?:watch\?v=|shorts/|embed/)|youtu\.be/)[a-zA-Z0-9_-]+(?:[?&][^\s<>()]*)?)',
  caseSensitive: false,
);

List<String> _extractYouTubeUrls(String text) {
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

_GeminiSignatureMeta _extractGeminiThoughtMeta(String raw) {
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
    return _GeminiSignatureMeta(
      cleanedText: cleaned,
      textKey: textKey,
      textValue: textVal,
      images: images,
    );
  } catch (_) {
    return _GeminiSignatureMeta(cleanedText: raw);
  }
}

String _buildGeminiThoughtSigComment({
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
  return '\n<!-- $_geminiThoughtSigTag:${jsonEncode(payload)} -->';
}

void _applyGeminiThoughtSignatures(
  _GeminiSignatureMeta meta,
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
    const dummy = 'context_engineering_is_the_way_to_go';
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

String _collectThoughtSigCommentFromParts(List<dynamic> parts) {
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
    final hasInline =
        p['inlineData'] is Map ||
        p['inline_data'] is Map ||
        p['fileData'] is Map ||
        p['file_data'] is Map;
    if (hasText && sigKey != null && textKey == null) {
      textKey = sigKey;
      textVal = sigVal;
    }
    if (hasInline && sigKey != null && sigVal != null) {
      images.add({'k': sigKey, 'v': sigVal});
    }
  }
  return _buildGeminiThoughtSigComment(
    textKey: textKey,
    textValue: textVal,
    imageSigs: images,
  );
}

// Simple container for parsed text + image refs

Stream<ChatStreamChunk> _sendGoogleGeminiStream(
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
}) {
  final cfg = config.copyWith(vertexAI: false);
  return _sendGoogleStream(
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
  );
}
