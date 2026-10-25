import 'dart:io';
import 'package:Kelivo/core/database/startup_failure_report.dart';
import 'package:Kelivo/core/database/startup_recovery_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:Kelivo/core/database/database_family_preserver.dart';
import 'package:Kelivo/core/database/database_installation_gate.dart';
import 'package:Kelivo/core/services/backup/data_sync.dart';
import 'package:Kelivo/core/services/backup/local_copy_catalog.dart';
import 'package:Kelivo/core/services/backup/restore_durability.dart';

class _InterruptRetirement implements RestoreDurability {
  final delegate = RestorePlatformDurability();
  @override
  Future<void> restrictFile(File f) => delegate.restrictFile(f);
  @override
  Future<void> restrictDirectory(Directory d) => delegate.restrictDirectory(d);
  @override
  Future<void> syncDirectory(Directory d, {bool fullBarrier = false}) =>
      delegate.syncDirectory(d, fullBarrier: fullBarrier);
  @override
  Future<void> syncFile(File f, {bool fullBarrier = false}) =>
      delegate.syncFile(f, fullBarrier: fullBarrier);
  @override
  Future<void> renameAndSync({
    required FileSystemEntity source,
    required String targetPath,
  }) async {
    await delegate.renameAndSync(source: source, targetPath: targetPath);
    if (p.basename(targetPath) == 'original-kelivo.db') {
      throw StateError('injected termination');
    }
  }
}

void main() {
  late Directory root;
  setUp(
    () async =>
        root = await Directory.systemTemp.createTemp('family-preservation-'),
  );
  tearDown(() async => root.delete(recursive: true));

  test(
    'interrupted retirement retains committed WAL with its main database and resumes before admission',
    () async {
      final producer = await root.createTemp('producer-');
      final producerFile = File(p.join(producer.path, 'kelivo.db'));
      final database = sqlite.sqlite3.open(producerFile.path);
      database.execute('CREATE TABLE evidence (value TEXT);');
      database.execute('PRAGMA journal_mode=WAL;');
      database.execute("INSERT INTO evidence VALUES ('committed in WAL');");
      final source = File(p.join(root.path, 'kelivo.db'));
      for (final suffix in ['', '-wal', '-shm']) {
        await File('${producerFile.path}$suffix').copy('${source.path}$suffix');
      }
      database.close();
      final originalMain = await source.readAsBytes();
      final originalWal = await File('${source.path}-wal').readAsBytes();
      final originalShm = await File('${source.path}-shm').readAsBytes();
      await StartupFailureEnvironment.collect(appDataDirectory: root);
      await StartupFailureEnvironment.collect(
        appDataDirectory: root,
        inspectDatabase: false,
      );
      await StartupDiagnosticsService.checkIntegrity(appDataDirectory: root);
      expect(await source.readAsBytes(), originalMain);
      expect(await File('${source.path}-wal').readAsBytes(), originalWal);
      expect(await File('${source.path}-shm').readAsBytes(), originalShm);
      await expectLater(
        DatabaseFamilyPreserver.preserve(
          source,
          durability: _InterruptRetirement(),
        ),
        throwsStateError,
      );
      expect(await source.exists(), isFalse);
      expect(await File('${source.path}-wal').exists(), isTrue);
      final copies = await LocalCopyCatalog(appDataDirectory: root).list();
      expect(copies, hasLength(1));
      final copy = copies.single.file;
      expect(await copy.readAsBytes(), originalMain);
      expect(await File('${copy.path}-wal').readAsBytes(), originalWal);
      // Admission replays the pending retirement and refuses to silently build
      // an empty database beside the retained history.
      await expectLater(
        DatabaseInstallationGate.ensureReady(appDataDirectory: root),
        throwsStateError,
      );
      expect(await File('${source.path}-wal').exists(), isFalse);
      expect(
        await File(
          p.join(root.path, DatabaseFamilyPreserver.pendingName),
        ).exists(),
        isFalse,
      );
      final reading = await root.createTemp('reading-');
      for (final suffix in ['', '-wal', '-shm']) {
        await File(
          '${copy.path}$suffix',
        ).copy(p.join(reading.path, 'kelivo.db$suffix'));
      }
      final recovered = sqlite.sqlite3.open(p.join(reading.path, 'kelivo.db'));
      expect(
        recovered.select('SELECT value FROM evidence').single['value'],
        'committed in WAL',
      );
      recovered.close();
      expect(await copy.readAsBytes(), originalMain);
      expect(await File('${copy.path}-wal').readAsBytes(), originalWal);
      // A missing journal must fail validation, even when the main file opens.
      await File('${copy.path}-wal').rename('${copy.path}-wal-moved');
      await expectLater(
        DataSync.prepareRecoveryDatabaseArchive(copy),
        throwsStateError,
      );
    },
  );
}
