import 'dart:convert';

import '../../../../models/token_usage.dart';
import '../../stream/sse_event.dart';
import '../../stream/stream_chunk.dart';
import '../../stream/stream_chunk_decoder.dart';
import '../../stream/stream_chunk_ids.dart';

class ResponsesFunctionCall {
  ResponsesFunctionCall({
    required this.index,
    required this.callId,
    required this.name,
    this.args = '',
  });

  final int index;
  String callId;
  String name;
  String args;

  Map<String, dynamic> get decodedArguments {
    try {
      return (jsonDecode(args.isEmpty ? '{}' : args) as Map)
          .cast<String, dynamic>();
    } catch (_) {
      return <String, dynamic>{};
    }
  }
}

class ResponsesPendingImage {
  const ResponsesPendingImage({
    required this.index,
    required this.base64,
    this.outputFormat = '',
  });

  final int index;
  final String base64;
  final String outputFormat;
}

/// Stateful OpenAI Responses SSE decoder. One instance per HTTP response.
class ResponsesStreamDecoder implements StreamChunkDecoder {
  ResponsesStreamDecoder({this.initialUsage, String sourceId = 'stream'})
    : usage = initialUsage,
      _ids = StreamChunkIds(sourceId);

  final TokenUsage? initialUsage;
  final StreamChunkIds _ids;
  TokenUsage? usage;
  bool completed = false;
  int approxCompletionChars = 0;

  List<Map<String, dynamic>> outputItems = const <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> citations = <Map<String, dynamic>>[];
  final Map<int, ResponsesFunctionCall> toolCallsByIndex =
      <int, ResponsesFunctionCall>{};
  final Map<String, ResponsesFunctionCall> toolCallsByKey =
      <String, ResponsesFunctionCall>{};
  final Map<int, ResponsesPendingImage> imagesByIndex =
      <int, ResponsesPendingImage>{};

  bool _closed = false;

  bool get hasFunctionCalls =>
      toolCallsByIndex.isNotEmpty || toolCallsByKey.isNotEmpty;

  List<ResponsesFunctionCall> takeFunctionCalls() {
    if (toolCallsByIndex.isNotEmpty) {
      final sorted = toolCallsByIndex.keys.toList()..sort();
      return [for (final index in sorted) toolCallsByIndex[index]!];
    }
    var index = 0;
    return [
      for (final entry in toolCallsByKey.entries)
        ResponsesFunctionCall(
          index: index++,
          callId: entry.key,
          name: entry.value.name,
          args: entry.value.args,
        ),
    ];
  }

  List<ResponsesPendingImage> takeImages() {
    final sorted = imagesByIndex.keys.toList()..sort();
    return [for (final index in sorted) imagesByIndex[index]!];
  }

