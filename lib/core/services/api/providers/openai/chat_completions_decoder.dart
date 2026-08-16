import 'dart:convert';

import '../../../../models/token_usage.dart';
import '../../stream/sse_event.dart';
import '../../stream/stream_chunk.dart';
import '../../stream/stream_chunk_decoder.dart';

/// Stateful OpenAI Chat Completions SSE decoder. One instance per HTTP response.
class ChatCompletionsStreamDecoder implements StreamChunkDecoder {
  ChatCompletionsStreamDecoder({
    this.wantsImageOutput = false,
    this.needsReasoningEcho = false,
    this.allowReasoningSnapshots = true,
    this.initialUsage,
  }) : usage = initialUsage;

  final bool wantsImageOutput;
  final bool needsReasoningEcho;
  final bool allowReasoningSnapshots;
  final TokenUsage? initialUsage;

  TokenUsage? usage;
  String? finishReason;
  int approxCompletionChars = 0;
  String reasoningEcho = '';
  String assistantContent = '';
  final Map<int, Map<String, String>> toolCalls = <int, Map<String, String>>{};

  final List<dynamic> _details = <dynamic>[];
  bool _snapshotMode = false;
  bool _closed = false;
  bool _completed = false;

  List<dynamic>? get reasoningDetails => _details.isEmpty ? null : _details;

  @override
  DecodeResult accept(SseEvent event) {
    if (_closed || _completed) {
      return const DecodeResult(completed: true);
    }
    final data = event.data;
    if (data.isEmpty) return const DecodeResult();
    if (data == '[DONE]') {
      _completed = true;
      return const DecodeResult(completed: true);
    }

    late final Map<String, dynamic> obj;
    try {
      final decoded = jsonDecode(data);
      if (decoded is! Map) return const DecodeResult();
      obj = decoded.cast<String, dynamic>();
    } catch (_) {
      return const DecodeResult();
    }

    final chunks = <StreamChunk>[];
    _parseEvent(obj, chunks);
    return DecodeResult(chunks: chunks, completed: _completed);
  }

  @override
  List<StreamChunk> onClosed() {
    if (_closed) return const <StreamChunk>[];
    _closed = true;
    return const <StreamChunk>[];
  }

  void _parseEvent(Map<String, dynamic> obj, List<StreamChunk> chunks) {
    var content = '';
    String? reasoning;
    final choices = obj['choices'];
    if (choices is List && choices.isNotEmpty) {
      final c0 = choices[0];
      if (c0 is Map) {
        final fr = c0['finish_reason'];
        finishReason = fr is String ? fr : null;
        final message = c0['message'];
        final delta = c0['delta'];
        if (delta is Map) {
          final deltaContent = _extractDeltaText(delta);
          if (deltaContent.isNotEmpty) {
            content += deltaContent;
            approxCompletionChars += deltaContent.length;
          }
          final rc = delta['reasoning_content'] ?? delta['reasoning'];
          if (rc is String && rc.isNotEmpty) {
            reasoning = rc;
            if (needsReasoningEcho) reasoningEcho += rc;
          }
          final rdDelta = delta['reasoning_details'];
          if (rdDelta is List && rdDelta.isNotEmpty) {
            _addReasoningDetails(rdDelta);
          }
          if (wantsImageOutput) {
            content += _imageMarkdown(delta);
          }
          _accumulateToolCalls(delta['tool_calls']);
        }
        if (message is Map) {
          final rdMsg = message['reasoning_details'];
          if (rdMsg is List && rdMsg.isNotEmpty) {
            _addReasoningDetails(rdMsg);
          }
          if (message['content'] != null) {
            final messageContent = _messageText(message['content']);
            if (messageContent.isNotEmpty) {
              content += messageContent;
              approxCompletionChars += messageContent.length;
            }
            final rcMsg = message['reasoning_content'] ?? message['reasoning'];
            if (rcMsg is String && rcMsg.isNotEmpty) {
              if (needsReasoningEcho) reasoningEcho += rcMsg;
              reasoning ??= rcMsg;
            }
            if (wantsImageOutput && message['content'] is List) {
              content += _imageMarkdownFromList([
                for (final it in message['content'] as List)
                  if (it is Map &&
                      (it['type'] == 'image_url' || it['type'] == 'image'))
                    it,
              ]);
            }
          }
        }
      }
    }

    final rootToolCalls = obj['tool_calls'];
    if (rootToolCalls is List) {
      for (final t in rootToolCalls) {
        if (t is! Map) continue;
        final id = (t['id'] ?? '').toString();
        final type = (t['type'] ?? 'function').toString();
        if (type != 'function') continue;
        final func = t['function'];
        if (func is! Map) continue;
        final name = (func['name'] ?? '').toString();
        final argsStr = (func['arguments'] ?? '').toString();
        if (name.isEmpty) continue;
        final idx = toolCalls.length;
        final entry = toolCalls.putIfAbsent(
          idx,
          () => <String, String>{
            'id': _effectiveToolCallId(id, 'call', idx),
            'name': name,
            'args': argsStr,
          },
        );
        if (id.isNotEmpty) entry['id'] = id;
        entry['name'] = name;
        entry['args'] = argsStr;
      }
      if (rootToolCalls.isNotEmpty) {
        finishReason = 'tool_calls';
      }
    }

    if (obj.containsKey('usage')) {
      usage = _mergeUsage(usage, obj['usage']);
    }

    final citations = obj['citations'];
    if (citations is List && citations.isNotEmpty) {
      final items = <Map<String, dynamic>>[
        for (var k = 0; k < citations.length; k++)
          <String, dynamic>{
            'index': k + 1,
            'url': citations[k].toString(),
            'title': citations[k].toString(),
          },
      ];
      chunks.add(
        const ServerToolStart(id: 'builtin_search', toolName: 'search_web'),
      );
      chunks.add(
        ServerToolEnd(
          id: 'builtin_search',
          output: <String, dynamic>{'items': items},
        ),
      );
    }

    if (reasoning != null && reasoning.isNotEmpty) {
      chunks.add(ReasoningDelta(id: 'reasoning', text: reasoning));
    }
    if (content.isNotEmpty) {
      assistantContent += content;
      chunks.add(TextDelta(id: 'text', text: content));
    }
  }

