import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/services/backup/restore_bundle_preparation.dart';
import 'package:Kelivo/core/services/backup/restore_cutover_executor.dart';
import 'package:Kelivo/core/services/backup/restore_durability.dart';
import 'package:Kelivo/core/services/backup/restore_previous_store.dart';
import 'package:Kelivo/core/services/backup/restore_receipt.dart';
import 'package:Kelivo/core/services/backup/restore_startup_gate.dart';
import 'package:Kelivo/core/services/backup/restore_workspace_lock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RestoreStartupGate', () {
    late Directory root;
    late Directory appData;

    setUp(() async {
      root = await Directory.systemTemp.createTemp(
        'kelivo_restore_startup_gate_test_',
      );
      appData = Directory(p.join(root.path, 'app_data'));
      await appData.create();
    });

    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    test('allows startup when no restore run exists', () async {
      expect(
        await RestoreStartupGate.recoverAndRequireBusinessReady(
          appDataDirectory: appData,
        ),
        isNull,
      );
    });

    test('discards a marker-only unpublished allocation', () async {
      const runId = '0123456789abcdef0123456789abcdef';
      final workspace = Directory(
        p.join(appData.path, RestoreWorkspaceLock.workspaceRootName),
      );
      await workspace.create();
      final marker = File(
        p.join(workspace.path, RestoreWorkspaceLock.activeRunFileName),
      );
      await marker.writeAsString(runId, flush: true);

      expect(
        await RestoreStartupGate.recoverAndRequireBusinessReady(
          appDataDirectory: appData,
        ),
        isNull,
      );
      expect(await marker.exists(), isFalse);
    });

    test('commits, revalidates, and archives in one startup pass', () async {
      final liveDatabase = File(p.join(appData.path, 'kelivo.db'));
      await _createDatabase(liveDatabase, conversationId: 'old');
      final oldUpload = File(p.join(appData.path, 'upload', 'old.txt'));
      await oldUpload.parent.create();
      await oldUpload.writeAsString('old asset', flush: true);
      final prepared = await _prepareBundle(
        root: root,
        appData: appData,
        directoryName: 'commit_source',
        includeFiles: true,
      );

      final terminal = await RestoreStartupGate.recoverAndRequireBusinessReady(
        appDataDirectory: appData,
      );

      expect(terminal?.state, RestoreReceiptState.committed);
      expect(await _conversationIds(liveDatabase), ['new']);
      expect(
        await File(p.join(appData.path, 'upload', 'new.txt')).readAsString(),
        'new asset',
      );
      expect(await oldUpload.exists(), isFalse);
      expect(
        await RestoreStartupGate.inspect(appDataDirectory: appData),
        isNull,
      );
      final archived = Directory(
        p.join(
          appData.path,
          RestoreWorkspaceLock.workspaceRootName,
          RestoreWorkspaceLock.completedRunsDirectoryName,
          'run_${prepared.runId}',
        ),
      );
      expect(await archived.exists(), isTrue);
      expect(
        await File(p.join(archived.path, 'settings_cold_ack.json')).exists(),
        isFalse,
      );
      expect(
        await File(
          p.join(
            archived.path,
            RestorePreviousStore.previousDirectoryName,
            'settings.json',
          ),
        ).exists(),
        isFalse,
      );
    });

    for (final includeFiles in [false, true]) {
      test(
        'resumes a v1.3.0 prepared restore with a local link ($includeFiles)',
        () async {
          final liveDatabase = File(p.join(appData.path, 'kelivo.db'));
          await _createDatabase(liveDatabase, conversationId: 'old');
          final external = File(p.join(root.path, 'external.txt'));
          await external.writeAsString('untouched');
          final link = Link(p.join(appData.path, 'workspaces', 'local-link'));
          await link.parent.create();
          await link.create(external.path);
          final prepared = await _prepareV130Bundle(
            root: root,
            appData: appData,
            includeFiles: includeFiles,
          );
          final manifestBytes = await File(
            p.join(prepared.candidateDirectory.path, 'manifest.json'),
          ).readAsBytes();

          final terminal =
              await RestoreStartupGate.recoverAndRequireBusinessReady(
                appDataDirectory: appData,
              );

          expect(terminal?.state, RestoreReceiptState.committed);
          expect(await _conversationIds(liveDatabase), ['new']);
          final archived = _archivedRun(appData, prepared.runId);
          final preservedLink = includeFiles
              ? Link(
                  p.join(archived.path, 'previous', 'workspaces', 'local-link'),
                )
              : link;
          expect(await preservedLink.target(), external.path);
          expect(await external.readAsString(), 'untouched');
          expect(
            await File(
              p.join(archived.path, 'candidate', 'manifest.json'),
            ).readAsBytes(),
            manifestBytes,
          );
          expect(
            await RestoreStartupGate.hasPendingWork(appDataDirectory: appData),
            isFalse,
          );
        },
        skip: Platform.isWindows
            ? 'Creating links requires Windows privileges'
            : false,
      );
    }

    for (final phase in [
      'preserving',
      'preserved',
      'installing',
      'installed',
      'verified',
      'rollingBack',
      'committed',
      'rolledBack',
    ]) {
      test('resumes v1.3.0 evidence interrupted while $phase', () async {
        final liveDatabase = File(p.join(appData.path, 'kelivo.db'));
        await _createDatabase(liveDatabase, conversationId: 'old');
        final oldUpload = File(p.join(appData.path, 'upload', 'old.txt'));
        await oldUpload.parent.create();
        await oldUpload.writeAsString('old asset');
        final prepared = await _prepareV130Bundle(
          root: root,
          appData: appData,
          includeFiles: true,
        );
        final previousBytes = await _interruptV130Cutover(
          prepared: prepared,
          appData: appData,
          phase: phase,
        );
        final originalReceipts = <String, List<int>>{};
        await for (final file in Directory(
          p.join(prepared.workspace.path, 'receipts'),
        ).list()) {
          originalReceipts[p.basename(file.path)] = await File(
            file.path,
          ).readAsBytes();
        }

        final terminal =
            await RestoreStartupGate.recoverAndRequireBusinessReady(
              appDataDirectory: appData,
            );

        final rolledBack = phase == 'rollingBack' || phase == 'rolledBack';
        expect(
          terminal?.state,
          rolledBack
              ? RestoreReceiptState.rolledBack
              : RestoreReceiptState.committed,
        );
        expect(await _conversationIds(liveDatabase), [
          rolledBack ? 'old' : 'new',
        ]);
        final archived = _archivedRun(appData, prepared.runId);
        expect(
          await File(
            p.join(archived.path, 'previous', 'manifest.json'),
          ).readAsBytes(),
          previousBytes,
        );
        for (final entry in originalReceipts.entries) {
          expect(
            await File(
              p.join(archived.path, 'receipts', entry.key),
            ).readAsBytes(),
            entry.value,
          );
        }
        expect(
          await File(
            p.join(appData.path, 'upload', rolledBack ? 'old.txt' : 'new.txt'),
          ).readAsString(),
          rolledBack ? 'old asset' : 'new asset',
        );
        final history = await RestoreReceiptStore(
          appDataDirectory: appData,
          runId: prepared.runId,
          archived: true,
        ).readHistory();
        expect(history.first.checksum, prepared.receipt.checksum);
        expect(history.last.checksum, terminal!.checksum);
        expect(
          await RestoreStartupGate.recoverAndRequireBusinessReady(
            appDataDirectory: appData,
          ),
          isNull,
        );
      });
    }

    test('reports every cutover stage in order for a pending run', () async {
      final liveDatabase = File(p.join(appData.path, 'kelivo.db'));
      await _createDatabase(liveDatabase, conversationId: 'old');
      final oldUpload = File(p.join(appData.path, 'upload', 'old.txt'));
      await oldUpload.parent.create();
      await oldUpload.writeAsString('old asset', flush: true);
      await _prepareBundle(
        root: root,
        appData: appData,
        directoryName: 'stage_source',
        includeFiles: true,
      );
      expect(
        await RestoreStartupGate.hasPendingWork(appDataDirectory: appData),
        isTrue,
      );

      final stages = <RestoreStartupStage>[];
      final terminal = await RestoreStartupGate.recoverAndRequireBusinessReady(
        appDataDirectory: appData,
        onStage: stages.add,
      );

      expect(terminal?.state, RestoreReceiptState.committed);
      expect(stages, [
        RestoreStartupStage.checkingBackup,
        RestoreStartupStage.preservingCurrentData,
        RestoreStartupStage.installingBackup,
        RestoreStartupStage.verifying,
        RestoreStartupStage.finishing,
      ]);
      expect(
        await RestoreStartupGate.hasPendingWork(appDataDirectory: appData),
        isFalse,
      );
    });

    test('rolls back and archives in the same startup pass', () async {
      final liveDatabase = File(p.join(appData.path, 'kelivo.db'));
      await _createDatabase(liveDatabase, conversationId: 'old');
      final oldUpload = File(p.join(appData.path, 'upload', 'old.txt'));
      await oldUpload.parent.create();
      await oldUpload.writeAsString('old asset', flush: true);
      final prepared = await _prepareBundle(
        root: root,
        appData: appData,
        directoryName: 'rollback_source',
        includeFiles: true,
      );
      final durability = _ThrowAfterCandidateDatabaseRename(
        appDataDirectory: appData,
        delegate: RestorePlatformDurability(),
      );

      final stages = <RestoreStartupStage>[];
      final terminal = await RestoreStartupGate.recoverAndRequireBusinessReady(
        appDataDirectory: appData,
        durability: durability,
        onStage: stages.add,
      );

      expect(terminal?.state, RestoreReceiptState.rolledBack);
      // Rollback re-derives the whole bundle from disk and outlasts the
      // forward path, so it must not leave the screen on 'installingBackup'.
      // It is reported twice because the compensating rollback and the
      // terminal re-convergence each enter the phase; a listener holding the
      // latest value sees one uninterrupted stage.
      expect(stages, [
        RestoreStartupStage.checkingBackup,
        RestoreStartupStage.preservingCurrentData,
        RestoreStartupStage.installingBackup,
        RestoreStartupStage.rollingBack,
        RestoreStartupStage.rollingBack,
        RestoreStartupStage.finishing,
      ]);
      expect(await _conversationIds(liveDatabase), ['old']);
      expect(await oldUpload.readAsString(), 'old asset');
      final archivedCandidate = File(
        p.join(
          appData.path,
          RestoreWorkspaceLock.workspaceRootName,
          RestoreWorkspaceLock.completedRunsDirectoryName,
          'run_${prepared.runId}',
          'candidate',
          'database',
          'kelivo.db',
        ),
      );
      expect(await _conversationIds(archivedCandidate), ['new']);
      expect(
        await RestoreStartupGate.inspect(appDataDirectory: appData),
        isNull,
      );
    });

    test('revalidates and archives an already-terminal active run', () async {
      await _createDatabase(
        File(p.join(appData.path, 'kelivo.db')),
        conversationId: 'old',
      );
      final prepared = await _prepareBundle(
        root: root,
        appData: appData,
        directoryName: 'terminal_source',
        includeFiles: false,
      );
      final workspaceLock = RestoreWorkspaceLock(appDataDirectory: appData);
      final executor = RestoreCutoverExecutor(
        appDataDirectory: appData,
        runId: prepared.runId,
        workspaceLock: workspaceLock,
      );
      final terminal = await workspaceLock.synchronized(
        () => executor.executeWhileWorkspaceLocked(
          observedMarkerFileName: RestoreWorkspaceLock.activeRunFileName,
        ),
      );
      expect(terminal.state, RestoreReceiptState.committed);
      expect(
        (await RestoreStartupGate.inspect(
          appDataDirectory: appData,
        ))?.receipt.state,
        RestoreReceiptState.committed,
      );

      final recovered = await RestoreStartupGate.recoverAndRequireBusinessReady(
        appDataDirectory: appData,
      );

      expect(recovered?.checksum, terminal.checksum);
      expect(
        await RestoreStartupGate.inspect(appDataDirectory: appData),
        isNull,
      );
    });

    test('resumes an interrupted terminal archive', () async {
      await _createDatabase(
        File(p.join(appData.path, 'kelivo.db')),
        conversationId: 'old',
      );
      final prepared = await _prepareBundle(
        root: root,
        appData: appData,
        directoryName: 'archive_source',
        includeFiles: false,
      );
      final throwing = _ThrowAfterRunArchiveRename(
        runId: prepared.runId,
        delegate: RestorePlatformDurability(),
      );

      await expectLater(
        RestoreStartupGate.recoverAndRequireBusinessReady(
          appDataDirectory: appData,
          durability: throwing,
        ),
        throwsA(isA<StateError>()),
      );
      final pending = await RestoreStartupGate.inspect(
        appDataDirectory: appData,
      );
      expect(pending?.runInCompletedDirectory, isTrue);
      expect(
        pending?.markerFileName,
        RestoreWorkspaceLock.archivingRunFileName,
      );

      final terminal = await RestoreStartupGate.recoverAndRequireBusinessReady(
        appDataDirectory: appData,
      );

      expect(terminal?.state, RestoreReceiptState.committed);
      expect(
        await RestoreStartupGate.inspect(appDataDirectory: appData),
        isNull,
      );
    });

    test('fails closed on a publishing marker without its run', () async {
      const runId = '0123456789abcdef0123456789abcdef';
      final workspace = Directory(
        p.join(appData.path, RestoreWorkspaceLock.workspaceRootName),
      );
      await workspace.create();
      final marker = File(
        p.join(workspace.path, RestoreWorkspaceLock.publishingRunFileName),
      );
      await marker.writeAsString(runId, flush: true);

      await expectLater(
        RestoreStartupGate.recoverAndRequireBusinessReady(
          appDataDirectory: appData,
        ),
        throwsA(isA<StateError>()),
      );
      expect(await marker.exists(), isTrue);
    });

    test('fails closed on an unpublished three-leg settings trace', () async {
      const runId = '0123456789abcdef0123456789abcdef';
      final workspace = Directory(
        p.join(appData.path, RestoreWorkspaceLock.workspaceRootName),
      );
      final run = Directory(p.join(workspace.path, 'run_$runId'));
      final candidate = Directory(p.join(run.path, 'candidate'));
      await candidate.create(recursive: true);
      final marker = File(
        p.join(workspace.path, RestoreWorkspaceLock.activeRunFileName),
      );
      await marker.writeAsString(runId, flush: true);
      final retired = File(p.join(candidate.path, 'settings.json'));
      await retired.writeAsString('{}', flush: true);

      await expectLater(
        RestoreStartupGate.recoverAndRequireBusinessReady(
          appDataDirectory: appData,
        ),
        throwsA(isA<StateError>()),
      );
      expect(await retired.exists(), isTrue);
      expect(await marker.exists(), isTrue);
    });
  });
}

