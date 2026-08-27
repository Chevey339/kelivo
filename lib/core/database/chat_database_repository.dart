import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:uuid/uuid.dart';

import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../models/message_part.dart';
import '../utils/multimodal_input_utils.dart';
import '../../utils/sandbox_path_resolver.dart';
import '../../utils/kelivo_file_uri.dart';
import '../models/memory_entry.dart';
import '../models/user_profile_field.dart';
import 'app_database.dart';
import 'business_data.dart';
import 'business_repository.dart';
import 'chat_database_observer.dart';
import 'generation_run.dart';
import 'generation_run_commands.dart';
import 'schema_migrations.dart';
import '../services/api/stream/stream_chunk_handler.dart';
import '../services/backup/restore_durability.dart';

typedef ChatDatabaseSnapshotInfo = ({
  int schemaVersion,
  int conversationCount,
  int messageCount,
});

typedef InstalledChatDatabaseInfo = ({int schemaVersion, String? databaseId});

/// What crash recovery is allowed to do with the installed database.
///
/// The distinction that matters is between damage and a version this build
/// simply does not know: a pre-migration copy may replace the former, but
/// replacing the latter would let an older build silently overwrite everything
/// a newer one wrote.
enum InstalledDatabaseDisposition {
  /// Opens cleanly at a schema this build knows. Any pre-migration copy beside
  /// it is redundant and may be deleted.
  usable,

  /// Opens, but at a schema this build does not know — in practice, a
  /// downgrade after a newer build migrated the database. Nothing may be
  /// deleted or overwritten: the copy is older than what is on disk, and the
  /// startup gate reports `database_schema_too_new` so the user updates
  /// instead.
  foreignSchema,

  /// Missing, truncated, or failing `quick_check`. A pre-migration copy is the
  /// better state.
  unusable,
}

typedef ParsedChatImportBatch = ({
  Conversation conversation,
  List<ChatMessage> messages,
});

final class LinearMessageWindowSlot {
  const LinearMessageWindowSlot({
    required this.groupId,
    required this.revisionId,
    required this.versionCount,
    required this.logicalIndex,
  });

  final String groupId;
  final String revisionId;
  final int versionCount;
  final int logicalIndex;
}

final class LinearMessageWindow {
  const LinearMessageWindow({
    required this.slots,
    required this.totalSlotCount,
    required this.hasMoreBefore,
    required this.hasMoreAfter,
  });

  final List<LinearMessageWindowSlot> slots;
  final int totalSlotCount;
  final bool hasMoreBefore;
  final bool hasMoreAfter;
}

typedef AppendedMessageVersion = ({
  Conversation conversation,
  ChatMessage message,
});

typedef DeletedMessagesResult = ({
  Conversation conversation,
  List<ChatMessage> messages,
});

typedef GenerationBeginResult = ({
  Conversation conversation,
  ChatMessage? userMessage,
  ChatMessage assistantMessage,
  GenerationRun run,
});

class BackupMergeReport {
  const BackupMergeReport({
    required this.importedConversations,
    required this.deduplicatedConversations,
    required this.skippedConversations,
    required this.remappedConversationIds,
    this.importedConversationIds = const <String>[],
  });

  final int importedConversations;
  final int deduplicatedConversations;
  final int skippedConversations;
  final Map<String, String> remappedConversationIds;

  /// Target conversation ids newly inserted by this merge (post-remap ids).
  final List<String> importedConversationIds;

  int get remappedConversations => remappedConversationIds.length;
}

class SandboxPathMigrationResult {
  const SandboxPathMigrationResult({
    required this.ran,
    required this.scannedMessages,
    required this.updatedMessages,
    required this.skippedParts,
  });

  final bool ran;
  final int scannedMessages;
  final int updatedMessages;
  final int skippedParts;
}

class ChatDatabaseRepository {
  ChatDatabaseRepository(
    this._db, {
    File? databaseFile,
    ChatDatabaseObserver? observer,
  }) : _databaseFile = databaseFile?.absolute,
       _observer = observer ?? ChatDatabaseObserver.instance;

  final AppDatabase _db;
  final File? _databaseFile;
  final ChatDatabaseObserver _observer;
  bool _messageSearchFtsReady = false;

  static ChatDatabaseRepository open({
    File? file,
    ChatDatabaseObserver? observer,
  }) {
    final db = AppDatabase.open(file: file);
    return ChatDatabaseRepository(db, databaseFile: file, observer: observer);
  }

  Future<GenerationRun> createGenerationRun({
    required String id,
    required String conversationId,
    required String targetRevisionId,
    required DateTime createdAt,
  }) => GenerationRunCommands(_db).create(
    id: id,
    conversationId: conversationId,
    targetRevisionId: targetRevisionId,
    createdAt: createdAt,
  );

  Future<GenerationRun?> getGenerationRun(String id) =>
      GenerationRunCommands(_db).get(id);

  Future<GenerationRun> transitionGenerationRun({
    required String id,
    required GenerationRunState expectedState,
    required int expectedStateRevision,
    required GenerationRunState nextState,
    required DateTime updatedAt,
    String? errorCode,
  }) => GenerationRunCommands(_db).transition(
    id: id,
    expectedState: expectedState,
    expectedStateRevision: expectedStateRevision,
    nextState: nextState,
    updatedAt: updatedAt,
    errorCode: errorCode,
  );

  Future<GenerationRun> checkpointGenerationRun({
    required String id,
    required String targetRevisionId,
    required int checkpointSeq,
    required DateTime updatedAt,
  }) => GenerationRunCommands(_db).checkpoint(
    id: id,
    targetRevisionId: targetRevisionId,
    checkpointSeq: checkpointSeq,
    updatedAt: updatedAt,
  );

  Future<GenerationRun> finalizeGenerationRun({
    required ChatMessage message,
    required List<Map<String, dynamic>> toolEvents,
    required String generationRunId,
    required GenerationRunState expectedState,
    required int expectedStateRevision,
    required GenerationRunState terminalState,
    int? checkpointSeq,
    String? errorCode,
  }) {
    if (!terminalState.isTerminal) {
      throw ArgumentError.value(terminalState, 'terminalState');
    }
    return _observer.measure(
      ChatDatabaseOperation.commandFinalCheckpoint,
      () => _db.transaction(() async {
        await _updateStreamingCheckpoint(
          message,
          toolEvents,
          generationRunId: checkpointSeq == null ? null : generationRunId,
          checkpointSeq: checkpointSeq,
        );
        return GenerationRunCommands(_db).transition(
          id: generationRunId,
          expectedState: expectedState,
          expectedStateRevision: expectedStateRevision,
          nextState: terminalState,
          updatedAt: DateTime.now().toUtc(),
          errorCode: errorCode,
        );
      }),
    );
  }

  /// Strips a database written by a NEWER build down to the shape this build
  /// knows, so a forward-compatible backup can still be restored.
  ///
  /// Drops tables this build does not know, drops unknown columns from tables
  /// it does know, and stamps [AppDatabase.currentSchemaVersion]. Afterwards
  /// the ordinary validators see an exact current-schema database, which is
  /// what keeps them single-version.
  ///
  /// This only reconciles *structure*. It cannot detect a newer build changing
  /// what an existing column MEANS — that is what the manifest's
  /// `minimumReadableSchemaVersion` declaration is for. Callers must have
  /// established permission to proceed before calling this.
  ///
  /// Operates on a staged copy; the archive itself is never touched, so the
  /// data dropped here is still present if the same backup is later restored
  /// into a build that understands it.
  static Future<void> normalizeForwardCompatibleSnapshot(File file) async {
    final database = sqlite.sqlite3.open(file.absolute.path);
    try {
      // Foreign keys stay off for the rewrite: dropping an unknown table can
      // transiently orphan rows in another unknown table dropped later.
      database.execute('PRAGMA foreign_keys = OFF;');
      database.execute('BEGIN IMMEDIATE;');
      try {
        final presentTables = database
            .select("SELECT name FROM sqlite_master WHERE type = 'table';")
            .map((row) => row['name'])
            .whereType<String>()
            .where((name) => !name.startsWith('sqlite_'))
            .toList(growable: false);

        for (final table in presentTables) {
          if (!currentSchemaColumns.containsKey(table)) {
            database.execute('DROP TABLE IF EXISTS "$table";');
          }
        }

        for (final entry in currentSchemaColumns.entries) {
          if (!presentTables.contains(entry.key)) continue;
          final known = entry.value.toSet();
          final actual = database
              .select('PRAGMA table_info("${entry.key}");')
              .map((row) => row['name'])
              .whereType<String>()
              .toList(growable: false);
          for (final column in actual) {
            if (known.contains(column)) continue;
            // Any index over the column has to go first; SQLite refuses to
            // drop an indexed column.
            final indexes = database
                .select('PRAGMA index_list("${entry.key}");')
                .map((row) => row['name'])
                .whereType<String>()
                .toList(growable: false);
            for (final index in indexes) {
              if (index.startsWith('sqlite_autoindex_')) continue;
              final covers = database
                  .select('PRAGMA index_info("$index");')
                  .map((row) => row['name'])
                  .whereType<String>()
                  .contains(column);
              if (covers) database.execute('DROP INDEX IF EXISTS "$index";');
            }
            database.execute(
              'ALTER TABLE "${entry.key}" DROP COLUMN "$column";',
            );
          }
        }

        database.execute('COMMIT;');
      } catch (_) {
        database.execute('ROLLBACK;');
        rethrow;
      }
      // Only after the structure matches, so a crash mid-rewrite leaves a file
      // still stamped with its original (rejected) version rather than a lie.
      database.userVersion = AppDatabase.currentSchemaVersion;
      database.execute('PRAGMA foreign_keys = ON;');
      if (database.select('PRAGMA foreign_key_check;').isNotEmpty) {
        throw StateError('database_forward_compat_foreign_keys');
      }
    } on sqlite.SqliteException {
      throw StateError('database_forward_compat_failed');
    } finally {
      database.close();
    }
    await normalizeSnapshotJournal(file);
  }

  /// Suffix of the copy kept while an installed database is being upgraded.
  ///
  /// The version is part of the name so a sweep can recognise leftovers from a
  /// crash without opening them.
  static const premigrationBackupPrefix = '.premigrate-v';

  /// Brings the installed database at [file] up to the current schema.
  ///
  /// A file already at [AppDatabase.currentSchemaVersion] is validated and left
  /// untouched — this is the every-launch path and performs no writes. A file
  /// at an older published schema is copied aside, upgraded through
  /// [SchemaMigrations], re-validated, and the copy deleted; if any of that
  /// fails the copy is restored and `StateError('database_migration_failed:N')`
  /// is thrown. Anything newer or unpublished throws
  /// `StateError('database_schema_version')`.
  static Future<DatabaseUpgradeOutcome> migrateInstalledDatabase(
    File file, {
    RestoreDurability? durability,
  }) async {
    final int schemaVersion;
    try {
      schemaVersion = SchemaMigrations.readSchemaVersion(file);
    } on sqlite.SqliteException {
      throw StateError('database_corrupt');
    }

    if (schemaVersion == AppDatabase.currentSchemaVersion) {
      final database = sqlite.sqlite3.open(
        file.absolute.path,
        mode: sqlite.OpenMode.readOnly,
      );
      try {
        // Deliberately validated only at the current schema; see
        // _validateRawStructure.
        _validateRawStructure(database);
      } on sqlite.SqliteException {
        throw StateError('database_corrupt');
      } finally {
        database.close();
      }
      return (
        fromVersion: schemaVersion,
        toVersion: schemaVersion,
        upgraded: false,
      );
    }

    if (!SchemaMigrations.needsUpgrade(schemaVersion)) {
      throw StateError('database_schema_version');
    }

    final resolvedDurability = durability ?? RestorePlatformDurability();
    final parent = file.absolute.parent;
    final backup = File(
      '${file.absolute.path}$premigrationBackupPrefix$schemaVersion',
    );

    // Fold any WAL back in first so the copy is a self-contained database.
    try {
      final database = sqlite.sqlite3.open(file.absolute.path);
      try {
        database.execute('PRAGMA wal_checkpoint(TRUNCATE);');
      } finally {
        database.close();
      }
    } on sqlite.SqliteException {
      throw StateError('database_corrupt');
    }

    if (await backup.exists()) await backup.delete();
    await file.copy(backup.path);
    await resolvedDurability.restrictFile(backup);
    await resolvedDurability.syncFile(backup, fullBarrier: true);
    await resolvedDurability.syncDirectory(parent, fullBarrier: true);

    try {
      await SchemaMigrations.upgradeFileInPlace(file);
      final database = sqlite.sqlite3.open(
        file.absolute.path,
        mode: sqlite.OpenMode.readOnly,
      );
      try {
        _validateRawStructure(database);
      } finally {
        database.close();
      }
    } catch (_) {
      // The copy is deliberately LEFT BEHIND. Between deleting the database
      // family and finishing the copy back there is no usable database on
      // disk, so the copy is the only surviving good state and must outlive
      // this process: DatabaseInstallationGate's sweep finishes the rollback
      // on the next launch if we die here.
      await restorePreMigrationBackup(
        backup: backup,
        target: file,
        durability: resolvedDurability,
      );
      throw StateError('database_migration_failed:$schemaVersion');
    }

    await resolvedDurability.syncFile(file, fullBarrier: true);
    await backup.delete();
    await resolvedDurability.syncDirectory(parent, fullBarrier: true);

    return (
      fromVersion: schemaVersion,
      toVersion: AppDatabase.currentSchemaVersion,
      upgraded: true,
    );
  }

  static InstalledChatDatabaseInfo inspectInstalledDatabase(
    File file, {
    bool validateContents = false,
  }) {
    final database = sqlite.sqlite3.open(
      file.absolute.path,
      mode: sqlite.OpenMode.readOnly,
    );
    try {
      final schemaVersion = database.userVersion;
      if (schemaVersion > AppDatabase.currentSchemaVersion) {
        throw StateError('database_schema_too_new');
      }
      if (validateContents) {
        _validateRawSnapshot(database);
      } else {
        _validateRawStructure(database);
      }
      if (schemaVersion != AppDatabase.currentSchemaVersion) {
        throw StateError('database_schema_version');
      }
      final identityRows = database.select(
        'SELECT value FROM chat_storage_meta_rows WHERE key = ?;',
        [ChatStorageMetaKeys.databaseIdentity],
      );
      if (identityRows.length > 1) {
        throw StateError('database_identity_duplicate');
      }
      final databaseId = identityRows.isEmpty
          ? null
          : identityRows.single['value'] as String?;
      if (databaseId != null && !_isUuid(databaseId)) {
        throw StateError('database_identity_invalid');
      }
      return (schemaVersion: schemaVersion, databaseId: databaseId);
    } on sqlite.SqliteException {
      throw StateError('database_corrupt');
    } finally {
      database.close();
    }
  }

  static InstalledChatDatabaseInfo inspectUncleanInstalledDatabase(File file) {
    final database = sqlite.sqlite3.open(
      file.absolute.path,
      mode: sqlite.OpenMode.readOnly,
    );
    try {
      final quickCheckRows = database.select('PRAGMA quick_check;');
      if (quickCheckRows.length != 1 ||
          quickCheckRows.single.values.single != 'ok') {
        throw StateError('quick_check');
      }
      if (database.select('PRAGMA foreign_key_check;').isNotEmpty) {
        throw StateError('foreign_key_check');
      }
      _validateRawStructure(database);
      if (database.userVersion != AppDatabase.currentSchemaVersion) {
        throw StateError('database_schema_version');
      }
      final identityRows = database.select(
        'SELECT value FROM chat_storage_meta_rows WHERE key = ?;',
        [ChatStorageMetaKeys.databaseIdentity],
      );
      if (identityRows.length > 1) {
        throw StateError('database_identity_duplicate');
      }
      final databaseId = identityRows.isEmpty
          ? null
          : identityRows.single['value'] as String?;
      if (databaseId != null && !_isUuid(databaseId)) {
        throw StateError('database_identity_invalid');
      }
      return (schemaVersion: database.userVersion, databaseId: databaseId);
    } on sqlite.SqliteException {
      throw StateError('database_corrupt');
    } finally {
      database.close();
    }
  }

  static void assignInstalledDatabaseIdentity(File file, String databaseId) {
    if (!_isUuid(databaseId)) throw StateError('database_identity_invalid');
    final database = sqlite.sqlite3.open(file.absolute.path);
    try {
      database.execute('PRAGMA foreign_keys = ON;');
      database.execute('PRAGMA synchronous = FULL;');
      _validateRawStructure(database);
      if (database.userVersion != AppDatabase.currentSchemaVersion) {
        throw StateError('database_schema_version');
      }
      final existing = database.select(
        'SELECT value FROM chat_storage_meta_rows WHERE key = ?;',
        [ChatStorageMetaKeys.databaseIdentity],
      );
      if (existing.isNotEmpty && existing.single['value'] != databaseId) {
        throw StateError('database_identity_mismatch');
      }
      database.execute(
        'INSERT OR IGNORE INTO chat_storage_meta_rows (key, value) VALUES (?, ?);',
        [ChatStorageMetaKeys.databaseIdentity, databaseId],
      );
      database.execute('PRAGMA wal_checkpoint(TRUNCATE);');
    } on sqlite.SqliteException {
      throw StateError('database_corrupt');
    } finally {
      database.close();
    }
  }

