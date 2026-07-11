import 'dart:io';

import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatDatabaseRepository streaming checkpoint', () {
    late Directory directory;
    late ChatDatabaseRepository repository;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp(
        'kelivo_streaming_checkpoint_test_',
      );
      repository = ChatDatabaseRepository.open(
        file: File('${directory.path}/chat.sqlite'),
      );
      await repository.ensureReady();
      await repository.putMigrationBatch(
        conversations: [
          Conversation(
            id: 'conversation',
            title: 'Conversation',
            messageIds: const ['first', 'streaming'],
          ),
        ],
        messages: [
          (
            message: ChatMessage(
              id: 'first',
              role: 'user',
              content: 'question',
              conversationId: 'conversation',
            ),
            messageOrder: 0,
          ),
          (
            message: ChatMessage(
              id: 'streaming',
              role: 'assistant',
              content: '',
              conversationId: 'conversation',
              isStreaming: true,
            ),
            messageOrder: 1,
          ),
        ],
        toolEventsByMessageId: const {},
        geminiSignaturesByMessageId: const {},
      );
    });

    tearDown(() async {
      await repository.close();
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    test('一次事务写入完整消息快照和 tool events 且不改变顺序', () async {
      final snapshot = ChatMessage(
        id: 'streaming',
        role: 'assistant',
        content: 'partial answer',
        conversationId: 'conversation',
        isStreaming: true,
        totalTokens: 12,
        reasoningText: 'thinking',
      );

      await repository.updateStreamingCheckpoint(snapshot, const [
        {
          'id': 'tool-1',
          'name': 'search',
          'arguments': {'q': 'kelivo'},
          'content': 'result',
        },
      ]);

      final messages = await repository.getMessagesByIds(const [
        'first',
        'streaming',
      ]);
      expect(messages.map((message) => message.id), const [
        'first',
        'streaming',
      ]);
      expect(messages.last.content, 'partial answer');
      expect(messages.last.totalTokens, 12);
      expect(messages.last.reasoningText, 'thinking');
      expect(await repository.getToolEvents('streaming'), const [
        {
          'id': 'tool-1',
          'name': 'search',
          'arguments': {'q': 'kelivo'},
          'content': 'result',
        },
      ]);
    });

    test('不存在的消息不会被 checkpoint 意外插入', () async {
      await expectLater(
        repository.updateStreamingCheckpoint(
          ChatMessage(
            id: 'missing',
            role: 'assistant',
            content: 'orphan',
            conversationId: 'conversation',
            isStreaming: true,
          ),
          const [],
        ),
        throwsA(anything),
      );

      expect(await repository.getMessagesByIds(const ['missing']), isEmpty);
    });

    test('cold start 一次事务清理未登记 flag 和孤儿 tracking metadata', () async {
      await repository.setActiveStreamingIds(const [
        'different-message',
        'missing-message',
      ]);

      await repository.resetStaleStreamingState();

      final message = await repository.getMessage('streaming');
      expect(message?.isStreaming, isFalse);
      expect(await repository.getActiveStreamingIds(), isEmpty);
    });

    test('并发 generation 的 tracking 更新不会互相覆盖', () async {
      await Future.wait([
        repository.trackActiveStreamingId('first-stream'),
        repository.trackActiveStreamingId('second-stream'),
      ]);

      expect(
        await repository.getActiveStreamingIds(),
        containsAll(['first-stream', 'second-stream']),
      );
    });
  });
}
