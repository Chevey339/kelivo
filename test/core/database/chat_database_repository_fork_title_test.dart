import 'dart:io';

import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/context_operation.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  late ChatDatabaseRepository repository;
  const sourceId = 'source';
  const messageId = 'message';
  const title = '项目讨论';

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('kelivo_fork_titles_');
    repository = ChatDatabaseRepository.open(
      file: File('${directory.path}/chat.sqlite'),
    );
    await repository.ensureReady();
    await repository.appendLinearMessageToConversation(
      conversation: Conversation(id: sourceId, title: title),
      message: ChatMessage(
        id: messageId,
        conversationId: sourceId,
        role: 'user',
        content: 'Discuss the project',
      ),
    );
  });

  tearDown(() async {
    await repository.close();
    await directory.delete(recursive: true);
  });

  Future<Conversation> fork({
    String from = sourceId,
    String at = messageId,
    bool preserveVersions = false,
  }) async => (await repository.forkConversationWithVersions(
    sourceId: from,
    targetRevisionId: at,
    preserveVersions: preserveVersions,
  ))!;

  Future<Conversation> compact() async {
    final snapshot = await repository.readContextSnapshot(sourceId);
    return repository.createCompressedConversation(
      sourceId,
      ContextOperation(
        id: 'compression',
        kind: ContextOperationKind.compress,
        anchorGroupId: messageId,
        appliedAfterGroupId: messageId,
        sourceGroups: const [messageId],
        dependencies: const [],
        createdAt: DateTime.now(),
        summary: 'Project summary',
      ),
      expectedFingerprint: snapshot.fingerprint,
      retained: const [],
    );
  }

  test(
    'all persisted fork paths share the sequence, including nested forks',
    () async {
      final first = await fork();
      expect(first.title, '$title (1)');
      final nested = await fork(from: first.id, at: first.messageIds.single);
      expect(nested.title, '$title (2)');
      expect((await fork(preserveVersions: true)).title, '$title (3)');
      expect(
        (await repository.duplicateConversation(nested.id))!.title,
        '$title (4)',
      );
      expect((await compact()).title, '$title (5)');
      final selected = Conversation(title: first.title);
      await repository.putForkConversation(selected);
      expect(selected.title, '$title (6)');
      expect((await repository.getConversation(sourceId))!.title, title);
    },
  );

  test(
    'skips persisted names across assistants and reuses gaps after reload',
    () async {
      for (final number in [1, 3]) {
        await repository.putConversation(
          Conversation(
            id: 'occupied-$number',
            title: '$title ($number)',
            assistantId: 'another-assistant',
          ),
        );
      }
      final second = await fork();
      expect(second.title, '$title (2)');
      await repository.close();
      repository = ChatDatabaseRepository.open(
        file: File('${directory.path}/chat.sqlite'),
      );
      await repository.ensureReady();
      expect(
        (await repository.duplicateConversation(sourceId))!.title,
        '$title (4)',
      );
      await repository.deleteConversation(second.id);
      expect((await fork()).title, '$title (2)');
    },
  );

  test(
    'concurrent forks reserve distinct titles across creation paths',
    () async {
      final copies = await Future.wait([
        for (var i = 0; i < 3; i++) ...[
          fork(preserveVersions: i.isEven),
          repository.duplicateConversation(sourceId),
          compact(),
        ],
      ]);
      expect(copies.map((copy) => copy!.title).toSet(), {
        for (var number = 1; number <= 9; number++) '$title ($number)',
      });
    },
  );

  test('failed copies leave the next number available', () async {
    expect(
      await repository.forkConversationWithVersions(
        sourceId: sourceId,
        targetRevisionId: 'missing',
      ),
      isNull,
    );
    expect((await fork()).title, '$title (1)');
  });

  for (final sourceTitle in ['Plan (draft)', r'100%_ [a-z].* \\ 讨论', '']) {
    test('preserves literal base title: $sourceTitle', () async {
      final source = (await repository.getConversation(sourceId))!;
      await repository.putConversation(source.copyWith(title: sourceTitle));
      expect((await fork()).title, '$sourceTitle (1)');
      expect(
        (await repository.duplicateConversation(sourceId))!.title,
        '$sourceTitle (2)',
      );
    });
  }

  test(
    'large and repeated numeric suffixes use the same base without nesting',
    () async {
      final source = (await repository.getConversation(sourceId))!;
      await repository.putConversation(
        source.copyWith(title: '$title (999999999999999999999999999) (7)'),
      );
      expect((await fork()).title, '$title (1)');
    },
  );
}
