import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../models/token_usage.dart';
import 'sse_event.dart';
import 'stream_chunk.dart';

/// Load framed SSE events from an `events.jsonl` fixture.
List<SseEvent> loadSseEventsJsonl(String source) {
  return [
    for (final line in source.split('\n'))
      if (line.trim().isNotEmpty)
        SseEvent.fromJson((jsonDecode(line) as Map).cast<String, dynamic>()),
  ];
}

String encodeSseEventsJsonl(Iterable<SseEvent> events) {
  final buffer = StringBuffer();
  for (final event in events) {
    buffer.writeln(jsonEncode(event.toJson()));
  }
  return buffer.toString();
}

/// Stable semantic snapshot of decoder output. Image bytes are hashed;
/// timestamps and bulky vendor metadata are dropped.
Map<String, dynamic> streamTraceSnapshot({
  required List<StreamChunk> chunks,
  TokenUsage? usage,
  bool completed = false,
  Map<String, dynamic>? extras,
}) {
  final textBuf = StringBuffer();
  final reasoningBuf = StringBuffer();
  final toolCalls = <Map<String, dynamic>>[];
  final serverTools = <Map<String, dynamic>>[];
  final images = <Map<String, dynamic>>[];
  TokenUsage? seenUsage = usage;

  for (final chunk in chunks) {
    switch (chunk) {
      case TextDelta(:final text):
        textBuf.write(text);
      case ReasoningDelta(:final text):
        reasoningBuf.write(text);
      case ToolCallStart(:final id, :final toolName):
        toolCalls.add(<String, dynamic>{
          'id': id,
          'name': toolName,
          'phase': 'start',
        });
      case ToolCallEnd(:final id):
        toolCalls.add(<String, dynamic>{'id': id, 'phase': 'end'});
      case ServerToolStart(:final id, :final toolName):
        serverTools.add(<String, dynamic>{
          'id': id,
          'name': toolName,
          'phase': 'start',
        });
      case ServerToolEnd(:final id, :final output, :final status):
        serverTools.add(<String, dynamic>{
          'id': id,
          'status': status.name,
          'phase': 'end',
          if (output != null) 'output': _stableJson(output),
        });
      case ImageStart(:final id, :final mimeType):
        images.add(<String, dynamic>{
          'id': id,
          'mimeType': mimeType,
          'phase': 'start',
        });
      case ImageDelta(:final id, :final data):
        images.add(_imageDigest(id: id, data: data, phase: 'delta'));
      case ImageSnapshot(:final id, :final data):
        images.add(_imageDigest(id: id, data: data, phase: 'snapshot'));
      case ImageEnd(:final id):
        images.add(<String, dynamic>{'id': id, 'phase': 'end'});
      case Usage(:final usage):
        seenUsage = usage;
      default:
        break;
    }
  }

  return <String, dynamic>{
    'text': textBuf.toString(),
    'reasoning': reasoningBuf.toString(),
    'toolCalls': toolCalls,
    'serverTools': serverTools,
    'images': images,
    'chunks': [for (final chunk in chunks) _chunkSnapshot(chunk)],
    'finishCount': chunks.whereType<Finish>().length,
    'completed': completed,
    if (seenUsage != null)
      'usage': <String, dynamic>{
        'promptTokens': seenUsage.promptTokens,
        'completionTokens': seenUsage.completionTokens,
        'cachedTokens': seenUsage.cachedTokens,
        'totalTokens': seenUsage.totalTokens,
      },
    if (extras != null && extras.isNotEmpty) 'extras': extras,
  };
}

String encodeTraceSnapshot(Map<String, dynamic> snapshot) {
  return const JsonEncoder.withIndent('  ').convert(snapshot);
}

