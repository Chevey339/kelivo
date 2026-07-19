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

      final terminal = await RestoreStartupGate.recoverAndRequireBusinessReady(
        appDataDirectory: appData,
        durability: durability,
      );

      expect(terminal?.state, RestoreReceiptState.rolledBack);
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
