import 'dart:convert';

import '../../../core/models/message_part.dart';
import '../../../utils/mcp_structured_image.dart';

/// The completed tool rounds and the remaining assistant output of one reply.
/// Explicit response boundaries distinguish consecutive calls even when a
/// response has no text. Tool results stay attached to the calls they answer.
typedef AssistantToolHistory = ({
  List<Map<String, dynamic>> messages,
  String content,
  String? reasoning,
});

AssistantToolHistory buildAssistantToolHistory(List<MessagePart> parts) {
  final messages = <Map<String, dynamic>>[];
  var text = StringBuffer();
  var reasoning = StringBuffer();
  final tools = <Map<String, dynamic>>[];

  void flush([List<dynamic>? details]) {
    if (tools.isEmpty) return;
    // A cancelled batch is not a completed exchange. Keep preceding complete
    // batches, but never invent results for its unfinished calls.
    if (tools.every((tool) => tool['content'] != null)) {
      messages.add({
        'role': 'assistant',
        'content': text.toString(),
        'reasoning_content': reasoning.toString(),
        if (details != null) 'reasoning_details': details,
        'tool_calls': [
          for (final tool in tools)
            {
              'id': tool['id'],
              'type': 'function',
              'function': {
                'name': tool['name'],
                'arguments': tool['arguments'] is String
                    ? tool['arguments']
                    : jsonEncode(tool['arguments'] ?? {}),
              },
              if (tool['metadata'] != null) 'metadata': tool['metadata'],
            },
        ],
      });
      for (final tool in tools) {
        messages.add({
          'role': 'tool',
          'tool_call_id': tool['id'],
          'name': tool['name'],
          'content': toolResultContentForModel(tool['content'].toString()),
          if (tool['metadata'] != null) 'metadata': tool['metadata'],
        });
      }
      text = StringBuffer();
      reasoning = StringBuffer();
    }
    tools.clear();
  }

  final lastBoundary = parts.lastIndexWhere(
    (part) => part is AssistantRoundEndPart,
  );
  for (var index = 0; index < parts.length; index++) {
    final part = parts[index];
    // An unbounded tail (including output from other protocols) only records
    // part order. Keep its post-tool output after the results. Inside an
    // explicit response, text may arrive after calls but before execution.
    if (index > lastBoundary &&
        (part is TextPart && part.text.isNotEmpty ||
            part is ReasoningPart && part.text.isNotEmpty)) {
      flush();
    }
    if (part is TextPart) {
      if (part.text.isEmpty) continue;
      text.write(part.text);
    } else if (part is ReasoningPart) {
      if (part.text.isEmpty) continue;
      reasoning.write(part.text);
    } else if (part is ToolCallPart) {
      final Object? raw;
      try {
        raw = jsonDecode(part.payloadJson);
      } on FormatException {
        // Stored/imported tool payloads are losslessly hydrated. One damaged
        // card must not prevent replaying the rest of the conversation.
        continue;
      }
      if (raw is! Map) continue;
      final tool = Map<String, dynamic>.from(raw);
      if ((tool['id'] ?? '').toString().isEmpty ||
          (tool['name'] ?? '').toString().isEmpty) {
        continue;
      }
      tools.add(tool);
    } else if (part is AssistantRoundEndPart) {
      flush(part.reasoningDetails);
    }
  }
  flush();
  return (
    messages: messages,
    content: text.toString(),
    reasoning: reasoning.isEmpty ? null : reasoning.toString(),
  );
}
