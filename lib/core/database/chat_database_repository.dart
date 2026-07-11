import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../models/chat_message.dart';
import '../models/conversation.dart';
import 'app_database.dart';

typedef ChatDatabaseSnapshotInfo = ({
  int schemaVersion,
  int conversationCount,
  int messageCount,
});

typedef InstalledChatDatabaseInfo = ({int schemaVersion, String? databaseId});

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

class ChatDatabaseRepository {
  ChatDatabaseRepository(this._db, [this._syncDb]);

  final AppDatabase _db;
  final sqlite.Database? _syncDb;

  static ChatDatabaseRepository open({File? file}) {
    final db = AppDatabase.open(file: file);
    return ChatDatabaseRepository(db, file == null ? null : _openSync(file));
  }

  static sqlite.Database _openSync(File file) {
    final db = sqlite.sqlite3.open(file.path);
    db.execute('PRAGMA journal_mode = WAL;');
    db.execute('PRAGMA foreign_keys = ON;');
    db.execute('PRAGMA busy_timeout = 5000;');
    return db;
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
    const requiredTables = {
      'conversation_rows',
      'conversation_mcp_server_rows',
      'message_rows',
      'tool_event_rows',
      'gemini_thought_signature_rows',
      'chat_storage_meta_rows',
    };
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
    _validateRawSchema(database);
  }