const _v130AssetRoots = [
  'upload',
  'images',
  'avatars',
  'fonts',
  'skills',
  'workspaces',
  'sessions',
];

Directory _archivedRun(Directory appData, String runId) => Directory(
  p.join(
    appData.path,
    RestoreWorkspaceLock.workspaceRootName,
    RestoreWorkspaceLock.completedRunsDirectoryName,
    'run_$runId',
  ),
);

Future<void> _writeFixtureReceipt(Directory run, RestoreReceipt receipt) async {
  await File(
    p.join(
      run.path,
      'receipts',
      'receipt_${receipt.sequence.toString().padLeft(16, '0')}.json',
    ),
  ).writeAsString(jsonEncode(receipt.toJson()), flush: true);
}

Future<PreparedRestoreBundle> _prepareV130Bundle({
  required Directory root,
  required Directory appData,
  required bool includeFiles,
}) async {
  final current = await _prepareBundle(
    root: root,
    appData: appData,
    directoryName: 'v130_source',
    includeFiles: includeFiles,
  );
  // v1.3.0 persisted version 2, without an assetRoots declaration. Its
  // receipt format is unchanged; bind the fixture receipt to the old bytes.
  final manifestFile = File(
    p.join(current.candidateDirectory.path, 'manifest.json'),
  );
  final manifest = jsonDecode(await manifestFile.readAsString()) as Map;
  manifest['formatVersion'] = 2;
  manifest.remove('assetRoots');
  final bytes = utf8.encode(jsonEncode(manifest));
  await manifestFile.writeAsBytes(bytes, flush: true);
  final receipt = RestoreReceipt.prepared(
    runId: current.runId,
    createdAtUtc: current.receipt.createdAtUtc,
    restoreFiles: includeFiles,
    candidateManifestSha256: sha256.convert(bytes).toString(),
  );
  await _writeFixtureReceipt(current.workspace, receipt);
  await File(
    p.join(
      current.workspace.parent.path,
      RestoreWorkspaceLock.activeRunFileName,
    ),
  ).rename(
    p.join(
      current.workspace.parent.path,
      RestoreWorkspaceLock.publishingRunFileName,
    ),
  );
  return PreparedRestoreBundle(
    runId: current.runId,
    workspace: current.workspace,
    candidateDirectory: current.candidateDirectory,
    receipt: receipt,
  );
}

