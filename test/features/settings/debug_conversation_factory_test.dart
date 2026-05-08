import 'dart:convert';

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

    test('creates a long reasoning conversation with assistant thinking', () {
      final seed = DebugConversationFactory.createLongReasoningConversation(
        title: 'reasoning',
        assistantId: 'assistant-thinking',
        messageCount: 64,
      );

      expect(seed.conversation.assistantId, 'assistant-thinking');
      expect(seed.messages, hasLength(64));
      expect(seed.conversation.messageIds, [
        for (final message in seed.messages) message.id,
      ]);

      final assistantMessages = seed.messages.where(
        (message) => message.role == 'assistant',
      );
      expect(assistantMessages, hasLength(32));
      for (final message in assistantMessages) {
        expect(message.reasoningText, isNotEmpty);
        expect(message.reasoningStartAt, isNotNull);
        expect(message.reasoningFinishedAt, isNotNull);
        expect(message.reasoningSegmentsJson, contains('"segments"'));

        final reasoningPayload =
            jsonDecode(message.reasoningSegmentsJson!) as Map<String, dynamic>;
        final segments = reasoningPayload['segments'] as List<dynamic>;
        final firstSegment = segments.first as Map<String, dynamic>;
        expect(firstSegment['text'], message.reasoningText);

        final contentSplits =
            reasoningPayload['contentSplits'] as Map<String, dynamic>;
        expect(contentSplits['offsets'], [0]);
        expect(contentSplits['reasoningCounts'], [1]);
        expect(contentSplits['toolCounts'], [0]);
      }
    });

    test('creates 3000 mixed daily markdown messages', () {
      final seed =
          DebugConversationFactory.createDailyMixedMarkdownConversation(
            title: 'daily mixed',
            assistantId: 'assistant-daily',
          );

      expect(seed.conversation.assistantId, 'assistant-daily');
      expect(seed.messages, hasLength(3000));
      expect(seed.conversation.messageIds, [
        for (final message in seed.messages) message.id,
      ]);
      expect(seed.totalContentBytes, greaterThan(0));

      final userMessages = seed.messages.where(
        (message) => message.role == 'user',
      );
      final assistantMessages = seed.messages.where(
        (message) => message.role == 'assistant',
      );
      expect(userMessages, hasLength(1500));
      expect(assistantMessages, hasLength(1500));
      expect(
        seed.messages.any((message) => message.content.contains('```')),
        isTrue,
      );
      expect(
        seed.messages.any((message) => message.content.contains('|')),
        isTrue,
      );
      expect(
        seed.messages.any((message) => message.content.contains('- [')),
        isTrue,
      );
    });

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

      expect(
        () => DebugConversationFactory.createDailyMixedMarkdownConversation(
          title: 'invalid',
          assistantId: null,
          messageCount: 0,
        ),
        throwsArgumentError,
      );

      expect(
        () => DebugConversationFactory.createLongReasoningConversation(
          title: 'invalid',
          assistantId: null,
          messageCount: 0,
        ),
        throwsArgumentError,
      );
    });
  });
}
