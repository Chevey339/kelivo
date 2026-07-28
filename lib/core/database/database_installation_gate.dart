import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:uuid/uuid.dart';

import '../services/backup/restore_durability.dart';
import 'app_database.dart';
import 'chat_database_repository.dart';

final class DatabaseInstallationReceipt {
  const DatabaseInstallationReceipt({
    required this.installationId,
    required this.databaseId,
  });

  static const formatVersion = 1;

  final String installationId;
  final String databaseId;

  Map<String, Object> toJson() => {
    'version': formatVersion,
    'installationId': installationId,
    'databaseId': databaseId,
  };

  static DatabaseInstallationReceipt fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value.length != 3 ||
        value['version'] != formatVersion ||
        value['installationId'] is! String ||
        value['databaseId'] is! String) {
      throw const FormatException('database_installation_receipt');
    }
    final receipt = DatabaseInstallationReceipt(
      installationId: value['installationId'] as String,
      databaseId: value['databaseId'] as String,
    );
    if (!_isUuid(receipt.installationId) || !_isUuid(receipt.databaseId)) {
      throw const FormatException('database_installation_receipt');
    }
    return receipt;
  }
}

/// Recovery route for a failed startup admission. Only
/// [rebuildAutomatically] may run without further user confirmation; every
/// other route must be confirmed by the user first.
enum DatabaseRecoveryAction {
  none,
  rebuildAutomatically,
  promptRemigration,
  promptUpgrade,
}

final class DatabaseInstallationGate {
  DatabaseInstallationGate._();

  static const _receiptPrefix = 'database_installation_receipt_';
  static const _receiptSuffix = '.json';
  static const _temporaryFileName = '.database_installation_receipt.tmp';
  static const _maximumReceiptBytes = 4096;

  static Future<DatabaseInstallationReceipt> ensureReady({
    required Directory appDataDirectory,
    bool allowDatabaseIdentityChange = false,
    RestoreDurability? durability,
  }) async {
    final resolvedDurability = durability ?? RestorePlatformDurability();
    await appDataDirectory.create(recursive: true);
    final databaseFile = File(
      p.join(appDataDirectory.path, AppDatabase.databaseFileName),
    );
    final receipts = await _readReceipts(appDataDirectory);
    final databaseType = await FileSystemEntity.type(
      databaseFile.path,
      followLinks: false,
    );
    if (receipts.isNotEmpty && databaseType == FileSystemEntityType.notFound) {
      throw StateError('database_missing');
    }
    if (databaseType != FileSystemEntityType.notFound &&
        databaseType != FileSystemEntityType.file) {
      throw StateError('database_type');
    }

    late InstalledChatDatabaseInfo info;
    try {
      if (databaseType == FileSystemEntityType.notFound) {
        final repository = ChatDatabaseRepository.open(file: databaseFile);
        try {
          await repository.ensureReady();
        } finally {
          await repository.close();
        }
      } else {
        await ChatDatabaseRepository.migrateInstalledDatabase(databaseFile);
      }

      info = ChatDatabaseRepository.inspectInstalledDatabase(databaseFile);
    } on StateError catch (error) {
      // migrateInstalledDatabase reports every schema mismatch with the same
      // code; only a newer schema means the user must update the app.
      if (error.message == 'database_schema_version') {
        final userVersion = _tryReadUserVersion(databaseFile);
        if (userVersion != null &&
            userVersion > AppDatabase.currentSchemaVersion) {
          throw StateError('database_schema_too_new');
        }
      }
      rethrow;
    }
    if (info.databaseId == null) {
      if (receipts.isNotEmpty) {
        if (!allowDatabaseIdentityChange) {
          throw StateError('database_identity_missing');
        }
      }
      final databaseId = const Uuid().v4();
      ChatDatabaseRepository.assignInstalledDatabaseIdentity(
        databaseFile,
        databaseId,
      );
      info = ChatDatabaseRepository.inspectInstalledDatabase(databaseFile);
    }
    final databaseId = info.databaseId!;
    final matching = receipts
        .where((entry) => entry.receipt.databaseId == databaseId)
        .toList(growable: false);
    if (matching.length > 1) {
      throw StateError('database_installation_receipt_duplicate');
    }
    if (matching.length == 1) {
      await _removeStaleReceipts(
        receipts.where((entry) => entry.file.path != matching.single.file.path),
        durability: resolvedDurability,
      );
      return matching.single.receipt;
    }
    if (receipts.isNotEmpty) {
      if (!allowDatabaseIdentityChange) {
        throw StateError('database_identity_mismatch');
      }
    }
    final installationIds = receipts
        .map((entry) => entry.receipt.installationId)
        .toSet();
    if (installationIds.length > 1) {
      throw StateError('database_installation_identity_mismatch');
    }
    final updated = DatabaseInstallationReceipt(
      installationId: installationIds.firstOrNull ?? const Uuid().v4(),
      databaseId: databaseId,
    );
    final receiptFile = File(
      p.join(
        appDataDirectory.path,
        '$_receiptPrefix${updated.databaseId}$_receiptSuffix',
      ),
    );
    await _publishReceipt(receiptFile, updated, durability: resolvedDurability);
    await _removeStaleReceipts(receipts, durability: resolvedDurability);
    return updated;
  }

