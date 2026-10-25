import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/context_operation.dart';
import 'package:Kelivo/core/models/message_part.dart';

void main() {
  late Directory dir;
  late ChatDatabaseRepository repo;
  final conversation = Conversation(id: 'chat', title: 'Keep my title');
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('context_nodes_');
    repo = ChatDatabaseRepository.open(file: File('${dir.path}/chat.sqlite'));
    await repo.ensureReady();
    for (final id in ['u1', 'a1', 'u2', 'a2', 'u3', 'a3']) {
      await repo.appendLinearMessageToConversation(
        conversation: conversation,
        message: ChatMessage(
          id: id,
          role: id.startsWith('u') ? 'user' : 'assistant',
          content: 'Original $id',
          conversationId: 'chat',
        ),
      );
    }
  });
  tearDown(() async {
    await repo.close();
    await dir.delete(recursive: true);
  });

  Future<ContextOperation> compact(
    String id,
    List<String> groups, {
    List<String> depends = const [],
  }) async {
    final snapshot = await repo.readContextSnapshot('chat');
    final op = ContextOperation(
      id: id,
      kind: ContextOperationKind.compress,
      anchorGroupId: groups.last,
      appliedAfterGroupId: 'a3',
      sourceGroups: groups,
      dependencies: depends,
      createdAt: DateTime(2026),
      summary: 'Summary $id',
      originalSummary: 'Summary $id',
    );
    await repo.appendContextOperation(
      'chat',
      op,
      expectedFingerprint: snapshot.fingerprint,
    );
    return op;
  }

  Future<List<String>> effective() async =>
      (await repo.getEffectiveContextMessages(
        'chat',
        limit: 100,
      )).map((m) => m.content).toList();

  test(
    'in-place summary preserves originals, title, tail and raw message window',
    () async {
      await compact('S1', ['u1', 'a1']);
      expect(await effective(), [
        'Summary S1',
        'Original u2',
        'Original a2',
        'Original u3',
        'Original a3',
      ]);
      expect(
        (await repo.getEffectiveContextMessages(
          'chat',
          limit: 1,
        )).map((m) => m.content),
        ['Summary S1', 'Original a3'],
      );
      expect((await repo.readContextSnapshot('chat')).messages.length, 6);
      expect((await repo.getConversation('chat'))!.title, 'Keep my title');
    },
  );

  test(
    'source append version and dependent revocations commit together',
    () async {
      await compact('S1', ['u1', 'a1']);
      await compact('S2', ['u1', 'a1', 'u2', 'a2'], depends: ['S1']);
      final state = ContextHistory.operationsFingerprint(
        await repo.readContextOperations('chat'),
      );
      final edited = await repo.appendMessageVersion(
        messageId: 'u1',
        content: 'corrected',
        expectedContextState: state,
      );
      expect(edited, isNotNull);
      expect(
        (await repo.readContextOperations('chat')).every((op) => op.revoked),
        isTrue,
      );
      expect((await effective()).first, 'corrected');
      expect((await effective()).last, 'Original a3');
    },
  );

  test(
    'a new node after confirmation rejects the source edit without partial writes',
    () async {
      await compact('S1', ['u1', 'a1']);
      final state = ContextHistory.operationsFingerprint(
        await repo.readContextOperations('chat'),
      );
      await compact('S2', ['u1', 'a1', 'u2', 'a2'], depends: ['S1']);
      await expectLater(
        repo.appendMessageVersion(
          messageId: 'u1',
          content: 'not committed',
          expectedContextState: state,
        ),
        throwsStateError,
      );
      expect(
        (await repo.readContextSnapshot('chat')).messages.first.content,
        'Original u1',
      );
      expect(
        (await repo.readContextOperations('chat')).every((op) => !op.revoked),
        isTrue,
      );
    },
  );

  test('stale compression result cannot overwrite edited source', () async {
    final snapshot = await repo.readContextSnapshot('chat');
    final op = await compact('S1', ['u1', 'a1']);
    await repo.updateMessageFields('u1', content: 'changed');
    await expectLater(
      repo.appendContextOperation(
        'chat',
        ContextOperation(
          id: 'late',
          kind: op.kind,
          anchorGroupId: op.anchorGroupId,
          appliedAfterGroupId: op.appliedAfterGroupId,
          sourceGroups: op.sourceGroups,
          dependencies: [],
          createdAt: op.createdAt,
          summary: 'stale',
        ),
        expectedFingerprint: snapshot.fingerprint,
      ),
      throwsStateError,
    );
    expect((await effective()).first, 'changed');
  });

  test(
    'historical regeneration uses original history and keeps following assistant',
    () async {
      await compact('S1', ['u1', 'a1']);
      final selected = await repo.appendMessageVersion(
        messageId: 'u3',
        content: 'selected version',
      );
      // Regenerating with the original revision id resolves the logical group.
      final result = await repo.getEffectiveContextMessages(
        'chat',
        limit: 100,
        throughRevisionId: 'u3',
        includeFollowingAssistant: true,
      );
      expect(result.map((m) => m.id), [
        'u1',
        'a1',
        'u2',
        'a2',
        selected!.message.id,
        'a3',
      ]);
    },
  );

  test(
    'delete source revokes summary and retains independent later node',
    () async {
      await compact('S1', ['u1', 'a1']);
      await compact('S2', ['u2', 'a2']);
      await repo.deleteMessages(
        conversationId: 'chat',
        messageIds: {'u1'},
        versionSelectionChanges: {},
      );
      final operations = await repo.readContextOperations('chat');
      expect(operations.map((op) => op.revoked), [true, false]);
      expect(await effective(), [
        'Original a1',
        'Summary S2',
        'Original u3',
        'Original a3',
      ]);
    },
  );

  test('undo and guarded restore preserve later messages', () async {
    await compact('S1', ['u1', 'a1']);
    final before = await repo.readContextOperations('chat');
    await repo.changeContextOperation(
      'chat',
      'S1',
      includeDependents: true,
      expectedState: ContextHistory.operationsFingerprint(before),
    );
    final undone = await repo.readContextSnapshot('chat');
    await repo.restoreContextOperations(
      'chat',
      before,
      expectedFingerprint: undone.fingerprint,
    );
    expect((await effective()).first, 'Summary S1');
    await repo.updateMessageFields('u2', content: 'changed after undo');
    await expectLater(
      repo.restoreContextOperations(
        'chat',
        before,
        expectedFingerprint: undone.fingerprint,
      ),
      throwsStateError,
    );
  });

  test(
    'old clear boundary converts once atomically without changing title',
    () async {
      final old = (await repo.getConversation(
        'chat',
      ))!.copyWith(truncateIndex: 2);
      await repo.putConversation(old);
      final first = await repo.readContextOperations('chat');
      expect(first.single.kind, ContextOperationKind.clear);
      expect(first.single.anchorGroupId, 'a1');
      expect((await repo.getConversation('chat'))!.truncateIndex, -1);
      expect(
        (await repo.readContextOperations('chat')).single.id,
        first.single.id,
      );
      expect(await effective(), [
        'Original u2',
        'Original a2',
        'Original u3',
        'Original a3',
      ]);
    },
  );

  test('duplicate remaps context nodes and keeps editable summary', () async {
    await compact('S1', ['u1', 'a1']);
    final ops = await repo.readContextOperations('chat');
    await repo.changeContextOperation(
      'chat',
      'S1',
      summary: 'manual decision',
      includeDependents: true,
      expectedState: ContextHistory.operationsFingerprint(ops),
    );
    final copy = await repo.duplicateConversation('chat');
    final copied = await repo.readContextOperations(copy!.id);
    expect(copied.single.id, isNot('S1'));
    expect(copied.single.sourceGroups, isNot(contains('u1')));
    expect(copied.single.isEdited, isTrue);
    expect(
      (await repo.getEffectiveContextMessages(
        copy.id,
        limit: 100,
      )).first.content,
      'manual decision',
    );
  });

  test('node and completed task status share a transaction', () async {
    await repo.saveCompressionTask('chat', {'id': 'S1', 'phase': 'applying'});
    await compact('S1', ['u1', 'a1']);
    expect((await repo.readCompressionTasks())['chat']!['phase'], 'completed');
    await repo.deleteConversation('chat');
    await repo.saveCompressionTask('chat', {'id': 'late', 'phase': 'failed'});
    expect(await repo.readCompressionTasks(), isEmpty);
  });
  test(
    'backup merge preserves context nodes, remaps references and deduplicates repeated imports',
    () async {
      await compact('S1', ['u1', 'a1']);
      await compact('S2', ['u2', 'a2']);
      await repo.deleteMessages(
        conversationId: 'chat',
        messageIds: {'u1'},
        versionSelectionChanges: {},
      );
      final snapshotFile = File('${dir.path}/snapshot.sqlite');
      await ChatDatabaseRepository.createConsistentSnapshot(
        sourceFile: File('${dir.path}/chat.sqlite'),
        destinationFile: snapshotFile,
      );
      final target = ChatDatabaseRepository.open(
        file: File('${dir.path}/import.sqlite'),
      );
      await target.ensureReady();
      try {
        await target.putConversation(
          Conversation(id: 'chat', title: 'collision'),
        );
        final report = await target.mergeBackupSnapshot(snapshotFile);
        final id = report.remappedConversationIds['chat']!;
        final imported = await target.readContextOperations(id);
        expect(imported.length, 2);
        expect(imported.first.revoked, isTrue);
        expect(imported.last.summary, 'Summary S2');
        expect(
          (await target.getEffectiveContextMessages(
            id,
            limit: 100,
          )).map((m) => m.content),
          ['Original a1', 'Summary S2', 'Original u3', 'Original a3'],
        );
        final second = await target.mergeBackupSnapshot(snapshotFile);
        expect(second.importedConversations, 0);
        expect(second.deduplicatedConversations, 1);
      } finally {
        await target.close();
      }
    },
  );

  test(
    'chats-only attachment availability preserves summaries and deduplication',
    () async {
      await repo.updateMessage(
        (await repo.getMessage('u1'))!.copyWith(
          parts: [
            const TextPart('Original u1'),
            ImagePart(uri: '${dir.path}/photo.png'),
            FilePart(uri: '${dir.path}/document.txt', name: 'document.txt'),
          ],
        ),
      );
      await compact('S1', ['u1', 'a1']);
      await compact('S2', ['u1', 'a1', 'u2', 'a2'], depends: ['S1']);
      final snapshotFile = File('${dir.path}/attachments.sqlite');
      await ChatDatabaseRepository.createConsistentSnapshot(
        sourceFile: File('${dir.path}/chat.sqlite'),
        destinationFile: snapshotFile,
      );
      final target = ChatDatabaseRepository.open(
        file: File('${dir.path}/import.sqlite'),
      );
      await target.ensureReady();
      try {
        final report = await target.mergeBackupSnapshot(snapshotFile);
        expect(report.importedConversations, 1);
        expect(
          await target.recomputeAttachmentAvailabilityForConversations(
            conversationIds: report.importedConversationIds,
            filesRestored: false,
          ),
          1,
        );
        final imported = (await target.getMessage('u1'))!;
        expect(
          imported.parts.whereType<ImagePart>().single.unavailable,
          isTrue,
        );
        expect(imported.parts.whereType<FilePart>().single.unavailable, isTrue);
        expect(
          (await target.readContextOperations(
            'chat',
          )).every((op) => !op.revoked),
          isTrue,
        );
        expect(
          (await target.getEffectiveContextMessages(
            'chat',
            limit: 100,
          )).map((m) => m.content),
          ['Summary S2', 'Original u3', 'Original a3'],
        );
        final again = await target.mergeBackupSnapshot(snapshotFile);
        expect(again.importedConversations, 0);
        expect(again.deduplicatedConversations, 1);
        // A real source edit must still revoke both the summary and its successor.
        await target.updateMessage(
          imported.copyWith(content: 'Corrected original'),
        );
        expect(
          (await target.readContextOperations(
            'chat',
          )).every((op) => op.revoked),
          isTrue,
        );
      } finally {
        await target.close();
      }
    },
  );

  for (final boundary in [0, 2]) {
    for (final collision in [false, true]) {
      test(
        'legacy clear import remains idempotent after conversion: boundary=$boundary collision=$collision',
        () async {
          await repo.appendMessageVersion(
            messageId: 'u1',
            content: 'Selected version',
          );
          await repo.putConversation(
            (await repo.getConversation(
              'chat',
            ))!.copyWith(truncateIndex: boundary),
          );
          final snapshotFile = File('${dir.path}/legacy.sqlite');
          await ChatDatabaseRepository.createConsistentSnapshot(
            sourceFile: File('${dir.path}/chat.sqlite'),
            destinationFile: snapshotFile,
          );
          final target = ChatDatabaseRepository.open(
            file: File('${dir.path}/import.sqlite'),
          );
          await target.ensureReady();
          try {
            if (collision) {
              await target.putConversation(
                Conversation(id: 'chat', title: 'Existing unrelated chat'),
              );
            }
            final report = await target.mergeBackupSnapshot(snapshotFile);
            final id = report.remappedConversationIds['chat'] ?? 'chat';
            expect(report.importedConversations, 1);
            final operations = await target.readContextOperations(id);
            expect(operations.length, boundary == 0 ? 0 : 1);
            if (boundary > 0) {
              expect(operations.single.convertedFromLegacyClear, isTrue);
            }
            expect((await target.getConversation(id))!.truncateIndex, -1);
            expect(
              (await target.getEffectiveContextMessages(
                id,
                limit: 100,
              )).first.content,
              boundary == 0 ? 'Selected version' : 'Original u2',
            );
            for (var i = 0; i < 2; i++) {
              final again = await target.mergeBackupSnapshot(snapshotFile);
              expect(again.importedConversations, 0);
              expect(again.deduplicatedConversations, 1);
            }
          } finally {
            await target.close();
          }
        },
      );
    }
  }

  test(
    'fork cutoff excludes future nodes and selected-only forks retain current nodes',
    () async {
      await compact('S1', ['u1', 'a1']);
      final old = await repo.forkConversationWithVersions(
        sourceId: 'chat',
        targetRevisionId: 'u2',
        title: 'old',
      );
      expect(await repo.readContextOperations(old!.id), isEmpty);
      final current = await repo.forkConversationWithVersions(
        sourceId: 'chat',
        targetRevisionId: 'a3',
        title: 'current',
        preserveVersions: false,
      );
      expect((await repo.readContextOperations(current!.id)).length, 1);
      expect(
        (await repo.getEffectiveContextMessages(
          current.id,
          limit: 100,
        )).first.content,
        'Summary S1',
      );
    },
  );
  test(
    'new chat copies independent summaries inside its retained tail atomically',
    () async {
      final old = await compact('S1', ['u1', 'a1']);
      await compact('S2', ['u3', 'a3']);
      final snapshot = await repo.readContextSnapshot('chat');
      final projected = ContextHistory.resolve(
        snapshot.messages,
        snapshot.operations,
      );
      final created = await repo.createCompressedConversation(
        'chat',
        old.copyWith(summary: 'new summary'),
        expectedFingerprint: snapshot.fingerprint,
        retained: projected.skip(1).toList(),
      );
      expect(
        (await repo.getSelectedContextMessages(
          created.id,
          limit: 100,
        )).map((m) => m.content),
        ['new summary', 'Original u2', 'Original a2', 'Summary S2'],
      );
      expect((await repo.readContextOperations('chat')).length, 2);
    },
  );
  test(
    'a no-op version selection converts rather than drops an old clear boundary',
    () async {
      final old = (await repo.getConversation(
        'chat',
      ))!.copyWith(truncateIndex: 2);
      await repo.putConversation(old);
      await repo.setSelectedVersion(
        conversationId: 'chat',
        groupId: 'u1',
        version: null,
      );
      expect(
        (await repo.readContextOperations('chat')).single.anchorGroupId,
        'a1',
      );
      expect((await effective()).first, 'Original u2');
    },
  );

  test(
    'scheduled revision is stable across the one-time clear conversion',
    () async {
      await repo.putConversation(
        (await repo.getConversation('chat'))!.copyWith(truncateIndex: 2),
      );
      final revision = await repo.scheduledContextRevision('chat');
      expect(await repo.scheduledContextRevision('chat'), revision);
    },
  );
}