Future<List<int>> _interruptV130Cutover({
  required PreparedRestoreBundle prepared,
  required Directory appData,
  required String phase,
}) async {
  final liveDatabase = File(p.join(appData.path, 'kelivo.db'));
  final liveUpload = Directory(p.join(appData.path, 'upload'));
  final previous = Directory(
    p.join(
      prepared.workspace.path,
      phase == 'preserving' ? 'previous.pending' : 'previous',
    ),
  );
  await Directory(p.join(previous.path, 'database')).create(recursive: true);
  // Frozen v1.3.0 previous schema: entries have bytes/sha256 directly.
  final payload = {
    'format': 'kelivo.restore-previous-plan',
    'formatVersion': 2,
    'runId': prepared.runId,
    'preparedReceiptChecksum': prepared.receipt.checksum,
    'candidateManifestSha256': prepared.receipt.candidateManifestSha256,
    'selectedComponents': ['database', 'assets'],
    'createdAtUtc': prepared.receipt.createdAtUtc.toIso8601String(),
    'database': {
      'state': 'file',
      'path': 'database/kelivo.db',
      'descriptor': await _descriptor(liveDatabase),
    },
    'assets': {
      'roots': {
        for (final root in _v130AssetRoots)
          root: root == 'upload' ? 'directory' : 'missing',
      },
      'entries': {
        'upload/old.txt': await _descriptor(
          File(p.join(liveUpload.path, 'old.txt')),
        ),
      },
    },
  };
  final bytes = utf8.encode(
    jsonEncode({
      ...payload,
      'checksum': sha256.convert(utf8.encode(jsonEncode(payload))).toString(),
    }),
  );
  await File(
    p.join(previous.path, 'manifest.json'),
  ).writeAsBytes(bytes, flush: true);
  await liveUpload.rename(p.join(previous.path, 'upload'));
  if (phase == 'preserving') return bytes;
  final oldDatabase = File(p.join(previous.path, 'database', 'kelivo.db'));
  await liveDatabase.rename(oldDatabase.path);
  if (phase == 'preserved') return bytes;
  var receipt = prepared.receipt.advance(
    RestoreReceiptState.oldRenamed,
    previousManifestSha256: sha256.convert(bytes).toString(),
  );
  await _writeFixtureReceipt(prepared.workspace, receipt);
  final newDatabase = File(
    p.join(prepared.candidateDirectory.path, 'database', 'kelivo.db'),
  );
  await newDatabase.rename(liveDatabase.path);
  if (phase == 'installing') return bytes;
  for (final root in _v130AssetRoots) {
    await Directory(
      p.join(prepared.candidateDirectory.path, root),
    ).rename(p.join(appData.path, root));
  }
  receipt = receipt.advance(RestoreReceiptState.newInstalled);
  await _writeFixtureReceipt(prepared.workspace, receipt);
  if (phase == 'installed') return bytes;
  if (phase == 'rollingBack' || phase == 'rolledBack') {
    receipt = receipt.advance(RestoreReceiptState.rollingBack);
    await _writeFixtureReceipt(prepared.workspace, receipt);
    await liveDatabase.rename(newDatabase.path);
    await oldDatabase.rename(liveDatabase.path);
    if (phase == 'rollingBack') return bytes;
    for (final root in _v130AssetRoots) {
      await Directory(
        p.join(appData.path, root),
      ).rename(p.join(prepared.candidateDirectory.path, root));
    }
    await Directory(p.join(previous.path, 'upload')).rename(liveUpload.path);
    receipt = receipt.advance(RestoreReceiptState.rolledBack);
  } else {
    receipt = receipt.advance(RestoreReceiptState.verified);
    await _writeFixtureReceipt(prepared.workspace, receipt);
    if (phase == 'verified') return bytes;
    receipt = receipt.advance(RestoreReceiptState.committed);
  }
  await _writeFixtureReceipt(prepared.workspace, receipt);
  return bytes;
}

