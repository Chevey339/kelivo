import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/database/database_installation_gate.dart';
import 'package:Kelivo/core/services/backup/local_snapshot_schedule.dart';
import 'package:Kelivo/core/services/backup/restore_workspace_lock.dart';
import 'package:Kelivo/core/services/storage/storage_usage_service.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;

  @override
  Future<String?> getApplicationSupportPath() async => path;

  @override
  Future<String?> getApplicationCachePath() async => p.join(path, 'cache');

  @override
  Future<String?> getTemporaryPath() async => p.join(path, 'tmp');
}

Future<void> _writeSizedFile(Directory root, String name, int size) async {
  final file = File(p.join(root.path, name));
  await file.parent.create(recursive: true);
  await file.writeAsBytes(List<int>.filled(size, 1), flush: true);
}

void _markMigrationComplete(Directory root) {
  final database = sqlite3.open(
    p.join(root.path, AppDatabase.databaseFileName),
  );
  try {
    database.execute(
      'CREATE TABLE IF NOT EXISTS chat_storage_meta_rows '
      '(key TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL);',
    );
    database.execute(
      'INSERT OR REPLACE INTO chat_storage_meta_rows (key, value) '
      'VALUES (?, ?);',
      [ChatStorageMetaKeys.hiveMigrationComplete, 'true'],
    );
  } finally {
    database.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late PathProviderPlatform previousPathProvider;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'kelivo_storage_usage_test_',
    );
    previousPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
  });

  tearDown(() async {
    PathProviderPlatform.instance = previousPathProvider;
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'chat records size uses SQLite files instead of legacy Hive files',
    () async {
      await _writeSizedFile(tempDir, AppDatabase.databaseFileName, 11);
      await _writeSizedFile(tempDir, '${AppDatabase.databaseFileName}-wal', 7);
      await _writeSizedFile(tempDir, '${AppDatabase.databaseFileName}-shm', 5);
      await _writeSizedFile(tempDir, 'conversations.hive', 100);
      await _writeSizedFile(tempDir, 'messages.hive', 200);
      await _writeSizedFile(tempDir, 'tool_events_v1.hive', 300);
      await _writeSizedFile(tempDir, 'messages.lock', 400);

      final report = await StorageUsageService.computeReport();
      final chat = report.categories.singleWhere(
        (category) => category.key == StorageUsageCategoryKey.chatData,
      );

      expect(chat.stats.bytes, 23);
      expect(chat.stats.fileCount, 3);
      expect(
        chat.subcategories.map((subcategory) => subcategory.id),
        containsAllInOrder(['sqlite_database', 'sqlite_wal', 'sqlite_shm']),
      );
      expect(
        chat.subcategories.map((subcategory) => p.basename(subcategory.path!)),
        containsAllInOrder([
          AppDatabase.databaseFileName,
          '${AppDatabase.databaseFileName}-wal',
          '${AppDatabase.databaseFileName}-shm',
        ]),
      );
      expect(report.totalBytes, 1023);
      expect(
        report.categories.where(
          (category) => category.key == StorageUsageCategoryKey.legacyChatData,
        ),
        isEmpty,
      );
    },
  );

  test(
    'migrated legacy chat data is clearable and disappears after cleanup',
    () async {
      _markMigrationComplete(tempDir);
      await _writeSizedFile(tempDir, 'conversations.hive', 100);
      await _writeSizedFile(tempDir, 'messages.hive', 200);
      await _writeSizedFile(tempDir, 'tool_events_v1.hive', 300);

      final before = await StorageUsageService.computeReport();
      final legacy = before.categories.singleWhere(
        (category) => category.key == StorageUsageCategoryKey.legacyChatData,
      );
      expect(legacy.stats.bytes, 600);
      expect(legacy.stats.fileCount, 3);
      expect(before.clearable.bytes, greaterThanOrEqualTo(600));

      await StorageUsageService.clearLegacyChatData();
      final after = await StorageUsageService.computeReport();

      expect(
        after.categories.where(
          (category) => category.key == StorageUsageCategoryKey.legacyChatData,
        ),
        isEmpty,
      );
    },
  );

  test(
    'cleanup gate reopens after a legacy backup restore and re-migration',
    () async {
      _markMigrationComplete(tempDir);
      await _writeSizedFile(tempDir, 'messages.hive', 200);
      await StorageUsageService.clearLegacyChatData();

      // Restoring a 1.1.17 backup brings the Hive files back and the
      // re-migration writes its receipt into a fresh database. Earlier
      // cleanup evidence must not lock the gate.
      await File(p.join(tempDir.path, AppDatabase.databaseFileName)).delete();
      _markMigrationComplete(tempDir);
      await _writeSizedFile(tempDir, 'messages.hive', 128);

      final again = await StorageUsageService.computeReport();
      final legacy = again.categories.singleWhere(
        (category) => category.key == StorageUsageCategoryKey.legacyChatData,
      );
      expect(legacy.stats.bytes, 128);
      expect(again.clearable.bytes, greaterThanOrEqualTo(128));

      await StorageUsageService.clearLegacyChatData();
      final after = await StorageUsageService.computeReport();
      expect(
        after.categories.where(
          (category) => category.key == StorageUsageCategoryKey.legacyChatData,
        ),
        isEmpty,
      );
      expect(File(p.join(tempDir.path, 'messages.hive')).existsSync(), isFalse);
    },
  );

  test('legacy cleanup refuses to run without a migration receipt', () async {
    await _writeSizedFile(tempDir, 'messages.hive', 64);

    await expectLater(
      StorageUsageService.clearLegacyChatData(),
      throwsA(isA<StateError>()),
    );
    expect(File(p.join(tempDir.path, 'messages.hive')).existsSync(), isTrue);
  });

  test(
    'chat records size works when only the main SQLite database exists',
    () async {
      await _writeSizedFile(tempDir, AppDatabase.databaseFileName, 19);

      final report = await StorageUsageService.computeReport();
      final chat = report.categories.singleWhere(
        (category) => category.key == StorageUsageCategoryKey.chatData,
      );

      expect(chat.stats.bytes, 19);
      expect(chat.stats.fileCount, 1);
      expect(chat.subcategories.single.id, 'sqlite_database');
      expect(
        p.basename(chat.subcategories.single.path!),
        AppDatabase.databaseFileName,
      );
    },
  );

  test('completed restore traces are clearable and then disappear', () async {
    const runId = '0123456789abcdef0123456789abcdef';
    final run = Directory(
      p.join(
        tempDir.path,
        RestoreWorkspaceLock.workspaceRootName,
        RestoreWorkspaceLock.completedRunsDirectoryName,
        'run_$runId',
      ),
    );
    await run.create(recursive: true);
    await _writeSizedFile(run, 'database.sqlite', 64);

    final before = await StorageUsageService.computeReport();
    final traces = before.categories.singleWhere(
      (category) => category.key == StorageUsageCategoryKey.restoreTraces,
    );
    expect(traces.stats.bytes, 64);
    expect(traces.stats.fileCount, 1);

    await StorageUsageService.clearRestoreTraces();
    final after = await StorageUsageService.computeReport();
    expect(
      after.categories.where(
        (category) => category.key == StorageUsageCategoryKey.restoreTraces,
      ),
      isEmpty,
    );
  });

  test(
    'set-aside databases are listed, clearable, and not swept as reclaimable',
    () async {
      const prefix =
          '${AppDatabase.databaseFileName}'
          '${DatabaseInstallationGate.displacedDatabasePrefix}';
      await _writeSizedFile(tempDir, '${prefix}0000000000000001', 96);
      await _writeSizedFile(tempDir, '${prefix}0000000000000001-wal', 32);

      final before = await StorageUsageService.computeReport();
      final displaced = before.categories.singleWhere(
        (category) =>
            category.key == StorageUsageCategoryKey.displacedDatabases,
      );
      expect(displaced.stats.bytes, 128);
      expect(displaced.stats.fileCount, 2);
      expect(displaced.subcategories.single.id, 'displaced_databases');
      // A copy can be the only surviving version of the user's data, so the
      // "space you can reclaim" prompt must not offer to sweep it.
      expect(before.clearable.bytes, 0);
      expect(before.clearable.fileCount, 0);

      await StorageUsageService.clearDisplacedDatabases();
      final after = await StorageUsageService.computeReport();
      expect(
        after.categories.where(
          (category) =>
              category.key == StorageUsageCategoryKey.displacedDatabases,
        ),
        isEmpty,
      );
    },
  );

  test('local copies are accounted for on their own, not as "other"', () async {
    final snapshots = Directory(
      p.join(tempDir.path, LocalSnapshotPaths.directoryName),
    );
    await snapshots.create(recursive: true);
    await _writeSizedFile(
      snapshots,
      LocalSnapshotPaths.fileNameFor(DateTime.utc(2026, 5, 1)),
      512,
    );
    await _writeSizedFile(
      snapshots,
      '${LocalSnapshotPaths.fileNameFor(DateTime.utc(2026, 5, 1))}'
      '${LocalSnapshotPaths.metadataSuffix}',
      64,
    );

    final report = await StorageUsageService.computeReport();
    final copies = report.categories.singleWhere(
      (category) => category.key == StorageUsageCategoryKey.localSnapshots,
    );

    expect(copies.stats.bytes, 576);
    expect(copies.stats.fileCount, 2);
    expect(copies.subcategories.single.id, 'local_snapshots');
    expect(copies.subcategories.single.path, snapshots.path);
    // Restorable data is never offered up as space to reclaim.
    expect(report.clearable.bytes, 0);
    final other = report.categories.singleWhere(
      (category) => category.key == StorageUsageCategoryKey.other,
    );
    expect(other.stats.bytes, 0);
  });

  test('restore traces stay hidden while a restore run is active', () async {
    const runId = '0123456789abcdef0123456789abcdef';
    final workspace = Directory(
      p.join(tempDir.path, RestoreWorkspaceLock.workspaceRootName),
    );
    final completedRun = Directory(
      p.join(
        workspace.path,
        RestoreWorkspaceLock.completedRunsDirectoryName,
        'run_$runId',
      ),
    );
    await completedRun.create(recursive: true);
    await _writeSizedFile(completedRun, 'settings.json', 64);
    await File(
      p.join(workspace.path, RestoreWorkspaceLock.activeRunFileName),
    ).writeAsString(runId);

    final report = await StorageUsageService.computeReport();
    expect(
      report.categories.where(
        (category) => category.key == StorageUsageCategoryKey.restoreTraces,
      ),
      isEmpty,
    );
  });

  test('fonts and local models are listed under other', () async {
    await _writeSizedFile(tempDir, p.join('fonts', 'Custom.ttf'), 40);
    await _writeSizedFile(
      tempDir,
      p.join('asr_models', 'paraformer-zh-small-2024-03-09', 'model.int8.onnx'),
      80,
    );
    await _writeSizedFile(
      tempDir,
      p.join('asr_models', '.downloads', 'partial.tar.bz2.part'),
      16,
    );
    await _writeSizedFile(tempDir, 'settings.json', 8);

    final report = await StorageUsageService.computeReport();
    final other = report.categories.singleWhere(
      (category) => category.key == StorageUsageCategoryKey.other,
    );
    expect(other.stats.bytes, 144);
    expect(other.stats.fileCount, 4);
    expect(other.subcategories.map((subcategory) => subcategory.id), [
      'fonts',
      'local_models',
      'app',
    ]);
    expect(
      other.subcategories
          .singleWhere((subcategory) => subcategory.id == 'fonts')
          .stats
          .bytes,
      40,
    );
    expect(
      other.subcategories
          .singleWhere((subcategory) => subcategory.id == 'local_models')
          .stats
          .bytes,
      96,
    );
    expect(
      other.subcategories
          .singleWhere((subcategory) => subcategory.id == 'app')
          .stats
          .bytes,
      8,
    );
    expect(report.totalBytes, 144);
    expect(
      report.categories.fold<int>(
        0,
        (sum, category) => sum + category.stats.bytes,
      ),
      report.totalBytes,
    );
  });

  test(
    'image entries distinguish user uploads from assistant images',
    () async {
      final uploadDir = Directory(p.join(tempDir.path, 'upload'));
      final imagesDir = Directory(p.join(tempDir.path, 'images'));
      await uploadDir.create();
      await imagesDir.create();
      await _writeSizedFile(uploadDir, 'uploaded.png', 10);
      await _writeSizedFile(imagesDir, 'assistant.png', 20);

      final entries = await StorageUsageService.listUploadEntries(images: true);
      final sources = {for (final entry in entries) entry.name: entry.source};

      expect(sources['uploaded.png'], StorageFileSource.userUpload);
      expect(sources['assistant.png'], StorageFileSource.assistant);
    },
  );
}
