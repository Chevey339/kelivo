import 'dart:convert';
import 'database_family_preserver.dart';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:uuid/uuid.dart';

import '../services/backup/local_copy_catalog.dart';
import '../services/backup/recovery_file_discovery.dart';
import '../services/backup/restore_durability.dart';
import 'app_database.dart';
import 'database_installation_gate.dart';
import 'chat_database_repository.dart' show ChatStorageMetaKeys;
import 'empty_database_permission.dart';

/// A valid SQLite file is not sufficient proof that an empty installation is
/// intentional. Stop before providers seed defaults or schedule new snapshots.
abstract final class EmptyDatabaseRecoveryGuard {
  static const acknowledgementName = '.kelivo_empty_database_ack.json';

  static Future<void> check({
    required Directory appDataDirectory,
    required String databaseId,
  }) async {
    final database = sqlite.sqlite3.open(
      p.join(appDataDirectory.path, AppDatabase.databaseFileName),
      mode: sqlite.OpenMode.readOnly,
    );
    final bool hasChats;
    final String? token;
    try {
      hasChats =
          database
              .select(
                'SELECT EXISTS(SELECT 1 FROM conversation_rows LIMIT 1) AS present',
              )
              .single['present'] ==
          1;
      final rows = database.select(
        'SELECT value FROM chat_storage_meta_rows WHERE key = ?',
        [EmptyDatabasePermission.tokenKey],
      );
      token = rows.isEmpty ? null : rows.single['value'] as String;
    } finally {
      database.close();
    }
    final ack = File(p.join(appDataDirectory.path, acknowledgementName));
    if (hasChats) {
      await invalidate(appDataDirectory);
      return;
    }
    try {
      if (await ack.length() > 4096) {
        throw StateError('database_acknowledgement_size');
      }
      final value = jsonDecode(await ack.readAsString());
      if (token != null &&
          value is Map &&
          value['version'] == 1 &&
          value['databaseId'] == databaseId &&
          value['token'] == token) {
        return;
      }
    } catch (_) {
      // A stale, absent or damaged acknowledgement never authorizes an empty start.
    }
    final catalog = LocalCopyCatalog(appDataDirectory: appDataDirectory);
    final copies = await catalog.list();
    if (catalog.hadReadErrors) {
      throw StateError('database_empty_with_recovery_copies');
    }
    for (final copy in copies) {
      final hasContent = copy.isArchive
          ? await RecoveryFileDiscovery.archiveHasChats(copy.file)
          : await _databaseCopyHasChats(copy.file);
      if (hasContent != false) {
        throw StateError('database_empty_with_recovery_copies');
      }
    }
  }

  static Future<bool?> _databaseCopyHasChats(
    File source,
  ) => Isolate.run(() async {
    final temporary = await Directory.systemTemp.createTemp(
      'kelivo-empty-check-',
    );
    sqlite.Database? database;
    try {
      await DatabaseFamilyPreserver.validateSource(source);
      final copy = File(p.join(temporary.path, 'kelivo.db'));
      for (final suffix in ['', '-wal', '-shm', '-journal']) {
        final file = File('${source.path}$suffix');
        if (await FileSystemEntity.type(file.path, followLinks: false) ==
            FileSystemEntityType.file) {
          await file.copy('${copy.path}$suffix');
        }
      }
      database = sqlite.sqlite3.open(copy.path);
      return database
              .select(
                'SELECT EXISTS(SELECT 1 FROM conversation_rows LIMIT 1) AS present',
              )
              .single['present'] ==
          1;
    } catch (_) {
      return null;
    } finally {
      database?.close();
      await temporary.delete(recursive: true);
    }
  });

  /// Persist before accepting new conversation writes. A one-time empty-start
  /// choice must not authorize losing later chats in the same app session.
  static Future<void> invalidate(Directory directory) async {
    final file = File(p.join(directory.path, acknowledgementName));
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return;
    if (type != FileSystemEntityType.file) {
      throw StateError('database_acknowledgement_type');
    }
    try {
      await file.delete();
    } on FileSystemException {
      if (await FileSystemEntity.type(file.path, followLinks: false) !=
          FileSystemEntityType.notFound) {
        rethrow;
      }
    }
    await RestorePlatformDurability().syncDirectory(
      directory,
      fullBarrier: true,
    );
  }

  /// Only called after an explicit keep/reset/restore choice, before business
  /// services open the database. Nonempty restores never receive permission.
  static Future<void> acknowledge(Directory directory) async {
    final receipt = await DatabaseInstallationGate.read(
      appDataDirectory: directory,
    );
    if (receipt == null) throw StateError('database_identity_missing');
    final database = sqlite.sqlite3.open(
      p.join(directory.path, AppDatabase.databaseFileName),
      mode: sqlite.OpenMode.readWrite,
    );
    try {
      database.execute('BEGIN IMMEDIATE');
      final identity = database.select(
        'SELECT value FROM chat_storage_meta_rows WHERE key = ?',
        [ChatStorageMetaKeys.databaseIdentity],
      );
      if (identity.length != 1 ||
          identity.single['value'] != receipt.databaseId) {
        throw StateError('database_identity_mismatch');
      }
      if (database
              .select(EmptyDatabasePermission.hasDataQuery)
              .single['present'] ==
          1) {
        await invalidate(directory);
      } else {
        for (final statement in EmptyDatabasePermission.invalidationTriggers) {
          database.execute(statement);
        }
        final token = await recordEmptyState(directory, receipt.databaseId);
        database.execute(
          'INSERT OR REPLACE INTO chat_storage_meta_rows (key, value) VALUES (?, ?)',
          [EmptyDatabasePermission.tokenKey, token],
        );
      }
      database.execute('COMMIT');
    } catch (_) {
      if (!database.autocommit) database.execute('ROLLBACK');
      rethrow;
    } finally {
      database.close();
    }
  }

  /// The caller must hold a DB transaction, verify it is empty, then store the
  /// returned token in that same transaction. A rollback cannot authorize an
  /// older DB state because the durable file already contains a new token.
  static Future<String> recordEmptyState(
    Directory directory,
    String databaseId,
  ) async {
    final token = const Uuid().v4();
    final target = File(p.join(directory.path, acknowledgementName));
    final temporary = File('${target.path}.${const Uuid().v4()}.tmp');
    await temporary.writeAsString(
      jsonEncode({'version': 1, 'databaseId': databaseId, 'token': token}),
      flush: true,
    );
    final durability = RestorePlatformDurability();
    await durability.syncFile(temporary, fullBarrier: true);
    final type = await FileSystemEntity.type(target.path, followLinks: false);
    if (type != FileSystemEntityType.notFound) {
      if (type != FileSystemEntityType.file) {
        throw StateError('database_acknowledgement_type');
      }
      // Losing this small acknowledgement only causes another prompt. Never
      // use a replacement operation that could overwrite data at another path.
      await target.delete();
      await durability.syncDirectory(directory, fullBarrier: true);
    }
    await durability.renameAndSync(source: temporary, targetPath: target.path);
    return token;
  }
}
