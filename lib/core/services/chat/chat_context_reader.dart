import 'dart:convert';
import '../../models/compression_config.dart';
import '../../database/generation_run.dart';
import '../../models/chat_message.dart';
import '../../models/message_part.dart';
import '../../../utils/utf16_safe_cut.dart';

const readChatContextDefinition = <String, dynamic>{
  'type': 'function',
  'function': {
    'name': 'read_chat_context',
    'description':
        'Read a referenced original tool result from the visible selected history of this conversation. Read-only; never executes the tool again.',
    'parameters': {
      'type': 'object',
      'properties': {
        'source_id': {'type': 'string'},
        'offset': {'type': 'integer', 'minimum': 0},
      },
      'required': ['source_id'],
      'additionalProperties': false,
    },
  },
};

/// The original selected message parts remain the storage authority. Handles
/// authorize only references actually emitted by this generation.
class ChatContextReader {
  ChatContextReader(this.loadVisibleHistory);
  final Future<List<ChatMessage>> Function() loadVisibleHistory;
  final _references = <String, ({String messageId, int ordinal})>{};

  Future<Map<String, String>> replacements(Set<String> consumed) async {
    final result = <String, String>{};
    final seen = <String>{};
    final ambiguous = <String>{};
    for (final message in await loadVisibleHistory()) {
      for (var i = 0; i < message.parts.length; i++) {
        final part = message.parts[i];
        if (part is! ToolCallPart) continue;
        final tool = _tool(part);
        final id = tool?['id']?.toString();
        if (id != null && !seen.add(id)) ambiguous.add(id);
        if (tool == null ||
            id == null ||
            tool['content'] == null ||
            tool['name'] == 'read_chat_context') {
          continue;
        }
        final consumedInHistory =
            message.generationState == GenerationRunState.completed ||
            // The first boundary closes the response that requested this tool,
            // before its result is consumed. A later boundary proves a follow-up.
            message.parts
                    .skip(i + 1)
                    .whereType<AssistantRoundEndPart>()
                    .length >
                1;
        if (!consumed.contains(id) && !consumedInHistory) continue;
        final body = tool['content'].toString();
        if (body.length < 1500) continue;
        final source = contextTextReference(message.id, i, id);
        _references[source] = (messageId: message.id, ordinal: i);
        result[id] =
            '[Tool ${tool['name'] ?? 'unknown'}; call $id; completed; '
            'status=${tool['error'] == null ? 'see original result' : 'error'}. '
            'Previously consumed result: $source. Read with read_chat_context(source_id="$source", offset=0).]';
      }
    }
    // Imported or provider-created turns can reuse a call ID. Never let an
    // older result replacement hide the newest unread result with that ID.
    for (final id in ambiguous) {
      result.remove(id);
    }
    return result;
  }

  Future<String> read(String source, int offset) async {
    final reference = _references[source];
    if (reference == null) return 'Context reference is unavailable.';
    final messages = await loadVisibleHistory();
    final message = messages
        .where((m) => m.id == reference.messageId)
        .firstOrNull;
    if (message == null || reference.ordinal >= message.parts.length) {
      return 'Context reference is no longer visible.';
    }
    final part = message.parts[reference.ordinal];
    if (part is! ToolCallPart) {
      return 'Context reference is no longer available.';
    }
    final tool = _tool(part);
    if (tool == null) return 'Context reference is unreadable.';
    if (contextTextReference(
          message.id,
          reference.ordinal,
          tool['id']?.toString() ?? '',
        ) !=
        source) {
      return 'Context reference has changed.';
    }
    final text = (tool['content'] ?? '').toString();
    final start = utf16SafeTailStart(text, offset.clamp(0, text.length));
    final page = truncateHeadUtf16Safe(text.substring(start), 6000);
    return jsonEncode({
      'source_id': source,
      'tool': tool['name'],
      'call_id': tool['id'],
      'offset': start,
      'content': page,
      'next_offset': start + page.length < text.length
          ? start + page.length
          : null,
    });
  }

  Map? _tool(ToolCallPart part) {
    try {
      final value = jsonDecode(part.payloadJson);
      return value is Map ? value : null;
    } on FormatException {
      return null;
    }
  }
}
