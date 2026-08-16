import 'dart:convert';

import '../../../../models/token_usage.dart';
import '../../stream/sse_event.dart';
import '../../stream/stream_chunk.dart';
import '../../stream/stream_chunk_decoder.dart';
import '../../stream/stream_chunk_ids.dart';

/// Stateful OpenAI Chat Completions SSE decoder. One instance per HTTP response.
class ChatCompletionsStreamDecoder implements StreamChunkDecoder {
  ChatCompletionsStreamDecoder({
    this.wantsImageOutput = false,
    this.needsReasoningEcho = false,
    this.allowReasoningSnapshots = true,
    this.initialUsage,
    String sourceId = 'stream',
  }) : usage = initialUsage,
       _ids = StreamChunkIds(sourceId);

  final bool wantsImageOutput;
  final bool needsReasoningEcho;
  final bool allowReasoningSnapshots;
  final TokenUsage? initialUsage;
  final StreamChunkIds _ids;

  TokenUsage? usage;
  String? finishReason;
  int approxCompletionChars = 0;
  String reasoningEcho = '';
  String assistantContent = '';
  final Map<int, Map<String, String>> toolCalls = <int, Map<String, String>>{};

  final List<dynamic> _details = <dynamic>[];
  final Map<int, String> _toolIdsByIndex = <int, String>{};
  final Set<String> _openToolIds = <String>{};
  final Set<String> _endedToolIds = <String>{};
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
      return DecodeResult(chunks: _endOpenTools(), completed: true);
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
    if (_completed) return const <StreamChunk>[];
    return _endOpenTools();
  }

  void _parseEvent(Map<String, dynamic> obj, List<StreamChunk> chunks) {
    var content = '';
    String? reasoning;
    final pendingImages = <dynamic>[];
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
            pendingImages.addAll(_imageItems(delta));
          }
          _accumulateToolCalls(delta['tool_calls'], chunks);
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
              pendingImages.addAll([
                for (final it in message['content'] as List)
                  if (it is Map &&
                      (it['type'] == 'image_url' || it['type'] == 'image'))
                    it,
              ]);
            }
          }
          if (delta is! Map || delta['tool_calls'] == null) {
            _ingestCompleteToolCalls(message['tool_calls'], chunks);
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
        final eventId = _toolSeriesId(idx, vendorId: id);
        final entry = toolCalls.putIfAbsent(
          idx,
          () => <String, String>{'id': '', 'name': '', 'args': ''},
        );
        entry['id'] = id.isNotEmpty ? id : eventId;
        entry['name'] = name;
        entry['args'] = argsStr;
        chunks.addAll(
          _emitCompleteToolCall(eventId, name: name, args: argsStr),
        );
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
      final searchId = _ids.searchSticky();
      chunks.add(ServerToolStart(id: searchId, toolName: 'search_web'));
      chunks.add(
        ServerToolEnd(id: searchId, output: <String, dynamic>{'items': items}),
      );
    }

    if (reasoning != null && reasoning.isNotEmpty) {
      chunks.add(ReasoningDelta(id: _ids.reasoning(), text: reasoning));
    }
    if (content.isNotEmpty) {
      assistantContent += content;
      chunks.add(TextDelta(id: _ids.text(), text: content));
    }
    if (pendingImages.isNotEmpty) {
      chunks.addAll(_emitImages(pendingImages));
    }
    if (finishReason == 'tool_calls') {
      chunks.addAll(_endOpenTools());
    }
  }

  void _accumulateToolCalls(dynamic raw, List<StreamChunk> chunks) {
    if (raw is! List) return;
    for (final t in raw) {
      if (t is! Map) continue;
      final idx = (t['index'] as int?) ?? 0;
      final vendorId = (t['id'] as String?)?.trim() ?? '';
      final func = t['function'];
      final name = func is Map ? func['name'] as String? : null;
      final argsDelta = func is Map ? func['arguments'] as String? : null;
      final firstSeen = !toolCalls.containsKey(idx);
      final entry = toolCalls.putIfAbsent(
        idx,
        () => <String, String>{'id': '', 'name': '', 'args': ''},
      );
      final eventId = _toolSeriesId(idx, vendorId: vendorId);
      if (vendorId.isNotEmpty) {
        entry['id'] = vendorId;
      } else if ((entry['id'] ?? '').isEmpty) {
        entry['id'] = eventId;
      }
      final hadName = (entry['name'] ?? '').isNotEmpty;
      if (name != null && name.isNotEmpty) entry['name'] = name;
      if (argsDelta != null && argsDelta.isNotEmpty) {
        entry['args'] = (entry['args'] ?? '') + argsDelta;
      }
      if (_openToolIds.add(eventId) && !_endedToolIds.contains(eventId)) {
        chunks.add(
          ToolCallStart(id: eventId, toolName: entry['name'] ?? name ?? ''),
        );
      } else if (!firstSeen && !hadName && name != null && name.isNotEmpty) {
        chunks.add(ToolCallDelta(id: eventId, toolNameDelta: name));
      }
      if (argsDelta != null && argsDelta.isNotEmpty) {
        chunks.add(ToolCallDelta(id: eventId, inputDelta: argsDelta));
      }
    }
  }

  void _ingestCompleteToolCalls(dynamic raw, List<StreamChunk> chunks) {
    if (raw is! List) return;
    for (final t in raw) {
      if (t is! Map) continue;
      final idx = (t['index'] as int?) ?? toolCalls.length;
      final id = (t['id'] ?? '').toString();
      final func = t['function'];
      if (func is! Map) continue;
      final name = (func['name'] ?? '').toString();
      final argsStr = (func['arguments'] ?? '').toString();
      if (name.isEmpty) continue;
      final eventId = _toolSeriesId(idx, vendorId: id);
      final entry = toolCalls.putIfAbsent(
        idx,
        () => <String, String>{'id': '', 'name': '', 'args': ''},
      );
      entry['id'] = id.isNotEmpty ? id : eventId;
      entry['name'] = name;
      entry['args'] = argsStr;
      chunks.addAll(_emitCompleteToolCall(eventId, name: name, args: argsStr));
    }
    if (raw.isNotEmpty) {
      finishReason ??= 'tool_calls';
    }
  }

  String _toolSeriesId(int index, {String vendorId = ''}) {
    final existing = _toolIdsByIndex[index];
    if (existing != null) return existing;
    final id = vendorId.isNotEmpty ? vendorId : _ids.next('tool');
    _toolIdsByIndex[index] = id;
    return id;
  }

  List<StreamChunk> _emitCompleteToolCall(
    String id, {
    required String name,
    required String args,
  }) {
    if (_endedToolIds.contains(id)) return const <StreamChunk>[];
    final chunks = <StreamChunk>[];
    if (_openToolIds.add(id)) {
      chunks.add(ToolCallStart(id: id, toolName: name));
    }
    if (args.isNotEmpty) {
      chunks.add(ToolCallDelta(id: id, inputDelta: args));
    }
    chunks.addAll(_endTool(id));
    return chunks;
  }

  List<StreamChunk> _endTool(String id) {
    _openToolIds.remove(id);
    if (!_endedToolIds.add(id)) return const <StreamChunk>[];
    return <StreamChunk>[ToolCallEnd(id)];
  }

  List<StreamChunk> _emitImages(List<dynamic> imageItems) {
    final chunks = <StreamChunk>[];
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
      if (url == null || url.isEmpty) continue;
      final mime = mimeTypeFromImageUri(url) ?? 'image/png';
      final uri = completeRenderableImageUri(url, mimeType: mime);
      final id = _ids.next('image');
      chunks.add(ImageStart(id: id, mimeType: mime));
      chunks.add(ImageSnapshot(id: id, data: uri));
      chunks.add(ImageEnd(id));
    }
    return chunks;
  }

  List<StreamChunk> _endOpenTools() {
    if (_openToolIds.isEmpty) return const <StreamChunk>[];
    final chunks = <StreamChunk>[];
    for (final id in _openToolIds.toList()) {
      chunks.addAll(_endTool(id));
    }
    return chunks;
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

List<dynamic> _imageItems(Map delta) {
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
  return imageItems;
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
