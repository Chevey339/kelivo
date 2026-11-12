import 'dart:convert';
import 'dart:io';
import 'database_family_preserver.dart';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:uuid/uuid.dart';

import '../services/backup/recovery_file_discovery.dart';
import '../services/backup/restore_durability.dart';
import 'app_database.dart';
import 'chat_database_repository.dart';
import '../../utils/app_directories.dart';

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

/// Recovery route for a failed startup admission. Existing data is never
/// replaced automatically after an admission failure.
enum DatabaseRecoveryAction { none, promptRemigration, promptUpgrade }

/// A database family that [DatabaseInstallationGate.rebuildFresh] moved aside
/// instead of deleting.
final class DisplacedDatabaseCopy {
  const DisplacedDatabaseCopy({
    required this.file,
    required this.stamp,
    required this.displacedAt,
    required this.bytes,
  });

  /// The database itself; sidecars sit beside it with their own suffixes.
  final File file;

  /// Identifies the family. Sorts chronologically as text.
  final String stamp;

  /// Null when the stamp predates the current naming and cannot be read.
  final DateTime? displacedAt;

  /// The whole family, sidecars included.
  final int bytes;
}

final class DatabaseInstallationGate {
  DatabaseInstallationGate._();

  static const historyFileName = '.kelivo_database_history.json';

  static const _receiptPrefix = 'database_installation_receipt_';
  static const _receiptSuffix = '.json';
  // A crash between creating the temp file and renaming it must not brick the
  // next launch, so each publish uses a unique temp name and sweeps stale ones
  // rather than reusing a single fixed name that a leftover could block. The
  // prefix intentionally omits the trailing separator so the sweep also clears
  // the legacy fixed-name temp ('.database_installation_receipt.tmp').
  static const _temporaryPrefix = '.database_installation_receipt';
  static const _temporarySuffix = '.tmp';
  static const _maximumReceiptBytes = 4096;

  /// Suffix marking a database family moved aside by [rebuildFresh] rather
  /// than deleted. The stamp keeps generations distinct and sorts
  /// chronologically; every sidecar keeps its suffix so the whole set stays
  /// openable, uncheckpointed transactions included.
  static const displacedDatabasePrefix = '.displaced-';

  /// The database and every sidecar SQLite may leave beside it. Must stay in
  /// step with ChatDatabaseRepository's own family handling: moving a database
  /// without its journal strands the journal next to whatever takes its place.
  static const _databaseFamilySuffixes = <String>[
    '',
    '-wal',
    '-shm',
    '-journal',
  ];

