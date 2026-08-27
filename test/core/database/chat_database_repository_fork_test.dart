import 'dart:io';

import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  group('ChatDatabaseRepository forkConversationWithVersions', () {
    late Directory directory;
    late ChatDatabaseRepository repository;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp(
        'kelivo_fork_conversation_test_',
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

    test('copies every version of groups at or before the cut', () async {
      final createdAt = DateTime.utc(2026, 8, 1);
      final user1 = ChatMessage(
        id: 'u1',
        role: 'user',
        content: 'question 1',
        conversationId: 'source',
        groupId: 'u1',
        version: 0,
        timestamp: createdAt,
      );
      final a1v0 = ChatMessage(
        id: 'a1v0',
        role: 'assistant',
        content: 'first answer',
        conversationId: 'source',
        groupId: 'a1',
        version: 0,
        timestamp: createdAt.add(const Duration(minutes: 1)),
      );
      final a1v1 = ChatMessage(
        id: 'a1v1',
        role: 'assistant',
        content: 'second answer',
        conversationId: 'source',
        groupId: 'a1',
        version: 1,
        timestamp: createdAt.add(const Duration(minutes: 2)),
      );
      final user2 = ChatMessage(
        id: 'u2',
        role: 'user',
        content: 'question 2',
        conversationId: 'source',
        groupId: 'u2',
        version: 0,
        timestamp: createdAt.add(const Duration(minutes: 3)),
      );
      final a2 = ChatMessage(
        id: 'a2',
        role: 'assistant',
        content: 'later answer',
        conversationId: 'source',
        groupId: 'a2',
        version: 0,
        timestamp: createdAt.add(const Duration(minutes: 4)),
      );
      await repository.putMigrationBatch(
        conversations: [
          Conversation(
            id: 'source',
            title: 'Topic',
            createdAt: createdAt,
            updatedAt: createdAt,
            messageIds: const ['u1', 'a1v0', 'a1v1', 'u2', 'a2'],
            isPinned: true,
            mcpServerIds: const ['mcp-server'],
            assistantId: 'assistant',
            truncateIndex: 1,
            versionSelections: const {'a1': 0, 'a2': 0},
            summary: 'summary',
            lastSummarizedMessageCount: 5,
            chatSuggestions: const ['next'],
            injectedMemoryHash: 'source-memory',
          ),
        ],
        messages: [
          (message: user1, messageOrder: 0),
          (message: a1v0, messageOrder: 1),
          (message: a1v1, messageOrder: 2),
          (message: user2, messageOrder: 3),
          (message: a2, messageOrder: 4),
        ],
        toolEventsByMessageId: {
          'a1v1': [
            {'id': 'tool-call', 'result': 'done'},
          ],
        },
        geminiSignaturesByMessageId: const {'a1v1': 'signature'},
      );

      await repository.setProviderArtifact(
        'a1v1',
        'claude_container',
        '{"id":"container_1"}',
      );

      final fork = await repository.forkConversationWithVersions(
        sourceId: 'source',
        targetRevisionId: 'a1v1',
        title: 'Fork title',
        assistantId: 'assistant',
      );

      expect(fork, isNotNull);
      expect(fork!.id, isNot('source'));
      expect(fork.title, 'Fork title');
      expect(fork.assistantId, 'assistant');
      expect(fork.isPinned, isFalse);
      expect(fork.mcpServerIds, isEmpty);
      expect(fork.truncateIndex, -1);
      expect(fork.summary, isNull);
      expect(fork.chatSuggestions, isEmpty);
      expect(fork.injectedMemoryHash, isNull);
      expect(fork.lastMemoryExtractedOrder, -1);
      expect(fork.messageIds, hasLength(3));
      expect(
        fork.messageIds,
        isNot(contains(anyOf('u1', 'a1v0', 'a1v1', 'u2', 'a2'))),
      );

      final messages = await repository.getMessagesRange(
        fork.id,
        start: 0,
        limit: 20,
      );
      expect(messages.map((message) => message.content), [
        'question 1',
        'first answer',
        'second answer',
      ]);
      expect(messages.map((message) => message.conversationId).toSet(), {
        fork.id,
      });
      expect(messages.map((message) => message.version), [0, 0, 1]);

      final remappedUserGroup = messages.first.groupId ?? messages.first.id;
      final remappedA1Group = messages[1].groupId ?? messages[1].id;
      expect(messages[2].groupId ?? messages[2].id, remappedA1Group);
      expect(remappedA1Group, isNot('a1'));
      expect(remappedUserGroup, isNot('u1'));
      expect(remappedA1Group, isNot(remappedUserGroup));
      expect(fork.versionSelections, {remappedA1Group: 1});

      expect(await repository.getToolEvents(messages.last.id), [
        {'id': 'tool-call', 'result': 'done'},
      ]);
      expect(
        await repository.getGeminiThoughtSignature(messages.last.id),
        'signature',
      );
      // Any provider artifact rides along with its revision, not just the
      // Gemini signature.
      expect(
        await repository.getProviderArtifactsForMessages([
          messages.last.id,
        ], 'claude_container'),
        {messages.last.id: '{"id":"container_1"}'},
      );

      final raw = sqlite.sqlite3.open('${directory.path}/chat.sqlite');
      try {
        expect(
          raw.select(
            'SELECT COUNT(*) AS n FROM message_part_rows '
            'WHERE conversation_id = ?;',
            [fork.id],
          ).single['n'],
          greaterThan(0),
        );
        expect(
          raw.select(
            'SELECT COUNT(*) AS n FROM provider_artifact_rows '
            'WHERE conversation_id = ? AND revision_id = ?;',
            [fork.id, messages.last.id],
          ).single['n'],
          greaterThan(0),
        );
      } finally {
        raw.close();
      }
    });

    test(
      'keeps a later roll of an earlier group when forking at that group',
      () async {
        final createdAt = DateTime.utc(2026, 8, 2);
        await repository.putMigrationBatch(
          conversations: [
            Conversation(
              id: 'source',
              title: 'Rolled',
              createdAt: createdAt,
              updatedAt: createdAt,
              messageIds: const ['u1', 'a1v0', 'u2', 'a1v1'],
              assistantId: 'assistant',
              versionSelections: const {'a1': 1},
            ),
          ],
          messages: [
            (
              message: ChatMessage(
                id: 'u1',
                role: 'user',
                content: 'q1',
                conversationId: 'source',
                groupId: 'u1',
                version: 0,
                timestamp: createdAt,
              ),
              messageOrder: 0,
            ),
            (
              message: ChatMessage(
                id: 'a1v0',
                role: 'assistant',
                content: 'a1-v0',
                conversationId: 'source',
                groupId: 'a1',
                version: 0,
                timestamp: createdAt.add(const Duration(minutes: 1)),
              ),
              messageOrder: 1,
            ),
            (
              message: ChatMessage(
                id: 'u2',
                role: 'user',
                content: 'q2',
                conversationId: 'source',
                groupId: 'u2',
                version: 0,
                timestamp: createdAt.add(const Duration(minutes: 2)),
              ),
              messageOrder: 2,
            ),
            (
              message: ChatMessage(
                id: 'a1v1',
                role: 'assistant',
                content: 'a1-v1',
                conversationId: 'source',
                groupId: 'a1',
                version: 1,
                timestamp: createdAt.add(const Duration(minutes: 3)),
              ),
              messageOrder: 3,
            ),
          ],
          toolEventsByMessageId: const {},
          geminiSignaturesByMessageId: const {},
        );

        final fork = await repository.forkConversationWithVersions(
          sourceId: 'source',
          targetRevisionId: 'a1v0',
          title: 'Rolled fork',
          assistantId: 'assistant',
        );

        expect(fork, isNotNull);
        final messages = await repository.getMessagesRange(
          fork!.id,
          start: 0,
          limit: 20,
        );
        expect(messages.map((message) => message.content), [
          'q1',
          'a1-v0',
          'a1-v1',
        ]);
        expect(messages.map((message) => message.version), [0, 0, 1]);
        final remappedA1 = messages[1].groupId ?? messages[1].id;
        expect(messages[2].groupId ?? messages[2].id, remappedA1);
        expect(fork.versionSelections, {remappedA1: 0});
        expect(
          messages.map((message) => message.content),
          isNot(contains('q2')),
        );
      },
    );

    test('returns null when the source topic does not exist', () async {
      expect(
        await repository.forkConversationWithVersions(
          sourceId: 'missing',
          targetRevisionId: 'rev',
          title: 'Fork',
        ),
        isNull,
      );
    });

    test('returns null when the target revision is missing', () async {
      final createdAt = DateTime.utc(2026, 8, 3);
      await repository.putMigrationBatch(
        conversations: [
          Conversation(
            id: 'source',
            title: 'Topic',
            createdAt: createdAt,
            updatedAt: createdAt,
          ),
        ],
        messages: [
          (
            message: ChatMessage(
              id: 'only',
              role: 'user',
              content: 'hi',
              conversationId: 'source',
              groupId: 'only',
              version: 0,
              timestamp: createdAt,
            ),
            messageOrder: 0,
          ),
        ],
        toolEventsByMessageId: const {},
        geminiSignaturesByMessageId: const {},
      );

      expect(
        await repository.forkConversationWithVersions(
          sourceId: 'source',
          targetRevisionId: 'missing-rev',
          title: 'Fork',
        ),
        isNull,
      );
    });

    test(
      'returns null when the target revision belongs to another conversation',
      () async {
        final createdAt = DateTime.utc(2026, 8, 4);
        await repository.putMigrationBatch(
          conversations: [
            Conversation(
              id: 'source',
              title: 'A',
              createdAt: createdAt,
              updatedAt: createdAt,
            ),
            Conversation(
              id: 'other',
              title: 'B',
              createdAt: createdAt,
              updatedAt: createdAt,
            ),
          ],
          messages: [
            (
              message: ChatMessage(
                id: 'src-msg',
                role: 'user',
                content: 'a',
                conversationId: 'source',
                groupId: 'src-msg',
                version: 0,
                timestamp: createdAt,
              ),
              messageOrder: 0,
            ),
            (
              message: ChatMessage(
                id: 'other-msg',
                role: 'user',
                content: 'b',
                conversationId: 'other',
                groupId: 'other-msg',
                version: 0,
                timestamp: createdAt,
              ),
              messageOrder: 0,
            ),
          ],
          toolEventsByMessageId: const {},
          geminiSignaturesByMessageId: const {},
        );

        expect(
          await repository.forkConversationWithVersions(
            sourceId: 'source',
            targetRevisionId: 'other-msg',
            title: 'Fork',
          ),
          isNull,
        );
      },
    );
  });
}
