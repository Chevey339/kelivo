import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../services/backup/restore_durability.dart';
import 'app_database.dart';
import 'database_installation_gate.dart';

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
  }) async {
    if (!await appDataDirectory.exists()) {
      throw StateError('startup_recovery_source_missing');
    }
    // A destination inside the data directory would make the copy recurse
    // into itself (the target shows up while the source is being listed).
    final sourcePath = p.normalize(appDataDirectory.absolute.path);
    final destinationPath = p.normalize(destinationParent.absolute.path);
    if (destinationPath == sourcePath ||
        p.isWithin(sourcePath, destinationPath)) {
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
    await _copyDirectory(appDataDirectory, target);
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
    await _sweepReceiptTemporaries(appDataDirectory);
    await _sweepRestoreWorkspaceJunk(appDataDirectory);
    await _deleteUnparseableReceipts(appDataDirectory);
    // Adopting the identity lets a receipt that was deleted (because it was
    // unparseable) or that mismatches be rewritten from the live database. A
    // user electing to repair is implicitly trusting the database on disk.
    await DatabaseInstallationGate.ensureReady(
      appDataDirectory: appDataDirectory,
      allowDatabaseIdentityChange: true,
      durability: durability,
    );
  }

  /// Deletes the installed database family and installation receipts and
  /// re-runs first-launch setup. Destructive: the current database is lost.
  /// Callers must confirm with the user and should offer [exportDataCopy]
  /// first.
  static Future<void> reset({
    required Directory appDataDirectory,
    RestoreDurability? durability,
  }) async {
    // Remove installation receipts (and any temps) first: rebuildFresh only
    // recreates the database family, and admission rejects a receipt whose
    // database has been rebuilt. Clearing them lets a fresh identity issue
    // cleanly.
    await _sweepReceiptTemporaries(appDataDirectory);
    await for (final entity in appDataDirectory.list(followLinks: false)) {
      final name = p.basename(entity.path);
      if (name.startsWith(_receiptPrefix) && name.endsWith(_receiptSuffix)) {
        await _deleteFileIfPresent(entity.path);
      }
    }
    await DatabaseInstallationGate.rebuildFresh(
      appDataDirectory: appDataDirectory,
      durability: durability,
    );
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

  static Future<void> _deleteUnparseableReceipts(Directory directory) async {
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
        await _deleteFileIfPresent(entity.path);
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
        p.join(appDataDirectory.path, _logDirectoryName),
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
  }) async {
    if (!await appDataDirectory.exists()) {
      throw StateError('startup_recovery_source_missing');
    }
    final sourcePath = p.normalize(appDataDirectory.absolute.path);
    final workingPath = p.normalize(workingDirectory.absolute.path);
    if (workingPath == sourcePath || p.isWithin(sourcePath, workingPath)) {
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
    await encoder.zipDirectory(
      appDataDirectory,
      filename: archive.path,
      followLinks: false,
    );
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
    final database = sqlite.sqlite3.open(
      file.absolute.path,
      mode: sqlite.OpenMode.readOnly,
    );
    try {
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
      database.close();
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
