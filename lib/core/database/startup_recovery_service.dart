import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:uuid/uuid.dart';

import '../services/backup/restore_durability.dart';
import '../services/backup/restore_business_lease.dart';
import '../services/backup/restore_workspace_lock.dart';
import 'app_database.dart';
import '../../utils/app_directories.dart';
import 'empty_database_recovery_guard.dart';
import 'database_installation_gate.dart';
import 'database_family_preserver.dart';

/// User-initiated recovery actions for the pre-initialization failure screen.
///
/// These run before any app services exist, so every operation works purely at
/// the file level. They exist to guarantee that a fail-closed startup can never
/// become a permanent lockout: the user can always salvage a copy of their
/// data, repair recoverable metadata damage, or (as a last resort) reset.
final class StartupRecoveryService {
  StartupRecoveryService._();

  // Inert OS metadata files that must never block startup validation.
  static const _junkFileNames = <String>{
    '.DS_Store',
    'Thumbs.db',
    'desktop.ini',
    '.localized',
  };

  static const _receiptPrefix = 'database_installation_receipt_';
  static const _receiptSuffix = '.json';
  static const _temporaryPrefix = '.database_installation_receipt';
  static const _temporarySuffix = '.tmp';
  static const _restoreWorkspaceName = '.kelivo_restore';

  /// Copies the entire app data directory into a timestamped folder under
  /// [destinationParent] so the user can salvage their data before attempting
  /// any repair or reset. Returns the created directory. Non-destructive.
  static Future<Directory> exportDataCopy({
    required Directory appDataDirectory,
    required Directory destinationParent,
    DateTime Function()? clock,
    List<Directory> additionalDataDirectories = const [],
  }) async {
    final roots = await _exportRoots(
      appDataDirectory,
      additionalDataDirectories,
    );
    if (roots.isEmpty) {
      throw StateError('startup_recovery_source_missing');
    }
    // A destination inside the data directory would make the copy recurse
    // into itself (the target shows up while the source is being listed).
    final destinationPath = p.normalize(destinationParent.absolute.path);
    if (roots.any(
      (root) =>
          p.equals(root.absolute.path, destinationPath) ||
          p.isWithin(root.absolute.path, destinationPath),
    )) {
      throw StateError('startup_recovery_export_inside_source');
    }
    await destinationParent.create(recursive: true);
    final stamp = (clock?.call() ?? DateTime.now())
        .toUtc()
        .toIso8601String()
        .replaceAll(RegExp(r'[:.]'), '-');
    final target = Directory(
      p.join(destinationParent.path, 'kelivo-data-$stamp'),
    );
    if (await target.exists()) {
      throw StateError('startup_recovery_export_collision');
    }
    await target.create(recursive: true);
    for (var i = 0; i < roots.length; i++) {
      final destination = additionalDataDirectories.isEmpty && roots.length == 1
          ? target
          : await Directory(p.join(target.path, 'data-$i')).create();
      await _copyDirectory(roots[i], destination);
    }
    return target;
  }

  /// Repairs recoverable metadata damage that fails startup closed without any
  /// real data loss: leftover publish temp files, inert OS junk inside the
  /// restore workspace, and unparseable installation receipts. It then
  /// re-runs admission, adopting the current database's identity so a corrupt
  /// or swapped receipt is rewritten from the authoritative on-disk database.
  ///
  /// Rethrows when the database itself is missing or corrupt: those cannot be
  /// repaired at the file level and the caller should offer a reset instead.
  static Future<void> repair({
    required Directory appDataDirectory,
    RestoreDurability? durability,
  }) async {
    if (!await appDataDirectory.exists()) {
      throw StateError('startup_recovery_source_missing');
    }
    if (await FileSystemEntity.type(
          p.join(appDataDirectory.path, AppDatabase.databaseFileName),
          followLinks: false,
        ) !=
        FileSystemEntityType.file) {
      throw StateError('database_missing_with_prior_data');
    }
    await _sweepReceiptTemporaries(appDataDirectory);
    await _sweepRestoreWorkspaceJunk(appDataDirectory);
    await _archiveUnparseableReceipts(
      appDataDirectory,
      durability ?? RestorePlatformDurability(),
    );
    // Adopting the identity lets an archived unreadable receipt or an identity
    // mismatch be repaired from the live database without discarding evidence. A
    // user electing to repair is implicitly trusting the database on disk.
    await DatabaseInstallationGate.ensureReady(
      appDataDirectory: appDataDirectory,
      allowDatabaseIdentityChange: true,
      durability: durability,
    );
  }

