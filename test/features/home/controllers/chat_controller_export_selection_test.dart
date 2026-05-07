import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/features/home/controllers/chat_controller.dart';

ChatMessage _assistantMessage({
  required String id,
  String content = 'answer',
  String? reasoningSegmentsJson,
}) {
  return ChatMessage(
    id: id,
    role: 'assistant',
    content: content,
    conversationId: 'conversation-1',
    reasoningSegmentsJson: reasoningSegmentsJson,
  );
}

void main() {
  group('ChatController export selection', () {
    test('uses latest stored message metadata for selected exports', () {
      final visible = _assistantMessage(id: 'assistant-1');
      final latest = _assistantMessage(
        id: 'assistant-1',
        reasoningSegmentsJson: '{"segments":[{"text":"thinking"}]}',
      );

      final selected = ChatController.selectedCollapsedMessagesForExport(
        collapsedMessages: [visible],
        selectedIds: const {'assistant-1'},
        storedMessages: [latest],
      );

      expect(selected, hasLength(1));
      expect(
        selected.single.reasoningSegmentsJson,
        '{"segments":[{"text":"thinking"}]}',
      );
    });

    test('returns empty when no selected ids are provided', () {
      final selected = ChatController.selectedCollapsedMessagesForExport(
        collapsedMessages: [_assistantMessage(id: 'assistant-1')],
        selectedIds: const <String>{},
        storedMessages: [_assistantMessage(id: 'assistant-1')],
      );

      expect(selected, isEmpty);
    });

    test('falls back to visible message when storage has no matching id', () {
      final visible = _assistantMessage(
        id: 'assistant-1',
        content: 'visible fallback',
      );

      final selected = ChatController.selectedCollapsedMessagesForExport(
        collapsedMessages: [visible],
        selectedIds: const {'assistant-1'},
        storedMessages: const <ChatMessage>[],
      );

      expect(selected, [visible]);
    });
  });
}
