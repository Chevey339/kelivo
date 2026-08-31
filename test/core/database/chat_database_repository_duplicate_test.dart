import 'dart:io';

import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  group('ChatDatabaseRepository duplicateConversation', () {
    late Directory directory;
    late ChatDatabaseRepository repository;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp(
        'kelivo_duplicate_conversation_test_',
      );
      repository = ChatDatabaseRepository.open(
        file: File('${directory.path}/chat.sqlite'),
      );
      await repository.ensureReady();
    });

    tearDown(() async {
      await repository.close();
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    test(
      'copies the full topic with fresh conversation and message ids',
      () async {
        final createdAt = DateTime.utc(2026, 8, 1);
        final anchor = ChatMessage(
          id: 'anchor',
          role: 'assistant',
          content: 'first answer',
          conversationId: 'source',
          groupId: 'anchor',
          version: 0,
          timestamp: createdAt,
        );
        final revision = ChatMessage(
          id: 'revision',
          role: 'assistant',
          content: 'second answer',
          conversationId: 'source',
          groupId: 'anchor',
          version: 1,
          timestamp: createdAt.add(const Duration(minutes: 1)),
        );
        await repository.putMigrationBatch(
          conversations: [
            Conversation(
              id: 'source',
              title: 'Topic',
              createdAt: createdAt,
              updatedAt: createdAt,
              messageIds: const ['anchor', 'revision'],
              isPinned: true,
              mcpServerIds: const ['mcp-server'],
              assistantId: 'assistant',
              truncateIndex: 1,
              versionSelections: const {'anchor': 1},
              summary: 'summary',
              lastSummarizedMessageCount: 2,
              chatSuggestions: const ['next'],
              injectedMemoryHash: 'source-memory',
            ),
          ],
          messages: [
            (message: anchor, messageOrder: 0),
            (message: revision, messageOrder: 1),
          ],
          toolEventsByMessageId: {
            'revision': [
              {'id': 'tool-call', 'result': 'done'},
            ],
          },
          geminiSignaturesByMessageId: const {'revision': 'signature'},
        );
        await repository.putMessagePrompt(
          revisionId: 'revision',
          conversationId: 'source',
          payload: 'frozen prompt',
          carriesMemorySnapshot: false,
        );
        await repository.registerAsset(
          id: 'stale-asset',
          contentHash: List.filled(64, 'a').join(),
          path: '${directory.path}/stale.png',
          byteSize: 1,
          createdAt: createdAt,
        );
        await repository.linkMessageAsset(
          conversationId: 'source',
          revisionId: 'revision',
          assetId: 'stale-asset',
          kind: 'image',
        );
        await repository.markMessageAssetReferencesDirty('revision');

        final duplicate = await repository.duplicateConversation('source');

        expect(duplicate, isNotNull);
        expect(duplicate!.id, isNot('source'));
        expect(duplicate.title, 'Topic');
        expect(duplicate.isPinned, isTrue);
        expect(duplicate.mcpServerIds, const ['mcp-server']);
        expect(duplicate.assistantId, 'assistant');
        expect(duplicate.truncateIndex, 1);
        expect(duplicate.summary, 'summary');
        expect(duplicate.chatSuggestions, const ['next']);
        expect(duplicate.injectedMemoryHash, isNull);
        expect(duplicate.messageIds, hasLength(2));
        expect(duplicate.messageIds, isNot(contains('anchor')));
        expect(duplicate.messageIds, isNot(contains('revision')));
        expect(duplicate.versionSelections, {duplicate.messageIds.first: 1});

        final messages = await repository.getMessagesRange(
          duplicate.id,
          start: 0,
          limit: 10,
        );
        expect(messages.map((message) => message.content), [
          'first answer',
          'second answer',
        ]);
        expect(messages.map((message) => message.conversationId).toSet(), {
          duplicate.id,
        });
        expect(messages.map((message) => message.groupId).toSet(), {
          duplicate.messageIds.first,
        });
        expect(messages.map((message) => message.version), [0, 1]);
        expect(await repository.getToolEvents(duplicate.messageIds.last), [
          {'id': 'tool-call', 'result': 'done'},
        ]);
        expect(
          await repository.getGeminiThoughtSignature(duplicate.messageIds.last),
          'signature',
        );
        expect(
          await repository.getMessagePrompt(duplicate.messageIds.last),
          isNull,
        );
        final raw = sqlite.sqlite3.open('${directory.path}/chat.sqlite');
        try {
          expect(
            raw.select(
              'SELECT asset_id FROM message_asset_rows '
              'WHERE revision_id = ?;',
              [duplicate.messageIds.last],
            ).single['asset_id'],
            'stale-asset',
          );
          expect(
            raw.select(
              'SELECT revision_id FROM asset_reference_dirty_rows '
              'WHERE revision_id = ?;',
              [duplicate.messageIds.last],
            ),
            isNotEmpty,
          );
        } finally {
          raw.close();
        }
      },
    );

    test('copies sender_id and extras_json onto duplicated messages', () async {
      final createdAt = DateTime.utc(2026, 8, 1);
      await repository.putMigrationBatch(
        conversations: [
          Conversation(
            id: 'identity-source',
            title: 'Identity',
            createdAt: createdAt,
            updatedAt: createdAt,
            messageIds: const ['identity-msg'],
          ),
        ],
        messages: [
          (
            message: ChatMessage(
              id: 'identity-msg',
              role: 'assistant',
              content: 'who said it',
              conversationId: 'identity-source',
              groupId: 'identity-msg',
              version: 0,
              timestamp: createdAt,
            ),
            messageOrder: 0,
          ),
        ],
        toolEventsByMessageId: const {},
        geminiSignaturesByMessageId: const {},
      );
      final databasePath = '${directory.path}/chat.sqlite';
      final raw = sqlite.sqlite3.open(databasePath);
      try {
        raw.execute('PRAGMA busy_timeout = 5000;');
        raw.execute(
          'UPDATE message_rows SET sender_id = ?, extras_json = ? '
          'WHERE id = ?;',
          ['assistant-b', '{"subagent":true}', 'identity-msg'],
        );
      } finally {
        raw.close();
      }

      final duplicate = await repository.duplicateConversation(
        'identity-source',
      );

      expect(duplicate, isNotNull);
      final verify = sqlite.sqlite3.open(databasePath);
      try {
        final row = verify.select(
          'SELECT sender_id, extras_json, updated_at FROM message_rows '
          'WHERE conversation_id = ?;',
          [duplicate!.id],
        ).single;
        expect(row['sender_id'], 'assistant-b');
        expect(row['extras_json'], '{"subagent":true}');
        // A copy is a fresh row: its effective updated_at falls back to its
        // (copied) timestamp, so the column stays null.
        expect(row['updated_at'], isNull);
      } finally {
        verify.close();
      }
    });

    test('returns null when the source topic does not exist', () async {
      expect(await repository.duplicateConversation('missing'), isNull);
    });
  });
}
