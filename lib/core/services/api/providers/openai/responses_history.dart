import 'dart:convert';

import '../../../../models/model_spec.dart';
import '../../../../providers/settings_provider.dart';
import '../../../../utils/multimodal_input_utils.dart';
import '../../../../../utils/mcp_structured_image.dart';
import '../../chat_api_helpers.dart';
import '../../stream/stream_chunk.dart';
import '../../stream/stream_chunk_emit.dart';
import 'openai_tool_transcript.dart';

const responsesTurnArtifactKind = 'responses_turn';

/// Each request records its own cumulative rounds. A resumed message owns
/// earlier rounds too, so prepend its snapshot from before this request, not
/// the last upsert (which would duplicate rounds on every tool follow-up).
String appendResponsesTurn(String? prefix, String current) {
  if (prefix == null) return current;
  try {
    final previous = jsonDecode(prefix) as Map;
    final next = jsonDecode(current) as Map;
    for (final key in ['providerId', 'baseUrl', 'modelId']) {
      if (previous[key] != next[key]) return current;
    }
    return jsonEncode({
      ...next,
      'rounds': [...previous['rounds'] as List, ...next['rounds'] as List],
    });
  } catch (_) {
    return current;
  }
}

typedef ResponsesReplayScope = ({
  String providerId,
  String baseUrl,
  String modelId,
});

ResponsesReplayScope responsesReplayScope(
  ProviderConfig config,
  String modelId,
) => (
  providerId: config.id,
  baseUrl: config.baseUrl,
  modelId: apiModelId(config, modelId),
);

/// Records the native output of each response, including opaque reasoning.
/// Call ids map back to the stable ids used by persisted tool cards: a vendor
/// call_id can arrive after the card was created under a temporary stream id.
class ResponsesTurnRecorder {
  ResponsesTurnRecorder(this.scope);

  final ResponsesReplayScope scope;
  final _rounds = <Map<String, dynamic>>[];

  ProviderArtifact record(
    List<Map<String, dynamic>> output,
    List<EmitToolCall> calls,
  ) {
    _rounds.add({
      'output': output,
      'callIds': {
        for (final call in calls) openaiTranscriptCallId(call): call.id,
      },
    });
    return ProviderArtifact(
      kind: responsesTurnArtifactKind,
      payload: jsonEncode({
        'providerId': scope.providerId,
        'baseUrl': scope.baseUrl,
        'modelId': scope.modelId,
        'rounds': _rounds,
      }),
    );
  }
}

String responsesMessageText(Map item) {
  if (item['type'] != 'message') return '';
  return _contentText(item);
}

String _contentText(Map item) {
  final content = item['content'];
  if (content is String) return content;
  if (content is! List) return '';
  return content
      .whereType<Map>()
      .where(
        (part) =>
            part['type'] == 'output_text' ||
            part['type'] == 'text' ||
            part['type'] == 'reasoning_text',
      )
      .map((part) => (part['text'] ?? '').toString())
      .join();
}

/// Filter only history supplied to a new request. Native outputs produced
/// during its live tool loop are appended separately and remain intact.
/// Assistant items between user/tool messages belong to one response; hosted
/// calls count as tool rounds as well as client function calls.
List<Map<String, dynamic>> filterResponsesReasoningHistory(
  List<Map<String, dynamic>> messages,
  ReasoningReplayPolicy replay,
) {
  if (replay == ReasoningReplayPolicy.all) return messages;
  final out = <Map<String, dynamic>>[];
  final response = <Map<String, dynamic>>[];
  void flush() {
    final keepThinking =
        replay == ReasoningReplayPolicy.toolTurns &&
        response.any((message) {
          final calls = message['tool_calls'];
          final item = message[multimodalInternalResponsesItemKey];
          final type = item is Map ? (item['type'] ?? '').toString() : '';
          return (calls is List && calls.isNotEmpty) ||
              type.endsWith('_call') ||
              type == 'openrouter:image_generation';
        });
    for (final message in response) {
      final item = message[multimodalInternalResponsesItemKey];
      if (keepThinking || item is! Map || item['type'] != 'reasoning') {
        out.add(message);
      }
    }
    response.clear();
  }

  for (final message in messages) {
    if (message['role'] == 'assistant') {
      response.add(message);
    } else {
      flush();
      out.add(message);
    }
  }
  flush();
  return out;
}

