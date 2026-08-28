import 'dart:io';

import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'app_database.dart';

/// The result of considering a database file for upgrade.
///
/// [upgraded] is false when the file was already at [toVersion], in which case
/// nothing was written.
typedef DatabaseUpgradeOutcome = ({
  int fromVersion,
  int toVersion,
  bool upgraded,
});

/// Runs drift's schema migrator against a SQLite file.
///
/// This is the single place that turns a published-but-older database into the
/// current schema. It is deliberately unaware of policy: it takes no backup,
/// validates nothing afterwards, and leaves durability to the caller.
/// [ChatDatabaseRepository.migrateInstalledDatabase] wraps it with the
/// backup/verify/rollback policy the installed database needs; the restore
/// pipeline calls it directly because a staged snapshot is already a
/// disposable copy.
///
/// ## Adding a schema version
///
/// 1. Edit the table DSL in [AppDatabase]. Append new columns at the **end** of
///    a table — `ChatDatabaseRepository` validates column order exactly, and
///    only an appended column makes `ALTER TABLE ADD COLUMN` agree with
///    `createAll`.
/// 2. Bump `AppDatabase.currentSchemaVersion` and add the new number to
///    `AppDatabase.publishedSchemaVersions`.
/// 3. Regenerate, then commit every product:
///    - `dart run build_runner build`
///    - `dart run drift_dev schema dump lib/core/database/app_database.dart drift_schemas/app_database/`
///    - `dart run drift_dev schema generate drift_schemas/app_database/ test/core/database/generated_schema/`
///    - `dart run drift_dev schema steps drift_schemas/app_database/ lib/core/database/schema_versions.dart`
///    Already-published `drift_schema_vN.json` files are frozen: never re-dump
///    one in place, or the migration it anchors stops describing what shipped.
/// 4. Add the `fromNToN+1` callback to the `stepByStep` call in
///    `AppDatabase.migration`.
/// 5. Append the new column names to the matching list in
///    `ChatDatabaseRepository._validateRawSchema`.
///
/// Watch out for one `stepByStep` trap: **new indexes are not created
/// automatically**. A step that introduces a `@TableIndex` must call
/// `m.create(schema.idxWhatever)` itself.
///
/// Also reconsider [minimumReadableSchemaVersion] below: leaving it behind is
/// what lets an older build still read the new backups, and that is only safe
/// while the change is purely additive.
///
/// ## The other version, and the trap that connects them
///
/// The schema version governs the SQLite payload. The **archive** format —
/// entry names and manifest fields — has its own version, `DataSync`'s
/// `_backupFormatVersion`, with its own declaration next to it. The two move
/// independently: a release can add an ignorable directory to backups without
/// touching the schema, and a settings-only backup has no schema at all. Bump
/// and declare each on its own.
///
/// The recurring mistake in both of them, and in
/// `ChatDatabaseRepository.classifyInstalledDatabase`, is judging a newer
/// build's output by this build's vocabulary. Before adding any "is this
/// something I recognise" test, decide which way being wrong fails: refusing
/// to act is recoverable, overwriting or deleting is not.
/// How a backup's declared schema relates to what this build can read.
enum BackupSchemaVerdict {
  /// Written by this exact schema; restore as-is.
  current,

  /// Written by an older published schema; migrate it forward.
  needsUpgrade,

  /// Written by a newer schema that declares this build can still read it.
  /// Restore after stripping what this build does not know.
  forwardCompatible,

  /// Written by a newer schema that made no compatibility declaration, so
  /// whether it is readable is unknown. Restorable only with the user's
  /// informed consent.
  forwardUndeclared,

  /// Cannot be read: either a newer schema that declares it needs a newer
  /// build, or a version this build has never heard of.
  unreadable,
}

final class SchemaMigrations {
  SchemaMigrations._();

