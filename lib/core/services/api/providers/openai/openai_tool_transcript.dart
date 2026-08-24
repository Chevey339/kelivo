import 'dart:convert';

import '../../chat_api_helpers.dart';
import '../../generation/tool_loop_runner.dart';
import '../../stream/stream_chunk_emit.dart';

String openaiTranscriptCallId(EmitToolCall call) {
  final providerId = call.providerCallId?.trim() ?? '';
  if (providerId.isNotEmpty) return providerId;
  return call.id;
}

List<EmitToolCall> clientToolCallsFromChatAcc(Map<dynamic, dynamic> toolAcc) {
  final calls = <EmitToolCall>[];
  final keys = toolAcc.keys.toList()
    ..sort((a, b) {
      final ai = a is int ? a : int.tryParse(a.toString()) ?? 0;
      final bi = b is int ? b : int.tryParse(b.toString()) ?? 0;
      return ai.compareTo(bi);
    });
  for (final key in keys) {
    final raw = toolAcc[key];
    if (raw is! Map) continue;
    final vendorId = (raw['id'] ?? '').toString().trim();
    final seriesId = (raw['series_id'] ?? '').toString().trim();
    final id = seriesId.isNotEmpty
        ? seriesId
        : effectiveToolCallId(raw['id'], 'call', key);
    final name = (raw['name'] ?? '').toString();
    Map<String, dynamic> arguments;
    try {
      arguments = (jsonDecode((raw['args'] ?? '{}').toString()) as Map)
          .cast<String, dynamic>();
    } catch (_) {
      arguments = <String, dynamic>{};
    }
    calls.add(
      emitToolCall(
        id: id,
        name: name,
        arguments: arguments,
        metadata: openaiMetadataForExtraContent(
          raw['extra_content'] ??
              _openaiExtraContentFromMetadata(raw['metadata']),
        ),
        providerCallId: vendorId.isNotEmpty ? vendorId : null,
      ),
    );
  }
  return calls;
}

List<Map<String, dynamic>> openaiToolCallMaps(List<EmitToolCall> calls) {
  final out = <Map<String, dynamic>>[];
  for (final call in calls) {
    final extra = _openaiExtraContentFromMetadata(call.metadata);
    out.add(<String, dynamic>{
      'id': openaiTranscriptCallId(call),
      'type': 'function',
      'function': <String, dynamic>{
        'name': call.name,
        'arguments': jsonEncode(call.arguments),
      },
      if (extra != null) 'extra_content': extra,
    });
  }
  return out;
}

Map<String, dynamic>? openaiMetadataForExtraContent(dynamic extraContent) {
  final extra = _openaiExtraContentFrom(extraContent);
  if (extra == null) return null;
  return <String, dynamic>{
    'google': <String, dynamic>{'extra_content': extra},
  };
}

Map<String, dynamic> openaiToolCallForRequest(
  Map toolCall, {
  bool includeGoogleExtraContent = true,
}) {
  final copy = toolCall.map((key, value) => MapEntry(key.toString(), value));
  final extra =
      _openaiExtraContentFrom(copy['extra_content']) ??
      _openaiExtraContentFromMetadata(copy['metadata']);
  copy.remove('metadata');
  if (extra != null && includeGoogleExtraContent) {
    copy['extra_content'] = extra;
  } else {
    copy.remove('extra_content');
  }
  return copy;
}

Map<String, dynamic>? _openaiExtraContentFromMetadata(dynamic metadata) {
  if (metadata is! Map) return null;
  final fromMeta = _openaiExtraContentFrom(metadata['extra_content']);
  if (fromMeta != null) return fromMeta;
  final google = metadata['google'];
  if (google is Map) {
    return _openaiExtraContentFrom(google['extra_content']);
  }
  return null;
}

Map<String, dynamic>? _openaiExtraContentFrom(dynamic value) {
  if (value is! Map || value.isEmpty) return null;
  return value.map((key, item) => MapEntry(key.toString(), item));
}

List<Map<String, dynamic>> openaiToolResultMessages(
  List<ExecutedClientTool> executed,
) {
  return [
    for (final item in executed)
      <String, dynamic>{
        'role': 'tool',
        'tool_call_id': openaiTranscriptCallId(item.call),
        'name': item.call.name,
        'content': item.content,
      },
  ];
}
