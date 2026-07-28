import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

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

    test('rejects current schema missing generation run state', () async {
      await sourceRepository.close();
      sourceClosed = true;
      final raw = sqlite.sqlite3.open(sourceFile.path);
      try {
        raw.execute('PRAGMA foreign_keys = OFF;');
        raw.execute('DROP TABLE generation_run_rows;');
      } finally {
        raw.close();
      }

      expect(
        () => ChatDatabaseRepository.inspectInstalledDatabase(
          sourceFile,
          validateContents: true,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'required_tables',
          ),
        ),
      );
    });

    test('rejects current schema missing an asset table', () async {
      await sourceRepository.close();
      sourceClosed = true;
      final raw = sqlite.sqlite3.open(sourceFile.path);
      try {
        raw.execute('DROP TABLE asset_reference_dirty_rows;');
      } finally {
        raw.close();
      }

      expect(
        () => ChatDatabaseRepository.inspectInstalledDatabase(
          sourceFile,
          validateContents: true,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'required_tables',
          ),
        ),
      );
    });

    test(
      'rejects a same-version business table without its primary key',
      () async {
        await sourceRepository.close();
        sourceClosed = true;
        final raw = sqlite.sqlite3.open(sourceFile.path);
        try {
          raw.execute('ALTER TABLE provider_rows RENAME TO provider_rows_old;');
          raw.execute('''
CREATE TABLE provider_rows (
  provider_key TEXT NOT NULL,
  sort_order INTEGER NOT NULL CHECK(sort_order >= 0),
  payload TEXT NOT NULL,
  updated_at INTEGER NOT NULL
);
''');
          raw.execute('DROP TABLE provider_rows_old;');
        } finally {
          raw.close();
        }

        expect(
          () => ChatDatabaseRepository.inspectInstalledDatabase(
            sourceFile,
            validateContents: true,
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'primary_key_schema:provider_rows',
            ),
          ),
        );
      },
    );

    test(
      'rejects a same-version asset table without its primary key',
      () async {
        await sourceRepository.close();
        sourceClosed = true;
        final raw = sqlite.sqlite3.open(sourceFile.path);
        try {
          raw.execute('DROP TABLE message_asset_rows;');
          raw.execute('''
CREATE TABLE message_asset_rows (
  conversation_id TEXT NOT NULL,
  revision_id TEXT NOT NULL
    REFERENCES message_rows(id) ON DELETE CASCADE,
  asset_id TEXT NOT NULL
    REFERENCES asset_rows(id) ON DELETE CASCADE,
  kind TEXT NOT NULL CHECK(kind <> '')
);
''');
          raw.execute(
            'CREATE INDEX idx_message_assets_asset '
            'ON message_asset_rows(asset_id, revision_id);',
          );
        } finally {
          raw.close();
        }

        expect(
          () => ChatDatabaseRepository.inspectInstalledDatabase(
            sourceFile,
            validateContents: true,
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'primary_key_schema:message_asset_rows',
            ),
          ),
        );
      },
    );

    test('rejects a same-version database missing the memory index', () async {
      await sourceRepository.close();
      sourceClosed = true;
      final raw = sqlite.sqlite3.open(sourceFile.path);
      try {
        raw.execute('DROP INDEX idx_assistant_memories_assistant;');
      } finally {
        raw.close();
      }

      expect(
        () => ChatDatabaseRepository.inspectInstalledDatabase(
          sourceFile,
          validateContents: true,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'index_schema:idx_assistant_memories_assistant',
          ),
        ),
      );
    });

    test('rejects a same-version database missing the asset index', () async {
      await sourceRepository.close();
      sourceClosed = true;
      final raw = sqlite.sqlite3.open(sourceFile.path);
      try {
        raw.execute('DROP INDEX idx_message_assets_asset;');
      } finally {
        raw.close();
      }

      expect(
        () => ChatDatabaseRepository.inspectInstalledDatabase(
          sourceFile,
          validateContents: true,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'index_schema:idx_message_assets_asset',
          ),
        ),
      );
    });

    test(
      'rejects a same-version asset table without unique content hashes',
      () async {
        await sourceRepository.close();
        sourceClosed = true;
        final raw = sqlite.sqlite3.open(sourceFile.path);
        try {
          raw.execute('DROP TABLE asset_rows;');
          raw.execute('''
CREATE TABLE asset_rows (
  id TEXT NOT NULL PRIMARY KEY,
  content_hash TEXT NOT NULL,
  path TEXT NOT NULL,
  byte_size INTEGER NOT NULL CHECK(byte_size >= 0),
  width INTEGER CHECK(width > 0),
  height INTEGER CHECK(height > 0),
  thumbnail_path TEXT,
  created_at INTEGER NOT NULL,
  last_referenced_at INTEGER NOT NULL
);
''');
        } finally {
          raw.close();
        }

        expect(
          () => ChatDatabaseRepository.inspectInstalledDatabase(
            sourceFile,
            validateContents: true,
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'index_schema:asset_rows.content_hash',
            ),
          ),
        );
      },
    );

    test(
      'rejects a same-version asset table without its foreign key',
      () async {
        await sourceRepository.close();
        sourceClosed = true;
        final raw = sqlite.sqlite3.open(sourceFile.path);
        try {
          raw.execute('DROP TABLE asset_reference_dirty_rows;');
          raw.execute('''
CREATE TABLE asset_reference_dirty_rows (
  revision_id TEXT PRIMARY KEY NOT NULL
);
''');
        } finally {
          raw.close();
        }

        expect(
          () => ChatDatabaseRepository.inspectInstalledDatabase(
            sourceFile,
            validateContents: true,
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'foreign_key_schema:asset_reference_dirty_rows',
            ),
          ),
        );
      },
    );
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
