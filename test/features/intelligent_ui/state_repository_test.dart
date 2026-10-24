import '../../support/commit_gate.dart';
import 'dart:async';
import 'dart:io';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/database/generation_run.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/features/intelligent_ui/host/ui_persistence_binding.dart';
import 'package:Kelivo/features/intelligent_ui/host/ui_runtime_registry.dart';
import 'package:Kelivo/features/intelligent_ui/host/ui_source_selection.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_state.dart';
import 'package:Kelivo/features/intelligent_ui/storage/ui_state_repository.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const _body = r'''ui 1 catalog "kelivo.native/1"
$value: number = 1
root = Column(children=[field,result])
field = Slider(label="Value", bind=$value, min=0, max=100)
result = Metric(label="Result", value=$value * 2)
''';
const _fence = '```kelivo-ui\n$_body```';
const _owner = UiSurfaceOwner(revisionId: 'revision', surfaceKey: '0:0');

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory directory;
  late AppDatabase db;
  late ChatDatabaseRepository repo;
  late CommitGate commits;
  late ChatMessage original;
  late List<GenUiSurfaceStateRow> initialCache;
  final bindings = <UiPersistenceBinding>[];
  final controllers = <UiSurfaceController>[];

  Future<void> open() async {
    commits = CommitGate();
    db = AppDatabase(
      NativeDatabase(
        File('${directory.path}/chat.sqlite'),
      ).interceptWith(commits),
    );
    repo = ChatDatabaseRepository(db);
    await repo.ensureReady();
  }

  Future<void> complete(String id, {String runId = 'run'}) async {
    var run = await repo.createGenerationRun(
      id: runId,
      conversationId: 'conversation',
      targetRevisionId: id,
      createdAt: DateTime.now().toUtc(),
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
        updatedAt: DateTime.now().toUtc(),
      );
    }
  }

  UiSurfaceController controller({
    String source = _body,
    UiSurfaceOwner owner = _owner,
  }) {
    final value = UiSurfaceController(owner: owner)
      ..updateSource(
        source,
        closed: true,
        generation: UiGenerationStatus.complete,
      );
    controllers.add(value);
    return value;
  }

  UiStateLease attach(UiSurfaceController value) =>
      repo.genUiStates.attach('conversation', value.owner, value.sourceHash!)!;

  void accept(UiSurfaceController value, UiStateLease lease, num input) {
    expect(
      value.setInputs({'value': input}, token: value.token),
      anyOf(UiMutationResult.accepted, UiMutationResult.unchanged),
    );
    expect(repo.genUiStates.accept(lease, value.captureSnapshot()), isTrue);
  }

  Future<List<GenUiSurfaceStateRow>> rows() =>
      db.select(db.genUiSurfaceStateRows).get();

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('genui-state-');
    await open();
    await repo.putConversation(Conversation(id: 'conversation', title: 'Test'));
    original = ChatMessage(
      id: 'revision',
      conversationId: 'conversation',
      role: 'assistant',
      content: _fence,
    );
    await repo.putMessage(original);
    await complete(original.id);
    original = (await repo.getMessage(original.id))!;
    initialCache = await rows();
  });

  tearDown(() async {
    for (final binding in bindings) {
      binding.dispose();
    }
    for (final value in controllers) {
      value.dispose();
    }
    bindings.clear();
    controllers.clear();
    await db.customStatement('DROP TRIGGER IF EXISTS fail_genui;');
    await repo.close();
    await directory.delete(recursive: true);
  });

  test(
    'accepted normalized inputs survive a real SQLite close/reopen',
    () async {
      final value = controller();
      accept(value, attach(value), 7);
      await repo.genUiStates.flush();
      expect(
        (await rows()).single.stateJson,
        '{"inputs":{"value":7.0},"view":{}}',
      );
      await repo.close();
      await open();
      final reopened = controller();
      final restored = await repo.genUiStates.load(attach(reopened));
      expect(
        reopened.restore(restored.snapshot!, token: reopened.restoreToken),
        isTrue,
      );
      expect(reopened.nodes['result']!.properties['value'], 14);
    },
  );

  test(
    'upsert preserves rowid and semantic cache; Reset preserves that row',
    () async {
      final value = controller();
      final lease = attach(value);
      accept(value, lease, 3);
      await repo.genUiStates.flush();
      await db.customStatement(
        "UPDATE gen_ui_surface_state_rows SET search_text = 'cached result';",
      );
      final id =
          (await db
                  .customSelect('SELECT rowid FROM gen_ui_surface_state_rows')
                  .getSingle())
              .read<int>('rowid');
      accept(value, lease, 9);
      await repo.genUiStates.flush();
      expect((await rows()).single.searchText, 'cached result');
      value.reset(token: value.token);
      repo.genUiStates.accept(lease, value.captureSnapshot());
      await repo.genUiStates.flush();
      final reset = (await rows()).single;
      expect(reset.stateJson, '{"inputs":{},"view":{}}');
      expect(reset.searchText, 'cached result');
      expect(
        (await db
                .customSelect('SELECT rowid FROM gen_ui_surface_state_rows')
                .getSingle())
            .read<int>('rowid'),
        id,
      );
      expect(
        (await db
                .customSelect(
                  "SELECT count(*) AS n FROM gen_ui_surface_search WHERE gen_ui_surface_search MATCH 'cached'",
                )
                .getSingle())
            .read<int>('n'),
        1,
      );
    },
  );

  test('IO queue progresses after its creator microtask clock stops', () async {
    final stranded = <void Function()>[];
    final marker = Object();
    Object? observed;
    late UiStateRepository scoped;
    runZoned(
      () {
        scoped = UiStateRepository(db, (id) {
          observed = Zone.current[marker];
          return repo.getMessage(id);
        });
      },
      zoneValues: {marker: 'retained'},
      zoneSpecification: ZoneSpecification(
        scheduleMicrotask: (_, _, _, callback) {
          stranded.add(callback);
        },
      ),
    );
    final value = controller();
    final lease = scoped.attach(
      'conversation',
      value.owner,
      value.sourceHash!,
    )!;
    value.setInputs({'value': 6}, token: value.token);
    scoped.accept(lease, value.captureSnapshot());
    await scoped.flush().timeout(const Duration(seconds: 3));
    expect((await rows()).single.stateJson, contains('6.0'));
    expect(observed, 'retained');
    expect(stranded, isEmpty);
    await scoped.pauseAndDrain();
    scoped.discardAfterCutover();
  });

  test(
    'debounce coalesces accepted values without an explicit flush',
    () async {
      final value = controller();
      final lease = attach(value);
      final saved = db
          .select(db.genUiSurfaceStateRows)
          .watch()
          .firstWhere(
            (rows) => rows.any((row) => row.stateJson.contains('4.0')),
          )
          .timeout(const Duration(seconds: 3));
      accept(value, lease, 2);
      accept(value, lease, 3);
      accept(value, lease, 4);
      expect(await rows(), initialCache);
      expect((await saved).single.stateJson, contains('4.0'));
    },
  );

  test('same normalized value does not change its save timestamp', () async {
    final value = controller();
    final lease = attach(value);
    accept(value, lease, 2);
    await repo.genUiStates.flush();
    final saved = (await rows()).single.updatedAt;
    repo.genUiStates.accept(lease, value.captureSnapshot());
    await repo.genUiStates.flush();
    expect((await rows()).single.updatedAt, saved);
  });

  test('completed source is verified from DB, never from a UI claim', () async {
    await db.customStatement('DELETE FROM generation_run_rows;');
    final value = controller();
    final lease = attach(value);
    accept(value, lease, 3);
    await repo.genUiStates.flush();
    expect(await rows(), initialCache);
    expect(lease.valid, isFalse);
  });

  for (final change in ['role', 'source', 'missing', 'nested', 'thinking']) {
    test(
      'save rejects changed $change authority in the same transaction',
      () async {
        final value = controller();
        final lease = attach(value);
        accept(value, lease, 4);
        switch (change) {
          case 'role':
            await db.customStatement("UPDATE message_rows SET role = 'user';");
          case 'source':
            await repo.updateMessage(
              original.copyWith(content: _fence.replaceAll('= 1', '= 2')),
            );
          case 'missing':
            await repo.deleteMessage(original.id);
          case 'nested':
            await repo.updateMessage(
              original.copyWith(
                content: _fence.split('\n').map((line) => '> $line').join('\n'),
              ),
            );
          case 'thinking':
            await repo.updateMessage(
              original.copyWith(content: '<think>\n$_fence\n</think>'),
            );
        }
        await repo.genUiStates.flush();
        if (change == 'role') {
          expect(await rows(), initialCache);
        } else if (change == 'source') {
          final cached = (await rows()).single;
          expect(cached.stateJson, '{"inputs":{},"view":{}}');
          expect(cached.sourceHash, isNot(initialCache.single.sourceHash));
          expect(cached.searchText, contains('Result: 4'));
        } else {
          expect(await rows(), isEmpty);
        }
        expect(lease.valid, isFalse);
        expect(
          repo.genUiStates.accept(lease, value.captureSnapshot()),
          isFalse,
        );
        if (change == 'missing') {
          expect(await repo.getMessage(original.id), isNull);
        }
      },
    );
  }

  test(
    'same-source update keeps the active lease and pending overrides',
    () async {
      final value = controller();
      final lease = attach(value);
      accept(value, lease, 5);
      await repo.updateMessage(
        original.copyWith(translation: 'unchanged source'),
      );
      expect(lease.valid, isTrue);
      await repo.genUiStates.flush();
      expect((await rows()).single.stateJson, contains('5.0'));
    },
  );

  test(
    'committed A to B to A revokes a captured lease despite matching final hash',
    () async {
      final value = controller();
      final lease = attach(value);
      accept(value, lease, 6);
      await repo.genUiStates.transaction(() async {
        await repo.updateMessage(
          original.copyWith(content: _fence.replaceAll('= 1', '= 2')),
        );
        await repo.updateMessage(original);
      });
      expect(lease.valid, isFalse);
      expect(repo.genUiStates.accept(lease, value.captureSnapshot()), isFalse);
      await repo.genUiStates.flush();
      expect(await rows(), initialCache);
      final fresh = await repo.genUiStates.load(attach(controller()));
      expect(fresh.valid, isTrue);
      expect(fresh.snapshot!.state.isDefault, isTrue);
    },
  );

  test(
    'rollback discards invalidations and retains dirty accepted state',
    () async {
      final value = controller();
      final lease = attach(value);
      accept(value, lease, 3);
      await repo.genUiStates.flush();
      accept(value, lease, 8);
      await expectLater(
        repo.genUiStates.transaction(() async {
          await repo.updateMessage(original.copyWith(content: 'new source'));
          throw StateError('rollback');
        }),
        throwsStateError,
      );
      expect(lease.valid, isTrue);
      expect((await rows()).single.stateJson, contains('3.0'));
      await repo.genUiStates.flush();
      expect((await rows()).single.stateJson, contains('8.0'));
    },
  );

  for (final deleteFirst in [false, true]) {
    test(
      'queued save/delete ordering never resurrects an owner deleteFirst=$deleteFirst',
      () async {
        final entered = Completer<void>();
        final release = Completer<void>();
        final held = repo.genUiStates.transaction(() async {
          entered.complete();
          await release.future;
        });
        await entered.future;
        final value = controller();
        accept(value, attach(value), 7);
        final Future<void> save, delete;
        if (deleteFirst) {
          delete = repo
              .deleteMessages(
                conversationId: 'conversation',
                messageIds: {'revision'},
                versionSelectionChanges: const {},
              )
              .then((_) {});
          save = repo.genUiStates.flush();
        } else {
          save = repo.genUiStates.flush();
          delete = repo
              .deleteMessages(
                conversationId: 'conversation',
                messageIds: {'revision'},
                versionSelectionChanges: const {},
              )
              .then((_) {});
        }
        release.complete();
        await Future.wait([held, save, delete]);
        expect(await rows(), isEmpty);
        expect(await repo.getMessage('revision'), isNull);
      },
    );
  }

  test(
    'conversation deletion enters composer then writer without deadlock',
    () async {
      final value = controller();
      final lease = attach(value);
      accept(value, lease, 5);
      await Future.wait([
        repo.genUiStates.flush(),
        repo.deleteConversation('conversation'),
      ]).timeout(const Duration(seconds: 5));
      expect(await rows(), isEmpty);
      expect(lease.valid, isFalse);
    },
  );

  test(
    'clearAll cancels pending tasks and cannot create replacement messages',
    () async {
      final value = controller();
      final lease = attach(value);
      accept(value, lease, 5);
      await repo.clearAllData();
      await repo.genUiStates.flush();
      expect(await rows(), isEmpty);
      expect(lease.valid, isFalse);
      expect(await repo.getMessage('revision'), isNull);
    },
  );

  test('failed write is visible, retained on reopen and retryable', () async {
    final value = controller();
    final binding = UiPersistenceBinding(
      value,
      repo.genUiStates,
      'conversation',
    );
    bindings.add(binding);
    await binding.flush();
    await db.customStatement(
      "CREATE TRIGGER fail_genui BEFORE INSERT ON gen_ui_surface_state_rows BEGIN SELECT RAISE(ABORT, 'disk failure'); END;",
    );
    value.setInputs({'value': 9}, token: value.token);
    await expectLater(value.flush(), throwsA(anything));
    expect(value.saveFailed, isTrue);
    expect(await rows(), initialCache);
    binding.dispose();
    value.dispose();
    final reopened = controller();
    final next = UiPersistenceBinding(
      reopened,
      repo.genUiStates,
      'conversation',
    );
    bindings.add(next);
    // The queue's accepted value wins over the durable default cache.
    await repo.genUiStates.load(attach(reopened));
    await Future<void>.delayed(Duration.zero);
    expect(reopened.state.inputs['value'], 9);
    expect(reopened.saveFailed, isTrue);
    await db.customStatement('DROP TRIGGER fail_genui;');
    await reopened.flush();
    expect(reopened.saveFailed, isFalse);
    expect((await rows()).single.stateJson, contains('9.0'));
  });

  test('a disposed page cannot cancel its accepted save', () async {
    final registry = UiRuntimeRegistry()
      ..configurePersistence(repo.genUiStates, canPersist: (_) => true);
    final entry = registry.obtain('conversation', _owner);
    entry.controller.updateSource(
      _body,
      closed: true,
      generation: UiGenerationStatus.complete,
    );
    await entry.controller.flush();
    entry.controller.setInputs({'value': 12}, token: entry.controller.token);
    registry.dispose();
    await repo.genUiStates.flush();
    expect((await rows()).single.stateJson, contains('12.0'));
  });

  test(
    'temporary registry remains memory-only and does not invent messages',
    () async {
      final registry = UiRuntimeRegistry()
        ..configurePersistence(repo.genUiStates, canPersist: (_) => false);
      const owner = UiSurfaceOwner(revisionId: 'temporary', surfaceKey: '0:0');
      final entry = registry.obtain('temporary', owner);
      entry.controller.updateSource(
        _body,
        closed: true,
        generation: UiGenerationStatus.complete,
      );
      entry.controller.setInputs({'value': 12}, token: entry.controller.token);
      await entry.controller.flush();
      registry.dispose();
      await repo.genUiStates.flush();
      expect(await rows(), initialCache);
      expect(await repo.getMessage('temporary'), isNull);
    },
  );

  test(
    'retained reasoning publishes canonical owner only after commit',
    () async {
      final next = ChatMessage(
        id: 'with-reasoning',
        conversationId: 'conversation',
        role: 'assistant',
        content: _fence,
        reasoningText: 'plan',
      );
      expect(uiEligibleFences(next).single.surfaceKey, '0:0');
      await repo.putMessage(next);
      await complete(next.id, runId: 'reasoning-run');
      expect(uiEligibleFences(next).single.surfaceKey, '1:0');
      expect(next.parts.first, isA<ReasoningPart>());
      expect(next.content, _fence);
      final copy = next.copyWith(parts: const [TextPart('replacement')]);
      expect(copy.parts, hasLength(1));
      expect(copy.content, 'replacement');
      final value = controller(
        owner: const UiSurfaceOwner(
          revisionId: 'with-reasoning',
          surfaceKey: '1:0',
        ),
      );
      accept(value, attach(value), 7);
      await repo.genUiStates.flush();
      final stored = await rows();
      expect(stored, hasLength(2));
      expect(
        stored.where((row) => row.revisionId == original.id).single,
        initialCache.single,
      );
      final saved = stored.singleWhere((row) => row.revisionId == next.id);
      expect(saved.surfaceKey, '1:0');
      expect(saved.stateJson, contains('7.0'));
    },
  );

  test(
    'rolled-back normalized parts are never published to the caller',
    () async {
      final next = ChatMessage(
        id: 'rollback-reasoning',
        conversationId: 'conversation',
        role: 'assistant',
        content: _fence,
        reasoningText: 'plan',
      );
      await expectLater(
        repo.genUiStates.transaction(() async {
          await repo.putMessage(next);
          throw StateError('rollback');
        }),
        throwsStateError,
      );
      expect(next.parts.first, isA<TextPart>());
      expect(await repo.getMessage(next.id), isNull);
    },
  );

  test(
    'delayed callbacks leave their completed transaction zone and requeue',
    () async {
      final value = controller();
      final lease = attach(value);
      final finished = Completer<void>();
      final committed = Completer<void>();
      await repo.genUiStates.transaction(() async {
        Timer.run(() async {
          try {
            await committed.future;
            await repo.updateMessage(original.copyWith(translation: 'later'));
            accept(value, lease, 11);
            await repo.genUiStates.flush();
            finished.complete();
          } catch (error, stack) {
            finished.completeError(error, stack);
          }
        });
      });
      committed.complete();
      await finished.future.timeout(const Duration(seconds: 5));
      expect((await rows()).single.stateJson, contains('11.0'));
    },
  );

  test(
    'pause blocks edits and resume attaches a runtime mounted while paused',
    () async {
      await repo.genUiStates.pauseAndDrain();
      final value = controller();
      final binding = UiPersistenceBinding(
        value,
        repo.genUiStates,
        'conversation',
      );
      bindings.add(binding);
      expect(value.readOnly, isTrue);
      expect(
        value.setInputs({'value': 7}, token: value.token),
        UiMutationResult.readOnly,
      );
      repo.genUiStates.resume();
      expect(value.readOnly, isFalse);
      value.setInputs({'value': 7}, token: value.token);
      await value.flush();
      expect((await rows()).single.stateJson, contains('7.0'));
    },
  );

  test(
    'stale source attachment cannot evict the current pending snapshot',
    () async {
      final current = controller();
      final currentBinding = UiPersistenceBinding(
        current,
        repo.genUiStates,
        'conversation',
      );
      bindings.add(currentBinding);
      await current.flush();
      current.setInputs({'value': 7}, token: current.token);
      final stale = controller(source: _body.replaceAll('= 1', '= 2'));
      final staleBinding = UiPersistenceBinding(
        stale,
        repo.genUiStates,
        'conversation',
      );
      bindings.add(staleBinding);
      await stale.flush();
      expect(current.readOnly, isFalse);
      expect(stale.readOnly, isTrue);
      expect((await rows()).single.stateJson, contains('7.0'));
    },
  );

  test(
    'candidate source waiting for commit retains accepted input until verified',
    () async {
      final previous = controller();
      final oldLease = attach(previous);
      final entered = Completer<void>(), release = Completer<void>();
      commits.onNextCommit = () {
        entered.complete();
        return release.future;
      };
      final rewrite = repo.updateMessage(
        original.copyWith(content: _fence.replaceAll('= 1', '= 2')),
      );
      await entered.future;
      final next = controller(source: _body.replaceAll('= 1', '= 2'));
      final binding = UiPersistenceBinding(
        next,
        repo.genUiStates,
        'conversation',
      );
      bindings.add(binding);
      next.setInputs({'value': 8}, token: next.token);
      release.complete();
      await rewrite;
      await next.flush();
      expect(oldLease.valid, isFalse);
      expect(next.readOnly, isFalse);
      expect((await rows()).single.stateJson, contains('8.0'));
    },
  );

  for (final metadata in [
    '[{"text":"reasoning"}]',
    '{"v":2,"segments":[{"text":"reasoning"}]}',
  ]) {
    test(
      'reasoning metadata eligibility uses renderer format $metadata',
      () async {
        await repo.updateMessage(
          original.copyWith(
            content: '<think>\n\n$_fence\n\n</think>',
            reasoningSegmentsJson: metadata,
          ),
        );
        final value = controller();
        final lease = attach(value);
        accept(value, lease, 7);
        await repo.genUiStates.flush();
        expect(lease.valid, isTrue);
        expect((await rows()).single.stateJson, contains('7.0'));
        await repo.genUiStates.transaction(() async {
          await repo.updateMessageFields(
            'revision',
            reasoningSegmentsJson: '{"v":2,"segments":[]}',
          );
          await repo.updateMessageFields(
            'revision',
            reasoningSegmentsJson: metadata,
          );
        });
        expect(lease.valid, isFalse);
        expect(await rows(), initialCache);
      },
    );
  }

  test('delayed transaction during COMMIT queues past a rollback', () async {
    final entered = Completer<void>(), release = Completer<void>();
    final delayed = Completer<void>();
    commits.onNextCommit = () async {
      entered.complete();
      await release.future;
      throw StateError('commit failed');
    };
    final outer = repo.genUiStates.transaction(() async {
      Timer.run(() async {
        try {
          await entered.future;
          await repo.updateMessage(original.copyWith(translation: 'later'));
          delayed.complete();
        } catch (error, stack) {
          delayed.completeError(error, stack);
        }
      });
    });
    final failed = expectLater(outer, throwsStateError);
    await entered.future;
    await Future<void>.delayed(Duration.zero);
    expect(delayed.isCompleted, isFalse);
    release.complete();
    await failed;
    await delayed.future.timeout(const Duration(seconds: 5));
    expect((await repo.getMessage('revision'))!.translation, 'later');
  });

  test(
    'caught nested rollback retains its source and lease inside outer commit',
    () async {
      final value = controller();
      final lease = attach(value);
      accept(value, lease, 7);
      await repo.genUiStates.flush();
      await repo.genUiStates.transaction(() async {
        try {
          await repo.finalizeGenerationRun(
            message: original.copyWith(content: 'removed'),
            toolEvents: const [],
            generationRunId: 'run',
            expectedState: GenerationRunState.streaming,
            expectedStateRevision: 0,
            terminalState: GenerationRunState.completed,
          );
        } on GenerationRunTransitionConflict {
          // Deliberately continue the outer transaction after a failed command.
        }
      });
      expect(lease.valid, isTrue);
      expect((await repo.getMessage('revision'))!.content, _fence);
      expect((await rows()).single.stateJson, contains('7.0'));
    },
  );

  for (final reset in [false, true]) {
    test(
      'explicit default choice beats blocked restore and persists reset=$reset',
      () async {
        final saved = controller();
        accept(saved, attach(saved), 9);
        await repo.genUiStates.flush();
        final entered = Completer<void>(), release = Completer<void>();
        final blocker = repo.genUiStates.transaction(() async {
          entered.complete();
          await release.future;
        });
        await entered.future;
        final next = controller();
        final binding = UiPersistenceBinding(
          next,
          repo.genUiStates,
          'conversation',
        );
        bindings.add(binding);
        if (reset) {
          next.reset(token: next.token);
        } else {
          next.setInputs({'value': 1}, token: next.token);
        }
        release.complete();
        await blocker;
        await next.flush();
        expect(next.state.isDefault, isTrue);
        expect((await rows()).single.stateJson, '{"inputs":{},"view":{}}');
      },
    );
  }

  test('a save whose SQL has executed drains before deletion', () async {
    final value = controller();
    final lease = attach(value);
    accept(value, lease, 4);
    final entered = Completer<void>(), release = Completer<void>();
    commits.onNextCommit = () {
      entered.complete();
      return release.future;
    };
    final save = repo.genUiStates.flush();
    await entered.future;
    var deleted = false;
    final deletion = repo
        .deleteMessages(
          conversationId: 'conversation',
          messageIds: {'revision'},
          versionSelectionChanges: const {},
        )
        .then((_) => deleted = true);
    await Future<void>.delayed(Duration.zero);
    expect(deleted, isFalse);
    release.complete();
    await save;
    await deletion;
    expect(await rows(), isEmpty);
    expect(await repo.getMessage('revision'), isNull);
  });

  test(
    'new value accepted during issued SQL survives the older save completion',
    () async {
      final value = controller();
      final lease = attach(value);
      accept(value, lease, 4);
      final entered = Completer<void>(), release = Completer<void>();
      commits.onNextCommit = () {
        entered.complete();
        return release.future;
      };
      final save = repo.genUiStates.flush();
      await entered.future;
      accept(value, lease, 7);
      release.complete();
      await save;
      expect(
        (await repo.genUiStates.load(lease)).snapshot!.state.inputs['value'],
        7,
      );
      await repo.genUiStates.flush();
      expect((await rows()).single.stateJson, contains('7.0'));
    },
  );

  test(
    'failed restore shows retry without overwriting a durable value with defaults',
    () async {
      final saved = controller();
      accept(saved, attach(saved), 9);
      await repo.genUiStates.flush();
      final timestamp = (await rows()).single.updatedAt;
      final next = controller();
      final failed = Completer<void>();
      next.listenStatus(() {
        if (next.saveFailed && !failed.isCompleted) failed.complete();
      });
      commits.onNextCommit = () async {
        throw StateError('read unavailable');
      };
      final binding = UiPersistenceBinding(
        next,
        repo.genUiStates,
        'conversation',
      );
      bindings.add(binding);
      await failed.future.timeout(const Duration(seconds: 5));
      expect(next.state.isDefault, isTrue);
      expect((await rows()).single.stateJson, contains('9.0'));
      await next.flush();
      expect(next.state.inputs['value'], 9);
      expect(next.saveFailed, isFalse);
      expect((await rows()).single.updatedAt, timestamp);
    },
  );

  test(
    'replacement conversation import revokes dirty revisions omitted by the batch',
    () async {
      final value = controller();
      final lease = attach(value);
      accept(value, lease, 8);
      await repo.putMigrationBatch(
        conversations: [Conversation(id: 'conversation', title: 'replacement')],
        messages: const [],
        toolEventsByMessageId: const {},
        geminiSignaturesByMessageId: const {},
      );
      await repo.genUiStates.flush();
      expect(lease.valid, isFalse);
      expect(await rows(), isEmpty);
      expect(await repo.getMessage('revision'), isNull);
    },
  );

  test(
    'tool-event deletion changes the original run owner and invalidates it',
    () async {
      final next = original.copyWith(
        parts: const [
          TextPart('prefix\n\n'),
          ToolCallPart('{"id":"tool","name":"test"}'),
          TextPart(_fence),
        ],
      );
      await repo.updateMessage(next);
      const owner = UiSurfaceOwner(revisionId: 'revision', surfaceKey: '2:0');
      final value = controller(owner: owner);
      final lease = attach(value);
      accept(value, lease, 8);
      await repo.genUiStates.flush();
      await repo.deleteToolEvents('revision');
      expect(lease.valid, isFalse);
      expect(await rows(), initialCache);
      expect(
        uiEligibleFences(
          (await repo.getMessage('revision'))!,
        ).single.surfaceKey,
        '0:0',
      );
    },
  );

  test(
    'finalization transition failure rolls back source and keeps the lease',
    () async {
      final value = controller();
      final lease = attach(value);
      accept(value, lease, 3);
      await repo.genUiStates.flush();
      await expectLater(
        repo.finalizeGenerationRun(
          message: original.copyWith(content: 'removed'),
          toolEvents: const [],
          generationRunId: 'run',
          expectedState: GenerationRunState.streaming,
          expectedStateRevision: 0,
          terminalState: GenerationRunState.completed,
        ),
        throwsA(isA<GenerationRunTransitionConflict>()),
      );
      expect(lease.valid, isTrue);
      expect((await rows()).single.stateJson, contains('3.0'));
      expect((await repo.getMessage('revision'))!.content, _fence);
    },
  );

  test(
    'failed drain resumes accepting values on the original database',
    () async {
      final value = controller();
      final lease = attach(value);
      accept(value, lease, 6);
      await db.customStatement(
        "CREATE TRIGGER fail_genui BEFORE INSERT ON gen_ui_surface_state_rows BEGIN SELECT RAISE(ABORT, 'disk failure'); END;",
      );
      await expectLater(repo.genUiStates.pauseAndDrain(), throwsA(anything));
      expect(lease.valid, isTrue);
      accept(value, lease, 8);
      await db.customStatement('DROP TRIGGER fail_genui;');
      await repo.genUiStates.flush();
      expect((await rows()).single.stateJson, contains('8.0'));
    },
  );
}
