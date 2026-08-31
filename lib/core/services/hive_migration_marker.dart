import 'dart:io';

import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../database/app_database.dart';
import '../database/chat_database_repository.dart';

/// Reads the in-database migration receipt
/// ([ChatStorageMetaKeys.hiveMigrationComplete]) without starting a drift
/// isolate. WAL mode allows this read-only connection while the running app
/// holds the database open.
abstract final class HiveMigrationMarker {
  HiveMigrationMarker._();

  /// Whether [databaseFile] carries the completed Hive migration receipt.
  ///
  /// A missing, unreadable or structurally broken database keeps the legacy
  /// Hive cleanup gate closed; database admission problems are handled by
  /// DatabaseInstallationGate, not here.
  static bool isMigrationComplete(File databaseFile) {
    if (!_hasSqliteHeader(databaseFile)) return false;
    final sqlite.Database database;
    try {
      database = sqlite.sqlite3.open(
        databaseFile.absolute.path,
        mode: sqlite.OpenMode.readOnly,
      );
    } on sqlite.SqliteException {
      return false;
    }
    try {
      final rows = database.select(
        'SELECT value FROM chat_storage_meta_rows WHERE key = ?;',
        [ChatStorageMetaKeys.hiveMigrationComplete],
      );
      return rows.length == 1 && rows.single['value'] == 'true';
    } on sqlite.SqliteException {
      return false;
    } finally {
      database.close();
    }
  }

  /// Whether [databaseFile] carries the receipt, for a caller whose fallback
  /// is destructive.
  ///
  /// [isMigrationComplete] answers false whenever it cannot tell, which is the
  /// safe direction for a cleanup gate — it keeps the legacy data. The startup
  /// legacy check needs the opposite: false there means "run the Hive
  /// migration", and that REPLACES the installed database, so a file it merely
  /// failed to read must not be mistaken for one that was never migrated. This
  /// throws `StateError('database_corrupt')` instead, leaving the decision to
  /// database admission.
  ///
  /// Like [isMigrationComplete] it reads the file directly, at whatever
  /// published schema the file happens to be. That is the whole point: the
  /// legacy check runs BEFORE `DatabaseInstallationGate` upgrades the
  /// database, and a live drift connection rejects every schema that is not
  /// already current ([AppDatabase.acceptsLiveSchema]) — which fails startup
  /// closed on exactly the devices this check exists for, the ones that came
  /// from Hive and are still a schema behind. Nothing before admission may
  /// assume the current schema.
  static bool requireMigrationComplete(File databaseFile) {
    final int length;
    try {
      length = databaseFile.lengthSync();
    } on FileSystemException {
      throw StateError('database_corrupt');
    }
    // An empty file is not damage: SQLite creates one on open and only writes
    // a header once something is stored. A crashed first launch leaves exactly
    // this, and it carries no data to lose.
    if (length == 0) return false;
    if (!_hasSqliteHeader(databaseFile)) {
      throw StateError('database_corrupt');
    }
    final sqlite.Database database;
    try {
      database = sqlite.sqlite3.open(
        databaseFile.absolute.path,
        mode: sqlite.OpenMode.readOnly,
      );
    } on sqlite.SqliteException {
      throw StateError('database_corrupt');
    }
    try {
      // A half-created file carries no tables yet, so it cannot hold a
      // receipt. That is what a crashed first launch leaves behind, and
      // re-running the legacy migration is the right answer for it.
      if (database.userVersion == 0) return false;
      final rows = database.select(
        'SELECT value FROM chat_storage_meta_rows WHERE key = ?;',
        [ChatStorageMetaKeys.hiveMigrationComplete],
      );
      if (rows.isEmpty) return false;
      return rows.single['value'] == 'true';
    } on sqlite.SqliteException {
      throw StateError('database_corrupt');
    } finally {
      database.close();
    }
  }

  /// Opening a non-SQLite file next to stray -wal/-shm siblings can grow the
  /// -shm file even in read-only mode, and a report must not mutate files, so
  /// the magic bytes are checked before SQLite touches the path.
  static bool _hasSqliteHeader(File databaseFile) {
    const magic = 'SQLite format 3\x00';
    try {
      final file = databaseFile.openSync();
      try {
        final header = file.readSync(magic.length);
        return String.fromCharCodes(header) == magic;
      } finally {
        file.closeSync();
      }
    } on FileSystemException {
      return false;
    }
  }
}