  /// Maps a startup admission failure to the strongest safe recovery route.
  ///
  /// Automatic rebuild is only returned when no installation receipt and no
  /// legacy Hive source exist and the installed file is half-created
  /// (userVersion 0) or unreadable, so no reachable data can be lost.
  static Future<DatabaseRecoveryAction> recoveryActionFor({
    required Directory appDataDirectory,
    required Object error,
    required bool legacyHiveDataPresent,
  }) async {
    if (error is StateError && error.message == 'database_schema_too_new') {
      return DatabaseRecoveryAction.promptUpgrade;
    }
    final isSchemaOrCorrupt =
        error is StateError &&
        (error.message == 'database_schema_version' ||
            error.message == 'database_corrupt');
    final isRawSqliteFailure = error is sqlite.SqliteException;
    if (!isSchemaOrCorrupt && !isRawSqliteFailure) {
      return DatabaseRecoveryAction.none;
    }
    // A receipt that exists but cannot be parsed still proves a previous
    // install, so it must block automatic rebuild like a valid one.
    final bool hasReceipts;
    try {
      hasReceipts = (await _readReceipts(appDataDirectory)).isNotEmpty;
    } catch (_) {
      return DatabaseRecoveryAction.none;
    }
    if (hasReceipts) return DatabaseRecoveryAction.none;
    if (legacyHiveDataPresent) {
      return DatabaseRecoveryAction.promptRemigration;
    }
    if (isRawSqliteFailure) {
      // A raw sqlite error never justifies deleting data automatically.
      return DatabaseRecoveryAction.none;
    }
    final databaseFile = File(
      p.join(appDataDirectory.path, AppDatabase.databaseFileName),
    );
    if (await FileSystemEntity.type(databaseFile.path, followLinks: false) !=
        FileSystemEntityType.file) {
      return DatabaseRecoveryAction.none;
    }
    final userVersion = _tryReadUserVersion(databaseFile);
    if (userVersion == null || userVersion == 0) {
      return DatabaseRecoveryAction.rebuildAutomatically;
    }
    return DatabaseRecoveryAction.none;
  }

  /// Deletes the installed database family and repeats first-launch setup.
  /// Only safe where [recoveryActionFor] returned
  /// [DatabaseRecoveryAction.rebuildAutomatically].
  static Future<DatabaseInstallationReceipt> rebuildFresh({
    required Directory appDataDirectory,
    RestoreDurability? durability,
  }) async {
    final resolvedDurability = durability ?? RestorePlatformDurability();
    await appDataDirectory.create(recursive: true);
    final databaseFile = File(
      p.join(appDataDirectory.path, AppDatabase.databaseFileName),
    );
    for (final suffix in const ['', '-wal', '-shm']) {
      final target = File('${databaseFile.path}$suffix');
      if (await FileSystemEntity.type(target.path, followLinks: false) ==
          FileSystemEntityType.file) {
        await target.delete();
      }
    }
    await resolvedDurability.syncDirectory(appDataDirectory, fullBarrier: true);
    return ensureReady(
      appDataDirectory: appDataDirectory,
      durability: resolvedDurability,
    );
  }