Future<PreparedRestoreBundle> _prepareBundle({
  required Directory root,
  required Directory appData,
  required String directoryName,
  required bool includeFiles,
}) async {
  final extracted = Directory(p.join(root.path, directoryName));
  await extracted.create();
  final settings = File(p.join(extracted.path, 'settings.json'));
  await settings.writeAsString('{"theme":"new"}', flush: true);
  final database = File(p.join(extracted.path, 'database', 'kelivo.db'));
  await database.parent.create(recursive: true);
  await _createDatabase(database, conversationId: 'new');
  final databaseInfo = await ChatDatabaseRepository.prepareSnapshotForRestore(
    database,
  );
  final entries = <String, dynamic>{
    'settings.json': await _descriptor(settings),
    'database/kelivo.db': await _descriptor(database),
  };
  if (includeFiles) {
    final upload = File(p.join(extracted.path, 'upload', 'new.txt'));
    await upload.parent.create();
    await upload.writeAsString('new asset', flush: true);
    entries['upload/new.txt'] = await _descriptor(upload);
  }
  final manifest = File(p.join(extracted.path, 'manifest.json'));
  await manifest.writeAsString(
    jsonEncode({
      'format': 'kelivo-backup',
      'formatVersion': 2,
      'payloadKind': 'sqlite',
      'createdAtUtc': '2026-07-09T00:00:00.000Z',
      'appVersion': 'test',
      'includeChats': true,
      'includeFiles': includeFiles,
      'secretsIncluded': true,
      'database': {
        'entry': 'database/kelivo.db',
        'schemaVersion': databaseInfo.schemaVersion,
        'conversationCount': databaseInfo.conversationCount,
        'messageCount': databaseInfo.messageCount,
      },
      'entries': entries,
    }),
    flush: true,
  );
  return RestoreBundlePreparation.prepare(
    appDataDirectory: appData,
    extractedDirectory: extracted,
    sourceManifestSha256: (await sha256.bind(manifest.openRead()).first)
        .toString(),
    bundleIncludesChats: true,
    bundleIncludesFiles: includeFiles,
    restoreChats: true,
    restoreFiles: includeFiles,
    createdAtUtc: DateTime.utc(2026, 7, 9, 12),
  );
}

