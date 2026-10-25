import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:Kelivo/core/database/database_family_preserver.dart';
import 'package:Kelivo/core/database/database_installation_gate.dart';
import 'package:Kelivo/core/database/empty_database_recovery_guard.dart';
import 'package:Kelivo/core/database/startup_recovery_service.dart';
import 'package:Kelivo/core/services/backup/data_sync.dart';
import 'package:Kelivo/core/services/backup/restore_durability.dart';
import 'package:Kelivo/core/services/backup/restore_receipt.dart';
import 'package:Kelivo/core/services/backup/restore_startup_gate.dart';
import 'package:Kelivo/core/services/backup/restore_workspace_lock.dart';

import '../../support/recovery_snapshot_fixture.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.root);
  final Directory root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root.path;
  @override
  Future<String?> getApplicationSupportPath() async => root.path;
  @override
  Future<String?> getTemporaryPath() async => '${root.path}/tmp';
}

class _Faults implements RestoreDurability {
  _Faults({this.beforeRename, this.afterRename, this.afterSync});
  final void Function(FileSystemEntity, String)? beforeRename;
  final void Function(FileSystemEntity, String)? afterRename;
  final void Function(File)? afterSync;
  final delegate = RestorePlatformDurability();
  @override
  Future<void> restrictFile(File file) => delegate.restrictFile(file);
  @override
  Future<void> restrictDirectory(Directory dir) =>
      delegate.restrictDirectory(dir);
  @override
  Future<void> syncDirectory(Directory dir, {bool fullBarrier = false}) =>
      delegate.syncDirectory(dir, fullBarrier: fullBarrier);
  @override
  Future<void> syncFile(File file, {bool fullBarrier = false}) async {
    await delegate.syncFile(file, fullBarrier: fullBarrier);
    afterSync?.call(file);
  }

  @override
  Future<void> renameAndSync({
    required FileSystemEntity source,
    required String targetPath,
  }) async {
    beforeRename?.call(source, targetPath);
    await delegate.renameAndSync(source: source, targetPath: targetPath);
    afterRename?.call(source, targetPath);
  }
}

Future<Map<String, int>> _hashCounts(Iterable<File> files) async {
  final counts = <String, int>{};
  for (final file in files) {
    final hash = sha256.convert(await file.readAsBytes()).toString();
    counts[hash] = (counts[hash] ?? 0) + 1;
  }
  return counts;
}

Future<Map<String, int>> _brokenPreservation(
  Directory root,
  String damage,
) async {
  await DatabaseInstallationGate.ensureReady(appDataDirectory: root);
  final live = File('${root.path}/kelivo.db');
  final producer = await Directory.systemTemp.createTemp(
    'kelivo-wal-producer-',
  );
  try {
    final producerFile = await live.copy('${producer.path}/kelivo.db');
    final database = sqlite.sqlite3.open(producerFile.path);
    try {
      database.execute('PRAGMA journal_mode=WAL');
      database.execute(
        "INSERT INTO conversation_rows(id,title,created_at,updated_at) VALUES('old','Old chat',1,1)",
      );
      for (final suffix in ['', '-wal', '-shm']) {
        await File('${producerFile.path}$suffix').copy('${live.path}$suffix');
      }
    } finally {
      database.close();
    }
  } finally {
    await producer.delete(recursive: true);
  }
  await expectLater(
    DatabaseFamilyPreserver.preserve(
      live,
      durability: _Faults(
        beforeRename: (_, target) {
          if (p.basename(target) == 'original-kelivo.db') {
            throw StateError('injected interruption');
          }
        },
      ),
    ),
    throwsStateError,
  );
  final copy = root.listSync().whereType<Directory>().singleWhere(
    (d) => DatabaseFamilyPreserver.isCopyDirectory(p.basename(d.path)),
  );
  final pending = File('${root.path}/${DatabaseFamilyPreserver.pendingName}');
  final manifest = File('${copy.path}/${DatabaseFamilyPreserver.manifestName}');
  switch (damage) {
    case 'pending':
      await pending.writeAsString('{broken pending');
    case 'manifest':
      await manifest.writeAsString('{broken manifest');
    case 'missing manifest':
      await manifest.delete();
  }
  return _hashCounts([
    for (final suffix in ['', '-wal', '-shm']) File('${live.path}$suffix'),
    pending,
    ...copy.listSync().whereType<File>(),
  ]);
}

Future<void> _expectEvidence(Directory root, Map<String, int> expected) async {
  final actual = await _hashCounts(
    root.listSync(recursive: true).whereType<File>(),
  );
  for (final entry in expected.entries) {
    expect(
      actual[entry.key] ?? 0,
      greaterThanOrEqualTo(entry.value),
      reason: 'Original evidence bytes must remain',
    );
  }
}

