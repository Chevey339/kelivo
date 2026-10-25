import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/database/generation_run.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/context_operation.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/intelligent_ui/host/ui_runtime_registry.dart';
import 'package:Kelivo/features/intelligent_ui/host/ui_persistence_host.dart';
import 'package:Kelivo/features/intelligent_ui/host/ui_source_selection.dart';
import 'package:Kelivo/features/intelligent_ui/protocol/ui_source_hash.dart';
import 'package:Kelivo/features/intelligent_ui/protocol/ui_stream_parser.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_state.dart';
import 'package:Kelivo/features/intelligent_ui/storage/ui_state_transfer.dart';
import 'package:Kelivo/utils/sandbox_path_resolver.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _body = r'''ui 1 catalog "kelivo.native/1"
$value: number = 1
root = Column(children=[field,table,chart])
field = Slider(label="Value", bind=$value, min=0, max=100)
table = DataTable(data=[{"id":"one","v":1}], rowKey="id", columns=[{"key":"id","label":"ID"},{"key":"v","label":"Value"}])
chart = Chart(kind="line", data=[{"x":0,"y":1},{"x":1,"y":2}], x="x", y=["y"])
''';
const _fence = '```kelivo-ui\n$_body```\n';
final _anchor = DateTime.utc(2026, 8, 1);

class _Paths extends PathProviderPlatform {
  _Paths(this.root);
  final String root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
  @override
  Future<String?> getApplicationSupportPath() async => root;
  @override
  Future<String?> getApplicationCachePath() async => '$root/cache';
  @override
  Future<String?> getTemporaryPath() async => '$root/tmp';
}

class _StateInsertGate extends QueryInterceptor {
  Future<void> Function()? next;
  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    if (statement.contains('gen_ui_surface_state_rows') && next != null) {
      final callback = next!;
      next = null;
      await callback();
    }
    return executor.runInsert(statement, args);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory directory;
  late AppDatabase db, backupDb;
  late ChatDatabaseRepository repo, backup;
  late File backupFile;
  late _StateInsertGate stateGate;
  var backupClosed = false;
  final services = <ChatService>[];
  late PathProviderPlatform oldPaths;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('genui-copy-');
    oldPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(directory.path);
    SandboxPathResolver.debugSetDirs(
      docsDir: directory.path,
      supportDir: directory.path,
    );
    SharedPreferences.setMockInitialValues({});
    stateGate = _StateInsertGate();
    db = AppDatabase(
      NativeDatabase(
        File('${directory.path}/live.sqlite'),
      ).interceptWith(stateGate),
    );
    backupFile = File('${directory.path}/backup.sqlite');
    backupDb = AppDatabase(NativeDatabase(backupFile));
    repo = ChatDatabaseRepository(db);
    backup = ChatDatabaseRepository(backupDb);
    backupClosed = false;
    await repo.ensureReady();
    await backup.ensureReady();
  });

  tearDown(() async {
    await db.customStatement('DROP TRIGGER IF EXISTS fail_genui;');
    for (final service in services) {
      await service.close();
      service.dispose();
    }
    services.clear();
    await repo.close();
    if (!backupClosed) await backup.close();
    PathProviderPlatform.instance = oldPaths;
    SandboxPathResolver.debugSetDirs(docsDir: null, supportDir: null);
    await directory.delete(recursive: true);
  });

  ChatMessage message(
    String id, {
    String? group,
    int version = 0,
    String content = _fence,
  }) => ChatMessage(
    id: id,
    conversationId: 'source',
    role: 'assistant',
    content: content,
    groupId: group,
    version: version,
    timestamp: _anchor,
  );

  Future<void> seed(ChatDatabaseRepository store, List<ChatMessage> messages) =>
      store.putMigrationBatch(
        conversations: [
          Conversation(
            id: 'source',
            title: 'Source',
            createdAt: _anchor,
            updatedAt: _anchor,
            messageIds: messages.map((m) => m.id).toList(),
          ),
        ],
        messages: [
          for (final (order, message) in messages.indexed)
            (message: message, messageOrder: order),
        ],
        toolEventsByMessageId: const {},
        geminiSignaturesByMessageId: const {},
      );

  Future<void> run(
    AppDatabase database,
    String id, {
    GenerationRunState state = GenerationRunState.completed,
    String suffix = '',
    DateTime? createdAt,
  }) async {
    final created = createdAt ?? _anchor;
    await database
        .into(database.generationRunRows)
        .insert(
          GenerationRunRowsCompanion.insert(
            id: 'run-$id$suffix',
            conversationId: 'source',
            targetRevisionId: id,
            state: state.databaseValue,
            createdAt: created,
            updatedAt: created,
            terminalAt: Value(state.isTerminal ? created : null),
          ),
        );
  }

  Future<UiSurfaceSnapshot> save(
    ChatDatabaseRepository store,
    String id, {
    num value = 7,
    Map<String, Map<String, Object?>> view = const {},
    bool flush = true,
    String? surfaceKey,
  }) async {
    final m = (await store.getMessage(id))!;
    final fence = uiEligibleFences(
      m,
    ).firstWhere((f) => surfaceKey == null || f.surfaceKey == surfaceKey);
    final parsed = UiStreamParser().update(fence.body, closed: true);
    expect(parsed.invalid, isFalse);
    final snapshot = UiSurfaceSnapshot(
      owner: UiSurfaceOwner(revisionId: id, surfaceKey: fence.surfaceKey),
      sourceHash: uiSourceHash(parsed.source),
      state: UiSurfaceState.normalize(
        parsed.program,
        inputs: {'value': value},
        view: view,
      ),
    );
    final lease = store.genUiStates.attach(
      m.conversationId,
      snapshot.owner,
      snapshot.sourceHash,
    )!;
    expect(store.genUiStates.accept(lease, snapshot), isTrue);
    if (flush) await store.genUiStates.flush();
    return snapshot;
  }

  Future<List<GenUiSurfaceStateRow>> rows(String conversationId) async {
    final ids = (await repo.getConversation(conversationId))!.messageIds;
    return (db.select(
      db.genUiSurfaceStateRows,
    )..where((s) => s.revisionId.isIn(ids))).get();
  }

  Future<BackupMergeReport> merge() async {
    if (!backupClosed) {
      await backup.close();
      backupClosed = true;
    }
    return repo.mergeBackupSnapshot(backupFile);
  }

  Future<ChatService> service() async {
    final result = ChatService(existingRepository: repo);
    services.add(result);
    await result.init();
    return result;
  }

  test(
    'compression into a new chat preserves pending UI state and completion',
    () async {
      await seed(repo, [message('history', content: 'Earlier'), message('r')]);
      await run(db, 'r');
      final snapshot = await repo.readContextSnapshot('source');
      await save(repo, 'r', value: 37, flush: false);
      final copied = await repo.createCompressedConversation(
        'source',
        ContextOperation(
          id: 'compression',
          kind: ContextOperationKind.compress,
          anchorGroupId: 'history',
          appliedAfterGroupId: 'r',
          sourceGroups: const ['history'],
          dependencies: const [],
          createdAt: _anchor,
          summary: 'Compressed history',
        ),
        expectedFingerprint: snapshot.fingerprint,
        retained: [snapshot.messages.last],
      );
      final messages = await repo.getSelectedContextMessages(
        copied.id,
        limit: 10,
      );
      expect(messages.map((m) => m.content), ['Compressed history', _fence]);
      final state = (await rows(copied.id)).single;
      expect(state.revisionId, messages.last.id);
      expect(state.revisionId, isNot('r'));
      expect(jsonDecode(state.stateJson)['inputs'], {'value': 37});
      expect(messages.last.generationState, GenerationRunState.completed);
      expect(jsonDecode((await rows('source')).single.stateJson)['inputs'], {
        'value': 37,
      });
      expect(await repo.readContextOperations('source'), isEmpty);
    },
  );
  test('restore availability bookkeeping retains pending UI state', () async {
    await seed(repo, [
      message('r').copyWith(
        parts: [
          const TextPart(_fence),
          FilePart(uri: '${directory.path}/missing.txt', name: 'missing.txt'),
        ],
      ),
    ]);
    await run(db, 'r');
    await save(repo, 'r', value: 43, flush: false);
    expect(
      await repo.recomputeAttachmentAvailabilityForConversations(
        conversationIds: ['source'],
        filesRestored: false,
      ),
      1,
    );
    await repo.genUiStates.flush();
    final restored = (await repo.getMessage('r'))!;
    expect(restored.content, _fence);
    expect(restored.parts.whereType<FilePart>().single.unavailable, isTrue);
    expect(restored.generationState, GenerationRunState.completed);
    expect(jsonDecode((await rows('source')).single.stateJson)['inputs'], {
      'value': 43,
    });
  });
  test(
    'duplicate flushes newest inputs/view and copies cache plus completion',
    () async {
      await seed(repo, [message('r')]);
      await run(db, 'r');
      await save(repo, 'r');
      await repo.rebuildGenUiSearchIndex();
      final sourceCache = (await rows('source')).single.searchText;
      await save(
        repo,
        'r',
        value: 12,
        view: {
          'chart': {'dataView': true},
        },
        flush: false,
      );
      final copied = (await repo.duplicateConversation('source'))!;
      final copiedState = (await rows(copied.id)).single;
      expect(jsonDecode(copiedState.stateJson), {
        'inputs': {'value': 12},
        'view': {
          'chart': {'dataView': true},
        },
      });
      expect(copiedState.searchText, sourceCache);
      expect(sourceCache, contains('Value: 1'));
      expect(sourceCache, isNot(contains('Value: 12')));
      expect(copiedState.sourceHash, (await rows('source')).single.sourceHash);
      expect(copiedState.revisionId, isNot('r'));
      expect(
        (await repo.getMessage(copiedState.revisionId))!.generationState,
        GenerationRunState.completed,
      );
      expect(
        (await db
                .customSelect(
                  "SELECT rowid FROM gen_ui_surface_search WHERE gen_ui_surface_search MATCH 'Value';",
                )
                .get())
            .length,
        2,
      );
    },
  );

  test(
    'version fork carries late revisions of earlier groups, not later groups',
    () async {
      await seed(repo, [
        message('old', group: 'g'),
        message('cut'),
        message('later'),
        message('late-version', group: 'g', version: 1),
      ]);
      for (final id in ['old', 'cut', 'later', 'late-version']) {
        await run(db, id);
        await save(repo, id, value: id.length);
      }
      final copied = (await repo.forkConversationWithVersions(
        sourceId: 'source',
        targetRevisionId: 'cut',
        title: 'Fork',
      ))!;
      expect(copied.messageIds, hasLength(3));
      final copiedRows = await rows(copied.id);
      expect(copiedRows, hasLength(3));
      expect(
        copiedRows.map((r) => jsonDecode(r.stateJson)['inputs']['value']),
        unorderedEquals([3, 3, 12]),
      );
    },
  );

  for (final operation in [
    'duplicate',
    'versions',
    'service',
    'messages',
    'merge',
  ]) {
    test(
      '$operation stops before creating targets when accepted state cannot save',
      () async {
        await seed(repo, [message('r')]);
        await run(db, 'r');
        final chat = await service();
        await save(repo, 'r', flush: false);
        await db.customStatement(
          "CREATE TRIGGER fail_genui BEFORE INSERT ON gen_ui_surface_state_rows BEGIN SELECT RAISE(ABORT, 'disk'); END;",
        );
        Future<Object?> action() => switch (operation) {
          'duplicate' => repo.duplicateConversation('source'),
          'versions' => repo.forkConversationWithVersions(
            sourceId: 'source',
            targetRevisionId: 'r',
            title: 'Fork',
          ),
          'service' => chat.forkConversationAtRevision(
            sourceConversationId: 'source',
            sourceRevisionId: 'r',
            title: 'Fork',
          ),
          'messages' => chat.forkConversationFromMessages(
            title: 'Fork',
            assistantId: null,
            sourceMessages: [message('r')],
          ),
          _ => merge(),
        };
        await expectLater(action(), throwsA(anything));
        expect(await repo.getAllConversationSummaries(), hasLength(1));
        await db.customStatement('DROP TRIGGER fail_genui;');
        await repo.genUiStates.flush();
        expect(await rows('source'), hasLength(1));
      },
    );
  }

  for (final state in GenerationRunState.values) {
    test(
      'latest $state provenance is copied without resuming a task',
      () async {
        await seed(repo, [message('r')]);
        await run(db, 'r');
        final future = DateTime.now().toUtc().add(const Duration(days: 2));
        await run(db, 'r', state: state, suffix: '-newest', createdAt: future);
        final copied = (await repo.duplicateConversation('source'))!;
        final m = (await repo.getMessage(copied.messageIds.single))!;
        expect(m.isStreaming, isFalse);
        expect(
          m.generationState,
          state.isTerminal ? state : GenerationRunState.interrupted,
        );
        final runs = await (db.select(
          db.generationRunRows,
        )..where((r) => r.targetRevisionId.equals(m.id))).get();
        expect(runs, hasLength(1));
        expect(runs.single.terminalAt!.isBefore(future), isFalse);
        expect(runs.single.id, isNot('run-r-newest'));
      },
    );
  }

  test('missing completion proof is never invented', () async {
    await seed(repo, [message('r')]);
    final copied = (await repo.duplicateConversation('source'))!;
    expect(
      (await repo.getMessage(copied.messageIds.single))!.generationState,
      isNull,
    );
  });

  for (final fromList in [false, true]) {
    test(
      'service fork fromList=$fromList retains selected input/view in actual cache',
      () async {
        await seed(repo, [
          message('r', group: 'g'),
          message('selected', group: 'g', version: 1),
        ]);
        for (final id in ['r', 'selected']) {
          await run(db, id);
          await save(
            repo,
            id,
            value: id == 'r' ? 4 : 9,
            view: {
              'table': {'sortKey': 'v', 'descending': true},
            },
          );
        }
        final conversation = (await repo.getConversation('source'))!;
        conversation.versionSelections['g'] = 1;
        await repo.putConversation(conversation);
        final chat = await service();
        final fork = fromList
            ? await chat.forkConversationFromMessages(
                title: 'Copy',
                assistantId: null,
                sourceMessages: [
                  ChatMessage(
                    id: 'synthetic',
                    conversationId: '',
                    role: 'user',
                    content: 'Summary',
                  ),
                  (await repo.getMessage('selected'))!,
                ],
              )
            : await chat.forkConversationAtRevision(
                sourceConversationId: 'source',
                sourceRevisionId: 'selected',
                title: 'Fork',
              );
        final copied = (await rows(fork.id)).single;
        expect(jsonDecode(copied.stateJson)['inputs'], {'value': 9});
        expect(jsonDecode(copied.stateJson)['view']['table'], {
          'sortKey': 'v',
          'descending': true,
        });
        final cached = chat
            .getMessages(fork.id)
            .where((m) => m.role == 'assistant')
            .single;
        expect(cached.generationState, GenerationRunState.completed);
        expect(uiEligibleFences(cached).single.surfaceKey, copied.surfaceKey);
        expect(chat.currentConversationId, fork.id);
      },
    );
  }

  test(
    'temporary compression freezes repeated fence states before owner discard',
    () async {
      final chat = await service();
      final temporary = await chat.createDraftConversation(temporary: true);
      final original = await chat.addMessage(
        conversationId: temporary.id,
        role: 'assistant',
        parts: const [
          TextPart(_fence),
          ToolCallPart('{"id":"tool","name":"x"}'),
          TextPart(_fence),
        ],
        reasoningText: 'Provider reasoning',
      );
      await chat.finalizeGenerationRunSilent(
        message: original,
        toolEvents: const [],
        generationRunId: null,
        expectedState: null,
        expectedStateRevision: null,
        terminalState: GenerationRunState.completed,
      );
      final unseen = await chat.addMessage(
        conversationId: temporary.id,
        role: 'assistant',
        content: _fence,
      );
      await chat.finalizeGenerationRunSilent(
        message: unseen,
        toolEvents: const [],
        generationRunId: null,
        expectedState: null,
        expectedStateRevision: null,
        terminalState: GenerationRunState.completed,
      );
      final registry = UiRuntimeRegistry();
      addTearDown(registry.dispose);
      for (final fence in uiEligibleFences(original)) {
        registry.obtain(
          temporary.id,
          UiSurfaceOwner(revisionId: original.id, surfaceKey: fence.surfaceKey),
        );
      }
      registry.reconcile(original);
      for (final (index, fence) in uiEligibleFences(original).indexed) {
        final controller = registry
            .obtain(
              temporary.id,
              UiSurfaceOwner(
                revisionId: original.id,
                surfaceKey: fence.surfaceKey,
              ),
            )
            .controller;
        controller.setInputs({'value': index + 6}, token: controller.token);
      }
      final remove = chat.registerGenUiSnapshotReader(
        registry.captureCopySnapshots,
      );
      addTearDown(remove);
      final copied = await chat.forkConversationFromMessages(
        title: 'Compressed',
        assistantId: null,
        sourceMessages: [
          ChatMessage(conversationId: '', role: 'user', content: 'Summary'),
          original,
          unseen,
        ],
      );
      expect(await repo.getMessage(original.id), isNull);
      expect(await repo.getConversation(temporary.id), isNull);
      expect(chat.getMessages(temporary.id), isEmpty);
      final copiedRows = await rows(copied.id);
      expect(copiedRows, hasLength(3));
      final copiedMessages = chat
          .getMessages(copied.id)
          .where((m) => m.role == 'assistant')
          .toList();
      expect(
        copiedMessages.every(
          (m) => m.generationState == GenerationRunState.completed,
        ),
        isTrue,
      );
      final first = copiedMessages.first;
      final fences = uiEligibleFences(first);
      expect(fences, hasLength(2));
      for (final (index, fence) in fences.indexed) {
        final row = copiedRows.singleWhere(
          (r) => r.revisionId == first.id && r.surfaceKey == fence.surfaceKey,
        );
        expect(jsonDecode(row.stateJson)['inputs']['value'], index + 6);
      }
      final defaultCache = copiedRows.singleWhere(
        (row) => row.revisionId == copiedMessages.last.id,
      );
      expect(defaultCache.stateJson, '{"inputs":{},"view":{}}');
      expect(defaultCache.searchText, contains('Value: 1'));
      expect(first.parts.whereType<ReasoningPart>(), isNotEmpty);
    },
  );

  testWidgets('host registers and removes temporary copy snapshots', (
    tester,
  ) async {
    final chat = (await tester.runAsync(service))!;
    final registry = UiRuntimeRegistry();
    addTearDown(registry.dispose);
    Future<ChatMessage> prepare() async {
      final temporary = await chat.createDraftConversation(temporary: true);
      final original = await chat.addMessage(
        conversationId: temporary.id,
        role: 'assistant',
        content: _fence,
      );
      await chat.finalizeGenerationRunSilent(
        message: original,
        toolEvents: const [],
        generationRunId: null,
        expectedState: null,
        expectedStateRevision: null,
        terminalState: GenerationRunState.completed,
      );
      return original;
    }

    void edit(ChatMessage message) {
      final owner = UiSurfaceOwner(revisionId: message.id, surfaceKey: '0:0');
      final controller = registry
          .obtain(message.conversationId, owner)
          .controller;
      registry.reconcile(message);
      controller.setInputs({'value': 9}, token: controller.token);
    }

    final first = (await tester.runAsync(prepare))!;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: chat,
        child: UiPersistenceHost(
          registry: registry,
          conversationId: first.conversationId,
          child: const SizedBox(),
        ),
      ),
    );
    edit(first);
    final copied = (await tester.runAsync(
      () => chat.forkConversationFromMessages(
        title: 'With host',
        assistantId: null,
        sourceMessages: [first],
      ),
    ))!;
    expect((await tester.runAsync(() => rows(copied.id)))!, hasLength(1));
    await tester.pumpWidget(const SizedBox());
    final second = (await tester.runAsync(prepare))!;
    edit(second);
    final detachedCopy = (await tester.runAsync(
      () => chat.forkConversationFromMessages(
        title: 'No host',
        assistantId: null,
        sourceMessages: [second],
      ),
    ))!;
    final detachedRows = (await tester.runAsync(() => rows(detachedCopy.id)))!;
    expect(detachedRows.single.stateJson, '{"inputs":{},"view":{}}');
    expect(detachedRows.single.searchText, contains('Value: 1'));
  });

  for (final path in ['revision', 'messages', 'temporary']) {
    test(
      '$path target save failure removes partial fork and keeps source',
      () async {
        final chat = await service();
        late ChatMessage original;
        UiRuntimeRegistry? registry;
        if (path == 'temporary') {
          final temporary = await chat.createDraftConversation(temporary: true);
          original = await chat.addMessage(
            conversationId: temporary.id,
            role: 'assistant',
            content: _fence,
          );
          await chat.finalizeGenerationRunSilent(
            message: original,
            toolEvents: const [],
            generationRunId: null,
            expectedState: null,
            expectedStateRevision: null,
            terminalState: GenerationRunState.completed,
          );
          registry = UiRuntimeRegistry();
          final controller = registry
              .obtain(
                temporary.id,
                UiSurfaceOwner(revisionId: original.id, surfaceKey: '0:0'),
              )
              .controller;
          registry.reconcile(original);
          controller.setInputs({'value': 9}, token: controller.token);
          addTearDown(registry.dispose);
          addTearDown(
            chat.registerGenUiSnapshotReader(registry.captureCopySnapshots),
          );
        } else {
          final conversation = await chat.createConversation(title: 'Source');
          original = await chat.addMessage(
            conversationId: conversation.id,
            role: 'assistant',
            content: _fence,
          );
          await db
              .into(db.generationRunRows)
              .insert(
                GenerationRunRowsCompanion.insert(
                  id: 'source-run',
                  conversationId: conversation.id,
                  targetRevisionId: original.id,
                  state: 'completed',
                  createdAt: _anchor,
                  updatedAt: _anchor,
                  terminalAt: Value(_anchor),
                ),
              );
          await save(repo, original.id);
        }
        final sourceId = original.conversationId;
        // Saving the source succeeded; only writes under fresh target revisions fail.
        await db.customStatement(
          'CREATE TRIGGER fail_genui BEFORE INSERT ON gen_ui_surface_state_rows '
          "WHEN NEW.revision_id != '${original.id}' BEGIN SELECT RAISE(ABORT, 'target disk'); END;",
        );
        await expectLater(
          path == 'revision'
              ? chat.forkConversationAtRevision(
                  sourceConversationId: sourceId,
                  sourceRevisionId: original.id,
                  title: 'Fork',
                )
              : chat.forkConversationFromMessages(
                  title: 'Fork',
                  assistantId: null,
                  sourceMessages: [original],
                ),
          throwsA(anything),
        );
        expect(chat.currentConversationId, sourceId);
        expect(chat.getMessages(sourceId).single.id, original.id);
        expect(
          await repo.getAllConversationSummaries(),
          hasLength(path == 'temporary' ? 0 : 1),
        );
        expect(
          (await db.select(db.messageRows).get()).length,
          path == 'temporary' ? 0 : 1,
        );
        if (registry != null) {
          expect(
            registry.captureCopySnapshots([original]).single.state.inputs,
            {'value': 9},
          );
        }
      },
    );
  }

  for (final path in ['revision', 'versions', 'messages', 'temporary']) {
    test(
      '$path fork cannot discard a newer temporary owner while copying',
      () async {
        final chat = await service();
        final source = path == 'temporary'
            ? await chat.createDraftConversation(temporary: true)
            : await chat.createConversation(title: 'Source');
        final original = await chat.addMessage(
          conversationId: source.id,
          role: 'assistant',
          content: _fence,
        );
        if (path == 'temporary') {
          await chat.finalizeGenerationRunSilent(
            message: original,
            toolEvents: const [],
            generationRunId: null,
            expectedState: null,
            expectedStateRevision: null,
            terminalState: GenerationRunState.completed,
          );
          final registry = UiRuntimeRegistry();
          final controller = registry
              .obtain(
                source.id,
                UiSurfaceOwner(revisionId: original.id, surfaceKey: '0:0'),
              )
              .controller;
          registry.reconcile(original);
          controller.setInputs({'value': 9}, token: controller.token);
          addTearDown(registry.dispose);
          addTearDown(
            chat.registerGenUiSnapshotReader(registry.captureCopySnapshots),
          );
        } else {
          await db
              .into(db.generationRunRows)
              .insert(
                GenerationRunRowsCompanion.insert(
                  id: 'source-run',
                  conversationId: source.id,
                  targetRevisionId: original.id,
                  state: 'completed',
                  createdAt: _anchor,
                  updatedAt: _anchor,
                  terminalAt: Value(_anchor),
                ),
              );
          await save(repo, original.id, value: 9);
        }
        final entered = Completer<void>();
        final release = Completer<void>();
        addTearDown(() {
          if (!release.isCompleted) release.complete();
        });
        stateGate.next = () async {
          entered.complete();
          await release.future;
        };
        final copying = path == 'revision' || path == 'versions'
            ? chat.forkConversationAtRevision(
                sourceConversationId: source.id,
                sourceRevisionId: original.id,
                title: 'Fork',
                preserveVersions: path == 'versions',
              )
            : chat.forkConversationFromMessages(
                title: 'Fork',
                assistantId: null,
                sourceMessages: [original],
              );
        await entered.future;
        final newer = await chat.createDraftConversation(temporary: true);
        final newerMessage = await chat.addMessage(
          conversationId: newer.id,
          role: 'user',
          content: 'Keep this new draft',
        );
        release.complete();
        final copied = await copying;
        expect(chat.currentConversationId, newer.id);
        expect(chat.getMessages(newer.id).single.id, newerMessage.id);
        expect(
          chat.getMessages(newer.id).single.content,
          'Keep this new draft',
        );
        expect(
          jsonDecode(
            (await rows(copied.id)).single.stateJson,
          )['inputs']['value'],
          9,
        );
      },
    );
  }

  test(
    'merge associates overrides with their message, not a conversation bag',
    () async {
      for (final (store, database) in [(repo, db), (backup, backupDb)]) {
        await seed(store, [message('one'), message('two')]);
        await run(database, 'one');
        await run(database, 'two');
      }
      await save(repo, 'one', value: 3);
      await save(repo, 'two', value: 9);
      await save(backup, 'one', value: 9);
      await save(backup, 'two', value: 3);
      expect((await merge()).importedConversations, 1);
      expect((await merge()).deduplicatedConversations, 1);
    },
  );

  test('active-run merge becomes interrupted and remains idempotent', () async {
    await seed(backup, [message('r')]);
    await run(
      backupDb,
      'r',
      state: GenerationRunState.streaming,
      createdAt: DateTime.now().add(const Duration(days: 1)),
    );
    final copied = await merge();
    final target = (await repo.getConversation(
      copied.importedConversationIds.single,
    ))!;
    expect(
      (await repo.getMessage(target.messageIds.single))!.generationState,
      GenerationRunState.interrupted,
    );
    expect((await merge()).deduplicatedConversations, 1);
  });

  for (final kind in ['input', 'view']) {
    test(
      'merge keeps differing $kind and is idempotent after remapping',
      () async {
        for (final (store, database) in [(repo, db), (backup, backupDb)]) {
          await seed(store, [message('r')]);
          await run(database, 'r');
        }
        await save(repo, 'r', value: 3);
        await save(
          backup,
          'r',
          value: kind == 'input' ? 9 : 3,
          view: kind == 'view'
              ? {
                  'chart': {
                    'hiddenSeries': [0],
                  },
                }
              : {},
        );
        final first = await merge();
        expect(first.importedConversations, 1);
        final target = first.importedConversationIds.single;
        expect(target, isNot('source'));
        expect(await rows(target), hasLength(1));
        expect(
          (await repo.getMessage(
            (await rows(target)).single.revisionId,
          ))!.generationState,
          GenerationRunState.completed,
        );
        final again = await merge();
        expect(again.importedConversations, 0);
        expect(again.deduplicatedConversations, 1);
      },
    );
  }

  for (final empty in ['absent', 'explicit-defaults', 'cache-only', 'reset']) {
    test(
      'merge $empty normalizes to defaults despite timestamps/search cache',
      () async {
        for (final (store, database) in [(repo, db), (backup, backupDb)]) {
          await seed(store, [message('r')]);
          await run(database, 'r');
        }
        if (empty != 'absent') {
          await save(backup, 'r');
          final state = empty == 'explicit-defaults'
              ? '{"view":{"chart":{"dataView":false,"hiddenSeries":[]},"table":{"filter":"","page":0,"descending":false}},"inputs":{"value":1}}'
              : '{"inputs":{},"view":{}}';
          await backupDb.customStatement(
            'UPDATE gen_ui_surface_state_rows SET state_json = ?, search_text = ?, updated_at = updated_at + 999;',
            [state, 'derived only'],
          );
        }
        final report = await merge();
        expect(report.importedConversations, 0);
        expect(report.deduplicatedConversations, 1);
      },
    );
  }

  test(
    'equal overrides with different key order/cache/save time deduplicate',
    () async {
      for (final (store, database) in [(repo, db), (backup, backupDb)]) {
        await seed(store, [message('r')]);
        await run(database, 'r');
        await save(
          store,
          'r',
          view: {
            'table': {'sortKey': 'v', 'descending': true},
          },
        );
      }
      await backupDb.customStatement(
        'UPDATE gen_ui_surface_state_rows SET state_json = ?, search_text = ?, updated_at = updated_at + 1000;',
        [
          '{"view":{"table":{"descending":true,"sortKey":"v"}},"inputs":{"value":7}}',
          'other cache',
        ],
      );
      final report = await merge();
      expect(report.importedConversations, 0);
      expect(report.deduplicatedConversations, 1);
    },
  );

  test(
    'completed default UI cannot disappear into unconfirmed identical history',
    () async {
      await seed(repo, [message('r')]);
      await seed(backup, [message('r')]);
      await run(backupDb, 'r');
      final report = await merge();
      expect(report.importedConversations, 1);
      final id = report.importedConversationIds.single;
      expect(
        (await repo.getMessage(
          (await repo.getConversation(id))!.messageIds.single,
        ))!.generationState,
        GenerationRunState.completed,
      );
      expect((await merge()).deduplicatedConversations, 1);
    },
  );

  test(
    'reimport after editing a conflict copy uses fresh message IDs',
    () async {
      for (final (store, database) in [(repo, db), (backup, backupDb)]) {
        await seed(store, [message('r')]);
        await run(database, 'r');
      }
      await save(repo, 'r', value: 3);
      await save(backup, 'r', value: 9);
      final first = await merge();
      final firstId = first.importedConversationIds.single;
      final firstMessage = (await repo.getConversation(
        firstId,
      ))!.messageIds.single;
      await save(repo, firstMessage, value: 10);
      final second = await merge();
      final secondId = second.importedConversationIds.single;
      expect(secondId, isNot(firstId));
      final secondMessage = (await repo.getConversation(
        secondId,
      ))!.messageIds.single;
      expect(secondMessage, isNot(firstMessage));
      expect(
        jsonDecode((await rows(firstId)).single.stateJson)['inputs']['value'],
        10,
      );
      expect(
        jsonDecode((await rows(secondId)).single.stateJson)['inputs']['value'],
        9,
      );
      expect((await merge()).deduplicatedConversations, 1);
    },
  );

  test(
    'matching malformed private state aborts copy and merge atomically',
    () async {
      await seed(repo, [message('r')]);
      await run(db, 'r');
      await save(repo, 'r');
      await db.customStatement(
        'UPDATE gen_ui_surface_state_rows SET state_json = ?;',
        ['{"inputs":{"value":"bad"},"view":{}}'],
      );
      await expectLater(
        repo.duplicateConversation('source'),
        throwsFormatException,
      );
      expect(await repo.getAllConversationSummaries(), hasLength(1));
      await seed(backup, [message('r')]);
      await run(backupDb, 'r');
      await save(backup, 'r');
      await backupDb.customStatement(
        'UPDATE gen_ui_surface_state_rows SET state_json = ?;',
        ['{"inputs":{"unknown":9},"view":{}}'],
      );
      await expectLater(merge(), throwsFormatException);
      expect(await repo.getAllConversationSummaries(), hasLength(1));
    },
  );

  test('stale source hash is not copied as private state', () async {
    await seed(repo, [message('r')]);
    await run(db, 'r');
    await save(repo, 'r');
    await db.customStatement(
      "UPDATE gen_ui_surface_state_rows SET source_hash = 'stale';",
    );
    final copied = (await repo.duplicateConversation('source'))!;
    final copiedState = (await rows(copied.id)).single;
    expect(copiedState.stateJson, '{"inputs":{},"view":{}}');
    expect(copiedState.sourceHash, isNot('stale'));
    expect(copiedState.searchText, contains('Value: 1'));
  });

  test(
    'batch projection does not decode unrelated malformed attachment payloads',
    () async {
      await seed(repo, [message('r')]);
      await run(db, 'r');
      await db.customStatement(
        "INSERT INTO message_part_rows(conversation_id,revision_id,ordinal,kind,payload,created_at,updated_at) VALUES ('source','r',1,'image','malformed',0,0);",
      );
      final captured = await repo.captureGenUiTransfer(['r']);
      expect(captured['r']!.fingerprint, isNotNull);
    },
  );

  test('temporary transfer freezes completion proof', () async {
    final m = message('r')
      ..hydrateGenerationState(GenerationRunState.completed);
    final transfer = UiRevisionTransfer.temporary(m, const []);
    m.hydrateGenerationState(GenerationRunState.failed);
    expect(transfer.generation, GenerationRunState.completed);
  });
}
