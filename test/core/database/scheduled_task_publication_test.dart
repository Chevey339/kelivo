import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import '../../support/business_test_harness.dart';

void main() {
  late ChatDatabaseRepository repo;
  late Conversation conversation;
  setUp(() async {
    final storage = await createBusinessTestHarness();
    repo = ChatDatabaseRepository(storage.database);
    conversation = Conversation(id: 'chat', title: 'Chat', assistantId: 'a');
    await repo.putConversation(conversation);
  });
  Future<Conversation> publish({String? revision, bool create = false}) =>
      repo.publishScheduledMessages(
        conversation: conversation,
        createConversation: create,
        expectedContextRevision: revision,
        instruction: ChatMessage(
          id: 'run:instruction',
          conversationId: conversation.id,
          role: 'user',
          content: 'Task instruction',
        ),
        response: ChatMessage(
          id: 'run:result',
          conversationId: conversation.id,
          role: 'assistant',
          content: 'Prepared result',
        ),
      );
  test(
    'publication is idempotent across crash recovery, including both messages',
    () async {
      final revision = await repo.scheduledContextRevision(conversation.id);
      await publish(revision: revision);
      await publish(revision: revision);
      final messages = await repo.getSelectedMessageProjections(
        conversation.id,
      );
      expect(messages.map((m) => m.id), ['run:instruction', 'run:result']);
      expect(messages.last.content, 'Prepared result');
    },
  );
  test(
    'stale result appends neither instruction nor assistant message',
    () async {
      final revision = await repo.scheduledContextRevision(conversation.id);
      await repo.appendLinearMessageToConversation(
        conversation: conversation,
        message: ChatMessage(
          id: 'new',
          conversationId: conversation.id,
          role: 'user',
          content: 'Plans changed',
        ),
      );
      await expectLater(publish(revision: revision), throwsStateError);
      expect(await repo.getMessage('run:instruction'), isNull);
      expect(await repo.getMessage('run:result'), isNull);
    },
  );
  test(
    'an edit to old history changes the lightweight context revision',
    () async {
      await repo.appendLinearMessageToConversation(
        conversation: conversation,
        message: ChatMessage(
          id: 'old',
          conversationId: conversation.id,
          role: 'user',
          content: 'Interview tomorrow',
        ),
      );
      final revision = await repo.scheduledContextRevision(conversation.id);
      await repo.updateMessageFields('old', content: 'Interview cancelled');
      expect(
        await repo.scheduledContextRevision(conversation.id),
        isNot(revision),
      );
      await expectLater(publish(revision: revision), throwsStateError);
    },
  );
  test(
    'new chat is created only by publication and is reused on retry',
    () async {
      conversation = Conversation(
        id: 'new-chat',
        title: 'Scheduled',
        assistantId: 'a',
      );
      expect(await repo.getConversation(conversation.id), isNull);
      await publish(create: true);
      await publish(create: true);
      expect(
        (await repo.getSelectedMessageProjections(conversation.id)),
        hasLength(2),
      );
    },
  );
  test('deleted target is not recreated by a follow-up result', () async {
    conversation = Conversation(
      id: 'missing',
      title: 'Deleted',
      assistantId: 'a',
    );
    await expectLater(publish(), throwsStateError);
    expect(await repo.getConversation(conversation.id), isNull);
  });
}