  /// Manifest key naming the oldest schema that can still read a backup.
  ///
  /// Written by every build that understands forward compatibility. A build
  /// whose [AppDatabase.currentSchemaVersion] is at least this value may
  /// restore the backup after normalizing away what it does not know.
  static const minimumReadableManifestKey = 'minimumReadableSchemaVersion';

  /// The oldest schema that can read a backup written by this build.
  ///
  /// Forward compatibility only started at schema 2 — schema 1 builds reject
  /// anything but their own version — so this can never usefully be lower.
  ///
  /// Raise this to [AppDatabase.currentSchemaVersion] in any release whose
  /// schema change is NOT purely additive: a renamed or repurposed column, a
  /// new value in an existing column that older builds would misread, or a
  /// tightened constraint. Leaving it low in that case lets an older build
  /// silently import data it misunderstands.
  static const minimumReadableSchemaVersion = 2;

  /// Classifies a backup from its manifest.
  ///
  /// [declaredMinimumReadable] is the manifest's
  /// [minimumReadableManifestKey], or null for a backup written before that
  /// key existed (or by a build that omitted it).
  static BackupSchemaVerdict classifyBackup({
    required int schemaVersion,
    int? declaredMinimumReadable,
  }) {
    final current = AppDatabase.currentSchemaVersion;
    if (schemaVersion == current) return BackupSchemaVerdict.current;
    if (schemaVersion < current) {
      return isPublished(schemaVersion)
          ? BackupSchemaVerdict.needsUpgrade
          // An unpublished version below ours never shipped; refuse rather
          // than guess what it is.
          : BackupSchemaVerdict.unreadable;
    }
    if (declaredMinimumReadable == null) {
      return BackupSchemaVerdict.forwardUndeclared;
    }
    return declaredMinimumReadable <= current
        ? BackupSchemaVerdict.forwardCompatible
        : BackupSchemaVerdict.unreadable;
  }

  /// Whether [version] is a schema this app has ever shipped.
  static bool isPublished(int version) =>
      AppDatabase.publishedSchemaVersions.contains(version);

  /// Whether a file at [version] can and must be upgraded before use.
  static bool needsUpgrade(int version) =>
      isPublished(version) && version < AppDatabase.currentSchemaVersion;

  /// Reads `PRAGMA user_version` without otherwise touching [file].
  static int readSchemaVersion(File file) {
    final database = sqlite.sqlite3.open(
      file.absolute.path,
      mode: sqlite.OpenMode.readOnly,
    );
    try {
      return database.userVersion;
    } finally {
      database.close();
    }
  }

  /// Upgrades [file] to [AppDatabase.currentSchemaVersion] in place.
  ///
  /// A file already at the current schema is left untouched. Anything newer or
  /// unpublished throws `StateError('database_schema_version')`.
  ///
  /// Atomicity comes from drift: `onUpgrade` and the `PRAGMA user_version`
  /// write share one transaction, so a crash leaves the file either wholly at
  /// the old schema or wholly at the new one.
  static Future<DatabaseUpgradeOutcome> upgradeFileInPlace(File file) async {
    final installed = readSchemaVersion(file);
    if (installed == AppDatabase.currentSchemaVersion) {
      return (fromVersion: installed, toVersion: installed, upgraded: false);
    }
    if (!needsUpgrade(installed)) {
      throw StateError('database_schema_version');
    }

    final database = AppDatabase(AppDatabase.upgradeExecutor(file));
    try {
      // Forces the executor open, which is what runs the migrator.
      await database.customSelect('SELECT 1;').getSingle();
      // Fold the upgrade back into the main file so the caller sees a
      // self-contained database, and so a snapshot keeps no sidecars.
      await database.customStatement('PRAGMA wal_checkpoint(TRUNCATE);');
    } finally {
      await database.close();
    }

    final resulting = readSchemaVersion(file);
    if (resulting != AppDatabase.currentSchemaVersion) {
      throw StateError('database_schema_version');
    }
    return (fromVersion: installed, toVersion: resulting, upgraded: true);
  }
}
