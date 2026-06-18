import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import '../../database/chat_database.dart' hide ChatMessage;
import '../../models/chat_message.dart';
import '../../models/conversation.dart';

class ChatSqliteStore {
  ChatSqliteStore._(this._db);

  final Database _db;
  bool _inTransaction = false;

  static Future<ChatSqliteStore> open(File file) async {
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }

    final driftDb = ChatDatabase(file);
    await driftDb.customSelect('SELECT 1').getSingle();
    await driftDb.close();

    final db = sqlite3.open(file.path);
    db
      ..execute('PRAGMA foreign_keys = ON')
      ..execute('PRAGMA journal_mode = WAL');
    return ChatSqliteStore._(db);
  }

  void close() {
    _db.dispose();
  }

  bool get hasCompletedHiveMigration {
    return getMeta('hive_migration_complete_v1') == 'true';
  }

  String? getMeta(String key) {
    final row = _db.select(
      'SELECT value FROM chat_meta WHERE key = ? LIMIT 1',
      [key],
    );
    if (row.isEmpty) return null;
    return row.first['value']?.toString();
  }

  void setMeta(String key, String value) {
    _db.execute('INSERT OR REPLACE INTO chat_meta(key, value) VALUES(?, ?)', [
      key,
      value,
    ]);
  }

  void markHiveMigrationComplete() {
    setMeta('hive_migration_complete_v1', 'true');
  }

  List<Conversation> getAllConversations() {
    final rows = _db.select(
      'SELECT c.*, '
      '(SELECT json_group_array(id) FROM ('
      'SELECT id FROM chat_messages m '
      'WHERE m.conversation_id = c.id '
      'ORDER BY m.message_order'
      ')) AS message_ids_json '
      'FROM chat_conversations c '
      'ORDER BY c.updated_at_ms DESC',
    );
    return [for (final row in rows) _conversationFromRow(row)];
  }

  Conversation? getConversation(String id) {
    final rows = _db.select(
      'SELECT c.*, '
      '(SELECT json_group_array(id) FROM ('
      'SELECT id FROM chat_messages m '
      'WHERE m.conversation_id = c.id '
      'ORDER BY m.message_order'
      ')) AS message_ids_json '
      'FROM chat_conversations c '
      'WHERE c.id = ? '
      'LIMIT 1',
      [id],
    );
    if (rows.isEmpty) return null;
    return _conversationFromRow(rows.first);
  }

  int getMessageCount(String conversationId) {
    final rows = _db.select(
      'SELECT COUNT(*) AS count FROM chat_messages WHERE conversation_id = ?',
      [conversationId],
    );
    return (rows.first['count'] as int?) ?? 0;
  }

  int getMessageIndex(String conversationId, String messageId) {
    final rows = _db.select(
      'SELECT message_order FROM chat_messages '
      'WHERE conversation_id = ? AND id = ? LIMIT 1',
      [conversationId, messageId],
    );
    if (rows.isEmpty) return -1;
    return (rows.first['message_order'] as int?) ?? -1;
  }

  ChatMessage? getMessage(String id) {
    final rows = _db.select(
      'SELECT * FROM chat_messages WHERE id = ? LIMIT 1',
      [id],
    );
    if (rows.isEmpty) return null;
    return _messageFromRow(rows.first);
  }

  List<ChatMessage> getMessages(String conversationId) {
    final rows = _db.select(
      'SELECT * FROM chat_messages '
      'WHERE conversation_id = ? '
      'ORDER BY message_order',
      [conversationId],
    );
    return [for (final row in rows) _messageFromRow(row)];
  }

  List<ChatMessage> getMessagesRange(
    String conversationId, {
    required int start,
    required int limit,
  }) {
    if (limit <= 0) return const <ChatMessage>[];
    final safeStart = start < 0 ? 0 : start;
    final rows = _db.select(
      'SELECT * FROM chat_messages '
      'WHERE conversation_id = ? '
      'ORDER BY message_order '
      'LIMIT ? OFFSET ?',
      [conversationId, limit, safeStart],
    );
    return [for (final row in rows) _messageFromRow(row)];
  }

  List<ChatMessage> getRecentMessages(
    String conversationId, {
    required int limit,
  }) {
    if (limit <= 0) return const <ChatMessage>[];
    final rows = _db.select(
      'SELECT * FROM ('
      'SELECT * FROM chat_messages '
      'WHERE conversation_id = ? '
      'ORDER BY message_order DESC '
      'LIMIT ?'
      ') ORDER BY message_order',
      [conversationId, limit],
    );
    return [for (final row in rows) _messageFromRow(row)];
  }

  void resetStreamingFlags() {
    _db.execute(
      'UPDATE chat_messages SET is_streaming = 0 WHERE is_streaming = 1',
    );
  }

  Map<String, int> getFirstMessageIndicesForGroups(
    String conversationId,
    Iterable<String> groupIds,
  ) {
    final result = <String, int>{};
    for (final groupId in groupIds.where((id) => id.isNotEmpty)) {
      final rows = _db.select(
        'SELECT message_order FROM chat_messages '
        'WHERE conversation_id = ? AND COALESCE(group_id, id) = ? '
        'ORDER BY message_order LIMIT 1',
        [conversationId, groupId],
      );
      if (rows.isNotEmpty) {
        result[groupId] = (rows.first['message_order'] as int?) ?? 0;
      }
    }
    return result;
  }

  List<ChatMessage> getMessagesForGroups(
    String conversationId,
    Iterable<String> groupIds,
  ) {
    final result = <ChatMessage>[];
    for (final groupId in groupIds.where((id) => id.isNotEmpty)) {
      final rows = _db.select(
        'SELECT * FROM chat_messages '
        'WHERE conversation_id = ? AND COALESCE(group_id, id) = ? '
        'ORDER BY message_order',
        [conversationId, groupId],
      );
      result.addAll([for (final row in rows) _messageFromRow(row)]);
    }
    return result;
  }

  void putConversation(Conversation conversation) {
    _db.execute(_upsertConversationSql, _conversationArgs(conversation));
  }

  void putMessage(ChatMessage message, {int? order}) {
    final resolvedOrder = order ?? getMessageCount(message.conversationId);
    _db.execute(_upsertMessageSql, _messageArgs(message, resolvedOrder));
  }

  void restoreConversation(
    Conversation conversation,
    List<ChatMessage> messages,
  ) {
    transaction(() {
      _deleteConversation(conversation.id);
      final restored = conversation.copyWith(
        messageIds: messages.map((m) => m.id).toList(),
      );
      putConversation(restored);
      for (var i = 0; i < messages.length; i++) {
        putMessage(messages[i], order: i);
      }
    });
  }

  void addMessageToConversation(String conversationId, ChatMessage message) {
    transaction(() {
      final existing = getMessage(message.id);
      if (existing != null) return;
      putMessage(message);
      final conversation = getConversation(conversationId);
      if (conversation != null &&
          !conversation.messageIds.contains(message.id)) {
        putConversation(
          conversation.copyWith(
            messageIds: [...conversation.messageIds, message.id],
          ),
        );
      }
    });
  }

  void updateConversation(Conversation conversation) {
    putConversation(conversation);
  }

  void updateMessage(ChatMessage message) {
    final order = getMessageIndex(message.conversationId, message.id);
    if (order < 0) return;
    putMessage(message, order: order);
  }

  void deleteConversation(String id) {
    transaction(() {
      _deleteConversation(id);
    });
  }

  void _deleteConversation(String id) {
    _db.execute('DELETE FROM chat_conversations WHERE id = ?', [id]);
  }

  void deleteMessage(String messageId, {List<String>? remainingOrder}) {
    final message = getMessage(messageId);
    if (message == null) return;
    transaction(() {
      _db.execute('DELETE FROM chat_messages WHERE id = ?', [messageId]);
      if (remainingOrder == null) {
        _renumberMessages(message.conversationId);
      } else {
        replaceConversationOrder(message.conversationId, remainingOrder);
      }
    });
  }

  void replaceConversationOrder(
    String conversationId,
    List<String> messageIds,
  ) {
    transaction(() {
      for (var i = 0; i < messageIds.length; i++) {
        _db.execute(
          'UPDATE chat_messages SET message_order = ? '
          'WHERE conversation_id = ? AND id = ?',
          [i, conversationId, messageIds[i]],
        );
      }
    });
  }

  void clearAll() {
    transaction(() {
      _db.execute('DELETE FROM chat_tool_events');
      _db.execute('DELETE FROM chat_gemini_thought_signatures');
      _db.execute('DELETE FROM chat_messages');
      _db.execute('DELETE FROM chat_conversations');
      _db.execute('DELETE FROM chat_meta WHERE key != ?', [
        'hive_migration_complete_v1',
      ]);
    });
  }

  List<Map<String, dynamic>> getToolEvents(String messageId) {
    final rows = _db.select(
      'SELECT events_json FROM chat_tool_events WHERE message_id = ? LIMIT 1',
      [messageId],
    );
    if (rows.isEmpty) return const <Map<String, dynamic>>[];
    final decoded = jsonDecode((rows.first['events_json'] ?? '[]').toString());
    if (decoded is! List) return const <Map<String, dynamic>>[];
    return decoded
        .whereType<Map>()
        .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
        .toList();
  }

  void setToolEvents(String messageId, List<Map<String, dynamic>> events) {
    _db.execute(
      'INSERT OR REPLACE INTO chat_tool_events(message_id, events_json) '
      'VALUES(?, ?)',
      [messageId, jsonEncode(events)],
    );
  }

  void deleteToolEvents(String messageId) {
    _db.execute('DELETE FROM chat_tool_events WHERE message_id = ?', [
      messageId,
    ]);
  }

  String? getGeminiThoughtSignature(String messageId) {
    final rows = _db.select(
      'SELECT signature FROM chat_gemini_thought_signatures '
      'WHERE message_id = ? LIMIT 1',
      [messageId],
    );
    if (rows.isEmpty) return null;
    final value = rows.first['signature']?.toString();
    if (value == null || value.trim().isEmpty) return null;
    return value;
  }

  void setGeminiThoughtSignature(String messageId, String signature) {
    _db.execute(
      'INSERT OR REPLACE INTO chat_gemini_thought_signatures'
      '(message_id, signature) VALUES(?, ?)',
      [messageId, signature],
    );
  }

  void deleteGeminiThoughtSignature(String messageId) {
    _db.execute(
      'DELETE FROM chat_gemini_thought_signatures WHERE message_id = ?',
      [messageId],
    );
  }

  void transaction(void Function() run) {
    if (_inTransaction) {
      run();
      return;
    }

    _db.execute('BEGIN IMMEDIATE');
    _inTransaction = true;
    try {
      run();
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    } finally {
      _inTransaction = false;
    }
  }

  void _renumberMessages(String conversationId) {
    final ids = _db.select(
      'SELECT id FROM chat_messages '
      'WHERE conversation_id = ? '
      'ORDER BY message_order',
      [conversationId],
    );
    for (var i = 0; i < ids.length; i++) {
      _db.execute('UPDATE chat_messages SET message_order = ? WHERE id = ?', [
        i,
        ids[i]['id'],
      ]);
    }
  }

  Conversation _conversationFromRow(Row row) {
    return Conversation(
      id: row['id'] as String,
      title: row['title'] as String,
      createdAt: _date(row['created_at_ms'] as int),
      updatedAt: _date(row['updated_at_ms'] as int),
      messageIds: _stringList(row['message_ids_json']),
      isPinned: _bool(row['is_pinned']),
      mcpServerIds: _stringList(row['mcp_server_ids_json']),
      assistantId: row['assistant_id'] as String?,
      truncateIndex: row['truncate_index'] as int? ?? -1,
      versionSelections: _intMap(row['version_selections_json']),
      summary: row['summary'] as String?,
      lastSummarizedMessageCount:
          row['last_summarized_message_count'] as int? ?? 0,
      chatSuggestions: _stringList(row['chat_suggestions_json']),
    );
  }

  ChatMessage _messageFromRow(Row row) {
    return ChatMessage(
      id: row['id'] as String,
      role: row['role'] as String,
      content: row['content'] as String,
      timestamp: _date(row['timestamp_ms'] as int),
      modelId: row['model_id'] as String?,
      providerId: row['provider_id'] as String?,
      totalTokens: row['total_tokens'] as int?,
      conversationId: row['conversation_id'] as String,
      isStreaming: _bool(row['is_streaming']),
      reasoningText: row['reasoning_text'] as String?,
      reasoningStartAt: _nullableDate(row['reasoning_start_at_ms']),
      reasoningFinishedAt: _nullableDate(row['reasoning_finished_at_ms']),
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

  List<Object?> _conversationArgs(Conversation conversation) {
    return [
      conversation.id,
      conversation.title,
      conversation.createdAt.millisecondsSinceEpoch,
      conversation.updatedAt.millisecondsSinceEpoch,
      conversation.isPinned ? 1 : 0,
      jsonEncode(conversation.mcpServerIds),
      conversation.assistantId,
      conversation.truncateIndex,
      jsonEncode(conversation.versionSelections),
      conversation.summary,
      conversation.lastSummarizedMessageCount,
      jsonEncode(conversation.chatSuggestions),
    ];
  }

  List<Object?> _messageArgs(ChatMessage message, int order) {
    return [
      message.id,
      message.conversationId,
      message.role,
      message.content,
      message.timestamp.millisecondsSinceEpoch,
      message.modelId,
      message.providerId,
      message.totalTokens,
      message.isStreaming ? 1 : 0,
      message.reasoningText,
      message.reasoningStartAt?.millisecondsSinceEpoch,
      message.reasoningFinishedAt?.millisecondsSinceEpoch,
      message.translation,
      message.reasoningSegmentsJson,
      message.groupId,
      message.version,
      message.promptTokens,
      message.completionTokens,
      message.cachedTokens,
      message.durationMs,
      order,
    ];
  }

  static DateTime _date(int ms) => DateTime.fromMillisecondsSinceEpoch(ms);

  static DateTime? _nullableDate(Object? value) {
    if (value is int) return _date(value);
    return null;
  }

  static bool _bool(Object? value) => value == true || value == 1;

  static List<String> _stringList(Object? raw) {
    if (raw == null) return <String>[];
    final decoded = jsonDecode(raw.toString());
    if (decoded is! List) return <String>[];
    return decoded.map((e) => e.toString()).toList();
  }

  static Map<String, int> _intMap(Object? raw) {
    if (raw == null) return <String, int>{};
    final decoded = jsonDecode(raw.toString());
    if (decoded is! Map) return <String, int>{};
    return decoded.map(
      (key, value) => MapEntry(key.toString(), (value as num).toInt()),
    );
  }
}

const String _upsertConversationSql =
    'INSERT INTO chat_conversations('
    'id, title, created_at_ms, updated_at_ms, is_pinned, '
    'mcp_server_ids_json, assistant_id, truncate_index, '
    'version_selections_json, summary, last_summarized_message_count, '
    'chat_suggestions_json'
    ') VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) '
    'ON CONFLICT(id) DO UPDATE SET '
    'title = excluded.title, '
    'created_at_ms = excluded.created_at_ms, '
    'updated_at_ms = excluded.updated_at_ms, '
    'is_pinned = excluded.is_pinned, '
    'mcp_server_ids_json = excluded.mcp_server_ids_json, '
    'assistant_id = excluded.assistant_id, '
    'truncate_index = excluded.truncate_index, '
    'version_selections_json = excluded.version_selections_json, '
    'summary = excluded.summary, '
    'last_summarized_message_count = excluded.last_summarized_message_count, '
    'chat_suggestions_json = excluded.chat_suggestions_json';

const String _upsertMessageSql =
    'INSERT INTO chat_messages('
    'id, conversation_id, role, content, timestamp_ms, model_id, provider_id, '
    'total_tokens, is_streaming, reasoning_text, reasoning_start_at_ms, '
    'reasoning_finished_at_ms, translation, reasoning_segments_json, '
    'group_id, version, prompt_tokens, completion_tokens, cached_tokens, '
    'duration_ms, message_order'
    ') VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) '
    'ON CONFLICT(id) DO UPDATE SET '
    'conversation_id = excluded.conversation_id, '
    'role = excluded.role, '
    'content = excluded.content, '
    'timestamp_ms = excluded.timestamp_ms, '
    'model_id = excluded.model_id, '
    'provider_id = excluded.provider_id, '
    'total_tokens = excluded.total_tokens, '
    'is_streaming = excluded.is_streaming, '
    'reasoning_text = excluded.reasoning_text, '
    'reasoning_start_at_ms = excluded.reasoning_start_at_ms, '
    'reasoning_finished_at_ms = excluded.reasoning_finished_at_ms, '
    'translation = excluded.translation, '
    'reasoning_segments_json = excluded.reasoning_segments_json, '
    'group_id = excluded.group_id, '
    'version = excluded.version, '
    'prompt_tokens = excluded.prompt_tokens, '
    'completion_tokens = excluded.completion_tokens, '
    'cached_tokens = excluded.cached_tokens, '
    'duration_ms = excluded.duration_ms, '
    'message_order = excluded.message_order';