  void _accumulateToolCalls(dynamic raw) {
    if (raw is! List) return;
    for (final t in raw) {
      if (t is! Map) continue;
      final idx = (t['index'] as int?) ?? 0;
      final id = t['id'] as String?;
      final func = t['function'];
      final name = func is Map ? func['name'] as String? : null;
      final argsDelta = func is Map ? func['arguments'] as String? : null;
      final entry = toolCalls.putIfAbsent(
        idx,
        () => <String, String>{'id': '', 'name': '', 'args': ''},
      );
      if (id != null) entry['id'] = id;
      if (name != null && name.isNotEmpty) entry['name'] = name;
      if (argsDelta != null && argsDelta.isNotEmpty) {
        entry['args'] = (entry['args'] ?? '') + argsDelta;
      }
    }
  }

  void _addReasoningDetails(List<dynamic> incoming) {
    if (incoming.isEmpty) return;
    if (_details.isEmpty) {
      _details.addAll(incoming);
      return;
    }
    final prefixMatches =
        allowReasoningSnapshots && _hasCurrentAsPrefix(incoming);
    if (prefixMatches && incoming.length > _details.length) {
      _snapshotMode = true;
      _details
        ..clear()
        ..addAll(incoming);
      return;
    }
    if (_snapshotMode && prefixMatches) return;
    _details.addAll(incoming);
  }

  bool _hasCurrentAsPrefix(List<dynamic> incoming) {
    if (incoming.length < _details.length) return false;
    for (var i = 0; i < _details.length; i++) {
      if (jsonEncode(_details[i]) != jsonEncode(incoming[i])) return false;
    }
    return true;
  }
}

String _extractDeltaText(Map? delta) {
  if (delta == null) return '';
  final deltaType = (delta['type'] ?? '').toString();
  if (deltaType == 'response.audio.delta') return '';
  final content = delta['content'];
  if (content is String) return content;
  if (content is List) {
    final buffer = StringBuffer();
    for (final item in content) {
      if (item is! Map) continue;
      final text = (item['text'] ?? item['delta'] ?? '').toString();
      final type = (item['type'] ?? '').toString();
      if (text.isEmpty) continue;
      if (type.isEmpty || type == 'text') buffer.write(text);
    }
    return buffer.toString();
  }
  return '';
}

String _messageText(dynamic mc) {
  if (mc is String) return mc;
  if (mc is List) {
    final sb = StringBuffer();
    for (final it in mc) {
      if (it is! Map) continue;
      final t = (it['text'] ?? '') as String? ?? '';
      if (t.isNotEmpty && (it['type'] == null || it['type'] == 'text')) {
        sb.write(t);
      }
    }
    return sb.toString();
  }
  return (mc ?? '').toString();
}

String _imageMarkdown(Map delta) {
  final imageItems = <dynamic>[];
  final imgs = delta['images'];
  if (imgs is List) imageItems.addAll(imgs);
  final dc = delta['content'];
  if (dc is List) {
    for (final it in dc) {
      if (it is Map && (it['type'] == 'image_url' || it['type'] == 'image')) {
        imageItems.add(it);
      }
    }
  }
  final singleImage = delta['image_url'];
  if (singleImage is Map || singleImage is String) {
    imageItems.add(<String, dynamic>{
      'type': 'image_url',
      'image_url': singleImage,
    });
  }
  return _imageMarkdownFromList(imageItems);
}

String _imageMarkdownFromList(List<dynamic> imageItems) {
  final buf = StringBuffer();
  for (final it in imageItems) {
    if (it is! Map) continue;
    final iu = it['image_url'];
    String? url;
    if (iu is String) {
      url = iu;
    } else if (iu is Map) {
      final u2 = iu['url'];
      if (u2 is String) url = u2;
    }
    if (url != null && url.isNotEmpty) {
      buf.write('\n\n![image]($url)');
    }
  }
  return buf.toString();
}

TokenUsage? _mergeUsage(TokenUsage? current, dynamic rawUsage) {
  if (rawUsage is! Map) return current;
  final details =
      rawUsage['prompt_tokens_details'] ?? rawUsage['input_tokens_details'];
  final cachedTokens = details is Map ? _readInt(details['cached_tokens']) : 0;
  return (current ?? const TokenUsage()).merge(
    TokenUsage(
      promptTokens: _readInt(
        rawUsage['prompt_tokens'] ?? rawUsage['input_tokens'],
      ),
      completionTokens: _readInt(
        rawUsage['completion_tokens'] ?? rawUsage['output_tokens'],
      ),
      cachedTokens: cachedTokens,
    ),
  );
}

int _readInt(dynamic value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

String _effectiveToolCallId(
  dynamic rawId,
  String fallbackPrefix,
  Object index,
) {
  final id = rawId?.toString().trim() ?? '';
  if (id.isNotEmpty) return id;
  return '${fallbackPrefix}_${DateTime.now().microsecondsSinceEpoch}_$index';
}