  static Future<DatabaseInstallationReceipt> ensureReady({
    required Directory appDataDirectory,
    bool allowDatabaseIdentityChange = false,
    bool allowEmptyInitialization = false,
    RestoreDurability? durability,
  }) async {
    final resolvedDurability = durability ?? RestorePlatformDurability();
    await appDataDirectory.create(recursive: true);
    await DatabaseFamilyPreserver.resume(
      appDataDirectory,
      durability: resolvedDurability,
    );
    final databaseFile = File(
      p.join(appDataDirectory.path, AppDatabase.databaseFileName),
    );
    // A crash during a schema upgrade -- or during the rollback from a failed
    // one -- can leave the pre-migration copy behind. Resolve it before the
    // migration below writes a fresh one; this may restore the database from
    // that copy, so it has to run before we decide the database is missing.
    await _sweepPreMigrationBackups(
      appDataDirectory,
      durability: resolvedDurability,
    );
    final receipts = await _readReceipts(appDataDirectory);
    final databaseType = await FileSystemEntity.type(
      databaseFile.path,
      followLinks: false,
    );
    if (databaseType == FileSystemEntityType.notFound &&
        (receipts.isNotEmpty ||
            (!allowEmptyInitialization &&
                (await (await _historyFile(appDataDirectory)).exists() ||
                    await RecoveryFileDiscovery.hasPriorData(
                      appDataDirectory,
                    ))))) {
      throw StateError('database_missing_with_prior_data');
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
        await ChatDatabaseRepository.migrateInstalledDatabase(
          databaseFile,
          durability: resolvedDurability,
        );
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
      await _recordHistory(
        appDataDirectory,
        matching.single.receipt,
        resolvedDurability,
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
    await _recordHistory(appDataDirectory, updated, resolvedDurability);
    return updated;
  }

  static Future<File> _historyFile(Directory root) async {
    final retained = await AppDirectories.documentsDirectoryFor(root);
    return File(
      p.join(retained == null ? root.path : root.parent.path, historyFileName),
    );
  }

  static Future<void> _recordHistory(
    Directory root,
    DatabaseInstallationReceipt receipt,
    RestoreDurability durability,
  ) async {
    final file = await _historyFile(root);
    if (await file.exists()) return;
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(receipt.toJson()), flush: true);
    await durability.syncFile(temporary, fullBarrier: true);
    await durability.renameAndSync(source: temporary, targetPath: file.path);
  }

  /// Reconciles installation metadata with a committed, verified restore.
  /// Must run under the startup business/workspace leases before archiving the
  /// terminal run. It never changes database bytes, so interrupted terminal
  /// revalidation can still compare the database with the candidate hash.
  static Future<void> reconcileCommittedRestore({
    required Directory appDataDirectory,
    required RestoreDurability durability,
  }) async {
    final info = ChatDatabaseRepository.inspectInstalledDatabase(
      File(p.join(appDataDirectory.path, AppDatabase.databaseFileName)),
    );
    var receipts = <({File file, DatabaseInstallationReceipt receipt})>[];
    try {
      receipts = await _readReceipts(appDataDirectory);
    } on FormatException {
      // Preserve the malformed metadata below instead of trusting or deleting it.
    }
    if (info.databaseId != null &&
        receipts.length == 1 &&
        receipts.single.receipt.databaseId == info.databaseId) {
      return;
    }
    final files = await appDataDirectory.list(followLinks: false).where((
      entity,
    ) {
      final name = p.basename(entity.path);
      return name.startsWith(_receiptPrefix) && name.endsWith(_receiptSuffix);
    }).toList();
    for (final file in files) {
      if (await FileSystemEntity.type(file.path, followLinks: false) !=
          FileSystemEntityType.file) {
        throw StateError('database_installation_receipt_type');
      }
    }
    if (files.isNotEmpty) {
      final archive = await appDataDirectory.createTemp(
        '.kelivo_installation_receipts_',
      );
      await durability.restrictDirectory(archive);
      await durability.syncDirectory(appDataDirectory, fullBarrier: true);
      for (final file in files) {
        await durability.renameAndSync(
          source: file,
          targetPath: p.join(archive.path, p.basename(file.path)),
        );
      }
    }
    // An older snapshot may have no identity. With the old receipts safely
    // removed, normal admission will assign one even after another cold start.
    // Assigning it here would invalidate the pending terminal run's hash.
    final databaseId = info.databaseId;
    if (databaseId == null) return;
    final installationIds = receipts
        .map((entry) => entry.receipt.installationId)
        .toSet();
    final receipt = DatabaseInstallationReceipt(
      installationId: installationIds.length == 1
          ? installationIds.single
          : const Uuid().v4(),
      databaseId: databaseId,
    );
    await _publishReceipt(
      File(
        p.join(
          appDataDirectory.path,
          '$_receiptPrefix$databaseId$_receiptSuffix',
        ),
      ),
      receipt,
      durability: durability,
    );
  }

  /// Offers explicit recovery or an upgrade; never rebuilds a failed database.
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
    // A receipt, including a malformed receipt, proves this is not first use.
    try {
      if ((await _readReceipts(appDataDirectory)).isNotEmpty) {
        return DatabaseRecoveryAction.none;
      }
    } catch (_) {
      return DatabaseRecoveryAction.none;
    }
    return legacyHiveDataPresent
        ? DatabaseRecoveryAction.promptRemigration
        : DatabaseRecoveryAction.none;
  }

  /// Starts a fresh database only after an explicit reset request.
  ///
  /// Preserves every previous family by default. Explicit deletion is only
  /// available to callers that specifically requested removal of those files.
  static Future<DatabaseInstallationReceipt> rebuildFresh({
    required Directory appDataDirectory,
    RestoreDurability? durability,
    bool preserveDisplacedCopy = true,
  }) async {
    final resolvedDurability = durability ?? RestorePlatformDurability();
    await appDataDirectory.create(recursive: true);
    await DatabaseFamilyPreserver.resume(
      appDataDirectory,
      durability: resolvedDurability,
    );
    final databaseFile = File(
      p.join(appDataDirectory.path, AppDatabase.databaseFileName),
    );
    if (preserveDisplacedCopy) {
      await _displaceDatabaseFamily(
        databaseFile,
        durability: resolvedDurability,
      );
    } else {
      for (final suffix in _databaseFamilySuffixes) {
        final target = File('${databaseFile.path}$suffix');
        if (await FileSystemEntity.type(target.path, followLinks: false) ==
            FileSystemEntityType.file) {
          await target.delete();
        }
      }
      await _pruneDisplacedGenerations(
        appDataDirectory,
        keep: 0,
        durability: resolvedDurability,
      );
    }
    await resolvedDurability.syncDirectory(appDataDirectory, fullBarrier: true);
    return ensureReady(
      appDataDirectory: appDataDirectory,
      durability: resolvedDurability,
      allowEmptyInitialization: true,
    );
  }

