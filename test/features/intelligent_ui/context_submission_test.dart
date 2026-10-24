import 'dart:async';
import 'package:drift/drift.dart' show ApplyInterceptor;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/database/generation_run.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/features/intelligent_ui/host/ui_context_submission.dart';
import 'package:Kelivo/features/intelligent_ui/host/ui_user_context_parts.dart';
import 'package:Kelivo/features/intelligent_ui/models/ui_context_attachment.dart';
import 'package:Kelivo/features/intelligent_ui/protocol/ui_source_hash.dart';
import 'package:Kelivo/features/intelligent_ui/protocol/ui_stream_parser.dart';
import '../../support/commit_gate.dart';

const _source = '''ui 1 catalog "kelivo.native/1"
root = Metric(label="Result", value=42)
''';

void main() {
  late AppDatabase db;
  late ChatDatabaseRepository repo;
  late CommitGate commits;
  late Conversation conversation;
  late ChatMessage source;
  late UiContextAttachment attachment;
  final frozen = UiContextText(title: 'Frozen result', body: 'Result: 42 kg');
  UiContextSubmission request([UiContextAttachment? value]) =>
      UiContextSubmission(
        value ?? attachment,
        omittedText: 'Source unavailable; UI state omitted.',
      );
  Future<void> complete(String id) async {
    var run = await repo.createGenerationRun(
      id: 'run-$id',
      conversationId: 'source-chat',
      targetRevisionId: id,
      createdAt: DateTime.now(),
    );
    for (final next in [
      GenerationRunState.requesting,
      GenerationRunState.streaming,
      GenerationRunState.completed,
    ]) {
      run = await repo.transitionGenerationRun(
        id: run.id,
        expectedState: run.state,
        expectedStateRevision: run.stateRevision,
        nextState: next,
        updatedAt: DateTime.now(),
      );
    }
  }

  Future<PersistedChatMessage> send({
    String text = 'Explain',
    String? target,
  }) async {
    final destination = target == null
        ? conversation
        : Conversation(id: target, title: target);
    return repo.appendLinearMessageToConversation(
      conversation: destination,
      message: ChatMessage(
        role: 'user',
        conversationId: destination.id,
        content: text,
      ),
      uiContext: request(),
    );
  }

  setUp(() async {
    commits = CommitGate();
    db = AppDatabase(NativeDatabase.memory().interceptWith(commits));
    repo = ChatDatabaseRepository(db);
    await repo.ensureReady();
    conversation = Conversation(id: 'source-chat', title: 'Source');
    await repo.putConversation(conversation);
    source = ChatMessage(
      id: 'source',
      conversationId: conversation.id,
      role: 'assistant',
      content: '```kelivo-ui\n$_source```',
    );
    await repo.putMessage(source);
    await complete(source.id);
    attachment = UiContextAttachment.attached(
      source: UiContextSource(
        conversationId: conversation.id,
        revisionId: source.id,
        surfaceKey: '0:0',
        sourceHash: uiSourceHash(
          UiStreamParser().update(_source, closed: true).source,
        ),
      ),
      text: frozen,
    );
  });
  tearDown(() async => repo.close());

  test(
    'fresh database needs no lazily installed timeline; parts stay distinct',
    () async {
      expect(await repo.isUiContextCurrent(attachment.source!), isTrue);
      final sent = await send(text: '');
      final saved = (await repo.getMessage(sent.message.id))!;
      expect(saved.parts.whereType<TextPart>().map((p) => p.text), [
        frozen.exactText,
        '\n\n',
      ]);
      expect(sent.message.content, saved.content);
      expect(UiUserContextParts.read(saved.parts).context, frozen);
      expect(UiUserContextParts.read(saved.parts).bodyText, '');
    },
  );

  test('explicit draft transfer retains original-source provenance', () async {
    final sent = await send(target: 'other-chat');
    expect(sent.message.conversationId, 'other-chat');
    expect(UiUserContextParts.read(sent.message.parts).context, frozen);
  });

  test(
    'regeneration deselects source even with unchanged original hash/run',
    () async {
      final next = await repo.appendMessageVersion(
        messageId: source.id,
        content: source.content,
      );
      await complete(next!.message.id);
      expect(await repo.isUiContextCurrent(attachment.source!), isFalse);
      final sent = await send();
      expect(sent.message.content, contains('Source unavailable'));
      expect(sent.message.content, isNot(contains('42 kg')));
      await repo.setSelectedVersion(
        conversationId: conversation.id,
        groupId: source.id,
        version: 0,
      );
      expect(await repo.isUiContextCurrent(attachment.source!), isTrue);
    },
  );

  test('source replacement cannot silently supply another state', () async {
    await repo.putMessage(
      source.copyWith(
        content: '```kelivo-ui\n${_source.replaceFirst('42', '99')}```',
      ),
    );
    final sent = await send();
    expect(sent.message.content, contains('omitted'));
    expect(sent.message.content, isNot(contains('42 kg')));
  });

  test(
    'queued source deletion commits before send resolves attachment',
    () async {
      final entered = Completer<void>(), release = Completer<void>();
      commits.onNextCommit = () async {
        entered.complete();
        await release.future;
      };
      final deletion = repo.deleteMessages(
        conversationId: conversation.id,
        messageIds: {source.id},
        versionSelectionChanges: const {},
      );
      await entered.future;
      var finished = false;
      final pending = send().then((value) {
        finished = true;
        return value;
      });
      await Future<void>.delayed(Duration.zero);
      expect(finished, isFalse);
      release.complete();
      await deletion;
      expect((await pending).message.content, contains('Source unavailable'));
    },
  );

  test(
    'generation result and database use the same resolved message',
    () async {
      final user = ChatMessage(
        role: 'user',
        conversationId: conversation.id,
        content: 'Question',
      );
      final result = await repo.beginSendGeneration(
        conversation: conversation,
        userMessage: user,
        assistantMessage: ChatMessage(
          role: 'assistant',
          conversationId: conversation.id,
          content: '',
          isStreaming: true,
        ),
        runId: 'new-run',
        uiContext: request(),
      );
      expect(
        UiUserContextParts.read(result.userMessage!.parts).context,
        frozen,
      );
      expect(
        (await repo.getMessage(user.id))!.content,
        result.userMessage!.content,
      );
      expect(
        user.content,
        'Question',
      ); // Input object is never mutated precommit.
    },
  );

  test(
    'failed commit neither publishes changed parts nor inserts a message',
    () async {
      final user = ChatMessage(
        role: 'user',
        conversationId: conversation.id,
        content: 'Question',
      );
      commits.onNextCommit = () async => throw StateError('commit failed');
      await expectLater(
        repo.appendLinearMessageToConversation(
          conversation: conversation,
          message: user,
          uiContext: request(),
        ),
        throwsStateError,
      );
      expect(user.content, 'Question');
      expect(await repo.getMessage(user.id), isNull);
    },
  );

  test(
    'editing an already sent chip preserves history after source deletion',
    () async {
      final sent = await send();
      await repo.deleteMessage(source.id);
      final edited = await repo.appendMessageVersion(
        messageId: sent.message.id,
        parts: const [TextPart('Edited question')],
        uiContext: request(UiContextAttachment.history(frozen)),
      );
      expect(UiUserContextParts.read(edited!.message.parts).context, frozen);
      expect(
        UiUserContextParts.read(edited.message.parts).bodyText,
        'Edited question',
      );
      expect(
        (await repo.getMessage(edited.message.id))!.content,
        edited.message.content,
      );
    },
  );

  test(
    'fresh chip-only edit of stale source still produces a visible message',
    () async {
      final sent = await send();
      await repo.deleteMessage(source.id);
      final edited = await repo.appendMessageVersion(
        messageId: sent.message.id,
        parts: const [TextPart('')],
        uiContext: request(),
      );
      expect(
        edited!.message.content.trim(),
        'Source unavailable; UI state omitted.',
      );
      expect(UiUserContextParts.read(edited.message.parts).context, isNull);
    },
  );
}
