import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';

void main() {
  group('ChatDatabaseRepository clearAllData', () {
    late Directory directory;
    late ChatDatabaseRepository repository;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp(
        'kelivo_repository_clear_test_',
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
      'preserves migration receipt and clears runtime streaming state',
      () async {
        await repository.markMigrationComplete();

        await repository.clearAllData();

        expect(await repository.isMigrationComplete(), isTrue);
        expect(await repository.getActiveStreamingIds(), isEmpty);
      },
    );

    test('replaces all backup data in one transaction', () async {
      await repository.putMigrationBatch(
        conversations: [
          Conversation(
            id: 'existing-conversation',
            title: 'Existing',
            messageIds: const ['existing-message'],
          ),
        ],
        messages: [
          (
            message: ChatMessage(
              id: 'existing-message',
              role: 'user',
              content: 'existing',
              conversationId: 'existing-conversation',
            ),
            messageOrder: 0,
          ),
        ],
        toolEventsByMessageId: const {},
        geminiSignaturesByMessageId: const {},
      );

      await repository.replaceBackupData(
        conversations: [
          Conversation(
            id: 'restored-conversation',
            title: 'Restored',
            messageIds: const ['restored-message'],
          ),
        ],
        messages: [
          (
            message: ChatMessage(
              id: 'restored-message',
              role: 'assistant',
              content: 'restored',
              conversationId: 'restored-conversation',
            ),
            messageOrder: 0,
          ),
        ],
        toolEventsByMessageId: const {
          'restored-message': [
            {'id': 'tool-event'},
          ],
        },
        geminiSignaturesByMessageId: const {'restored-message': 'signature'},
      );

      expect(await repository.getConversation('existing-conversation'), isNull);
      expect(
        await repository.getConversation('restored-conversation'),
        isNotNull,
      );
      expect(await repository.getToolEvents('restored-message'), const [
        {'id': 'tool-event'},
      ]);
      expect(
        await repository.getGeminiThoughtSignature('restored-message'),
        'signature',
      );
      expect(await repository.isMigrationComplete(), isTrue);
      expect(await repository.getActiveStreamingIds(), isEmpty);
    });

    test(
      'rolls back deletion when replacement data cannot be written',
      () async {
        await repository.putMigrationBatch(
          conversations: [
            Conversation(
              id: 'existing-conversation',
              title: 'Existing',
              messageIds: const ['existing-message'],
            ),
          ],
          messages: [
            (
              message: ChatMessage(
                id: 'existing-message',
                role: 'user',
                content: 'existing',
                conversationId: 'existing-conversation',
              ),
              messageOrder: 0,
            ),
          ],
          toolEventsByMessageId: const {},
          geminiSignaturesByMessageId: const {},
        );

        await expectLater(
          repository.replaceBackupData(
            conversations: const [],
            messages: [
              (
                message: ChatMessage(
                  id: 'orphan-message',
                  role: 'user',
                  content: 'orphan',
                  conversationId: 'missing-conversation',
                ),
                messageOrder: 0,
              ),
            ],
            toolEventsByMessageId: const {},
            geminiSignaturesByMessageId: const {},
          ),
          throwsA(anything),
        );

        expect(
          await repository.getConversation('existing-conversation'),
          isNotNull,
        );
        expect(
          await repository.getConversation('missing-conversation'),
          isNull,
        );
        expect(await repository.getMessageCount('existing-conversation'), 1);
        expect(await repository.getActiveStreamingIds(), isEmpty);
      },
    );
  });
}