/// Projects native items into the app's history envelope. Tool results still
/// use the ordinary tool-message path so image capabilities and local assets
/// are resolved for the current request. Each item keeps its original place.
List<Map<String, dynamic>>? buildResponsesHistory({
  required String? payload,
  required ResponsesReplayScope scope,
  required List<Map<String, dynamic>> toolEvents,
  required String content,
}) {
  if (payload == null) return null;
  try {
    final stored = jsonDecode(payload) as Map;
    if (stored['providerId'] != scope.providerId ||
        stored['baseUrl'] != scope.baseUrl ||
        stored['modelId'] != scope.modelId) {
      return null;
    }
    final rounds = (stored['rounds'] as List).cast<Map>();
    final recordedText = rounds
        .expand((round) => (round['output'] as List).cast<Map>())
        .map(responsesMessageText)
        .join();
    // An edited reply owns its text; don't restore the original provider text
    // over that edit. A stream cut short may have an additional unrecorded tail.
    if (!content.startsWith(recordedText)) return null;

    final messages = <Map<String, dynamic>>[];
    final emittedText = StringBuffer();
    final remainingEvents = List<Map<String, dynamic>>.of(toolEvents);
    for (final round in rounds) {
      final output = (round['output'] as List).cast<Map>();
      final calls = output.where((item) => item['type'] == 'function_call');
      final callIds = round['callIds'] as Map;
      final results = <Map<String, dynamic>>[];
      var complete = true;
      for (final call in calls) {
        final callId = call['call_id'];
        final localId = callIds[callId] ?? callId;
        final index = remainingEvents.indexWhere(
          (event) => event['id'] == localId,
        );
        if (index < 0 || remainingEvents[index]['content'] == null) {
          complete = false;
          break;
        }
        final event = remainingEvents.removeAt(index);
        results.add({
          'role': 'tool',
          'tool_call_id': callId,
          'name': call['name'],
          'content': toolResultContentForModel(event['content'].toString()),
          if (event['metadata'] != null) 'metadata': event['metadata'],
        });
      }
      // A cancelled batch cannot be replayed, including reasoning that belongs
      // to its calls. Keep earlier complete exchanges and the visible tail.
      if (!complete) break;
      for (final item in output) {
        final text = responsesMessageText(item);
        emittedText.write(text);
        messages.add({
          'role': 'assistant',
          'content': text,
          // The shared context preview reads these fields. The Responses
          // adapter sends only the native item, without duplicating either.
          if (item['type'] == 'reasoning' && item['content'] != null)
            'reasoning_content': _contentText(item),
          if (item['type'] == 'function_call')
            'tool_calls': [
              {
                'id': item['call_id'],
                'type': 'function',
                'function': {
                  'name': item['name'],
                  'arguments': item['arguments'],
                },
              },
            ],
          multimodalInternalResponsesItemKey: Map<String, dynamic>.from(item),
        });
      }
      messages.addAll(results);
    }
    final tail = content.substring(emittedText.length);
    if (tail.isNotEmpty) messages.add({'role': 'assistant', 'content': tail});
    return messages;
  } catch (_) {
    return null;
  }
}

/// Preserve native fields while honoring assistant text transformations (for
/// example regex rules) applied after history assembly. Reasoning stays opaque.
Map<String, dynamic> responsesInputItem(Map<String, dynamic> message) {
  final item = Map<String, dynamic>.from(
    message[multimodalInternalResponsesItemKey] as Map,
  );
  final text = (message['content'] ?? '').toString();
  if (item['type'] == 'message' && text != responsesMessageText(item)) {
    if (item['content'] is String) {
      item['content'] = text;
      return item;
    }
    var replaced = false;
    final parts = <Map>[];
    for (final part in (item['content'] as List).cast<Map>()) {
      if (part['type'] == 'output_text' || part['type'] == 'text') {
        if (!replaced) parts.add({...part, 'text': text});
        replaced = true;
      } else {
        parts.add(part);
      }
    }
    item['content'] = parts;
  }
  return item;
}