  @override
  DecodeResult accept(SseEvent event) {
    if (_closed || completed) {
      return const DecodeResult(completed: true);
    }
    final data = event.data;
    if (data.isEmpty) return const DecodeResult();
    if (data == '[DONE]') {
      completed = true;
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
    try {
      _parseEvent(obj, chunks);
    } catch (_) {
      return const DecodeResult();
    }
    return DecodeResult(chunks: chunks, completed: completed);
  }

  @override
  List<StreamChunk> onClosed() {
    if (_closed) return const <StreamChunk>[];
    _closed = true;
    return const <StreamChunk>[];
  }

  void _parseEvent(Map<String, dynamic> obj, List<StreamChunk> chunks) {
    final type = obj['type'];
    if (type == 'response.output_text.delta') {
      final delta = obj['delta'];
      if (delta is String && delta.isNotEmpty) {
        approxCompletionChars += delta.length;
        chunks.add(TextDelta(id: _ids.text(), text: delta));
      }
      return;
    }
    if (type == 'response.reasoning_summary_text.delta' ||
        type == 'response.reasoning_text.delta') {
      final delta = obj['delta'];
      if (delta is String && delta.isNotEmpty) {
        chunks.add(ReasoningDelta(id: _ids.reasoning(), text: delta));
      }
      return;
    }
    if (type == 'response.output_item.added') {
      final item = obj['item'];
      final idx = (obj['output_index'] ?? 0) as int;
      if (item is Map && (item['type'] ?? '') == 'function_call') {
        toolCallsByIndex[idx] = ResponsesFunctionCall(
          index: idx,
          callId: (item['call_id'] ?? '').toString(),
          name: (item['name'] ?? '').toString(),
        );
      } else if (item is Map && _isImageGenerationType(item['type'])) {
        imagesByIndex.putIfAbsent(
          idx,
          () => ResponsesPendingImage(index: idx, base64: ''),
        );
      }
      return;
    }
    if (type == 'response.image_generation_call.partial_image') {
      final b64 = (obj['partial_image_b64'] ?? '').toString();
      if (b64.isNotEmpty) {
        final idx = (obj['output_index'] ?? 0) as int;
        imagesByIndex[idx] = ResponsesPendingImage(
          index: idx,
          base64: b64,
          outputFormat: (obj['output_format'] ?? '').toString(),
        );
      }
      return;
    }
    if (type == 'response.function_call_arguments.delta') {
      final idx = (obj['output_index'] ?? 0) as int;
      final delta = (obj['delta'] ?? '').toString();
      final entry = toolCallsByIndex.putIfAbsent(
        idx,
        () => ResponsesFunctionCall(index: idx, callId: '', name: ''),
      );
      if (delta.isNotEmpty) entry.args += delta;
      return;
    }
    if (type == 'response.output_item.done') {
      final item = obj['item'];
      final idx = (obj['output_index'] ?? 0) as int;
      if (item is Map && (item['type'] ?? '') == 'function_call') {
        final args = (item['arguments'] ?? '').toString();
        final entry = toolCallsByIndex.putIfAbsent(
          idx,
          () => ResponsesFunctionCall(
            index: idx,
            callId: (item['call_id'] ?? '').toString(),
            name: (item['name'] ?? '').toString(),
          ),
        );
        if (args.isNotEmpty) entry.args = args;
        if (entry.callId.isEmpty) {
          entry.callId = (item['call_id'] ?? '').toString();
        }
        if (entry.name.isEmpty) {
          entry.name = (item['name'] ?? '').toString();
        }
      } else if (item is Map && _isImageGenerationType(item['type'])) {
        final b64 = (item['result'] ?? '').toString();
        if (b64.isNotEmpty) {
          imagesByIndex[idx] = ResponsesPendingImage(
            index: idx,
            base64: b64,
            outputFormat: (item['output_format'] ?? '').toString(),
          );
        }
      }
      return;
    }
    if (type is String && type.contains('function_call')) {
      final id = (obj['id'] ?? obj['call_id'] ?? '').toString();
      final name = (obj['name'] ?? obj['function']?['name'] ?? '').toString();
      final argsDelta =
          (obj['arguments'] ?? obj['arguments_delta'] ?? obj['delta'] ?? '')
              .toString();
      if (id.isNotEmpty || name.isNotEmpty) {
        final key = id.isNotEmpty ? id : name;
        final entry = toolCallsByKey.putIfAbsent(
          key,
          () => ResponsesFunctionCall(index: 0, callId: key, name: name),
        );
        if (name.isNotEmpty) entry.name = name;
        if (argsDelta.isNotEmpty) entry.args += argsDelta;
      }
      return;
    }
    if (type == 'response.completed') {
      _onCompleted(obj, chunks);
      return;
    }

    final output = obj['output'];
    if (output is Map) {
      final content = (output['content'] ?? '').toString();
      if (content.isNotEmpty) {
        approxCompletionChars += content.length;
        chunks.add(TextDelta(id: _ids.text(), text: content));
      }
      if (obj['usage'] != null) {
        usage = _mergeUsage(usage, obj['usage']);
        if (usage != null) chunks.add(Usage(usage!));
      }
    }
  }

  void _onCompleted(Map<String, dynamic> obj, List<StreamChunk> chunks) {
    final response = obj['response'];
    if (response is Map) {
      final u = response['usage'];
      if (u != null) {
        usage = _mergeUsage(usage, u);
        if (usage != null) chunks.add(Usage(usage!));
      }
      final output = response['output'];
      outputItems = const <Map<String, dynamic>>[];
      if (output is List) {
        outputItems = [
          for (final it in output)
            if (it is Map) it.cast<String, dynamic>(),
        ];
        try {
          _collectCitations(output);
          _collectCompletedImages(output);
        } catch (_) {}
      }
    }
    completed = true;
  }

  void _collectCitations(List<dynamic> output) {
    citations.clear();
    var idx = 1;
    final seen = <String>{};
    for (final it in output) {
      if (it is! Map || it['type'] != 'message') continue;
      final content = it['content'];
      if (content is! List) continue;
      for (final block in content) {
        if (block is! Map) continue;
        final anns = block['annotations'] as List? ?? const <dynamic>[];
        for (final an in anns) {
          if (an is! Map) continue;
          if ((an['type'] ?? '') != 'url_citation') continue;
          final url = (an['url'] ?? '').toString();
          if (url.isEmpty || seen.contains(url)) continue;
          final title = (an['title'] ?? '').toString();
          citations.add(<String, dynamic>{
            'index': idx,
            'url': url,
            if (title.isNotEmpty) 'title': title,
          });
          seen.add(url);
          idx += 1;
        }
      }
    }
  }

  void _collectCompletedImages(List<dynamic> output) {
    for (var outputIndex = 0; outputIndex < output.length; outputIndex++) {
      final it = output[outputIndex];
      if (it is! Map || !_isImageGenerationType(it['type'])) continue;
      final b64 = (it['result'] ?? '').toString();
      if (b64.isEmpty) continue;
      imagesByIndex[outputIndex] = ResponsesPendingImage(
        index: outputIndex,
        base64: b64,
        outputFormat: (it['output_format'] ?? '').toString(),
      );
    }
  }
}

bool _isImageGenerationType(dynamic type) {
  return type == 'image_generation_call' ||
      type == 'openrouter:image_generation';
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