  /// Preserves the installed database family and receipts, then explicitly
  /// starts a new database. Retained copies remain available for recovery.
  /// Callers must confirm with the user and should offer [exportDataCopy]
  /// first.
  static Future<void> reset({
    required Directory appDataDirectory,
    RestoreBusinessLease? businessLease,
    RestoreDurability? durability,
  }) async {
    final resolvedDurability = durability ?? RestorePlatformDurability();
    final ownedLease = businessLease == null
        ? await RestoreBusinessLease.acquire(
            appDataDirectory: appDataDirectory,
            durability: resolvedDurability,
          )
        : null;
    final lease = businessLease ?? ownedLease!;
    try {
      final expectedLeasePath = p.join(
        appDataDirectory.absolute.path,
        RestoreBusinessLease.leaseDirectoryName,
        RestoreBusinessLease.lockFileName,
      );
      if (lease.isClosed ||
          !p.equals(lease.lockFile.absolute.path, expectedLeasePath)) {
        throw StateError('restore_startup_business_lease');
      }
      final workspaceLock = RestoreWorkspaceLock(
        appDataDirectory: appDataDirectory,
        durability: resolvedDurability,
      );
      await workspaceLock.synchronized(() async {
        // A reset supersedes the entire interrupted restore. Preserve its
        // evidence outside admission, so a published candidate cannot replace
        // the fresh database on the next launch. Keep admission blocked until
        // both the new database and installation receipt are durable.
        await workspaceLock.beginSnapshotRecoveryWhileLocked();
        // A process exit between Hive renames must remain behind the durable
        // barrier. A later explicit reset resumes retirement before admission,
        // instead of migrating the remaining, incomplete set of legacy boxes.
        await _retainLegacyHiveFiles(appDataDirectory, resolvedDurability);
        await DatabaseFamilyPreserver.prepareExplicitRecovery(
          appDataDirectory,
          recoveryBarrier: File(
            p.join(
              appDataDirectory.path,
              RestoreWorkspaceLock.snapshotRecoveryMarkerName,
            ),
          ),
          durability: resolvedDurability,
          retireExistingFamilies: true,
        );
        await _sweepReceiptTemporaries(appDataDirectory);
        final receipts = Directory(
          p.join(
            appDataDirectory.path,
            '.kelivo_retained_receipts_${DateTime.now().microsecondsSinceEpoch}',
          ),
        );
        await for (final entity in appDataDirectory.list(followLinks: false)) {
          final name = p.basename(entity.path);
          if (entity is File &&
              name.startsWith(_receiptPrefix) &&
              name.endsWith(_receiptSuffix)) {
            await receipts.create(recursive: true);
            await resolvedDurability.renameAndSync(
              source: entity,
              targetPath: p.join(receipts.path, name),
            );
          }
        }
        // An explicit fresh start still preserves the previous database family.
        await DatabaseInstallationGate.rebuildFresh(
          appDataDirectory: appDataDirectory,
          durability: resolvedDurability,
          preserveDisplacedCopy: true,
        );
        await EmptyDatabaseRecoveryGuard.acknowledge(appDataDirectory);
        await workspaceLock.finishSnapshotRecoveryWhileLocked();
      });
    } finally {
      await ownedLease?.close();
    }
  }

  static Future<void> _retainLegacyHiveFiles(
    Directory root,
    RestoreDurability durability,
  ) async {
    for (final name in ['conversations', 'messages', 'tool_events_v1']) {
      for (final extension in ['hive', 'lock']) {
        final file = File(p.join(root.path, '$name.$extension'));
        final type = await FileSystemEntity.type(file.path, followLinks: false);
        if (type == FileSystemEntityType.notFound) continue;
        if (type != FileSystemEntityType.file) {
          throw StateError('startup_recovery_hive_type');
        }
        var destination = '${file.path}.retired';
        if (await FileSystemEntity.type(destination, followLinks: false) !=
            FileSystemEntityType.notFound) {
          destination = '$destination-${const Uuid().v4()}';
        }
        await durability.renameAndSync(source: file, targetPath: destination);
      }
    }
  }

  static Future<List<Directory>> _exportRoots(
    Directory root,
    List<Directory> additional,
  ) async {
    final paths = <String>{};
    final result = <Directory>[];
    for (final directory in [
      root,
      await AppDirectories.contentDirectoryFor(root),
      ...additional,
    ]) {
      if (!paths.add(p.normalize(directory.absolute.path))) continue;
      final type = await FileSystemEntity.type(
        directory.path,
        followLinks: false,
      );
      if (type == FileSystemEntityType.notFound) continue;
      if (type != FileSystemEntityType.directory) {
        throw StateError('startup_recovery_source_type');
      }
      result.add(directory);
    }
    return result;
  }

  static Future<void> _copyDirectory(Directory source, Directory target) async {
    await for (final entity in source.list(followLinks: false)) {
      final name = p.basename(entity.path);
      final destinationPath = p.join(target.path, name);
      if (entity is Directory) {
        final childTarget = Directory(destinationPath);
        await childTarget.create(recursive: true);
        await _copyDirectory(entity, childTarget);
      } else if (entity is File) {
        await entity.copy(destinationPath);
      }
      // Links and other special entities are intentionally skipped.
    }
  }

