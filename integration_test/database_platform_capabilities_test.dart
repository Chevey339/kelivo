import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/services/backup/restore_durability.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('DB2-07 native platform capability matrix', (tester) async {
    final root = await Directory.systemTemp.createTemp(
      'kelivo_db2_platform_capability_',
    );
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    final migrationVersion = await _verifySchemaMigration(root);
    final sqliteCapabilities = await _verifySqliteCapabilities(root);
    await _verifyDurableFileOperations(root);

    final version = sqlite.sqlite3.version;
    final report = <String, Object>{
      'format': 'kelivo-db2-platform-capabilities-v1',
      'platform': Platform.operatingSystem,
      'operatingSystemVersion': Platform.operatingSystemVersion,
      'abi': Abi.current().toString(),
      'sqliteVersion': version.libVersion,
      'sqliteVersionNumber': version.versionNumber,
      'sqliteSourceId': version.sourceId,
      'schemaVersion': migrationVersion,
      ...sqliteCapabilities,
      'fileLock': true,
      'fullBarrierRename': true,
    };
    // Machine-readable evidence without database paths or application data.
    // ignore: avoid_print
    print('DB2_CAPABILITY_RESULT:${jsonEncode(report)}');
  });
}

Future<int> _verifySchemaMigration(Directory root) async {
  final file = File(p.join(root.path, 'migration.sqlite'));
  var repository = ChatDatabaseRepository.open(file: file);
  try {
    await repository.ensureReady();
  } finally {
    await repository.close();
  }

  final raw = sqlite.sqlite3.open(file.path);
  raw.userVersion = AppDatabase.currentSchemaVersion - 1;
  raw.close();

  repository = ChatDatabaseRepository.open(file: file);
  try {
    await repository.ensureReady();
    await repository.validateConnectionContract();
    await repository.validateIntegrity();
  } finally {
    await repository.close();
  }
  final info = ChatDatabaseRepository.inspectInstalledDatabase(
    file,
    validateContents: true,
  );
  expect(info.schemaVersion, AppDatabase.currentSchemaVersion);
  return info.schemaVersion;
}

Future<Map<String, Object>> _verifySqliteCapabilities(Directory root) async {
  final sourceFile = File(p.join(root.path, 'source.sqlite'));
  final backupFile = File(p.join(root.path, 'backup.sqlite'));
  final source = sqlite.sqlite3.open(sourceFile.path);
  sqlite.Database? backup;
  sqlite.Database? contender;
  try {
    final journalMode = source
        .select('PRAGMA journal_mode = WAL;')
        .single
        .values
        .single
        .toString()
        .toLowerCase();
    source.execute('PRAGMA synchronous = FULL;');
    final synchronous =
        source.select('PRAGMA synchronous;').single.values.single as int;
    expect(journalMode, 'wal');
    expect(synchronous, 2);

    expect(sqlite.sqlite3.usedCompileOption('ENABLE_FTS5'), isTrue);
    source.execute(
      "CREATE VIRTUAL TABLE capability_fts USING fts5(content, tokenize='unicode61');",
    );
    source.execute('INSERT INTO capability_fts(content) VALUES (?);', [
      'database capability 中文测试',
    ]);
    expect(
      source.select(
        'SELECT COUNT(*) AS count FROM capability_fts '
        'WHERE capability_fts MATCH ?;',
        ['database'],
      ).single['count'],
      1,
    );
    final shortChineseMatchCount =
        source.select(
              'SELECT COUNT(*) AS count FROM capability_fts '
              'WHERE capability_fts MATCH ?;',
              ['中文'],
            ).single['count']
            as int;
    expect(
      source.select(
        'SELECT COUNT(*) AS count FROM capability_fts '
        'WHERE capability_fts MATCH ?;',
        ['中文测试'],
      ).single['count'],
      1,
    );

    source.execute('CREATE TABLE capability_rows(value TEXT NOT NULL);');
    source.execute('INSERT INTO capability_rows(value) VALUES (?);', [
      'backup-sentinel',
    ]);
    backup = sqlite.sqlite3.open(backupFile.path);
    await source.backup(backup, nPage: 1).drain<void>();
    expect(
      backup.select('SELECT value FROM capability_rows;').single['value'],
      'backup-sentinel',
    );
    expect(backup.select('PRAGMA integrity_check;').single.values.single, 'ok');

    source.execute('BEGIN IMMEDIATE;');
    contender = sqlite.sqlite3.open(sourceFile.path);
    contender.execute('PRAGMA busy_timeout = 1;');
    expect(
      () => contender!.execute('BEGIN IMMEDIATE;'),
      throwsA(isA<sqlite.SqliteException>()),
    );
    source.execute('ROLLBACK;');

    return {
      'fts5': true,
      'unicode61': true,
      'shortChineseMatchCount': shortChineseMatchCount,
      'onlineBackup': true,
      'sqliteLockContention': true,
      'journalMode': journalMode,
      'synchronous': synchronous,
    };
  } finally {
    contender?.close();
    backup?.close();
    source.close();
  }
}

Future<void> _verifyDurableFileOperations(Directory root) async {
  final durability = RestorePlatformDurability();
  final source = File(p.join(root.path, 'barrier-source'));
  final target = File(p.join(root.path, 'barrier-target'));
  await source.writeAsBytes(const [1, 2, 3, 4], flush: true);
  await durability.restrictFile(source);

  final lockHandle = await source.open(mode: FileMode.append);
  try {
    await lockHandle.lock(FileLock.exclusive);
    await lockHandle.unlock();
  } finally {
    await lockHandle.close();
  }

  await durability.syncFile(source, fullBarrier: true);
  await durability.renameAndSync(source: source, targetPath: target.path);
  expect(await target.readAsBytes(), const [1, 2, 3, 4]);
  await durability.syncDirectory(root, fullBarrier: true);
}
