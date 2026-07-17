import 'dart:io';

import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/database/generation_run.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

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

      final raw = sqlite.sqlite3.open('${directory.path}/chat.sqlite');
      try {
        final parts = raw.select(
          "SELECT kind FROM message_part_rows WHERE revision_id = "
          "'streaming' ORDER BY ordinal;",
        );
        expect(parts.map((row) => row['kind']), const [
          'reasoning',
          'tool_call',
          'tool_result',
          'text',
        ]);
        raw.execute(
          "UPDATE message_rows SET content = 'wrong shadow', "
          "reasoning_text = 'wrong reasoning' WHERE id = 'streaming';",
        );
      } finally {
        raw.close();
      }

      final authoritative = await repository.getMessage('streaming');
      expect(authoritative?.content, 'partial answer');
      expect(authoritative?.reasoningText, 'thinking');
    });

    test(
      'provider artifact remains authoritative over legacy signature',
      () async {
        await repository.setGeminiThoughtSignature(
          'streaming',
          'authoritative',
        );
        final raw = sqlite.sqlite3.open('${directory.path}/chat.sqlite');
        try {
          raw.execute(
            "UPDATE gemini_thought_signature_rows SET signature = 'wrong' "
            "WHERE message_id = 'streaming';",
          );
        } finally {
          raw.close();
        }
        expect(
          await repository.getGeminiThoughtSignature('streaming'),
          'authoritative',
        );
      },
    );

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
      final createdAt = DateTime.now().toUtc();
      await repository.createGenerationRun(
        id: 'abandoned-run',
        conversationId: 'conversation',
        targetRevisionId: 'streaming',
        createdAt: createdAt,
      );
      await repository.transitionGenerationRun(
        id: 'abandoned-run',
        expectedState: GenerationRunState.preparing,
        expectedStateRevision: 0,
        nextState: GenerationRunState.requesting,
        updatedAt: createdAt.add(const Duration(milliseconds: 1)),
      );
      await repository.updateStreamingCheckpoint(
        ChatMessage(
          id: 'streaming',
          role: 'assistant',
          content: 'preserved partial',
          conversationId: 'conversation',
          isStreaming: true,
        ),
        const [],
        generationRunId: 'abandoned-run',
        checkpointSeq: 1,
      );

      expect(await repository.resetStaleStreamingState(), 1);

      final message = await repository.getMessage('streaming');
      expect(message?.isStreaming, isFalse);
      expect(message?.content, 'preserved partial');
      final run = await repository.getGenerationRun('abandoned-run');
      expect(run?.state, GenerationRunState.interrupted);
      expect(run?.stateRevision, 2);
      expect(run?.checkpointSeq, 1);
      expect(run?.errorCode, 'app_restart');
      expect(await repository.getActiveStreamingIds(), isEmpty);
    });

    test('active generation projection comes only from run rows', () async {
      final createdAt = DateTime.now().toUtc();
      await repository.createGenerationRun(
        id: 'first-run',
        conversationId: 'conversation',
        targetRevisionId: 'first',
        createdAt: createdAt,
      );
      await repository.createGenerationRun(
        id: 'streaming-run',
        conversationId: 'conversation',
        targetRevisionId: 'streaming',
        createdAt: createdAt,
      );

      expect(
        await repository.getActiveStreamingIds(),
        containsAll(['first', 'streaming']),
      );
      final raw = sqlite.sqlite3.open('${directory.path}/chat.sqlite');
      try {
        expect(
          raw.select(
            "SELECT value FROM chat_storage_meta_rows "
            "WHERE key = 'active_streaming_ids';",
          ),
          isEmpty,
        );
      } finally {
        raw.close();
      }
    });
  });
}
