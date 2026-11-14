import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/features/chat/services/conversation_find_service.dart';

void main() {
  test(
    'pages selected revisions in order, ignores tools and other conversations',
    () async {
      final repo = ChatDatabaseRepository(AppDatabase(NativeDatabase.memory()));
      addTearDown(repo.close);
      await repo.ensureReady();
      final c = Conversation(
        id: 'c',
        title: 'find',
        versionSelections: {'g': 0},
      );
      final other = Conversation(id: 'd', title: 'other');
      ChatMessage message(
        String id,
        String text, {
        String? group,
        int version = 0,
        String role = 'assistant',
        String conversation = 'c',
        List<MessagePart>? parts,
      }) => ChatMessage(
        id: id,
        role: role,
        content: text,
        groupId: group,
        version: version,
        conversationId: conversation,
        parts: parts,
      );
      final messages = [
        message('first', '🙂match match'),
        message('old', 'match', group: 'g'),
        message('new', 'new version', group: 'g', version: 1),
        message('tool', 'match', role: 'tool'),
        message('other', 'match', conversation: 'd'),
        message(
          'structured',
          '',
          parts: const [
            TextPart('visible'),
            ToolCallPart(
              '{"id":"t","name":"tool","arguments":{"q":"match"},"content":"match"}',
            ),
          ],
        ),
        for (var i = 0; i < 60; i++) message('m$i', 'ordinary'),
        message('last', 'match'),
      ];
      await repo.putMigrationBatch(
        conversations: [c, other],
        messages: [
          for (final (index, msg) in messages.indexed)
            (message: msg, messageOrder: index),
        ],
        toolEventsByMessageId: const {},
        geminiSignaturesByMessageId: const {},
      );
      Future<List<ConversationFindHit>> search(String q) async =>
          (await const ConversationFindService().search(
            repo.conversationFindCandidates('c'),
            q,
            defaultFindOptions,
          )).values.expand((h) => h).toList();
      expect((await search('match')).map((h) => h.messageId), [
        'first',
        'first',
        'old',
        'last',
      ]);
      expect(await search('new version'), isEmpty);
      await repo.putConversation(c.copyWith(versionSelections: {'g': 1}));
      expect((await search('new version')).single.messageId, 'new');
      expect((await search('match')).map((h) => h.messageId), [
        'first',
        'first',
        'last',
      ]);
    },
  );
}
