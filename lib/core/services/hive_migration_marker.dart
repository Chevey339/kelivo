import 'dart:io';

import 'package:sqlite3/sqlite3.dart' as sqlite;

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