Future<void> _createDatabase(
  File file, {
  required String conversationId,
}) async {
  final repository = ChatDatabaseRepository.open(file: file);
  try {
    await repository.ensureReady();
    await repository.putMigrationBatch(
      conversations: [Conversation(id: conversationId, title: conversationId)],
      messages: const [],
      toolEventsByMessageId: const {},
      geminiSignaturesByMessageId: const {},
    );
    await repository.markMigrationComplete();
    await repository.checkpoint();
  } finally {
    await repository.close();
  }
}

Future<Map<String, dynamic>> _descriptor(File file) async => {
  'bytes': await file.length(),
  'sha256': (await sha256.bind(file.openRead()).first).toString(),
};

Future<List<String>> _conversationIds(File file) async {
  final database = sqlite.sqlite3.open(
    file.path,
    mode: sqlite.OpenMode.readOnly,
  );
  try {
    return database
        .select('SELECT id FROM conversation_rows ORDER BY id;')
        .map((row) => row['id'] as String)
        .toList(growable: false);
  } finally {
    database.close();
  }
}

final class _ThrowAfterCandidateDatabaseRename implements RestoreDurability {
  _ThrowAfterCandidateDatabaseRename({
    required this.appDataDirectory,
    required this.delegate,
  });

  final Directory appDataDirectory;
  final RestoreDurability delegate;
  var _didThrow = false;