  /// Whether [appDataDirectory] holds any displaced database copy.
  static Future<bool> hasDisplacedDatabases({
    required Directory appDataDirectory,
  }) async {
    final prefix = '${AppDatabase.databaseFileName}$displacedDatabasePrefix';
    try {
      await for (final entity in appDataDirectory.list(followLinks: false)) {
        if (p.basename(entity.path).startsWith(prefix)) return true;
      }
    } catch (_) {}
    return false;
  }

  /// The database families set aside by [rebuildFresh], newest first.
  ///
  /// Each is a bare SQLite family, possibly on an older schema and possibly
  /// still holding an unreplayed journal, so nothing here opens one: the
  /// listing is for a screen that offers to export or restore it, and both of
  /// those go through the backup pipeline rather than reading it directly.
  static Future<List<DisplacedDatabaseCopy>> listDisplacedDatabases({
    required Directory appDataDirectory,
  }) async {
    final prefix = '${AppDatabase.databaseFileName}$displacedDatabasePrefix';
    final bytesByStamp = <String, int>{};
    final directoryCopies = <String>{};
    try {
      await for (final entity in appDataDirectory.list(followLinks: false)) {
        final name = p.basename(entity.path);
        if (entity is Directory &&
            DatabaseFamilyPreserver.isCopyDirectory(name)) {
          final stamp = name.substring(prefix.length);
          directoryCopies.add(stamp);
          bytesByStamp[stamp] = 0;
          await for (final member in entity.list(followLinks: false)) {
            if (member is File) {
              bytesByStamp[stamp] =
                  bytesByStamp[stamp]! + await member.length();
            }
          }
          continue;
        }
        if (entity is! File || !name.startsWith(prefix)) continue;
        var stamp = name.substring(prefix.length);
        for (final suffix in _databaseFamilySuffixes) {
          if (suffix.isEmpty) continue;
          if (stamp.endsWith(suffix)) {
            stamp = stamp.substring(0, stamp.length - suffix.length);
            break;
          }
        }
        if (stamp.isEmpty) continue;
        try {
          bytesByStamp[stamp] =
              (bytesByStamp[stamp] ?? 0) + await entity.length();
        } catch (_) {
          bytesByStamp[stamp] ??= 0;
        }
      }
    } catch (_) {
      return const <DisplacedDatabaseCopy>[];
    }

    final copies = <DisplacedDatabaseCopy>[];
    for (final entry in bytesByStamp.entries) {
      final base = File(
        directoryCopies.contains(entry.key)
            ? p.join(appDataDirectory.path, '$prefix${entry.key}', 'kelivo.db')
            : p.join(appDataDirectory.path, '$prefix${entry.key}'),
      );
      if (await FileSystemEntity.type(base.path, followLinks: false) !=
          FileSystemEntityType.file) {
        // The family exists but its database does not; there is nothing a
        // restore could be built from, so do not offer it.
        continue;
      }
      final micros = int.tryParse(entry.key);
      copies.add(
        DisplacedDatabaseCopy(
          file: base,
          stamp: entry.key,
          displacedAt: micros == null
              ? null
              : DateTime.fromMicrosecondsSinceEpoch(micros, isUtc: true),
          bytes: entry.value,
        ),
      );
    }
    copies.sort((a, b) => b.stamp.compareTo(a.stamp));
    return copies;
  }

