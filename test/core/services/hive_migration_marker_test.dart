import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/services/hive_migration_marker.dart';

/// [HiveMigrationMarker.requireMigrationComplete] is read by the startup legacy
/// check, whose fallback re-runs the Hive migration and replaces the installed
/// database. So it has to answer at any published schema — it runs before
/// admission upgrades the file — and it must never answer "not migrated" for a
/// database it merely failed to read.
void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('kelivo_hive_marker_');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  File fileNamed(String name) => File(p.join(directory.path, name));

  /// Writes a database carrying [receipt] as the migration marker value, or no
  /// marker row at all when [receipt] is null.
  File writeDatabase({
    required int schemaVersion,
    String? receipt,
    bool createTable = true,
  }) {
    final file = fileNamed('kelivo.db');
    final database = sqlite.sqlite3.open(file.path);
    try {
      if (createTable) {
        database.execute(
          'CREATE TABLE chat_storage_meta_rows '
          '(key TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL);',
        );
        if (receipt != null) {
          database.execute(
            'INSERT INTO chat_storage_meta_rows (key, value) VALUES (?, ?);',
            [ChatStorageMetaKeys.hiveMigrationComplete, receipt],
          );
        }
      } else {
        // A database has to hold something for SQLite to write a header.
        database.execute('CREATE TABLE unrelated (value TEXT);');
      }
      database.userVersion = schemaVersion;
    } finally {
      database.close();
    }
    return file;
  }

  Matcher throwsCorrupt() => throwsA(
    isA<StateError>().having(
      (error) => error.message,
      'message',
      'database_corrupt',
    ),
  );

  for (final schemaVersion in AppDatabase.publishedSchemaVersions) {
    test('reads the receipt at schema $schemaVersion', () {
      final file = writeDatabase(schemaVersion: schemaVersion, receipt: 'true');
      expect(HiveMigrationMarker.requireMigrationComplete(file), isTrue);
    });
  }

  test('reads the receipt at a schema newer than this build', () {
    // A downgraded install still has to reach admission, which is where
    // "please update" is decided — the receipt read must not pre-empt it.
    final file = writeDatabase(
      schemaVersion: AppDatabase.currentSchemaVersion + 1,
      receipt: 'true',
    );
    expect(HiveMigrationMarker.requireMigrationComplete(file), isTrue);
  });

  test('reports not migrated when the receipt row is absent', () {
    final file = writeDatabase(schemaVersion: AppDatabase.currentSchemaVersion);
    expect(HiveMigrationMarker.requireMigrationComplete(file), isFalse);
  });

  test('reports not migrated for a receipt value other than true', () {
    for (final receipt in const ['false', 'True', '1', '']) {
      final file = writeDatabase(
        schemaVersion: AppDatabase.currentSchemaVersion,
        receipt: receipt,
      );
      expect(
        HiveMigrationMarker.requireMigrationComplete(file),
        isFalse,
        reason: 'receipt value "$receipt" must not count as complete',
      );
      file.deleteSync();
    }
  });

  test('reports not migrated for a database that was never initialised', () {
    // What a launch that crashed before drift wrote anything leaves behind.
    final file = fileNamed('kelivo.db')..writeAsBytesSync(const []);
    expect(file.lengthSync(), 0);
    expect(HiveMigrationMarker.requireMigrationComplete(file), isFalse);
  });

  test('reports not migrated for a half-created database', () {
    final file = writeDatabase(schemaVersion: 0, createTable: false);
    expect(HiveMigrationMarker.requireMigrationComplete(file), isFalse);
  });

  test('refuses a database whose meta table is missing', () {
    // Not "never migrated": re-running the migration would replace a file we
    // failed to understand, so this has to go to admission instead.
    final file = writeDatabase(
      schemaVersion: AppDatabase.currentSchemaVersion,
      createTable: false,
    );
    expect(
      () => HiveMigrationMarker.requireMigrationComplete(file),
      throwsCorrupt(),
    );
  });

  test('refuses a file that is not a database', () {
    final file = fileNamed('kelivo.db')
      ..writeAsBytesSync(List<int>.filled(4096, 0x7f));
    expect(
      () => HiveMigrationMarker.requireMigrationComplete(file),
      throwsCorrupt(),
    );
  });

  test('refuses a truncated database header', () {
    final file = fileNamed('kelivo.db')..writeAsStringSync('SQLite fo');
    expect(
      () => HiveMigrationMarker.requireMigrationComplete(file),
      throwsCorrupt(),
    );
  });

  test('refuses a path it cannot read', () {
    expect(
      () =>
          HiveMigrationMarker.requireMigrationComplete(fileNamed('absent.db')),
      throwsCorrupt(),
    );
    expect(
      () => HiveMigrationMarker.requireMigrationComplete(File(directory.path)),
      throwsCorrupt(),
    );
  });

  test('reads a receipt that is still only in the write-ahead log', () {
    // A crashed launch leaves an unfolded -wal and no -shm; the receipt lives
    // in the log, so a read that ignored it would report "not migrated" and
    // send a migrated device back through a migration that replaces its data.
    final file = fileNamed('kelivo.db');
    final database = sqlite.sqlite3.open(file.path);
    database.execute(
      'CREATE TABLE chat_storage_meta_rows '
      '(key TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL);',
    );
    database.userVersion = AppDatabase.currentSchemaVersion;
    database.execute('PRAGMA wal_checkpoint(TRUNCATE);');
    database.select('PRAGMA journal_mode = WAL;');
    database.execute(
      'INSERT INTO chat_storage_meta_rows (key, value) VALUES (?, ?);',
      [ChatStorageMetaKeys.hiveMigrationComplete, 'true'],
    );

    final crashed = fileNamed('crashed.db');
    final withoutLog = fileNamed('without_log.db');
    file.copySync(crashed.path);
    file.copySync(withoutLog.path);
    File('${file.path}-wal').copySync('${crashed.path}-wal');
    database.close();

    expect(File('${crashed.path}-wal').lengthSync(), greaterThan(0));
    expect(File('${crashed.path}-shm').existsSync(), isFalse);
    // The same bytes without the log do not carry the receipt, so reading it
    // out of the log is what this asserts — not a checkpoint that already ran.
    expect(HiveMigrationMarker.requireMigrationComplete(withoutLog), isFalse);
    expect(HiveMigrationMarker.requireMigrationComplete(crashed), isTrue);
  });

  test('the cleanup gate keeps answering false where this one refuses', () {
    // The two readers deliberately disagree: [isMigrationComplete] guards a
    // destructive cleanup, so "cannot tell" must keep the legacy data.
    final file = fileNamed('kelivo.db')
      ..writeAsBytesSync(List<int>.filled(4096, 0x7f));
    expect(HiveMigrationMarker.isMigrationComplete(file), isFalse);
    expect(
      () => HiveMigrationMarker.requireMigrationComplete(file),
      throwsCorrupt(),
    );
  });
}