Map<String, dynamic> _chunkSnapshot(StreamChunk chunk) {
  return switch (chunk) {
    TextStart(:final id) => <String, dynamic>{'type': 'text_start', 'id': id},
    TextDelta(:final id, :final text) => <String, dynamic>{
      'type': 'text_delta',
      'id': id,
      'text': text,
    },
    TextEnd(:final id) => <String, dynamic>{'type': 'text_end', 'id': id},
    ReasoningStart(:final id, :final reasoningType) => <String, dynamic>{
      'type': 'reasoning_start',
      'id': id,
      'reasoningType': reasoningType.name,
    },
    ReasoningDelta(
      :final id,
      :final text,
      :final reasoningType,
      :final details,
    ) =>
      <String, dynamic>{
        'type': 'reasoning_delta',
        'id': id,
        'text': text,
        'reasoningType': reasoningType.name,
        if (details != null) 'details': _stableJson(details),
      },
    ReasoningEnd(:final id) => <String, dynamic>{
      'type': 'reasoning_end',
      'id': id,
    },
    ToolCallStart(:final id, :final toolName) => <String, dynamic>{
      'type': 'tool_call_start',
      'id': id,
      'name': toolName,
    },
    ToolCallDelta(:final id, :final toolNameDelta, :final inputDelta) =>
      <String, dynamic>{
        'type': 'tool_call_delta',
        'id': id,
        if (toolNameDelta.isNotEmpty) 'nameDelta': toolNameDelta,
        if (inputDelta.isNotEmpty) 'inputDelta': inputDelta,
      },
    ToolCallEnd(:final id) => <String, dynamic>{
      'type': 'tool_call_end',
      'id': id,
    },
    ServerToolStart(:final id, :final toolName) => <String, dynamic>{
      'type': 'server_tool_start',
      'id': id,
      'name': toolName,
    },
    ServerToolInputDelta(:final id, :final inputDelta) => <String, dynamic>{
      'type': 'server_tool_input_delta',
      'id': id,
      'inputDelta': inputDelta,
    },
    ServerToolInputEnd(:final id) => <String, dynamic>{
      'type': 'server_tool_input_end',
      'id': id,
    },
    ServerToolEnd(:final id, :final status, :final output) => <String, dynamic>{
      'type': 'server_tool_end',
      'id': id,
      'status': status.name,
      if (output != null) 'output': _stableJson(output),
    },
    ImageStart(:final id, :final mimeType) => <String, dynamic>{
      'type': 'image_start',
      'id': id,
      'mimeType': mimeType,
    },
    ImageDelta(:final id, :final data) => _imageDigest(
      id: id,
      data: data,
      phase: 'delta',
    )..['type'] = 'image_delta',
    ImageSnapshot(:final id, :final data) => _imageDigest(
      id: id,
      data: data,
      phase: 'snapshot',
    )..['type'] = 'image_snapshot',
    ImageEnd(:final id) => <String, dynamic>{'type': 'image_end', 'id': id},
    Annotations(:final annotations) => <String, dynamic>{
      'type': 'annotations',
      'items': [
        for (final annotation in annotations)
          if (annotation is UrlCitationAnnotation)
            <String, dynamic>{
              'type': 'url_citation',
              'url': annotation.url,
              if (annotation.title.isNotEmpty) 'title': annotation.title,
            },
      ],
    },
    Usage(:final usage) => <String, dynamic>{
      'type': 'usage',
      'promptTokens': usage.promptTokens,
      'completionTokens': usage.completionTokens,
      'cachedTokens': usage.cachedTokens,
      'totalTokens': usage.totalTokens,
    },
    Finish(:final finishReason) => <String, dynamic>{
      'type': 'finish',
      if (finishReason != null) 'finishReason': finishReason,
    },
  };
}

Map<String, dynamic> _imageDigest({
  required String id,
  required String data,
  required String phase,
}) {
  final bytes = _tryDecodeBase64(data);
  return <String, dynamic>{
    'id': id,
    'phase': phase,
    'byteCount': bytes.length,
    'sha256': sha256.convert(bytes).toString(),
  };
}

List<int> _tryDecodeBase64(String data) {
  try {
    return base64Decode(data);
  } catch (_) {
    return utf8.encode(data);
  }
}

Object _stableJson(Object? value) {
  if (value == null) return const <String, dynamic>{};
  if (value is String) {
    try {
      return _stableJson(jsonDecode(value));
    } catch (_) {
      return value;
    }
  }
  if (value is Map) {
    final keys = value.keys.map((k) => k.toString()).toList()..sort();
    return <String, dynamic>{
      for (final key in keys) key: _stableJson(value[key]),
    };
  }
  if (value is List) {
    return [for (final item in value) _stableJson(item)];
  }
  return value;
}