  /// Removes one displaced family. Throws if anything survives.
  static Future<void> deleteDisplacedDatabase({
    required Directory appDataDirectory,
    required String stamp,
  }) async {
    if (stamp.isEmpty || !RegExp(r'^[0-9]+$').hasMatch(stamp)) {
      throw ArgumentError.value(stamp, 'stamp');
    }
    final prefix = '${AppDatabase.databaseFileName}$displacedDatabasePrefix';
    if (await File(
      p.join(appDataDirectory.path, DatabaseFamilyPreserver.pendingName),
    ).exists()) {
      throw StateError('database_preservation_pending');
    }
    final directory = Directory(p.join(appDataDirectory.path, '$prefix$stamp'));
    if (await FileSystemEntity.type(directory.path, followLinks: false) ==
        FileSystemEntityType.directory) {
      await directory.delete(recursive: true);
      return;
    }
    // Sidecars first, database last. [listDisplacedDatabases] only surfaces a
    // family whose database still exists, so removing the database first would
    // hide any sidecar that then failed to delete -- leaving debris the user
    // can no longer reach, while `hasDisplacedDatabases` still reports it.
    for (final suffix in _databaseFamilySuffixes.reversed) {
      final file = File(p.join(appDataDirectory.path, '$prefix$stamp$suffix'));
      try {
        if (await FileSystemEntity.type(file.path, followLinks: false) ==
            FileSystemEntityType.file) {
          await file.delete();
        }
      } catch (_) {}
    }
    for (final suffix in _databaseFamilySuffixes) {
      final file = File(p.join(appDataDirectory.path, '$prefix$stamp$suffix'));
      if (await FileSystemEntity.type(file.path, followLinks: false) !=
          FileSystemEntityType.notFound) {
        throw StateError('displaced_databases_not_cleared');
      }
    }
  }

  /// Removes every displaced database copy.
  ///
  /// A copy can be the only surviving version of the user's data, so nothing
  /// calls this on its own schedule — it exists for the storage screen, where
  /// the user is told what they are discarding.
  static Future<void> clearDisplacedDatabases({
    required Directory appDataDirectory,
    RestoreDurability? durability,
  }) async {
    await _pruneDisplacedGenerations(
      appDataDirectory,
      keep: 0,
      durability: durability ?? RestorePlatformDurability(),
    );
    // Pruning swallows per-file errors so housekeeping can never fail a
    // rebuild. This caller is a user pressing Delete, so it has to report
    // that nothing happened rather than show a success it did not achieve.
    if (await hasDisplacedDatabases(appDataDirectory: appDataDirectory)) {
      throw StateError('displaced_databases_not_cleared');
    }
  }

  /// Preserves unreadable live files before installing a validated snapshot.
  /// The caller must hold the business/workspace leases and have a durable
  /// restore candidate. Unlike automatic rebuilds, this never prunes evidence.
  static Future<void> preserveFailedDatabaseForRestore({
    required Directory appDataDirectory,
    required RestoreDurability durability,
  }) async {
    await _displaceDatabaseFamily(
      File(p.join(appDataDirectory.path, AppDatabase.databaseFileName)),
      durability: durability,
    );
  }

  /// Renames the database family aside. Returns the new base path, or null
  /// when there was nothing to move.
  static Future<String?> _displaceDatabaseFamily(
    File databaseFile, {
    required RestoreDurability durability,
  }) async {
    return DatabaseFamilyPreserver.preserve(
      databaseFile,
      durability: durability,
    );
  }