  @override
  Future<void> renameAndSync({
    required FileSystemEntity source,
    required String targetPath,
  }) async {
    await delegate.renameAndSync(source: source, targetPath: targetPath);
    if (!_didThrow &&
        p.basename(source.path) == 'kelivo.db' &&
        p.basename(p.dirname(source.path)) == 'database' &&
        p.equals(targetPath, p.join(appDataDirectory.path, 'kelivo.db')) &&
        source.path.contains('${p.separator}candidate${p.separator}')) {
      _didThrow = true;
      throw StateError('injected_after_candidate_database_rename');
    }
  }

  @override
  Future<void> restrictDirectory(Directory directory) =>
      delegate.restrictDirectory(directory);

  @override
  Future<void> restrictFile(File file) => delegate.restrictFile(file);

  @override
  Future<void> syncDirectory(Directory directory, {bool fullBarrier = false}) =>
      delegate.syncDirectory(directory, fullBarrier: fullBarrier);

  @override
  Future<void> syncFile(File file, {bool fullBarrier = false}) =>
      delegate.syncFile(file, fullBarrier: fullBarrier);
}

final class _ThrowAfterRunArchiveRename implements RestoreDurability {
  _ThrowAfterRunArchiveRename({required this.runId, required this.delegate});

  final String runId;
  final RestoreDurability delegate;
  var _didThrow = false;

  @override
  Future<void> renameAndSync({
    required FileSystemEntity source,
    required String targetPath,
  }) async {
    await delegate.renameAndSync(source: source, targetPath: targetPath);
    if (!_didThrow &&
        p.basename(source.path) == 'run_$runId' &&
        p.basename(p.dirname(targetPath)) ==
            RestoreWorkspaceLock.completedRunsDirectoryName) {
      _didThrow = true;
      throw StateError('injected_after_run_archive_rename');
    }
  }

  @override
  Future<void> restrictDirectory(Directory directory) =>
      delegate.restrictDirectory(directory);

  @override
  Future<void> restrictFile(File file) => delegate.restrictFile(file);

  @override
  Future<void> syncDirectory(Directory directory, {bool fullBarrier = false}) =>
      delegate.syncDirectory(directory, fullBarrier: fullBarrier);

  @override
  Future<void> syncFile(File file, {bool fullBarrier = false}) =>
      delegate.syncFile(file, fullBarrier: fullBarrier);
}
