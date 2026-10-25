import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/backup_scope.dart';
import 'package:Kelivo/core/services/backup/restore_bundle_preparation.dart';
import 'package:Kelivo/core/services/backup/restore_cutover_executor.dart';
import 'package:Kelivo/core/services/backup/restore_durability.dart';
import 'package:Kelivo/core/services/backup/restore_previous_store.dart';
import 'package:Kelivo/core/services/backup/restore_receipt.dart';
import 'package:Kelivo/core/services/backup/restore_workspace_lock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RestoreCutoverExecutor', () {
    late Directory root;
    late Directory appData;

    setUp(() async {
      root = await Directory.systemTemp.createTemp(
        'kelivo_restore_cutover_test_',
      );
      appData = Directory(p.join(root.path, 'app_data'));
      await appData.create();
    });

    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    test('commits database and assets in the first startup pass', () async {
      final liveDatabase = File(p.join(appData.path, 'kelivo.db'));
      await _createDatabase(liveDatabase, conversationId: 'old');
      final oldUpload = File(p.join(appData.path, 'upload', 'old.txt'));
      await oldUpload.parent.create();
      await oldUpload.writeAsString('old asset', flush: true);
      await Directory(p.join(appData.path, 'images')).create();
      final prepared = await _prepareBundle(
        root: root,
        appData: appData,
        directoryName: 'commit_source',
        includeFiles: true,
      );
      final workspaceLock = RestoreWorkspaceLock(appDataDirectory: appData);
      final executor = RestoreCutoverExecutor(
        appDataDirectory: appData,
        runId: prepared.runId,
        workspaceLock: workspaceLock,
      );

      final terminal = await workspaceLock.synchronized(() async {
        final result = await executor.executeWhileWorkspaceLocked(
          observedMarkerFileName: RestoreWorkspaceLock.activeRunFileName,
        );
        return executor.revalidateTerminalWhileWorkspaceLocked(result);
      });

      expect(terminal.state, RestoreReceiptState.committed);
      expect(await _conversationIds(liveDatabase), ['new']);
      expect(
        await File(p.join(appData.path, 'upload', 'new.txt')).readAsString(),
        'new asset',
      );
      expect(await oldUpload.exists(), isFalse);
      final previous = Directory(
        p.join(
          prepared.workspace.path,
          RestorePreviousStore.previousDirectoryName,
        ),
      );
      expect(
        await _conversationIds(
          File(p.join(previous.path, 'database', 'kelivo.db')),
        ),
        ['old'],
      );
      expect(
        await File(p.join(previous.path, 'settings.json')).exists(),
        isFalse,
      );
    });

    test(
      'partial startup cutover keeps the unselected workspace in place',
      () async {
        final liveDatabase = File(p.join(appData.path, 'kelivo.db'));
        await _createDatabase(liveDatabase, conversationId: 'old');
        final workspace = Directory(
          p.join(appData.path, 'workspaces', 'local'),
        );
        final empty = Directory(p.join(workspace.path, 'empty'));
        await empty.create(recursive: true);
        final script = File(p.join(workspace.path, 'run.sh'));
        await script.writeAsString('before staging');
        if (!Platform.isWindows) {
          expect(
            (await Process.run('chmod', ['755', script.path])).exitCode,
            0,
          );
          await Link(p.join(workspace.path, 'script-link')).create('run.sh');
        }
        final mode = (await script.stat()).mode;
        final prepared = await _prepareBundle(
          root: root,
          appData: appData,
          directoryName: 'partial_source',
          includeFiles: true,
          scope: const BackupScope(excluded: {BackupCategory.workspaces}),
        );
        await script.writeAsString('after staging');
        final lock = RestoreWorkspaceLock(appDataDirectory: appData);
        final executor = RestoreCutoverExecutor(
          appDataDirectory: appData,
          runId: prepared.runId,
          workspaceLock: lock,
        );
        final terminal = await lock.synchronized(() async {
          final result = await executor.executeWhileWorkspaceLocked(
            observedMarkerFileName: RestoreWorkspaceLock.activeRunFileName,
          );
          return executor.revalidateTerminalWhileWorkspaceLocked(result);
        });
        expect(terminal.state, RestoreReceiptState.committed);
        expect(await _conversationIds(liveDatabase), ['new']);
        expect(await empty.exists(), isTrue);
        expect(await script.readAsString(), 'after staging');
        expect((await script.stat()).mode, mode);
        expect(
          await Directory(
            p.join(prepared.candidateDirectory.path, 'workspaces'),
          ).exists(),
          isFalse,
        );
        expect(
          await Directory(
            p.join(prepared.workspace.path, 'previous', 'workspaces'),
          ).exists(),
          isFalse,
        );
      },
    );

    test('commits when the previous database was absent', () async {
      final prepared = await _prepareBundle(
        root: root,
        appData: appData,
        directoryName: 'missing_live_source',
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
      expect(await _conversationIds(File(p.join(appData.path, 'kelivo.db'))), [
        'new',
      ]);
      final manifest =
          (jsonDecode(
                    await File(
                      p.join(
                        prepared.workspace.path,
                        RestorePreviousStore.previousDirectoryName,
                        RestorePreviousStore.manifestFileName,
                      ),
                    ).readAsString(),
                  )
                  as Map)
              .cast<String, dynamic>();
      expect((manifest['database'] as Map)['state'], 'missing');
    });

    test('rolls back an interrupted candidate database install', () async {
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
      final workspaceLock = RestoreWorkspaceLock(
        appDataDirectory: appData,
        durability: _ThrowAfterRestoreRename(
          appDataDirectory: appData,
          delegate: RestorePlatformDurability(),
        ),
      );
      final executor = RestoreCutoverExecutor(
        appDataDirectory: appData,
        runId: prepared.runId,
        workspaceLock: workspaceLock,
        durability: workspaceLock.durability,
      );

      final terminal = await workspaceLock.synchronized(
        () => executor.executeWhileWorkspaceLocked(
          observedMarkerFileName: RestoreWorkspaceLock.activeRunFileName,
        ),
      );

      expect(terminal.state, RestoreReceiptState.rolledBack);
      expect(await _conversationIds(liveDatabase), ['old']);
      expect(await oldUpload.readAsString(), 'old asset');
      expect(
        await _conversationIds(
          File(
            p.join(prepared.candidateDirectory.path, 'database', 'kelivo.db'),
          ),
        ),
        ['new'],
      );
      expect(
        await File(
          p.join(
            prepared.workspace.path,
            RestorePreviousStore.previousDirectoryName,
            'settings.json',
          ),
        ).exists(),
        isFalse,
      );
    });

    for (final scenario in ['commit', 'rollback', 'resume']) {
      final rollback = scenario == 'rollback';
      final resume = scenario == 'resume';
      test(
        'preserves local links and IPC entries through $scenario and restart',
        () async {
          final liveDatabase = File(p.join(appData.path, 'kelivo.db'));
          await _createDatabase(liveDatabase, conversationId: 'old');
          final workspace = Directory(
            p.join(appData.path, 'workspaces', 'local'),
          );
          await workspace.create(recursive: true);
          await File(
            p.join(workspace.path, 'run.sh'),
          ).writeAsString('original');
          final outside = File(p.join(root.path, 'outside.txt'));
          await outside.writeAsString('outside');
          final links = {
            'relative': 'run.sh',
            'broken': 'missing',
            'cycle': 'cycle',
            'external-file': outside.path,
            'external-directory': root.path,
          };
          for (final entry in links.entries) {
            await Link(p.join(workspace.path, entry.key)).create(entry.value);
          }
          expect(
            (await Process.run('mkfifo', [
              p.join(workspace.path, 'pipe'),
            ])).exitCode,
            0,
          );
          // Bind at a short path to stay within the Unix socket path limit.
          final socketRoot = await Directory.systemTemp.createTemp('ks_');
          final socketPath = p.join(socketRoot.path, 's');
          final socket = await ServerSocket.bind(
            InternetAddress(socketPath, type: InternetAddressType.unix),
            0,
          );
          addTearDown(() async {
            await socket.close();
            await socketRoot.delete(recursive: true);
          });
          await File(socketPath).rename(p.join(workspace.path, 'socket'));

          final prepared = await _prepareBundle(
            root: root,
            appData: appData,
            directoryName: 'special_source',
            includeFiles: true,
          );
          final durability = rollback || resume
              ? _ThrowAfterRestoreRename(
                  appDataDirectory: appData,
                  delegate: RestorePlatformDurability(),
                  afterPreviousAssets: resume,
                )
              : RestorePlatformDurability();
          final lock = RestoreWorkspaceLock(
            appDataDirectory: appData,
            durability: durability,
          );
          var executor = RestoreCutoverExecutor(
            appDataDirectory: appData,
            runId: prepared.runId,
            workspaceLock: lock,
            durability: durability,
          );
          if (resume) {
            await expectLater(
              lock.synchronized(
                () => executor.executeWhileWorkspaceLocked(
                  observedMarkerFileName:
                      RestoreWorkspaceLock.activeRunFileName,
                ),
              ),
              throwsA(
                isA<StateError>().having(
                  (error) => error.message,
                  'message',
                  'injected_after_restore_rename',
                ),
              ),
            );
            expect(await workspace.exists(), isFalse);
            expect(await _conversationIds(liveDatabase), ['old']);
            executor = RestoreCutoverExecutor(
              appDataDirectory: appData,
              runId: prepared.runId,
              workspaceLock: lock,
            );
          }
          final terminal = await lock.synchronized(
            () => executor.executeWhileWorkspaceLocked(
              observedMarkerFileName: resume
                  ? RestoreWorkspaceLock.publishingRunFileName
                  : RestoreWorkspaceLock.activeRunFileName,
            ),
          );
          expect(
            terminal.state,
            rollback
                ? RestoreReceiptState.rolledBack
                : RestoreReceiptState.committed,
          );
          expect(await _conversationIds(liveDatabase), [
            rollback ? 'old' : 'new',
          ]);
          final preserved = rollback
              ? workspace
              : Directory(
                  p.join(
                    prepared.workspace.path,
                    'previous',
                    'workspaces',
                    'local',
                  ),
                );
          for (final entry in links.entries) {
            final path = p.join(preserved.path, entry.key);
            expect(
              await FileSystemEntity.type(path, followLinks: false),
              FileSystemEntityType.link,
            );
            expect(await Link(path).target(), entry.value);
          }
          expect(
            await File(p.join(preserved.path, 'run.sh')).readAsString(),
            'original',
          );
          expect(
            await FileSystemEntity.type(
              p.join(preserved.path, 'pipe'),
              followLinks: false,
            ),
            FileSystemEntityType.pipe,
          );
          expect(
            await FileSystemEntity.type(
              p.join(preserved.path, 'socket'),
              followLinks: false,
            ),
            FileSystemEntityType.unixDomainSock,
          );
          expect(await outside.readAsString(), 'outside');

          // A fresh executor must validate only the link, never its target.
          await outside.writeAsString('changed externally');
          final restarted = RestoreCutoverExecutor(
            appDataDirectory: appData,
            runId: prepared.runId,
            workspaceLock: lock,
          );
          final revalidated = await lock.synchronized(
            () => restarted.revalidateTerminalWhileWorkspaceLocked(terminal),
          );
          expect(revalidated.state, terminal.state);
          expect(await outside.readAsString(), 'changed externally');

          await Link(
            p.join(preserved.path, 'relative'),
          ).update('changed-target');
          await expectLater(
            lock.synchronized(
              () => restarted.revalidateTerminalWhileWorkspaceLocked(terminal),
            ),
            throwsA(isA<StateError>()),
          );
        },
        skip: Platform.isWindows,
      );
    }

    test('keeps a divergent committed terminal fail-closed', () async {
      final liveDatabase = File(p.join(appData.path, 'kelivo.db'));
      await _createDatabase(liveDatabase, conversationId: 'old');
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
      late RestoreReceipt terminal;
      await workspaceLock.synchronized(() async {
        terminal = await executor.executeWhileWorkspaceLocked(
          observedMarkerFileName: RestoreWorkspaceLock.activeRunFileName,
        );
      });
      final database = sqlite.sqlite3.open(liveDatabase.path);
      try {
        database.execute(
          "UPDATE conversation_rows SET title = 'tampered' WHERE id = 'new';",
        );
      } finally {
        database.close();
      }

      await expectLater(
        workspaceLock.synchronized(
          () => executor.revalidateTerminalWhileWorkspaceLocked(terminal),
        ),
        throwsA(isA<StateError>()),
      );
      expect(
        (await executor.receiptStore.readLatest())?.state,
        RestoreReceiptState.committed,
      );
    });
  });
}