  static bool _isUuid(String value) => RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  ).hasMatch(value);

  static Future<ChatDatabaseSnapshotInfo> createConsistentSnapshot({
    required File sourceFile,
    required File destinationFile,
    void Function(int handleAddress)? registerSourceHandle,
    Future<void> Function()? waitForSourceCloseAck,
  }) async {
    final sourcePath = sourceFile.absolute.path;
    final destinationPath = destinationFile.absolute.path;
    if (sourcePath == destinationPath) {
      throw ArgumentError.value(
        destinationFile.path,
        'destinationFile',
        'must differ from sourceFile',
      );
    }
    if (!await sourceFile.exists()) {
      throw FileSystemException('Source database does not exist', sourcePath);
    }

    await destinationFile.parent.create(recursive: true);
    await _deleteDatabaseFamily(destinationFile);

    try {
      final source = sqlite.sqlite3.open(sourcePath);
      try {
        source.execute('PRAGMA busy_timeout = 30000;');
        registerSourceHandle?.call(source.handle.address);
        // VACUUM INTO does not write the source. query_only is omitted because
        // SQLite rejects VACUUM INTO while query_only is ON.
        // Parent timeout/cancel calls sqlite3_interrupt on [source.handle]
        // before isolate.kill so a stuck step can return and release WAL.
        source.execute('VACUUM INTO ?', [destinationPath]);
      } finally {
        if (waitForSourceCloseAck != null) {
          await waitForSourceCloseAck();
        }
        source.close();
      }

      final snapshot = sqlite.sqlite3.open(destinationPath);
      try {
        return _validateRawSnapshot(snapshot);
      } finally {
        snapshot.close();
      }
    } catch (_) {
      await _deleteDatabaseFamily(destinationFile);
      rethrow;
    }
  }

  /// Prepares a snapshot for restore, bringing its schema to this build's.
  ///
  /// An older published schema is migrated forward. A NEWER schema is only
  /// accepted when [allowForwardCompatible] is set — the caller establishes
  /// that from the backup manifest's compatibility declaration, or from the
  /// user's explicit consent — and is then stripped down to what this build
  /// knows. See [normalizeForwardCompatibleSnapshot].
  static Future<ChatDatabaseSnapshotInfo> prepareSnapshotForRestore(
    File snapshotFile, {
    bool allowForwardCompatible = false,
  }) async {
    if (!await snapshotFile.exists()) {
      throw FileSystemException(
        'Snapshot database does not exist',
        snapshotFile.path,
      );
    }

    // A snapshot authored by an older build carries an older schema; bring it
    // forward before validating, because the validators only ever describe the
    // current schema. Migrating first is also what keeps the DELETE-mode
    // contract below intact: the upgrade may leave a WAL sidecar, and the tail
    // of this method checkpoints, switches to DELETE and deletes sidecars.
    final snapshotSchemaVersion = SchemaMigrations.readSchemaVersion(
      snapshotFile,
    );
    if (SchemaMigrations.needsUpgrade(snapshotSchemaVersion)) {
      await SchemaMigrations.upgradeFileInPlace(snapshotFile);
    } else if (snapshotSchemaVersion > AppDatabase.currentSchemaVersion) {
      if (!allowForwardCompatible) {
        throw StateError('database_schema_too_new');
      }
      await normalizeForwardCompatibleSnapshot(snapshotFile);
    } else if (snapshotSchemaVersion != AppDatabase.currentSchemaVersion) {
      throw StateError('database_schema_version');
    }

    final database = sqlite.sqlite3.open(snapshotFile.absolute.path);
    late final ChatDatabaseSnapshotInfo initialInfo;
    try {
      initialInfo = _validateRawSnapshot(database);
      // Now a post-condition: the migration above guarantees it.
      if (initialInfo.schemaVersion != AppDatabase.currentSchemaVersion) {
        throw StateError('database_schema_version');
      }
      database.execute('BEGIN IMMEDIATE;');
      try {
        database.execute(
          'UPDATE message_rows SET is_streaming = 0 '
          'WHERE is_streaming != 0;',
        );
        database.execute('DELETE FROM chat_storage_meta_rows WHERE key = ?;', [
          ChatStorageMetaKeys.activeStreamingIds,
        ]);
        database.execute(
          'INSERT OR REPLACE INTO chat_storage_meta_rows (key, value) '
          'VALUES (?, ?);',
          [ChatStorageMetaKeys.hiveMigrationComplete, 'true'],
        );
        database.execute('COMMIT;');
      } catch (_) {
        database.execute('ROLLBACK;');
        rethrow;
      }
      database.execute('PRAGMA wal_checkpoint(TRUNCATE);');
      database.select('PRAGMA journal_mode = DELETE;');
    } finally {
      database.close();
    }

    await _deleteDatabaseSidecars(snapshotFile);
    final reopenedInfo = await inspectPreparedSnapshot(snapshotFile);
    if (reopenedInfo != initialInfo) {
      throw StateError('snapshot_reopen_mismatch');
    }
    return initialInfo;
  }

  static Future<ChatDatabaseSnapshotInfo> inspectPreparedSnapshot(
    File snapshotFile,
  ) async {
    if (await FileSystemEntity.type(snapshotFile.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw FileSystemException(
        'Snapshot database is not a regular file',
        snapshotFile.path,
      );
    }
    await _requireNoDatabaseSidecars(snapshotFile);

    final database = sqlite.sqlite3.open(
      snapshotFile.absolute.path,
      mode: sqlite.OpenMode.readOnly,
    );
    var inspectionCompleted = false;
    try {
      final info = _validateRawSnapshot(database);
      if (info.schemaVersion != AppDatabase.currentSchemaVersion) {
        throw StateError('database_schema_version');
      }
      final streamingRows = database.select(
        'SELECT COUNT(*) AS count FROM message_rows WHERE is_streaming != 0;',
      );
      if (streamingRows.single['count'] != 0) {
        throw StateError('database_streaming_messages');
      }
      final activeStreamingRows = database.select(
        'SELECT value FROM chat_storage_meta_rows WHERE key = ?;',
        [ChatStorageMetaKeys.activeStreamingIds],
      );
      if (activeStreamingRows.isNotEmpty) {
        throw StateError('database_active_streaming_ids');
      }
      final migrationRows = database.select(
        'SELECT value FROM chat_storage_meta_rows WHERE key = ?;',
        [ChatStorageMetaKeys.hiveMigrationComplete],
      );
      if (migrationRows.length != 1 ||
          migrationRows.single['value'] != 'true') {
        throw StateError('database_migration_receipt');
      }
      inspectionCompleted = true;
      return info;
    } finally {
      database.close();
      if (inspectionCompleted) {
        await _requireNoDatabaseSidecars(snapshotFile);
      }
    }
  }

  static Future<void> _requireNoDatabaseSidecars(File databaseFile) async {
    for (final suffix in const ['-wal', '-shm', '-journal']) {
      final sidecar = File('${databaseFile.path}$suffix');
      if (await FileSystemEntity.type(sidecar.path, followLinks: false) !=
          FileSystemEntityType.notFound) {
        throw StateError('database_sidecar:$suffix');
      }
    }
  }

  static ChatDatabaseSnapshotInfo _validateRawSnapshot(
    sqlite.Database database,
  ) {
    final integrityRows = database.select('PRAGMA integrity_check;');
    if (integrityRows.length != 1 ||
        integrityRows.single.values.single != 'ok') {
      throw StateError('integrity_check');
    }
    if (database.select('PRAGMA foreign_key_check;').isNotEmpty) {
      throw StateError('foreign_key_check');
    }

    _validateRawStructure(database);

    return (
      schemaVersion: database.userVersion,
      conversationCount: _rawTableCount(database, 'conversation_rows'),
      messageCount: _rawTableCount(database, 'message_rows'),
    );
  }

  /// Validates that [database] matches the CURRENT schema exactly.
  ///
  /// It never validates a historical schema: callers must upgrade to
  /// [AppDatabase.currentSchemaVersion] first (see [SchemaMigrations]). Keeping
  /// this rule is what lets future migrations ship without version-aware
  /// validators.
  static void _validateRawStructure(sqlite.Database database) {
    if (database.userVersion != AppDatabase.currentSchemaVersion) {
      throw StateError('database_schema_version');
    }

    const requiredTables = {
      'conversation_rows',
      'conversation_mcp_server_rows',
      'message_rows',
      'chat_storage_meta_rows',
      'message_part_rows',
      'generation_run_rows',
      'provider_artifact_rows',
      'asset_rows',
      'message_asset_rows',
      'asset_gc_rows',
      'gc_audit_rows',
      'asset_reference_dirty_rows',
      'assistant_rows',
      'provider_rows',
      'provider_group_rows',
      'mcp_server_rows',
      'world_book_rows',
      'assistant_memory_rows',
      'quick_phrase_rows',
      'search_service_rows',
      'tts_service_rows',
      'instruction_injection_rows',
      'assistant_tag_rows',
      'preference_rows',
      'memory_entry_rows',
      'user_profile_field_rows',
      'message_prompt_rows',
    };
    final tableRows = database.select(
      "SELECT name FROM sqlite_master WHERE type = 'table';",
    );
    final tables = tableRows
        .map((row) => row['name'])
        .whereType<String>()
        .toSet();
    if (tables.intersection(const {
      'message_slot_rows',
      'message_revision_rows',
      'conversation_branch_rows',
      'conversation_state_rows',
    }).isNotEmpty) {
      throw StateError('retired_tables');
    }
    if (!tables.containsAll(requiredTables)) {
      throw StateError('required_tables');
    }
    _validateRawSchema(database);
  }

  /// Every table this build knows, with its exact column order.
  ///
  /// This is the authoritative shape of [AppDatabase.currentSchemaVersion]:
  /// [_validateRawSchema] asserts a database matches it exactly, and
  /// [normalizeForwardCompatibleSnapshot] strips a newer database down to it.
  /// Keep it in step with the table DSL — see SchemaMigrations for the
  /// checklist that a schema bump has to follow.
  static const currentSchemaColumns = <String, List<String>>{
    'conversation_rows': [
      'id',
      'title',
      'created_at',
      'updated_at',
      'is_pinned',
      'assistant_id',
      'truncate_index',
      'version_selections_json',
      'summary',
      'last_summarized_message_count',
      'chat_suggestions_json',
      'injected_memory_hash',
      'last_memory_extracted_order',
      'chat_model_provider',
      'chat_model_id',
    ],
    'conversation_mcp_server_rows': ['conversation_id', 'server_id', 'ordinal'],
    'message_rows': [
      'id',
      'conversation_id',
      'role',
      'timestamp',
      'model_id',
      'provider_id',
      'total_tokens',
      'is_streaming',
      'reasoning_start_at',
      'reasoning_finished_at',
      'translation',
      'reasoning_segments_json',
      'group_id',
      'version',
      'prompt_tokens',
      'completion_tokens',
      'cached_tokens',
      'duration_ms',
      'message_order',
    ],
    'chat_storage_meta_rows': ['key', 'value'],
    'message_part_rows': [
      'part_id',
      'conversation_id',
      'revision_id',
      'ordinal',
      'kind',
      'payload',
      'created_at',
      'updated_at',
    ],
    'generation_run_rows': [
      'id',
      'conversation_id',
      'target_revision_id',
      'state',
      'state_revision',
      'checkpoint_seq',
      'error_code',
      'created_at',
      'updated_at',
      'terminal_at',
    ],
    'provider_artifact_rows': [
      'conversation_id',
      'revision_id',
      'kind',
      'payload',
      'created_at',
      'updated_at',
    ],
    'asset_rows': [
      'id',
      'content_hash',
      'path',
      'byte_size',
      'width',
      'height',
      'thumbnail_path',
      'created_at',
      'last_referenced_at',
    ],
    'message_asset_rows': [
      'conversation_id',
      'revision_id',
      'asset_id',
      'kind',
    ],
    'asset_gc_rows': ['asset_id', 'not_before', 'attempts', 'generation'],
    'gc_audit_rows': ['id', 'kind', 'entity_id', 'completed_at'],
    'asset_reference_dirty_rows': ['revision_id'],
    'assistant_rows': ['id', 'sort_order', 'payload', 'updated_at'],
    'provider_rows': ['provider_key', 'sort_order', 'payload', 'updated_at'],
    'provider_group_rows': ['id', 'sort_order', 'payload', 'updated_at'],
    'mcp_server_rows': ['id', 'sort_order', 'payload', 'updated_at'],
    'world_book_rows': ['id', 'sort_order', 'payload', 'updated_at'],
    'assistant_memory_rows': [
      'id',
      'sort_order',
      'assistant_id',
      'payload',
      'updated_at',
    ],
    'quick_phrase_rows': ['id', 'sort_order', 'payload', 'updated_at'],
    'search_service_rows': ['id', 'sort_order', 'payload', 'updated_at'],
    'tts_service_rows': ['id', 'sort_order', 'payload', 'updated_at'],
    'instruction_injection_rows': ['id', 'sort_order', 'payload', 'updated_at'],
    'assistant_tag_rows': ['id', 'sort_order', 'payload', 'updated_at'],
    'preference_rows': ['key', 'value', 'updated_at'],
    'memory_entry_rows': [
      'id',
      'sort_order',
      'scope',
      'assistant_id',
      'type',
      'status',
      'content',
      'content_normalized',
      'entry_created_at',
      'entry_updated_at',
      'payload',
      'updated_at',
    ],
    'user_profile_field_rows': ['id', 'sort_order', 'payload', 'updated_at'],
    'message_prompt_rows': [
      'revision_id',
      'conversation_id',
      'payload',
      'carries_memory_snapshot',
      'created_at',
    ],
  };

  static void _validateRawSchema(sqlite.Database database) {
    const expectedColumns = currentSchemaColumns;
    for (final entry in expectedColumns.entries) {
      final tableInfo = database.select('PRAGMA table_info(${entry.key});');
      final actual = tableInfo
          .map((row) => row['name'])
          .whereType<String>()
          .toList(growable: false);
      if (!_sameOrderedStrings(actual, entry.value)) {
        throw StateError('table_schema:${entry.key}');
      }
    }

    const expectedPrimaryKeys = <String, List<String>>{
      'asset_rows': ['id'],
      'message_asset_rows': ['revision_id', 'asset_id', 'kind'],
      'asset_gc_rows': ['asset_id'],
      'gc_audit_rows': ['id'],
      'asset_reference_dirty_rows': ['revision_id'],
      'assistant_rows': ['id'],
      'provider_rows': ['provider_key'],
      'provider_group_rows': ['id'],
      'mcp_server_rows': ['id'],
      'world_book_rows': ['id'],
      'assistant_memory_rows': ['id'],
      'quick_phrase_rows': ['id'],
      'search_service_rows': ['id'],
      'tts_service_rows': ['id'],
      'instruction_injection_rows': ['id'],
      'assistant_tag_rows': ['id'],
      'preference_rows': ['key'],
      'memory_entry_rows': ['id'],
      'user_profile_field_rows': ['id'],
      'message_prompt_rows': ['revision_id'],
    };
    const sortOrderTables = {
      'assistant_rows',
      'provider_rows',
      'provider_group_rows',
      'mcp_server_rows',
      'world_book_rows',
      'assistant_memory_rows',
      'quick_phrase_rows',
      'search_service_rows',
      'tts_service_rows',
      'instruction_injection_rows',
      'assistant_tag_rows',
      'memory_entry_rows',
      'user_profile_field_rows',
    };
    for (final entry in expectedPrimaryKeys.entries) {
      final primaryRows =
          database
              .select('PRAGMA table_info(${entry.key});')
              .where((row) => (row['pk'] as int? ?? 0) > 0)
              .toList()
            ..sort(
              (left, right) =>
                  (left['pk'] as int).compareTo(right['pk'] as int),
            );
      final actual = primaryRows
          .map((row) => row['name'])
          .whereType<String>()
          .toList(growable: false);
      if (!_sameOrderedStrings(actual, entry.value)) {
        throw StateError('primary_key_schema:${entry.key}');
      }
      if (sortOrderTables.contains(entry.key)) {
        final schemaRow = database.select(
          "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = ?;",
          [entry.key],
        ).single;
        final normalizedSql = (schemaRow['sql'] as String? ?? '')
            .replaceAll(RegExp(r'[\s"]'), '')
            .toLowerCase();
        if (!normalizedSql.contains('check(sort_order>=0)')) {
          throw StateError('check_schema:${entry.key}');
        }
      }
    }

    const memoryIndexName = 'idx_assistant_memories_assistant';
    final memoryIndexRows = database.select(
      'PRAGMA index_list(assistant_memory_rows);',
    );
    final memoryIndex = memoryIndexRows.where(
      (row) => row['name'] == memoryIndexName,
    );
    if (memoryIndex.length != 1 || memoryIndex.single['unique'] != 0) {
      throw StateError('index_schema:$memoryIndexName');
    }
    final memoryIndexColumns = database
        .select('PRAGMA index_info($memoryIndexName);')
        .map((row) => row['name'])
        .whereType<String>()
        .toList(growable: false);
    if (!_sameOrderedStrings(memoryIndexColumns, const [
      'assistant_id',
      'id',
    ])) {
      throw StateError('index_schema:$memoryIndexName');
    }

    void requireIndex({
      required String table,
      required String name,
      required List<String> columns,
    }) {
      final indexRows = database.select('PRAGMA index_list($table);');
      final index = indexRows.where((row) => row['name'] == name);
      if (index.length != 1 || index.single['unique'] != 0) {
        throw StateError('index_schema:$name');
      }
      final actual = database
          .select('PRAGMA index_info($name);')
          .map((row) => row['name'])
          .whereType<String>()
          .toList(growable: false);
      if (!_sameOrderedStrings(actual, columns)) {
        throw StateError('index_schema:$name');
      }
    }

    requireIndex(
      table: 'memory_entry_rows',
      name: 'idx_memory_entries_visible',
      columns: const ['status', 'type', 'scope', 'assistant_id'],
    );
    requireIndex(
      table: 'memory_entry_rows',
      name: 'idx_memory_entries_recent',
      columns: const ['status', 'type', 'entry_updated_at', 'id'],
    );
    requireIndex(
      table: 'memory_entry_rows',
      name: 'idx_memory_entries_dedupe',
      columns: const ['scope', 'assistant_id', 'type', 'content_normalized'],
    );
    requireIndex(
      table: 'message_prompt_rows',
      name: 'idx_message_prompts_conversation_snapshot',
      columns: const ['conversation_id', 'carries_memory_snapshot'],
    );

    const assetIndexName = 'idx_message_assets_asset';
    final assetIndexRows = database.select(
      'PRAGMA index_list(message_asset_rows);',
    );
    final assetIndex = assetIndexRows.where(
      (row) => row['name'] == assetIndexName,
    );
    if (assetIndex.length != 1 || assetIndex.single['unique'] != 0) {
      throw StateError('index_schema:$assetIndexName');
    }
    final assetIndexColumns = database
        .select('PRAGMA index_info($assetIndexName);')
        .map((row) => row['name'])
        .whereType<String>()
        .toList(growable: false);
    if (!_sameOrderedStrings(assetIndexColumns, const [
      'asset_id',
      'revision_id',
    ])) {
      throw StateError('index_schema:$assetIndexName');
    }

    final hasUniqueAssetContentHash = database
        .select('PRAGMA index_list(asset_rows);')
        .where(
          (row) => row['unique'] == 1 && (row['partial'] as int? ?? 0) == 0,
        )
        .any((row) {
          final indexName = row['name'] as String?;
          if (indexName == null) return false;
          final columns = database.select(
            'SELECT name FROM pragma_index_info(?) ORDER BY seqno;',
            [indexName],
          );
          return columns.length == 1 &&
              columns.single['name'] == 'content_hash';
        });
    if (!hasUniqueAssetContentHash) {
      throw StateError('index_schema:asset_rows.content_hash');
    }

    const expectedForeignKeys = <String, Set<String>>{
      'conversation_mcp_server_rows': {
        'conversation_id->conversation_rows.id:CASCADE',
      },
      'message_rows': {'conversation_id->conversation_rows.id:CASCADE'},
      'message_part_rows': {'revision_id->message_rows.id:CASCADE'},
      'generation_run_rows': {
        'conversation_id->conversation_rows.id:CASCADE',
        'target_revision_id->message_rows.id:NO ACTION',
      },
      'provider_artifact_rows': {'revision_id->message_rows.id:CASCADE'},
      'asset_rows': <String>{},
      'message_asset_rows': {
        'revision_id->message_rows.id:CASCADE',
        'asset_id->asset_rows.id:CASCADE',
      },
      'asset_gc_rows': {'asset_id->asset_rows.id:CASCADE'},
      'gc_audit_rows': <String>{},
      'asset_reference_dirty_rows': {'revision_id->message_rows.id:CASCADE'},
      'assistant_rows': <String>{},
      'provider_rows': <String>{},
      'provider_group_rows': <String>{},
      'mcp_server_rows': <String>{},
      'world_book_rows': <String>{},
      'assistant_memory_rows': <String>{},
      'quick_phrase_rows': <String>{},
      'search_service_rows': <String>{},
      'tts_service_rows': <String>{},
      'instruction_injection_rows': <String>{},
      'assistant_tag_rows': <String>{},
      'preference_rows': <String>{},
      'memory_entry_rows': <String>{},
      'user_profile_field_rows': <String>{},
      'message_prompt_rows': {'revision_id->message_rows.id:CASCADE'},
    };
    for (final entry in expectedForeignKeys.entries) {
      final actual = database
          .select('PRAGMA foreign_key_list(${entry.key});')
          .map(
            (row) =>
                '${row['from']}->${row['table']}.${row['to']}:'
                '${row['on_delete']}',
          )
          .toSet();
      if (actual.length != entry.value.length ||
          !actual.containsAll(entry.value)) {
        throw StateError('foreign_key_schema:${entry.key}');
      }
    }
  }

  static bool _sameOrderedStrings(List<String> actual, List<String> expected) {
    if (actual.length != expected.length) return false;
    for (var i = 0; i < actual.length; i++) {
      if (actual[i] != expected[i]) return false;
    }
    return true;
  }

  static int _rawTableCount(sqlite.Database database, String table) {
    return database
            .select('SELECT COUNT(*) AS count FROM $table;')
            .single['count']
        as int;
  }

  /// Puts [backup] back at [target], leaving [backup] in place until the
  /// restored database has been verified.
  ///
  /// Idempotent by construction, because the only step that destroys
  /// information is the last one: a crash at any point leaves [backup] intact
  /// and a re-run redoes the copy. This is what makes the pre-migration copy a
  /// real safety net rather than a second thing to lose.
  static Future<void> restorePreMigrationBackup({
    required File backup,
    required File target,
    RestoreDurability? durability,
  }) async {
    final resolvedDurability = durability ?? RestorePlatformDurability();
    final parent = target.absolute.parent;
    await _deleteDatabaseFamily(target);
    await backup.copy(target.absolute.path);
    await resolvedDurability.syncFile(target, fullBarrier: true);
    await resolvedDurability.syncDirectory(parent, fullBarrier: true);
    if (classifyInstalledDatabase(target) !=
        InstalledDatabaseDisposition.usable) {
      throw StateError('database_rollback_failed');
    }
    await backup.delete();
    await resolvedDurability.syncDirectory(parent, fullBarrier: true);
  }

  /// What a crash-recovery sweep may do with the installed database at [file].
  ///
  /// Deliberately total: throwing here would strand the user with a
  /// pre-migration copy nobody dares act on, so every failure mode resolves to
  /// a disposition.
  static InstalledDatabaseDisposition classifyInstalledDatabase(File file) {
    if (!file.existsSync()) return InstalledDatabaseDisposition.unusable;

    // The schema version is read FIRST and read-only. A database written by a
    // newer build must never be touched, and opening it read-write to find
    // that out would be the very thing that damages it -- so a foreign version
    // wins before any write is attempted.
    final peeked = _peekSchemaVersion(file, writable: false);
    if (peeked != null && _isForeignSchema(peeked)) {
      return InstalledDatabaseDisposition.foreignSchema;
    }

    try {
      final database = sqlite.sqlite3.open(file.absolute.path);
      try {
        // Folds in a hot WAL, so committed data is not mistaken for damage.
        database.execute('PRAGMA wal_checkpoint(TRUNCATE);');
        // Re-read after the checkpoint: the read-only peek above can fail
        // outright on a hot WAL, and this is the first reliable reading.
        final schemaVersion = database.userVersion;
        if (_isForeignSchema(schemaVersion)) {
          return InstalledDatabaseDisposition.foreignSchema;
        }
        // 0 is a file that was created but never given a schema -- a copy
        // interrupted at the very start, not a version from elsewhere.
        if (schemaVersion == 0) return InstalledDatabaseDisposition.unusable;
        final check = database.select('PRAGMA quick_check;');
        if (check.length != 1 || check.single.values.single != 'ok') {
          return InstalledDatabaseDisposition.unusable;
        }
        // quick_check only proves the file is physically sound; it says
        // nothing about missing tables, columns, or indexes. A migration that
        // committed but left the schema incomplete would otherwise read as
        // healthy here, and the pre-migration copy -- the only way back --
        // would be deleted moments before migrateInstalledDatabase notices.
        //
        // Only meaningful at the current schema: _validateRawStructure asserts
        // this build's exact column set, so an older published version has to
        // wait until it has been migrated. Its copy is a duplicate of itself
        // at that point, so nothing is lost by trusting it.
        if (schemaVersion == AppDatabase.currentSchemaVersion) {
          try {
            _validateRawStructure(database);
          } catch (_) {
            return InstalledDatabaseDisposition.unusable;
          }
        }
        return InstalledDatabaseDisposition.usable;
      } finally {
        database.close();
      }
    } catch (_) {
      return InstalledDatabaseDisposition.unusable;
    }
  }

  /// A version that belongs to some other build, as opposed to damage.
  ///
  /// 0 is excluded on purpose: it means no schema was ever written, which is
  /// an interrupted copy rather than a foreign version.
  static bool _isForeignSchema(int userVersion) =>
      userVersion != 0 && !SchemaMigrations.isPublished(userVersion);

  static int? _peekSchemaVersion(File file, {required bool writable}) {
    try {
      final database = sqlite.sqlite3.open(
        file.absolute.path,
        mode: writable ? sqlite.OpenMode.readWrite : sqlite.OpenMode.readOnly,
      );
      try {
        return database.userVersion;
      } finally {
        database.close();
      }
    } catch (_) {
      return null;
    }
  }

  static Future<void> _deleteDatabaseFamily(File databaseFile) async {
    for (final suffix in const ['', '-wal', '-shm', '-journal']) {
      final file = File('${databaseFile.path}$suffix');
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  /// Returns [databaseFile] to the shape an archived snapshot must have:
  /// journal folded in, DELETE journal mode, no sidecars.
  ///
  /// Opening a snapshot for anything — including a schema upgrade — can leave a
  /// WAL behind, and [inspectPreparedSnapshot] rejects sidecars.
  static Future<void> normalizeSnapshotJournal(File databaseFile) async {
    final database = sqlite.sqlite3.open(databaseFile.absolute.path);
    try {
      database.execute('PRAGMA wal_checkpoint(TRUNCATE);');
      database.select('PRAGMA journal_mode = DELETE;');
    } finally {
      database.close();
    }
    await _deleteDatabaseSidecars(databaseFile);
  }

  static Future<void> _deleteDatabaseSidecars(File databaseFile) async {
    for (final suffix in const ['-wal', '-shm', '-journal']) {
      final file = File('${databaseFile.path}$suffix');
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<void> close() async {
    await _db.close();
  }

  Future<void> ensureReady() async {
    await _db.customSelect('SELECT 1').get();
  }

  Future<ChatDatabaseConnectionContract> validateConnectionContract() async {
    final stopwatch = Stopwatch()..start();
    try {
      Future<Object?> pragma(String name) async {
        final row = await _db.customSelect('PRAGMA $name;').getSingle();
        return row.data.values.single;
      }

      final contract = ChatDatabaseConnectionContract(
        schemaVersion: await pragma('user_version') as int,
        journalModeWal:
            (await pragma('journal_mode')).toString().toLowerCase() == 'wal',
        foreignKeysEnabled: await pragma('foreign_keys') == 1,
        busyTimeoutMillis: await pragma('busy_timeout') as int,
        synchronous: await pragma('synchronous') as int,
        walAutoCheckpointPages: await pragma('wal_autocheckpoint') as int,
        journalSizeLimitBytes: await pragma('journal_size_limit') as int,
      );
      if (contract.schemaVersion != AppDatabase.currentSchemaVersion) {
        throw StateError('database_connection_contract:schema_version');
      }
      if (!contract.journalModeWal) {
        throw StateError('database_connection_contract:journal_mode');
      }
      if (!contract.foreignKeysEnabled) {
        throw StateError('database_connection_contract:foreign_keys');
      }
      if (contract.busyTimeoutMillis != AppDatabase.busyTimeoutMillis) {
        throw StateError('database_connection_contract:busy_timeout');
      }
      if (contract.synchronous != AppDatabase.synchronousNormal) {
        throw StateError('database_connection_contract:synchronous');
      }
      if (contract.walAutoCheckpointPages !=
          AppDatabase.walAutoCheckpointPages) {
        throw StateError('database_connection_contract:wal_autocheckpoint');
      }
      if (contract.journalSizeLimitBytes != AppDatabase.journalSizeLimitBytes) {
        throw StateError('database_connection_contract:journal_size_limit');
      }
      stopwatch.stop();
      _observer.recordConnectionContract(
        contract,
        elapsedMicros: stopwatch.elapsedMicroseconds,
      );
      return contract;
    } catch (error) {
      stopwatch.stop();
      _observer.recordFailure(
        operation: ChatDatabaseOperation.connectionContract,
        elapsedMicros: stopwatch.elapsedMicroseconds,
        error: error,
      );
      rethrow;
    }
  }

  Future<String?> getDatabaseIdentity() async {
    final row =
        await (_db.select(_db.chatStorageMetaRows)..where(
              (table) => table.key.equals(ChatStorageMetaKeys.databaseIdentity),
            ))
            .getSingleOrNull();
    return row?.value;
  }

  Future<SandboxPathMigrationResult> migrateSandboxPaths({
    required int targetVersion,
    required String targetRoot,
    required String Function(String uri) rewriteUri,
    int batchSize = 360,
  }) async {
    if (targetVersion <= 0) {
      throw ArgumentError.value(targetVersion, 'targetVersion');
    }
    if (targetRoot.trim().isEmpty) {
      throw ArgumentError.value(targetRoot, 'targetRoot');
    }
    if (batchSize <= 0) throw ArgumentError.value(batchSize, 'batchSize');
    return _db.transaction(() async {
      final receipt =
          await (_db.select(_db.chatStorageMetaRows)..where(
                (row) => row.key.equals(ChatStorageMetaKeys.sandboxPathVersion),
              ))
              .getSingleOrNull();
      var currentVersion = 0;
      String? currentRoot;
      if (receipt != null) {
        final Object? decoded;
        try {
          decoded = jsonDecode(receipt.value);
        } on FormatException {
          throw StateError('sandbox_path_migration_receipt');
        }
        if (decoded is! Map<String, dynamic> ||
            decoded.length != 2 ||
            decoded['version'] is! int ||
            decoded['targetRoot'] is! String) {
          throw StateError('sandbox_path_migration_receipt');
        }
        currentVersion = decoded['version'] as int;
        currentRoot = decoded['targetRoot'] as String;
      }
      if (currentVersion > targetVersion) {
        throw StateError('sandbox_path_migration_version');
      }
      if (currentVersion == targetVersion && currentRoot == targetRoot) {
        return const SandboxPathMigrationResult(
          ran: false,
          scannedMessages: 0,
          updatedMessages: 0,
          skippedParts: 0,
        );
      }

      var scanned = 0;
      var updated = 0;
      var skipped = 0;
      // Cursor on part_id (AUTOINCREMENT PK): stable order, no missed rows,
      // and no re-scan loop after payload rewrites (part_id is unchanged).
      var cursor = 0;
      while (true) {
        final rows = await _db
            .customSelect(
              'SELECT part_id, revision_id, ordinal, kind, payload '
              'FROM message_part_rows '
              "WHERE kind IN ('image', 'file') AND part_id > ? "
              'ORDER BY part_id LIMIT ?;',
              variables: [Variable<int>(cursor), Variable<int>(batchSize)],
            )
            .get();
        if (rows.isEmpty) break;
        for (final row in rows) {
          final partId = row.read<int>('part_id');
          final revisionId = row.read<String>('revision_id');
          final ordinal = row.read<int>('ordinal');
          final kind = row.read<String>('kind');
          final payload = row.read<String>('payload');
          final rewrite = _rewriteAttachmentPartUri(
            kind: kind,
            payload: payload,
            rewriteUri: rewriteUri,
          );
          scanned += 1;
          if (rewrite.parseError case final parseError?) {
            skipped += 1;
            await markMessageAssetReferencesDirty(revisionId);
            debugPrint(
              'Sandbox path migration skipped malformed part: '
              'revisionId=$revisionId ordinal=$ordinal kind=$kind '
              'parseError=$parseError',
            );
          }
          final rewritten = rewrite.payload;
          if (rewritten != payload) {
            await _db.customStatement(
              'UPDATE message_part_rows SET payload = ? WHERE part_id = ?;',
              [rewritten, partId],
            );
            updated += 1;
          }
          cursor = partId;
        }
      }
      await _db
          .into(_db.chatStorageMetaRows)
          .insertOnConflictUpdate(
            ChatStorageMetaRowsCompanion.insert(
              key: ChatStorageMetaKeys.sandboxPathVersion,
              value: jsonEncode({
                'version': targetVersion,
                'targetRoot': targetRoot,
              }),
            ),
          );
      return SandboxPathMigrationResult(
        ran: true,
        scannedMessages: scanned,
        updatedMessages: updated,
        skippedParts: skipped,
      );
    });
  }

  ({String payload, String? parseError}) _rewriteAttachmentPartUri({
    required String kind,
    required String payload,
    required String Function(String uri) rewriteUri,
  }) {
    final MessagePart part;
    try {
      part = MessagePart.fromRow(kind, payload);
    } on FormatException catch (error) {
      return (
        payload: payload,
        parseError: messagePartParseErrorCategory(error),
      );
    }
    if (part is ImagePart) {
      final nextUri = rewriteUri(part.uri);
      final nextUnavailable = _unavailableForRewrittenUri(nextUri);
      if (nextUri == part.uri && nextUnavailable == part.unavailable) {
        return (payload: payload, parseError: null);
      }
      return (
        payload: ImagePart(
          uri: nextUri,
          mime: part.mime,
          assetId: part.assetId,
          unavailable: nextUnavailable,
        ).encodePayload(),
        parseError: null,
      );
    }
    if (part is FilePart) {
      final nextUri = rewriteUri(part.uri);
      final nextUnavailable = _unavailableForRewrittenUri(nextUri);
      if (nextUri == part.uri && nextUnavailable == part.unavailable) {
        return (payload: payload, parseError: null);
      }
      return (
        payload: FilePart(
          uri: nextUri,
          name: part.name,
          mime: part.mime,
          assetId: part.assetId,
          unavailable: nextUnavailable,
        ).encodePayload(),
        parseError: null,
      );
    }
    return (payload: payload, parseError: null);
  }

  /// Remote/data URIs stay available; local paths use [localFileExists]
  /// (no fix→File SMB probe).
  bool _unavailableForRewrittenUri(String nextUri) {
    if (isRemoteOrDataUri(nextUri)) return false;
    return !SandboxPathResolver.localFileExists(nextUri);
  }

  Future<bool> needsAssetReferenceBackfill({
    required int version,
    required String targetRoot,
  }) async {
    final row =
        await (_db.select(_db.chatStorageMetaRows)..where(
              (table) => table.key.equals(
                ChatStorageMetaKeys.assetReferenceBackfillVersion,
              ),
            ))
            .getSingleOrNull();
    if (row == null) return true;
    try {
      final value = jsonDecode(row.value);
      return value is! Map<String, dynamic> ||
          value['version'] != version ||
          value['targetRoot'] != targetRoot;
    } on FormatException {
      return true;
    }
  }

  Future<void> markAssetReferenceBackfillComplete({
    required int version,
    required String targetRoot,
  }) async {
    await _db
        .into(_db.chatStorageMetaRows)
        .insertOnConflictUpdate(
          ChatStorageMetaRowsCompanion.insert(
            key: ChatStorageMetaKeys.assetReferenceBackfillVersion,
            value: jsonEncode({'version': version, 'targetRoot': targetRoot}),
          ),
        );
  }

  Future<List<ChatMessage>> getMessagesForAssetReferenceBackfill({
    required String afterMessageId,
    required bool includeLegacyCandidates,
    int limit = 360,
  }) async {
    if (limit <= 0) return const <ChatMessage>[];
    final rows = await _db
        .customSelect(
          '''
          SELECT m.* FROM message_rows m
          WHERE m.id > ? AND (
            EXISTS (
              SELECT 1 FROM asset_reference_dirty_rows d
              WHERE d.revision_id = m.id
            ) OR (? AND (
              EXISTS (
                SELECT 1 FROM message_part_rows p
                WHERE p.revision_id = m.id
                  AND p.kind IN ('image', 'file')
              ) OR
              EXISTS (
                SELECT 1 FROM message_asset_rows a WHERE a.revision_id = m.id
              )
            ))
          )
          ORDER BY m.id LIMIT ?;
        ''',
          variables: [
            Variable<String>(afterMessageId),
            Variable<bool>(includeLegacyCandidates),
            Variable<int>(limit),
          ],
          readsFrom: {_db.messageRows, _db.messagePartRows},
        )
        .get();
    return _messagesFromRowsWithParts(
      rows.map((row) => _db.messageRows.map(row.data)).toList(growable: false),
    );
  }

  Future<bool> hasPendingAssetReferenceSync() async {
    return await _db
            .customSelect('SELECT 1 FROM asset_reference_dirty_rows LIMIT 1;')
            .getSingleOrNull() !=
        null;
  }

  Future<void> markMessageAssetReferencesDirty(String revisionId) async {
    await _db.customStatement(
      'INSERT OR IGNORE INTO asset_reference_dirty_rows(revision_id) '
      'VALUES (?);',
      [revisionId],
    );
  }

  /// Bulk variant of [markMessageAssetReferencesDirty] for restore/import
  /// paths that write message rows without going through
  /// `_replaceMessageParts`. Queuing the revisions keeps the asset-reference
  /// backfill invariant: every attachment-bearing revision is re-registered
  /// before GC may collect its files.
  Future<void> _markMessageAssetReferencesDirtyBatch(
    List<String> revisionIds,
  ) async {
    if (revisionIds.isEmpty) return;
    const chunkSize = 200;
    for (var start = 0; start < revisionIds.length; start += chunkSize) {
      final end = start + chunkSize < revisionIds.length
          ? start + chunkSize
          : revisionIds.length;
      final chunk = revisionIds.sublist(start, end);
      await _db.customStatement(
        'INSERT OR IGNORE INTO asset_reference_dirty_rows(revision_id) '
        'VALUES ${List.filled(chunk.length, '(?)').join(', ')};',
        chunk,
      );
    }
  }

  Future<void> checkpoint() async {
    final stopwatch = Stopwatch()..start();
    int? walBytesBefore;
    try {
      walBytesBefore = await _walBytes();
      final row = await _db
          .customSelect('PRAGMA wal_checkpoint(TRUNCATE);')
          .getSingle();
      final walBytesAfter = await _walBytes();
      stopwatch.stop();
      _observer.record(
        ChatDatabaseObservation(
          operation: ChatDatabaseOperation.walCheckpoint,
          elapsedMicros: stopwatch.elapsedMicroseconds,
          succeeded: true,
          walBytesBefore: walBytesBefore,
          walBytesAfter: walBytesAfter,
          checkpointBusy: row.read<int>('busy'),
          checkpointLogFrames: row.read<int>('log'),
          checkpointedFrames: row.read<int>('checkpointed'),
        ),
      );
    } catch (error) {
      stopwatch.stop();
      _observer.recordFailure(
        operation: ChatDatabaseOperation.walCheckpoint,
        elapsedMicros: stopwatch.elapsedMicroseconds,
        error: error,
        walBytesBefore: walBytesBefore,
      );
      rethrow;
    }
  }

  Future<void> validateIntegrity() async {
    await _observer.measure(ChatDatabaseOperation.integrityCheck, () async {
      final integrityRows = await _db
          .customSelect('PRAGMA integrity_check')
          .get();
      final integrityValues = integrityRows
          .expand((row) => row.data.values)
          .map((value) => value.toString())
          .toList(growable: false);
      if (integrityValues.length != 1 || integrityValues.single != 'ok') {
        throw StateError('integrity_check');
      }
      final foreignKeyRows = await _db
          .customSelect('PRAGMA foreign_key_check')
          .get();
      if (foreignKeyRows.isNotEmpty) {
        throw StateError('foreign_key_check');
      }
    });
  }

  Future<int?> _walBytes() async {
    final databaseFile = _databaseFile;
    if (databaseFile == null) return null;
    final wal = File('${databaseFile.path}-wal');
    if (await FileSystemEntity.type(wal.path, followLinks: false) !=
        FileSystemEntityType.file) {
      return 0;
    }
    return wal.length();
  }

  Future<List<Conversation>> getAllConversations() async {
    return _observer.measure(
      ChatDatabaseOperation.queryConversationList,
      () async {
        final rows =
            await (_db.select(_db.conversationRows)..orderBy([
                  (t) => OrderingTerm(
                    expression: t.updatedAt,
                    mode: OrderingMode.desc,
                  ),
                ]))
                .get();
        final out = <Conversation>[];
        for (final row in rows) {
          out.add(await _conversationFromRow(row));
        }
        return out;
      },
      resultCount: (rows) => rows.length,
    );
  }

  Future<List<Conversation>> getAllConversationSummaries() async {
    return _observer.measure(
      ChatDatabaseOperation.queryConversationList,
      () async {
        final rows =
            await (_db.select(_db.conversationRows)..orderBy([
                  (t) => OrderingTerm(
                    expression: t.updatedAt,
                    mode: OrderingMode.desc,
                  ),
                ]))
                .get();
        // One bulk read instead of a per-conversation query; the ordinal
        // ordering is preserved by the in-Dart bucketing below.
        final mcpRows = await (_db.select(
          _db.conversationMcpServerRows,
        )..orderBy([(t) => OrderingTerm.asc(t.ordinal)])).get();
        final mcpServerIdsByConversation = <String, List<String>>{};
        for (final mcpRow in mcpRows) {
          mcpServerIdsByConversation
              .putIfAbsent(mcpRow.conversationId, () => <String>[])
              .add(mcpRow.serverId);
        }
        final out = <Conversation>[];
        for (final row in rows) {
          out.add(
            await _conversationFromRow(
              row,
              includeMessageIds: false,
              mcpServerIds:
                  mcpServerIdsByConversation[row.id] ?? const <String>[],
            ),
          );
        }
        return out;
      },
      resultCount: (rows) => rows.length,
    );
  }

  Future<Conversation?> getConversation(String id) async {
    return _observer.measure(
      ChatDatabaseOperation.queryConversation,
      () async {
        final row = await (_db.select(
          _db.conversationRows,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        if (row == null) return null;
        return _conversationFromRow(row);
      },
      resultCount: (conversation) => conversation == null ? 0 : 1,
    );
  }

  Future<int> getMessageCount(String conversationId) async {
    return _observer.measure(ChatDatabaseOperation.queryMessageCount, () async {
      final count = _db.messageRows.id.count();
      final row =
          await (_db.selectOnly(_db.messageRows)
                ..addColumns([count])
                ..where(_db.messageRows.conversationId.equals(conversationId)))
              .getSingle();
      return row.read(count) ?? 0;
    }, resultCount: (count) => count);
  }

  Future<Map<String, int>> getMessageCountsByConversation() async {
    final conversationId = _db.messageRows.conversationId;
    final count = _db.messageRows.id.count();
    final rows =
        await (_db.selectOnly(_db.messageRows)
              ..addColumns([conversationId, count])
              ..groupBy([conversationId]))
            .get();
    return {
      for (final row in rows) row.read(conversationId)!: row.read(count) ?? 0,
    };
  }

  Future<int> getConversationCount() async {
    return _observer.measure(
      ChatDatabaseOperation.queryConversationCount,
      () async {
        final count = _db.conversationRows.id.count();
        final row = await (_db.selectOnly(
          _db.conversationRows,
        )..addColumns([count])).getSingle();
        return row.read(count) ?? 0;
      },
      resultCount: (count) => count,
    );
  }

  Future<int> getTotalMessageCount() async {
    return _observer.measure(
      ChatDatabaseOperation.queryTotalMessageCount,
      () async {
        final count = _db.messageRows.id.count();
        final row = await (_db.selectOnly(
          _db.messageRows,
        )..addColumns([count])).getSingle();
        return row.read(count) ?? 0;
      },
      resultCount: (count) => count,
    );
  }

  Future<int> getTextPartCount() async {
    return _observer.measure(
      ChatDatabaseOperation.queryTextPartCount,
      () async {
        final count = _db.messagePartRows.partId.count();
        final row =
            await (_db.selectOnly(_db.messagePartRows)
                  ..addColumns([count])
                  ..where(_db.messagePartRows.kind.equals('text')))
                .getSingle();
        return row.read(count) ?? 0;
      },
      resultCount: (count) => count,
    );
  }

  Future<int> getToolCallPartCount() async {
    return _observer.measure(
      ChatDatabaseOperation.queryToolCallPartCount,
      () async {
        final count = _db.messagePartRows.partId.count();
        final row =
            await (_db.selectOnly(_db.messagePartRows)
                  ..addColumns([count])
                  ..where(_db.messagePartRows.kind.equals('tool_call')))
                .getSingle();
        return row.read(count) ?? 0;
      },
      resultCount: (count) => count,
    );
  }

  Future<int> getImagePartCount() async {
    return _observer.measure(
      ChatDatabaseOperation.queryImagePartCount,
      () async {
        final count = _db.messagePartRows.partId.count();
        final row =
            await (_db.selectOnly(_db.messagePartRows)
                  ..addColumns([count])
                  ..where(_db.messagePartRows.kind.equals('image')))
                .getSingle();
        return row.read(count) ?? 0;
      },
      resultCount: (count) => count,
    );
  }

  Future<int> getFilePartCount() async {
    return _observer.measure(
      ChatDatabaseOperation.queryFilePartCount,
      () async {
        final count = _db.messagePartRows.partId.count();
        final row =
            await (_db.selectOnly(_db.messagePartRows)
                  ..addColumns([count])
                  ..where(_db.messagePartRows.kind.equals('file')))
                .getSingle();
        return row.read(count) ?? 0;
      },
      resultCount: (count) => count,
    );
  }

  /// Strictly validates every persisted attachment payload in bounded pages.
  ///
  /// This is a migration publication guard, not a normal hydration path:
  /// malformed rows fail the migration instead of becoming [MalformedPart]s.
  Future<void> validateAttachmentPartPayloads({
    void Function(int processed, int total)? onProgress,
    @visibleForTesting void Function(int rowCount)? onMetadataWindow,
  }) async {
    final totalRow = await _db
        .customSelect(
          "SELECT COUNT(*) AS total FROM message_part_rows "
          "WHERE kind IN ('image', 'file');",
          readsFrom: {_db.messagePartRows},
        )
        .getSingle();
    final total = totalRow.read<int>('total');
    onProgress?.call(0, total);

    const metadataPageSize = 256;
    const payloadPageByteBudget = 2 * 1024 * 1024;
    var cursor = 0;
    var processed = 0;
    while (true) {
      final metadataRows = await _db
          .customSelect(
            'SELECT part_id, LENGTH(CAST(payload AS BLOB)) AS payload_bytes '
            'FROM message_part_rows '
            "WHERE kind IN ('image', 'file') AND part_id > ? "
            'ORDER BY part_id LIMIT ?;',
            variables: [
              Variable<int>(cursor),
              const Variable<int>(metadataPageSize),
            ],
            readsFrom: {_db.messagePartRows},
          )
          .get();
      if (metadataRows.isEmpty) break;
      onMetadataWindow?.call(metadataRows.length);

      var metadataIndex = 0;
      while (metadataIndex < metadataRows.length) {
        final partIds = <int>[];
        var selectedBytes = 0;
        while (metadataIndex < metadataRows.length) {
          final row = metadataRows[metadataIndex];
          final payloadBytes = row.read<int>('payload_bytes');
          if (partIds.isNotEmpty &&
              selectedBytes + payloadBytes > payloadPageByteBudget) {
            break;
          }
          partIds.add(row.read<int>('part_id'));
          selectedBytes += payloadBytes;
          metadataIndex += 1;
        }
        final placeholders = List.filled(partIds.length, '?').join(', ');
        final rows = await _db
            .customSelect(
              'SELECT part_id, revision_id, ordinal, kind, payload '
              'FROM message_part_rows WHERE part_id IN ($placeholders) '
              'ORDER BY part_id;',
              variables: [for (final partId in partIds) Variable<int>(partId)],
              readsFrom: {_db.messagePartRows},
            )
            .get();
        if (rows.length != partIds.length) {
          throw StateError(
            'Migration validation failed (attachment payload page incomplete): '
            'expected=${partIds.length} actual=${rows.length}.',
          );
        }
        for (final row in rows) {
          final partId = row.read<int>('part_id');
          final revisionId = row.read<String>('revision_id');
          final ordinal = row.read<int>('ordinal');
          final kind = row.read<String>('kind');
          final payload = row.read<String>('payload');
          try {
            MessagePart.fromRow(kind, payload);
          } on FormatException {
            throw StateError(
              'Migration validation failed (attachment part payload): '
              'revisionId=$revisionId ordinal=$ordinal kind=$kind.',
            );
          }
          cursor = partId;
          processed += 1;
        }
        onProgress?.call(processed, total);
      }
    }
  }

  /// When true, the worker-isolate digest path throws before spawn so tests can
  /// assert the Drift fallback still completes validation.
  @visibleForTesting
  bool debugForceTextPartDigestIsolateFailureForTest = false;

  /// Order-independent digest of every `kind='text'` part payload.
  ///
  /// Each row contributes `SHA-256(revision_id || NUL || payload)` XORed into a
  /// 32-byte accumulator. When a database file path is available the scan and
  /// SHA-256 work prefer a **dedicated worker isolate** (not the Drift SQL
  /// isolate and not the UI isolate). Any infrastructure failure on that path
  /// (including [Isolate.spawn]) is recorded via [_observer] and transparently
  /// falls back to the Drift in-process scan — only a digest *mismatch* at the
  /// call site should fail migration. [onProgress] reports SQLite `LENGTH`
  /// character counts (same unit for total and processed).
  Future<String> getTextPartContentDigest({
    void Function(int processedChars, int totalChars)? onProgress,
  }) async {
    return _observer.measure(
      ChatDatabaseOperation.queryTextPartContentDigest,
      () async {
        final file = _databaseFile;
        if (file != null) {
          final isolateSw = Stopwatch()..start();
          try {
            if (debugForceTextPartDigestIsolateFailureForTest) {
              throw StateError('digest_isolate_forced_failure');
            }
            return await _computeTextPartContentDigestInIsolate(
              file.path,
              onProgress: onProgress,
            );
          } catch (error) {
            isolateSw.stop();
            // Infrastructure-only: digest mismatch is decided by the caller.
            _observer.recordFailure(
              operation: ChatDatabaseOperation.queryTextPartContentDigest,
              elapsedMicros: isolateSw.elapsedMicroseconds,
              error: error,
            );
          }
        }
        return _computeTextPartContentDigestViaDrift(onProgress: onProgress);
      },
    );
  }

  /// Drift-backed scan: SQL on the Drift worker isolate, SHA-256 on the caller.
  /// Used when no file path is available, and as fallback when the dedicated
  /// digest isolate cannot complete.
  Future<String> _computeTextPartContentDigestViaDrift({
    void Function(int processedChars, int totalChars)? onProgress,
  }) async {
    final totalRow = await _db
        .customSelect(
          "SELECT COALESCE(SUM(LENGTH(payload)), 0) AS total "
          "FROM message_part_rows WHERE kind = 'text';",
          readsFrom: {_db.messagePartRows},
        )
        .getSingle();
    final totalChars = totalRow.read<int>('total');
    _emitTextPartDigestProgress(onProgress, 0, totalChars);

    final digest = Uint8List(32);
    const pageSize = 256;
    var cursor = 0;
    var processedChars = 0;
    while (true) {
      final rows = await _db
          .customSelect(
            'SELECT part_id, revision_id, payload, LENGTH(payload) AS '
            'payload_length FROM message_part_rows '
            "WHERE kind = 'text' AND part_id > ? "
            'ORDER BY part_id LIMIT ?;',
            variables: [Variable<int>(cursor), const Variable<int>(pageSize)],
            readsFrom: {_db.messagePartRows},
          )
          .get();
      if (rows.isEmpty) break;
      for (final row in rows) {
        mixTextPartContentDigest(
          digest,
          row.read<String>('revision_id'),
          row.read<String>('payload'),
        );
        processedChars += row.read<int>('payload_length');
        cursor = row.read<int>('part_id');
      }
      _emitTextPartDigestProgress(onProgress, processedChars, totalChars);
      if (rows.length < pageSize) break;
    }
    return textPartContentDigestHex(digest);
  }

  static Future<String> _computeTextPartContentDigestInIsolate(
    String databasePath, {
    void Function(int processedChars, int totalChars)? onProgress,
  }) async {
    final receivePort = ReceivePort();
    Isolate? isolate;
    try {
      isolate = await Isolate.spawn(_textPartContentDigestIsolateMain, (
        path: databasePath,
        sendPort: receivePort.sendPort,
      ), debugName: 'text_part_content_digest');
      await for (final message in receivePort) {
        if (message is! Map) {
          throw StateError('digest_isolate_protocol');
        }
        final type = message['type'];
        if (type == 'progress') {
          _emitTextPartDigestProgress(
            onProgress,
            message['processed'] as int,
            message['total'] as int,
          );
          continue;
        }
        if (type == 'result') {
          return message['digest'] as String;
        }
        if (type == 'error') {
          throw StateError(
            'Migration validation digest isolate failed: '
            '${message['error']}',
          );
        }
        throw StateError('digest_isolate_protocol');
      }
      throw StateError('digest_isolate_ended');
    } finally {
      receivePort.close();
      isolate?.kill(priority: Isolate.immediate);
    }
  }

  /// Worker entry: own read-only sqlite3 connection; never touches the UI
  /// isolate. Progress/result maps are sent back on [args.sendPort].
  ///
  /// Progress uses SQLite `LENGTH(payload)` for both total and processed so
  /// emoji / surrogate pairs cannot push the bar past 100%.
  static void _textPartContentDigestIsolateMain(
    ({String path, SendPort sendPort}) args,
  ) {
    try {
      final database = sqlite.sqlite3.open(
        args.path,
        mode: sqlite.OpenMode.readOnly,
      );
      try {
        final totalChars =
            database
                    .select(
                      "SELECT COALESCE(SUM(LENGTH(payload)), 0) AS total "
                      "FROM message_part_rows WHERE kind = 'text';",
                    )
                    .single['total']
                as int;
        args.sendPort.send({
          'type': 'progress',
          'processed': 0,
          'total': totalChars,
        });

        final digest = Uint8List(32);
        const pageSize = 256;
        var cursor = 0;
        var processedChars = 0;
        while (true) {
          final rows = database.select(
            'SELECT part_id, revision_id, payload, LENGTH(payload) AS '
            'payload_length FROM message_part_rows '
            "WHERE kind = 'text' AND part_id > ? "
            'ORDER BY part_id LIMIT ?;',
            [cursor, pageSize],
          );
          if (rows.isEmpty) break;
          for (final row in rows) {
            mixTextPartContentDigest(
              digest,
              row['revision_id'] as String,
              row['payload'] as String,
            );
            processedChars += row['payload_length'] as int;
            cursor = row['part_id'] as int;
          }
          args.sendPort.send({
            'type': 'progress',
            'processed': processedChars,
            'total': totalChars,
          });
          if (rows.length < pageSize) break;
        }
        args.sendPort.send({
          'type': 'result',
          'digest': textPartContentDigestHex(digest),
        });
      } finally {
        database.close();
      }
    } catch (error, stackTrace) {
      args.sendPort.send({'type': 'error', 'error': '$error\n$stackTrace'});
    }
  }

  static void _emitTextPartDigestProgress(
    void Function(int processedChars, int totalChars)? onProgress,
    int processedChars,
    int totalChars,
  ) {
    if (onProgress == null) return;
    final safeTotal = totalChars < 0 ? 0 : totalChars;
    final safeProcessed = processedChars.clamp(0, safeTotal);
    onProgress(safeProcessed, safeTotal);
  }

  /// Mixes one text part into an order-independent 32-byte XOR digest.
  static void mixTextPartContentDigest(
    Uint8List digest,
    String revisionId,
    String payload,
  ) {
    final hash = sha256.convert(utf8.encode('$revisionId\u0000$payload')).bytes;
    for (var i = 0; i < digest.length; i++) {
      digest[i] ^= hash[i];
    }
  }

  static String textPartContentDigestHex(Uint8List digest) {
    final buffer = StringBuffer();
    for (final byte in digest) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  @visibleForTesting
  Future<void> corruptTextPartPayloadForTest(
    String revisionId,
    String payload,
  ) async {
    await _db.customStatement(
      "UPDATE message_part_rows SET payload = ? "
      "WHERE revision_id = ? AND kind = 'text';",
      [payload, revisionId],
    );
  }

  @visibleForTesting
  Future<void> corruptPartPayloadForTest(
    String revisionId,
    String kind,
    String payload,
  ) async {
    await _db.customStatement(
      'UPDATE message_part_rows SET payload = ? '
      'WHERE revision_id = ? AND kind = ?;',
      [payload, revisionId, kind],
    );
  }

  @visibleForTesting
  Future<void> deleteTextPartsForTest(String revisionId) async {
    await _db.customStatement(
      "DELETE FROM message_part_rows "
      "WHERE revision_id = ? AND kind = 'text';",
      [revisionId],
    );
  }

  @visibleForTesting
  Future<void> deletePartsByKindForTest(String revisionId, String kind) async {
    await _db.customStatement(
      'DELETE FROM message_part_rows '
      'WHERE revision_id = ? AND kind = ?',
      [revisionId, kind],
    );
  }

  Future<int> getMessageIndex(String conversationId, String messageId) async {
    final row =
        await (_db.select(_db.messageRows)
              ..where(
                (t) =>
                    t.conversationId.equals(conversationId) &
                    t.id.equals(messageId),
              )
              ..limit(1))
            .getSingleOrNull();
    return row?.messageOrder ?? -1;
  }

  Future<ChatMessage?> getMessage(String messageId) async {
    final row = await (_db.select(
      _db.messageRows,
    )..where((t) => t.id.equals(messageId))).getSingleOrNull();
    return row == null ? null : _messageFromRowWithParts(row);
  }

  Future<List<ChatMessage>> getMessagesRange(
    String conversationId, {
    required int start,
    required int limit,
  }) async {
    if (limit <= 0) return const <ChatMessage>[];
    final safeStart = start < 0 ? 0 : start;
    return _observer.measure(ChatDatabaseOperation.queryMessageRange, () async {
      final rows =
          await (_db.select(_db.messageRows)
                ..where((t) => t.conversationId.equals(conversationId))
                ..orderBy([(t) => OrderingTerm.asc(t.messageOrder)])
                ..limit(limit, offset: safeStart))
              .get();
      return _messagesFromRowsWithParts(rows);
    }, resultCount: (rows) => rows.length);
  }

  /// Loads the selected linear message versions needed for model context.
  ///
  /// Version collapsing, truncate-index application, tail limiting, and part
  /// hydration intentionally happen in one SQL statement so a large
  /// conversation is never materialized merely to discard its prefix.
  Future<List<ChatMessage>> getSelectedContextMessages(
    String conversationId, {
    required int truncateIndex,
    required int limit,
    String? throughRevisionId,
    bool includeFollowingAssistant = false,
  }) async {
    if (limit <= 0) return const <ChatMessage>[];
    return _observer.measure(ChatDatabaseOperation.queryMessageRange, () async {
      final result = await _db
          .customSelect(
            '''
            WITH group_rows AS (
              SELECT
                COALESCE(m.group_id, m.id) AS group_id,
                MIN(m.message_order) AS anchor_order,
                MAX(m.version) AS latest_version
              FROM message_rows m
              WHERE m.conversation_id = ?
              GROUP BY COALESCE(m.group_id, m.id)
            ),
            selections AS (
              SELECT j.key AS group_id, CAST(j.value AS INTEGER) AS version
              FROM conversation_rows c, json_each(c.version_selections_json) j
              WHERE c.id = ?
            ),
            ranked AS (
              SELECT
                m.id AS revision_id,
                g.group_id,
                m.role,
                g.anchor_order,
                ROW_NUMBER() OVER (
                  PARTITION BY g.group_id
                  ORDER BY
                    CASE
                      WHEN m.version = COALESCE(s.version, g.latest_version)
                      THEN 0 ELSE 1
                    END,
                    m.version DESC,
                    m.message_order DESC,
                    m.id DESC
                ) AS version_rank
              FROM group_rows g
              JOIN message_rows m
                ON m.conversation_id = ?
               AND COALESCE(m.group_id, m.id) = g.group_id
              LEFT JOIN selections s ON s.group_id = g.group_id
            ),
            ordered AS (
              SELECT
                revision_id,
                group_id,
                role,
                ROW_NUMBER() OVER (ORDER BY anchor_order, revision_id) - 1
                  AS logical_index,
                COUNT(*) OVER () AS total_count
              FROM ranked
              WHERE version_rank = 1
            ),
            target AS (
              SELECT COALESCE(group_id, id) AS group_id, role
              FROM message_rows
              WHERE conversation_id = ? AND id = ?
            ),
            cutoff AS (
              SELECT CASE
                WHEN ? AND target.role = 'user' THEN COALESCE(
                  (
                    SELECT candidate.logical_index
                    FROM ordered candidate
                    WHERE candidate.logical_index = selected.logical_index + 1
                      AND candidate.role = 'assistant'
                  ),
                  selected.logical_index
                )
                ELSE selected.logical_index
              END AS logical_index
              FROM target
              JOIN ordered selected ON selected.group_id = target.group_id
            ),
            limited AS (
              SELECT revision_id, logical_index
              FROM ordered
              WHERE logical_index >= CASE
                WHEN ? >= 0 AND ? <= total_count THEN ?
                ELSE 0
              END
                AND (
                  ? IS NULL OR
                  logical_index <= (SELECT logical_index FROM cutoff)
                )
              ORDER BY logical_index DESC
              LIMIT ?
            )
            SELECT
              m.*,
              p.part_id AS part_part_id,
              p.ordinal AS part_ordinal,
              p.kind AS part_kind,
              p.payload AS part_payload,
              p.created_at AS part_created_at,
              p.updated_at AS part_updated_at
            FROM limited l
            JOIN message_rows m ON m.id = l.revision_id
            LEFT JOIN message_part_rows p ON p.revision_id = m.id
            ORDER BY l.logical_index, p.ordinal;
            ''',
            variables: [
              Variable<String>(conversationId),
              Variable<String>(conversationId),
              Variable<String>(conversationId),
              Variable<String>(conversationId),
              Variable<String>(throughRevisionId ?? ''),
              Variable<bool>(includeFollowingAssistant),
              Variable<int>(truncateIndex),
              Variable<int>(truncateIndex),
              Variable<int>(truncateIndex),
              Variable<String>(throughRevisionId),
              Variable<int>(limit),
            ],
            readsFrom: {
              _db.conversationRows,
              _db.messageRows,
              _db.messagePartRows,
            },
          )
          .get();
      final rowsById = <String, MessageRow>{};
      final partsById = <String, List<MessagePartRow>>{};
      for (final row in result) {
        final message = _db.messageRows.map(row.data);
        rowsById.putIfAbsent(message.id, () => message);
        final ordinal = row.readNullable<int>('part_ordinal');
        if (ordinal == null) continue;
        partsById
            .putIfAbsent(message.id, () => <MessagePartRow>[])
            .add(
              MessagePartRow(
                partId: row.read<int>('part_part_id'),
                conversationId: message.conversationId,
                revisionId: message.id,
                ordinal: ordinal,
                kind: row.read<String>('part_kind'),
                payload: row.read<String>('part_payload'),
                createdAt: _dateTimeFromSqlite(row.data['part_created_at']),
                updatedAt: _dateTimeFromSqlite(row.data['part_updated_at']),
              ),
            );
      }
      return [
        for (final message in rowsById.values)
          _messageFromRow(message, authoritativeParts: partsById[message.id]),
      ];
    }, resultCount: (rows) => rows.length);
  }

  Future<int> getMaxMessageVersionForGroup(
    String conversationId,
    String groupId,
  ) async {
    final maxVersion = _db.messageRows.version.max();
    final row =
        await (_db.selectOnly(_db.messageRows)
              ..addColumns([maxVersion])
              ..where(
                _db.messageRows.conversationId.equals(conversationId) &
                    (_db.messageRows.groupId.equals(groupId) |
                        _db.messageRows.id.equals(groupId)),
              ))
            .getSingle();
    return row.read(maxVersion) ?? -1;
  }

  Future<List<ChatMessage>> getSelectedMessageProjections(
    String conversationId, {
    int summaryCharacters = 200,
  }) async {
    final safeSummaryCharacters = summaryCharacters.clamp(0, 200);
    final rows = await _db
        .customSelect(
          '''
          WITH group_rows AS (
            SELECT
              COALESCE(m.group_id, m.id) AS group_id,
              MIN(m.message_order) AS anchor_order,
              MAX(m.version) AS latest_version
            FROM message_rows m
            WHERE m.conversation_id = ?
            GROUP BY COALESCE(m.group_id, m.id)
          ),
          selections AS (
            SELECT j.key AS group_id, CAST(j.value AS INTEGER) AS version
            FROM conversation_rows c, json_each(c.version_selections_json) j
            WHERE c.id = ?
          ),
          ranked AS (
            SELECT
              m.id,
              m.role,
              m.timestamp,
              m.conversation_id,
              COALESCE(m.group_id, m.id) AS group_id,
              m.version,
              g.anchor_order,
              ROW_NUMBER() OVER (
                PARTITION BY g.group_id
                ORDER BY
                  CASE
                    WHEN m.version = COALESCE(s.version, g.latest_version)
                    THEN 0 ELSE 1
                  END,
                  m.version DESC,
                  m.message_order DESC,
                  m.id DESC
              ) AS version_rank
            FROM group_rows g
            JOIN message_rows m
              ON m.conversation_id = ?
             AND COALESCE(m.group_id, m.id) = g.group_id
            LEFT JOIN selections s ON s.group_id = g.group_id
          )
          SELECT
            ranked.id,
            ranked.role,
            (SELECT SUBSTR(concat_text.txt, 1, ?)
               FROM (
                 SELECT GROUP_CONCAT(ordered.payload, '') AS txt
                 FROM (
                   SELECT p.payload AS payload
                   FROM message_part_rows p
                   WHERE p.revision_id = ranked.id
                     AND p.kind = 'text'
                     AND p.conversation_id = ranked.conversation_id
                   ORDER BY p.revision_id, p.ordinal
                 ) AS ordered
               ) AS concat_text)
              AS content_summary,
            ranked.timestamp,
            ranked.conversation_id,
            ranked.group_id,
            ranked.version
          FROM ranked
          WHERE ranked.version_rank = 1
          ORDER BY ranked.anchor_order, ranked.group_id;
          ''',
          variables: [
            Variable<String>(conversationId),
            Variable<String>(conversationId),
            Variable<String>(conversationId),
            Variable<int>(safeSummaryCharacters),
          ],
          readsFrom: {
            _db.conversationRows,
            _db.messageRows,
            _db.messagePartRows,
          },
        )
        .get();
    return [
      for (final row in rows)
        ChatMessage(
          id: row.read<String>('id'),
          role: row.read<String>('role'),
          content: row.readNullable<String>('content_summary') ?? '',
          timestamp: _dateTimeFromSqlite(row.data['timestamp']),
          conversationId: row.read<String>('conversation_id'),
          groupId: row.read<String>('group_id'),
          version: row.read<int>('version'),
        ),
    ];
  }

  /// Searches the selected visible revision of each message group.
  ///
  /// SQLite `LOWER` / `INSTR` only fold ASCII case. Non-ASCII case variants
  /// (for example Greek or Cyrillic) are not matched; this path does not load
  /// ICU.
  Future<List<MiniMapSearchHit>> searchMiniMapMatches(
    String conversationId,
    String query, {
    int snippetRadius = 40,
    int snippetLength = 120,
  }) {
    return _observer.measure(
      ChatDatabaseOperation.querySearch,
      () => _searchMiniMapMatches(
        conversationId,
        query,
        snippetRadius: snippetRadius,
        snippetLength: snippetLength,
      ),
      resultCount: (rows) => rows.length,
    );
  }

  Future<List<MiniMapSearchHit>> _searchMiniMapMatches(
    String conversationId,
    String query, {
    required int snippetRadius,
    required int snippetLength,
  }) async {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return const <MiniMapSearchHit>[];
    final radius = snippetRadius < 0 ? 0 : snippetRadius;
    final length = miniMapSnippetLength(
      needleLength: needle.length,
      snippetRadius: snippetRadius,
      snippetLength: snippetLength,
    );
    final rows = await _db
        .customSelect(
          '''
          WITH group_rows AS (
            SELECT
              COALESCE(m.group_id, m.id) AS group_id,
              MIN(m.message_order) AS anchor_order,
              MAX(m.version) AS latest_version
            FROM message_rows m
            WHERE m.conversation_id = ?
            GROUP BY COALESCE(m.group_id, m.id)
          ),
          selections AS (
            SELECT j.key AS group_id, CAST(j.value AS INTEGER) AS version
            FROM conversation_rows c, json_each(c.version_selections_json) j
            WHERE c.id = ?
          ),
          ranked AS (
            SELECT
              m.id,
              m.role,
              COALESCE(m.group_id, m.id) AS group_id,
              g.anchor_order,
              ROW_NUMBER() OVER (
                PARTITION BY g.group_id
                ORDER BY
                  CASE
                    WHEN m.version = COALESCE(s.version, g.latest_version)
                    THEN 0 ELSE 1
                  END,
                  m.version DESC,
                  m.message_order DESC,
                  m.id DESC
              ) AS version_rank
            FROM group_rows g
            JOIN message_rows m
              ON m.conversation_id = ?
             AND COALESCE(m.group_id, m.id) = g.group_id
            LEFT JOIN selections s ON s.group_id = g.group_id
          ),
          text_bodies AS (
            SELECT revision_id, GROUP_CONCAT(payload, '') AS txt
            FROM (
              SELECT p.revision_id AS revision_id, p.payload AS payload
              FROM message_part_rows p
              WHERE p.conversation_id = ?
                AND p.kind = 'text'
              ORDER BY p.revision_id, p.ordinal
            )
            GROUP BY revision_id
          ),
          params AS (
            SELECT ? AS needle, ? AS radius, ? AS snippet_len
          )
          SELECT
            ranked.id AS message_id,
            (LENGTH(t.txt) - LENGTH(REPLACE(LOWER(t.txt), p.needle, '')))
              / LENGTH(p.needle) AS match_count,
            SUBSTR(
              t.txt,
              MAX(1, INSTR(LOWER(t.txt), p.needle) - p.radius),
              p.snippet_len
            ) AS snippet,
            MAX(1, INSTR(LOWER(t.txt), p.needle) - p.radius) AS snippet_start
          FROM ranked
          JOIN text_bodies t ON t.revision_id = ranked.id
          CROSS JOIN params p
          WHERE ranked.version_rank = 1
            AND ranked.role IN ('user', 'assistant')
            AND INSTR(LOWER(t.txt), p.needle) > 0
          ORDER BY ranked.anchor_order, ranked.group_id;
          ''',
          variables: [
            Variable<String>(conversationId),
            Variable<String>(conversationId),
            Variable<String>(conversationId),
            Variable<String>(conversationId),
            Variable<String>(needle),
            Variable<int>(radius),
            Variable<int>(length),
          ],
          readsFrom: {
            _db.conversationRows,
            _db.messageRows,
            _db.messagePartRows,
          },
        )
        .get();
    return [
      for (final row in rows)
        MiniMapSearchHit(
          messageId: row.read<String>('message_id'),
          matchCount: row.read<int>('match_count'),
          snippet: row.readNullable<String>('snippet') ?? '',
          snippetStart: row.read<int>('snippet_start') - 1,
        ),
    ];
  }

  Future<Set<String>> getMessageIdsForGroups(
    String conversationId,
    Set<String> groupIds,
  ) async {
    if (groupIds.isEmpty) return const <String>{};
    final rows =
        await (_db.selectOnly(_db.messageRows)
              ..addColumns([_db.messageRows.id])
              ..where(
                _db.messageRows.conversationId.equals(conversationId) &
                    (_db.messageRows.groupId.isIn(groupIds) |
                        _db.messageRows.id.isIn(groupIds)),
              ))
            .get();
    return {for (final row in rows) row.read(_db.messageRows.id)!};
  }

  Future<LinearMessageWindow> loadLinearMessageWindow({
    required String conversationId,
    String? beforeRevisionId,
    String? afterRevisionId,
    String? aroundRevisionId,
    bool fromStart = false,
    int limit = 40,
  }) async {
    if (limit <= 0) {
      return const LinearMessageWindow(
        slots: <LinearMessageWindowSlot>[],
        totalSlotCount: 0,
        hasMoreBefore: false,
        hasMoreAfter: false,
      );
    }
    final cursorCount = <String?>[
      beforeRevisionId,
      afterRevisionId,
      aroundRevisionId,
    ].whereType<String>().length;
    if (cursorCount > 1 || (fromStart && cursorCount > 0)) {
      throw ArgumentError('Only one linear message cursor may be supplied.');
    }
    final cursorVariables = <Variable<Object>>[];
    late final String pageSql;
    if (fromStart) {
      pageSql = 'SELECT * FROM ordered ORDER BY logical_index LIMIT ?';
    } else if (beforeRevisionId != null || afterRevisionId != null) {
      final cursor = beforeRevisionId ?? afterRevisionId!;
      cursorVariables.add(Variable<String>(cursor));
      final comparison = beforeRevisionId != null ? '<' : '>';
      final direction = beforeRevisionId != null ? 'DESC' : 'ASC';
      pageSql =
          '''
        , target_group AS (
          SELECT COALESCE(group_id, id) AS group_id
          FROM message_rows WHERE conversation_id = ? AND id = ?
        ),
        target_index AS (
          SELECT logical_index FROM ordered
          WHERE group_id = (SELECT group_id FROM target_group)
        )
        SELECT * FROM ordered
        WHERE logical_index $comparison (SELECT logical_index FROM target_index)
        ORDER BY logical_index $direction LIMIT ?
      ''';
      cursorVariables.insert(0, Variable<String>(conversationId));
    } else if (aroundRevisionId != null) {
      cursorVariables
        ..add(Variable<String>(conversationId))
        ..add(Variable<String>(aroundRevisionId));
      pageSql = '''
        , target_group AS (
          SELECT COALESCE(group_id, id) AS group_id
          FROM message_rows WHERE conversation_id = ? AND id = ?
        ),
        target_index AS (
          SELECT logical_index FROM ordered
          WHERE group_id = (SELECT group_id FROM target_group)
        ),
        nearest AS (
          SELECT ordered.* FROM ordered, target_index
          ORDER BY ABS(ordered.logical_index - target_index.logical_index),
                   ordered.logical_index
          LIMIT ?
        )
        SELECT * FROM nearest ORDER BY logical_index
      ''';
    } else {
      pageSql = 'SELECT * FROM ordered ORDER BY logical_index DESC LIMIT ?';
    }
    final rows = await _db
        .customSelect(
          '''
          WITH group_rows AS (
            SELECT
              COALESCE(m.group_id, m.id) AS group_id,
              MIN(m.message_order) AS anchor_order,
              COUNT(*) AS version_count,
              MAX(m.version) AS latest_version
            FROM message_rows m
            WHERE m.conversation_id = ?
            GROUP BY COALESCE(m.group_id, m.id)
          ),
          selections AS (
            SELECT j.key AS group_id, CAST(j.value AS INTEGER) AS version
            FROM conversation_rows c, json_each(c.version_selections_json) j
            WHERE c.id = ?
          ),
          ranked AS (
            SELECT
              m.id AS revision_id,
              g.group_id,
              g.anchor_order,
              g.version_count,
              ROW_NUMBER() OVER (
                PARTITION BY g.group_id
                ORDER BY
                  CASE
                    WHEN m.version = COALESCE(s.version, g.latest_version)
                    THEN 0 ELSE 1
                  END,
                  m.version DESC,
                  m.message_order DESC,
                  m.id DESC
              ) AS version_rank
            FROM group_rows g
            JOIN message_rows m
              ON m.conversation_id = ?
             AND COALESCE(m.group_id, m.id) = g.group_id
            LEFT JOIN selections s ON s.group_id = g.group_id
          ),
          ordered AS (
            SELECT
              revision_id,
              group_id,
              version_count,
              ROW_NUMBER() OVER (
                ORDER BY anchor_order, group_id
              ) - 1 AS logical_index,
              COUNT(*) OVER () AS total_count
            FROM ranked
            WHERE version_rank = 1
          )
          $pageSql;
        ''',
          variables: [
            Variable<String>(conversationId),
            Variable<String>(conversationId),
            Variable<String>(conversationId),
            ...cursorVariables,
            Variable<int>(limit),
          ],
          readsFrom: {_db.conversationRows, _db.messageRows},
        )
        .get();
    final orderedRows =
        beforeRevisionId != null ||
            (!fromStart && afterRevisionId == null && aroundRevisionId == null)
        ? rows.reversed
        : rows;
    final slots = orderedRows
        .map(
          (row) => LinearMessageWindowSlot(
            groupId: row.read<String>('group_id'),
            revisionId: row.read<String>('revision_id'),
            versionCount: row.read<int>('version_count'),
            logicalIndex: row.read<int>('logical_index'),
          ),
        )
        .toList(growable: false);
    final total = rows.isEmpty ? 0 : rows.first.read<int>('total_count');
    return LinearMessageWindow(
      slots: slots,
      totalSlotCount: total,
      hasMoreBefore: slots.isNotEmpty && slots.first.logicalIndex > 0,
      hasMoreAfter: slots.isNotEmpty && slots.last.logicalIndex + 1 < total,
    );
  }

  Future<List<ChatMessage>> getMessagesByIds(List<String> ids) async {
    if (ids.isEmpty) return const <ChatMessage>[];
    return _observer.measure(
      ChatDatabaseOperation.queryMessagesByIds,
      () async {
        final rows = await (_db.select(
          _db.messageRows,
        )..where((t) => t.id.isIn(ids))).get();
        final messages = await _messagesFromRowsWithParts(rows);
        final byId = <String, ChatMessage>{
          for (final message in messages) message.id: message,
        };
        return [
          for (final id in ids)
            if (byId[id] != null) byId[id]!,
        ];
      },
      resultCount: (rows) => rows.length,
    );
  }

  Future<Map<String, int>> getFirstMessageIndicesForGroups(
    String conversationId,
    Iterable<String> groupIds,
  ) async {
    final ids = groupIds.where((id) => id.isNotEmpty).toSet();
    if (ids.isEmpty) return const <String, int>{};
    final group = _db.messageRows.groupId;
    final minOrder = _db.messageRows.messageOrder.min();
    final messageId = _db.messageRows.id;
    final rows =
        await (_db.selectOnly(_db.messageRows)
              ..addColumns([group, messageId, minOrder])
              ..where(
                _db.messageRows.conversationId.equals(conversationId) &
                    (group.isIn(ids) | messageId.isIn(ids)),
              )
              ..groupBy([group, messageId]))
            .get();
    return {
      for (final row in rows)
        if ((row.read(group) ?? row.read(messageId)) != null &&
            row.read(minOrder) != null)
          (row.read(group) ?? row.read(messageId))!: row.read(minOrder)!,
    };
  }

  Future<List<ChatMessage>> getMessagesForGroups(
    String conversationId,
    Iterable<String> groupIds,
  ) async {
    final ids = groupIds.where((id) => id.isNotEmpty).toSet();
    if (ids.isEmpty) return const <ChatMessage>[];
    return _observer.measure(
      ChatDatabaseOperation.queryMessagesForGroups,
      () async {
        final rows =
            await (_db.select(_db.messageRows)
                  ..where(
                    (t) =>
                        t.conversationId.equals(conversationId) &
                        (t.groupId.isIn(ids) | t.id.isIn(ids)),
                  )
                  ..orderBy([(t) => OrderingTerm.asc(t.messageOrder)]))
                .get();
        return _messagesFromRowsWithParts(rows);
      },
      resultCount: (rows) => rows.length,
    );
  }

  Future<List<String>> getMessageIds(String conversationId) async {
    return _observer.measure(ChatDatabaseOperation.queryMessageIds, () async {
      final rows =
          await (_db.selectOnly(_db.messageRows)
                ..addColumns([_db.messageRows.id])
                ..where(_db.messageRows.conversationId.equals(conversationId))
                ..orderBy([OrderingTerm.asc(_db.messageRows.messageOrder)]))
              .get();
      return rows
          .map((row) => row.read(_db.messageRows.id)!)
          .toList(growable: false);
    }, resultCount: (rows) => rows.length);
  }

  @Deprecated('legacy/test only; rewrites the complete conversation order')
  Future<void> updateMessageOrder(
    String conversationId,
    List<String> messageIds,
  ) async {
    await _db.transaction(() async {
      await _rewriteMessageOrder(conversationId, messageIds);
    });
  }

  /// Searches conversations for [tokens].
  ///
  /// [conversationId] restricts the search to one conversation and
  /// [excludeConversationId] omits one. Both are applied in SQL rather than by
  /// the caller, because the candidate `LIMIT` is global: a conversation whose
  /// matches rank below the cut would otherwise be filtered down to nothing.
  ///
  /// When [assistantId] is non-empty, only that assistant's conversations and
  /// unowned (`assistant_id IS NULL`) chats are included. The predicate uses
  /// `idx_conversations_assistant`; NULL rows stay visible so pre-ownership
  /// history is not dropped.
  Future<List<ConversationSearchMatch>> searchConversationMatches({
    required List<String> tokens,
    int limit = 200,
    int candidateMultiplier = 8,
    bool includeAllRevisions = false,
    String? conversationId,
    String? excludeConversationId,
    String? assistantId,
  }) {
    return _observer.measure(
      ChatDatabaseOperation.querySearch,
      () => _searchConversationMatches(
        tokens: tokens,
        limit: limit,
        candidateMultiplier: candidateMultiplier,
        includeAllRevisions: includeAllRevisions,
        conversationId: conversationId,
        excludeConversationId: excludeConversationId,
        assistantId: assistantId,
      ),
      resultCount: (rows) => rows.length,
    );
  }

  Future<List<ConversationSearchMatch>> _searchConversationMatches({
    required List<String> tokens,
    required int limit,
    required int candidateMultiplier,
    required bool includeAllRevisions,
    String? conversationId,
    String? excludeConversationId,
    String? assistantId,
  }) async {
    final cleanTokens = tokens
        .map((token) => token.trim().toLowerCase())
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
    if (cleanTokens.isEmpty || limit <= 0) {
      return const <ConversationSearchMatch>[];
    }
    await _ensureMessageSearchFts();
    final useSubstringFallback = cleanTokens.any(_requiresCjkFallback);

    String escapeLike(String value) => value
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');

    final titleClauses = <String>[];
    final existsClauses = <String>[];
    final messageAnyClauses = <String>[];
    final titleArgs = <Object?>[];
    final existsArgs = <Object?>[];
    final messageArgs = <Object?>[];
    for (final token in cleanTokens) {
      final pattern = '%${escapeLike(token)}%';
      titleClauses.add('LOWER(c.title) LIKE ? ESCAPE \'\\\'');
      titleArgs.add(pattern);
      existsClauses.add('''
        EXISTS (
          SELECT 1 FROM message_rows mx
          WHERE mx.conversation_id = c.id
            AND mx.role IN ('user', 'assistant')
            AND EXISTS (
              SELECT 1 FROM message_part_rows px
              WHERE px.revision_id = mx.id
                AND px.kind = 'text'
                AND LOWER(px.payload) LIKE ? ESCAPE '\\'
            )
            ${includeAllRevisions ? '' : 'AND EXISTS (SELECT 1 FROM visible_groups visible WHERE visible.conversation_id = mx.conversation_id AND visible.group_id = COALESCE(mx.group_id, mx.id) AND visible.selected_version = mx.version)'}
        )
        ''');
      existsArgs.add(pattern);
      if (useSubstringFallback) {
        messageAnyClauses.add('''
          EXISTS (
            SELECT 1 FROM message_part_rows px
            WHERE px.revision_id = m.id
              AND px.kind = 'text'
              AND LOWER(px.payload) LIKE ? ESCAPE '\\'
          )
          ''');
        messageArgs.add(pattern);
      }
    }
    final ftsQuery = cleanTokens
        .map((token) => '"${token.replaceAll('"', '""')}"')
        .join(' AND ');
    if (!useSubstringFallback) {
      messageAnyClauses.add(
        'm.id IN (SELECT revision_id FROM message_search_fts '
        'WHERE payload MATCH ?)',
      );
      messageArgs.add(ftsQuery);
      existsClauses
        ..clear()
        ..add('''
        EXISTS (
          SELECT 1 FROM message_search_fts fx
          WHERE fx.conversation_id = c.id AND fx.payload MATCH ?
            ${includeAllRevisions ? '' : 'AND EXISTS (SELECT 1 FROM visible_groups visible INNER JOIN message_rows selected ON selected.id = fx.revision_id WHERE visible.conversation_id = selected.conversation_id AND visible.group_id = COALESCE(selected.group_id, selected.id) AND visible.selected_version = selected.version)'}
        )
        ''');
      existsArgs
        ..clear()
        ..add(ftsQuery);
    }

    // Applied alongside the match predicate so the candidate LIMIT is spent on
    // rows the caller can actually use.
    final scopeArgs = <String>[];
    var scopeSql = '';
    if (conversationId != null && conversationId.isNotEmpty) {
      scopeSql = 'AND c.id = ?';
      scopeArgs.add(conversationId);
    } else if (excludeConversationId != null &&
        excludeConversationId.isNotEmpty) {
      scopeSql = 'AND c.id <> ?';
      scopeArgs.add(excludeConversationId);
    }
    if (assistantId != null && assistantId.isNotEmpty) {
      scopeSql += ' AND (c.assistant_id = ? OR c.assistant_id IS NULL)';
      scopeArgs.add(assistantId);
    }

    final candidateLimit = (limit * candidateMultiplier)
        .clamp(limit, 2000)
        .toInt();
    final rows = await _db
        .customSelect(
          '''
      WITH selections AS (
        SELECT c.id AS conversation_id, j.key AS group_id,
               CAST(j.value AS INTEGER) AS selected_version
        FROM conversation_rows c, json_each(c.version_selections_json) j
      ), visible_groups AS (
        SELECT
          m.conversation_id,
          COALESCE(m.group_id, m.id) AS group_id,
          MAX(m.version) AS max_version,
          COALESCE(
            MAX(CASE
              WHEN m.version = s.selected_version THEN m.version
            END),
            MAX(m.version)
          ) AS selected_version
        FROM message_rows m
        LEFT JOIN selections s
          ON s.conversation_id = m.conversation_id
         AND s.group_id = COALESCE(m.group_id, m.id)
        GROUP BY m.conversation_id, COALESCE(m.group_id, m.id)
      )
      SELECT
        c.id AS conversation_id,
        c.title AS conversation_title,
        c.updated_at AS updated_at,
        m.id AS message_id,
        (
          SELECT px.payload
          FROM message_part_rows px
          WHERE px.revision_id = m.id AND px.kind = 'text'
          ORDER BY px.ordinal
          LIMIT 1
        ) AS message_content,
        m.role AS message_role,
        m.group_id AS group_id,
        m.version AS version,
        m.message_order AS message_order,
        (
          SELECT visible.selected_version
          FROM visible_groups visible
          WHERE visible.conversation_id = m.conversation_id
            AND visible.group_id = COALESCE(m.group_id, m.id)
          LIMIT 1
        ) AS selected_version,
        (
          SELECT visible.max_version
          FROM visible_groups visible
          WHERE visible.conversation_id = m.conversation_id
            AND visible.group_id = COALESCE(m.group_id, m.id)
          LIMIT 1
        ) AS max_version
      FROM conversation_rows c
      LEFT JOIN message_rows m
        ON m.conversation_id = c.id
        AND m.role IN ('user', 'assistant')
        AND (${messageAnyClauses.join(' OR ')})
        ${includeAllRevisions ? '' : 'AND EXISTS (SELECT 1 FROM visible_groups visible WHERE visible.conversation_id = m.conversation_id AND visible.group_id = COALESCE(m.group_id, m.id) AND visible.selected_version = m.version)'}
      WHERE ((${titleClauses.join(' AND ')}) OR (${existsClauses.join(' AND ')}))
        $scopeSql
      ORDER BY c.updated_at DESC, m.message_order ASC
      LIMIT ?
      ''',
          variables: [
            ...messageArgs.map((value) => Variable<String>(value! as String)),
            ...titleArgs.map((value) => Variable<String>(value! as String)),
            ...existsArgs.map((value) => Variable<String>(value! as String)),
            ...scopeArgs.map(Variable<String>.new),
            Variable<int>(candidateLimit),
          ],
        )
        .get();

    return rows
        .map((row) {
          final groupId = row.readNullable<String>('group_id');
          final messageId = row.readNullable<String>('message_id');
          final effectiveGroupId = groupId ?? messageId;
          final selectedVersion = row.readNullable<int>('selected_version');
          return ConversationSearchMatch(
            conversationId: row.read<String>('conversation_id'),
            conversationTitle: row.read<String>('conversation_title'),
            updatedAt: _dateTimeFromSqlite(row.read<int>('updated_at')),
            versionSelections:
                effectiveGroupId == null || selectedVersion == null
                ? const {}
                : {effectiveGroupId: selectedVersion},
            messageId: messageId,
            messageContent: row.readNullable<String>('message_content'),
            messageRole: row.readNullable<String>('message_role'),
            groupId: groupId,
            version: row.readNullable<int>('version'),
            maxVersion: row.readNullable<int>('max_version'),
          );
        })
        .toList(growable: false);
  }

  Future<ChatStatsAggregate> queryStatsAggregate({
    required DateTime? rangeStart,
    required DateTime? rangeEndExclusive,
    required DateTime heatmapStart,
    required DateTime trendStart,
    required DateTime trendEndExclusive,
  }) async {
    final start = rangeStart?.microsecondsSinceEpoch;
    final end = rangeEndExclusive?.microsecondsSinceEpoch;
    final rangeClause = <String>[
      if (start != null) 'm.timestamp >= ?',
      if (end != null) 'm.timestamp < ?',
    ].join(' AND ');
    final rangeWhere = rangeClause.isEmpty ? '' : 'AND $rangeClause';
    final rangeVariables = <Variable>[
      if (start != null) Variable<int>(start),
      if (end != null) Variable<int>(end),
    ];
    final conversationRangeClause = <String>[
      if (start != null) 'c.created_at >= ?',
      if (end != null) 'c.created_at < ?',
    ].join(' AND ');

    final summary = await _db
        .customSelect(
          '''
      SELECT
        (SELECT COUNT(*) FROM conversation_rows c
          ${conversationRangeClause.isEmpty ? '' : 'WHERE $conversationRangeClause'}) AS conversations,
        COUNT(*) AS messages,
        COALESCE(SUM(prompt_tokens), 0) AS input_tokens,
        COALESCE(SUM(completion_tokens), 0) AS output_tokens,
        COALESCE(SUM(cached_tokens), 0) AS cached_tokens
      FROM message_rows m WHERE 1 = 1 $rangeWhere;
    ''',
          variables: [...rangeVariables, ...rangeVariables],
        )
        .getSingle();

    final heatmapRows = await _db
        .customSelect(
          '''
      SELECT strftime('%Y-%m-%d', m.timestamp / 1000000.0,
          'unixepoch', 'localtime') AS day,
        COUNT(*) AS message_count
      FROM message_rows m
      WHERE m.timestamp >= ?
      GROUP BY day ORDER BY day;
    ''',
          variables: [Variable<int>(heatmapStart.microsecondsSinceEpoch)],
        )
        .get();

    final trendRows = await _db
        .customSelect(
          '''
      SELECT strftime('%Y-%m-%d', m.timestamp / 1000000.0,
          'unixepoch', 'localtime') AS day,
        COALESCE(NULLIF(TRIM(m.provider_id), ''), '_unknown') AS provider_id,
        COUNT(*) AS activity_count,
        COALESCE(SUM(m.prompt_tokens), 0) AS input_tokens,
        COALESCE(SUM(m.completion_tokens), 0) AS output_tokens,
        COALESCE(SUM(m.cached_tokens), 0) AS cached_tokens,
        COALESCE(SUM(CASE WHEN COALESCE(m.prompt_tokens, 0) = 0
          AND COALESCE(m.completion_tokens, 0) = 0
          THEN COALESCE(m.total_tokens, 0) ELSE 0 END), 0) AS uncategorized_tokens
      FROM message_rows m
      WHERE m.timestamp >= ? AND m.timestamp < ?
        AND (NULLIF(TRIM(m.provider_id), '') IS NOT NULL
          OR COALESCE(m.prompt_tokens, 0) != 0
          OR COALESCE(m.completion_tokens, 0) != 0
          OR COALESCE(m.cached_tokens, 0) != 0
          OR COALESCE(m.total_tokens, 0) != 0)
      GROUP BY day, provider_id ORDER BY day, provider_id;
    ''',
          variables: [
            Variable<int>(trendStart.microsecondsSinceEpoch),
            Variable<int>(trendEndExclusive.microsecondsSinceEpoch),
          ],
        )
        .get();

    final modelRows = await _db.customSelect('''
      SELECT m.model_id AS id, MIN(m.provider_id) AS provider_id,
        COUNT(*) AS item_count
      FROM message_rows m
      WHERE NULLIF(TRIM(m.model_id), '') IS NOT NULL $rangeWhere
      GROUP BY m.model_id ORDER BY item_count DESC, id;
    ''', variables: rangeVariables).get();
    final topicRows = await _db.customSelect('''
      SELECT c.id AS id, c.title AS label, COUNT(*) AS item_count
      FROM message_rows m
      JOIN conversation_rows c ON c.id = m.conversation_id
      WHERE 1 = 1 $rangeWhere
      GROUP BY c.id, c.title ORDER BY item_count DESC, c.id;
    ''', variables: rangeVariables).get();
    final conversationRange = <String>[
      if (start != null) 'created_at >= ?',
      if (end != null) 'created_at < ?',
    ].join(' AND ');
    final assistantRows = await _db.customSelect('''
      SELECT COALESCE(NULLIF(TRIM(assistant_id), ''), '_default') AS id,
        COUNT(*) AS item_count
      FROM conversation_rows
      ${conversationRange.isEmpty ? '' : 'WHERE $conversationRange'}
      GROUP BY id ORDER BY item_count DESC, id;
    ''', variables: rangeVariables).get();

    return ChatStatsAggregate(
      conversations: summary.read<int>('conversations'),
      totals: ChatStatsTotals(
        messages: summary.read<int>('messages'),
        inputTokens: summary.read<int>('input_tokens'),
        outputTokens: summary.read<int>('output_tokens'),
        cachedTokens: summary.read<int>('cached_tokens'),
      ),
      heatmap: [
        for (final row in heatmapRows)
          ChatStatsDayCount(
            day: DateTime.parse(row.read<String>('day')),
            count: row.read<int>('message_count'),
          ),
      ],
      trend: [
        for (final row in trendRows)
          ChatStatsTrendBucket(
            day: DateTime.parse(row.read<String>('day')),
            providerId: row.read<String>('provider_id'),
            activityCount: row.read<int>('activity_count'),
            inputTokens: row.read<int>('input_tokens'),
            outputTokens: row.read<int>('output_tokens'),
            cachedTokens: row.read<int>('cached_tokens'),
            uncategorizedTokens: row.read<int>('uncategorized_tokens'),
          ),
      ],
      models: [
        for (final row in modelRows)
          ChatStatsRank(
            id: row.read<String>('id'),
            label: row.read<String>('id'),
            count: row.read<int>('item_count'),
            providerId: row.readNullable<String>('provider_id'),
          ),
      ],
      assistants: [
        for (final row in assistantRows)
          ChatStatsRank(
            id: row.read<String>('id'),
            label: row.read<String>('id'),
            count: row.read<int>('item_count'),
          ),
      ],
      topics: [
        for (final row in topicRows)
          ChatStatsRank(
            id: row.read<String>('id'),
            label: row.read<String>('label'),
            count: row.read<int>('item_count'),
          ),
      ],
    );
  }

  Future<void> registerAsset({
    required String id,
    required String contentHash,
    required String path,
    required int byteSize,
    int? width,
    int? height,
    String? thumbnailPath,
    DateTime? createdAt,
  }) async {
    final timestamp = (createdAt ?? DateTime.now()).microsecondsSinceEpoch;
    await _db.customStatement(
      '''
      INSERT INTO asset_rows(
        id, content_hash, path, byte_size, width, height, thumbnail_path,
        created_at, last_referenced_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        content_hash = excluded.content_hash,
        path = excluded.path,
        byte_size = excluded.byte_size,
        width = excluded.width,
        height = excluded.height,
        thumbnail_path = excluded.thumbnail_path;
    ''',
      [
        id,
        contentHash,
        path,
        byteSize,
        width,
        height,
        thumbnailPath,
        timestamp,
        timestamp,
      ],
    );
  }

  Future<void> linkMessageAsset({
    required String conversationId,
    required String revisionId,
    required String assetId,
    required String kind,
  }) async {
    await _db.transaction(() async {
      await _db.customStatement(
        '''
        INSERT OR IGNORE INTO message_asset_rows(
          conversation_id, revision_id, asset_id, kind
        ) VALUES (?, ?, ?, ?);
      ''',
        [conversationId, revisionId, assetId, kind],
      );
      await _db.customStatement(
        'UPDATE asset_rows SET last_referenced_at = '
        'MAX(last_referenced_at + 1, ?) WHERE id = ?;',
        [DateTime.now().microsecondsSinceEpoch, assetId],
      );
      await _db.customStatement(
        'DELETE FROM asset_gc_rows WHERE asset_id = ?;',
        [assetId],
      );
    });
  }

  Future<void> replaceMessageAssetReferences({
    required String conversationId,
    required String revisionId,
    required List<MessageAssetRegistration> assets,
  }) async {
    await _db.transaction(() async {
      await _db.customStatement(
        'DELETE FROM message_asset_rows WHERE revision_id = ?;',
        [revisionId],
      );
      final now = DateTime.now().microsecondsSinceEpoch;
      for (final asset in assets) {
        await _db.customStatement(
          '''
          INSERT INTO asset_rows(
            id, content_hash, path, byte_size, width, height, thumbnail_path,
            created_at, last_referenced_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
          ON CONFLICT(id) DO UPDATE SET
            path = excluded.path,
            byte_size = excluded.byte_size,
            width = excluded.width,
            height = excluded.height,
            thumbnail_path = excluded.thumbnail_path,
            last_referenced_at = MAX(
              asset_rows.last_referenced_at + 1,
              excluded.last_referenced_at
            );
        ''',
          [
            asset.assetId,
            asset.contentHash,
            asset.path,
            asset.byteSize,
            asset.width,
            asset.height,
            asset.thumbnailPath,
            now,
            now,
          ],
        );
        await _db.customStatement(
          '''
          INSERT OR IGNORE INTO message_asset_rows(
            conversation_id, revision_id, asset_id, kind
          ) VALUES (?, ?, ?, ?);
        ''',
          [conversationId, revisionId, asset.assetId, asset.kind],
        );
        await _db.customStatement(
          'DELETE FROM asset_gc_rows WHERE asset_id = ?;',
          [asset.assetId],
        );
      }
      await _db.customStatement(
        'DELETE FROM asset_reference_dirty_rows WHERE revision_id = ?;',
        [revisionId],
      );
    });
  }

  Future<void> unlinkMessageAsset({
    required String revisionId,
    required String assetId,
  }) async {
    await _db.customStatement(
      'DELETE FROM message_asset_rows WHERE revision_id = ? AND asset_id = ?;',
      [revisionId, assetId],
    );
  }

  Future<int> scheduleUnreferencedAssetGc({required DateTime notBefore}) async {
    await _db.customStatement(
      '''
      INSERT OR IGNORE INTO asset_gc_rows(
        asset_id, not_before, attempts, generation
      )
      SELECT a.id, ?, 0, a.last_referenced_at FROM asset_rows a
      WHERE NOT EXISTS (
        SELECT 1 FROM message_asset_rows r WHERE r.asset_id = a.id
      );
    ''',
      [notBefore.microsecondsSinceEpoch],
    );
    final row = await _db
        .customSelect('SELECT changes() AS changed;')
        .getSingle();
    return row.read<int>('changed');
  }

  Future<List<AssetGcCandidate>> claimAssetGc({
    required DateTime now,
    int limit = 50,
    @visibleForTesting int maxScan = 500,
  }) async {
    if (limit <= 0) return const <AssetGcCandidate>[];
    return _db.transaction(() async {
      // Page candidates with keyset pagination, then ask SQLite once per page
      // whether any dirty text references those paths (set-based instr). Never
      // pull the full dirty payload corpus into Dart.
      final ids = <String>[];
      final protectedIds = <String>[];
      var scanned = 0;
      const pageSize = 50;
      int? cursorNotBefore;
      String? cursorAssetId;

      while (ids.length < limit && scanned < maxScan) {
        final List<QueryRow> dueRows;
        if (cursorNotBefore == null) {
          dueRows = await _db
              .customSelect(
                '''
            SELECT g.asset_id, a.path, g.not_before FROM asset_gc_rows g
            JOIN asset_rows a ON a.id = g.asset_id
            WHERE g.not_before <= ?
              AND NOT EXISTS (
                SELECT 1 FROM message_asset_rows r
                WHERE r.asset_id = g.asset_id
              )
            ORDER BY g.not_before, g.asset_id
            LIMIT ?;
          ''',
                variables: [
                  Variable<int>(now.microsecondsSinceEpoch),
                  Variable<int>(pageSize),
                ],
              )
              .get();
        } else {
          dueRows = await _db
              .customSelect(
                '''
            SELECT g.asset_id, a.path, g.not_before FROM asset_gc_rows g
            JOIN asset_rows a ON a.id = g.asset_id
            WHERE g.not_before <= ?
              AND NOT EXISTS (
                SELECT 1 FROM message_asset_rows r
                WHERE r.asset_id = g.asset_id
              )
              AND (
                g.not_before > ?
                OR (g.not_before = ? AND g.asset_id > ?)
              )
            ORDER BY g.not_before, g.asset_id
            LIMIT ?;
          ''',
                variables: [
                  Variable<int>(now.microsecondsSinceEpoch),
                  Variable<int>(cursorNotBefore),
                  Variable<int>(cursorNotBefore),
                  Variable<String>(cursorAssetId!),
                  Variable<int>(pageSize),
                ],
              )
              .get();
        }
        if (dueRows.isEmpty) break;

        final page = <({String id, String path, int notBefore})>[];
        for (final row in dueRows) {
          if (scanned >= maxScan) break;
          scanned += 1;
          final assetId = row.read<String>('asset_id');
          final path = row.read<String>('path');
          final notBefore = row.read<int>('not_before');
          cursorNotBefore = notBefore;
          cursorAssetId = assetId;
          page.add((id: assetId, path: path, notBefore: notBefore));
        }
        if (page.isEmpty) break;

        final protected = await _dirtyPartProtectedAssetIds(page);
        for (final item in page) {
          if (ids.length >= limit) break;
          if (protected.contains(item.id)) {
            protectedIds.add(item.id);
            continue;
          }
          ids.add(item.id);
        }
        if (dueRows.length < pageSize) break;
      }

      if (protectedIds.isNotEmpty) {
        final deferUntil = now
            .add(const Duration(hours: 6))
            .microsecondsSinceEpoch;
        final placeholders = List.filled(protectedIds.length, '?').join(',');
        await _db.customStatement(
          'UPDATE asset_gc_rows SET not_before = ? '
          'WHERE asset_id IN ($placeholders);',
          [deferUntil, ...protectedIds],
        );
      }

      if (ids.isEmpty) return const <AssetGcCandidate>[];
      for (final id in ids) {
        await _db.customStatement(
          'UPDATE asset_gc_rows SET attempts = attempts + 1, '
          'generation = generation + 1 WHERE asset_id = ?;',
          [id],
        );
      }
      final rows = await _db.customSelect(
        '''
            SELECT a.id, a.path, a.thumbnail_path, a.byte_size, g.generation
            FROM asset_gc_rows g JOIN asset_rows a ON a.id = g.asset_id
            WHERE a.id IN (${List.filled(ids.length, '?').join(',')})
            ORDER BY g.not_before, a.id;
          ''',
        variables: ids.map(Variable<String>.new).toList(growable: false),
      ).get();
      return [
        for (final row in rows)
          AssetGcCandidate(
            assetId: row.read<String>('id'),
            path: row.read<String>('path'),
            thumbnailPath: row.readNullable<String>('thumbnail_path'),
            byteSize: row.read<int>('byte_size'),
            generation: row.read<int>('generation'),
          ),
      ];
    });
  }

  /// Set-based dirty-part protection for a candidate page.
  ///
  /// A never-registered malformed attachment whose raw payload no longer
  /// contains its path (for example, a non-string `uri`) cannot be protected
  /// here and may be collected. We accept that residual loss window because a
  /// global malformed-part interlock would let one corrupt row disable all
  /// asset GC indefinitely and cause unbounded disk growth.
  Future<Set<String>> _dirtyPartProtectedAssetIds(
    List<({String id, String path, int notBefore})> page,
  ) async {
    if (page.isEmpty) return const <String>{};
    final tuples = List.filled(page.length, '(?, ?, ?, ?, ?)').join(', ');
    final variables = <Variable<Object>>[];
    for (final item in page) {
      final pathForm = item.path.isEmpty ? ' ' : item.path;
      final altForm = _alternateAssetPathForm(pathForm);
      final jsonPathForm = _jsonEscapedPathForm(pathForm);
      final jsonAltForm = _jsonEscapedPathForm(altForm);
      variables
        ..add(Variable<String>(item.id))
        ..add(Variable<String>(pathForm))
        ..add(Variable<String>(altForm))
        ..add(Variable<String>(jsonPathForm))
        ..add(Variable<String>(jsonAltForm));
    }
    final rows = await _db.customSelect('''
          WITH candidates(
            asset_id, path_form, alt_form, json_path_form, json_alt_form
          ) AS (
            VALUES $tuples
          )
          SELECT DISTINCT c.asset_id AS asset_id
          FROM candidates c
          WHERE EXISTS (
            SELECT 1
            FROM asset_reference_dirty_rows d
            JOIN message_part_rows p ON p.revision_id = d.revision_id
            WHERE p.kind IN ('text', 'image', 'file')
              AND (
                instr(p.payload, c.path_form) > 0
                OR instr(p.payload, c.alt_form) > 0
                OR instr(p.payload, c.json_path_form) > 0
                OR instr(p.payload, c.json_alt_form) > 0
              )
          );
        ''', variables: variables).get();
    return {for (final row in rows) row.read<String>('asset_id')};
  }

  Future<bool> isAssetGcClaimStillValid(AssetGcCandidate candidate) async {
    final pathForm = candidate.path.isEmpty ? ' ' : candidate.path;
    final altForm = _alternateAssetPathForm(pathForm);
    final jsonPathForm = _jsonEscapedPathForm(pathForm);
    final jsonAltForm = _jsonEscapedPathForm(altForm);
    final row = await _db
        .customSelect(
          '''
          SELECT 1 AS valid FROM asset_gc_rows g
          WHERE g.asset_id = ? AND g.generation = ?
            AND NOT EXISTS (
              SELECT 1 FROM message_asset_rows r
              WHERE r.asset_id = g.asset_id
            )
            AND NOT EXISTS (
              SELECT 1 FROM asset_reference_dirty_rows d
              JOIN message_part_rows p ON p.revision_id = d.revision_id
              WHERE p.kind IN ('text', 'image', 'file')
                AND (
                  instr(p.payload, ?) > 0 OR instr(p.payload, ?) > 0
                  OR instr(p.payload, ?) > 0 OR instr(p.payload, ?) > 0
                )
            )
          LIMIT 1;
        ''',
          variables: [
            Variable<String>(candidate.assetId),
            Variable<int>(candidate.generation),
            Variable<String>(pathForm),
            Variable<String>(altForm),
            Variable<String>(jsonPathForm),
            Variable<String>(jsonAltForm),
          ],
        )
        .getSingleOrNull();
    return row != null;
  }

  Future<bool> completeAssetGc({
    required String assetId,
    required int expectedGeneration,
    required String path,
    DateTime? completedAt,
  }) async {
    // Dirty-part protection must match either stored form. Never pass '' —
    // instr(x, '') is always true and would stall GC forever.
    final pathForm = path.isEmpty ? ' ' : path;
    final altForm = _alternateAssetPathForm(pathForm);
    final jsonPathForm = _jsonEscapedPathForm(pathForm);
    final jsonAltForm = _jsonEscapedPathForm(altForm);
    return _db.transaction(() async {
      final claim = await _db
          .customSelect(
            '''
            SELECT 1 AS valid FROM asset_gc_rows g
            WHERE g.asset_id = ? AND g.generation = ?
              AND NOT EXISTS (
                SELECT 1 FROM message_asset_rows r
                WHERE r.asset_id = g.asset_id
              )
              AND NOT EXISTS (
                SELECT 1 FROM asset_reference_dirty_rows d
                JOIN message_part_rows p ON p.revision_id = d.revision_id
                WHERE p.kind IN ('text', 'image', 'file')
                  AND (
                    instr(p.payload, ?) > 0 OR instr(p.payload, ?) > 0
                    OR instr(p.payload, ?) > 0 OR instr(p.payload, ?) > 0
                  )
              )
            LIMIT 1;
          ''',
            variables: [
              Variable<String>(assetId),
              Variable<int>(expectedGeneration),
              Variable<String>(pathForm),
              Variable<String>(altForm),
              Variable<String>(jsonPathForm),
              Variable<String>(jsonAltForm),
            ],
          )
          .getSingleOrNull();
      if (claim == null) return false;
      await _db.customStatement('DELETE FROM asset_rows WHERE id = ?;', [
        assetId,
      ]);
      final changed =
          (await _db.customSelect('SELECT changes() AS changed;').getSingle())
              .read<int>('changed');
      if (changed == 0) return false;
      await _db.customStatement(
        '''
        INSERT INTO gc_audit_rows(kind, entity_id, completed_at)
        VALUES ('asset', ?, ?);
      ''',
        [assetId, (completedAt ?? DateTime.now()).microsecondsSinceEpoch],
      );
      return true;
    });
  }

  bool _requiresCjkFallback(String token) {
    return RegExp(
      r'[\u3400-\u9fff\uf900-\ufaff\u3040-\u30ff\uac00-\ud7af]',
    ).hasMatch(token);
  }

  Future<void> _ensureMessageSearchFts() async {
    if (_messageSearchFtsReady) return;
    final existing = await _db
        .customSelect(
          "SELECT sql FROM sqlite_master "
          "WHERE type = 'table' AND name = 'message_search_fts';",
        )
        .getSingleOrNull();
    final existingSql = existing?.readNullable<String>('sql') ?? '';
    final externalContent =
        existingSql.contains("content='message_part_rows'") &&
        existingSql.contains("content_rowid='part_id'");
    if (existing != null && !externalContent) {
      await _db.transaction(() async {
        await _db.customStatement(
          'DROP TRIGGER IF EXISTS message_search_fts_insert;',
        );
        await _db.customStatement(
          'DROP TRIGGER IF EXISTS message_search_fts_delete;',
        );
        await _db.customStatement(
          'DROP TRIGGER IF EXISTS message_search_fts_update;',
        );
        await _db.customStatement(
          'DROP TRIGGER IF EXISTS message_search_fts_finalize;',
        );
        await _db.customStatement(
          'DROP TRIGGER IF EXISTS message_search_fts_unindex;',
        );
        await _db.customStatement(
          'DROP TRIGGER IF EXISTS message_search_fts_message_delete;',
        );
        await _db.customStatement('DROP TABLE message_search_fts;');
      });
    }
    final needsRebuild = existing == null || !externalContent;
    await _db.customStatement('''
      CREATE VIRTUAL TABLE IF NOT EXISTS message_search_fts USING fts5(
        revision_id UNINDEXED,
        conversation_id UNINDEXED,
        payload,
        content='message_part_rows',
        content_rowid='part_id',
        tokenize = 'unicode61 remove_diacritics 2'
      );
    ''');
    // Index only finalized text parts. Positive EXISTS (not NOT EXISTS) so a
    // deferred part insert that races ahead of its message_rows parent stays
    // out of the index until a later finalize/rebuild path can see is_streaming=0.
    await _db.customStatement('''
      CREATE TRIGGER IF NOT EXISTS message_search_fts_insert
      AFTER INSERT ON message_part_rows
      WHEN new.kind = 'text'
       AND EXISTS (
         SELECT 1 FROM message_rows m
         WHERE m.id = new.revision_id AND m.is_streaming = 0
       )
      BEGIN
        INSERT INTO message_search_fts(
          rowid, revision_id, conversation_id, payload
        ) VALUES (
          new.part_id, new.revision_id, new.conversation_id, new.payload
        );
      END;
    ''');
    // Symmetric with insert: only reverse-delete postings that were indexed.
    // During ON DELETE CASCADE the parent message_rows row is already gone, so
    // this WHEN fails — message_search_fts_message_delete covers that path.
    await _db.customStatement('''
      CREATE TRIGGER IF NOT EXISTS message_search_fts_delete
      AFTER DELETE ON message_part_rows
      WHEN old.kind = 'text'
       AND EXISTS (
         SELECT 1 FROM message_rows m
         WHERE m.id = old.revision_id AND m.is_streaming = 0
       )
      BEGIN
        INSERT INTO message_search_fts(
          message_search_fts, rowid, revision_id, conversation_id, payload
        ) VALUES (
          'delete', old.part_id, old.revision_id, old.conversation_id,
          old.payload
        );
      END;
    ''');
    // Rare direct payload rewrites (e.g. sandbox path migration). Normal
    // checkpoints delete+insert parts instead.
    await _db.customStatement('''
      CREATE TRIGGER IF NOT EXISTS message_search_fts_update
      AFTER UPDATE OF payload, conversation_id, kind ON message_part_rows
      WHEN (old.kind = 'text' OR new.kind = 'text')
       AND EXISTS (
         SELECT 1 FROM message_rows m
         WHERE m.id = new.revision_id AND m.is_streaming = 0
       )
      BEGIN
        INSERT INTO message_search_fts(
          message_search_fts, rowid, revision_id, conversation_id, payload
        )
        SELECT
          'delete', old.part_id, old.revision_id, old.conversation_id,
          old.payload
        WHERE old.kind = 'text';
        INSERT INTO message_search_fts(
          rowid, revision_id, conversation_id, payload
        )
        SELECT
          new.part_id, new.revision_id, new.conversation_id, new.payload
        WHERE new.kind = 'text';
      END;
    ''');
    // Streaming checkpoints defer FTS; when is_streaming flips to 0, index the
    // text parts present at that moment. The subsequent part rewrite (if any)
    // then delete+inserts under the finalized gate.
    await _db.customStatement('''
      CREATE TRIGGER IF NOT EXISTS message_search_fts_finalize
      AFTER UPDATE OF is_streaming ON message_rows
      WHEN old.is_streaming <> 0 AND new.is_streaming = 0
      BEGIN
        INSERT INTO message_search_fts(
          rowid, revision_id, conversation_id, payload
        )
        SELECT
          p.part_id, p.revision_id, p.conversation_id, p.payload
        FROM message_part_rows p
        WHERE p.revision_id = new.id AND p.kind = 'text';
      END;
    ''');
    // Symmetric with finalize: reopening a finished revision (0→1) must drop
    // its postings before streaming checkpoints rewrite parts under the
    // is_streaming≠0 gate that would otherwise leave orphan FTS rows.
    await _db.customStatement('''
      CREATE TRIGGER IF NOT EXISTS message_search_fts_unindex
      AFTER UPDATE OF is_streaming ON message_rows
      WHEN old.is_streaming = 0 AND new.is_streaming <> 0
      BEGIN
        INSERT INTO message_search_fts(
          message_search_fts, rowid, revision_id, conversation_id, payload
        )
        SELECT
          'delete', p.part_id, p.revision_id, p.conversation_id, p.payload
        FROM message_part_rows p
        WHERE p.revision_id = new.id AND p.kind = 'text';
      END;
    ''');
    // Cascade deletes remove parts after the parent row is invisible to the
    // part DELETE trigger's EXISTS gate. Clean FTS here first, and only for
    // revisions that were eligible to be indexed (is_streaming = 0).
    await _db.customStatement('''
      CREATE TRIGGER IF NOT EXISTS message_search_fts_message_delete
      BEFORE DELETE ON message_rows
      WHEN old.is_streaming = 0
      BEGIN
        INSERT INTO message_search_fts(
          message_search_fts, rowid, revision_id, conversation_id, payload
        )
        SELECT
          'delete', p.part_id, p.revision_id, p.conversation_id, p.payload
        FROM message_part_rows p
        WHERE p.revision_id = old.id AND p.kind = 'text';
      END;
    ''');
    if (needsRebuild) {
      await _db.customStatement('''
        INSERT INTO message_search_fts(
          rowid, revision_id, conversation_id, payload
        )
        SELECT
          p.part_id, p.revision_id, p.conversation_id, p.payload
        FROM message_part_rows p
        INNER JOIN message_rows m ON m.id = p.revision_id
        WHERE p.kind = 'text' AND m.is_streaming = 0;
      ''');
    }
    _messageSearchFtsReady = true;
  }

  Future<void> putConversation(Conversation conversation) async {
    await _db.transaction(() async {
      // Existing rows keep the database-owned hash written by prompt freeze;
      // cached Conversation instances may still hold an older value.
      final updated =
          await (_db.update(
            _db.conversationRows,
          )..where((row) => row.id.equals(conversation.id))).write(
            _conversationCompanion(
              conversation,
              injectedMemoryHash: const Value.absent(),
            ),
          );
      if (updated == 0) {
        await _db
            .into(_db.conversationRows)
            .insert(_conversationCompanion(conversation));
      }
      await _replaceMcpServers(conversation.id, conversation.mcpServerIds);
    });
  }

  Future<Conversation?> duplicateConversation(String sourceId) {
    return _db.transaction(() async {
      final sourceRow = await (_db.select(
        _db.conversationRows,
      )..where((row) => row.id.equals(sourceId))).getSingleOrNull();
      if (sourceRow == null) return null;

      final sourceMessages =
          await (_db.select(_db.messageRows)
                ..where((row) => row.conversationId.equals(sourceId))
                ..orderBy([(row) => OrderingTerm.asc(row.messageOrder)]))
              .get();
      const uuid = Uuid();
      final targetId = uuid.v4();
      final messageIdMap = {
        for (final message in sourceMessages) message.id: uuid.v4(),
      };
      final groupIdMap = <String, String>{};
      for (final message in sourceMessages) {
        final groupId = message.groupId ?? message.id;
        groupIdMap.putIfAbsent(
          groupId,
          () => messageIdMap[groupId] ?? uuid.v4(),
        );
      }

      final source = await _conversationFromRow(
        sourceRow,
        includeMessageIds: false,
      );
      final duplicatedAt = DateTime.now();
      final duplicate = source.copyWith(
        id: targetId,
        createdAt: duplicatedAt,
        updatedAt: duplicatedAt,
        messageIds: [
          for (final message in sourceMessages) messageIdMap[message.id]!,
        ],
        versionSelections: {
          for (final entry in source.versionSelections.entries)
            groupIdMap[entry.key] ?? entry.key: entry.value,
        },
        clearInjectedMemoryHash: true,
        lastMemoryExtractedOrder: sourceMessages.isEmpty
            ? -1
            : sourceMessages.last.messageOrder,
      );
      await _db
          .into(_db.conversationRows)
          .insert(_conversationCompanion(duplicate));
      await _replaceMcpServers(targetId, duplicate.mcpServerIds);
      await _copyMessageRowsInto(
        targetConversationId: targetId,
        messages: sourceMessages,
        messageIdMap: messageIdMap,
        groupIdMap: groupIdMap,
      );
      return duplicate;
    });
  }

  Future<void> _copyMessageRowsInto({
    required String targetConversationId,
    required List<MessageRow> messages,
    required Map<String, String> messageIdMap,
    required Map<String, String> groupIdMap,
  }) async {
    for (final message in messages) {
      final targetMessageId = messageIdMap[message.id]!;
      await _db
          .into(_db.messageRows)
          .insert(
            MessageRowsCompanion.insert(
              id: targetMessageId,
              conversationId: targetConversationId,
              role: message.role,
              timestamp: message.timestamp,
              modelId: Value(message.modelId),
              providerId: Value(message.providerId),
              totalTokens: Value(message.totalTokens),
              isStreaming: const Value(false),
              reasoningStartAt: Value(message.reasoningStartAt),
              reasoningFinishedAt: Value(message.reasoningFinishedAt),
              translation: Value(message.translation),
              reasoningSegmentsJson: Value(message.reasoningSegmentsJson),
              groupId: Value(
                message.groupId == null ? null : groupIdMap[message.groupId],
              ),
              version: Value(message.version),
              promptTokens: Value(message.promptTokens),
              completionTokens: Value(message.completionTokens),
              cachedTokens: Value(message.cachedTokens),
              durationMs: Value(message.durationMs),
              messageOrder: message.messageOrder,
            ),
          );
      await _db.customStatement(
        'INSERT INTO message_part_rows '
        '(conversation_id, revision_id, ordinal, kind, payload, '
        'created_at, updated_at) '
        'SELECT ?, ?, ordinal, kind, payload, created_at, updated_at '
        'FROM message_part_rows WHERE revision_id = ?;',
        [targetConversationId, targetMessageId, message.id],
      );
      await _db.customStatement(
        'INSERT INTO provider_artifact_rows '
        '(conversation_id, revision_id, kind, payload, created_at, '
        'updated_at) '
        'SELECT ?, ?, kind, payload, created_at, updated_at '
        'FROM provider_artifact_rows WHERE revision_id = ?;',
        [targetConversationId, targetMessageId, message.id],
      );
      await _db.customStatement(
        'INSERT INTO message_asset_rows '
        '(conversation_id, revision_id, asset_id, kind) '
        'SELECT ?, ?, asset_id, kind FROM message_asset_rows '
        'WHERE revision_id = ?;',
        [targetConversationId, targetMessageId, message.id],
      );
    }
    await _db.customStatement(
      'INSERT OR IGNORE INTO asset_reference_dirty_rows(revision_id) '
      'SELECT revision_id FROM message_asset_rows WHERE conversation_id = ? '
      'UNION '
      'SELECT revision_id FROM message_part_rows '
      "WHERE conversation_id = ? AND kind IN ('image', 'file');",
      [targetConversationId, targetConversationId],
    );
  }

  Future<Conversation?> forkConversationWithVersions({
    required String sourceId,
    required String targetRevisionId,
    required String title,
    String? assistantId,
  }) {
    return _db.transaction(() async {
      final sourceRow = await (_db.select(
        _db.conversationRows,
      )..where((row) => row.id.equals(sourceId))).getSingleOrNull();
      if (sourceRow == null) return null;

      final sourceMessages =
          await (_db.select(_db.messageRows)
                ..where((row) => row.conversationId.equals(sourceId))
                ..orderBy([(row) => OrderingTerm.asc(row.messageOrder)]))
              .get();

      final firstOrderByGroup = <String, int>{};
      for (final row in sourceMessages) {
        final groupId = row.groupId ?? row.id;
        final current = firstOrderByGroup[groupId];
        if (current == null || row.messageOrder < current) {
          firstOrderByGroup[groupId] = row.messageOrder;
        }
      }

      MessageRow? target;
      for (final row in sourceMessages) {
        if (row.id == targetRevisionId) {
          target = row;
          break;
        }
      }
      if (target == null || target.conversationId != sourceId) {
        return null;
      }

      final targetGroupId = target.groupId ?? target.id;
      final anchorOrder = firstOrderByGroup[targetGroupId];
      if (anchorOrder == null) return null;

      final kept = sourceMessages
          .where((row) {
            final firstOrder = firstOrderByGroup[row.groupId ?? row.id];
            return firstOrder != null && firstOrder <= anchorOrder;
          })
          .toList(growable: false);

      const uuid = Uuid();
      final targetId = uuid.v4();
      final messageIdMap = {for (final message in kept) message.id: uuid.v4()};
      final groupIdMap = <String, String>{};
      for (final message in kept) {
        final groupId = message.groupId ?? message.id;
        groupIdMap.putIfAbsent(
          groupId,
          () => messageIdMap[groupId] ?? uuid.v4(),
        );
      }

      final source = await _conversationFromRow(
        sourceRow,
        includeMessageIds: false,
      );
      final keptSourceGroupIds = {
        for (final row in kept) row.groupId ?? row.id,
      };
      final selections = <String, int>{
        for (final entry in source.versionSelections.entries)
          if (keptSourceGroupIds.contains(entry.key))
            (groupIdMap[entry.key] ?? entry.key): entry.value,
      };
      selections[groupIdMap[targetGroupId]!] = target.version;

      final now = DateTime.now();
      await _db
          .into(_db.conversationRows)
          .insert(
            _conversationCompanion(
              Conversation(
                id: targetId,
                title: title,
                createdAt: now,
                updatedAt: now,
                assistantId: assistantId,
                versionSelections: selections,
                messageIds: [
                  for (final message in kept) messageIdMap[message.id]!,
                ],
              ),
            ),
          );
      await _copyMessageRowsInto(
        targetConversationId: targetId,
        messages: kept,
        messageIdMap: messageIdMap,
        groupIdMap: groupIdMap,
      );
      final insertedRow = await (_db.select(
        _db.conversationRows,
      )..where((row) => row.id.equals(targetId))).getSingle();
      return _conversationFromRow(insertedRow);
    });
  }

  Future<bool> moveConversationToAssistant({
    required String conversationId,
    required String assistantId,
    required DateTime updatedAt,
  }) {
    return _db.transaction(() async {
      final activeRun =
          await (_db.select(_db.generationRunRows)
                ..where(
                  (row) =>
                      row.conversationId.equals(conversationId) &
                      row.state.isIn(const [
                        'preparing',
                        'requesting',
                        'streaming',
                        'waiting_tool',
                      ]),
                )
                ..limit(1))
              .getSingleOrNull();
      if (activeRun != null) return false;
      await (_db.delete(_db.messagePromptRows)..where(
            (row) =>
                row.conversationId.equals(conversationId) &
                row.carriesMemorySnapshot.equals(true),
          ))
          .go();
      final updated =
          await (_db.update(
            _db.conversationRows,
          )..where((row) => row.id.equals(conversationId))).write(
            ConversationRowsCompanion(
              assistantId: Value(assistantId),
              updatedAt: Value(updatedAt),
              injectedMemoryHash: const Value(null),
            ),
          );
      return updated != 0;
    });
  }

  Future<void> putMessage(ChatMessage message, {int? messageOrder}) async {
    final order =
        messageOrder ?? await _nextMessageOrder(message.conversationId);
    await _db.transaction(() async {
      await _db
          .into(_db.messageRows)
          .insertOnConflictUpdate(_messageCompanion(message, order));
      await _replaceMessageParts(message);
    });
  }

  Future<Conversation> appendLinearMessageToConversation({
    required Conversation conversation,
    required ChatMessage message,
    bool selectVersion = false,
    bool touchUpdatedAt = true,
  }) {
    return _observer.measure(
      ChatDatabaseOperation.commandAppendMessage,
      () => _appendLinearMessageToConversation(
        conversation: conversation,
        message: message,
        selectVersion: selectVersion,
        touchUpdatedAt: touchUpdatedAt,
      ),
    );
  }

  Future<GenerationBeginResult> beginSendGeneration({
    required Conversation conversation,
    required ChatMessage userMessage,
    required ChatMessage assistantMessage,
    required String runId,
  }) {
    _validateGenerationBeginMessages(
      conversation: conversation,
      userMessage: userMessage,
      assistantMessage: assistantMessage,
    );
    return _observer.measure(
      ChatDatabaseOperation.commandAppendMessage,
      () => _db.transaction(() async {
        final afterUser = await _appendLinearMessageToConversation(
          conversation: conversation,
          message: userMessage,
          selectVersion: false,
          touchUpdatedAt: true,
        );
        final persisted = await _appendLinearMessageToConversation(
          conversation: afterUser,
          message: assistantMessage,
          selectVersion: false,
          touchUpdatedAt: true,
        );
        final run = await GenerationRunCommands(_db).create(
          id: runId,
          conversationId: conversation.id,
          targetRevisionId: assistantMessage.id,
          createdAt: assistantMessage.timestamp,
        );
        return (
          conversation: persisted,
          userMessage: userMessage,
          assistantMessage: assistantMessage,
          run: run,
        );
      }),
    );
  }

  Future<GenerationBeginResult> beginRegeneration({
    required Conversation conversation,
    required ChatMessage assistantMessage,
    required String runId,
    required bool truncateFuture,
  }) {
    _validateGenerationBeginMessages(
      conversation: conversation,
      assistantMessage: assistantMessage,
    );
    if (assistantMessage.groupId == null) {
      throw ArgumentError.value(
        assistantMessage.groupId,
        'assistantMessage.groupId',
      );
    }
    return _observer.measure(
      ChatDatabaseOperation.commandAppendMessage,
      () => _db.transaction(() async {
        var current = conversation;
        if (truncateFuture) {
          current = await _truncateLinearMessageGroupsAfter(
            conversation: conversation,
            anchorGroupId: assistantMessage.groupId!,
          );
        }
        final persisted = await _appendLinearMessageToConversation(
          conversation: current,
          message: assistantMessage,
          selectVersion: true,
          touchUpdatedAt: true,
        );
        final run = await GenerationRunCommands(_db).create(
          id: runId,
          conversationId: conversation.id,
          targetRevisionId: assistantMessage.id,
          createdAt: assistantMessage.timestamp,
        );
        return (
          conversation: persisted,
          userMessage: null,
          assistantMessage: assistantMessage,
          run: run,
        );
      }),
    );
  }

  Future<GenerationBeginResult> beginAssistantGeneration({
    required Conversation conversation,
    required ChatMessage assistantMessage,
    required String anchorGroupId,
    required String runId,
    required bool truncateFuture,
  }) {
    _validateGenerationBeginMessages(
      conversation: conversation,
      assistantMessage: assistantMessage,
    );
    return _observer.measure(
      ChatDatabaseOperation.commandAppendMessage,
      () => _db.transaction(() async {
        var current = conversation;
        if (truncateFuture) {
          current = await _truncateLinearMessageGroupsAfter(
            conversation: conversation,
            anchorGroupId: anchorGroupId,
          );
        }
        final persisted = await _appendLinearMessageToConversation(
          conversation: current,
          message: assistantMessage,
          selectVersion: false,
          touchUpdatedAt: true,
          afterGroupId: anchorGroupId,
        );
        final run = await GenerationRunCommands(_db).create(
          id: runId,
          conversationId: conversation.id,
          targetRevisionId: assistantMessage.id,
          createdAt: assistantMessage.timestamp,
        );
        return (
          conversation: persisted,
          userMessage: null,
          assistantMessage: assistantMessage,
          run: run,
        );
      }),
    );
  }

  Future<Conversation> _truncateLinearMessageGroupsAfter({
    required Conversation conversation,
    required String anchorGroupId,
  }) async {
    final rows =
        await (_db.select(_db.messageRows)
              ..where((row) => row.conversationId.equals(conversation.id))
              ..orderBy([(row) => OrderingTerm.asc(row.messageOrder)]))
            .get();
    final firstOrderByGroup = <String, int>{};
    for (final row in rows) {
      final groupId = row.groupId ?? row.id;
      final current = firstOrderByGroup[groupId];
      if (current == null || row.messageOrder < current) {
        firstOrderByGroup[groupId] = row.messageOrder;
      }
    }
    final anchorOrder = firstOrderByGroup[anchorGroupId];
    if (anchorOrder == null) {
      throw StateError('linear_message_group_missing');
    }
    final trailingGroupIds = {
      for (final entry in firstOrderByGroup.entries)
        if (entry.value > anchorOrder) entry.key,
    };
    if (trailingGroupIds.isEmpty) return conversation;

    final trailing = rows
        .where((row) => trailingGroupIds.contains(row.groupId ?? row.id))
        .toList(growable: false);
    final deleted = await _deleteMessages(
      conversationId: conversation.id,
      messageIds: trailing.map((row) => row.id).toSet(),
      versionSelectionChanges: {
        for (final groupId in trailingGroupIds) groupId: null,
      },
    );
    return deleted?.conversation ?? conversation;
  }

  static void _validateGenerationBeginMessages({
    required Conversation conversation,
    ChatMessage? userMessage,
    required ChatMessage assistantMessage,
  }) {
    if (userMessage != null &&
        (userMessage.conversationId != conversation.id ||
            userMessage.role != 'user' ||
            userMessage.isStreaming)) {
      throw ArgumentError.value(userMessage, 'userMessage');
    }
    if (assistantMessage.conversationId != conversation.id ||
        assistantMessage.role != 'assistant' ||
        !assistantMessage.isStreaming) {
      throw ArgumentError.value(assistantMessage, 'assistantMessage');
    }
  }

  Future<Conversation> _appendLinearMessageToConversation({
    required Conversation conversation,
    required ChatMessage message,
    required bool selectVersion,
    required bool touchUpdatedAt,
    String? afterGroupId,
  }) {
    if (message.conversationId != conversation.id) {
      throw ArgumentError.value(
        message.conversationId,
        'message.conversationId',
        'Message and conversation IDs must match.',
      );
    }
    return _db.transaction(() async {
      final existingRow = await (_db.select(
        _db.conversationRows,
      )..where((row) => row.id.equals(conversation.id))).getSingleOrNull();
      final current = existingRow == null
          ? conversation
          : await _conversationFromRow(existingRow, includeMessageIds: false);
      final selections = Map<String, int>.from(current.versionSelections);
      if (selectVersion) {
        selections[message.groupId ?? message.id] = message.version;
      }
      final persisted = current.copyWith(
        versionSelections: selections,
        updatedAt: touchUpdatedAt ? DateTime.now() : current.updatedAt,
      );
      await _db
          .into(_db.conversationRows)
          .insertOnConflictUpdate(_conversationCompanion(persisted));
      if (existingRow == null) {
        await _replaceMcpServers(persisted.id, persisted.mcpServerIds);
      }

      final order = afterGroupId == null
          ? await _nextMessageOrder(persisted.id)
          : await _makeMessageOrderAfterGroup(persisted.id, afterGroupId);
      await _db
          .into(_db.messageRows)
          .insert(_messageCompanion(message, order), mode: InsertMode.insert);
      await _replaceMessageParts(message);
      return persisted;
    });
  }

  Future<void> _replaceMessageParts(
    ChatMessage message, {
    List<Map<String, dynamic>>? toolEvents,
  }) async {
    if (_messageHasAttachmentParts(message)) {
      await markMessageAssetReferencesDirty(message.id);
    }
    // A mid-stream reasoning pause is not a reasoning removal: the checkpoint
    // snapshot still carries the pre-allocated reasoningStartAt timestamp, so
    // keep the persisted reasoning part until a timestamp-free message proves
    // the reasoning is gone (full rebuild, edit, finalize).
    final effectiveReasoningText =
        message.reasoningText == null && message.reasoningStartAt != null
        ? (await (_db.select(_db.messagePartRows)
                    ..where(
                      (row) =>
                          row.revisionId.equals(message.id) &
                          row.kind.equals('reasoning'),
                    )
                    ..orderBy([(row) => OrderingTerm.asc(row.ordinal)]))
                  .get())
              .map((part) => part.payload)
              .join('\n')
        : null;
    if (effectiveReasoningText != null && effectiveReasoningText.isNotEmpty) {
      message = message.copyWith(reasoningText: effectiveReasoningText);
    }
    final parts = _partsForPersistence(message, toolEvents);
    await (_db.delete(
      _db.messagePartRows,
    )..where((row) => row.revisionId.equals(message.id))).go();
    var ordinal = 0;
    final now = DateTime.now().toUtc();
    final updatedAt = now.isBefore(message.timestamp) ? message.timestamp : now;
    await _db.batch((batch) {
      for (final part in parts) {
        batch.insert(
          _db.messagePartRows,
          MessagePartRowsCompanion.insert(
            conversationId: message.conversationId,
            revisionId: message.id,
            ordinal: ordinal++,
            kind: part.kind,
            payload: part.encodePayload(),
            createdAt: message.timestamp,
            updatedAt: updatedAt,
          ),
        );
      }
    });
  }

  Future<AppendedMessageVersion?> appendMessageVersion({
    required String messageId,
    String content = '',
    List<MessagePart>? parts,
  }) {
    return _observer.measure(
      ChatDatabaseOperation.commandAppendVersion,
      () => _appendMessageVersion(
        messageId: messageId,
        content: content,
        parts: parts,
      ),
    );
  }

  Future<AppendedMessageVersion?> _appendMessageVersion({
    required String messageId,
    required String content,
    List<MessagePart>? parts,
  }) async {
    return _db.transaction(() async {
      final originalRow = await (_db.select(
        _db.messageRows,
      )..where((row) => row.id.equals(messageId))).getSingleOrNull();
      if (originalRow == null) return null;
      final conversationRow =
          await (_db.select(_db.conversationRows)
                ..where((row) => row.id.equals(originalRow.conversationId)))
              .getSingleOrNull();
      if (conversationRow == null) return null;

      // Metadata only — body text is written via message parts.
      final groupId = originalRow.groupId ?? originalRow.id;
      final maxVersion = _db.messageRows.version.max();
      final maxVersionRow =
          await (_db.selectOnly(_db.messageRows)
                ..addColumns([maxVersion])
                ..where(
                  _db.messageRows.conversationId.equals(
                        originalRow.conversationId,
                      ) &
                      (_db.messageRows.groupId.equals(groupId) |
                          (_db.messageRows.groupId.isNull() &
                              _db.messageRows.id.equals(groupId))),
                ))
              .getSingle();
      final nextVersion = (maxVersionRow.read(maxVersion) ?? -1) + 1;
      // Content-only append must load original parts first and keep non-text
      // attachments (ImagePart/FilePart/etc.) on the new revision, preserving
      // ordinal ([Image, Text] stays [Image, Text(new)], not [Text(new), Image]).
      // Assistant body-only edits also inherit reasoning metadata so the
      // collapsed card stays toggleable on the new version.
      final original = await _messageFromRowWithParts(originalRow);
      final preserveReasoning = parts == null && original.role == 'assistant';
      final resolvedParts =
          parts ??
          ChatMessage.partsWithRedistributedText(original.parts, content);
      final message = ChatMessage(
        role: original.role,
        parts: resolvedParts,
        conversationId: original.conversationId,
        modelId: original.modelId,
        providerId: original.providerId,
        totalTokens: null,
        isStreaming: false,
        reasoningText: preserveReasoning ? original.reasoningText : null,
        reasoningStartAt: preserveReasoning ? original.reasoningStartAt : null,
        reasoningFinishedAt: preserveReasoning
            ? original.reasoningFinishedAt
            : null,
        reasoningSegmentsJson: preserveReasoning
            ? original.reasoningSegmentsJson
            : null,
        groupId: groupId,
        version: nextVersion,
      );
      final currentConversation = await _conversationFromRow(
        conversationRow,
        includeMessageIds: false,
      );
      final selections = Map<String, int>.from(
        currentConversation.versionSelections,
      )..[groupId] = nextVersion;
      final conversation = currentConversation.copyWith(
        versionSelections: selections,
        updatedAt: DateTime.now(),
      );
      final order = await _nextMessageOrder(conversation.id);
      await _db
          .into(_db.messageRows)
          .insert(_messageCompanion(message, order), mode: InsertMode.insert);
      await _replaceMessageParts(message);
      await (_db.update(_db.conversationRows)
            ..where((row) => row.id.equals(conversation.id)))
          .write(_conversationCompanion(conversation));
      return (conversation: conversation, message: message);
    });
  }

  Future<Conversation?> setSelectedVersion({
    required String conversationId,
    required String groupId,
    required int? version,
  }) {
    return _observer.measure(
      ChatDatabaseOperation.commandSelectVersion,
      () => _setSelectedVersion(
        conversationId: conversationId,
        groupId: groupId,
        version: version,
      ),
    );
  }

  Future<Conversation?> _setSelectedVersion({
    required String conversationId,
    required String groupId,
    required int? version,
  }) async {
    if (groupId.isEmpty) {
      throw ArgumentError.value(groupId, 'groupId', 'must not be empty');
    }
    if (version != null && version < 0) {
      throw ArgumentError.value(version, 'version', 'must not be negative');
    }
    return _db.transaction(() async {
      final row =
          await (_db.select(_db.conversationRows)..where(
                (conversation) => conversation.id.equals(conversationId),
              ))
              .getSingleOrNull();
      if (row == null) return null;
      final current = await _conversationFromRow(row, includeMessageIds: false);
      final selections = Map<String, int>.from(current.versionSelections);
      if (version == null) {
        selections.remove(groupId);
      } else {
        selections[groupId] = version;
      }
      final conversation = current.copyWith(
        versionSelections: selections,
        updatedAt: DateTime.now(),
      );
      await (_db.update(_db.conversationRows)
            ..where((conversation) => conversation.id.equals(conversationId)))
          .write(_conversationCompanion(conversation));
      return conversation;
    });
  }

  Future<void> putMigrationBatch({
    required List<Conversation> conversations,
    required List<({ChatMessage message, int messageOrder})> messages,
    required Map<String, List<Map<String, dynamic>>> toolEventsByMessageId,
    required Map<String, String> geminiSignaturesByMessageId,
  }) async {
    if (conversations.isEmpty &&
        messages.isEmpty &&
        toolEventsByMessageId.isEmpty &&
        geminiSignaturesByMessageId.isEmpty) {
      return;
    }

    await _db.transaction(() async {
      await _writeBackupData(
        conversations: conversations,
        messages: messages,
        toolEventsByMessageId: toolEventsByMessageId,
        geminiSignaturesByMessageId: geminiSignaturesByMessageId,
      );
    });
  }

  /// Commits a fully parsed external import together with its business-data
  /// patch. Nothing is written unless both repositories share this exact
  /// [AppDatabase] instance.
  Future<void> commitParsedImport({
    required BusinessRepository businessRepository,
    required bool overwrite,
    required List<ParsedChatImportBatch> conversationBatches,
    required Map<String, List<ChatMessage>> messagesToAppend,
    required BusinessSnapshot Function(BusinessSnapshot current)
    transformBusiness,
  }) async {
    if (!businessRepository.sharesDatabaseIdentity(_db)) {
      throw StateError('chat_business_database_mismatch');
    }
    if (overwrite && messagesToAppend.isNotEmpty) {
      throw ArgumentError.value(messagesToAppend, 'messagesToAppend');
    }
    for (final batch in conversationBatches) {
      for (final message in batch.messages) {
        if (message.conversationId != batch.conversation.id) {
          throw ArgumentError.value(
            message.conversationId,
            'message.conversationId',
          );
        }
      }
    }
    for (final entry in messagesToAppend.entries) {
      for (final message in entry.value) {
        if (message.conversationId != entry.key) {
          throw ArgumentError.value(
            message.conversationId,
            'message.conversationId',
          );
        }
      }
    }

    await _db.transaction(() async {
      if (overwrite) await _clearChatRows();

      final conversations = <Conversation>[];
      final messages = <({ChatMessage message, int messageOrder})>[];
      for (final batch in conversationBatches) {
        conversations.add(
          batch.conversation.copyWith(
            messageIds: batch.messages
                .map((message) => message.id)
                .toList(growable: false),
          ),
        );
        for (final (messageOrder, message) in batch.messages.indexed) {
          messages.add((message: message, messageOrder: messageOrder));
        }
      }
      await _writeBackupData(
        conversations: conversations,
        messages: messages,
        toolEventsByMessageId: const {},
        geminiSignaturesByMessageId: const {},
      );

      for (final entry in messagesToAppend.entries) {
        final current = await getConversation(entry.key);
        if (current == null) {
          throw StateError('chat_import_conversation_missing');
        }
        var conversation = current;
        for (final message in entry.value) {
          conversation = await _appendLinearMessageToConversation(
            conversation: conversation,
            message: message,
            selectVersion: false,
            touchUpdatedAt: false,
          );
        }
      }

      await businessRepository.transformSnapshot(
        transformBusiness,
        writeReceipt: true,
      );
    });
  }

  Future<void> replaceBackupData({
    required List<Conversation> conversations,
    required List<({ChatMessage message, int messageOrder})> messages,
    required Map<String, List<Map<String, dynamic>>> toolEventsByMessageId,
    required Map<String, String> geminiSignaturesByMessageId,
  }) async {
    await _db.transaction(() async {
      await _clearChatRows();
      await _writeBackupData(
        conversations: conversations,
        messages: messages,
        toolEventsByMessageId: toolEventsByMessageId,
        geminiSignaturesByMessageId: geminiSignaturesByMessageId,
      );
      await _writeMigrationCompleteReceipt();
    });
  }

  Future<BackupMergeReport> mergeBackupSnapshot(File snapshotFile) async {
    if (!await snapshotFile.exists()) {
      throw FileSystemException(
        'Snapshot database does not exist',
        snapshotFile.path,
      );
    }

    var attached = false;
    try {
      await _db.customStatement('ATTACH DATABASE ? AS merge_source;', [
        snapshotFile.absolute.path,
      ]);
      attached = true;
      return await _db.transaction(() async {
        final sourceRows = await _db
            .customSelect(
              'SELECT id FROM merge_source.conversation_rows ORDER BY id;',
            )
            .get();
        var imported = 0;
        var deduplicated = 0;
        var skipped = 0;
        final remapped = <String, String>{};
        final importedIds = <String>[];

        for (final sourceRow in sourceRows) {
          final sourceId = sourceRow.read<String>('id');
          try {
            await _requireValidMessageOrder('merge_source', sourceId);
          } on StateError catch (error) {
            if (error.message != 'conversation_message_order') rethrow;
            skipped += 1;
            continue;
          }
          final sourceFingerprint = await _conversationFingerprint(
            'merge_source',
            sourceId,
          );
          if (sourceFingerprint == null) {
            throw StateError('merge_source_conversation');
          }
          final existingFingerprint = await _conversationFingerprint(
            'main',
            sourceId,
          );
          if (existingFingerprint == sourceFingerprint) {
            deduplicated += 1;
            continue;
          }

          final sourceMessageIds = await _messageIds('merge_source', sourceId);
          final hasConversationConflict = existingFingerprint != null;
          final hasMessageConflict = await _anyMessageIdExists(
            sourceMessageIds,
          );
          var targetId = sourceId;
          var remapWholeConversation =
              hasConversationConflict || hasMessageConflict;
          if (remapWholeConversation) {
            targetId = _deterministicMergeId(
              'conversation',
              sourceId,
              sourceFingerprint,
            );
            var suffix = 0;
            while (true) {
              final candidateFingerprint = await _conversationFingerprint(
                'main',
                targetId,
              );
              if (candidateFingerprint == null) break;
              if (candidateFingerprint == sourceFingerprint) {
                deduplicated += 1;
                remapped[sourceId] = targetId;
                targetId = '';
                break;
              }
              suffix += 1;
              targetId =
                  '${_deterministicMergeId('conversation', sourceId, sourceFingerprint)}-$suffix';
            }
            if (targetId.isEmpty) continue;
            remapped[sourceId] = targetId;
          }

          final messageIdMap = <String, String>{};
          for (final messageId in sourceMessageIds) {
            messageIdMap[messageId] = remapWholeConversation
                ? _deterministicMergeId('message', messageId, sourceFingerprint)
                : messageId;
          }
          await _insertMergedConversation(
            sourceId: sourceId,
            targetId: targetId,
            messageIdMap: messageIdMap,
          );
          imported += 1;
          importedIds.add(targetId);
        }

        final foreignKeyFailures = await _db
            .customSelect('PRAGMA foreign_key_check;')
            .get();
        if (foreignKeyFailures.isNotEmpty) {
          throw StateError('foreign_key_check');
        }
        return BackupMergeReport(
          importedConversations: imported,
          deduplicatedConversations: deduplicated,
          skippedConversations: skipped,
          remappedConversationIds: Map.unmodifiable(remapped),
          importedConversationIds: List.unmodifiable(importedIds),
        );
      });
    } finally {
      if (attached) {
        await _db.customStatement('DETACH DATABASE merge_source;');
      }
    }
  }

  /// Chats-only restore/merge: mark local attachment parts unavailable unless
  /// remote/data. Does not reuse path/hash coincidence from asset_rows.
  Future<int> recomputeAttachmentAvailabilityForConversations({
    required Iterable<String> conversationIds,
    required bool filesRestored,
  }) async {
    final ids = conversationIds.toList(growable: false);
    if (ids.isEmpty) return 0;
    var updated = 0;
    for (final conversationId in ids) {
      final messages = await getMessagesRange(
        conversationId,
        start: 0,
        limit: 100000,
      );
      for (final message in messages) {
        final nextParts = <MessagePart>[];
        var changed = false;
        for (final part in message.parts) {
          if (part is ImagePart) {
            final unavailable = await _unavailableForRestoredPart(
              uri: part.uri,
              filesRestored: filesRestored,
            );
            if (unavailable != part.unavailable) changed = true;
            nextParts.add(
              ImagePart(
                uri: part.uri,
                mime: part.mime,
                assetId: part.assetId,
                unavailable: unavailable,
              ),
            );
          } else if (part is FilePart) {
            final unavailable = await _unavailableForRestoredPart(
              uri: part.uri,
              filesRestored: filesRestored,
            );
            if (unavailable != part.unavailable) changed = true;
            nextParts.add(
              FilePart(
                uri: part.uri,
                name: part.name,
                mime: part.mime,
                assetId: part.assetId,
                unavailable: unavailable,
              ),
            );
          } else {
            nextParts.add(part);
          }
        }
        if (!changed) continue;
        await updateMessage(message.copyWith(parts: nextParts));
        updated += 1;
      }
    }
    return updated;
  }

  Future<bool> _unavailableForRestoredPart({
    required String uri,
    required bool filesRestored,
  }) async {
    if (isRemoteOrDataUri(uri)) return false;
    if (filesRestored) {
      return !SandboxPathResolver.localFileExists(uri);
    }
    // Chats-only: never trust candidate asset_rows path / content_hash
    // coincidence on the target machine (same path may hold different bytes).
    // Reuse would require hashing the live target file and comparing bytes.
    return true;
  }

  /// Open [databaseFile] with raw sqlite3 and mark local attachments
  /// unavailable when [filesRestored] is false (overwrite chats-only candidate
  /// processing before publish). Avoids opening a Drift isolate inside
  /// restore staging.
  ///
  /// Minimal policy: every non-remote/data local attachment becomes
  /// unavailable. We deliberately do **not** reuse candidate `asset_rows`
  /// content_hash + path existence — that would treat the candidate's own
  /// absolute path (or a colliding target file with different bytes) as proof.
  static Future<int> recomputeAttachmentAvailabilityOnDatabaseFile({
    required File databaseFile,
    required bool filesRestored,
  }) async {
    if (filesRestored) return 0;
    if (!await databaseFile.exists()) {
      throw FileSystemException(
        'Candidate database does not exist',
        databaseFile.path,
      );
    }
    return Future<int>.sync(() {
      final db = sqlite.sqlite3.open(databaseFile.absolute.path);
      try {
        final rows = db.select(
          "SELECT revision_id, ordinal, kind, payload "
          "FROM message_part_rows WHERE kind IN ('image', 'file');",
        );
        var updated = 0;
        final stmt = db.prepare(
          'UPDATE message_part_rows SET payload = ? '
          'WHERE revision_id = ? AND ordinal = ?;',
        );
        try {
          for (final row in rows) {
            final payload = row['payload'] as String;
            final decoded = jsonDecode(payload);
            if (decoded is! Map) continue;
            final map = Map<String, dynamic>.from(decoded);
            final uri = (map['uri'] ?? '').toString();
            if (uri.isEmpty || isRemoteOrDataUri(uri)) continue;
            if (map['unavailable'] == true) continue;
            map['unavailable'] = true;
            stmt.execute([jsonEncode(map), row['revision_id'], row['ordinal']]);
            updated += 1;
          }
        } finally {
          stmt.close();
        }
        return updated;
      } finally {
        db.close();
      }
    });
  }

  Future<String?> _conversationFingerprint(String schema, String id) async {
    final conversation = await _db
        .customSelect(
          'SELECT title, created_at, updated_at, is_pinned, assistant_id, '
          'truncate_index, version_selections_json, summary, '
          'last_summarized_message_count, chat_suggestions_json '
          'FROM $schema.conversation_rows WHERE id = ?;',
          variables: [Variable<String>(id)],
        )
        .getSingleOrNull();
    if (conversation == null) return null;
    final mcpRows = await _db
        .customSelect(
          'SELECT server_id, ordinal FROM $schema.conversation_mcp_server_rows '
          'WHERE conversation_id = ? ORDER BY ordinal, server_id;',
          variables: [Variable<String>(id)],
        )
        .get();
    final messageRows = await _db
        .customSelect(
          'SELECT id, role, timestamp, model_id, provider_id, '
          'total_tokens, is_streaming, reasoning_start_at, '
          'reasoning_finished_at, translation, reasoning_segments_json, group_id, '
          'version, prompt_tokens, completion_tokens, cached_tokens, duration_ms, '
          'message_order FROM $schema.message_rows WHERE conversation_id = ? '
          'ORDER BY message_order, id;',
          variables: [Variable<String>(id)],
        )
        .get();
    // Text/reasoning/tool payloads and thought signatures are fingerprinted
    // from materialized parts/artifacts; part_id, timestamps, and ordinals are
    // excluded so equal payloads hash equally across snapshots. Both load once
    // per conversation: merging a large backup calls this per candidate id, so
    // per-message queries would cost four DB round trips per message. They join
    // through message_rows instead of trusting the denormalized
    // message_part_rows.conversation_id, matching the revision-keyed grouping
    // the fingerprint has always used.
    final partRows = await _db
        .customSelect(
          'SELECT p.revision_id, p.kind, p.payload '
          'FROM $schema.message_part_rows p '
          'INNER JOIN $schema.message_rows m ON m.id = p.revision_id '
          'WHERE m.conversation_id = ? '
          'ORDER BY p.revision_id, p.ordinal;',
          variables: [Variable<String>(id)],
        )
        .get();
    final partPayloads = <String, Map<String, List<String>>>{};
    // Image/file identity payloads in ordinal order (unavailable stripped).
    final attachmentPayloads = <String, List<String>>{};
    for (final part in partRows) {
      final revisionId = part.read<String>('revision_id');
      final kind = part.read<String>('kind');
      final payload = part.read<String>('payload');
      if (kind == 'image' || kind == 'file') {
        attachmentPayloads
            .putIfAbsent(revisionId, () => [])
            .add(_fingerprintAttachmentPayload(kind, payload));
        continue;
      }
      partPayloads
          .putIfAbsent(revisionId, () => {})
          .putIfAbsent(kind, () => [])
          .add(payload);
    }
    final signatureRows = await _db
        .customSelect(
          'SELECT a.revision_id, a.payload '
          'FROM $schema.provider_artifact_rows a '
          'INNER JOIN $schema.message_rows m ON m.id = a.revision_id '
          "WHERE m.conversation_id = ? AND a.kind = 'gemini_thought_signature';",
          variables: [Variable<String>(id)],
        )
        .get();
    final signatures = {
      for (final row in signatureRows)
        row.read<String>('revision_id'): row.read<String>('payload'),
    };
    final messages = <Object?>[];
    final groupOrdinals = <String, int>{};
    for (final row in messageRows) {
      final messageId = row.read<String>('id');
      final payloads = partPayloads[messageId];
      final data = Map<String, Object?>.from(row.data)..remove('id');
      data['is_streaming'] = 0;
      for (final field in const [
        'timestamp',
        'reasoning_start_at',
        'reasoning_finished_at',
      ]) {
        data[field] = _fingerprintTimestamp(data[field]);
      }
      final groupId = data.remove('group_id')?.toString() ?? '';
      data['group_ordinal'] = groupOrdinals.putIfAbsent(
        groupId,
        () => groupOrdinals.length,
      );
      messages.add([
        data,
        payloads?['text'],
        payloads?['reasoning'],
        payloads?['tool_call'],
        attachmentPayloads[messageId],
        signatures[messageId],
      ]);
    }
    return sha256
        .convert(
          utf8.encode(
            jsonEncode([
              _normalizedConversationFingerprintData(
                conversation.data,
                groupOrdinals,
              ),
              mcpRows.map((row) => row.data).toList(),
              messages,
            ]),
          ),
        )
        .toString();
  }

  Map<String, Object?> _normalizedConversationFingerprintData(
    Map<String, Object?> data,
    Map<String, int> groupOrdinals,
  ) {
    final normalized = Map<String, Object?>.from(data);
    normalized['created_at'] = _fingerprintTimestamp(normalized['created_at']);
    normalized['updated_at'] = _fingerprintTimestamp(normalized['updated_at']);
    final rawSelections = normalized['version_selections_json'];
    if (rawSelections is String) {
      final decoded = _decodeStringIntMap(rawSelections);
      final selections = <String, int>{};
      for (final entry in decoded.entries) {
        final ordinal = groupOrdinals[entry.key];
        if (ordinal != null) selections['$ordinal'] = entry.value;
      }
      normalized['version_selections_json'] = selections;
    }
    return normalized;
  }

  /// Attachment identity for merge fingerprints. Drops environment-state
  /// `unavailable` so the same attachment available on one device and missing
  /// on another still dedupes; keeps uri/name/mime/assetId and ordinal order.
  String _fingerprintAttachmentPayload(String kind, String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return jsonEncode({'kind': kind, 'raw': payload});
      final map = Map<String, Object?>.from(decoded);
      return jsonEncode({
        'kind': kind,
        'uri': map['uri'],
        if (map['name'] != null) 'name': map['name'],
        if (map['mime'] != null) 'mime': map['mime'],
        if (map['assetId'] != null) 'assetId': map['assetId'],
      });
    } catch (_) {
      return jsonEncode({'kind': kind, 'raw': payload});
    }
  }

  Object? _fingerprintTimestamp(Object? value) {
    if (value is int) return value ~/ Duration.microsecondsPerSecond;
    if (value is num) {
      return value.toInt() ~/ Duration.microsecondsPerSecond;
    }
    return value;
  }

  Future<List<String>> _messageIds(String schema, String conversationId) async {
    final rows = await _db
        .customSelect(
          'SELECT id FROM $schema.message_rows WHERE conversation_id = ? '
          'ORDER BY message_order, id;',
          variables: [Variable<String>(conversationId)],
        )
        .get();
    return rows.map((row) => row.read<String>('id')).toList(growable: false);
  }

  /// Message deletion intentionally preserves `message_order` gaps, so sparse
  /// orders are valid; only negative or duplicate values that bypassed the
  /// database constraints are rejected here.
  Future<void> _requireValidMessageOrder(
    String schema,
    String conversationId,
  ) async {
    final rows = await _db
        .customSelect(
          'SELECT message_order FROM $schema.message_rows '
          'WHERE conversation_id = ? ORDER BY message_order, id;',
          variables: [Variable<String>(conversationId)],
        )
        .get();
    int? previous;
    for (final row in rows) {
      final order = row.read<int>('message_order');
      if (order < 0 || (previous != null && order <= previous)) {
        throw StateError('conversation_message_order');
      }
      previous = order;
    }
  }

  Future<bool> _anyMessageIdExists(List<String> ids) async {
    for (final id in ids) {
      final row = await _db
          .customSelect(
            'SELECT 1 AS found FROM main.message_rows WHERE id = ? LIMIT 1;',
            variables: [Variable<String>(id)],
          )
          .getSingleOrNull();
      if (row != null) return true;
    }
    return false;
  }

  String _deterministicMergeId(String kind, String id, String fingerprint) {
    final digest = sha256.convert(
      utf8.encode('$kind\u0000$id\u0000$fingerprint'),
    );
    return 'merge-${digest.toString().substring(0, 32)}';
  }

  Future<void> _insertMergedConversation({
    required String sourceId,
    required String targetId,
    required Map<String, String> messageIdMap,
  }) async {
    final sourceMessages = await _db
        .customSelect(
          'SELECT id, group_id FROM merge_source.message_rows '
          'WHERE conversation_id = ? ORDER BY message_order, id;',
          variables: [Variable<String>(sourceId)],
        )
        .get();
    final remapping = sourceId != targetId;
    final groupIdMap = <String, String>{};
    for (final row in sourceMessages) {
      // A group is keyed by COALESCE(group_id, id): the first revision keeps a
      // null group_id, later versions carry that revision's id. Remapped groups
      // must therefore follow the anchor revision's new id, otherwise the
      // anchor and its later versions end up in two different groups.
      final groupId =
          row.data['group_id']?.toString() ?? row.read<String>('id');
      if (groupIdMap.containsKey(groupId)) continue;
      groupIdMap[groupId] =
          messageIdMap[groupId] ??
          (remapping
              ? _deterministicMergeId('group', groupId, targetId)
              : groupId);
    }
    final sourceConversation = await _db
        .customSelect(
          'SELECT version_selections_json FROM merge_source.conversation_rows '
          'WHERE id = ?;',
          variables: [Variable<String>(sourceId)],
        )
        .getSingle();
    final sourceSelections = _decodeStringIntMap(
      sourceConversation.read<String>('version_selections_json'),
    );
    final targetSelections = <String, int>{};
    for (final entry in sourceSelections.entries) {
      targetSelections[groupIdMap[entry.key] ?? entry.key] = entry.value;
    }
    await _db.customStatement(
      'INSERT INTO main.conversation_rows '
      '(id, title, created_at, updated_at, is_pinned, assistant_id, '
      'truncate_index, version_selections_json, summary, '
      'last_summarized_message_count, chat_suggestions_json, '
      'injected_memory_hash, last_memory_extracted_order, '
      'chat_model_provider, chat_model_id) '
      'SELECT ?, title, created_at, updated_at, is_pinned, assistant_id, '
      'truncate_index, ?, summary, '
      'last_summarized_message_count, chat_suggestions_json, '
      'NULL, COALESCE((SELECT MAX(message_order) '
      'FROM merge_source.message_rows WHERE conversation_id = ?), -1), '
      'chat_model_provider, chat_model_id '
      'FROM merge_source.conversation_rows WHERE id = ?;',
      [targetId, jsonEncode(targetSelections), sourceId, sourceId],
    );
    await _db.customStatement(
      'INSERT INTO main.conversation_mcp_server_rows '
      '(conversation_id, server_id, ordinal) '
      'SELECT ?, server_id, ordinal FROM merge_source.conversation_mcp_server_rows '
      'WHERE conversation_id = ?;',
      [targetId, sourceId],
    );
    for (final entry in messageIdMap.entries) {
      final sourceMessage = sourceMessages.firstWhere(
        (row) => row.read<String>('id') == entry.key,
      );
      final sourceGroupId = sourceMessage.data['group_id']?.toString();
      // Anchor revisions keep their null group_id so the merged rows describe
      // the same groups as the snapshot and stay fingerprint-identical.
      final targetGroupId = sourceGroupId == null
          ? null
          : (groupIdMap[sourceGroupId] ?? sourceGroupId);
      await _db.customStatement(
        'INSERT INTO main.message_rows '
        '(id, conversation_id, role, timestamp, model_id, provider_id, '
        'total_tokens, is_streaming, reasoning_start_at, '
        'reasoning_finished_at, translation, reasoning_segments_json, group_id, '
        'version, prompt_tokens, completion_tokens, cached_tokens, duration_ms, '
        'message_order) '
        'SELECT ?, ?, role, timestamp, model_id, provider_id, '
        'total_tokens, 0, reasoning_start_at, '
        'reasoning_finished_at, translation, reasoning_segments_json, '
        '?, version, '
        'prompt_tokens, completion_tokens, cached_tokens, duration_ms, '
        // message_order is part of the conversation fingerprint. Preserve it
        // verbatim so sparse snapshots remain idempotent across repeated merges.
        'message_order FROM merge_source.message_rows WHERE id = ?;',
        [entry.value, targetId, targetGroupId, entry.key],
      );
      await _db.customStatement(
        'INSERT INTO main.message_part_rows '
        '(conversation_id, revision_id, ordinal, kind, payload, '
        'created_at, updated_at) '
        'SELECT ?, ?, ordinal, kind, payload, created_at, updated_at '
        'FROM merge_source.message_part_rows WHERE revision_id = ?;',
        [targetId, entry.value, entry.key],
      );
      // generation_run_rows are intentionally not copied: merged revisions
      // are always persisted as non-streaming.
      await _db.customStatement(
        'INSERT INTO main.provider_artifact_rows '
        '(conversation_id, revision_id, kind, payload, created_at, updated_at) '
        'SELECT ?, ?, kind, payload, created_at, updated_at '
        'FROM merge_source.provider_artifact_rows WHERE revision_id = ?;',
        [targetId, entry.value, entry.key],
      );
    }
    // Merged revisions bypass _replaceMessageParts, so queue the
    // attachment-bearing ones for the asset-reference backfill before GC can
    // treat their files as unreferenced.
    await _db.customStatement(
      'INSERT OR IGNORE INTO asset_reference_dirty_rows(revision_id) '
      'SELECT DISTINCT revision_id FROM main.message_part_rows '
      "WHERE conversation_id = ? AND kind IN ('image', 'file');",
      [targetId],
    );
  }

  Future<void> _writeBackupData({
    required List<Conversation> conversations,
    required List<({ChatMessage message, int messageOrder})> messages,
    required Map<String, List<Map<String, dynamic>>> toolEventsByMessageId,
    required Map<String, String> geminiSignaturesByMessageId,
  }) async {
    await _db.batch((batch) {
      for (final conversation in conversations) {
        batch.insert(
          _db.conversationRows,
          _conversationCompanion(conversation),
          mode: InsertMode.insertOrReplace,
        );
        for (var i = 0; i < conversation.mcpServerIds.length; i++) {
          batch.insert(
            _db.conversationMcpServerRows,
            ConversationMcpServerRowsCompanion.insert(
              conversationId: conversation.id,
              serverId: conversation.mcpServerIds[i],
              ordinal: i,
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
      }
      for (final entry in messages) {
        batch.insert(
          _db.messageRows,
          _messageCompanion(entry.message, entry.messageOrder),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
    // Parts/artifacts are the only persistence for tool events and thought
    // signatures; the legacy tables no longer receive writes.
    final batchMessageIds = <String>{};
    for (final entry in messages) {
      final id = entry.message.id;
      batchMessageIds.add(id);
      await _replaceMessageParts(
        entry.message,
        toolEvents: toolEventsByMessageId[id],
      );
    }
    for (final entry in toolEventsByMessageId.entries) {
      if (batchMessageIds.contains(entry.key)) continue;
      final message = await getMessage(entry.key);
      if (message == null) throw StateError('tool_event_message_missing');
      await _replaceMessageParts(message, toolEvents: entry.value);
    }
    for (final entry in geminiSignaturesByMessageId.entries) {
      await _upsertGeminiThoughtSignature(entry.key, entry.value);
    }
    // _replaceMessageParts already queues attachment-bearing revisions; the
    // bulk mark stays as cheap insurance for the asset backfill invariant.
    await _markMessageAssetReferencesDirtyBatch([
      for (final entry in messages)
        if (_messageHasAttachmentParts(entry.message)) entry.message.id,
    ]);
  }

  Future<void> updateMessage(ChatMessage message) async {
    await _db.transaction(() async {
      await _updateMessageRow(message);
      await _replaceMessageParts(message);
    });
  }

  Future<void> _updateMessageRow(ChatMessage message) async {
    await (_db.update(
      _db.messageRows,
    )..where((t) => t.id.equals(message.id))).write(_messageUpdate(message));
  }

  /// Partial-column UPDATE: only the non-null fields are written, so
  /// concurrent writers touching disjoint columns cannot clobber each other.
  /// Message parts are rebuilt when [parts], content, or reasoning text
  /// changes; the other columns never affect parts. Returns the post-update
  /// message,
  /// or null when no row matches [messageId].
  Future<ChatMessage?> updateMessageFields(
    String messageId, {
    String? content,
    List<MessagePart>? parts,
    int? totalTokens,
    bool? isStreaming,
    String? reasoningText,
    DateTime? reasoningStartAt,
    DateTime? reasoningFinishedAt,
    String? translation,
    String? reasoningSegmentsJson,
    int? promptTokens,
    int? completionTokens,
    int? cachedTokens,
    int? durationMs,
  }) {
    final companion = MessageRowsCompanion(
      totalTokens: totalTokens != null
          ? Value(totalTokens)
          : const Value.absent(),
      isStreaming: isStreaming != null
          ? Value(isStreaming)
          : const Value.absent(),
      reasoningStartAt: reasoningStartAt != null
          ? Value(reasoningStartAt)
          : const Value.absent(),
      reasoningFinishedAt: reasoningFinishedAt != null
          ? Value(reasoningFinishedAt)
          : const Value.absent(),
      translation: translation != null
          ? Value(translation)
          : const Value.absent(),
      reasoningSegmentsJson: reasoningSegmentsJson != null
          ? Value(reasoningSegmentsJson)
          : const Value.absent(),
      promptTokens: promptTokens != null
          ? Value(promptTokens)
          : const Value.absent(),
      completionTokens: completionTokens != null
          ? Value(completionTokens)
          : const Value.absent(),
      cachedTokens: cachedTokens != null
          ? Value(cachedTokens)
          : const Value.absent(),
      durationMs: durationMs != null ? Value(durationMs) : const Value.absent(),
    );
    return _db.transaction(() async {
      await (_db.update(
        _db.messageRows,
      )..where((t) => t.id.equals(messageId))).write(companion);
      final updated = await getMessage(messageId);
      if (updated == null) return null;
      if (content == null && reasoningText == null && parts == null) {
        return updated;
      }
      var nextParts = updated.parts;
      if (parts != null) {
        nextParts = parts;
      } else if (content != null) {
        nextParts = ChatMessage.partsWithRedistributedText(nextParts, content);
      }
      if (reasoningText != null) {
        nextParts = ChatMessage.partsWithReplacedReasoning(
          nextParts,
          reasoningText,
        );
      }
      final corrected = updated.copyWith(
        parts: nextParts,
        reasoningText: reasoningText ?? updated.reasoningText,
      );
      await _replaceMessageParts(corrected);
      return corrected;
    });
  }

  Future<void> updateStreamingCheckpoint(
    ChatMessage message,
    List<Map<String, dynamic>> toolEvents, {
    String? generationRunId,
    int? checkpointSeq,
  }) {
    if ((generationRunId == null) != (checkpointSeq == null)) {
      throw ArgumentError('generationRunId and checkpointSeq must pair');
    }
    return _observer.measure(
      message.isStreaming
          ? ChatDatabaseOperation.commandStreamingCheckpoint
          : ChatDatabaseOperation.commandFinalCheckpoint,
      () => _updateStreamingCheckpoint(
        message,
        toolEvents,
        generationRunId: generationRunId,
        checkpointSeq: checkpointSeq,
      ),
    );
  }

  Future<void> _updateStreamingCheckpoint(
    ChatMessage message,
    List<Map<String, dynamic>> toolEvents, {
    String? generationRunId,
    int? checkpointSeq,
  }) async {
    await _db.transaction(() async {
      // Guard against a late flush resurrecting an already-finalized message.
      // A streaming snapshot (is_streaming = true) that arrives after the
      // terminal write has committed (row is_streaming = 0) must not overwrite
      // the terminal content or flip is_streaming back on (which would also
      // unindex it from search). Final writes carry is_streaming = false and
      // are unaffected.
      if (message.isStreaming) {
        final existing =
            await (_db.select(_db.messageRows)
                  ..where((row) => row.id.equals(message.id))
                  ..limit(1))
                .getSingleOrNull();
        if (existing != null && !existing.isStreaming) {
          return;
        }
      }
      // Keep message_rows (incl. is_streaming) ahead of parts rewrite so the
      // FTS finalize trigger indexes the pre-rewrite text part correctly.
      await _updateMessageRow(message);
      await _replaceMessageParts(message, toolEvents: toolEvents);
      if (generationRunId != null && checkpointSeq != null) {
        await GenerationRunCommands(_db).checkpoint(
          id: generationRunId,
          targetRevisionId: message.id,
          checkpointSeq: checkpointSeq,
          updatedAt: DateTime.now().toUtc(),
        );
      }
    });
  }

  @Deprecated('legacy/test only; rewrites the complete conversation order')
  Future<void> updateConversationMessages({
    required Conversation conversation,
    required List<String> messageIds,
  }) async {
    await _db.transaction(() async {
      await _db
          .into(_db.conversationRows)
          .insertOnConflictUpdate(
            _conversationCompanion(
              conversation.copyWith(messageIds: List<String>.of(messageIds)),
            ),
          );
      await _replaceMcpServers(conversation.id, conversation.mcpServerIds);
      await _rewriteMessageOrder(conversation.id, messageIds);
    });
  }

  Future<void> deleteConversation(String id) async {
    await (_db.delete(
      _db.conversationRows,
    )..where((t) => t.id.equals(id))).go();
  }

  Future<void> deleteMessage(String messageId) async {
    final row = await getMessage(messageId);
    if (row == null) return;
    await deleteMessages(
      conversationId: row.conversationId,
      messageIds: {messageId},
      versionSelectionChanges: const {},
    );
  }

  Future<DeletedMessagesResult?> deleteMessages({
    required String conversationId,
    required Set<String> messageIds,
    required Map<String, int?> versionSelectionChanges,
  }) {
    return _observer.measure(
      ChatDatabaseOperation.commandDeleteMessages,
      () async {
        return _deleteMessages(
          conversationId: conversationId,
          messageIds: messageIds,
          versionSelectionChanges: versionSelectionChanges,
        );
      },
    );
  }

  Future<DeletedMessagesResult?> _deleteMessages({
    required String conversationId,
    required Set<String> messageIds,
    required Map<String, int?> versionSelectionChanges,
  }) async {
    if (messageIds.isEmpty) return null;
    for (final entry in versionSelectionChanges.entries) {
      if (entry.key.isEmpty || (entry.value != null && entry.value! < 0)) {
        throw ArgumentError.value(
          versionSelectionChanges,
          'versionSelectionChanges',
          'Group IDs must be non-empty and versions non-negative.',
        );
      }
    }
    return _db.transaction(() async {
      final conversationRow = await (_db.select(
        _db.conversationRows,
      )..where((row) => row.id.equals(conversationId))).getSingleOrNull();
      if (conversationRow == null) return null;
      final rows =
          await (_db.select(_db.messageRows)
                ..where((row) => row.conversationId.equals(conversationId))
                ..orderBy([(row) => OrderingTerm.asc(row.messageOrder)]))
              .get();
      final deletedRows = rows
          .where((row) => messageIds.contains(row.id))
          .toList(growable: false);
      if (deletedRows.isEmpty) return null;
      if (deletedRows.length != messageIds.length) {
        throw StateError('delete_messages_not_found');
      }

      // Version groups are anchored at MIN(message_order) in the timeline
      // queries, while appended revisions get end-of-conversation orders.
      // Deleting the anchor row would therefore make the surviving revisions
      // drift to the appended position (e.g. edit mid-conversation, then
      // delete the old version -> group jumps to the bottom). Keep the group
      // in place by moving the earliest surviving revision back onto the
      // freed anchor order. The anchor slot is guaranteed free: it belonged
      // to a row of this same group that is deleted in this transaction, and
      // distinct groups never share an anchor row.
      final anchorRewrites = <String, int>{};
      final rowsByGroup = <String, List<MessageRow>>{};
      for (final row in rows) {
        rowsByGroup
            .putIfAbsent(row.groupId ?? row.id, () => <MessageRow>[])
            .add(row);
      }
      for (final group in rowsByGroup.values) {
        // `rows` is ordered by message_order, so group.first is the anchor.
        final anchor = group.first;
        if (!messageIds.contains(anchor.id)) continue;
        MessageRow? survivor;
        for (final row in group) {
          if (!messageIds.contains(row.id)) {
            survivor = row;
            break;
          }
        }
        if (survivor == null) continue;
        anchorRewrites[survivor.id] = anchor.messageOrder;
      }

      final remainingRows = rows
          .where((row) => !messageIds.contains(row.id))
          .toList(growable: false);
      final effectiveOrders = <String, int>{
        for (final row in remainingRows)
          row.id: anchorRewrites[row.id] ?? row.messageOrder,
      };
      final orderedIds = remainingRows.map((row) => row.id).toList()
        ..sort((a, b) => effectiveOrders[a]!.compareTo(effectiveOrders[b]!));

      final deletedIds = deletedRows
          .map((row) => row.id)
          .toList(growable: false);
      await (_db.delete(
        _db.generationRunRows,
      )..where((row) => row.targetRevisionId.isIn(deletedIds))).go();
      await (_db.delete(
        _db.providerArtifactRows,
      )..where((row) => row.revisionId.isIn(deletedIds))).go();
      await (_db.delete(
        _db.messageRows,
      )..where((row) => row.id.isIn(deletedIds))).go();
      for (final rewrite in anchorRewrites.entries) {
        await (_db.update(_db.messageRows)
              ..where((row) => row.id.equals(rewrite.key)))
            .write(MessageRowsCompanion(messageOrder: Value(rewrite.value)));
      }
      final currentConversation = await _conversationFromRow(
        conversationRow,
        includeMessageIds: false,
      );
      final selections = Map<String, int>.from(
        currentConversation.versionSelections,
      );
      for (final entry in versionSelectionChanges.entries) {
        final version = entry.value;
        if (version == null) {
          selections.remove(entry.key);
        } else {
          selections[entry.key] = version;
        }
      }
      final remainingByGroup = <String, List<MessageRow>>{};
      for (final row in rows) {
        if (messageIds.contains(row.id)) continue;
        remainingByGroup
            .putIfAbsent(row.groupId ?? row.id, () => <MessageRow>[])
            .add(row);
      }
      for (final groupId in selections.keys.toList(growable: false)) {
        final remaining = remainingByGroup[groupId];
        if (remaining == null || remaining.isEmpty) {
          selections.remove(groupId);
          continue;
        }
        final selectedVersion = selections[groupId];
        if (!remaining.any((row) => row.version == selectedVersion)) {
          selections[groupId] = remaining
              .map((row) => row.version)
              .reduce((left, right) => left > right ? left : right);
        }
      }
      final conversation = currentConversation.copyWith(
        messageIds: orderedIds,
        versionSelections: selections,
        chatSuggestions: const <String>[],
        updatedAt: DateTime.now(),
      );
      await (_db.update(_db.conversationRows)
            ..where((row) => row.id.equals(conversationId)))
          .write(_conversationCompanion(conversation));
      // Callers (ChatService.deleteMessages) only need message.id for cache
      // invalidation; body text is intentionally omitted.
      return (
        conversation: conversation,
        messages: [
          for (final row in deletedRows)
            ChatMessage(
              id: row.id,
              role: row.role,
              content: '',
              timestamp: row.timestamp,
              conversationId: row.conversationId,
              groupId: row.groupId,
              version: row.version,
            ),
        ],
      );
    });
  }

  Future<void> clearAllData() async {
    await _db.transaction(() async {
      await _clearChatRows();
    });
  }

  Future<void> _clearChatRows() async {
    await _db.delete(_db.conversationMcpServerRows).go();
    await _db.delete(_db.messageRows).go();
    await _db.delete(_db.conversationRows).go();
    await (_db.delete(
      _db.chatStorageMetaRows,
    )..where((t) => t.key.equals(ChatStorageMetaKeys.activeStreamingIds))).go();
  }

  Future<List<Map<String, dynamic>>> getToolEvents(String messageId) async {
    return (await getToolEventsForMessages([messageId]))[messageId] ??
        const <Map<String, dynamic>>[];
  }

  Future<Map<String, List<Map<String, dynamic>>>> getToolEventsForMessages(
    Iterable<String> messageIds,
  ) async {
    final ids = messageIds.toSet();
    if (ids.isEmpty) return const {};
    final partRows =
        await (_db.select(_db.messagePartRows)
              ..where(
                (row) =>
                    row.revisionId.isIn(ids) & row.kind.equals('tool_call'),
              )
              ..orderBy([(row) => OrderingTerm.asc(row.ordinal)]))
            .get();
    final result = <String, List<Map<String, dynamic>>>{};
    for (final row in partRows) {
      final decoded = jsonDecode(row.payload);
      if (decoded is Map) {
        result
            .putIfAbsent(row.revisionId, () => <Map<String, dynamic>>[])
            .add(Map<String, dynamic>.from(decoded));
      }
    }
    return result;
  }

  Future<void> setToolEvents(
    String messageId,
    List<Map<String, dynamic>> events,
  ) async {
    await _db.transaction(() async {
      final message = await getMessage(messageId);
      if (message == null) throw StateError('tool_event_message_missing');
      await _replaceMessageParts(message, toolEvents: events);
    });
  }

  Future<void> deleteToolEvents(String messageId) async {
    await _db.transaction(() async {
      final message = await getMessage(messageId);
      if (message != null) {
        await _replaceMessageParts(
          message.copyWith(
            parts: [
              for (final part in message.parts)
                if (part is! ToolCallPart) part,
            ],
          ),
        );
      }
    });
  }

  Future<String?> getGeminiThoughtSignature(String messageId) async {
    final artifacts = await getProviderArtifactsForMessages([
      messageId,
    ], 'gemini_thought_signature');
    return artifacts[messageId];
  }

  /// revisionId → payload for every message among [messageIds] that carries
  /// a provider artifact of [kind].
  Future<Map<String, String>> getProviderArtifactsForMessages(
    Iterable<String> messageIds,
    String kind,
  ) async {
    final ids = messageIds.toSet();
    if (ids.isEmpty) return const {};
    final rows = await (_db.select(
      _db.providerArtifactRows,
    )..where((row) => row.revisionId.isIn(ids) & row.kind.equals(kind))).get();
    return <String, String>{
      for (final row in rows)
        if (row.payload.trim().isNotEmpty) row.revisionId: row.payload.trim(),
    };
  }

  Future<void> setProviderArtifact(
    String messageId,
    String kind,
    String payload,
  ) async {
    await _db.transaction(() async {
      await _upsertProviderArtifact(messageId, kind, payload);
    });
  }

  static const String imageOcrArtifactKind = 'image_ocr_v1';

  /// Batch-load OCR artifacts for revisions.
  ///
  /// Returns revisionId → (contentHash → OCR text).
  Future<Map<String, Map<String, String>>> getImageOcrArtifacts(
    Iterable<String> revisionIds,
  ) async {
    final ids = revisionIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    if (ids.isEmpty) return const {};
    final rows =
        await (_db.select(_db.providerArtifactRows)..where(
              (row) =>
                  row.revisionId.isIn(ids) &
                  row.kind.equals(imageOcrArtifactKind),
            ))
            .get();
    final result = <String, Map<String, String>>{};
    for (final row in rows) {
      final items = _decodeImageOcrPayload(row.payload);
      if (items.isEmpty) continue;
      result[row.revisionId] = items;
    }
    return result;
  }

  /// Merge OCR items into the revision artifact and upsert.
  Future<void> upsertImageOcrArtifactItems({
    required String revisionId,
    required Map<String, String> items,
  }) async {
    final cleaned = <String, String>{
      for (final entry in items.entries)
        if (entry.key.trim().isNotEmpty && entry.value.trim().isNotEmpty)
          entry.key.trim(): entry.value.trim(),
    };
    if (cleaned.isEmpty) return;

    await _db.transaction(() async {
      final message = await (_db.select(
        _db.messageRows,
      )..where((row) => row.id.equals(revisionId))).getSingleOrNull();
      if (message == null) {
        throw StateError('provider_artifact_revision_missing');
      }

      final existingRows =
          await (_db.select(_db.providerArtifactRows)..where(
                (row) =>
                    row.revisionId.equals(revisionId) &
                    row.kind.equals(imageOcrArtifactKind),
              ))
              .get();
      final merged = <String, String>{
        for (final row in existingRows) ..._decodeImageOcrPayload(row.payload),
        ...cleaned,
      };
      final now = DateTime.now().toUtc();
      final createdAt = existingRows.isNotEmpty
          ? existingRows.first.createdAt
          : message.timestamp;
      final updatedAt = now.isBefore(createdAt) ? createdAt : now;
      await _db
          .into(_db.providerArtifactRows)
          .insertOnConflictUpdate(
            ProviderArtifactRowsCompanion.insert(
              conversationId: message.conversationId,
              revisionId: revisionId,
              kind: imageOcrArtifactKind,
              payload: _encodeImageOcrPayload(merged),
              createdAt: createdAt,
              updatedAt: updatedAt,
            ),
          );
    });
  }

  /// Copy still-present image OCR items from one revision to another.
  Future<void> inheritImageOcrArtifacts({
    required String fromRevisionId,
    required String toRevisionId,
    required Set<String> retainedContentHashes,
  }) async {
    if (retainedContentHashes.isEmpty) return;
    if (fromRevisionId == toRevisionId) return;
    final source = await getImageOcrArtifacts([fromRevisionId]);
    final items = source[fromRevisionId];
    if (items == null || items.isEmpty) return;
    final inherited = <String, String>{
      for (final entry in items.entries)
        if (retainedContentHashes.contains(entry.key) &&
            entry.value.trim().isNotEmpty)
          entry.key: entry.value.trim(),
    };
    if (inherited.isEmpty) return;
    await upsertImageOcrArtifactItems(
      revisionId: toRevisionId,
      items: inherited,
    );
  }

  /// Look up content hashes for known asset paths.
  ///
  /// Paths with multiple distinct content hashes are omitted so callers cannot
  /// accidentally reuse a stale hash after the file at that path changed.
  Future<Map<String, String>> getAssetContentHashesByPaths(
    Iterable<String> paths,
  ) async {
    final normalized = paths
        .map((path) => path.trim())
        .where((path) => path.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (normalized.isEmpty) return const {};
    final placeholders = List.filled(normalized.length, '?').join(', ');
    final rows = await _db
        .customSelect(
          '''
          SELECT path, content_hash
          FROM asset_rows
          WHERE path IN ($placeholders)
          ORDER BY last_referenced_at DESC, created_at DESC, id DESC;
          ''',
          variables: [for (final path in normalized) Variable<String>(path)],
        )
        .get();
    final hashesByPath = <String, Set<String>>{};
    for (final row in rows) {
      final path = row.read<String>('path');
      final hash = row.read<String>('content_hash');
      if (path.isEmpty || hash.isEmpty) continue;
      hashesByPath.putIfAbsent(path, () => <String>{}).add(hash);
    }
    return {
      for (final entry in hashesByPath.entries)
        if (entry.value.length == 1) entry.key: entry.value.single,
    };
  }

  /// Content hashes of image assets linked to a revision.
  Future<Set<String>> getMessageImageContentHashes(String revisionId) async {
    final id = revisionId.trim();
    if (id.isEmpty) return const {};
    final rows = await _db
        .customSelect(
          '''
      SELECT a.content_hash AS content_hash
      FROM message_asset_rows m
      JOIN asset_rows a ON a.id = m.asset_id
      WHERE m.revision_id = ? AND m.kind = 'image';
      ''',
          variables: [Variable<String>(id)],
        )
        .get();
    return {
      for (final row in rows)
        if (row.read<String>('content_hash').trim().isNotEmpty)
          row.read<String>('content_hash').trim(),
    };
  }

  Map<String, String> _decodeImageOcrPayload(String payload) {
    final raw = payload.trim();
    if (raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      final itemsRaw = decoded['items'];
      if (itemsRaw is! Map) return const {};
      final items = <String, String>{};
      for (final entry in itemsRaw.entries) {
        final hash = entry.key.toString().trim();
        final text = entry.value?.toString().trim() ?? '';
        if (hash.isEmpty || text.isEmpty) continue;
        items[hash] = text;
      }
      return items;
    } catch (_) {
      return const {};
    }
  }

  String _encodeImageOcrPayload(Map<String, String> items) {
    return jsonEncode({'version': 1, 'items': items});
  }

  Future<void> _upsertGeminiThoughtSignature(
    String messageId,
    String signature,
  ) =>
      _upsertProviderArtifact(messageId, 'gemini_thought_signature', signature);

  Future<void> _upsertProviderArtifact(
    String messageId,
    String kind,
    String payload,
  ) async {
    final message = await (_db.select(
      _db.messageRows,
    )..where((row) => row.id.equals(messageId))).getSingleOrNull();
    if (message == null) {
      throw StateError('provider_artifact_revision_missing');
    }
    final now = DateTime.now().toUtc();
    await _db
        .into(_db.providerArtifactRows)
        .insertOnConflictUpdate(
          ProviderArtifactRowsCompanion.insert(
            conversationId: message.conversationId,
            revisionId: messageId,
            kind: kind,
            payload: payload,
            createdAt: message.timestamp,
            updatedAt: now.isBefore(message.timestamp)
                ? message.timestamp
                : now,
          ),
        );
  }

  Future<List<String>> getActiveStreamingIds() async {
    final rows =
        await (_db.select(_db.generationRunRows)..where(
              (row) => row.state.isIn(const [
                'preparing',
                'requesting',
                'streaming',
                'waiting_tool',
              ]),
            ))
            .get();
    return rows.map((row) => row.targetRevisionId).toList(growable: false);
  }

  Future<void> clearActiveStreamingIds() async {
    await (_db.delete(
      _db.chatStorageMetaRows,
    )..where((t) => t.key.equals(ChatStorageMetaKeys.activeStreamingIds))).go();
  }

  /// Atomically terminalizes every generation abandoned by a prior process.
  Future<int> resetStaleStreamingState() async {
    return _db.transaction(() async {
      final activeStates = const [
        'preparing',
        'requesting',
        'streaming',
        'waiting_tool',
      ];
      final runs = await (_db.select(
        _db.generationRunRows,
      )..where((row) => row.state.isIn(activeStates))).get();
      final now = DateTime.now().toUtc();
      if (runs.isNotEmpty) {
        await (_db.update(
          _db.generationRunRows,
        )..where((row) => row.state.isIn(activeStates))).write(
          GenerationRunRowsCompanion(
            state: const Value('interrupted'),
            stateRevision: const Value.absent(),
            errorCode: const Value('app_restart'),
            updatedAt: Value(now),
            terminalAt: Value(now),
          ),
        );
        await _db.customUpdate(
          'UPDATE generation_run_rows '
          'SET state_revision = state_revision + 1 '
          "WHERE state = 'interrupted' AND terminal_at = ?;",
          variables: [Variable.withInt(now.microsecondsSinceEpoch)],
          updates: {_db.generationRunRows},
        );
      }
      // Clearing is_streaming fires message_search_fts_finalize, which indexes
      // the checkpointed text parts left by the abandoned stream.
      await (_db.update(_db.messageRows)
            ..where((row) => row.isStreaming.equals(true)))
          .write(const MessageRowsCompanion(isStreaming: Value(false)));
      await clearActiveStreamingIds();
      return runs.length;
    });
  }

  Future<void> markMigrationComplete() async {
    await _writeMigrationCompleteReceipt();
  }

  Future<void> _writeMigrationCompleteReceipt() async {
    await _db
        .into(_db.chatStorageMetaRows)
        .insertOnConflictUpdate(
          ChatStorageMetaRowsCompanion.insert(
            key: ChatStorageMetaKeys.hiveMigrationComplete,
            value: 'true',
          ),
        );
  }

  Future<bool> isMigrationComplete() async {
    final row =
        await (_db.select(_db.chatStorageMetaRows)..where(
              (t) => t.key.equals(ChatStorageMetaKeys.hiveMigrationComplete),
            ))
            .getSingleOrNull();
    return row?.value == 'true';
  }

  Future<int> _nextMessageOrder(String conversationId) async {
    final maxOrder = _db.messageRows.messageOrder.max();
    final row =
        await (_db.selectOnly(_db.messageRows)
              ..addColumns([maxOrder])
              ..where(_db.messageRows.conversationId.equals(conversationId)))
            .getSingle();
    return (row.read(maxOrder) ?? -1) + 1;
  }

  Future<int> _makeMessageOrderAfterGroup(
    String conversationId,
    String groupId,
  ) async {
    final minOrder = _db.messageRows.messageOrder.min();
    final anchorRow =
        await (_db.selectOnly(_db.messageRows)
              ..addColumns([minOrder])
              ..where(
                _db.messageRows.conversationId.equals(conversationId) &
                    (_db.messageRows.id.equals(groupId) |
                        _db.messageRows.groupId.equals(groupId)),
              ))
            .getSingle();
    final anchorOrder = anchorRow.read(minOrder);
    if (anchorOrder == null) {
      throw StateError('linear_message_group_missing');
    }

    final insertionOrder = anchorOrder + 1;
    final occupied =
        await (_db.selectOnly(_db.messageRows)
              ..addColumns([_db.messageRows.id])
              ..where(
                _db.messageRows.conversationId.equals(conversationId) &
                    _db.messageRows.messageOrder.equals(insertionOrder),
              ))
            .getSingleOrNull();
    if (occupied == null) {
      return insertionOrder;
    }

    final maxOrder = _db.messageRows.messageOrder.max();
    final maxRow =
        await (_db.selectOnly(_db.messageRows)
              ..addColumns([maxOrder])
              ..where(_db.messageRows.conversationId.equals(conversationId)))
            .getSingle();
    final currentMaxOrder = maxRow.read(maxOrder)!;
    final temporaryOffset = currentMaxOrder + 1;

    // A direct +1 update can violate the immediate unique constraint depending
    // on row update order. Move the suffix above the current range first, then
    // place it at its final orders with two set-based updates.
    await _db.customUpdate(
      'UPDATE message_rows SET message_order = message_order + ? '
      'WHERE conversation_id = ? AND message_order > ?;',
      variables: [
        Variable.withInt(temporaryOffset),
        Variable.withString(conversationId),
        Variable.withInt(anchorOrder),
      ],
      updates: {_db.messageRows},
    );
    await _db.customUpdate(
      'UPDATE message_rows SET message_order = message_order - ? + 1 '
      'WHERE conversation_id = ? AND message_order > ?;',
      variables: [
        Variable.withInt(temporaryOffset),
        Variable.withString(conversationId),
        Variable.withInt(currentMaxOrder),
      ],
      updates: {_db.messageRows},
    );
    return insertionOrder;
  }

  Future<void> _replaceMcpServers(
    String conversationId,
    List<String> serverIds,
  ) async {
    await (_db.delete(
      _db.conversationMcpServerRows,
    )..where((t) => t.conversationId.equals(conversationId))).go();
    if (serverIds.isEmpty) return;
    await _db.batch((batch) {
      for (var i = 0; i < serverIds.length; i++) {
        batch.insert(
          _db.conversationMcpServerRows,
          ConversationMcpServerRowsCompanion.insert(
            conversationId: conversationId,
            serverId: serverIds[i],
            ordinal: i,
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  Future<void> _rewriteMessageOrder(
    String conversationId,
    List<String> messageIds,
  ) async {
    if (messageIds.isEmpty) return;
    if (messageIds.toSet().length != messageIds.length) {
      throw ArgumentError.value(
        messageIds,
        'messageIds',
        'Message IDs must be unique when rewriting order.',
      );
    }

    final maxOrder = _db.messageRows.messageOrder.max();
    final maxRow =
        await (_db.selectOnly(_db.messageRows)
              ..addColumns([maxOrder])
              ..where(_db.messageRows.conversationId.equals(conversationId)))
            .getSingle();
    final temporaryStart = (maxRow.read(maxOrder) ?? -1) + 1;
    for (var i = 0; i < messageIds.length; i++) {
      await (_db.update(_db.messageRows)..where(
            (t) =>
                t.conversationId.equals(conversationId) &
                t.id.equals(messageIds[i]),
          ))
          .write(MessageRowsCompanion(messageOrder: Value(temporaryStart + i)));
    }
    for (var i = 0; i < messageIds.length; i++) {
      await (_db.update(_db.messageRows)..where(
            (t) =>
                t.conversationId.equals(conversationId) &
                t.id.equals(messageIds[i]),
          ))
          .write(MessageRowsCompanion(messageOrder: Value(i)));
    }
  }

  Future<List<String>> _getMcpServerIds(String conversationId) async {
    final mcpRows =
        await (_db.select(_db.conversationMcpServerRows)
              ..where((t) => t.conversationId.equals(conversationId))
              ..orderBy([(t) => OrderingTerm.asc(t.ordinal)]))
            .get();
    return mcpRows.map((m) => m.serverId).toList(growable: false);
  }

  Future<Conversation> _conversationFromRow(
    ConversationRow row, {
    bool includeMessageIds = true,
    List<String>? mcpServerIds,
  }) async {
    final resolvedMcpServerIds = mcpServerIds ?? await _getMcpServerIds(row.id);
    final messageRows = includeMessageIds
        ? await (_db.select(_db.messageRows)
                ..where((t) => t.conversationId.equals(row.id))
                ..orderBy([(t) => OrderingTerm.asc(t.messageOrder)]))
              .get()
        : const <MessageRow>[];
    return Conversation(
      id: row.id,
      title: row.title,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      messageIds: messageRows.map((m) => m.id).toList(growable: false),
      isPinned: row.isPinned,
      mcpServerIds: resolvedMcpServerIds,
      assistantId: row.assistantId,
      truncateIndex: row.truncateIndex,
      versionSelections: _decodeStringIntMap(row.versionSelectionsJson),
      summary: row.summary,
      lastSummarizedMessageCount: row.lastSummarizedMessageCount,
      chatSuggestions: _decodeStringList(row.chatSuggestionsJson),
      injectedMemoryHash: row.injectedMemoryHash,
      lastMemoryExtractedOrder: row.lastMemoryExtractedOrder,
      chatModelProvider: row.chatModelProvider,
      chatModelId: row.chatModelId,
    );
  }

  ConversationRowsCompanion _conversationCompanion(
    Conversation conversation, {
    Value<String?>? injectedMemoryHash,
  }) {
    return ConversationRowsCompanion.insert(
      id: conversation.id,
      title: conversation.title,
      createdAt: conversation.createdAt,
      updatedAt: conversation.updatedAt,
      isPinned: Value(conversation.isPinned),
      assistantId: Value(conversation.assistantId),
      truncateIndex: Value(conversation.truncateIndex),
      versionSelectionsJson: Value(jsonEncode(conversation.versionSelections)),
      summary: Value(conversation.summary),
      lastSummarizedMessageCount: Value(
        conversation.lastSummarizedMessageCount,
      ),
      chatSuggestionsJson: Value(jsonEncode(conversation.chatSuggestions)),
      injectedMemoryHash:
          injectedMemoryHash ?? Value(conversation.injectedMemoryHash),
      lastMemoryExtractedOrder: Value(conversation.lastMemoryExtractedOrder),
      chatModelProvider: Value(conversation.chatModelProvider),
      chatModelId: Value(conversation.chatModelId),
    );
  }

  Future<ChatMessage> _messageFromRowWithParts(MessageRow row) async {
    return (await _messagesFromRowsWithParts([row])).single;
  }

  Future<List<ChatMessage>> _messagesFromRowsWithParts(
    List<MessageRow> rows,
  ) async {
    if (rows.isEmpty) return const [];
    final ids = rows.map((row) => row.id).toSet();
    final parts =
        await (_db.select(_db.messagePartRows)
              ..where((part) => part.revisionId.isIn(ids))
              ..orderBy([(part) => OrderingTerm.asc(part.ordinal)]))
            .get();
    final byRevision = <String, List<MessagePartRow>>{};
    for (final part in parts) {
      byRevision.putIfAbsent(part.revisionId, () => []).add(part);
    }
    return [
      for (final row in rows)
        _messageFromRow(row, authoritativeParts: byRevision[row.id]),
    ];
  }

  /// Parts come only from [authoritativeParts] in ordinal order. Missing or
  /// empty parts yield empty content via the derived [ChatMessage.content].
  ChatMessage _messageFromRow(
    MessageRow row, {
    List<MessagePartRow>? authoritativeParts,
  }) {
    final partRows = authoritativeParts ?? const <MessagePartRow>[];
    final parts = <MessagePart>[
      for (final part in partRows)
        _hydratePart(
          revisionId: part.revisionId,
          ordinal: part.ordinal,
          kind: part.kind,
          payload: part.payload,
        ),
    ];
    final reasoningParts = parts.whereType<ReasoningPart>().toList(
      growable: false,
    );
    return ChatMessage(
      id: row.id,
      role: row.role,
      parts: parts,
      timestamp: row.timestamp,
      modelId: row.modelId,
      providerId: row.providerId,
      totalTokens: row.totalTokens,
      conversationId: row.conversationId,
      isStreaming: row.isStreaming,
      reasoningText: reasoningParts.isEmpty
          ? null
          : reasoningParts.map((part) => part.text).join('\n'),
      reasoningStartAt: row.reasoningStartAt,
      reasoningFinishedAt: row.reasoningFinishedAt,
      translation: row.translation,
      reasoningSegmentsJson: row.reasoningSegmentsJson,
      groupId: row.groupId,
      version: row.version,
      promptTokens: row.promptTokens,
      completionTokens: row.completionTokens,
      cachedTokens: row.cachedTokens,
      durationMs: row.durationMs,
    );
  }

  bool _messageHasAttachmentParts(ChatMessage message) {
    return message.parts.any(
      (part) =>
          part is ImagePart ||
          part is FilePart ||
          (part is MalformedPart && part.isAttachmentKind),
    );
  }

  /// Persist [message.parts] in arrival order.
  ///
  /// [toolEvents] / [ChatMessage.reasoningText] are compatibility overlays.
  /// Empty [toolEvents] never strips [ToolCallPart]s already on the message —
  /// those cards are the write source during a server-tool gap. Extra events
  /// that do not match a part are inserted after the last tool slot.
  List<MessagePart> _partsForPersistence(
    ChatMessage message,
    List<Map<String, dynamic>>? toolEvents,
  ) {
    var parts = List<MessagePart>.of(message.parts);
    if (!parts.any((part) => part is ReasoningPart)) {
      final reasoning = message.reasoningText;
      if (reasoning != null && reasoning.isNotEmpty) {
        parts = [ReasoningPart(reasoning), ...parts];
      }
    }
    if (toolEvents != null) {
      if (parts.any((part) => part is ToolCallPart)) {
        parts = _applyToolEventsToParts(parts, toolEvents);
      } else if (toolEvents.isNotEmpty) {
        parts = [
          ...parts,
          for (final event in toolEvents) ToolCallPart(jsonEncode(event)),
        ];
      }
    }
    if (parts.isEmpty) {
      return <MessagePart>[TextPart(message.content)];
    }
    return parts;
  }

  List<MessagePart> _applyToolEventsToParts(
    List<MessagePart> parts,
    List<Map<String, dynamic>> toolEvents,
  ) {
    final partCount = parts.whereType<ToolCallPart>().length;
    if (partCount != toolEvents.length) {
      debugPrint(
        'toolEvents/parts count mismatch: events=${toolEvents.length} '
        'parts=$partCount',
      );
    }
    final unused = [for (final event in toolEvents) event];
    Map<String, dynamic>? takeById(String id) {
      if (id.isEmpty) return null;
      final index = unused.indexWhere(
        (event) => (event['id'] ?? '').toString() == id,
      );
      if (index < 0) return null;
      return unused.removeAt(index);
    }

    final matchedByPart = List<Map<String, dynamic>?>.filled(
      parts.length,
      null,
    );
    for (var i = 0; i < parts.length; i++) {
      final part = parts[i];
      if (part is! ToolCallPart) continue;
      final partId = _toolCallPartId(part) ?? '';
      if (partId.isEmpty) continue;
      matchedByPart[i] = takeById(partId);
    }
    for (var i = 0; i < parts.length; i++) {
      final part = parts[i];
      if (part is! ToolCallPart) continue;
      if ((_toolCallPartId(part) ?? '').isNotEmpty) continue;
      if (unused.isEmpty) break;
      matchedByPart[i] = unused.removeAt(0);
    }

    final out = <MessagePart>[];
    var lastToolIndex = -1;
    for (var i = 0; i < parts.length; i++) {
      final part = parts[i];
      if (part is! ToolCallPart) {
        out.add(part);
        continue;
      }
      final matched = matchedByPart[i];
      if (matched != null) {
        out.add(ToolCallPart(jsonEncode(_mergeToolPayload(part, matched))));
      } else {
        out.add(part);
      }
      lastToolIndex = out.length - 1;
    }
    if (unused.isNotEmpty) {
      final extras = [
        for (final event in unused) ToolCallPart(jsonEncode(event)),
      ];
      final insertAt = lastToolIndex >= 0 ? lastToolIndex + 1 : out.length;
      out.insertAll(insertAt, extras);
    }
    return out;
  }

  Map<String, dynamic> _mergeToolPayload(
    ToolCallPart part,
    Map<String, dynamic> event,
  ) {
    Map<String, dynamic> base = const <String, dynamic>{};
    try {
      final decoded = jsonDecode(part.payloadJson);
      if (decoded is Map) {
        base = Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    final merged = Map<String, dynamic>.from(base);
    for (final entry in event.entries) {
      if (_isEmptyToolOverlay(entry.value) &&
          !_isEmptyToolOverlay(base[entry.key])) {
        continue;
      }
      merged[entry.key] = entry.value;
    }
    if (base['server'] == true && event['server'] != false) {
      merged['server'] = true;
    }
    if (_isSearchToolName(merged['name'] ?? base['name'] ?? event['name'])) {
      merged['content'] = jsonEncode(
        StreamChunkHandler.mergeSearchItems(
          base['content'],
          _searchItemsOf(event['content']),
        ),
      );
    }
    return merged;
  }

  bool _isEmptyToolOverlay(Object? value) {
    if (value == null) return true;
    if (value is String) return value.isEmpty;
    if (value is Map) return value.isEmpty;
    if (value is List) return value.isEmpty;
    return false;
  }

  bool _isSearchToolName(Object? name) {
    final toolName = (name ?? '').toString();
    return toolName == 'search_web' || toolName == 'builtin_search';
  }

  List<Map<String, dynamic>> _searchItemsOf(Object? raw) {
    final map = _asStringKeyedMap(raw);
    final items = map?['items'];
    if (items is! List) return const <Map<String, dynamic>>[];
    return [
      for (final item in items)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }

  Map<String, dynamic>? _asStringKeyedMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return null;
  }

  String? _toolCallPartId(ToolCallPart part) {
    try {
      final decoded = jsonDecode(part.payloadJson);
      if (decoded is Map) {
        final id = (decoded['id'] ?? '').toString();
        return id.isEmpty ? null : id;
      }
    } catch (_) {}
    return null;
  }

  MessagePart _hydratePart({
    required String revisionId,
    required int ordinal,
    required String kind,
    required String payload,
  }) {
    try {
      return MessagePart.fromRow(kind, payload);
    } on FormatException catch (error) {
      final parseError = messagePartParseErrorCategory(error);
      debugPrint(
        'Malformed message part: revisionId=$revisionId ordinal=$ordinal '
        'kind=$kind parseError=$parseError',
      );
      return MalformedPart(
        rawKind: kind,
        rawPayload: payload,
        parseError: parseError,
      );
    }
  }

  DateTime _dateTimeFromSqlite(Object? value) {
    if (value is int) {
      return DateTime.fromMicrosecondsSinceEpoch(value);
    }
    if (value is num) {
      return DateTime.fromMicrosecondsSinceEpoch(value.toInt());
    }
    throw StateError('Invalid SQLite DateTime value: $value.');
  }

  MessageRowsCompanion _messageCompanion(
    ChatMessage message,
    int messageOrder,
  ) {
    return MessageRowsCompanion.insert(
      id: message.id,
      conversationId: message.conversationId,
      role: message.role,
      timestamp: message.timestamp,
      modelId: Value(message.modelId),
      providerId: Value(message.providerId),
      totalTokens: Value(message.totalTokens),
      isStreaming: Value(message.isStreaming),
      reasoningStartAt: Value(message.reasoningStartAt),
      reasoningFinishedAt: Value(message.reasoningFinishedAt),
      translation: Value(message.translation),
      reasoningSegmentsJson: Value(message.reasoningSegmentsJson),
      groupId: Value(message.groupId),
      version: Value(message.version),
      promptTokens: Value(message.promptTokens),
      completionTokens: Value(message.completionTokens),
      cachedTokens: Value(message.cachedTokens),
      durationMs: Value(message.durationMs),
      messageOrder: messageOrder,
    );
  }

  MessageRowsCompanion _messageUpdate(ChatMessage message) {
    return MessageRowsCompanion(
      totalTokens: Value(message.totalTokens),
      isStreaming: Value(message.isStreaming),
      reasoningStartAt: Value(message.reasoningStartAt),
      reasoningFinishedAt: Value(message.reasoningFinishedAt),
      translation: Value(message.translation),
      reasoningSegmentsJson: Value(message.reasoningSegmentsJson),
      promptTokens: Value(message.promptTokens),
      completionTokens: Value(message.completionTokens),
      cachedTokens: Value(message.cachedTokens),
      durationMs: Value(message.durationMs),
    );
  }

  Map<String, int> _decodeStringIntMap(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, int>{};
      return decoded.map((key, value) {
        final intValue = value is num ? value.toInt() : int.parse('$value');
        return MapEntry(key.toString(), intValue);
      });
    } catch (_) {
      return <String, int>{};
    }
  }

  List<String> _decodeStringList(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <String>[];
      return decoded.map((e) => e.toString()).toList(growable: false);
    } catch (_) {
      return <String>[];
    }
  }

  // —— Memory system V1 read path (§13.3) ——

  /// Visible memories for [assistantId]: `status='active'` (unless
  /// [includeArchived]) and `(scope='global' OR (scope='assistant' AND
  /// assistant_id = :aid))`. When [assistantId] is null, only global rows
  /// are visible. Ordered for in-block injection (§7.2):
  /// `scope_rank ASC, entry_created_at ASC, id ASC` (global before assistant).
  Future<List<MemoryEntry>> queryVisibleMemories({
    required String? assistantId,
    MemoryType? type,
    bool includeArchived = false,
    int? limit,
  }) async {
    final clauses = <String>[_memoryVisibilitySql(assistantId)];
    final variables = <Variable<Object>>[
      ..._memoryVisibilityVariables(assistantId),
    ];
    if (!includeArchived) {
      clauses.add("status = 'active'");
    }
    if (type != null) {
      clauses.add('type = ?');
      variables.add(Variable<String>(MemoryEntry.typeToString(type)));
    }
    final limitSql = limit == null ? '' : ' LIMIT ?';
    if (limit != null) {
      variables.add(Variable<int>(limit));
    }
    final rows = await _db
        .customSelect(
          'SELECT payload FROM memory_entry_rows '
          'WHERE ${clauses.join(' AND ')} '
          'ORDER BY CASE WHEN scope = \'global\' THEN 0 ELSE 1 END ASC, '
          'entry_created_at ASC, id ASC'
          '$limitSql;',
          variables: variables,
          readsFrom: {_db.memoryEntryRows},
        )
        .get();
    return _memoryEntriesFromPayloadRows(
      rows,
      assistantId: assistantId,
      dropInvisibleRelated: true,
    );
  }

  /// Counts active visible memories by [MemoryType] for [assistantId].
  Future<Map<MemoryType, int>> countVisibleMemoriesByType({
    required String? assistantId,
  }) async {
    final rows = await _db
        .customSelect(
          'SELECT type, COUNT(*) AS count FROM memory_entry_rows '
          "WHERE status = 'active' AND ${_memoryVisibilitySql(assistantId)} "
          'GROUP BY type;',
          variables: _memoryVisibilityVariables(assistantId),
          readsFrom: {_db.memoryEntryRows},
        )
        .get();
    final result = <MemoryType, int>{
      for (final type in MemoryType.values) type: 0,
    };
    for (final row in rows) {
      final type = MemoryEntry.typeFromString(row.read<String>('type'));
      result[type] = row.read<int>('count');
    }
    return result;
  }

  /// Search memories by pre-normalized, LIKE-escaped [tokens].
  ///
  /// Callers must lowercase/normalize tokens and escape `%`, `_`, and `\`
  /// (e.g. via [MemoryTokenizer.escapeLike]) before passing them here.
  ///
  /// - [matchAll] `true` (§5.9): every token must match (`AND`), ordered by
  ///   `entry_updated_at DESC, id ASC`.
  /// - [matchAll] `false` (§12.6): `hits` = count of matching tokens (`OR`),
  ///   filter `hits >= 1`, ordered by
  ///   `hits DESC, entry_updated_at DESC, id ASC`.
  Future<List<MemoryEntry>> searchMemories({
    required String? assistantId,
    required List<String> tokens,
    MemoryType? type,
    bool matchAll = true,
    int limit = 10,
  }) async {
    if (tokens.isEmpty || limit <= 0) {
      return const <MemoryEntry>[];
    }
    if (!matchAll) {
      return _searchMemoriesMatchAny(
        assistantId: assistantId,
        tokens: tokens,
        type: type,
        limit: limit,
      );
    }

    final clauses = <String>[
      "status = 'active'",
      _memoryVisibilitySql(assistantId),
    ];
    final variables = <Variable<Object>>[
      ..._memoryVisibilityVariables(assistantId),
    ];
    if (type != null) {
      clauses.add('type = ?');
      variables.add(Variable<String>(MemoryEntry.typeToString(type)));
    }
    for (final token in tokens) {
      clauses.add("content_normalized LIKE ? ESCAPE '\\'");
      variables.add(Variable<String>('%$token%'));
    }
    variables.add(Variable<int>(limit));
    final rows = await _db
        .customSelect(
          'SELECT payload FROM memory_entry_rows '
          'WHERE ${clauses.join(' AND ')} '
          'ORDER BY entry_updated_at DESC, id ASC '
          'LIMIT ?;',
          variables: variables,
          readsFrom: {_db.memoryEntryRows},
        )
        .get();
    return _memoryEntriesFromPayloadRows(
      rows,
      assistantId: assistantId,
      dropInvisibleRelated: true,
    );
  }

  Future<List<MemoryEntry>> _searchMemoriesMatchAny({
    required String? assistantId,
    required List<String> tokens,
    required MemoryType? type,
    required int limit,
  }) async {
    final hitParts = <String>[
      for (final _ in tokens)
        "CASE WHEN content_normalized LIKE ? ESCAPE '\\' THEN 1 ELSE 0 END",
    ];
    final hitsExpr = hitParts.join(' + ');

    // Variable order must match `?` appearance: SELECT hits, then WHERE.
    final clauses = <String>[
      "status = 'active'",
      _memoryVisibilitySql(assistantId),
    ];
    final variables = <Variable<Object>>[
      for (final token in tokens) Variable<String>('%$token%'),
      ..._memoryVisibilityVariables(assistantId),
    ];
    if (type != null) {
      clauses.add('type = ?');
      variables.add(Variable<String>(MemoryEntry.typeToString(type)));
    }
    clauses.add('($hitsExpr) >= 1');
    for (final token in tokens) {
      variables.add(Variable<String>('%$token%'));
    }
    variables.add(Variable<int>(limit));

    final rows = await _db
        .customSelect(
          'SELECT payload, ($hitsExpr) AS hits FROM memory_entry_rows '
          'WHERE ${clauses.join(' AND ')} '
          'ORDER BY hits DESC, entry_updated_at DESC, id ASC '
          'LIMIT ?;',
          variables: variables,
          readsFrom: {_db.memoryEntryRows},
        )
        .get();
    return _memoryEntriesFromPayloadRows(
      rows,
      assistantId: assistantId,
      dropInvisibleRelated: true,
    );
  }

  Future<List<MemoryEntry>> memoriesByIds(List<String> ids) async {
    if (ids.isEmpty) return const <MemoryEntry>[];
    final unique = ids.toSet().toList(growable: false);
    final placeholders = List.filled(unique.length, '?').join(',');
    final rows = await _db
        .customSelect(
          'SELECT payload FROM memory_entry_rows '
          'WHERE id IN ($placeholders) '
          'ORDER BY id ASC;',
          variables: [for (final id in unique) Variable<String>(id)],
          readsFrom: {_db.memoryEntryRows},
        )
        .get();
    return _memoryEntriesFromPayloadRows(
      rows,
      assistantId: null,
      dropInvisibleRelated: false,
    );
  }

  Future<MemoryEntry?> findExactMemory({
    required String? assistantId,
    required MemoryType type,
    required String contentNormalized,
  }) async {
    final rows = await _db
        .customSelect(
          'SELECT payload FROM memory_entry_rows '
          "WHERE status = 'active' "
          'AND ${_memoryVisibilitySql(assistantId)} '
          'AND type = ? '
          'AND content_normalized = ? '
          'LIMIT 1;',
          variables: [
            ..._memoryVisibilityVariables(assistantId),
            Variable<String>(MemoryEntry.typeToString(type)),
            Variable<String>(contentNormalized),
          ],
          readsFrom: {_db.memoryEntryRows},
        )
        .get();
    if (rows.isEmpty) return null;
    final entries = await _memoryEntriesFromPayloadRows(
      rows,
      assistantId: assistantId,
      dropInvisibleRelated: true,
    );
    return entries.single;
  }

  Future<int> countOrphanAssistantMemories() async {
    final row = await _db
        .customSelect(
          'SELECT COUNT(*) AS count FROM memory_entry_rows m '
          "WHERE m.scope = 'assistant' "
          'AND NOT EXISTS ('
          'SELECT 1 FROM assistant_rows a WHERE a.id = m.assistant_id'
          ');',
          readsFrom: {_db.memoryEntryRows, _db.assistantRows},
        )
        .getSingle();
    return row.read<int>('count');
  }

  /// All memory entries across every assistant (global management UI §14.4).
  Future<List<MemoryEntry>> queryAllMemories({
    bool includeArchived = false,
    MemoryType? type,
  }) async {
    final clauses = <String>[];
    final variables = <Variable<Object>>[];
    if (!includeArchived) {
      clauses.add("status = 'active'");
    }
    if (type != null) {
      clauses.add('type = ?');
      variables.add(Variable<String>(MemoryEntry.typeToString(type)));
    }
    final where = clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')} ';
    final rows = await _db
        .customSelect(
          'SELECT payload FROM memory_entry_rows '
          '$where'
          'ORDER BY entry_updated_at DESC, id ASC;',
          variables: variables,
          readsFrom: {_db.memoryEntryRows},
        )
        .get();
    return _memoryEntriesFromPayloadRows(
      rows,
      assistantId: null,
      dropInvisibleRelated: false,
    );
  }

  /// Search across every assistant (§14.4 / §5.9 AND semantics).
  Future<List<MemoryEntry>> searchAllMemories({
    required List<String> tokens,
    MemoryType? type,
    bool includeArchived = false,
    int limit = 200,
  }) async {
    if (tokens.isEmpty || limit <= 0) {
      return const <MemoryEntry>[];
    }
    final clauses = <String>[];
    final variables = <Variable<Object>>[];
    if (!includeArchived) {
      clauses.add("status = 'active'");
    }
    if (type != null) {
      clauses.add('type = ?');
      variables.add(Variable<String>(MemoryEntry.typeToString(type)));
    }
    for (final token in tokens) {
      clauses.add("content_normalized LIKE ? ESCAPE '\\'");
      variables.add(Variable<String>('%$token%'));
    }
    variables.add(Variable<int>(limit));
    final rows = await _db
        .customSelect(
          'SELECT payload FROM memory_entry_rows '
          'WHERE ${clauses.join(' AND ')} '
          'ORDER BY entry_updated_at DESC, id ASC '
          'LIMIT ?;',
          variables: variables,
          readsFrom: {_db.memoryEntryRows},
        )
        .get();
    return _memoryEntriesFromPayloadRows(
      rows,
      assistantId: null,
      dropInvisibleRelated: false,
    );
  }

  Future<List<UserProfileField>> readProfileFields() async {
    final rows = await _db
        .customSelect(
          'SELECT payload FROM user_profile_field_rows '
          'ORDER BY sort_order ASC, id ASC;',
          readsFrom: {_db.userProfileFieldRows},
        )
        .get();
    return [
      for (final row in rows)
        UserProfileField.fromPayload(
          (jsonDecode(row.read<String>('payload')) as Map)
              .cast<String, dynamic>(),
        ),
    ];
  }

  Future<MessagePromptRow?> getMessagePrompt(String revisionId) {
    return (_db.select(
      _db.messagePromptRows,
    )..where((t) => t.revisionId.equals(revisionId))).getSingleOrNull();
  }

  Future<Map<String, MessagePromptRow>> getMessagePrompts(
    Iterable<String> revisionIds,
  ) async {
    final ids = revisionIds.toSet();
    if (ids.isEmpty) return const {};
    final rows = await (_db.select(
      _db.messagePromptRows,
    )..where((row) => row.revisionId.isIn(ids))).get();
    return {for (final row in rows) row.revisionId: row};
  }

  Future<void> putMessagePrompt({
    required String revisionId,
    required String conversationId,
    required String payload,
    required bool carriesMemorySnapshot,
  }) async {
    final now = DateTime.now().toUtc();
    await _db
        .into(_db.messagePromptRows)
        .insertOnConflictUpdate(
          MessagePromptRowsCompanion.insert(
            revisionId: revisionId,
            conversationId: conversationId,
            payload: payload,
            carriesMemorySnapshot: Value(carriesMemorySnapshot),
            createdAt: now,
          ),
        );
  }

  /// Freezes a message's final prompt string and, when a snapshot was
  /// injected, advances the conversation's injected-memory hash in the same
  /// transaction.
  ///
  /// The two writes must not be split: a crash between them leaves a hash that
  /// claims a snapshot was delivered while no message carries one, costing an
  /// extra full re-injection once self-healing notices (§8.3).
  Future<void> freezeMessagePrompt({
    required String revisionId,
    required String conversationId,
    required String payload,
    required bool carriesMemorySnapshot,
    String? injectedMemoryHash,
  }) {
    return _db.transaction(() async {
      await putMessagePrompt(
        revisionId: revisionId,
        conversationId: conversationId,
        payload: payload,
        carriesMemorySnapshot: carriesMemorySnapshot,
      );
      if (carriesMemorySnapshot) {
        await setConversationInjectedMemoryHash(
          conversationId,
          injectedMemoryHash,
        );
      }
    });
  }

  Future<bool> anyPromptCarriesMemorySnapshot(List<String> revisionIds) async {
    if (revisionIds.isEmpty) return false;
    final unique = revisionIds.toSet().toList(growable: false);
    final placeholders = List.filled(unique.length, '?').join(',');
    final row = await _db
        .customSelect(
          'SELECT 1 AS hit FROM message_prompt_rows '
          'WHERE carries_memory_snapshot = 1 '
          'AND revision_id IN ($placeholders) '
          'LIMIT 1;',
          variables: [for (final id in unique) Variable<String>(id)],
          readsFrom: {_db.messagePromptRows},
        )
        .getSingleOrNull();
    return row != null;
  }

  /// The last memory snapshot hash delivered to [conversationId].
  ///
  /// Read this rather than a cached [Conversation]: the field is written by
  /// [freezeMessagePrompt] and never loaded back into the in-memory model, so a
  /// cached copy reports the value from whenever it was constructed.
  Future<String?> getConversationInjectedMemoryHash(
    String conversationId,
  ) async {
    final row = await _db
        .customSelect(
          'SELECT injected_memory_hash FROM conversation_rows '
          'WHERE id = ? LIMIT 1;',
          variables: [Variable<String>(conversationId)],
          readsFrom: {_db.conversationRows},
        )
        .getSingleOrNull();
    return row?.read<String?>('injected_memory_hash');
  }

  Future<void> setConversationInjectedMemoryHash(
    String conversationId,
    String? hash,
  ) async {
    await (_db.update(_db.conversationRows)
          ..where((t) => t.id.equals(conversationId)))
        .write(ConversationRowsCompanion(injectedMemoryHash: Value(hash)));
  }

  Future<void> setConversationLastMemoryExtractedOrder(
    String conversationId,
    int order,
  ) async {
    await (_db.update(
      _db.conversationRows,
    )..where((t) => t.id.equals(conversationId))).write(
      ConversationRowsCompanion(lastMemoryExtractedOrder: Value(order)),
    );
  }

  /// Clears the per-conversation model override on every conversation pointing
  /// at [providerKey] (optionally narrowed to a single [modelId]).
  ///
  /// Called when a provider or model is deleted, so the affected conversations
  /// fall back to the assistant's model instead of pointing at something gone.
  /// Returns the number of conversations changed.
  Future<int> clearConversationModelOverrides({
    required String providerKey,
    String? modelId,
  }) async {
    final statement = _db.update(_db.conversationRows)
      ..where(
        (t) => modelId == null
            ? t.chatModelProvider.equals(providerKey)
            : t.chatModelProvider.equals(providerKey) &
                  t.chatModelId.equals(modelId),
      );
    return statement.write(
      const ConversationRowsCompanion(
        chatModelProvider: Value(null),
        chatModelId: Value(null),
      ),
    );
  }

  String _memoryVisibilitySql(String? assistantId) {
    if (assistantId == null) {
      return "scope = 'global'";
    }
    return "(scope = 'global' OR (scope = 'assistant' AND assistant_id = ?))";
  }

  List<Variable<Object>> _memoryVisibilityVariables(String? assistantId) {
    if (assistantId == null) return const <Variable<Object>>[];
    return <Variable<Object>>[Variable<String>(assistantId)];
  }

  Future<List<MemoryEntry>> _memoryEntriesFromPayloadRows(
    List<QueryRow> rows, {
    required String? assistantId,
    required bool dropInvisibleRelated,
  }) async {
    if (rows.isEmpty) return const <MemoryEntry>[];
    final entries = <MemoryEntry>[
      for (final row in rows)
        MemoryEntry.fromPayload(
          (jsonDecode(row.read<String>('payload')) as Map)
              .cast<String, dynamic>(),
        ),
    ];
    final related = <String>{for (final entry in entries) ...entry.relatedIds};
    if (related.isEmpty) return entries;

    final keep = dropInvisibleRelated
        ? await _filterRelatedIdsVisible(related, assistantId)
        : await _filterRelatedIdsExisting(related);
    return [
      for (final entry in entries)
        () {
          final filtered = entry.relatedIds
              .where(keep.contains)
              .toList(growable: false);
          if (filtered.length == entry.relatedIds.length) return entry;
          return entry.copyWith(relatedIds: filtered);
        }(),
    ];
  }

  Future<Set<String>> _filterRelatedIdsExisting(Set<String> ids) async {
    if (ids.isEmpty) return const <String>{};
    final list = ids.toList(growable: false);
    final placeholders = List.filled(list.length, '?').join(',');
    final rows = await _db
        .customSelect(
          'SELECT id FROM memory_entry_rows WHERE id IN ($placeholders);',
          variables: [for (final id in list) Variable<String>(id)],
          readsFrom: {_db.memoryEntryRows},
        )
        .get();
    return {for (final row in rows) row.read<String>('id')};
  }

  Future<Set<String>> _filterRelatedIdsVisible(
    Set<String> ids,
    String? assistantId,
  ) async {
    if (ids.isEmpty) return const <String>{};
    final list = ids.toList(growable: false);
    final placeholders = List.filled(list.length, '?').join(',');
    final rows = await _db
        .customSelect(
          'SELECT id FROM memory_entry_rows '
          "WHERE status = 'active' "
          'AND ${_memoryVisibilitySql(assistantId)} '
          'AND id IN ($placeholders);',
          variables: [
            ..._memoryVisibilityVariables(assistantId),
            for (final id in list) Variable<String>(id),
          ],
          readsFrom: {_db.memoryEntryRows},
        )
        .get();
    return {for (final row in rows) row.read<String>('id')};
  }
}

class ConversationSearchMatch {
  const ConversationSearchMatch({
    required this.conversationId,
    required this.conversationTitle,
    required this.updatedAt,
    required this.versionSelections,
    required this.messageId,
    required this.messageContent,
    required this.messageRole,
    required this.groupId,
    required this.version,
    required this.maxVersion,
  });

  final String conversationId;
  final String conversationTitle;
  final DateTime updatedAt;
  final Map<String, int> versionSelections;
  final String? messageId;
  final String? messageContent;
  final String? messageRole;
  final String? groupId;
  final int? version;
  final int? maxVersion;
}

class MiniMapSearchHit {
  const MiniMapSearchHit({
    required this.messageId,
    required this.matchCount,
    required this.snippet,
    required this.snippetStart,
  });

  final String messageId;
  final int matchCount;
  final String snippet;
  final int snippetStart;
}

/// Grows the snippet window so the first hit is not cut mid-keyword.
///
/// Default radius 40 + length 120 leaves only 80 characters for the needle.
int miniMapSnippetLength({
  required int needleLength,
  int snippetRadius = 40,
  int snippetLength = 120,
}) {
  final radius = snippetRadius < 0 ? 0 : snippetRadius;
  final length = snippetLength < 0 ? 0 : snippetLength;
  final needed = radius + needleLength;
  return length < needed ? needed : length;
}

final class ChatStatsTotals {
  const ChatStatsTotals({
    required this.messages,
    required this.inputTokens,
    required this.outputTokens,
    required this.cachedTokens,
  });

  final int messages;
  final int inputTokens;
  final int outputTokens;
  final int cachedTokens;
}

final class ChatStatsDayCount {
  const ChatStatsDayCount({required this.day, required this.count});
  final DateTime day;
  final int count;
}

final class ChatStatsTrendBucket {
  const ChatStatsTrendBucket({
    required this.day,
    required this.providerId,
    required this.activityCount,
    required this.inputTokens,
    required this.outputTokens,
    required this.cachedTokens,
    required this.uncategorizedTokens,
  });
  final DateTime day;
  final String providerId;
  final int activityCount;
  final int inputTokens;
  final int outputTokens;
  final int cachedTokens;
  final int uncategorizedTokens;
}

final class ChatStatsRank {
  const ChatStatsRank({
    required this.id,
    required this.label,
    required this.count,
    this.providerId,
  });
  final String id;
  final String label;
  final int count;
  final String? providerId;
}

final class ChatStatsAggregate {
  const ChatStatsAggregate({
    required this.conversations,
    required this.totals,
    required this.heatmap,
    required this.trend,
    required this.models,
    required this.assistants,
    required this.topics,
  });
  final int conversations;
  final ChatStatsTotals totals;
  final List<ChatStatsDayCount> heatmap;
  final List<ChatStatsTrendBucket> trend;
  final List<ChatStatsRank> models;
  final List<ChatStatsRank> assistants;
  final List<ChatStatsRank> topics;
}

final class AssetGcCandidate {
  const AssetGcCandidate({
    required this.assetId,
    required this.path,
    required this.thumbnailPath,
    required this.byteSize,
    required this.generation,
  });
  final String assetId;
  final String path;
  final String? thumbnailPath;
  final int byteSize;
  final int generation;
}

String _alternateAssetPathForm(String path) {
  if (KelivoFileUri.isKelivoFileUri(path)) {
    final resolved = SandboxPathResolver.fix(path);
    return resolved.isEmpty ? path : resolved;
  }
  final canonical = SandboxPathResolver.canonicalize(path);
  return canonical.isEmpty ? path : canonical;
}

String _jsonEscapedPathForm(String path) {
  final encoded = jsonEncode(path);
  return encoded.substring(1, encoded.length - 1);
}

final class MessageAssetRegistration {
  const MessageAssetRegistration({
    required this.assetId,
    required this.contentHash,
    required this.path,
    required this.byteSize,
    required this.kind,
    this.width,
    this.height,
    this.thumbnailPath,
  });

  final String assetId;
  final String contentHash;
  final String path;
  final int byteSize;
  final String kind;
  final int? width;
  final int? height;
  final String? thumbnailPath;
}

class ChatStorageMetaKeys {
  ChatStorageMetaKeys._();

  static const activeStreamingIds = 'active_streaming_ids';
  static const hiveMigrationComplete = 'hive_migration_complete_v1';
  static const databaseIdentity = 'database_identity_v1';
  static const sandboxPathVersion = 'sandbox_path_migration_version';
  static const assetReferenceBackfillVersion =
      'asset_reference_backfill_version';
}
