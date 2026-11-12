import 'package:Kelivo/core/database/chat_database_observer.dart';
import 'package:Kelivo/core/models/compress_context_options.dart';
import 'package:Kelivo/core/models/image_context.dart';
import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/models/request_budget.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/context_operation.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/services/api/request_image_context.dart';
import 'package:Kelivo/utils/mcp_structured_image.dart';

void main() {
  late Directory dir;
  late ChatDatabaseRepository repo;
  late ChatDatabaseObserver observer;
  final conversation = Conversation(id: 'chat', title: 'Keep my title');
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('context_nodes_');
    observer = ChatDatabaseObserver();
    repo = ChatDatabaseRepository.open(
      file: File('${dir.path}/chat.sqlite'),
      observer: observer,
    );
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

  for (final count in [0, 1, 3, 4, 13, 25]) {
    test(
      'operation history pages $count records without hydrating details',
      () async {
        final operations = [
          for (var i = 0; i < count; i++)
            ContextOperation(
              id: 'operation-$i',
              kind: ContextOperationKind.compress,
              anchorGroupId: 'u1',
              appliedAfterGroupId: 'a3',
              sourceGroups: const ['u1'],
              dependencies: const [],
              createdAt: DateTime.utc(2026, 1, 1, 0, i),
              revoked: true,
              summary: '${'a' * 239}😀${'body' * 25000}',
              originalSummary: 'original',
              compressionDetails: i == count - 1
                  ? {
                      'nativeCompaction': {'opaque': 'payload' * 25000},
                      'nativeContextImported': true,
                    }
                  : const {},
            ),
        ];
        await repo.restoreContextOperations(
          'chat',
          operations,
          expectedFingerprint: (await repo.readContextSnapshot(
            'chat',
          )).fingerprint,
        );
        observer.reset();
        final ids = <String>[];
        var page = await repo.readContextOperationPage(
          'chat',
          offset: 0,
          limit: 3,
        );
        expect(page.items.length, count < 3 ? count : 3);
        while (true) {
          for (final item in page.items) {
            expect(item.summaryPreview.length, lessThanOrEqualTo(240));
            expect(item.summaryPreview, item.isNative ? '' : 'a' * 239);
          }
          ids.addAll(page.items.map((item) => item.id));
          expect(page.hasMore, ids.length < count);
          if (!page.hasMore) break;
          page = await repo.readContextOperationPage(
            'chat',
            offset: ids.length,
            limit: 10,
          );
          expect(page.items.length, lessThanOrEqualTo(10));
        }
        expect(ids, operations.reversed.map((operation) => operation.id));
        expect(
          observer.snapshot().operations.containsKey(
            ChatDatabaseOperation.queryMessagesByIds,
          ),
          isFalse,
        );
        expect(
          (await repo.readContextOperationPage(
            'chat',
            offset: count,
            limit: 10,
          )).items,
          isEmpty,
        );
        expect(await repo.readContextOperation('chat', 'missing'), isNull);
        if (operations.isNotEmpty) {
          final detail = await repo.readContextOperation(
            'chat',
            operations.last.id,
          );
          expect(detail!.toJson(), operations.last.toJson());
        }
      },
    );
  }

  test(
    'paged status matches full history, with stable timestamp ordering',
    () async {
      ContextOperation operation(
        String id,
        ContextOperationKind kind, {
        List<String> dependencies = const [],
        bool revoked = false,
        DateTime? createdAt,
      }) => ContextOperation(
        id: id,
        kind: kind,
        anchorGroupId: 'u1',
        appliedAfterGroupId: 'a3',
        sourceGroups: const ['u1'],
        dependencies: dependencies,
        createdAt: createdAt ?? DateTime.utc(2026),
        revoked: revoked,
      );
      final operations = [
        operation(
          'summary',
          ContextOperationKind.compress,
          createdAt: DateTime.utc(2027),
        ),
        operation(
          'replacement',
          ContextOperationKind.compress,
          dependencies: ['summary'],
        ),
        operation('clear', ContextOperationKind.clear),
        operation('pin', ContextOperationKind.start),
        operation('revoked-clear', ContextOperationKind.clear, revoked: true),
        operation(
          'latest',
          ContextOperationKind.compress,
          createdAt: DateTime.utc(2028).toLocal(),
        ),
      ];
      await repo.restoreContextOperations(
        'chat',
        operations,
        expectedFingerprint: (await repo.readContextSnapshot(
          'chat',
        )).fingerprint,
      );
      final statuses = ContextHistory.operationStatuses(operations);
      final ids = <String>[];
      for (var i = 0; i < operations.length; i++) {
        final item = (await repo.readContextOperationPage(
          'chat',
          offset: i,
          limit: 1,
        )).items.single;
        ids.add(item.id);
        expect((
          hidden: item.hidden,
          superseded: item.superseded,
        ), statuses[item.id]);
      }
      expect(ids, [
        'latest',
        'summary',
        'revoked-clear',
        'pin',
        'clear',
        'replacement',
      ]);
    },
  );

  test(
    'range metadata preserves Unicode and attachment selection without loading bodies',
    () async {
      final additions = [
        ChatMessage(
          id: 'unicode',
          role: 'user',
          conversationId: 'chat',
          parts: const [TextPart('😀'), TextPart('文')],
        ),
        ChatMessage(
          id: 'blank',
          role: 'user',
          conversationId: 'chat',
          content: '\u2003\n',
        ),
        ChatMessage(
          id: 'image',
          role: 'user',
          conversationId: 'chat',
          parts: const [ImagePart(uri: 'https://example.com/image.png')],
        ),
        ChatMessage(
          id: 'broken',
          role: 'user',
          conversationId: 'chat',
          parts: const [
            MalformedPart(
              rawKind: 'file',
              rawPayload: '{}',
              parseError: 'missing_uri',
            ),
          ],
        ),
      ];
      for (final message in additions) {
        await repo.appendLinearMessageToConversation(
          conversation: conversation,
          message: message,
        );
      }
      observer.reset();
      final metadata = await repo.readCompressionHistory('chat');
      final counts = await repo.getContextMessageCounts('chat', limit: 100);
      expect(
        observer.snapshot().operations.containsKey(
          ChatDatabaseOperation.queryMessagesByIds,
        ),
        isFalse,
      );
      expect(
        observer.snapshot().operations.containsKey(
          ChatDatabaseOperation.queryMessageRange,
        ),
        isFalse,
      );
      expect(counts, (stored: 10, messages: 10, summaries: 0));
      final byId = {for (final m in metadata.messages) m.id: m};
      expect(byId['unicode']!.contentLength, 3);
      expect(byId['blank']!.isUserMessage, isFalse);
      expect(byId['image']!.isUserMessage, isTrue);
      expect(byId['broken']!.isUserMessage, isFalse);
      final history = await repo.readContextHistory('chat');
      for (final mode in CompressContextLimitMode.values) {
        final options = CompressContextOptions(
          mode: mode,
          maxChars: 14,
          keepUserMessages: 2,
        );
        final range = selectCompressionRange(
          metadata.messages,
          metadata.operations,
          options,
        );
        final full = selectCompressionHistory(
          history.messages,
          history.operations,
          options,
        );
        expect(range.covered.map((m) => m.id), full.covered.map((m) => m.id));
        expect(range.retained.map((m) => m.id), full.retained.map((m) => m.id));
      }
    },
  );

  test(
    'fixed start persists, moves atomically and counts the full pinned range',
    () async {
      Future<void> pin(String group) async {
        final snapshot = await repo.readContextSnapshot('chat');
        await repo.appendContextOperation(
          'chat',
          ContextOperation(
            id: 'pin-$group',
            kind: ContextOperationKind.start,
            anchorGroupId: group,
            appliedAfterGroupId: group,
            sourceGroups: [group],
            dependencies: const [],
            createdAt: DateTime.now(),
          ),
          expectedFingerprint: snapshot.fingerprint,
        );
      }

      await pin('u2');
      expect(
        await repo.contextBoundaryIndex(
          'chat',
          await repo.readContextOperations('chat'),
        ),
        2,
      );
      expect(
        (await repo.getEffectiveContextMessages(
          'chat',
          limit: 1,
        )).map((m) => m.id),
        ['u2', 'a2', 'u3', 'a3'],
      );
      expect(
        (await repo.getContextMessageCounts('chat', limit: 1)).messages,
        4,
      );
      await repo.close();
      repo = ChatDatabaseRepository.open(file: File('${dir.path}/chat.sqlite'));
      await repo.ensureReady();
      expect(
        (await repo.getEffectiveContextMessages('chat', limit: 1)).first.id,
        'u2',
      );
      await pin('u3');
      final operations = await repo.readContextOperations('chat');
      expect(
        operations
            .where((op) => op.isFixedStart && !op.revoked)
            .single
            .anchorGroupId,
        'u3',
      );
      expect(
        (await repo.getEffectiveContextMessages(
          'chat',
          limit: 1,
        )).map((m) => m.id),
        ['u3', 'a3'],
      );
      expect(await repo.getMessageCount('chat'), 6);
      final copy = (await repo.duplicateConversation('chat'))!;
      expect(
        (await repo.getEffectiveContextMessages(
          copy.id,
          limit: 1,
        )).map((m) => m.content),
        ['Original u3', 'Original a3'],
      );
      final fork = (await repo.forkConversationWithVersions(
        sourceId: 'chat',
        targetRevisionId: 'a2',
      ))!;
      expect(
        ContextHistory.fixedStart(await repo.readContextOperations(fork.id)),
        isNull,
      );
      final revision = (await repo.appendMessageVersion(
        messageId: 'u3',
        content: 'revised u3',
      ))!;
      expect(
        (await repo.getEffectiveContextMessages('chat', limit: 1)).first.id,
        revision.message.id,
      );
      await repo.deleteMessage('u3');
      expect(
        ContextHistory.fixedStart(await repo.readContextOperations('chat')),
        isNotNull,
      );
      await repo.deleteMessage(revision.message.id);
      expect(
        ContextHistory.fixedStart(await repo.readContextOperations('chat')),
        isNull,
      );
      expect(
        (await repo.getEffectiveContextMessages('chat', limit: 1)).single.id,
        'a3',
      );
    },
  );

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
    'Markdown catalog preserves original order and eviction outside the window',
    () async {
      const large = 'data:image/png;base64,AAAAAAAA';
      const small = 'data:image/png;base64,AAAA';
      final original = ChatMessage(
        id: 'markdown',
        conversationId: 'chat',
        role: 'user',
        parts: [
          const TextPart('```md\n'),
          const TextPart('![literal]($small)\n```\n![actual]($large)'),
        ],
      );
      final tools = ChatMessage(
        id: 'observations',
        conversationId: 'chat',
        role: 'assistant',
        parts: [
          for (var i = 0; i < 3; i++)
            ToolCallPart(
              jsonEncode({
                'id': 'tool_$i',
                'name': 'screenshot',
                'metadata': {
                  kMcpResultMetadataKey: mcpResultMetadata([small]),
                },
              }),
            ),
        ],
      );
      for (final message in [original, tools]) {
        await repo.appendLinearMessageToConversation(
          conversation: conversation,
          message: message,
        );
      }
      final history = await repo.readImageContextHistory('chat');
      expect(
        history.firstWhere((m) => m.id == original.id).content,
        original.content,
      );
      final images = await RequestImageContext.collectHistory(
        history,
        parseMarkdownImages: true,
        allowRemoteImages: false,
      );
      expect(images.map((im) => im.uri), [large, small, small, small]);
      expect(images.map((im) => im.partOrdinal), [1, 0, 1, 2]);
      final request = RequestImageContext(
        settings: const ImageContextSettings(),
        images: images,
        latestUserId: original.id,
        userTurns: RequestImageContext.userTurnsFor(history),
        budget: RequestBudget(totalImageBytes: 16),
      );
      final omitted = await request.historyOmissions();
      expect(omitted, {images[1].key});
      final window = await repo.getEffectiveContextMessages('chat', limit: 1);
      expect(window.map((m) => m.id), [tools.id]);
      final restored = RequestImageContext(
        settings: const ImageContextSettings(),
        images: await RequestImageContext.collectHistory(
          await repo.readImageContextHistory(
            'chat',
            throughMessageId: window.last.id,
          ),
          parseMarkdownImages: true,
          allowRemoteImages: false,
        ),
        latestUserId: original.id,
        userTurns: RequestImageContext.userTurnsFor(history),
        budget: RequestBudget(totalImageBytes: 16),
      );
      expect(await restored.historyOmissions(), omitted);
    },
  );

  test(
    'image preferences survive fork and backup, remap pins, and delete with their conversation',
    () async {
      final settings = ImageContextSettings(
        automatic: false,
        allowRecall: false,
        pinned: {
          const ContextImageIdentity('u1', 'part:1').key,
          const ContextImageIdentity('u3', 'part:0').key,
        },
      );
      await repo.saveImageContextSettings('chat', settings);
      final fork = (await repo.forkConversationWithVersions(
        sourceId: 'chat',
        targetRevisionId: 'a1',
      ))!;
      final forkMessages = (await repo.readContextSnapshot(fork.id)).messages;
      final forkSettings = await repo.readImageContextSettings(fork.id);
      expect(forkSettings.automatic, isFalse);
      expect(forkSettings.allowRecall, isFalse);
      expect(forkSettings.pinned, {
        ContextImageIdentity(forkMessages.first.id, 'part:1').key,
      });
      final snapshot = File('${dir.path}/images.sqlite');
      await ChatDatabaseRepository.createConsistentSnapshot(
        sourceFile: File('${dir.path}/chat.sqlite'),
        destinationFile: snapshot,
      );
      final target = ChatDatabaseRepository.open(
        file: File('${dir.path}/target.sqlite'),
      );
      await target.ensureReady();
      try {
        await target.putConversation(
          Conversation(id: 'chat', title: 'collision'),
        );
        final report = await target.mergeBackupSnapshot(snapshot);
        final importedId = report.remappedConversationIds['chat']!;
        final importedMessages = (await target.readContextSnapshot(
          importedId,
        )).messages;
        final importedSettings = await target.readImageContextSettings(
          importedId,
        );
        expect(importedSettings.automatic, isFalse);
        expect(importedSettings.allowRecall, isFalse);
        expect(importedSettings.pinned, {
          ContextImageIdentity(importedMessages.first.id, 'part:1').key,
          ContextImageIdentity(importedMessages[4].id, 'part:0').key,
        });
        expect(
          (await target.mergeBackupSnapshot(snapshot)).importedConversations,
          0,
        );
        await target.deleteConversation(importedId);
        expect(
          (await target.readImageContextSettings(importedId)).pinned,
          isEmpty,
        );
        expect(
          (await target.readImageContextSettings(importedId)).automatic,
          isTrue,
        );
        expect(
          (await target.readImageContextSettings(importedId)).allowRecall,
          isTrue,
        );
      } finally {
        await target.close();
      }
      await repo.deleteConversation(fork.id);
      expect((await repo.readImageContextSettings(fork.id)).pinned, isEmpty);
    },
  );

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
      final state = (await repo.readContextMutationState('chat')).revision;
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
      final state = (await repo.readContextMutationState('chat')).revision;
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
    'historical regeneration reuses earlier summaries and keeps following assistant',
    () async {
      final summary = await compact('S1', ['u1', 'a1']);
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
        summary.summaryMessageId,
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
    'context overview follows compression, history limits and undo',
    () async {
      expect(await repo.getContextMessageCounts('chat', limit: 100), (
        stored: 6,
        messages: 6,
        summaries: 0,
      ));
      await compact('S1', ['u1', 'a1']);
      expect(await repo.getContextMessageCounts('chat', limit: 100), (
        stored: 6,
        messages: 4,
        summaries: 1,
      ));
      expect(await repo.getContextMessageCounts('chat', limit: 2), (
        stored: 6,
        messages: 2,
        summaries: 1,
      ));
      await compact('S2', ['u1', 'a1', 'u2', 'a2'], depends: ['S1']);
      expect(await repo.getContextMessageCounts('chat', limit: 100), (
        stored: 6,
        messages: 2,
        summaries: 1,
      ));
      await repo.changeContextOperation(
        'chat',
        'S1',
        includeDependents: true,
        expectedState: ContextHistory.operationsFingerprint(
          await repo.readContextOperations('chat'),
        ),
      );
      expect(await repo.getContextMessageCounts('chat', limit: 100), (
        stored: 6,
        messages: 6,
        summaries: 0,
      ));
    },
  );

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

  test(
    'undo fixed start also revokes compression that depends on its projection',
    () async {
      await compact('old', ['u1', 'a1', 'u2', 'a2']);
      final snapshot = await repo.readContextSnapshot('chat');
      await repo.appendContextOperation(
        'chat',
        ContextOperation(
          id: 'pin',
          kind: ContextOperationKind.start,
          anchorGroupId: 'u2',
          appliedAfterGroupId: 'u2',
          sourceGroups: ['u2'],
          dependencies: [],
          createdAt: DateTime(2026),
        ),
        expectedFingerprint: snapshot.fingerprint,
      );
      await compact('new', ['u2', 'a2']);
      final operations = await repo.readContextOperations('chat');
      expect(operations.last.dependencies, ['pin']);
      expect(await effective(), ['Summary new', 'Original u3', 'Original a3']);
      await repo.changeContextOperation(
        'chat',
        'pin',
        includeDependents: true,
        expectedState: ContextHistory.operationsFingerprint(operations),
      );
      expect(await effective(), ['Summary old', 'Original u3', 'Original a3']);
      expect((await repo.readContextOperations('chat')).last.revoked, isTrue);
      expect(await repo.getMessageCount('chat'), 6);
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
      );
      expect(await repo.readContextOperations(old!.id), isEmpty);
      final current = await repo.forkConversationWithVersions(
        sourceId: 'chat',
        targetRevisionId: 'a3',
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
    'selected-only fork keeps a compression boundary after an earlier revision',
    () async {
      await repo.appendMessageVersion(messageId: 'a1', content: 'Revised a1');
      await compact('S1', ['u1', 'a1']);
      final expected = await effective();
      final fork = (await repo.forkConversationWithVersions(
        sourceId: 'chat',
        targetRevisionId: 'a3',
        preserveVersions: false,
      ))!;
      expect(
        (await repo.getEffectiveContextMessages(
          fork.id,
          limit: 100,
        )).map((m) => m.content),
        expected,
      );
      expect(
        (await repo.readContextSnapshot(
          fork.id,
        )).messages.map((m) => m.content),
        [
          'Original u1',
          'Revised a1',
          'Original u2',
          'Original a2',
          'Original u3',
          'Original a3',
        ],
      );
      expect(
        (await repo.readContextOperations(fork.id)).single.revoked,
        isFalse,
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
      expect(
        (await repo.getEffectiveContextMessages(
          created.id,
          limit: 1,
        )).map((m) => m.content),
        ['new summary', 'Original a2', 'Summary S2'],
      );
      final copiedNodes = await repo.readContextOperations(created.id);
      expect(copiedNodes, hasLength(2));
      expect(
        copiedNodes.every((node) => node.sourceGroups.length == 1),
        isTrue,
      );
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
