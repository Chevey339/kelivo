import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

part 'chat_database.g.dart';

class ChatConversations extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  IntColumn get createdAtMs => integer().named('created_at_ms')();
  IntColumn get updatedAtMs => integer().named('updated_at_ms')();
  BoolColumn get isPinned =>
      boolean().named('is_pinned').withDefault(const Constant(false))();
  TextColumn get mcpServerIdsJson =>
      text().named('mcp_server_ids_json').withDefault(const Constant('[]'))();
  TextColumn get assistantId => text().named('assistant_id').nullable()();
  IntColumn get truncateIndex =>
      integer().named('truncate_index').withDefault(const Constant(-1))();
  TextColumn get versionSelectionsJson => text()
      .named('version_selections_json')
      .withDefault(const Constant('{}'))();
  TextColumn get summary => text().nullable()();
  IntColumn get lastSummarizedMessageCount => integer()
      .named('last_summarized_message_count')
      .withDefault(const Constant(0))();
  TextColumn get chatSuggestionsJson =>
      text().named('chat_suggestions_json').withDefault(const Constant('[]'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ChatMessages extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId => text()
      .named('conversation_id')
      .references(ChatConversations, #id, onDelete: KeyAction.cascade)();
  TextColumn get role => text()();
  TextColumn get content => text()();
  IntColumn get timestampMs => integer().named('timestamp_ms')();
  TextColumn get modelId => text().named('model_id').nullable()();
  TextColumn get providerId => text().named('provider_id').nullable()();
  IntColumn get totalTokens => integer().named('total_tokens').nullable()();
  BoolColumn get isStreaming =>
      boolean().named('is_streaming').withDefault(const Constant(false))();
  TextColumn get reasoningText => text().named('reasoning_text').nullable()();
  IntColumn get reasoningStartAtMs =>
      integer().named('reasoning_start_at_ms').nullable()();
  IntColumn get reasoningFinishedAtMs =>
      integer().named('reasoning_finished_at_ms').nullable()();
  TextColumn get translation => text().nullable()();
  TextColumn get reasoningSegmentsJson =>
      text().named('reasoning_segments_json').nullable()();
  TextColumn get groupId => text().named('group_id').nullable()();
  IntColumn get version => integer().withDefault(const Constant(0))();
  IntColumn get promptTokens => integer().named('prompt_tokens').nullable()();
  IntColumn get completionTokens =>
      integer().named('completion_tokens').nullable()();
  IntColumn get cachedTokens => integer().named('cached_tokens').nullable()();
  IntColumn get durationMs => integer().named('duration_ms').nullable()();
  IntColumn get messageOrder => integer().named('message_order')();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ChatToolEvents extends Table {
  TextColumn get messageId => text()
      .named('message_id')
      .references(ChatMessages, #id, onDelete: KeyAction.cascade)();
  TextColumn get eventsJson => text().named('events_json')();

  @override
  Set<Column<Object>> get primaryKey => {messageId};
}

class ChatGeminiThoughtSignatures extends Table {
  TextColumn get messageId => text()
      .named('message_id')
      .references(ChatMessages, #id, onDelete: KeyAction.cascade)();
  TextColumn get signature => text()();

  @override
  Set<Column<Object>> get primaryKey => {messageId};
}

class ChatMeta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    ChatConversations,
    ChatMessages,
    ChatToolEvents,
    ChatGeminiThoughtSignatures,
    ChatMeta,
  ],
)
class ChatDatabase extends _$ChatDatabase {
  ChatDatabase(File file) : super(NativeDatabase(file));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
        await customStatement(
          'CREATE UNIQUE INDEX IF NOT EXISTS '
          'idx_chat_messages_conversation_order '
          'ON chat_messages(conversation_id, message_order)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_chat_messages_group '
          'ON chat_messages(conversation_id, group_id)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_chat_conversations_updated '
          'ON chat_conversations(updated_at_ms DESC)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_chat_conversations_assistant '
          'ON chat_conversations(assistant_id)',
        );
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }
}
