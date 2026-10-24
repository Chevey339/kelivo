import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/business_repository.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/backup.dart';
import 'package:Kelivo/core/services/backup/backup_cancel_token.dart';
import 'package:Kelivo/core/services/backup/backup_task_progress.dart';
import 'package:Kelivo/core/services/backup/data_sync.dart';
import 'package:Kelivo/core/services/backup/restore_receipt.dart';
import 'package:Kelivo/core/services/backup/restore_bundle_preparation.dart';
import 'package:Kelivo/core/services/backup/restore_startup_gate.dart';
import 'package:Kelivo/core/services/backup/restore_workspace_lock.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_state.dart';
import '../../support/commit_gate.dart';
import '../../support/genui_backup_fixture.dart';
import '../../support/recovery_fault_durability.dart';

const _config = WebDavConfig(
  scope: BackupScope(
    excluded: {
      BackupCategory.files,
      BackupCategory.skills,
      BackupCategory.workspaces,
    },
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory root;
  late GenUiBackupFixture fixture;
  late CommitGate commits;
  File? archive;
  var connectionsClosed = false;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('genui-backup-test-');
    commits = CommitGate();
    fixture = await GenUiBackupFixture.create(root, interceptor: commits);
    archive = null;
    connectionsClosed = false;
  });

  tearDown(() async {
    if (!connectionsClosed) {
      await fixture.database.customStatement(
        'DROP TRIGGER IF EXISTS fail_genui;',
      );
    }
    if (archive != null) await DataSync.cleanupTemporaryBackupFile(archive!);
    await fixture.dispose();
    await root.delete(recursive: true);
  });

  Future<void> closeConnections() async {
    await fixture.closeConnections();
    connectionsClosed = true;
  }

  Future<GenUiSurfaceStateRow> liveState() => (fixture.database.select(
    fixture.database.genUiSurfaceStateRows,
  )..where((s) => s.revisionId.equals('a1'))).getSingle();

  Future<void> verifyRestored() async {
    await closeConnections();
    final result = await RestoreStartupGate.recoverAndRequireBusinessReady(
      appDataDirectory: fixture.appData,
    );
    expect(result?.state, RestoreReceiptState.committed);
    final file = File(
      p.join(fixture.appData.path, AppDatabase.databaseFileName),
    );
    expect(
      (await ChatDatabaseRepository.inspectPreparedSnapshot(
        file,
      )).schemaVersion,
      5,
    );
    final database = AppDatabase.open(file: file, requireExisting: true);
    final repository = ChatDatabaseRepository(database, databaseFile: file);
    try {
      await repository.ensureReady();
      final states = await database
          .select(database.genUiSurfaceStateRows)
          .get();
      expect(states, hasLength(2));
      final selected = states.singleWhere((s) => s.revisionId == 'a1');
      expect(jsonDecode(selected.stateJson), {
        'inputs': {'factor': 15},
        'view': {
          'items': {'descending': true, 'filter': 'o', 'sortKey': 'v'},
        },
      });
      expect(selected.searchText, contains('Synthetic total: 6'));
      expect(
        (await repository.getConversation('genui-legacy'))!.versionSelections,
        {'a0': 1},
      );
      expect(
        (await repository.getMessage('a1'))!.content,
        contains(genUiBackupFence),
      );
      final found = await repository.searchConversationMatches(tokens: ['6']);
      expect(found.map((match) => match.messageId), ['a1']);
      expect(found.single.searchableText, contains('Synthetic total: 6'));
      expect(found.single.matchedSurfaceKey, '0:0');
      final miniMap = await repository.searchMiniMapMatches(
        'genui-legacy',
        'Synthetic total: 6',
      );
      expect(miniMap.single.messageId, 'a1');
      expect(miniMap.single.matchedSurfaceKey, '0:0');
      final afterIndex = await (database.select(
        database.genUiSurfaceStateRows,
      )..where((row) => row.revisionId.equals('a1'))).getSingle();
      expect(afterIndex.stateJson, selected.stateJson);
      expect(afterIndex.updatedAt, selected.updatedAt);
      expect(
        await database.customSelect('PRAGMA foreign_key_check;').get(),
        isEmpty,
      );
      expect(
        (await database
                .customSelect(
                  "SELECT rowid FROM gen_ui_surface_search WHERE gen_ui_surface_search MATCH 'Synthetic';",
                )
                .get())
            .length,
        2,
      );
    } finally {
      await repository.close();
    }
  }

  for (final flavor in ['plain', 'encrypted', 'local']) {
    test(
      '$flavor backup flushes inputs/view and survives actual startup cutover',
      () async {
        archive = flavor == 'local'
            ? (await fixture.sync.prepareLocalSnapshotArchive()).file
            : await fixture.sync.prepareBackupFile(
                _config,
                password: flavor == 'encrypted' ? 'synthetic-password' : null,
              );
        final originalHash = (await sha256.bind(archive!.openRead()).first)
            .toString();
        expect(
          jsonDecode((await liveState()).stateJson)['inputs']['factor'],
          15,
        );
        final lease = await fixture.accept(value: 77, flush: true);
        await fixture.sync.restoreFromLocalFile(
          archive!,
          _config,
          mode: RestoreMode.overwrite,
          onPassword: ({required retry}) async => 'synthetic-password',
        );
        expect(fixture.repository.genUiStates.accepting, isFalse);
        // Preparation has not installed the replacement database yet.
        expect(
          jsonDecode((await liveState()).stateJson)['inputs']['factor'],
          77,
        );
        await expectLater(
          fixture.preferences.setString('theme_mode_v1', 'late'),
          throwsStateError,
        );
        await verifyRestored();
        expect(lease.valid, isFalse);
        expect(
          (await sha256.bind(archive!.openRead()).first).toString(),
          originalHash,
        );
      },
    );
  }

  test(
    'backup aborts on save failure and retains the accepted update for retry',
    () async {
      await fixture.repository.genUiStates.flush();
      final lease = await fixture.accept(value: 23);
      final statuses = <bool>[];
      final remove = lease.listenSaved(
        (snapshot, failed) => statuses.add(failed),
      );
      addTearDown(remove);
      await fixture.database.customStatement(
        "CREATE TRIGGER fail_genui BEFORE INSERT ON gen_ui_surface_state_rows BEGIN SELECT RAISE(ABORT, 'disk'); END;",
      );
      await expectLater(
        fixture.sync.prepareBackupFile(_config),
        throwsA(anything),
      );
      expect(jsonDecode((await liveState()).stateJson)['inputs']['factor'], 15);
      expect(statuses, contains(true));
      expect(lease.valid, isTrue);
      await fixture.database.customStatement('DROP TRIGGER fail_genui;');
      archive = await fixture.sync.prepareBackupFile(_config);
      expect(jsonDecode((await liveState()).stateJson)['inputs']['factor'], 23);
      expect(statuses.last, isFalse);
    },
  );

  test(
    'settings-only export/restore omits UI state and never pauses its owner',
    () async {
      final config = _config.copyWith(
        scope: _config.scope.withCategory(BackupCategory.chats, false),
      );
      await fixture.repository.genUiStates.flush();
      await fixture.accept(value: 25);
      await fixture.database.customStatement(
        "CREATE TRIGGER fail_genui BEFORE INSERT ON gen_ui_surface_state_rows BEGIN SELECT RAISE(ABORT, 'disk'); END;",
      );
      archive = await fixture.sync.prepareBackupFile(config);
      final packed = ZipDecoder().decodeBytes(await archive!.readAsBytes());
      expect(packed.findFile('database/kelivo.db'), isNull);
      expect(packed.files.any((f) => f.name.contains('genui')), isFalse);
      packed.clear();
      await fixture.sync.restoreFromLocalFile(archive!, config);
      expect(fixture.repository.genUiStates.accepting, isTrue);
      await fixture.database.customStatement('DROP TRIGGER fail_genui;');
      await fixture.repository.genUiStates.flush();
      expect(jsonDecode((await liveState()).stateJson)['inputs']['factor'], 25);
    },
  );

  test(
    'authentication failure and password cancellation keep the current lease',
    () async {
      archive = await fixture.sync.prepareBackupFile(
        _config,
        password: 'synthetic-password',
      );
      final lease = await fixture.accept(value: 31);
      var attempts = 0;
      await expectLater(
        fixture.sync.restoreFromLocalFile(
          archive!,
          _config,
          onPassword: ({required retry}) async =>
              attempts++ == 0 ? 'wrong' : null,
        ),
        throwsA(isA<BackupCancelledException>()),
      );
      expect(attempts, 2);
      expect(fixture.repository.genUiStates.accepting, isTrue);
      expect(lease.valid, isTrue);
      await fixture.repository.genUiStates.flush();
      expect(jsonDecode((await liveState()).stateJson)['inputs']['factor'], 31);
      expect(
        await RestoreStartupGate.inspect(appDataDirectory: fixture.appData),
        isNull,
      );
    },
  );

  test(
    'preflight rejection and cancelled staging never revoke accepted state',
    () async {
      final malformed = File(p.join(root.path, 'malformed.zip'));
      await malformed.writeAsString('not an archive');
      final lease = await fixture.accept(value: 41);
      await expectLater(
        fixture.sync.restoreFromLocalFile(malformed, _config),
        throwsA(anything),
      );
      expect(fixture.repository.genUiStates.accepting, isTrue);
      expect(lease.valid, isTrue);
      archive = await fixture.sync.prepareBackupFile(_config);
      final cancel = BackupCancelToken();
      addTearDown(cancel.dispose);
      await expectLater(
        fixture.sync.restoreFromLocalFile(
          archive!,
          _config,
          cancelToken: cancel,
          onProgress: (progress) {
            if (progress.phase == BackupPhase.stagingCandidate &&
                progress.processed >= 1) {
              cancel.cancel();
            }
          },
        ),
        throwsA(isA<BackupCancelledException>()),
      );
      expect(fixture.repository.genUiStates.accepting, isTrue);
      expect(lease.valid, isTrue);
      await fixture.preferences.setString('theme_mode_v1', 'dark');
      expect(
        await RestoreStartupGate.inspect(appDataDirectory: fixture.appData),
        isNull,
      );
    },
  );

  test(
    'restore waits for issued UI SQL before publishing its receipt',
    () async {
      archive = await fixture.sync.prepareBackupFile(_config);
      final extracted = Directory(p.join(root.path, 'prepared-input'));
      await extracted.create();
      final packed = ZipDecoder().decodeBytes(await archive!.readAsBytes());
      for (final entry in packed.files.where((f) => f.isFile)) {
        final target = File(p.join(extracted.path, entry.name));
        expect(p.isWithin(extracted.path, target.path), isTrue);
        await target.parent.create(recursive: true);
        await target.writeAsBytes(entry.readBytes()!);
      }
      packed.clear();
      final manifest = File(p.join(extracted.path, 'manifest.json'));
      final manifestHash = (await sha256.bind(manifest.openRead()).first)
          .toString();
      final entered = Completer<void>();
      final release = Completer<void>();
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      final paused = Completer<void>();
      final remove = fixture.repository.genUiStates.listenAvailability(() {
        if (!fixture.repository.genUiStates.accepting && !paused.isCompleted) {
          paused.complete();
        }
      });
      addTearDown(remove);
      var completed = false;
      var drained = false;
      Future<void>? saving;
      final restoring =
          RestoreBundlePreparation.prepare(
            appDataDirectory: fixture.appData,
            extractedDirectory: extracted,
            sourceManifestSha256: manifestHash,
            bundleIncludesChats: true,
            bundleIncludesFiles: false,
            restoreChats: true,
            restoreFiles: false,
            scope: _config.scope,
            beforePublish: () async {
              // Candidate validation reads the old business snapshot first.
              // Hold a genuine write only once that preparatory work is done.
              await fixture.accept(value: 51);
              commits.onNextCommit = () async {
                entered.complete();
                await release.future;
              };
              saving = fixture.repository.genUiStates.flush();
              await entered.future;
              // Only the production barrier may delay publication. Waiting
              // for saving here would hide a broken pauseAndDrain contract.
              await fixture.repository.genUiStates.pauseAndDrain();
              drained = true;
            },
          ).then((_) {
            completed = true;
          });
      await paused.future.timeout(const Duration(seconds: 15));
      await Future<void>.delayed(Duration.zero);
      expect(drained, isFalse);
      expect(completed, isFalse);
      final workspace = Directory(
        p.join(fixture.appData.path, RestoreWorkspaceLock.workspaceRootName),
      );
      final receipts = await workspace
          .list(recursive: true, followLinks: false)
          .where(
            (f) =>
                p.basename(f.path).startsWith('receipt_') &&
                f.path.endsWith('.json'),
          )
          .toList();
      expect(receipts, isEmpty);
      release.complete();
      await saving;
      await restoring;
      expect(drained, isTrue);
      expect(fixture.repository.genUiStates.accepting, isFalse);
    },
  );

  test(
    'failed startup cutover rolls back private state and reopens writable owners',
    () async {
      archive = await fixture.sync.prepareBackupFile(_config);
      final oldLease = await fixture.accept(value: 71, flush: true);
      await fixture.sync.restoreFromLocalFile(archive!, _config);
      await closeConnections();
      expect(oldLease.valid, isFalse);
      final databaseFile = File(
        p.join(fixture.appData.path, AppDatabase.databaseFileName),
      );
      var thrown = false;
      final fault = FaultDurability()
        ..afterRename = (path) async {
          if (!thrown && p.equals(path, databaseFile.path)) {
            thrown = true;
            throw const FileSystemException(
              'injected new database install failure',
            );
          }
        };
      final restored = await RestoreStartupGate.recoverAndRequireBusinessReady(
        appDataDirectory: fixture.appData,
        durability: fault,
      );
      expect(thrown, isTrue);
      expect(restored?.state, RestoreReceiptState.rolledBack);
      final database = AppDatabase.open(
        file: databaseFile,
        requireExisting: true,
      );
      final repository = ChatDatabaseRepository(
        database,
        databaseFile: databaseFile,
      );
      const owner = UiSurfaceOwner(revisionId: 'a1', surfaceKey: '0:0');
      final controller = UiSurfaceController(owner: owner)
        ..updateSource(
          genUiBackupBody,
          closed: true,
          generation: UiGenerationStatus.complete,
        );
      try {
        final lease = repository.genUiStates.attach(
          'genui-legacy',
          owner,
          controller.sourceHash!,
        )!;
        final saved = await repository.genUiStates.load(lease);
        expect(
          controller.restore(saved.snapshot!, token: controller.restoreToken),
          isTrue,
        );
        expect(controller.state.inputs['factor'], 71);
        controller.setInputs({'factor': 72}, token: controller.token);
        expect(
          repository.genUiStates.accept(lease, controller.captureSnapshot()),
          isTrue,
        );
        await repository.genUiStates.flush();
        final row = await (database.select(
          database.genUiSurfaceStateRows,
        )..where((s) => s.revisionId.equals('a1'))).getSingle();
        expect(jsonDecode(row.stateJson)['inputs']['factor'], 72);
      } finally {
        controller.dispose();
        await repository.close();
      }
    },
  );

  for (final afterPublication in [false, true]) {
    test(
      'receipt IO failure afterPublication=$afterPublication resumes only proven old ownership',
      () async {
        archive = await fixture.sync.prepareBackupFile(_config);
        await fixture.accept(value: 61);
        final fault = FaultDurability();
        var thrown = false;
        if (afterPublication) {
          fault.afterRename = (path) async {
            if (!thrown &&
                p.basename(p.dirname(path)) == 'receipts' &&
                path.endsWith('.json')) {
              thrown = true;
              throw const FileSystemException('after durable receipt rename');
            }
          };
        } else {
          fault.onSync = (file) async {
            if (!thrown &&
                p.basename(file.parent.path) == 'receipts' &&
                file.path.endsWith('.tmp')) {
              thrown = true;
              throw const FileSystemException('before receipt publication');
            }
          };
        }
        final sync = DataSync(
          chatService: fixture.chat,
          businessRepository: BusinessRepository(fixture.database),
          businessPreferences: fixture.preferences,
          restoreDurability: fault,
        );
        await expectLater(
          sync.restoreFromLocalFile(archive!, _config),
          throwsA(anything),
        );
        expect(thrown, isTrue);
        expect(fixture.repository.genUiStates.accepting, !afterPublication);
        if (afterPublication) {
          await expectLater(
            fixture.preferences.setString('theme_mode_v1', 'late'),
            throwsStateError,
          );
          await verifyRestored();
        } else {
          await fixture.preferences.setString('theme_mode_v1', 'dark');
          await fixture.accept(value: 62, flush: true);
          expect(
            jsonDecode((await liveState()).stateJson)['inputs']['factor'],
            62,
          );
          expect(
            await RestoreStartupGate.inspect(appDataDirectory: fixture.appData),
            isNull,
          );
        }
      },
    );
  }
}