Future<void> _restore(Directory root, File snapshot) async {
  final before = await snapshot.readAsBytes();
  final inspected = await DataSync.inspectRecoverySnapshot(snapshot);
  expect(inspected.conversationCount, 2);
  expect(inspected.messageCount, 42);
  await DataSync.prepareStartupSnapshotRestore(
    appDataDirectory: root,
    snapshot: snapshot,
  );
  final outcome = await RestoreStartupGate.recoverAndRequireBusinessReady(
    appDataDirectory: root,
  );
  expect(outcome?.state, RestoreReceiptState.committed);
  await DatabaseInstallationGate.ensureReady(
    appDataDirectory: root,
    allowDatabaseIdentityChange: true,
  );
  final database = sqlite.sqlite3.open('${root.path}/kelivo.db');
  try {
    expect(
      database
          .select('SELECT COUNT(*) AS n FROM conversation_rows')
          .single['n'],
      2,
    );
    expect(
      database.select('SELECT COUNT(*) AS n FROM message_rows').single['n'],
      42,
    );
  } finally {
    database.close();
  }
  expect(await snapshot.readAsBytes(), before);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late PathProviderPlatform previousPaths;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('kelivo-broken-preservation-');
    previousPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(root);
    PackageInfo.setMockInitialValues(
      appName: 'Kelivo',
      packageName: 'Kelivo',
      version: '1.3.1',
      buildNumber: '80',
      buildSignature: 'test',
    );
  });
  tearDown(() async {
    PathProviderPlatform.instance = previousPaths;
    await root.delete(recursive: true);
  });

  for (final damage in ['pending', 'manifest', 'missing manifest']) {
    for (final restore in [false, true]) {
      test(
        'explicit ${restore ? 'snapshot restore' : 'reset'} escapes $damage damage and retains all evidence',
        () async {
          final evidence = await _brokenPreservation(root, damage);
          await expectLater(
            RestoreStartupGate.recoverAndRequireBusinessReady(
              appDataDirectory: root,
            ),
            throwsA(anything),
          );
          await _expectEvidence(root, evidence);
          if (restore) {
            final snapshot = await writeRecoverySnapshot(
              File('${root.path}/snapshots/kelivo-snapshot-good.zip'),
            );
            await _restore(root, snapshot);
          } else {
            await StartupRecoveryService.reset(appDataDirectory: root);
            final receipt = await DatabaseInstallationGate.ensureReady(
              appDataDirectory: root,
            );
            await EmptyDatabaseRecoveryGuard.check(
              appDataDirectory: root,
              databaseId: receipt.databaseId,
            );
          }
          await _expectEvidence(root, evidence);
        },
      );
    }
  }

  for (final point in ['phase', 'pending archive', 'main retired']) {
    test(
      'interruption after $point stays blocked and can switch from reset to snapshot recovery',
      () async {
        final evidence = await _brokenPreservation(root, 'manifest');
        var interrupted = false;
        void stop() {
          interrupted = true;
          throw StateError('injected recovery interruption');
        }

        final durability = _Faults(
          afterSync: (file) {
            if (point == 'phase' &&
                p.basename(file.path) ==
                    RestoreWorkspaceLock.snapshotRecoveryMarkerName &&
                file.readAsStringSync() ==
                    DatabaseFamilyPreserver.failedRecoveryPhase) {
              stop();
            }
          },
          afterRename: (source, target) {
            if (point == 'pending archive' &&
                p.basename(source.path) ==
                    DatabaseFamilyPreserver.pendingName) {
              stop();
            }
            if (point == 'main retired' &&
                p.basename(target) == 'original-kelivo.db') {
              stop();
            }
          },
        );
        await expectLater(
          StartupRecoveryService.reset(
            appDataDirectory: root,
            durability: durability,
          ),
          throwsStateError,
        );
        expect(interrupted, isTrue);
        await expectLater(
          RestoreStartupGate.recoverAndRequireBusinessReady(
            appDataDirectory: root,
          ),
          throwsA(anything),
        );
        await _expectEvidence(root, evidence);
        final snapshot = await writeRecoverySnapshot(
          File('${root.path}/snapshots/kelivo-snapshot-retry.zip'),
        );
        await _restore(root, snapshot);
        await _expectEvidence(root, evidence);
      },
    );
  }

  test('a non-UTF8 recovery barrier does not trap explicit recovery', () async {
    final evidence = await _brokenPreservation(root, 'manifest');
    await File(
      '${root.path}/${RestoreWorkspaceLock.snapshotRecoveryMarkerName}',
    ).writeAsBytes([255, 254]);
    await StartupRecoveryService.reset(appDataDirectory: root);
    await DatabaseInstallationGate.ensureReady(appDataDirectory: root);
    await _expectEvidence(root, evidence);
  });

  test(
    'healthy startup snapshot recovery still rolls back to the live database',
    () async {
      await DatabaseInstallationGate.ensureReady(appDataDirectory: root);
      final live = File('${root.path}/kelivo.db');
      final old = sqlite.sqlite3.open(live.path);
      old.execute(
        "INSERT INTO conversation_rows(id,title,created_at,updated_at) VALUES('old','Original chat',1,1)",
      );
      old.close();
      final snapshot = await writeRecoverySnapshot(
        File('${root.path}/snapshots/kelivo-snapshot-good.zip'),
      );
      await DataSync.prepareStartupSnapshotRestore(
        appDataDirectory: root,
        snapshot: snapshot,
      );
      expect(await live.exists(), isTrue);
      var failed = false;
      final outcome = await RestoreStartupGate.recoverAndRequireBusinessReady(
        appDataDirectory: root,
        durability: _Faults(
          afterRename: (source, target) {
            if (!failed &&
                target == live.path &&
                source.path.contains('${p.separator}candidate${p.separator}')) {
              failed = true;
              throw StateError('injected candidate install failure');
            }
          },
        ),
      );
      expect(failed, isTrue);
      expect(outcome?.state, RestoreReceiptState.rolledBack);
      final restored = sqlite.sqlite3.open(live.path);
      try {
        expect(
          restored.select('SELECT id FROM conversation_rows').single['id'],
          'old',
        );
      } finally {
        restored.close();
      }
    },
  );
}
