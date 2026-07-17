import 'dart:io';

import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sandbox path migration version', () {
    late Directory directory;
    late ChatDatabaseRepository repository;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp(
        'kelivo_sandbox_path_migration_',
      );
      repository = ChatDatabaseRepository.open(
        file: File('${directory.path}/chat.sqlite'),
      );
      await repository.ensureReady();
      await repository.putMigrationBatch(
        conversations: [
          Conversation(
            id: 'conversation',
            title: 'Paths',
            messageIds: const ['plain', 'path'],
          ),
        ],
        messages: [
          (
            message: ChatMessage(
              id: 'plain',
              conversationId: 'conversation',
              role: 'user',
              content: 'plain text',
            ),
            messageOrder: 0,
          ),
          (
            message: ChatMessage(
              id: 'path',
              conversationId: 'conversation',
              role: 'user',
              content: '[image:/old/upload/a.png]',
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
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    test('首次按批迁移并在同一事务写 version receipt', () async {
      final result = await repository.migrateSandboxPaths(
        targetVersion: 1,
        targetRoot: '/new',
        batchSize: 1,
        rewriteContent: (content) => content.replaceFirst('/old/', '/new/'),
      );

      expect(result.ran, isTrue);
      expect(result.scannedMessages, 1);
      expect(result.updatedMessages, 1);
      expect(
        (await repository.getMessagesRange(
          'conversation',
          start: 0,
          limit: 10,
        )).last.content,
        '[image:/new/upload/a.png]',
      );
    });

    test('同版本后续启动不读取候选消息', () async {
      await repository.migrateSandboxPaths(
        targetVersion: 1,
        targetRoot: '/same',
        rewriteContent: (content) => content,
      );

      final result = await repository.migrateSandboxPaths(
        targetVersion: 1,
        targetRoot: '/same',
        rewriteContent: (_) => throw StateError('must_not_scan'),
      );

      expect(result.ran, isFalse);
      expect(result.scannedMessages, 0);
    });

    test('rewrite 失败回滚内容且不写 receipt，可重试', () async {
      await expectLater(
        repository.migrateSandboxPaths(
          targetVersion: 1,
          targetRoot: '/new',
          rewriteContent: (_) => throw StateError('rewrite_failed'),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'rewrite_failed',
          ),
        ),
      );

      final retry = await repository.migrateSandboxPaths(
        targetVersion: 1,
        targetRoot: '/new',
        rewriteContent: (content) => content.replaceFirst('/old/', '/new/'),
      );
      expect(retry.ran, isTrue);
      expect(retry.updatedMessages, 1);
    });

    test('同版本目标根变化时重新执行一次', () async {
      await repository.migrateSandboxPaths(
        targetVersion: 1,
        targetRoot: '/first',
        rewriteContent: (content) => content,
      );

      final result = await repository.migrateSandboxPaths(
        targetVersion: 1,
        targetRoot: '/second',
        rewriteContent: (content) => content.replaceFirst('/old/', '/second/'),
      );

      expect(result.ran, isTrue);
      expect(result.updatedMessages, 1);
    });

    test('拒绝高于当前实现的已有 migration version', () async {
      await repository.migrateSandboxPaths(
        targetVersion: 2,
        targetRoot: '/future',
        rewriteContent: (content) => content,
      );

      await expectLater(
        repository.migrateSandboxPaths(
          targetVersion: 1,
          targetRoot: '/current',
          rewriteContent: (content) => content,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'sandbox_path_migration_version',
          ),
        ),
      );
    });
  });
}