  static void _validateRawSchema(sqlite.Database database) {
    const expectedColumns = <String, List<String>>{
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

    const expectedForeignKeys = <String, Set<String>>{
      'conversation_mcp_server_rows': {
        'conversation_id->conversation_rows.id:CASCADE',
      },
      'message_rows': {'conversation_id->conversation_rows.id:CASCADE'},
      'tool_event_rows': {'message_id->message_rows.id:CASCADE'},
      'gemini_thought_signature_rows': {'message_id->message_rows.id:CASCADE'},
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
    _syncDb?.close();
    await _db.close();
  }

  Future<void> ensureReady() async {
    await _db.customSelect('SELECT 1').get();
  }

  Future<void> checkpoint() async {
    await _db.customStatement('PRAGMA wal_checkpoint(TRUNCATE);');
  }

  Future<void> validateIntegrity() async {
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
  }

  Future<List<Conversation>> getAllConversations() async {
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
  }

  Future<List<Conversation>> getAllConversationSummaries() async {
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
  }

  List<Conversation> getAllConversationsSync() {
    final db = _syncDb;
    if (db == null) return const <Conversation>[];
    final rows = db.select(
      'SELECT * FROM conversation_rows ORDER BY updated_at DESC',
    );
    return rows
        .map((row) => _conversationFromSqliteRow(row, includeMessageIds: false))
        .toList(growable: false);
  }

  List<Conversation> getAllCompleteConversationsSync() {
    final db = _syncDb;
    if (db == null) return const <Conversation>[];
    final rows = db.select(
      'SELECT * FROM conversation_rows ORDER BY updated_at DESC',
    );
    return rows
        .map((row) => _conversationFromSqliteRow(row, includeMessageIds: true))
        .toList(growable: false);
  }

  Future<Conversation?> getConversation(String id) async {
    final row = await (_db.select(
      _db.conversationRows,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    return _conversationFromRow(row);
  }

  Conversation? getConversationSync(
    String id, {
    bool includeMessageIds = true,
  }) {
    final db = _syncDb;
    if (db == null) return null;
    final rows = db.select(
      'SELECT * FROM conversation_rows WHERE id = ? LIMIT 1',
      [id],
    );
    if (rows.isEmpty) return null;
    return _conversationFromSqliteRow(
      rows.first,
      includeMessageIds: includeMessageIds,
    );
  }

  Future<int> getMessageCount(String conversationId) async {
    final count = _db.messageRows.id.count();
    final row =
        await (_db.selectOnly(_db.messageRows)
              ..addColumns([count])
              ..where(_db.messageRows.conversationId.equals(conversationId)))
            .getSingle();
    return row.read(count) ?? 0;
  }

  int getMessageCountSync(String conversationId) {
    final db = _syncDb;
    if (db == null) return 0;
    final rows = db.select(
      'SELECT COUNT(*) AS count FROM message_rows WHERE conversation_id = ?',
      [conversationId],
    );
    return (rows.first['count'] as int?) ?? 0;
  }

  int getConversationCountSync() {
    final db = _syncDb;
    if (db == null) return 0;
    final rows = db.select('SELECT COUNT(*) AS count FROM conversation_rows');
    return (rows.first['count'] as int?) ?? 0;
  }

  int getTotalMessageCountSync() {
    final db = _syncDb;
    if (db == null) return 0;
    final rows = db.select('SELECT COUNT(*) AS count FROM message_rows');
    return (rows.first['count'] as int?) ?? 0;
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

  int getMessageIndexSync(String conversationId, String messageId) {
    final db = _syncDb;
    if (db == null) return -1;
    final rows = db.select(
      'SELECT message_order FROM message_rows '
      'WHERE conversation_id = ? AND id = ? LIMIT 1',
      [conversationId, messageId],
    );
    return rows.isEmpty ? -1 : rows.first['message_order'] as int;
  }

  Future<ChatMessage?> getMessage(String messageId) async {
    final row = await (_db.select(
      _db.messageRows,
    )..where((t) => t.id.equals(messageId))).getSingleOrNull();
    return row == null ? null : _messageFromRow(row);
  }

  ChatMessage? getMessageSync(String messageId) {
    final db = _syncDb;
    if (db == null) return null;
    final rows = db.select('SELECT * FROM message_rows WHERE id = ? LIMIT 1', [
      messageId,
    ]);
    return rows.isEmpty ? null : _messageFromSqliteRow(rows.first);
  }

  Future<List<ChatMessage>> getMessagesRange(
    String conversationId, {
    required int start,
    required int limit,
  }) async {
    if (limit <= 0) return const <ChatMessage>[];
    final safeStart = start < 0 ? 0 : start;
    final rows =
        await (_db.select(_db.messageRows)
              ..where((t) => t.conversationId.equals(conversationId))
              ..orderBy([(t) => OrderingTerm.asc(t.messageOrder)])
              ..limit(limit, offset: safeStart))
            .get();
    return rows.map(_messageFromRow).toList(growable: false);
  }

  List<ChatMessage> getMessagesRangeSync(
    String conversationId, {
    required int start,
    required int limit,
  }) {
    final db = _syncDb;
    if (db == null || limit <= 0) return const <ChatMessage>[];
    final safeStart = start < 0 ? 0 : start;
    final rows = db.select(
      'SELECT * FROM message_rows WHERE conversation_id = ? '
      'ORDER BY message_order ASC LIMIT ? OFFSET ?',
      [conversationId, limit, safeStart],
    );
    return rows.map(_messageFromSqliteRow).toList(growable: false);
  }

  Future<List<ChatMessage>> getMessagesByIds(List<String> ids) async {
    if (ids.isEmpty) return const <ChatMessage>[];
    final rows = await (_db.select(
      _db.messageRows,
    )..where((t) => t.id.isIn(ids))).get();
    final byId = <String, ChatMessage>{
      for (final row in rows) row.id: _messageFromRow(row),
    };
    return [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
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

  Map<String, int> getFirstMessageIndicesForGroupsSync(
    String conversationId,
    Iterable<String> groupIds,
  ) {
    final db = _syncDb;
    final ids = groupIds.where((id) => id.isNotEmpty).toSet();
    if (db == null || ids.isEmpty) return const <String, int>{};
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = db.select(
      'SELECT COALESCE(group_id, id) AS group_key, '
      'MIN(message_order) AS message_order FROM message_rows '
      'WHERE conversation_id = ? '
      'AND (group_id IN ($placeholders) OR id IN ($placeholders)) '
      'GROUP BY group_key',
      [conversationId, ...ids, ...ids],
    );
    return {
      for (final row in rows)
        if (row['group_key'] != null && row['message_order'] != null)
          row['group_key'] as String: row['message_order'] as int,
    };
  }

  Future<List<ChatMessage>> getMessagesForGroups(
    String conversationId,
    Iterable<String> groupIds,
  ) async {
    final ids = groupIds.where((id) => id.isNotEmpty).toSet();
    if (ids.isEmpty) return const <ChatMessage>[];
    final rows =
        await (_db.select(_db.messageRows)
              ..where(
                (t) =>
                    t.conversationId.equals(conversationId) &
                    (t.groupId.isIn(ids) | t.id.isIn(ids)),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.messageOrder)]))
            .get();
    return rows.map(_messageFromRow).toList(growable: false);
  }

  List<ChatMessage> getMessagesForGroupsSync(
    String conversationId,
    Iterable<String> groupIds,
  ) {
    final db = _syncDb;
    final ids = groupIds.where((id) => id.isNotEmpty).toSet();
    if (db == null || ids.isEmpty) return const <ChatMessage>[];
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = db.select(
      'SELECT * FROM message_rows WHERE conversation_id = ? '
      'AND (group_id IN ($placeholders) OR id IN ($placeholders)) '
      'ORDER BY message_order ASC',
      [conversationId, ...ids, ...ids],
    );
    return rows.map(_messageFromSqliteRow).toList(growable: false);
  }

  List<String> getMessageIdsSync(String conversationId) {
    final db = _syncDb;
    if (db == null) return const <String>[];
    final rows = db.select(
      'SELECT id FROM message_rows WHERE conversation_id = ? '
      'ORDER BY message_order ASC',
      [conversationId],
    );
    return rows.map((row) => row['id'] as String).toList(growable: false);
  }

  Future<void> updateMessageOrder(
    String conversationId,
    List<String> messageIds,
  ) async {
    await _db.transaction(() async {
      for (var i = 0; i < messageIds.length; i++) {
        await (_db.update(_db.messageRows)..where(
              (t) =>
                  t.conversationId.equals(conversationId) &
                  t.id.equals(messageIds[i]),
            ))
            .write(MessageRowsCompanion(messageOrder: Value(i)));
      }
    });
  }

  List<ConversationSearchMatch> searchConversationMatchesSync({
    required List<String> tokens,
    int limit = 200,
    int candidateMultiplier = 8,
  }) {
    final db = _syncDb;
    final cleanTokens = tokens
        .map((token) => token.trim().toLowerCase())
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
    if (db == null || cleanTokens.isEmpty || limit <= 0) {
      return const <ConversationSearchMatch>[];
    }

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
      messageAnyClauses.add('LOWER(m.content) LIKE ? ESCAPE \'\\\'');
      messageArgs.add(pattern);
    }

    final candidateLimit = (limit * candidateMultiplier)
        .clamp(limit, 2000)
        .toInt();
    final rows = db.select(
      '''
      SELECT
        c.id AS conversation_id,
        c.title AS conversation_title,
        c.updated_at AS updated_at,
        c.version_selections_json AS version_selections_json,
        m.id AS message_id,
        m.content AS message_content,
        m.role AS message_role,
        m.group_id AS group_id,
        m.version AS version,
        m.message_order AS message_order,
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
      WHERE (${titleClauses.join(' AND ')}) OR (${existsClauses.join(' AND ')})
      ORDER BY c.updated_at DESC, m.message_order ASC
      LIMIT ?
      ''',
      [...messageArgs, ...titleArgs, ...existsArgs, candidateLimit],
    );

    return rows
        .map((row) {
          return ConversationSearchMatch(
            conversationId: row['conversation_id'] as String,
            conversationTitle: row['conversation_title'] as String,
            updatedAt: _dateTimeFromSqlite(row['updated_at']),
            versionSelections: _decodeStringIntMap(
              row['version_selections_json'] as String? ?? '{}',
            ),
            messageId: row['message_id'] as String?,
            messageContent: row['message_content'] as String?,
            messageRole: row['message_role'] as String?,
            groupId: row['group_id'] as String?,
            version: row['version'] as int?,
            maxVersion: row['max_version'] as int?,
          );
        })
        .toList(growable: false);
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
    await _db
        .into(_db.messageRows)
        .insertOnConflictUpdate(_messageCompanion(message, order));
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
    await (_db.update(
      _db.messageRows,
    )..where((t) => t.id.equals(message.id))).write(_messageUpdate(message));
  }

  Future<void> updateStreamingCheckpoint(
    ChatMessage message,
    List<Map<String, dynamic>> toolEvents,
  ) async {
    await _db.transaction(() async {
      await (_db.update(
        _db.messageRows,
      )..where((t) => t.id.equals(message.id))).write(_messageUpdate(message));
      await _db
          .into(_db.toolEventRows)
          .insertOnConflictUpdate(
            ToolEventRowsCompanion.insert(
              messageId: message.id,
              eventsJson: jsonEncode(toolEvents),
            ),
          );
    });
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
      for (var i = 0; i < messageIds.length; i++) {
        await (_db.update(_db.messageRows)
              ..where((t) => t.id.equals(messageIds[i])))
            .write(MessageRowsCompanion(messageOrder: Value(i)));
      }
    });
  }

  Future<void> deleteConversation(String id) async {
    await (_db.delete(
      _db.conversationRows,
    )..where((t) => t.id.equals(id))).go();
  }

  Future<void> deleteMessage(String messageId) async {
    final row = await (_db.select(
      _db.messageRows,
    )..where((t) => t.id.equals(messageId))).getSingleOrNull();
    if (row == null) return;
    await (_db.delete(
      _db.messageRows,
    )..where((t) => t.id.equals(messageId))).go();
    await _compactMessageOrder(row.conversationId);
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
    final row = await (_db.select(
      _db.toolEventRows,
    )..where((t) => t.messageId.equals(messageId))).getSingleOrNull();
    if (row == null) return const <Map<String, dynamic>>[];
    final decoded = jsonDecode(row.eventsJson);
    if (decoded is! List) return const <Map<String, dynamic>>[];
    return decoded
        .whereType<Map>()
        .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
        .toList();
  }

  List<Map<String, dynamic>> getToolEventsSync(String messageId) {
    final db = _syncDb;
    if (db == null) return const <Map<String, dynamic>>[];
    final rows = db.select(
      'SELECT events_json FROM tool_event_rows WHERE message_id = ? LIMIT 1',
      [messageId],
    );
    if (rows.isEmpty) return const <Map<String, dynamic>>[];
    final decoded = jsonDecode(rows.first['events_json'] as String);
    if (decoded is! List) return const <Map<String, dynamic>>[];
    return decoded
        .whereType<Map>()
        .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
        .toList();
  }

  Future<void> setToolEvents(
    String messageId,
    List<Map<String, dynamic>> events,
  ) async {
    await _db
        .into(_db.toolEventRows)
        .insertOnConflictUpdate(
          ToolEventRowsCompanion.insert(
            messageId: messageId,
            eventsJson: jsonEncode(events),
          ),
        );
  }

  Future<void> deleteToolEvents(String messageId) async {
    await (_db.delete(
      _db.toolEventRows,
    )..where((t) => t.messageId.equals(messageId))).go();
  }

  Future<String?> getGeminiThoughtSignature(String messageId) async {
    final row = await (_db.select(
      _db.geminiThoughtSignatureRows,
    )..where((t) => t.messageId.equals(messageId))).getSingleOrNull();
    final value = row?.signature.trim();
    return value == null || value.isEmpty ? null : value;
  }

  String? getGeminiThoughtSignatureSync(String messageId) {
    final db = _syncDb;
    if (db == null) return null;
    final rows = db.select(
      'SELECT signature FROM gemini_thought_signature_rows '
      'WHERE message_id = ? LIMIT 1',
      [messageId],
    );
    if (rows.isEmpty) return null;
    final value = (rows.first['signature'] as String?)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  Future<void> setGeminiThoughtSignature(
    String messageId,
    String signature,
  ) async {
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
    await (_db.delete(
      _db.geminiThoughtSignatureRows,
    )..where((t) => t.messageId.equals(messageId))).go();
  }

  Future<List<String>> getActiveStreamingIds() async {
    final row =
        await (_db.select(_db.chatStorageMetaRows)..where(
              (t) => t.key.equals(ChatStorageMetaKeys.activeStreamingIds),
            ))
            .getSingleOrNull();
    if (row == null) return const <String>[];
    final decoded = jsonDecode(row.value);
    if (decoded is! List) return const <String>[];
    return decoded.map((e) => e.toString()).toList(growable: false);
  }

  Future<void> setActiveStreamingIds(List<String> ids) async {
    if (ids.isEmpty) {
      await clearActiveStreamingIds();
      return;
    }
    await _db
        .into(_db.chatStorageMetaRows)
        .insertOnConflictUpdate(
          ChatStorageMetaRowsCompanion.insert(
            key: ChatStorageMetaKeys.activeStreamingIds,
            value: jsonEncode(ids),
          ),
        );
  }

  Future<void> clearActiveStreamingIds() async {
    await (_db.delete(
      _db.chatStorageMetaRows,
    )..where((t) => t.key.equals(ChatStorageMetaKeys.activeStreamingIds))).go();
  }

  /// Clears every persisted streaming projection after a cold application start.
  Future<void> resetStaleStreamingState() async {
    await _db.transaction(() async {
      await (_db.update(_db.messageRows)
            ..where((row) => row.isStreaming.equals(true)))
          .write(const MessageRowsCompanion(isStreaming: Value(false)));
      await clearActiveStreamingIds();
    });
  }

  Future<void> untrackActiveStreamingId(String messageId) async {
    await _db.transaction(() async {
      final ids = await getActiveStreamingIds();
      if (!ids.contains(messageId)) return;
      final updated = ids
          .where((id) => id != messageId)
          .toList(growable: false);
      await setActiveStreamingIds(updated);
    });
  }

  Future<void> trackActiveStreamingId(String messageId) async {
    await _db.transaction(() async {
      final ids = (await getActiveStreamingIds()).toList();
      if (ids.contains(messageId)) return;
      ids.add(messageId);
      await setActiveStreamingIds(ids);
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

  Future<void> _compactMessageOrder(String conversationId) async {
    final rows =
        await (_db.select(_db.messageRows)
              ..where((t) => t.conversationId.equals(conversationId))
              ..orderBy([(t) => OrderingTerm.asc(t.messageOrder)]))
            .get();
    for (var i = 0; i < rows.length; i++) {
      if (rows[i].messageOrder == i) continue;
      await (_db.update(_db.messageRows)..where((t) => t.id.equals(rows[i].id)))
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

  Conversation _conversationFromSqliteRow(
    sqlite.Row row, {
    bool includeMessageIds = true,
  }) {
    final db = _syncDb;
    final id = row['id'] as String;
    final mcpRows = db?.select(
      'SELECT server_id FROM conversation_mcp_server_rows '
      'WHERE conversation_id = ? ORDER BY ordinal ASC',
      [id],
    );
    final messageRows = includeMessageIds
        ? db?.select(
            'SELECT id FROM message_rows WHERE conversation_id = ? '
            'ORDER BY message_order ASC',
            [id],
          )
        : null;
    return Conversation(
      id: id,
      title: row['title'] as String,
      createdAt: _dateTimeFromSqlite(row['created_at']),
      updatedAt: _dateTimeFromSqlite(row['updated_at']),
      messageIds:
          messageRows?.map((m) => m['id'] as String).toList(growable: false) ??
          const <String>[],
      isPinned: row['is_pinned'] == 1,
      mcpServerIds:
          mcpRows
              ?.map((m) => m['server_id'] as String)
              .toList(growable: false) ??
          const <String>[],
      assistantId: row['assistant_id'] as String?,
      truncateIndex: row['truncate_index'] as int? ?? -1,
      versionSelections: _decodeStringIntMap(
        row['version_selections_json'] as String? ?? '{}',
      ),
      summary: row['summary'] as String?,
      lastSummarizedMessageCount:
          row['last_summarized_message_count'] as int? ?? 0,
      chatSuggestions: _decodeStringList(
        row['chat_suggestions_json'] as String? ?? '[]',
      ),
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

  ChatMessage _messageFromRow(MessageRow row) {
    return ChatMessage(
      id: row.id,
      role: row.role,
      content: row.content,
      timestamp: row.timestamp,
      modelId: row.modelId,
      providerId: row.providerId,
      totalTokens: row.totalTokens,
      conversationId: row.conversationId,
      isStreaming: row.isStreaming,
      reasoningText: row.reasoningText,
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

  ChatMessage _messageFromSqliteRow(sqlite.Row row) {
    DateTime? nullableDate(String key) {
      final value = row[key];
      return value == null ? null : _dateTimeFromSqlite(value);
    }

    return ChatMessage(
      id: row['id'] as String,
      role: row['role'] as String,
      content: row['content'] as String,
      timestamp: _dateTimeFromSqlite(row['timestamp']),
      modelId: row['model_id'] as String?,
      providerId: row['provider_id'] as String?,
      totalTokens: row['total_tokens'] as int?,
      conversationId: row['conversation_id'] as String,
      isStreaming: row['is_streaming'] == 1,
      reasoningText: row['reasoning_text'] as String?,
      reasoningStartAt: nullableDate('reasoning_start_at'),
      reasoningFinishedAt: nullableDate('reasoning_finished_at'),
      translation: row['translation'] as String?,
      reasoningSegmentsJson: row['reasoning_segments_json'] as String?,
      groupId: row['group_id'] as String?,
      version: row['version'] as int? ?? 0,
      promptTokens: row['prompt_tokens'] as int?,
      completionTokens: row['completion_tokens'] as int?,
      cachedTokens: row['cached_tokens'] as int?,
      durationMs: row['duration_ms'] as int?,
    );
  }

  DateTime _dateTimeFromSqlite(Object? value) {
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(
        value * Duration.millisecondsPerSecond,
      );
    }
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(
        value.toInt() * Duration.millisecondsPerSecond,
      );
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
}
