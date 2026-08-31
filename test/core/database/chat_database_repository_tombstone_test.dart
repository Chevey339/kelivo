import 'dart:io';

import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  group('ChatDatabaseRepository conversation tombstones', () {
    late Directory directory;
    late File databaseFile;
    late ChatDatabaseRepository repository;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp(
        'kelivo_tombstone_test_',
      );
      databaseFile = File('${directory.path}/chat.sqlite');
      repository = ChatDatabaseRepository.open(file: databaseFile);
      await repository.ensureReady();
    });

    tearDown(() async {
      await repository.close();
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    Future<void> seedConversation(String id) async {
      final createdAt = DateTime.utc(2026, 8, 1);
      await repository.putMigrationBatch(
        conversations: [
          Conversation(
            id: id,
            title: 'Topic $id',
            createdAt: createdAt,
            updatedAt: createdAt,
            messageIds: ['$id-u1'],
          ),
        ],
        messages: [
          (
            message: ChatMessage(
              id: '$id-u1',
              role: 'user',
              content: 'hello',
              conversationId: id,
              groupId: '$id-u1',
              version: 0,
              timestamp: createdAt,
            ),
            messageOrder: 0,
          ),
        ],
        toolEventsByMessageId: const {},
        geminiSignaturesByMessageId: const {},
      );
    }

    /// Rewrites a tombstone's deleted_at through a second connection, the way
    /// time passing would.
    void ageTombstone(String entityId, DateTime deletedAt) {
      final raw = sqlite.sqlite3.open(databaseFile.path);
      try {
        raw.execute('PRAGMA busy_timeout = 5000;');
        raw.execute(
          'UPDATE tombstone_rows SET deleted_at = ? WHERE entity_id = ?;',
          [deletedAt.microsecondsSinceEpoch, entityId],
        );
      } finally {
        raw.close();
      }
    }

    test('deleteConversation records a tombstone', () async {
      await seedConversation('conv-a');

      await repository.deleteConversation('conv-a');

      final tombstones = await repository.readTombstones(
        scope: ChatDatabaseRepository.tombstoneScopeConversation,
      );
      expect(tombstones, hasLength(1));
      expect(tombstones.single.entityId, 'conv-a');
      expect(tombstones.single.deletedAt.isAfter(DateTime.utc(2026)), isTrue);
    });

    test('deleting an id that does not exist writes no tombstone', () async {
      await repository.deleteConversation('never-existed');

      expect(await repository.readTombstones(), isEmpty);
    });

    test('re-deleting a recreated conversation refreshes deletedAt', () async {
      await seedConversation('conv-a');
      await repository.deleteConversation('conv-a');
      final first = (await repository.readTombstones()).single.deletedAt;

      await Future<void>.delayed(const Duration(milliseconds: 2));
      await seedConversation('conv-a');
      await repository.deleteConversation('conv-a');

      final tombstones = await repository.readTombstones();
      expect(tombstones, hasLength(1));
      expect(tombstones.single.deletedAt.isAfter(first), isTrue);
    });

    test('deletes prune tombstones older than the retention window', () async {
      await seedConversation('conv-old');
      await repository.deleteConversation('conv-old');
      ageTombstone(
        'conv-old',
        DateTime.now().toUtc().subtract(
          ChatDatabaseRepository.tombstoneRetention + const Duration(days: 1),
        ),
      );

      await seedConversation('conv-new');
      await repository.deleteConversation('conv-new');

      final tombstones = await repository.readTombstones();
      expect(tombstones.map((t) => t.entityId), ['conv-new']);
    });

    test('clearAllData clears tombstones instead of writing them', () async {
      await seedConversation('conv-a');
      await repository.deleteConversation('conv-a');
      expect(await repository.readTombstones(), hasLength(1));

      await repository.clearAllData();

      expect(await repository.readTombstones(), isEmpty);
    });
  });
}
