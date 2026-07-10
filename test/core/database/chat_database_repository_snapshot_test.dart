import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';

void main() {
  group('ChatDatabaseRepository snapshot', () {
    late Directory directory;
    late File sourceFile;
    late ChatDatabaseRepository sourceRepository;
    late bool sourceClosed;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp(
        'kelivo_repository_snapshot_test_',
      );
      sourceFile = File('${directory.path}/source.sqlite');
      sourceRepository = ChatDatabaseRepository.open(file: sourceFile);
      await sourceRepository.ensureReady();
      sourceClosed = false;
    });

    tearDown(() async {
      if (!sourceClosed) {
        await sourceRepository.close();
      }
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    test('backs up a live WAL database into one standalone file', () async {
      await sourceRepository.putMigrationBatch(
        conversations: [
          Conversation(
            id: 'conversation',
            title: 'Snapshot',
            messageIds: const ['message'],
          ),
        ],
        messages: [
          (
            message: ChatMessage(
              id: 'message',
              role: 'assistant',
              content: 'content from live wal',
              conversationId: 'conversation',
            ),
            messageOrder: 0,
          ),
        ],
        toolEventsByMessageId: const {
          'message': [
            {'id': 'event'},
          ],
        },
        geminiSignaturesByMessageId: const {'message': 'signature'},
      );
      await sourceRepository.markMigrationComplete();

      final snapshotFile = File('${directory.path}/snapshot.sqlite');
      final info = await ChatDatabaseRepository.createConsistentSnapshot(
        sourceFile: sourceFile,
        destinationFile: snapshotFile,
      );

      expect(info.schemaVersion, 1);
      expect(info.conversationCount, 1);
      expect(info.messageCount, 1);
      expect(await snapshotFile.exists(), isTrue);
      expect(await File('${snapshotFile.path}-wal').exists(), isFalse);
      expect(await File('${snapshotFile.path}-shm').exists(), isFalse);

      await sourceRepository.close();
      sourceClosed = true;
      await _deleteDatabaseFamily(sourceFile);

      final snapshotRepository = ChatDatabaseRepository.open(
        file: snapshotFile,
      );
      try {
        await snapshotRepository.ensureReady();
        await snapshotRepository.validateIntegrity();
        expect(
          (await snapshotRepository.getMessagesRange(
            'conversation',
            start: 0,
            limit: 1,
          )).single.content,
          'content from live wal',
        );
        expect(await snapshotRepository.getToolEvents('message'), const [
          {'id': 'event'},
        ]);
        expect(
          await snapshotRepository.getGeminiThoughtSignature('message'),
          'signature',
        );
        expect(await snapshotRepository.isMigrationComplete(), isTrue);
      } finally {
        await snapshotRepository.close();
      }
    });

    test('rejects using the live database as its own destination', () async {
      await expectLater(
        ChatDatabaseRepository.createConsistentSnapshot(
          sourceFile: sourceFile,
          destinationFile: sourceFile,
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(await sourceRepository.isMigrationComplete(), isFalse);
    });
  });
}

Future<void> _deleteDatabaseFamily(File databaseFile) async {
  for (final suffix in const ['', '-wal', '-shm', '-journal']) {
    final file = File('${databaseFile.path}$suffix');
    if (await file.exists()) {
      await file.delete();
    }
  }
}