  static Future<void> _sweepReceiptTemporaries(Directory directory) async {
    await for (final entity in directory.list(followLinks: false)) {
      final name = p.basename(entity.path);
      if (name.startsWith(_temporaryPrefix) &&
          name.endsWith(_temporarySuffix)) {
        await _deleteFileIfPresent(entity.path);
      }
    }
  }

  static Future<void> _sweepRestoreWorkspaceJunk(Directory directory) async {
    final workspace = Directory(p.join(directory.path, _restoreWorkspaceName));
    if (!await workspace.exists()) return;
    await for (final entity in workspace.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File && _junkFileNames.contains(p.basename(entity.path))) {
        await _deleteFileIfPresent(entity.path);
      }
    }
  }

  static Future<void> _archiveUnparseableReceipts(
    Directory directory,
    RestoreDurability durability,
  ) async {
    final archive = Directory(
      p.join(
        directory.path,
        '.kelivo_retained_receipts_${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
    await for (final entity in directory.list(followLinks: false)) {
      final name = p.basename(entity.path);
      if (!name.startsWith(_receiptPrefix) || !name.endsWith(_receiptSuffix)) {
        continue;
      }
      if (await FileSystemEntity.type(entity.path, followLinks: false) !=
          FileSystemEntityType.file) {
        continue;
      }
      final file = File(entity.path);
      var valid = false;
      try {
        DatabaseInstallationReceipt.fromJson(
          jsonDecode(await file.readAsString()),
        );
        valid = true;
      } catch (_) {
        valid = false;
      }
      if (!valid) {
        await archive.create(recursive: true);
        await durability.renameAndSync(
          source: file,
          targetPath: p.join(archive.path, name),
        );
      }
    }
  }

  static Future<void> _deleteFileIfPresent(String path) async {
    try {
      if (await FileSystemEntity.type(path, followLinks: false) ==
          FileSystemEntityType.file) {
        await File(path).delete();
      }
    } catch (_) {
      // Best-effort: an undeletable junk/temp file does not block admission,
      // which uses unique temp names and adopts the database identity.
    }
  }

  /// The installed database file name, exposed so the failure screen can note
  /// what a reset will remove.
  static String get databaseFileName => AppDatabase.databaseFileName;
}

/// File-level diagnostics helpers for the pre-initialization failure screen.
///
/// Separate from [StartupRecoveryService] because nothing here changes app
/// state: these only read the data directory, or write into a log folder the
/// app never reads back during startup.
final class StartupDiagnosticsService {
  StartupDiagnosticsService._();

  static const _logDirectoryName = 'logs';
  static const _reportPrefix = 'startup_failure_';
  // .txt so the in-app log viewer, which lists that extension, picks these up
  // once the app starts successfully again.
  static const _reportSuffix = '.txt';

  /// How many failure reports to keep. Enough to compare a repeat failure
  /// against the first one, few enough to never matter for disk use.
  static const retainedReports = 5;

  /// Persists [text] so the failure survives the restart that follows it, and
  /// can be read later from the in-app log viewer or a file manager.
  ///
  /// Best effort by design: a report that cannot be written must never make a
  /// failing startup worse, so the caller gets null instead of an exception.
  static Future<File?> writeFailureReport({
    required Directory appDataDirectory,
    required String text,
    DateTime Function()? clock,
  }) async {
    try {
      final directory = Directory(
        p.join(
          (await AppDirectories.contentDirectoryFor(appDataDirectory)).path,
          _logDirectoryName,
        ),
      );
      await directory.create(recursive: true);
      final stamp = (clock?.call() ?? DateTime.now())
          .toUtc()
          .toIso8601String()
          .replaceAll(RegExp(r'[:.]'), '-');
      final file = File(
        p.join(directory.path, '$_reportPrefix$stamp$_reportSuffix'),
      );
      await file.writeAsString(text, flush: true);
      await _pruneReports(directory);
      return file;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _pruneReports(Directory directory) async {
    try {
      final reports = <File>[];
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        if (name.startsWith(_reportPrefix) && name.endsWith(_reportSuffix)) {
          reports.add(entity);
        }
      }
      if (reports.length <= retainedReports) return;
      reports.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
      for (final stale in reports.take(reports.length - retainedReports)) {
        try {
          await stale.delete();
        } catch (_) {
          // A report we cannot delete is harmless; it only costs disk space.
        }
      }
    } catch (_) {
      // Pruning is housekeeping, never a reason to lose the report we wrote.
    }
  }

  /// Zips the whole app data directory into [workingDirectory] and returns the
  /// archive, so mobile platforms — which cannot be handed a destination
  /// folder — can still salvage everything through a share sheet.
  ///
  /// [workingDirectory] must live outside [appDataDirectory]; otherwise the
  /// archive would try to contain itself.
  static Future<File> createDataArchive({
    required Directory appDataDirectory,
    required Directory workingDirectory,
    DateTime Function()? clock,
    List<Directory> additionalDataDirectories = const [],
  }) async {
    final roots = await StartupRecoveryService._exportRoots(
      appDataDirectory,
      additionalDataDirectories,
    );
    if (roots.isEmpty) {
      throw StateError('startup_recovery_source_missing');
    }
    final workingPath = p.normalize(workingDirectory.absolute.path);
    if (roots.any(
      (root) =>
          p.equals(root.absolute.path, workingPath) ||
          p.isWithin(root.absolute.path, workingPath),
    )) {
      throw StateError('startup_recovery_export_inside_source');
    }
    await workingDirectory.create(recursive: true);
    final stamp = (clock?.call() ?? DateTime.now())
        .toUtc()
        .toIso8601String()
        .replaceAll(RegExp(r'[:.]'), '-');
    final archive = File(
      p.join(workingDirectory.path, 'kelivo-data-$stamp.zip'),
    );
    if (await archive.exists()) {
      throw StateError('startup_recovery_export_collision');
    }
    final encoder = ZipFileEncoder();
    if (additionalDataDirectories.isEmpty && roots.length == 1) {
      await encoder.zipDirectory(
        roots.single,
        filename: archive.path,
        followLinks: false,
      );
    } else {
      encoder.create(archive.path);
      try {
        for (var i = 0; i < roots.length; i++) {
          await for (final file in roots[i].list(
            recursive: true,
            followLinks: false,
          )) {
            if (file is File) {
              await encoder.addFile(
                file,
                'data-$i/${p.relative(file.path, from: roots[i].path)}',
              );
            }
          }
        }
      } finally {
        await encoder.close();
      }
    }
    return archive;
  }

  /// Runs SQLite's own consistency checks against the installed database.
  ///
  /// This is the one probe expensive enough to be user-initiated: both
  /// pragmas scan the whole file. It answers the question the failure screen
  /// otherwise cannot — whether the data is intact and the fault is in the
  /// admission logic, or the file itself is damaged.
  static Future<StartupIntegrityResult> checkIntegrity({
    required Directory appDataDirectory,
  }) async {
    final file = File(
      p.join(appDataDirectory.path, AppDatabase.databaseFileName),
    );
    if (!await file.exists()) {
      return const StartupIntegrityResult(
        databasePresent: false,
        quickCheck: null,
        foreignKeyViolations: null,
      );
    }
    final temporary = await Directory.systemTemp.createTemp(
      'kelivo-integrity-',
    );
    sqlite.Database? database;
    try {
      final copied = File(p.join(temporary.path, AppDatabase.databaseFileName));
      for (final suffix in ['', '-wal', '-shm', '-journal']) {
        final member = File('${file.path}$suffix');
        if (await FileSystemEntity.type(member.path, followLinks: false) ==
            FileSystemEntityType.file) {
          await member.copy('${copied.path}$suffix');
        }
      }
      database = sqlite.sqlite3.open(copied.path);
      final quickCheck = database
          .select('PRAGMA quick_check;')
          .map((row) => row.values.first?.toString() ?? '')
          .where((line) => line.isNotEmpty)
          .toList(growable: false);
      final foreignKeys = database.select('PRAGMA foreign_key_check;').length;
      return StartupIntegrityResult(
        databasePresent: true,
        quickCheck: quickCheck,
        foreignKeyViolations: foreignKeys,
      );
    } finally {
      database?.close();
      await temporary.delete(recursive: true);
    }
  }
}

/// Outcome of [StartupDiagnosticsService.checkIntegrity].
final class StartupIntegrityResult {
  const StartupIntegrityResult({
    required this.databasePresent,
    required this.quickCheck,
    required this.foreignKeyViolations,
  });

  final bool databasePresent;

  /// SQLite's `quick_check` output; a single `ok` means no damage was found.
  final List<String>? quickCheck;
  final int? foreignKeyViolations;

  bool get isHealthy =>
      databasePresent &&
      quickCheck != null &&
      quickCheck!.length == 1 &&
      quickCheck!.single == 'ok' &&
      foreignKeyViolations == 0;

  String describe() {
    if (!databasePresent) return 'database file missing';
    final checks = quickCheck ?? const <String>[];
    final buffer = StringBuffer()
      ..write(
        'quick_check: ${checks.isEmpty ? 'no output' : checks.join('; ')}',
      )
      ..write(
        ' · foreign_key_check: ${foreignKeyViolations ?? '?'} violation(s)',
      );
    return buffer.toString();
  }
}
