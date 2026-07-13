import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../models/assistant.dart';
import '../models/preset_message.dart';
import 'app_database.dart';

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

  // ===== Assistant CRUD =====

  Future<List<Assistant>> getAllAssistants() async {
    final rows = await (_db.select(
      _db.assistantRows,
    )..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).get();
    return rows.map(_assistantFromRow).toList(growable: false);
  }

  Future<Assistant?> getAssistant(String id) async {
    final row = await (_db.select(
      _db.assistantRows,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _assistantFromRow(row);
  }

  Future<void> putAssistant(Assistant assistant, {int? sortOrder}) async {
    final order = sortOrder ?? 0;
    await _db
        .into(_db.assistantRows)
        .insertOnConflictUpdate(_assistantCompanion(assistant, order));
  }

  Future<void> putAssistants(List<Assistant> assistants) async {
    if (assistants.isEmpty) {
      await _db.delete(_db.assistantRows).go();
      return;
    }
    await _db.transaction(() async {
      await _db.delete(_db.assistantRows).go();
      for (var i = 0; i < assistants.length; i++) {
        await _db
            .into(_db.assistantRows)
            .insertOnConflictUpdate(_assistantCompanion(assistants[i], i));
      }
    });
  }

  Future<void> deleteAssistant(String id) async {
    await (_db.delete(_db.assistantRows)..where((t) => t.id.equals(id))).go();
  }

  Future<int> getAssistantCount() async {
    final count = _db.assistantRows.id.count();
    final row = await (_db.selectOnly(
      _db.assistantRows,
    )..addColumns([count])).getSingle();
    return row.read(count) ?? 0;
  }

  // ===== Cache CRUD =====

  Future<CacheRow?> getCacheEntry(String type, String key) async {
    return (_db.select(
      _db.cacheRows,
    )..where((t) => t.type.equals(type) & t.key.equals(key))).getSingleOrNull();
  }

  Future<void> putCacheEntry(String type, String key, String value) async {
    await _db
        .into(_db.cacheRows)
        .insertOnConflictUpdate(
          CacheRowsCompanion.insert(
            type: type,
            key: key,
            value: value,
            updatedAt: DateTime.now(),
          ),
        );
  }

  Future<void> deleteCacheEntry(String type, String key) async {
    await (_db.delete(
      _db.cacheRows,
    )..where((t) => t.type.equals(type) & t.key.equals(key))).go();
  }

  Future<void> clearCacheByType(String type) async {
    await (_db.delete(_db.cacheRows)..where((t) => t.type.equals(type))).go();
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
    });
  }

  Future<void> putRestoreBatch({
    required List<Conversation> conversations,
    required Map<String, List<ChatMessage>> messagesByConversation,
    required Map<String, List<Map<String, dynamic>>> toolEventsByMessageId,
    required Map<String, String> geminiSignaturesByMessageId,
  }) async {
    if (conversations.isEmpty &&
        messagesByConversation.values.every((l) => l.isEmpty) &&
        toolEventsByMessageId.isEmpty &&
        geminiSignaturesByMessageId.isEmpty) {
      return;
    }

    await _db.transaction(() async {
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
        for (final entry in messagesByConversation.entries) {
          final messages = entry.value;
          for (var i = 0; i < messages.length; i++) {
            batch.insert(
              _db.messageRows,
              _messageCompanion(messages[i], i),
              mode: InsertMode.insertOrReplace,
            );
          }
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
    });
  }

  Future<void> updateMessage(ChatMessage message) async {
    final existing = await (_db.select(
      _db.messageRows,
    )..where((t) => t.id.equals(message.id))).getSingleOrNull();
    if (existing == null) return;
    await _db
        .into(_db.messageRows)
        .insertOnConflictUpdate(
          _messageCompanion(message, existing.messageOrder),
        );
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
      await _db.delete(_db.geminiThoughtSignatureRows).go();
      await _db.delete(_db.toolEventRows).go();
      await _db.delete(_db.assistantRows).go();
      await _db.delete(_db.conversationMcpServerRows).go();
      await _db.delete(_db.messageRows).go();
      await _db.delete(_db.conversationRows).go();
      await _db.delete(_db.cacheRows).go();
      await _db.delete(_db.chatStorageMetaRows).go();
    });
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

  Future<void> untrackActiveStreamingId(String messageId) async {
    final ids = await getActiveStreamingIds();
    if (!ids.contains(messageId)) return;
    final updated = ids.where((id) => id != messageId).toList(growable: false);
    await setActiveStreamingIds(updated);
  }

  Future<void> markMigrationComplete() async {
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

  Assistant _assistantFromRow(AssistantRow row) {
    return Assistant.fromJson({
      'id': row.id,
      'name': row.name,
      'avatar': row.avatar,
      'useAssistantAvatar': row.useAssistantAvatar,
      'useAssistantName': row.useAssistantName,
      'background': row.background,
      'chatModelProvider': row.chatModelProvider,
      'chatModelId': row.chatModelId,
      'temperature': row.temperature,
      'topP': row.topP,
      'contextMessageSize': row.contextMessageSize,
      'limitContextMessages': row.limitContextMessages,
      'streamOutput': row.streamOutput,
      'thinkingBudget': row.thinkingBudget,
      'maxTokens': row.maxTokens,
      'systemPrompt': row.systemPrompt,
      'messageTemplate': row.messageTemplate,
      'searchEnabled': row.searchEnabled,
      'mcpServerIds': (jsonDecode(row.mcpServerIdsJson) as List).cast<String>(),
      'localToolIds': (jsonDecode(row.localToolIdsJson) as List).cast<String>(),
      'customHeaders': jsonDecode(row.customHeadersJson),
      'customBody': jsonDecode(row.customBodyJson),
      'enableMemory': row.enableMemory,
      'memoryMode': row.memoryMode,
      'enableRecentChatsReference': row.enableRecentChatsReference,
      'recentChatsSummaryMessageCount': row.recentChatsSummaryMessageCount,
      'memoryRecordPrompt': row.memoryRecordPrompt,
      'presetMessages': jsonDecode(row.presetMessagesJson),
      'regexRules': jsonDecode(row.regexRulesJson),
      'createdAt': row.createdAt.toIso8601String(),
      'updatedAt': row.updatedAt.toIso8601String(),
    });
  }

  AssistantRowsCompanion _assistantCompanion(Assistant a, int sortOrder) {
    return AssistantRowsCompanion.insert(
      id: a.id,
      name: a.name,
      avatar: Value(a.avatar),
      useAssistantAvatar: Value(a.useAssistantAvatar),
      useAssistantName: Value(a.useAssistantName),
      background: Value(a.background),
      chatModelProvider: Value(a.chatModelProvider),
      chatModelId: Value(a.chatModelId),
      temperature: Value(a.temperature),
      topP: Value(a.topP),
      contextMessageSize: Value(a.contextMessageSize),
      limitContextMessages: Value(a.limitContextMessages),
      streamOutput: Value(a.streamOutput),
      thinkingBudget: Value(a.thinkingBudget),
      maxTokens: Value(a.maxTokens),
      systemPrompt: Value(a.systemPrompt),
      messageTemplate: Value(a.messageTemplate),
      searchEnabled: Value(a.searchEnabled),
      mcpServerIdsJson: Value(jsonEncode(a.mcpServerIds)),
      localToolIdsJson: Value(jsonEncode(a.localToolIds)),
      customHeadersJson: Value(jsonEncode(a.customHeaders)),
      customBodyJson: Value(jsonEncode(a.customBody)),
      enableMemory: Value(a.enableMemory),
      memoryMode: Value(a.memoryMode),
      enableRecentChatsReference: Value(a.enableRecentChatsReference),
      recentChatsSummaryMessageCount: Value(a.recentChatsSummaryMessageCount),
      memoryRecordPrompt: Value(a.memoryRecordPrompt),
      presetMessagesJson: Value(
        jsonEncode(PresetMessage.encodeList(a.presetMessages)),
      ),
      regexRulesJson: Value(
        jsonEncode(a.regexRules.map((e) => e.toJson()).toList()),
      ),
      sortOrder: sortOrder,
      createdAt: a.createdAt,
      updatedAt: a.updatedAt,
    );
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
      messageIds: messageRows.map((m) => m.id).toList(),
      isPinned: row.isPinned,
      mcpServerIds: mcpRows.map((m) => m.serverId).toList(),
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
          messageRows?.map((m) => m['id'] as String).toList() ?? <String>[],
      isPinned: row['is_pinned'] == 1,
      mcpServerIds:
          mcpRows?.map((m) => m['server_id'] as String).toList() ?? <String>[],
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
}
