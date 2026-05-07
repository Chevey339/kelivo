import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/features/settings/services/debug_conversation_factory.dart';

void main() {
  group('DebugConversationFactory', () {
    test(
      'creates an oversized conversation at or above the target byte size',
      () {
        final seed = DebugConversationFactory.createOversizedConversation(
          title: 'large',
          assistantId: 'assistant-1',
          chunkText: '性能测试内容 abc 123 ',
          targetBytes: 64 * 1024,
        );

        expect(seed.totalContentBytes, greaterThanOrEqualTo(64 * 1024));
        expect(seed.conversation.assistantId, 'assistant-1');
        expect(seed.messages, isNotEmpty);
        expect(seed.conversation.messageIds, [
          for (final message in seed.messages) message.id,
        ]);
        expect(
          seed.messages.every(
            (message) =>
                message.conversationId == seed.conversation.id &&
                !message.isStreaming &&
                message.content.isNotEmpty,
          ),
          isTrue,
        );
      },
    );

    test(
      'creates exactly 1024 alternating messages for the current assistant',
      () {
        final seed = DebugConversationFactory.createManyMessagesConversation(
          title: 'many',
          assistantId: 'assistant-2',
          contentBuilder: (index, role) => '$role-$index',
        );

        expect(seed.conversation.assistantId, 'assistant-2');
        expect(seed.messages, hasLength(1024));
        expect(seed.conversation.messageIds, [
          for (final message in seed.messages) message.id,
        ]);

        for (var index = 0; index < seed.messages.length; index++) {
          final message = seed.messages[index];
          expect(message.role, index.isEven ? 'user' : 'assistant');
          expect(message.conversationId, seed.conversation.id);
          expect(message.groupId, message.id);
        }
      },
    );

    test('rejects invalid generation sizes', () {
      expect(
        () => DebugConversationFactory.createOversizedConversation(
          title: 'invalid',
          assistantId: null,
          chunkText: 'x',
          targetBytes: 0,
        ),
        throwsArgumentError,
      );

      expect(
        () => DebugConversationFactory.createManyMessagesConversation(
          title: 'invalid',
          assistantId: null,
          contentBuilder: (index, role) => '$role-$index',
          messageCount: 0,
        ),
        throwsArgumentError,
      );
    });
  });
}
