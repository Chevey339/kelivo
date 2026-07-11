import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/database/app_database.dart';
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

      expect(info.schemaVersion, AppDatabase.currentSchemaVersion);
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

    test('replaces live chat tables from a validated snapshot', () async {
      await sourceRepository.putMigrationBatch(
        conversations: [Conversation(id: 'old', title: 'Old')],
        messages: const [],
        toolEventsByMessageId: const {},
        geminiSignaturesByMessageId: const {},
      );
      final snapshotFile = File('${directory.path}/replacement.sqlite');
      await _createSnapshotFixture(
        databaseFile: snapshotFile,
        conversationId: 'new',
        title: 'New',
        messageId: 'new-message',
        messageContent: 'new content',
        isStreaming: true,
      );
      await _deleteDatabaseSidecars(snapshotFile);

      final info = await ChatDatabaseRepository.prepareSnapshotForRestore(
        snapshotFile,
      );
      expect(info.conversationCount, 1);
      await sourceRepository.replaceBackupSnapshot(snapshotFile);

      expect(await sourceRepository.getConversation('old'), isNull);
      expect(await sourceRepository.getConversation('new'), isNotNull);
      expect(
        (await sourceRepository.getMessagesRange(
          'new',
          start: 0,
          limit: 1,
        )).single.isStreaming,
        isFalse,
      );
      expect(await sourceRepository.isMigrationComplete(), isTrue);
    });

    test(
      'inspects only normalized standalone snapshots without writing',
      () async {
        final snapshotFile = File('${directory.path}/inspection.sqlite');
        await _createSnapshotFixture(
          databaseFile: snapshotFile,
          conversationId: 'inspection',
          title: 'Inspection',
          messageId: 'streaming-message',
          messageContent: 'partial',
          isStreaming: true,
        );

        await expectLater(
          ChatDatabaseRepository.inspectPreparedSnapshot(snapshotFile),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'database_streaming_messages',
            ),
          ),
        );

        await ChatDatabaseRepository.prepareSnapshotForRestore(snapshotFile);
        final before = (await sha256.bind(snapshotFile.openRead()).first)
            .toString();

        final info = await ChatDatabaseRepository.inspectPreparedSnapshot(
          snapshotFile,
        );

        final after = (await sha256.bind(snapshotFile.openRead()).first)
            .toString();
        expect(info.conversationCount, 1);
        expect(info.messageCount, 1);
        expect(after, before);
      },
    );

    test('rejects a prepared snapshot with a sidecar', () async {
      final snapshotFile = File('${directory.path}/sidecar.sqlite');
      await _createSnapshotFixture(
        databaseFile: snapshotFile,
        conversationId: 'sidecar',
        title: 'Sidecar',
      );
      await ChatDatabaseRepository.prepareSnapshotForRestore(snapshotFile);
      await File('${snapshotFile.path}-wal').writeAsBytes([1], flush: true);

      await expectLater(
        ChatDatabaseRepository.inspectPreparedSnapshot(snapshotFile),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'database_sidecar:-wal',
          ),
        ),
      );
    });
  });
}

Future<void> _createSnapshotFixture({
  required File databaseFile,
  required String conversationId,
  required String title,
  String? messageId,
  String? messageContent,
  bool isStreaming = false,
}) async {
  final databasePath = databaseFile.path;
  await Isolate.run(() async {
    final repository = ChatDatabaseRepository.open(file: File(databasePath));
    try {
      await repository.ensureReady();
      await repository.putMigrationBatch(
        conversations: [
          Conversation(
            id: conversationId,
            title: title,
            messageIds: messageId == null ? const [] : [messageId],
          ),
        ],
        messages: messageId == null
            ? const []
            : [
                (
                  message: ChatMessage(
                    id: messageId,
                    role: 'assistant',
                    content: messageContent ?? '',
                    conversationId: conversationId,
                    isStreaming: isStreaming,
                  ),
                  messageOrder: 0,
                ),
              ],
        toolEventsByMessageId: const {},
        geminiSignaturesByMessageId: const {},
      );
      await repository.checkpoint();
    } finally {
      await repository.close();
    }
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

Future<void> _deleteDatabaseSidecars(File databaseFile) async {
  for (final suffix in const ['-wal', '-shm', '-journal']) {
    final file = File('${databaseFile.path}$suffix');
    if (await file.exists()) {
      await file.delete();
    }
  }
}
