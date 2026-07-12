import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../models/chat_message.dart';
import '../models/conversation.dart';
import 'app_database.dart';
import 'chat_database_observer.dart';
import 'generation_run.dart';
import 'generation_run_commands.dart';
import 'message_graph_projector.dart';
import 'message_graph_commands.dart';
import 'legacy_message_graph_adapter.dart';

typedef ChatDatabaseSnapshotInfo = ({
  int schemaVersion,
  int conversationCount,
  int messageCount,
});

typedef InstalledChatDatabaseInfo = ({int schemaVersion, String? databaseId});

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
    required this.remappedConversationIds,
  });

  final int importedConversations;
  final int deduplicatedConversations;
  final Map<String, String> remappedConversationIds;

  int get remappedConversations => remappedConversationIds.length;
}

class SandboxPathMigrationResult {
  const SandboxPathMigrationResult({
    required this.ran,
    required this.scannedMessages,
    required this.updatedMessages,
  });

  final bool ran;
  final int scannedMessages;
  final int updatedMessages;
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
    String? geminiThoughtSignature,
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
        final signature = geminiThoughtSignature?.trim();
        if (signature != null && signature.isNotEmpty) {
          await _upsertGeminiThoughtSignature(message.id, signature);
        }
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

  static Future<bool> migrateInstalledDatabase(File file) async {
    final database = sqlite.sqlite3.open(
      file.absolute.path,
      mode: sqlite.OpenMode.readOnly,
    );
    late final int schemaVersion;
    try {
      schemaVersion = database.userVersion;
      if (schemaVersion > AppDatabase.currentSchemaVersion) {
        throw StateError('database_schema_too_new');
      }
      if (schemaVersion == AppDatabase.currentSchemaVersion) return false;
      if (schemaVersion < AppDatabase.oldestMigratableSchemaVersion) {
        throw StateError('database_schema_too_old');
      }
      _validateRawSnapshot(database);
    } on sqlite.SqliteException {
      throw StateError('database_corrupt');
    } finally {
      database.close();
    }

    final driftDatabase = AppDatabase.open(file: file);
    try {
      await driftDatabase.customSelect('SELECT 1;').getSingle();
    } finally {
      await driftDatabase.close();
    }
    inspectInstalledDatabase(file, validateContents: true);
    return true;
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
      final info = _validateRawSnapshot(database);
      if (info.schemaVersion != AppDatabase.currentSchemaVersion) {
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
      late final ChatDatabaseSnapshotInfo initialInfo;
      final source = sqlite.sqlite3.open(sourcePath);
      try {
        source.execute('PRAGMA query_only = ON;');
        final destination = sqlite.sqlite3.open(destinationPath);
        try {
          final pageSizeRows = source.select('PRAGMA page_size;');
          final pageSize = pageSizeRows.first.values.first as int;
          final pagesPerStep = (8 * 1024 * 1024 ~/ pageSize).clamp(1, 1 << 20);
          await source.backup(destination, nPage: pagesPerStep).drain<void>();
          initialInfo = _validateRawSnapshot(destination);
          destination.execute('PRAGMA wal_checkpoint(TRUNCATE);');
          destination.select('PRAGMA journal_mode = DELETE;');
        } finally {
          destination.close();
        }
      } finally {
        source.close();
      }

      await _deleteDatabaseSidecars(destinationFile);
      final reopened = sqlite.sqlite3.open(destinationPath);
      try {
        final reopenedInfo = _validateRawSnapshot(reopened);
        if (reopenedInfo != initialInfo) {
          throw StateError('snapshot_reopen_mismatch');
        }
      } finally {
        reopened.close();
      }
      await _deleteDatabaseSidecars(destinationFile);
      return initialInfo;
    } catch (_) {
      await _deleteDatabaseFamily(destinationFile);
      rethrow;
    }
  }