  static int? _tryReadUserVersion(File file) {
    sqlite.Database? database;
    try {
      database = sqlite.sqlite3.open(
        file.absolute.path,
        mode: sqlite.OpenMode.readOnly,
      );
      return database.userVersion;
    } catch (_) {
      return null;
    } finally {
      try {
        database?.close();
      } catch (_) {}
    }
  }

  static Future<DatabaseInstallationReceipt?> read({
    required Directory appDataDirectory,
  }) async {
    final receipts = await _readReceipts(appDataDirectory);
    if (receipts.isEmpty) return null;
    final databaseFile = File(
      p.join(appDataDirectory.path, AppDatabase.databaseFileName),
    );
    if (!await databaseFile.exists()) throw StateError('database_missing');
    final databaseId = ChatDatabaseRepository.inspectInstalledDatabase(
      databaseFile,
    ).databaseId;
    final matching = receipts
        .where((entry) => entry.receipt.databaseId == databaseId)
        .toList(growable: false);
    if (matching.length != 1) {
      throw StateError('database_installation_receipt_match');
    }
    return matching.single.receipt;
  }

  static Future<List<({File file, DatabaseInstallationReceipt receipt})>>
  _readReceipts(Directory directory) async {
    final receipts = <({File file, DatabaseInstallationReceipt receipt})>[];
    await for (final entity in directory.list(followLinks: false)) {
      final name = p.basename(entity.path);
      if (!name.startsWith(_receiptPrefix) || !name.endsWith(_receiptSuffix)) {
        continue;
      }
      if (await FileSystemEntity.type(entity.path, followLinks: false) !=
          FileSystemEntityType.file) {
        throw StateError('database_installation_receipt_type');
      }
      final file = File(entity.path);
      final receipt = await _readReceipt(file);
      if (name != '$_receiptPrefix${receipt.databaseId}$_receiptSuffix') {
        throw const FormatException('database_installation_receipt_name');
      }
      receipts.add((file: file, receipt: receipt));
    }
    return receipts;
  }

  static Future<void> _removeStaleReceipts(
    Iterable<({File file, DatabaseInstallationReceipt receipt})> entries, {
    required RestoreDurability durability,
  }) async {
    Directory? parent;
    for (final entry in entries) {
      await entry.file.delete();
      parent = entry.file.parent;
    }
    if (parent != null) {
      await durability.syncDirectory(parent, fullBarrier: true);
    }
  }

  static Future<DatabaseInstallationReceipt> _readReceipt(File file) async {
    if (await file.length() > _maximumReceiptBytes) {
      throw const FormatException('database_installation_receipt');
    }
    final decoded = jsonDecode(await file.readAsString());
    return DatabaseInstallationReceipt.fromJson(decoded);
  }

  static Future<void> _publishReceipt(
    File target,
    DatabaseInstallationReceipt receipt, {
    required RestoreDurability durability,
  }) async {
    final temporary = File(p.join(target.parent.path, _temporaryFileName));
    if (await FileSystemEntity.type(temporary.path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw StateError('database_installation_receipt_temporary');
    }
    try {
      await temporary.create(exclusive: true);
      await durability.restrictFile(temporary);
      await temporary.writeAsString(jsonEncode(receipt.toJson()), flush: true);
      await durability.syncFile(temporary, fullBarrier: true);
      if (await target.exists()) {
        throw StateError('database_installation_receipt_collision');
      }
      await durability.renameAndSync(
        source: temporary,
        targetPath: target.path,
      );
      final published = await _readReceipt(target);
      if (published.installationId != receipt.installationId ||
          published.databaseId != receipt.databaseId) {
        throw StateError('database_installation_receipt_publish');
      }
    } finally {
      if (await FileSystemEntity.type(temporary.path, followLinks: false) ==
          FileSystemEntityType.file) {
        await temporary.delete();
        await durability.syncDirectory(target.parent, fullBarrier: true);
      }
    }
  }
}

bool _isUuid(String value) => RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
).hasMatch(value);