  /// Bounds the displaced generations, always keeping the oldest.
  ///
  /// The oldest generation is the irreplaceable one: it holds what was on disk
  /// before anything started displacing, while later generations are usually
  /// copies of a state we produced ourselves. A caller that retries -- a
  /// pre-migration rollback that keeps failing re-displaces on every launch --
  /// would otherwise walk the user's only real copy off the end of a
  /// keep-the-newest window. So the first is kept outright and the window
  /// covers the most recent [keep] - 1.
  static Future<void> _pruneDisplacedGenerations(
    Directory directory, {
    required int keep,
    required RestoreDurability durability,
  }) async {
    final prefix = '${AppDatabase.databaseFileName}$displacedDatabasePrefix';
    final stamps = <String>{};
    try {
      await for (final entity in directory.list(followLinks: false)) {
        final name = p.basename(entity.path);
        if (!name.startsWith(prefix)) continue;
        var stamp = name.substring(prefix.length);
        for (final suffix in _databaseFamilySuffixes) {
          if (suffix.isEmpty) continue;
          if (stamp.endsWith(suffix)) {
            stamp = stamp.substring(0, stamp.length - suffix.length);
            break;
          }
        }
        if (stamp.isNotEmpty) stamps.add(stamp);
      }
    } catch (_) {
      // Pruning is housekeeping; failing it must never fail a rebuild.
      return;
    }
    if (stamps.length <= keep) return;
    final ordered = stamps.toList()..sort();
    final retained = keep <= 0
        ? const <String>{}
        : <String>{ordered.first, ...ordered.reversed.take(keep - 1)};
    final expiring = ordered.where((stamp) => !retained.contains(stamp));
    var removed = false;
    for (final stamp in expiring) {
      final preserved = Directory(p.join(directory.path, '$prefix$stamp'));
      if (DatabaseFamilyPreserver.isCopyDirectory(p.basename(preserved.path)) &&
          await FileSystemEntity.type(preserved.path, followLinks: false) ==
              FileSystemEntityType.directory) {
        await deleteDisplacedDatabase(
          appDataDirectory: directory,
          stamp: stamp,
        );
        removed = true;
        continue;
      }
      for (final suffix in _databaseFamilySuffixes) {
        final file = File(p.join(directory.path, '$prefix$stamp$suffix'));
        try {
          if (await FileSystemEntity.type(file.path, followLinks: false) ==
              FileSystemEntityType.file) {
            await file.delete();
            removed = true;
          }
        } catch (_) {}
      }
    }
    if (removed) {
      try {
        await durability.syncDirectory(directory, fullBarrier: true);
      } catch (_) {}
    }
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

  /// Resolves any pre-migration copy left behind by a crashed schema upgrade.
  ///
  /// The copy is only ever deleted once the installed database is confirmed
  /// usable. If it is not — a crash mid-rollback, when the database had been
  /// removed but the copy not yet written back — the copy is the only
  /// surviving good state and is restored instead. Deleting unconditionally
  /// would turn a recoverable crash into permanent data loss.
  static Future<void> _sweepPreMigrationBackups(
    Directory appDataDirectory, {
    required RestoreDurability durability,
  }) async {
    final prefix =
        '${AppDatabase.databaseFileName}'
        '${ChatDatabaseRepository.premigrationBackupPrefix}';
    final backups = <File>[];
    await for (final entity in appDataDirectory.list(followLinks: false)) {
      if (entity is! File) continue;
      if (!p.basename(entity.path).startsWith(prefix)) continue;
      backups.add(entity);
    }
    if (backups.isEmpty) return;

    final databaseFile = File(
      p.join(appDataDirectory.path, AppDatabase.databaseFileName),
    );
    switch (ChatDatabaseRepository.classifyInstalledDatabase(databaseFile)) {
      case InstalledDatabaseDisposition.usable:
        for (final backup in backups) {
          await durability.renameAndSync(
            source: backup,
            targetPath:
                '${databaseFile.path}$displacedDatabasePrefix${DateTime.now().microsecondsSinceEpoch}',
          );
        }
        await durability.syncDirectory(appDataDirectory, fullBarrier: true);

      case InstalledDatabaseDisposition.foreignSchema:
        // A newer build migrated this database and left its copy behind, and
        // we are the downgrade. The database on disk is strictly ahead of the
        // copy, so touching either would destroy data; leave both and let the
        // gate below ask the user to update.
        return;

      case InstalledDatabaseDisposition.unusable:
        // More than one copy means we cannot tell which state to return to.
        // Failing closed keeps every candidate on disk for the recovery UI
        // rather than guessing and destroying the rest.
        if (backups.length != 1) {
          throw StateError('database_premigration_ambiguous');
        }
        await ChatDatabaseRepository.restorePreMigrationBackup(
          backup: backups.single,
          target: databaseFile,
          durability: durability,
          // `unusable` also covers "could not be opened", which a healthy
          // database looks like whenever the OS is denying the read. This
          // rollback runs on every launch with nobody watching, so the file it
          // rolls over is kept rather than deleted: if the guess was wrong,
          // what it displaced is still there.
          retireTarget: (file) =>
              _displaceDatabaseFamily(file, durability: durability),
        );
    }
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
    // Remove any temp files left by a crashed earlier publish; they carry no
    // authoritative state (the database identity is the source of truth) and
    // must never block a fresh publish.
    await _sweepStaleTemporaries(target.parent);
    final temporary = File(
      p.join(
        target.parent.path,
        '${_temporaryPrefix}_${pid}_'
        '${DateTime.now().microsecondsSinceEpoch}$_temporarySuffix',
      ),
    );
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

  static Future<void> _sweepStaleTemporaries(Directory directory) async {
    await for (final entity in directory.list(followLinks: false)) {
      final name = p.basename(entity.path);
      if (!name.startsWith(_temporaryPrefix) ||
          !name.endsWith(_temporarySuffix)) {
        continue;
      }
      if (await FileSystemEntity.type(entity.path, followLinks: false) ==
          FileSystemEntityType.file) {
        try {
          await File(entity.path).delete();
        } catch (_) {
          // Best-effort: a temp we cannot delete still does not block publish,
          // which now uses a unique name.
        }
      }
    }
  }
}

bool _isUuid(String value) => RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
).hasMatch(value);