Future<PreparedRestoreBundle> _prepareBundle({
  required Directory root,
  required Directory appData,
  required String directoryName,
  required bool includeFiles,
  BackupScope scope = const BackupScope(),
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
    scope: scope,
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

final class _ThrowAfterRestoreRename implements RestoreDurability {
  _ThrowAfterRestoreRename({
    required this.appDataDirectory,
    required this.delegate,
    this.afterPreviousAssets = false,
  });

  final Directory appDataDirectory;
  final RestoreDurability delegate;
  final bool afterPreviousAssets;
  var _didThrow = false;

  @override
  Future<void> renameAndSync({
    required FileSystemEntity source,
    required String targetPath,
  }) async {
    await delegate.renameAndSync(source: source, targetPath: targetPath);
    final movedPreviousAssets =
        p.equals(source.path, p.join(appDataDirectory.path, 'workspaces')) &&
        p.basename(p.dirname(targetPath)) ==
            RestorePreviousStore.pendingDirectoryName;
    final installedDatabase =
        p.basename(source.path) == 'kelivo.db' &&
        p.basename(source.parent.path) == 'database' &&
        p.equals(targetPath, p.join(appDataDirectory.path, 'kelivo.db')) &&
        source.path.contains('${p.separator}candidate${p.separator}');
    if (!_didThrow &&
        (afterPreviousAssets ? movedPreviousAssets : installedDatabase)) {
      _didThrow = true;
      throw StateError('injected_after_restore_rename');
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
