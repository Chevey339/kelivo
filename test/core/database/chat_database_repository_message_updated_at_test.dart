import 'dart:io';

import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// message_rows.updated_at contract (schema 3): inserts leave it null — the
/// effective value is COALESCE(updated_at, timestamp) — and every repository
/// UPDATE path bumps it so a future sync can detect in-place edits.
void main() {
  group('ChatDatabaseRepository message updated_at', () {
    late Directory directory;
    late File databaseFile;
    late ChatDatabaseRepository repository;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp(
        'kelivo_message_updated_at_test_',
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

    ChatMessage message(String id) => ChatMessage(
      id: id,
      role: 'user',
      content: 'hello',
      conversationId: 'topic',
      groupId: id,
      version: 0,
      timestamp: DateTime.utc(2026, 8, 1),
    );

    Future<void> seed() async {
      final createdAt = DateTime.utc(2026, 8, 1);
      await repository.putMigrationBatch(
        conversations: [
          Conversation(
            id: 'topic',
            title: 'Topic',
            createdAt: createdAt,
            updatedAt: createdAt,
            messageIds: const ['u1'],
          ),
        ],
        messages: [(message: message('u1'), messageOrder: 0)],
        toolEventsByMessageId: const {},
        geminiSignaturesByMessageId: const {},
      );
    }

    Object? rawUpdatedAt(String messageId) {
      final raw = sqlite.sqlite3.open(
        databaseFile.path,
        mode: sqlite.OpenMode.readOnly,
      );
      try {
        return raw.select('SELECT updated_at FROM message_rows WHERE id = ?;', [
          messageId,
        ]).single['updated_at'];
      } finally {
        raw.close();
      }
    }

    test('inserted rows keep updated_at null', () async {
      await seed();

      expect(rawUpdatedAt('u1'), isNull);
    });

    test('updateMessageFields bumps updated_at', () async {
      await seed();

      await repository.updateMessageFields('u1', translation: 'bonjour');

      expect(rawUpdatedAt('u1'), isNotNull);
    });

    test('putMessage upserts bump updated_at', () async {
      await seed();
      expect(rawUpdatedAt('u1'), isNull);

      await repository.putMessage(message('u1'), messageOrder: 0);

      expect(rawUpdatedAt('u1'), isNotNull);
    });
  });
}
