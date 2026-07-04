import 'package:flutter_test/flutter_test.dart';

import 'package:Cuplivo/core/models/chat_message.dart';
import 'package:Cuplivo/features/home/services/message_generation_service.dart';

ChatMessage _message({
  required String id,
  required String role,
  required String groupId,
}) {
  return ChatMessage(
    id: id,
    role: role,
    content: '$role-$id',
    conversationId: 'conversation-1',
    groupId: groupId,
  );
}

void main() {
  group('MessageGenerationService.collectTrailingMessageIdsForRemoval', () {
    test('删除截断点之后不属于保留分组的消息', () {
      final messages = <ChatMessage>[
        _message(id: 'u1', role: 'user', groupId: 'u1'),
        _message(id: 'a1-v0', role: 'assistant', groupId: 'a1'),
        _message(id: 'u2', role: 'user', groupId: 'u2'),
        _message(id: 'a2-v0', role: 'assistant', groupId: 'a2'),
        _message(id: 'a1-v1', role: 'assistant', groupId: 'a1'),
      ];

      final result =
          MessageGenerationService.collectTrailingMessageIdsForRemoval(
            messages: messages,
            lastKeep: 1,
            targetGroupId: 'a1',
          );

      expect(result, ['u2', 'a2-v0']);
    });

    test('截断点已经在底部时不删除消息', () {
      final messages = <ChatMessage>[
        _message(id: 'u1', role: 'user', groupId: 'u1'),
        _message(id: 'a1-v0', role: 'assistant', groupId: 'a1'),
      ];

      final result =
          MessageGenerationService.collectTrailingMessageIdsForRemoval(
            messages: messages,
            lastKeep: 1,
            targetGroupId: 'a1',
          );

      expect(result, isEmpty);
    });
  });
}