  static Future<ChatDatabaseSnapshotInfo> prepareSnapshotForRestore(
    File snapshotFile,
  ) async {
    if (!await snapshotFile.exists()) {
      throw FileSystemException(
        'Snapshot database does not exist',
        snapshotFile.path,
      );
    }

    final database = sqlite.sqlite3.open(snapshotFile.absolute.path);
    late final ChatDatabaseSnapshotInfo initialInfo;
    try {
      initialInfo = _validateRawSnapshot(database);
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

  static void _validateRawStructure(sqlite.Database database) {
    final requiredTables = <String>{
      'conversation_rows',
      'conversation_mcp_server_rows',
      'message_rows',
      'tool_event_rows',
      'gemini_thought_signature_rows',
      'chat_storage_meta_rows',
    };
    final includesMessageGraph =
        database.userVersion >= AppDatabase.messageGraphSchemaVersion;
    final includesMessageParts =
        database.userVersion >= AppDatabase.messagePartsSchemaVersion;
    final includesMigrationLedger =
        database.userVersion >= AppDatabase.legacyGraphAdapterSchemaVersion;
    final includesGenerationRuns =
        database.userVersion >= AppDatabase.generationRunSchemaVersion;
    final includesProviderArtifacts =
        database.userVersion >= AppDatabase.orderedPartsSchemaVersion;
    if (includesMessageGraph) {
      requiredTables.addAll(const {
        'message_slot_rows',
        'message_revision_rows',
        'conversation_branch_rows',
        'conversation_state_rows',
      });
    }
    if (includesMessageParts) requiredTables.add('message_part_rows');
    if (includesMigrationLedger) {
      requiredTables.addAll(const {
        'migration_run_rows',
        'migration_issue_rows',
      });
    }
    if (includesGenerationRuns) requiredTables.add('generation_run_rows');
    if (includesProviderArtifacts) {
      requiredTables.add('provider_artifact_rows');
    }
    final tableRows = database.select(
      "SELECT name FROM sqlite_master WHERE type = 'table';",
    );
    final tables = tableRows
        .map((row) => row['name'])
        .whereType<String>()
        .toSet();
    if (!tables.containsAll(requiredTables)) {
      throw StateError('required_tables');
    }
    _validateRawSchema(
      database,
      includesMessageGraph: includesMessageGraph,
      includesMessageParts: includesMessageParts,
      includesMigrationLedger: includesMigrationLedger,
      includesGenerationRuns: includesGenerationRuns,
      includesProviderArtifacts: includesProviderArtifacts,
    );
  }

  static void _validateRawSchema(
    sqlite.Database database, {
    required bool includesMessageGraph,
    required bool includesMessageParts,
    required bool includesMigrationLedger,
    required bool includesGenerationRuns,
    required bool includesProviderArtifacts,
  }) {
    final expectedColumns = <String, List<String>>{
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
      ],
      'conversation_mcp_server_rows': [
        'conversation_id',
        'server_id',
        'ordinal',
      ],
      'message_rows': [
        'id',
        'conversation_id',
        'role',
        'content',
        'timestamp',
        'model_id',
        'provider_id',
        'total_tokens',
        'is_streaming',
        'reasoning_text',
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
      'tool_event_rows': ['message_id', 'events_json'],
      'gemini_thought_signature_rows': ['message_id', 'signature'],
      'chat_storage_meta_rows': ['key', 'value'],
    };
    if (includesMessageGraph) {
      expectedColumns.addAll(const {
        'message_slot_rows': ['id', 'conversation_id', 'role', 'created_at'],
        'message_revision_rows': [
          'id',
          'conversation_id',
          'slot_id',
          'parent_revision_id',
          'revision_no',
          'created_at',
          'updated_at',
          'finalized_at',
          'deleted_at',
        ],
        'conversation_branch_rows': [
          'id',
          'conversation_id',
          'parent_branch_id',
          'forked_from_revision_id',
          'leaf_revision_id',
          'causality_kind',
          'created_at',
          'deleted_at',
        ],
        'conversation_state_rows': [
          'conversation_id',
          'active_branch_id',
          'context_start_revision_id',
          'state_revision',
        ],
      });
    }
    if (includesMessageParts) {
      expectedColumns['message_part_rows'] = const [
        'conversation_id',
        'revision_id',
        'ordinal',
        'kind',
        'payload',
        'created_at',
        'updated_at',
      ];
    }
    if (includesMigrationLedger) {
      expectedColumns.addAll(const {
        'migration_run_rows': [
          'id',
          'source_kind',
          'source_hash',
          'status',
          'started_at',
          'completed_at',
        ],
        'migration_issue_rows': [
          'id',
          'migration_run_id',
          'conversation_id',
          'source_entity_id',
          'kind',
          'severity',
          'details_json',
          'created_at',
        ],
      });
    }
    if (includesGenerationRuns) {
      expectedColumns['generation_run_rows'] = const [
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
      ];
    }
    if (includesProviderArtifacts) {
      expectedColumns['provider_artifact_rows'] = const [
        'conversation_id',
        'revision_id',
        'kind',
        'payload',
        'created_at',
        'updated_at',
      ];
    }
    for (final entry in expectedColumns.entries) {
      final actual = database
          .select('PRAGMA table_info(${entry.key});')
          .map((row) => row['name'])
          .whereType<String>()
          .toList(growable: false);
      if (!_sameOrderedStrings(actual, entry.value)) {
        throw StateError('table_schema:${entry.key}');
      }
    }

    final expectedForeignKeys = <String, Set<String>>{
      'conversation_mcp_server_rows': {
        'conversation_id->conversation_rows.id:CASCADE',
      },
      'message_rows': {'conversation_id->conversation_rows.id:CASCADE'},
      'tool_event_rows': {'message_id->message_rows.id:CASCADE'},
      'gemini_thought_signature_rows': {'message_id->message_rows.id:CASCADE'},
    };
    if (includesMessageGraph) {
      expectedForeignKeys.addAll(const {
        'message_slot_rows': {'conversation_id->conversation_rows.id:CASCADE'},
        'message_revision_rows': {
          'conversation_id->conversation_rows.id:CASCADE',
          'conversation_id->message_slot_rows.conversation_id:NO ACTION',
          'slot_id->message_slot_rows.id:NO ACTION',
          'conversation_id->message_revision_rows.conversation_id:NO ACTION',
          'parent_revision_id->message_revision_rows.id:NO ACTION',
        },
        'conversation_branch_rows': {
          'conversation_id->conversation_rows.id:CASCADE',
          'conversation_id->conversation_branch_rows.conversation_id:NO ACTION',
          'parent_branch_id->conversation_branch_rows.id:NO ACTION',
          'conversation_id->message_revision_rows.conversation_id:NO ACTION',
          'forked_from_revision_id->message_revision_rows.id:NO ACTION',
          'leaf_revision_id->message_revision_rows.id:NO ACTION',
        },
        'conversation_state_rows': {
          'conversation_id->conversation_rows.id:CASCADE',
          'conversation_id->conversation_branch_rows.conversation_id:NO ACTION',
          'active_branch_id->conversation_branch_rows.id:NO ACTION',
          'conversation_id->message_revision_rows.conversation_id:NO ACTION',
          'context_start_revision_id->message_revision_rows.id:NO ACTION',
        },
      });
    }
    if (includesMessageParts) {
      expectedForeignKeys['message_part_rows'] = const {
        'conversation_id->message_revision_rows.conversation_id:CASCADE',
        'revision_id->message_revision_rows.id:CASCADE',
      };
    }
    if (includesMigrationLedger) {
      expectedForeignKeys['migration_issue_rows'] = const {
        'migration_run_id->migration_run_rows.id:CASCADE',
      };
    }
    if (includesGenerationRuns) {
      expectedForeignKeys['generation_run_rows'] = const {
        'conversation_id->conversation_rows.id:CASCADE',
        'conversation_id->message_revision_rows.conversation_id:NO ACTION',
        'target_revision_id->message_revision_rows.id:NO ACTION',
      };
    }
    if (includesProviderArtifacts) {
      expectedForeignKeys['provider_artifact_rows'] = const {
        'conversation_id->message_revision_rows.conversation_id:CASCADE',
        'revision_id->message_revision_rows.id:CASCADE',
      };
    }
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

  static Future<void> _deleteDatabaseFamily(File databaseFile) async {
    for (final suffix in const ['', '-wal', '-shm', '-journal']) {
      final file = File('${databaseFile.path}$suffix');
      if (await file.exists()) {
        await file.delete();
      }
    }
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

  Future<ActiveMessageGraphProjection?> projectActiveMessageGraph({
    required String conversationId,
    String? targetRevisionId,
  }) {
    return _observer.measure(
      ChatDatabaseOperation.queryMessageGraphPath,
      () => MessageGraphProjector(_db).projectActivePath(
        conversationId: conversationId,
        targetRevisionId: targetRevisionId,
      ),
      resultCount: (projection) => projection?.revisions.length ?? 0,
    );
  }

  Future<MessageGraphTimelineProjection?> projectMessageGraphTimeline({
    required String conversationId,
  }) {
    return _observer.measure(
      ChatDatabaseOperation.queryMessageGraphPath,
      () => MessageGraphProjector(
        _db,
      ).projectTimeline(conversationId: conversationId),
      resultCount: (projection) => projection?.activeRevisions.length ?? 0,
    );
  }

  Future<ActiveTimelinePage?> loadActiveTimelinePage({
    required String conversationId,
    String? beforeRevisionId,
    String? afterRevisionId,
    String? aroundRevisionId,
    bool fromStart = false,
    int limit = 40,
  }) => _observer.measure(
    ChatDatabaseOperation.queryMessageRange,
    () => MessageGraphProjector(_db).projectActiveTimelinePage(
      conversationId: conversationId,
      beforeRevisionId: beforeRevisionId,
      afterRevisionId: afterRevisionId,
      aroundRevisionId: aroundRevisionId,
      fromStart: fromStart,
      limit: limit,
    ),
    resultCount: (page) => page?.slots.length ?? 0,
  );

  Future<MessageGraphPath> projectMessageGraphBranch({
    required String conversationId,
    required String branchId,
    String? targetRevisionId,
  }) {
    return _observer.measure(
      ChatDatabaseOperation.queryMessageGraphPath,
      () => MessageGraphProjector(_db).projectBranchPath(
        conversationId: conversationId,
        branchId: branchId,
        targetRevisionId: targetRevisionId,
      ),
      resultCount: (path) => path.revisions.length,
    );
  }

  Future<MessageGraphValidationResult> validateMessageGraph(
    String conversationId,
  ) {
    return _observer.measure(
      ChatDatabaseOperation.queryMessageGraphPath,
      () =>
          MessageGraphProjector(_db).validateConversationGraph(conversationId),
      resultCount: (result) => result.pathRevisionCount,
    );
  }

  Future<ActiveMessageGraphProjection?> setMessageGraphContextBoundary({
    required String conversationId,
    required String? revisionId,
    int? expectedStateRevision,
  }) {
    return _observer.measure(
      ChatDatabaseOperation.commandSetContextBoundary,
      () => _setMessageGraphContextBoundary(
        conversationId: conversationId,
        revisionId: revisionId,
        expectedStateRevision: expectedStateRevision,
      ),
      resultCount: (projection) => projection?.contextRevisions.length ?? 0,
    );
  }

  Future<ActiveMessageGraphProjection?> _setMessageGraphContextBoundary({
    required String conversationId,
    required String? revisionId,
    int? expectedStateRevision,
  }) {
    return _db.transaction(() async {
      final projector = MessageGraphProjector(_db);
      final current = await projector.projectActivePath(
        conversationId: conversationId,
      );
      if (current == null) return null;
      if (expectedStateRevision != null &&
          current.stateRevision != expectedStateRevision) {
        throw StateError('message_graph_state_conflict');
      }
      if (revisionId != null &&
          !current.revisions.any((revision) => revision.id == revisionId)) {
        throw ArgumentError.value(
          revisionId,
          'revisionId',
          'must identify a revision on the active path',
        );
      }
      if (current.contextStartRevisionId == revisionId) return current;

      final updated =
          await (_db.update(_db.conversationStateRows)..where(
                (row) =>
                    row.conversationId.equals(conversationId) &
                    row.stateRevision.equals(current.stateRevision),
              ))
              .write(
                ConversationStateRowsCompanion(
                  contextStartRevisionId: Value(revisionId),
                  stateRevision: Value(current.stateRevision + 1),
                ),
              );
      if (updated != 1) throw StateError('message_graph_state_conflict');
      return projector.projectActivePath(conversationId: conversationId);
    });
  }

  Future<MessageGraphMutationResult> editMessageGraphUser({
    required String conversationId,
    required String targetRevisionId,
    required String text,
    int? expectedStateRevision,
  }) => _observer.measure(
    ChatDatabaseOperation.commandMessageGraphMutation,
    () => MessageGraphCommands(_db).graftRevision(
      conversationId: conversationId,
      targetRevisionId: targetRevisionId,
      text: text,
      mutation: MessageGraphRevisionMutation.editUser,
      expectedStateRevision: expectedStateRevision,
    ),
  );

  Future<MessageGraphMutationResult> regenerateMessageGraphAssistant({
    required String conversationId,
    required String targetRevisionId,
    int? expectedStateRevision,
  }) => _observer.measure(
    ChatDatabaseOperation.commandMessageGraphMutation,
    () => MessageGraphCommands(_db).createRevisionBranch(
      conversationId: conversationId,
      targetRevisionId: targetRevisionId,
      text: '',
      mutation: MessageGraphRevisionMutation.regenerateAssistant,
      expectedStateRevision: expectedStateRevision,
    ),
  );

  Future<ActiveMessageGraphProjection> selectMessageGraphRevision({
    required String conversationId,
    required String revisionId,
    int? expectedStateRevision,
  }) => _observer.measure(
    ChatDatabaseOperation.commandMessageGraphMutation,
    () => MessageGraphCommands(_db).selectRevision(
      conversationId: conversationId,
      revisionId: revisionId,
      expectedStateRevision: expectedStateRevision,
    ),
  );

  Future<MessageGraphDeleteResult> deleteMessageGraphRevision({
    required String conversationId,
    required String revisionId,
    required bool confirmCascade,
    int? expectedStateRevision,
  }) => _observer.measure(
    ChatDatabaseOperation.commandMessageGraphMutation,
    () => MessageGraphCommands(_db).deleteRevision(
      conversationId: conversationId,
      revisionId: revisionId,
      confirmCascade: confirmCascade,
      expectedStateRevision: expectedStateRevision,
    ),
  );

  Future<MessageGraphForkResult> forkMessageGraphConversation({
    required String sourceConversationId,
    required String sourceBranchId,
    required String sourceRevisionId,
    required String targetConversationId,
    required String title,
  }) => _observer.measure(
    ChatDatabaseOperation.commandMessageGraphMutation,
    () => MessageGraphCommands(_db).forkConversation(
      sourceConversationId: sourceConversationId,
      sourceBranchId: sourceBranchId,
      sourceRevisionId: sourceRevisionId,
      targetConversationId: targetConversationId,
      title: title,
    ),
  );

  Future<MessageGraphForkResult> forkMessageGraphConversationWithShadow({
    required String sourceConversationId,
    required String sourceBranchId,
    required String sourceRevisionId,
    required String targetConversationId,
    required String title,
  }) {
    return _observer.measure(
      ChatDatabaseOperation.commandMessageGraphMutation,
      () => _db.transaction(() async {
        final sourcePath = await MessageGraphProjector(_db).projectBranchPath(
          conversationId: sourceConversationId,
          branchId: sourceBranchId,
          targetRevisionId: sourceRevisionId,
        );
        final result = await MessageGraphCommands(_db).forkConversation(
          sourceConversationId: sourceConversationId,
          sourceBranchId: sourceBranchId,
          sourceRevisionId: sourceRevisionId,
          targetConversationId: targetConversationId,
          title: title,
        );
        final sourceIds = sourcePath.revisions
            .map((revision) => revision.id)
            .toList(growable: false);
        final sourceRows = await (_db.select(
          _db.messageRows,
        )..where((row) => row.id.isIn(sourceIds))).get();
        final byId = {for (final row in sourceRows) row.id: row};
        for (final (index, sourceRevision) in sourcePath.revisions.indexed) {
          final sourceRow = byId[sourceRevision.id];
          if (sourceRow == null) continue;
          final targetRevisionId = result.revisionIds[sourceRevision.id]!;
          final source = _messageFromRow(sourceRow);
          final clone = ChatMessage(
            id: targetRevisionId,
            role: source.role,
            content: source.content,
            timestamp: source.timestamp,
            modelId: source.modelId,
            providerId: source.providerId,
            totalTokens: source.totalTokens,
            conversationId: targetConversationId,
            isStreaming: false,
            reasoningText: source.reasoningText,
            reasoningStartAt: source.reasoningStartAt,
            reasoningFinishedAt: source.reasoningFinishedAt,
            translation: source.translation,
            reasoningSegmentsJson: source.reasoningSegmentsJson,
            groupId: targetRevisionId,
            version: 0,
            promptTokens: source.promptTokens,
            completionTokens: source.completionTokens,
            cachedTokens: source.cachedTokens,
            durationMs: source.durationMs,
          );
          await _db
              .into(_db.messageRows)
              .insert(_messageCompanion(clone, index), mode: InsertMode.insert);
        }
        return result;
      }),
    );
  }

  Future<void> beginLegacyGraphMigration({
    required String migrationRunId,
    required String sourceKind,
    required String sourceHash,
    required DateTime startedAt,
  }) => _db
      .into(_db.migrationRunRows)
      .insert(
        MigrationRunRowsCompanion.insert(
          id: migrationRunId,
          sourceKind: sourceKind,
          sourceHash: sourceHash,
          status: 'building',
          startedAt: startedAt,
        ),
        mode: InsertMode.insertOrIgnore,
      );

  /// Converts one already-copied legacy conversation into the authoritative
  /// graph representation. Memory is bounded to one conversation, never the
  /// complete Hive store.
  Future<ActiveMessageGraphProjection> migrateStoredLegacyConversationGraph({
    required String migrationRunId,
    required String conversationId,
  }) async {
    final conversationRow = await (_db.select(
      _db.conversationRows,
    )..where((row) => row.id.equals(conversationId))).getSingleOrNull();
    if (conversationRow == null) {
      throw StateError('legacy_graph_conversation_missing');
    }
    final conversation = await _conversationFromRow(conversationRow);
    final messageRows =
        await (_db.select(_db.messageRows)
              ..where((row) => row.conversationId.equals(conversationId))
              ..orderBy([
                (row) => OrderingTerm.asc(row.messageOrder),
                (row) => OrderingTerm.asc(row.id),
              ]))
            .get();
    final graph = const LegacyMessageGraphAdapter().adapt(
      conversation: conversation,
      messages: [
        for (final row in messageRows)
          LegacyOrderedMessage(
            message: _messageFromRow(row),
            order: row.messageOrder,
          ),
      ],
    );
    return putLegacyMessageGraph(migrationRunId: migrationRunId, graph: graph);
  }

  /// Best-effort bridge for development SQLite v1 databases and legacy JSON
  /// imports. Released installations enter through the Hive migration above.
  Future<int> backfillMissingMessageGraphs() async {
    final conversations = await _db.select(_db.conversationRows).get();
    final states = await _db.select(_db.conversationStateRows).get();
    final existing = states.map((state) => state.conversationId).toSet();
    final missing = conversations
        .where((conversation) => !existing.contains(conversation.id))
        .map((conversation) => conversation.id)
        .toList(growable: false);
    if (missing.isEmpty) return 0;

    const runId = 'sqlite-v1-development-backfill-v1';
    await beginLegacyGraphMigration(
      migrationRunId: runId,
      sourceKind: 'sqlite_v1',
      sourceHash: 'development-sqlite-v1-best-effort-v1',
      startedAt: DateTime.fromMicrosecondsSinceEpoch(0, isUtc: true),
    );
    for (final conversationId in missing) {
      await migrateStoredLegacyConversationGraph(
        migrationRunId: runId,
        conversationId: conversationId,
      );
    }
    await completeLegacyGraphMigration(
      migrationRunId: runId,
      completedAt: DateTime.now().toUtc(),
    );
    return missing.length;
  }

  Future<ActiveMessageGraphProjection> putLegacyMessageGraph({
    required String migrationRunId,
    required LegacyMessageGraphProjection graph,
  }) {
    return _db.transaction(() async {
      final conversation = await (_db.select(
        _db.conversationRows,
      )..where((row) => row.id.equals(graph.conversationId))).getSingleOrNull();
      if (conversation == null) {
        throw StateError('legacy_graph_conversation_missing');
      }
      await (_db.delete(_db.migrationIssueRows)..where(
            (row) =>
                row.migrationRunId.equals(migrationRunId) &
                row.conversationId.equals(graph.conversationId),
          ))
          .go();
      await (_db.delete(
        _db.conversationStateRows,
      )..where((row) => row.conversationId.equals(graph.conversationId))).go();
      await (_db.delete(
        _db.conversationBranchRows,
      )..where((row) => row.conversationId.equals(graph.conversationId))).go();
      await (_db.delete(
        _db.messageRevisionRows,
      )..where((row) => row.conversationId.equals(graph.conversationId))).go();
      await (_db.delete(
        _db.messageSlotRows,
      )..where((row) => row.conversationId.equals(graph.conversationId))).go();

      for (final slot in graph.slots) {
        await _db
            .into(_db.messageSlotRows)
            .insert(
              MessageSlotRowsCompanion.insert(
                id: slot.id,
                conversationId: graph.conversationId,
                role: slot.role,
                createdAt: slot.createdAt,
              ),
            );
        for (final revision in slot.revisions) {
          await _db
              .into(_db.messageRevisionRows)
              .insert(
                MessageRevisionRowsCompanion.insert(
                  id: revision.id,
                  conversationId: graph.conversationId,
                  slotId: slot.id,
                  parentRevisionId: Value(revision.parentRevisionId),
                  revisionNo: revision.revisionNo,
                  createdAt: revision.createdAt,
                  updatedAt: revision.updatedAt,
                  finalizedAt: Value(revision.finalizedAt),
                ),
              );
          for (final part in revision.parts) {
            await _db
                .into(_db.messagePartRows)
                .insert(
                  MessagePartRowsCompanion.insert(
                    conversationId: graph.conversationId,
                    revisionId: revision.id,
                    ordinal: part.ordinal,
                    kind: part.kind,
                    payload: part.payload,
                    createdAt: revision.createdAt,
                    updatedAt: revision.updatedAt,
                  ),
                );
          }
        }
      }
      await _db
          .into(_db.conversationBranchRows)
          .insert(
            ConversationBranchRowsCompanion.insert(
              id: graph.branchId,
              conversationId: graph.conversationId,
              leafRevisionId: Value(
                graph.activeRevisionIds.isEmpty
                    ? null
                    : graph.activeRevisionIds.last,
              ),
              causalityKind: graph.causalityKind,
              createdAt: conversation.updatedAt,
            ),
          );
      await _db
          .into(_db.conversationStateRows)
          .insert(
            ConversationStateRowsCompanion.insert(
              conversationId: graph.conversationId,
              activeBranchId: Value(graph.branchId),
              contextStartRevisionId: Value(graph.contextStartRevisionId),
            ),
          );
      for (final (index, issue) in graph.issues.indexed) {
        final details = jsonEncode(issue.details);
        final issueId = _deterministicMergeId(
          'migration_issue',
          '$migrationRunId:${graph.conversationId}:$index:${issue.kind}',
          sha256.convert(utf8.encode(details)).toString(),
        );
        await _db
            .into(_db.migrationIssueRows)
            .insert(
              MigrationIssueRowsCompanion.insert(
                id: issueId,
                migrationRunId: migrationRunId,
                conversationId: Value(graph.conversationId),
                sourceEntityId: Value(issue.sourceEntityId),
                kind: issue.kind,
                severity: issue.severity,
                detailsJson: Value(details),
                createdAt: conversation.updatedAt,
              ),
              mode: InsertMode.insertOrReplace,
            );
      }
      return (await MessageGraphProjector(
        _db,
      ).projectActivePath(conversationId: graph.conversationId))!;
    });
  }

  Future<void> completeLegacyGraphMigration({
    required String migrationRunId,
    required DateTime completedAt,
  }) async {
    final updated =
        await (_db.update(
          _db.migrationRunRows,
        )..where((row) => row.id.equals(migrationRunId))).write(
          MigrationRunRowsCompanion(
            status: const Value('completed'),
            completedAt: Value(completedAt),
          ),
        );
    if (updated != 1) throw StateError('migration_run_missing');
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
      if (contract.synchronous != AppDatabase.synchronousFull) {
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
    required String Function(String content) rewriteContent,
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
        );
      }

      var scanned = 0;
      var updated = 0;
      var cursor = '';
      while (true) {
        final rows = await _db
            .customSelect(
              'SELECT id, content FROM message_rows '
              'WHERE id > ? AND (content LIKE ? OR content LIKE ?) '
              'ORDER BY id LIMIT ?;',
              variables: [
                Variable<String>(cursor),
                const Variable<String>('%[image:%'),
                const Variable<String>('%[file:%'),
                Variable<int>(batchSize),
              ],
            )
            .get();
        if (rows.isEmpty) break;
        for (final row in rows) {
          final id = row.read<String>('id');
          final content = row.read<String>('content');
          final rewritten = rewriteContent(content);
          scanned += 1;
          if (rewritten != content) {
            await _db.customStatement(
              'UPDATE message_rows SET content = ? WHERE id = ?;',
              [rewritten, id],
            );
            updated += 1;
          }
          cursor = id;
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
      );
    });
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
        final out = <Conversation>[];
        for (final row in rows) {
          out.add(await _conversationFromRow(row, includeMessageIds: false));
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

  Future<void> updateMessageOrder(
    String conversationId,
    List<String> messageIds,
  ) async {
    await _db.transaction(() async {
      await _rewriteMessageOrder(conversationId, messageIds);
    });
  }

  Future<List<ConversationSearchMatch>> searchConversationMatches({
    required List<String> tokens,
    int limit = 200,
    int candidateMultiplier = 8,
    bool includeAllRevisions = false,
  }) {
    return _observer.measure(
      ChatDatabaseOperation.querySearch,
      () => _searchConversationMatches(
        tokens: tokens,
        limit: limit,
        candidateMultiplier: candidateMultiplier,
        includeAllRevisions: includeAllRevisions,
      ),
      resultCount: (rows) => rows.length,
    );
  }

  Future<List<ConversationSearchMatch>> _searchConversationMatches({
    required List<String> tokens,
    required int limit,
    required int candidateMultiplier,
    required bool includeAllRevisions,
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
            AND LOWER(mx.content) LIKE ? ESCAPE '\\'
        )
        ''');
      existsArgs.add(pattern);
      if (useSubstringFallback) {
        messageAnyClauses.add('LOWER(m.content) LIKE ? ESCAPE \'\\\'');
        messageArgs.add(pattern);
      }
    }
    final ftsQuery = cleanTokens
        .map((token) => '"${token.replaceAll('"', '""')}"')
        .join(' AND ');
    if (!useSubstringFallback) {
      messageAnyClauses.add(
        'm.id IN (SELECT revision_id FROM message_search_fts '
        'WHERE body MATCH ?)',
      );
      messageArgs.add(ftsQuery);
      existsClauses
        ..clear()
        ..add('''
        EXISTS (
          SELECT 1 FROM message_search_fts fx
          WHERE fx.conversation_id = c.id AND fx.body MATCH ?
        )
        ''');
      existsArgs
        ..clear()
        ..add(ftsQuery);
    }

    final candidateLimit = (limit * candidateMultiplier)
        .clamp(limit, 2000)
        .toInt();
    final rows = await _db
        .customSelect(
          '''
      WITH RECURSIVE active_revisions(conversation_id, revision_id, parent_revision_id) AS (
        SELECT s.conversation_id, b.leaf_revision_id, r.parent_revision_id
        FROM conversation_state_rows s
        INNER JOIN conversation_branch_rows b
          ON b.conversation_id = s.conversation_id
         AND b.id = s.active_branch_id
        INNER JOIN message_revision_rows r
          ON r.conversation_id = b.conversation_id
         AND r.id = b.leaf_revision_id
        UNION
        SELECT parent.conversation_id, parent.id, parent.parent_revision_id
        FROM message_revision_rows parent
        INNER JOIN active_revisions child
          ON child.conversation_id = parent.conversation_id
         AND child.parent_revision_id = parent.id
      )
      SELECT
        c.id AS conversation_id,
        c.title AS conversation_title,
        c.updated_at AS updated_at,
        m.id AS message_id,
        m.content AS message_content,
        m.role AS message_role,
        m.group_id AS group_id,
        m.version AS version,
        m.message_order AS message_order,
        (
          SELECT selected.version
          FROM active_revisions ar
          INNER JOIN message_rows selected
            ON selected.conversation_id = ar.conversation_id
           AND selected.id = ar.revision_id
          WHERE ar.conversation_id = m.conversation_id
            AND COALESCE(selected.group_id, selected.id) =
                COALESCE(m.group_id, m.id)
          LIMIT 1
        ) AS selected_version,
        (
          SELECT MAX(vm.version)
          FROM message_rows vm
          WHERE vm.conversation_id = m.conversation_id
            AND COALESCE(vm.group_id, vm.id) = COALESCE(m.group_id, m.id)
        ) AS max_version
      FROM conversation_rows c
      LEFT JOIN message_rows m
        ON m.conversation_id = c.id
        AND m.role IN ('user', 'assistant')
        AND (${messageAnyClauses.join(' OR ')})
        ${includeAllRevisions ? '' : 'AND EXISTS (SELECT 1 FROM active_revisions visible WHERE visible.conversation_id = m.conversation_id AND visible.revision_id = m.id)'}
      WHERE (${titleClauses.join(' AND ')}) OR (${existsClauses.join(' AND ')})
      ORDER BY c.updated_at DESC, m.message_order ASC
      LIMIT ?
      ''',
          variables: [
            ...messageArgs.map((value) => Variable<String>(value! as String)),
            ...titleArgs.map((value) => Variable<String>(value! as String)),
            ...existsArgs.map((value) => Variable<String>(value! as String)),
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

  bool _requiresCjkFallback(String token) {
    return RegExp(
      r'[\u3400-\u9fff\uf900-\ufaff\u3040-\u30ff\uac00-\ud7af]',
    ).hasMatch(token);
  }

  Future<void> _ensureMessageSearchFts() async {
    await _db.customStatement('''
      CREATE VIRTUAL TABLE IF NOT EXISTS message_search_fts USING fts5(
        revision_id UNINDEXED,
        conversation_id UNINDEXED,
        body,
        tokenize = 'unicode61 remove_diacritics 2'
      );
    ''');
    await _db.customStatement('''
      CREATE TRIGGER IF NOT EXISTS message_search_fts_insert
      AFTER INSERT ON message_rows BEGIN
        INSERT INTO message_search_fts(revision_id, conversation_id, body)
        VALUES (new.id, new.conversation_id, new.content);
      END;
    ''');
    await _db.customStatement('''
      CREATE TRIGGER IF NOT EXISTS message_search_fts_delete
      AFTER DELETE ON message_rows BEGIN
        DELETE FROM message_search_fts WHERE revision_id = old.id;
      END;
    ''');
    await _db.customStatement('''
      CREATE TRIGGER IF NOT EXISTS message_search_fts_update
      AFTER UPDATE OF content, conversation_id ON message_rows BEGIN
        DELETE FROM message_search_fts WHERE revision_id = old.id;
        INSERT INTO message_search_fts(revision_id, conversation_id, body)
        VALUES (new.id, new.conversation_id, new.content);
      END;
    ''');
    final counts = await _db.customSelect('''
      SELECT
        (SELECT COUNT(*) FROM message_rows) AS source_count,
        (SELECT COUNT(*) FROM message_search_fts) AS fts_count;
    ''').getSingle();
    if (counts.read<int>('source_count') != counts.read<int>('fts_count')) {
      await _db.transaction(() async {
        await _db.customStatement('DELETE FROM message_search_fts;');
        await _db.customStatement('''
          INSERT INTO message_search_fts(revision_id, conversation_id, body)
          SELECT id, conversation_id, content FROM message_rows;
        ''');
      });
    }
  }

  Future<void> putConversation(Conversation conversation) async {
    await _db.transaction(() async {
      await _db
          .into(_db.conversationRows)
          .insertOnConflictUpdate(_conversationCompanion(conversation));
      await _replaceMcpServers(conversation.id, conversation.mcpServerIds);
    });
  }

  Future<void> putMessage(ChatMessage message, {int? messageOrder}) async {
    final order =
        messageOrder ?? await _nextMessageOrder(message.conversationId);
    await _db.transaction(() async {
      await _db
          .into(_db.messageRows)
          .insertOnConflictUpdate(_messageCompanion(message, order));
      await _updateGraphRevisionPayload(message);
    });
  }

  Future<Conversation> appendMessageToConversation({
    required Conversation conversation,
    required ChatMessage message,
    bool selectVersion = false,
    bool touchUpdatedAt = true,
  }) {
    return _observer.measure(
      ChatDatabaseOperation.commandAppendMessage,
      () => _appendMessageToConversation(
        conversation: conversation,
        message: message,
        selectVersion: selectVersion,
        touchUpdatedAt: touchUpdatedAt,
      ),
    );
  }

  Future<Conversation> appendGraphMessageToConversation({
    required Conversation conversation,
    required ChatMessage message,
    bool selectVersion = false,
    bool touchUpdatedAt = true,
  }) {
    return _observer.measure(
      ChatDatabaseOperation.commandAppendMessage,
      () => _appendGraphMessageToConversation(
        conversation: conversation,
        message: message,
        selectVersion: selectVersion,
        graftSelectedVersion: false,
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
        final afterUser = await _appendGraphMessageToConversation(
          conversation: conversation,
          message: userMessage,
          selectVersion: false,
          graftSelectedVersion: false,
          touchUpdatedAt: true,
        );
        final persisted = await _appendGraphMessageToConversation(
          conversation: afterUser,
          message: assistantMessage,
          selectVersion: false,
          graftSelectedVersion: false,
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
        final persisted = await _appendGraphMessageToConversation(
          conversation: conversation,
          message: assistantMessage,
          selectVersion: true,
          graftSelectedVersion: !truncateFuture,
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

  Future<Conversation> _appendGraphMessageToConversation({
    required Conversation conversation,
    required ChatMessage message,
    required bool selectVersion,
    required bool graftSelectedVersion,
    required bool touchUpdatedAt,
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
      final persisted = current.copyWith(
        updatedAt: touchUpdatedAt ? DateTime.now() : current.updatedAt,
      );
      await _db
          .into(_db.conversationRows)
          .insertOnConflictUpdate(_conversationCompanion(persisted));
      if (existingRow == null) {
        await _replaceMcpServers(persisted.id, persisted.mcpServerIds);
      }

      var state =
          await (_db.select(_db.conversationStateRows)
                ..where((row) => row.conversationId.equals(conversation.id)))
              .getSingleOrNull();
      if (state == null) {
        final existingMessageCount = _db.messageRows.id.count();
        final countRow =
            await (_db.selectOnly(_db.messageRows)
                  ..addColumns([existingMessageCount])
                  ..where(
                    _db.messageRows.conversationId.equals(conversation.id),
                  ))
                .getSingle();
        if ((countRow.read(existingMessageCount) ?? 0) != 0) {
          throw StateError('message_graph_backfill_required');
        }
        final branchId = _deterministicMergeId(
          'graph_branch',
          conversation.id,
          'native-main',
        );
        await _db
            .into(_db.conversationBranchRows)
            .insert(
              ConversationBranchRowsCompanion.insert(
                id: branchId,
                conversationId: conversation.id,
                causalityKind: 'native',
                createdAt: message.timestamp,
              ),
            );
        await _db
            .into(_db.conversationStateRows)
            .insert(
              ConversationStateRowsCompanion.insert(
                conversationId: conversation.id,
                activeBranchId: Value(branchId),
              ),
            );
        state =
            await (_db.select(_db.conversationStateRows)
                  ..where((row) => row.conversationId.equals(conversation.id)))
                .getSingle();
      }

      final order = await _nextMessageOrder(persisted.id);
      await _db
          .into(_db.messageRows)
          .insert(_messageCompanion(message, order), mode: InsertMode.insert);
      final projector = MessageGraphProjector(_db);
      final active = (await projector.projectActivePath(
        conversationId: conversation.id,
      ))!;
      final activeBranchId = active.branchId!;

      if (selectVersion && message.groupId != null) {
        final activeIds = active.revisions
            .map((revision) => revision.id)
            .toList(growable: false);
        final rows = activeIds.isEmpty
            ? const <MessageRow>[]
            : await (_db.select(_db.messageRows)..where(
                    (row) =>
                        row.conversationId.equals(conversation.id) &
                        row.id.isIn(activeIds),
                  ))
                  .get();
        final byId = {for (final row in rows) row.id: row};
        MessageGraphRevision? target;
        for (final revision in active.revisions.reversed) {
          final row = byId[revision.id];
          if (row != null && (row.groupId ?? row.id) == message.groupId) {
            target = revision;
            break;
          }
        }
        if (target == null) {
          throw StateError('message_graph_revision_group_missing');
        }
        final commands = MessageGraphCommands(_db);
        if (graftSelectedVersion) {
          await commands.graftRevision(
            conversationId: conversation.id,
            targetRevisionId: target.id,
            text: message.content,
            mutation: MessageGraphRevisionMutation.regenerateAssistant,
            expectedStateRevision: active.stateRevision,
            revisionId: message.id,
          );
        } else {
          await commands.createRevisionBranch(
            conversationId: conversation.id,
            targetRevisionId: target.id,
            text: message.content,
            mutation: MessageGraphRevisionMutation.regenerateAssistant,
            expectedStateRevision: active.stateRevision,
            revisionId: message.id,
            branchId: _deterministicMergeId(
              'graph_branch',
              conversation.id,
              message.id,
            ),
          );
        }
      } else {
        final slotId = _deterministicMergeId(
          'graph_slot',
          conversation.id,
          message.id,
        );
        await _db
            .into(_db.messageSlotRows)
            .insert(
              MessageSlotRowsCompanion.insert(
                id: slotId,
                conversationId: conversation.id,
                role: message.role,
                createdAt: message.timestamp,
              ),
            );
        await _insertGraphRevision(
          message: message,
          slotId: slotId,
          parentRevisionId: active.branchLeafRevisionId,
          requestedRevisionNo: 0,
        );
        await (_db.update(_db.conversationBranchRows)..where(
              (row) =>
                  row.conversationId.equals(conversation.id) &
                  row.id.equals(activeBranchId),
            ))
            .write(
              ConversationBranchRowsCompanion(
                leafRevisionId: Value(message.id),
              ),
            );
        await (_db.update(
          _db.conversationStateRows,
        )..where((row) => row.conversationId.equals(conversation.id))).write(
          ConversationStateRowsCompanion(
            stateRevision: Value(state.stateRevision + 1),
          ),
        );
      }
      return persisted;
    });
  }

  Future<void> _insertGraphRevision({
    required ChatMessage message,
    required String slotId,
    required String? parentRevisionId,
    required int requestedRevisionNo,
  }) async {
    final maxRevision = _db.messageRevisionRows.revisionNo.max();
    final row =
        await (_db.selectOnly(_db.messageRevisionRows)
              ..addColumns([maxRevision])
              ..where(
                _db.messageRevisionRows.conversationId.equals(
                      message.conversationId,
                    ) &
                    _db.messageRevisionRows.slotId.equals(slotId),
              ))
            .getSingle();
    final maximum = row.read(maxRevision);
    final revisionNo = maximum != null && requestedRevisionNo <= maximum
        ? maximum + 1
        : requestedRevisionNo;
    await _db
        .into(_db.messageRevisionRows)
        .insert(
          MessageRevisionRowsCompanion.insert(
            id: message.id,
            conversationId: message.conversationId,
            slotId: slotId,
            parentRevisionId: Value(parentRevisionId),
            revisionNo: revisionNo,
            createdAt: message.timestamp,
            updatedAt: message.timestamp,
            finalizedAt: message.isStreaming
                ? const Value.absent()
                : Value(message.timestamp),
          ),
        );
    await _replaceGraphParts(message);
  }

  Future<void> _replaceGraphParts(
    ChatMessage message, {
    List<Map<String, dynamic>>? toolEvents,
  }) async {
    final preservedToolEvents = toolEvents ?? await getToolEvents(message.id);
    await (_db.delete(
      _db.messagePartRows,
    )..where((row) => row.revisionId.equals(message.id))).go();
    var ordinal = 0;
    final now = DateTime.now().toUtc();
    final updatedAt = now.isBefore(message.timestamp) ? message.timestamp : now;
    final reasoning = message.reasoningText;
    if (reasoning != null && reasoning.isNotEmpty) {
      await _db
          .into(_db.messagePartRows)
          .insert(
            MessagePartRowsCompanion.insert(
              conversationId: message.conversationId,
              revisionId: message.id,
              ordinal: ordinal++,
              kind: 'reasoning',
              payload: reasoning,
              createdAt: message.timestamp,
              updatedAt: updatedAt,
            ),
          );
    }
    for (final event in preservedToolEvents) {
      await _db
          .into(_db.messagePartRows)
          .insert(
            MessagePartRowsCompanion.insert(
              conversationId: message.conversationId,
              revisionId: message.id,
              ordinal: ordinal++,
              kind: 'tool_call',
              payload: jsonEncode(event),
              createdAt: message.timestamp,
              updatedAt: updatedAt,
            ),
          );
      if (event['content'] != null) {
        await _db
            .into(_db.messagePartRows)
            .insert(
              MessagePartRowsCompanion.insert(
                conversationId: message.conversationId,
                revisionId: message.id,
                ordinal: ordinal++,
                kind: 'tool_result',
                payload: jsonEncode({
                  if (event['id'] != null) 'id': event['id'],
                  'content': event['content'],
                }),
                createdAt: message.timestamp,
                updatedAt: updatedAt,
              ),
            );
      }
    }
    await _db
        .into(_db.messagePartRows)
        .insert(
          MessagePartRowsCompanion.insert(
            conversationId: message.conversationId,
            revisionId: message.id,
            ordinal: ordinal,
            kind: 'text',
            payload: message.content,
            createdAt: message.timestamp,
            updatedAt: updatedAt,
          ),
        );
  }

  Future<Conversation> _appendMessageToConversation({
    required Conversation conversation,
    required ChatMessage message,
    required bool selectVersion,
    required bool touchUpdatedAt,
  }) async {
    if (message.conversationId != conversation.id) {
      throw ArgumentError.value(
        message.conversationId,
        'message.conversationId',
        'Message and conversation IDs must match.',
      );
    }
    late final Conversation persisted;
    await _db.transaction(() async {
      final existingRow = await (_db.select(
        _db.conversationRows,
      )..where((row) => row.id.equals(conversation.id))).getSingleOrNull();
      final current = existingRow == null
          ? conversation
          : await _conversationFromRow(existingRow);
      final selections = Map<String, int>.from(current.versionSelections);
      if (selectVersion) {
        selections[message.groupId ?? message.id] = message.version;
      }
      persisted = current.copyWith(
        messageIds: [...current.messageIds, message.id],
        versionSelections: selections,
        updatedAt: touchUpdatedAt ? DateTime.now() : current.updatedAt,
      );
      await _db
          .into(_db.conversationRows)
          .insertOnConflictUpdate(_conversationCompanion(persisted));
      if (existingRow == null) {
        await _replaceMcpServers(persisted.id, persisted.mcpServerIds);
      }
      final order = await _nextMessageOrder(persisted.id);
      await _db
          .into(_db.messageRows)
          .insert(_messageCompanion(message, order), mode: InsertMode.insert);
    });
    return persisted;
  }

  Future<void> createConversationWithMessages({
    required Conversation conversation,
    required List<ChatMessage> messages,
  }) {
    return _observer.measure(
      ChatDatabaseOperation.commandCreateConversation,
      () => _createConversationWithMessages(
        conversation: conversation,
        messages: messages,
      ),
    );
  }

  Future<void> createGraphConversationWithMessages({
    required Conversation conversation,
    required List<ChatMessage> messages,
  }) async {
    for (final message in messages) {
      if (message.conversationId != conversation.id) {
        throw ArgumentError.value(
          message.conversationId,
          'messages',
          'Every message must belong to the new conversation.',
        );
      }
    }
    await _db.transaction(() async {
      final persisted = conversation.copyWith(
        messageIds: const [],
        versionSelections: const {},
        truncateIndex: -1,
      );
      await _db
          .into(_db.conversationRows)
          .insert(_conversationCompanion(persisted), mode: InsertMode.insert);
      await _replaceMcpServers(persisted.id, persisted.mcpServerIds);
      final branchId = _deterministicMergeId(
        'graph_branch',
        persisted.id,
        'native-main',
      );
      await _db
          .into(_db.conversationBranchRows)
          .insert(
            ConversationBranchRowsCompanion.insert(
              id: branchId,
              conversationId: persisted.id,
              causalityKind: 'native',
              createdAt: persisted.createdAt,
            ),
          );
      String? parentRevisionId;
      for (final (index, message) in messages.indexed) {
        await _db
            .into(_db.messageRows)
            .insert(_messageCompanion(message, index), mode: InsertMode.insert);
        final slotId = _deterministicMergeId(
          'graph_slot',
          persisted.id,
          message.id,
        );
        await _db
            .into(_db.messageSlotRows)
            .insert(
              MessageSlotRowsCompanion.insert(
                id: slotId,
                conversationId: persisted.id,
                role: message.role,
                createdAt: message.timestamp,
              ),
            );
        await _insertGraphRevision(
          message: message,
          slotId: slotId,
          parentRevisionId: parentRevisionId,
          requestedRevisionNo: 0,
        );
        parentRevisionId = message.id;
      }
      await (_db.update(_db.conversationBranchRows)..where(
            (row) =>
                row.conversationId.equals(persisted.id) &
                row.id.equals(branchId),
          ))
          .write(
            ConversationBranchRowsCompanion(
              leafRevisionId: Value(parentRevisionId),
            ),
          );
      await _db
          .into(_db.conversationStateRows)
          .insert(
            ConversationStateRowsCompanion.insert(
              conversationId: persisted.id,
              activeBranchId: Value(branchId),
              stateRevision: Value(messages.length),
            ),
          );
    });
  }

  Future<void> _createConversationWithMessages({
    required Conversation conversation,
    required List<ChatMessage> messages,
  }) async {
    for (final message in messages) {
      if (message.conversationId != conversation.id) {
        throw ArgumentError.value(
          message.conversationId,
          'messages',
          'Every message must belong to the new conversation.',
        );
      }
    }
    if (messages.map((message) => message.id).toSet().length !=
        messages.length) {
      throw ArgumentError.value(
        messages,
        'messages',
        'Message IDs must be unique.',
      );
    }
    final persisted = conversation.copyWith(
      messageIds: messages.map((message) => message.id).toList(growable: false),
    );
    await _db.transaction(() async {
      await _db
          .into(_db.conversationRows)
          .insert(_conversationCompanion(persisted), mode: InsertMode.insert);
      await _replaceMcpServers(persisted.id, persisted.mcpServerIds);
      for (final (index, message) in messages.indexed) {
        await _db
            .into(_db.messageRows)
            .insert(_messageCompanion(message, index), mode: InsertMode.insert);
      }
    });
  }

  Future<AppendedMessageVersion?> appendMessageVersion({
    required String messageId,
    required String content,
  }) {
    return _observer.measure(
      ChatDatabaseOperation.commandAppendVersion,
      () => _appendMessageVersion(messageId: messageId, content: content),
    );
  }

  Future<AppendedMessageVersion?> _appendMessageVersion({
    required String messageId,
    required String content,
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

      final original = _messageFromRow(originalRow);
      final groupId = original.groupId ?? original.id;
      final maxVersion = _db.messageRows.version.max();
      final maxVersionRow =
          await (_db.selectOnly(_db.messageRows)
                ..addColumns([maxVersion])
                ..where(
                  _db.messageRows.conversationId.equals(
                        original.conversationId,
                      ) &
                      (_db.messageRows.groupId.equals(groupId) |
                          (_db.messageRows.groupId.isNull() &
                              _db.messageRows.id.equals(groupId))),
                ))
              .getSingle();
      final nextVersion = (maxVersionRow.read(maxVersion) ?? -1) + 1;
      final message = ChatMessage(
        role: original.role,
        content: content,
        conversationId: original.conversationId,
        modelId: original.modelId,
        providerId: original.providerId,
        totalTokens: null,
        isStreaming: false,
        groupId: groupId,
        version: nextVersion,
      );
      final currentConversation = await _conversationFromRow(
        conversationRow,
        includeMessageIds: false,
      );
      final conversation = currentConversation.copyWith(
        updatedAt: DateTime.now(),
      );
      final mutation = original.role == 'user'
          ? MessageGraphRevisionMutation.editUser
          : MessageGraphRevisionMutation.regenerateAssistant;
      final commands = MessageGraphCommands(_db);
      if (mutation == MessageGraphRevisionMutation.editUser) {
        await commands.graftRevision(
          conversationId: conversation.id,
          targetRevisionId: original.id,
          text: content,
          mutation: mutation,
          revisionId: message.id,
        );
      } else {
        await commands.createRevisionBranch(
          conversationId: conversation.id,
          targetRevisionId: original.id,
          text: content,
          mutation: mutation,
          revisionId: message.id,
          branchId: _deterministicMergeId(
            'graph_branch',
            conversation.id,
            message.id,
          ),
        );
      }
      final order = await _nextMessageOrder(conversation.id);
      await _db
          .into(_db.messageRows)
          .insert(_messageCompanion(message, order), mode: InsertMode.insert);
      await _updateGraphRevisionPayload(message);
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
      final current = await _conversationFromRow(row);
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

  Future<void> replaceBackupSnapshot(File snapshotFile) async {
    await _importBackupSnapshot(snapshotFile);
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
        final remapped = <String, String>{};

        for (final sourceRow in sourceRows) {
          final sourceId = sourceRow.read<String>('id');
          await _requireContiguousMessageOrder('merge_source', sourceId);
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
          remappedConversationIds: Map.unmodifiable(remapped),
        );
      });
    } finally {
      if (attached) {
        await _db.customStatement('DETACH DATABASE merge_source;');
      }
    }
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
          'SELECT id, role, content, timestamp, model_id, provider_id, '
          'total_tokens, is_streaming, reasoning_text, reasoning_start_at, '
          'reasoning_finished_at, translation, reasoning_segments_json, group_id, '
          'version, prompt_tokens, completion_tokens, cached_tokens, duration_ms, '
          'message_order FROM $schema.message_rows WHERE conversation_id = ? '
          'ORDER BY message_order, id;',
          variables: [Variable<String>(id)],
        )
        .get();
    final messages = <Object?>[];
    final groupOrdinals = <String, int>{};
    for (final row in messageRows) {
      final messageId = row.read<String>('id');
      final tool = await _db
          .customSelect(
            'SELECT events_json FROM $schema.tool_event_rows WHERE message_id = ?;',
            variables: [Variable<String>(messageId)],
          )
          .getSingleOrNull();
      final signature = await _db
          .customSelect(
            'SELECT signature FROM $schema.gemini_thought_signature_rows '
            'WHERE message_id = ?;',
            variables: [Variable<String>(messageId)],
          )
          .getSingleOrNull();
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
        tool?.data['events_json'],
        signature?.data['signature'],
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

  Future<void> _requireContiguousMessageOrder(
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
    for (var index = 0; index < rows.length; index++) {
      if (rows[index].read<int>('message_order') != index) {
        throw StateError('conversation_message_order');
      }
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
      final groupId = row.data['group_id']?.toString();
      if (groupId == null || groupIdMap.containsKey(groupId)) continue;
      groupIdMap[groupId] = remapping
          ? _deterministicMergeId('group', groupId, targetId)
          : groupId;
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
      'last_summarized_message_count, chat_suggestions_json) '
      'SELECT ?, title, created_at, updated_at, is_pinned, assistant_id, '
      'truncate_index, ?, summary, '
      'last_summarized_message_count, chat_suggestions_json '
      'FROM merge_source.conversation_rows WHERE id = ?;',
      [targetId, jsonEncode(targetSelections), sourceId],
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
      final targetGroupId = sourceGroupId == null
          ? entry.value
          : (groupIdMap[sourceGroupId] ?? sourceGroupId);
      await _db.customStatement(
        'INSERT INTO main.message_rows '
        '(id, conversation_id, role, content, timestamp, model_id, provider_id, '
        'total_tokens, is_streaming, reasoning_text, reasoning_start_at, '
        'reasoning_finished_at, translation, reasoning_segments_json, group_id, '
        'version, prompt_tokens, completion_tokens, cached_tokens, duration_ms, '
        'message_order) '
        'SELECT ?, ?, role, content, timestamp, model_id, provider_id, '
        'total_tokens, 0, reasoning_text, reasoning_start_at, '
        'reasoning_finished_at, translation, reasoning_segments_json, '
        '?, version, '
        'prompt_tokens, completion_tokens, cached_tokens, duration_ms, '
        'message_order FROM merge_source.message_rows WHERE id = ?;',
        [entry.value, targetId, targetGroupId, entry.key],
      );
      await _db.customStatement(
        'INSERT INTO main.tool_event_rows (message_id, events_json) '
        'SELECT ?, events_json FROM merge_source.tool_event_rows '
        'WHERE message_id = ?;',
        [entry.value, entry.key],
      );
      await _db.customStatement(
        'INSERT INTO main.gemini_thought_signature_rows (message_id, signature) '
        'SELECT ?, signature FROM merge_source.gemini_thought_signature_rows '
        'WHERE message_id = ?;',
        [entry.value, entry.key],
      );
    }
  }

  Future<void> _importBackupSnapshot(File snapshotFile) async {
    if (!await snapshotFile.exists()) {
      throw FileSystemException(
        'Snapshot database does not exist',
        snapshotFile.path,
      );
    }

    var attached = false;
    try {
      await _db.customStatement('ATTACH DATABASE ? AS restore_source;', [
        snapshotFile.absolute.path,
      ]);
      attached = true;
      await _db.transaction(() async {
        await _clearChatRows();
        for (final table in const [
          'conversation_rows',
          'conversation_mcp_server_rows',
          'message_rows',
          'tool_event_rows',
          'gemini_thought_signature_rows',
        ]) {
          await _db.customStatement(
            'INSERT INTO main.$table '
            'SELECT * FROM restore_source.$table;',
          );
        }
        await _writeMigrationCompleteReceipt();
        final foreignKeyFailures = await _db
            .customSelect('PRAGMA foreign_key_check;')
            .get();
        if (foreignKeyFailures.isNotEmpty) {
          throw StateError('foreign_key_check');
        }
        final sourceConversationCount = await _attachedTableCount(
          'restore_source',
          'conversation_rows',
        );
        final sourceMessageCount = await _attachedTableCount(
          'restore_source',
          'message_rows',
        );
        if (await _attachedTableCount('main', 'conversation_rows') !=
                sourceConversationCount ||
            await _attachedTableCount('main', 'message_rows') !=
                sourceMessageCount) {
          throw StateError('snapshot_import_count');
        }
      });
    } finally {
      if (attached) {
        await _db.customStatement('DETACH DATABASE restore_source;');
      }
    }
    await validateIntegrity();
  }

  Future<int> _attachedTableCount(String schema, String table) async {
    final row = await _db
        .customSelect('SELECT COUNT(*) AS count FROM $schema.$table;')
        .getSingle();
    return row.read<int>('count');
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
      for (final entry in toolEventsByMessageId.entries) {
        batch.insert(
          _db.toolEventRows,
          ToolEventRowsCompanion.insert(
            messageId: entry.key,
            eventsJson: jsonEncode(entry.value),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
      for (final entry in geminiSignaturesByMessageId.entries) {
        batch.insert(
          _db.geminiThoughtSignatureRows,
          GeminiThoughtSignatureRowsCompanion.insert(
            messageId: entry.key,
            signature: entry.value,
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  Future<void> updateMessage(ChatMessage message) async {
    await _db.transaction(() async {
      await _updateMessageShadow(message);
      await _updateGraphRevisionPayload(message);
    });
  }

  Future<void> _updateMessageShadow(ChatMessage message) async {
    await (_db.update(
      _db.messageRows,
    )..where((t) => t.id.equals(message.id))).write(_messageUpdate(message));
  }

  Future<void> updateMessageAndStreamingState(
    ChatMessage message, {
    required bool untrackStreaming,
  }) async {
    await _db.transaction(() async {
      await _updateMessageShadow(message);
      await _updateGraphRevisionPayload(message);
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
      await _updateMessageShadow(message);
      await _updateGraphRevisionPayload(message, toolEvents: toolEvents);
      await _db
          .into(_db.toolEventRows)
          .insertOnConflictUpdate(
            ToolEventRowsCompanion.insert(
              messageId: message.id,
              eventsJson: jsonEncode(toolEvents),
            ),
          );
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

  Future<void> _updateGraphRevisionPayload(
    ChatMessage message, {
    List<Map<String, dynamic>>? toolEvents,
  }) async {
    final revision =
        await (_db.select(_db.messageRevisionRows)..where(
              (row) =>
                  row.conversationId.equals(message.conversationId) &
                  row.id.equals(message.id),
            ))
            .getSingleOrNull();
    if (revision == null) return;
    final now = DateTime.now().toUtc();
    final updatedAt = now.isBefore(revision.createdAt)
        ? revision.createdAt
        : now;
    await (_db.update(_db.messageRevisionRows)..where(
          (row) =>
              row.conversationId.equals(message.conversationId) &
              row.id.equals(message.id),
        ))
        .write(
          MessageRevisionRowsCompanion(
            updatedAt: Value(updatedAt),
            finalizedAt: message.isStreaming
                ? const Value.absent()
                : Value(updatedAt),
          ),
        );
    await _replaceGraphParts(message, toolEvents: toolEvents);
  }

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
      () => _deleteMessages(
        conversationId: conversationId,
        messageIds: messageIds,
        versionSelectionChanges: versionSelectionChanges,
      ),
    );
  }

  Future<DeletedMessagesResult?> deleteGraphMessages({
    required String conversationId,
    required Set<String> revisionIds,
  }) {
    if (revisionIds.isEmpty) return Future.value(null);
    return _observer.measure(
      ChatDatabaseOperation.commandDeleteMessages,
      () => _db.transaction(() async {
        final conversationRow = await (_db.select(
          _db.conversationRows,
        )..where((row) => row.id.equals(conversationId))).getSingleOrNull();
        if (conversationRow == null) return null;
        final beforeRows = await (_db.select(
          _db.messageRows,
        )..where((row) => row.conversationId.equals(conversationId))).get();
        final commands = MessageGraphCommands(_db);
        for (final revisionId in revisionIds) {
          final revision =
              await (_db.select(_db.messageRevisionRows)..where(
                    (row) =>
                        row.conversationId.equals(conversationId) &
                        row.id.equals(revisionId) &
                        row.deletedAt.isNull(),
                  ))
                  .getSingleOrNull();
          if (revision == null) continue;
          await commands.deleteRevision(
            conversationId: conversationId,
            revisionId: revisionId,
            confirmCascade: true,
          );
        }
        final deletedRevisionRows =
            await (_db.select(_db.messageRevisionRows)..where(
                  (row) =>
                      row.conversationId.equals(conversationId) &
                      row.deletedAt.isNotNull(),
                ))
                .get();
        final deletedIds = deletedRevisionRows.map((row) => row.id).toSet();
        final deletedMessages = beforeRows
            .where((row) => deletedIds.contains(row.id))
            .map(_messageFromRow)
            .toList(growable: false);
        if (deletedIds.isNotEmpty) {
          await (_db.delete(
            _db.messageRows,
          )..where((row) => row.id.isIn(deletedIds))).go();
        }
        final current = await _conversationFromRow(
          conversationRow,
          includeMessageIds: false,
        );
        final conversation = current.copyWith(
          chatSuggestions: const [],
          updatedAt: DateTime.now(),
        );
        await (_db.update(_db.conversationRows)
              ..where((row) => row.id.equals(conversationId)))
            .write(_conversationCompanion(conversation));
        return (conversation: conversation, messages: deletedMessages);
      }),
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
      final byId = {for (final row in rows) row.id: row};
      final deletedRows = rows
          .where((row) => messageIds.contains(row.id))
          .toList(growable: false);
      if (deletedRows.isEmpty) return null;
      if (deletedRows.length != messageIds.length) {
        throw StateError('delete_messages_not_found');
      }

      final orderedIds = rows.map((row) => row.id).toList(growable: true);
      for (final deletedRow in deletedRows) {
        final groupId = deletedRow.groupId ?? deletedRow.id;
        final anchorIndex = orderedIds.indexWhere((id) {
          final row = byId[id];
          return row != null && (row.groupId ?? row.id) == groupId;
        });
        orderedIds.remove(deletedRow.id);
        if (anchorIndex < 0) continue;
        final replacementIndex = orderedIds.indexWhere((id) {
          final row = byId[id];
          return row != null && (row.groupId ?? row.id) == groupId;
        });
        if (replacementIndex > anchorIndex) {
          final replacementId = orderedIds.removeAt(replacementIndex);
          orderedIds.insert(
            anchorIndex.clamp(0, orderedIds.length),
            replacementId,
          );
        }
      }

      await (_db.delete(
        _db.messageRows,
      )..where((row) => row.id.isIn(deletedRows.map((row) => row.id)))).go();
      await _rewriteMessageOrder(conversationId, orderedIds);
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
      final conversation = currentConversation.copyWith(
        messageIds: orderedIds,
        versionSelections: selections,
        chatSuggestions: const <String>[],
        updatedAt: DateTime.now(),
      );
      await (_db.update(_db.conversationRows)
            ..where((row) => row.id.equals(conversationId)))
          .write(_conversationCompanion(conversation));
      return (
        conversation: conversation,
        messages: deletedRows.map(_messageFromRow).toList(growable: false),
      );
    });
  }

  Future<void> clearAllData() async {
    await _db.transaction(() async {
      await _clearChatRows();
    });
  }

  Future<void> _clearChatRows() async {
    await _db.delete(_db.geminiThoughtSignatureRows).go();
    await _db.delete(_db.toolEventRows).go();
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
    final missing = ids.difference(result.keys.toSet());
    if (missing.isNotEmpty) {
      final legacyRows = await (_db.select(
        _db.toolEventRows,
      )..where((row) => row.messageId.isIn(missing))).get();
      for (final row in legacyRows) {
        result[row.messageId] = _decodeToolEvents(row.eventsJson);
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
      await _replaceGraphParts(message, toolEvents: events);
      await _db
          .into(_db.toolEventRows)
          .insertOnConflictUpdate(
            ToolEventRowsCompanion.insert(
              messageId: messageId,
              eventsJson: jsonEncode(events),
            ),
          );
    });
  }

  Future<void> deleteToolEvents(String messageId) async {
    await _db.transaction(() async {
      final message = await getMessage(messageId);
      if (message != null) {
        await _replaceGraphParts(message, toolEvents: const []);
      }
      await (_db.delete(
        _db.toolEventRows,
      )..where((t) => t.messageId.equals(messageId))).go();
    });
  }

  Future<String?> getGeminiThoughtSignature(String messageId) async {
    return (await getGeminiThoughtSignaturesForMessages([
      messageId,
    ]))[messageId];
  }

  Future<Map<String, String>> getGeminiThoughtSignaturesForMessages(
    Iterable<String> messageIds,
  ) async {
    final ids = messageIds.toSet();
    if (ids.isEmpty) return const {};
    final rows =
        await (_db.select(_db.providerArtifactRows)..where(
              (row) =>
                  row.revisionId.isIn(ids) &
                  row.kind.equals('gemini_thought_signature'),
            ))
            .get();
    final result = <String, String>{
      for (final row in rows)
        if (row.payload.trim().isNotEmpty) row.revisionId: row.payload.trim(),
    };
    final missing = ids.difference(result.keys.toSet());
    if (missing.isNotEmpty) {
      final legacyRows = await (_db.select(
        _db.geminiThoughtSignatureRows,
      )..where((row) => row.messageId.isIn(missing))).get();
      for (final row in legacyRows) {
        if (row.signature.trim().isNotEmpty) {
          result[row.messageId] = row.signature.trim();
        }
      }
    }
    return result;
  }

  Future<void> setGeminiThoughtSignature(
    String messageId,
    String signature,
  ) async {
    await _db.transaction(() async {
      await _upsertGeminiThoughtSignature(messageId, signature);
    });
  }

  Future<void> _upsertGeminiThoughtSignature(
    String messageId,
    String signature,
  ) async {
    final revision = await (_db.select(
      _db.messageRevisionRows,
    )..where((row) => row.id.equals(messageId))).getSingleOrNull();
    if (revision == null) {
      throw StateError('provider_artifact_revision_missing');
    }
    final now = DateTime.now().toUtc();
    await _db
        .into(_db.providerArtifactRows)
        .insertOnConflictUpdate(
          ProviderArtifactRowsCompanion.insert(
            conversationId: revision.conversationId,
            revisionId: messageId,
            kind: 'gemini_thought_signature',
            payload: signature,
            createdAt: revision.createdAt,
            updatedAt: now.isBefore(revision.createdAt)
                ? revision.createdAt
                : now,
          ),
        );
    await _db
        .into(_db.geminiThoughtSignatureRows)
        .insertOnConflictUpdate(
          GeminiThoughtSignatureRowsCompanion.insert(
            messageId: messageId,
            signature: signature,
          ),
        );
  }

  Future<void> deleteGeminiThoughtSignature(String messageId) async {
    await _db.transaction(() async {
      await (_db.delete(_db.providerArtifactRows)..where(
            (row) =>
                row.revisionId.equals(messageId) &
                row.kind.equals('gemini_thought_signature'),
          ))
          .go();
      await (_db.delete(
        _db.geminiThoughtSignatureRows,
      )..where((t) => t.messageId.equals(messageId))).go();
    });
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
      final targetIds = runs.map((run) => run.targetRevisionId).toSet();
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
      await (_db.update(_db.messageRows)
            ..where((row) => row.isStreaming.equals(true)))
          .write(const MessageRowsCompanion(isStreaming: Value(false)));
      if (targetIds.isNotEmpty) {
        await (_db.update(_db.messageRevisionRows)..where(
              (row) => row.id.isIn(targetIds) & row.finalizedAt.isNull(),
            ))
            .write(
              MessageRevisionRowsCompanion(
                updatedAt: Value(now),
                finalizedAt: Value(now),
              ),
            );
      }
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

  Future<Conversation> _conversationFromRow(
    ConversationRow row, {
    bool includeMessageIds = true,
  }) async {
    final mcpRows =
        await (_db.select(_db.conversationMcpServerRows)
              ..where((t) => t.conversationId.equals(row.id))
              ..orderBy([(t) => OrderingTerm.asc(t.ordinal)]))
            .get();
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
      mcpServerIds: mcpRows.map((m) => m.serverId).toList(growable: false),
      assistantId: row.assistantId,
      truncateIndex: row.truncateIndex,
      versionSelections: _decodeStringIntMap(row.versionSelectionsJson),
      summary: row.summary,
      lastSummarizedMessageCount: row.lastSummarizedMessageCount,
      chatSuggestions: _decodeStringList(row.chatSuggestionsJson),
    );
  }

  ConversationRowsCompanion _conversationCompanion(Conversation conversation) {
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

  /// Legacy row metadata remains as a compatibility shadow. Whenever graph
  /// parts exist, text/reasoning are projected exclusively from those parts.
  ChatMessage _messageFromRow(
    MessageRow row, {
    List<MessagePartRow>? authoritativeParts,
  }) {
    final hasAuthoritativeParts = authoritativeParts?.isNotEmpty ?? false;
    final text = hasAuthoritativeParts
        ? authoritativeParts!
              .where((part) => part.kind == 'text')
              .map((part) => part.payload)
              .join()
        : row.content;
    final reasoningParts = hasAuthoritativeParts
        ? authoritativeParts!
              .where((part) => part.kind == 'reasoning')
              .map((part) => part.payload)
              .toList(growable: false)
        : const <String>[];
    return ChatMessage(
      id: row.id,
      role: row.role,
      content: text,
      timestamp: row.timestamp,
      modelId: row.modelId,
      providerId: row.providerId,
      totalTokens: row.totalTokens,
      conversationId: row.conversationId,
      isStreaming: row.isStreaming,
      reasoningText: hasAuthoritativeParts
          ? (reasoningParts.isEmpty ? null : reasoningParts.join())
          : row.reasoningText,
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
      content: message.content,
      timestamp: message.timestamp,
      modelId: Value(message.modelId),
      providerId: Value(message.providerId),
      totalTokens: Value(message.totalTokens),
      isStreaming: Value(message.isStreaming),
      reasoningText: Value(message.reasoningText),
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
      content: Value(message.content),
      totalTokens: Value(message.totalTokens),
      isStreaming: Value(message.isStreaming),
      reasoningText: Value(message.reasoningText),
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

  List<Map<String, dynamic>> _decodeToolEvents(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const <Map<String, dynamic>>[];
    return decoded
        .whereType<Map>()
        .map((event) => event.map((key, value) => MapEntry('$key', value)))
        .toList(growable: false);
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

class ChatStorageMetaKeys {
  ChatStorageMetaKeys._();

  static const activeStreamingIds = 'active_streaming_ids';
  static const hiveMigrationComplete = 'hive_migration_complete_v1';
  static const databaseIdentity = 'database_identity_v1';
  static const sandboxPathVersion = 'sandbox_path_migration_version';
}
