import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import '../../utils/app_directories.dart';

part 'app_database.g.dart';

@TableIndex(name: 'idx_conversations_updated_at', columns: {#updatedAt})
@TableIndex(name: 'idx_conversations_assistant', columns: {#assistantId})
class ConversationRows extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  TextColumn get assistantId => text().nullable()();
  IntColumn get truncateIndex => integer().withDefault(const Constant(-1))();
  TextColumn get versionSelectionsJson =>
      text().withDefault(const Constant('{}'))();
  TextColumn get summary => text().nullable()();
  IntColumn get lastSummarizedMessageCount =>
      integer().withDefault(const Constant(0))();
  TextColumn get chatSuggestionsJson =>
      text().withDefault(const Constant('[]'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(
  name: 'idx_messages_conversation_order',
  columns: {#conversationId, #messageOrder},
)
@TableIndex(
  name: 'idx_messages_conversation_timestamp',
  columns: {#conversationId, #timestamp},
)
@TableIndex(name: 'idx_messages_group', columns: {#groupId})
class MessageRows extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId =>
      text().references(ConversationRows, #id, onDelete: KeyAction.cascade)();
  TextColumn get role => text()();
  TextColumn get content => text()();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get modelId => text().nullable()();
  TextColumn get providerId => text().nullable()();
  IntColumn get totalTokens => integer().nullable()();
  BoolColumn get isStreaming => boolean().withDefault(const Constant(false))();
  TextColumn get reasoningText => text().nullable()();
  DateTimeColumn get reasoningStartAt => dateTime().nullable()();
  DateTimeColumn get reasoningFinishedAt => dateTime().nullable()();
  TextColumn get translation => text().nullable()();
  TextColumn get reasoningSegmentsJson => text().nullable()();
  TextColumn get groupId => text().nullable()();
  IntColumn get version => integer().withDefault(const Constant(0))();
  IntColumn get promptTokens => integer().nullable()();
  IntColumn get completionTokens => integer().nullable()();
  IntColumn get cachedTokens => integer().nullable()();
  IntColumn get durationMs => integer().nullable()();
  IntColumn get messageOrder => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class AssistantRows extends Table {
  //--- Identifier & Display ---
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get avatar => text().nullable()();
  BoolColumn get useAssistantAvatar =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get useAssistantName =>
      boolean().withDefault(const Constant(false))();
  TextColumn get background => text().nullable()();

  // --- Model Selection ---
  TextColumn get chatModelProvider => text().nullable()();
  TextColumn get chatModelId => text().nullable()();

  // --- Request Params ---
  RealColumn get temperature => real().nullable()();
  RealColumn get topP => real().nullable()();
  IntColumn get contextMessageSize =>
      integer().withDefault(const Constant(64))();
  BoolColumn get limitContextMessages =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get streamOutput => boolean().withDefault(const Constant(true))();
  IntColumn get thinkingBudget => integer().nullable()();
  IntColumn get maxTokens => integer().nullable()();
  TextColumn get customHeadersJson =>
      text().withDefault(const Constant('[]'))();
  TextColumn get customBodyJson => text().withDefault(const Constant('[]'))();

  // --- Messages ---
  TextColumn get systemPrompt => text().withDefault(const Constant(''))();
  TextColumn get messageTemplate =>
      text().withDefault(const Constant('{{ message }}'))();
  TextColumn get presetMessagesJson =>
      text().withDefault(const Constant('[]'))();

  // --- Extended Functionality ---
  BoolColumn get searchEnabled =>
      boolean().withDefault(const Constant(false))();
  TextColumn get mcpServerIdsJson => text().withDefault(const Constant('[]'))();
  TextColumn get localToolIdsJson => text().withDefault(const Constant('[]'))();
  TextColumn get regexRulesJson => text().withDefault(const Constant('[]'))();

  // --- Memory ---
  BoolColumn get enableMemory => boolean().withDefault(const Constant(false))();
  BoolColumn get enableRecentChatsReference =>
      boolean().withDefault(const Constant(false))();
  IntColumn get recentChatsSummaryMessageCount =>
      integer().withDefault(const Constant(5))();
  TextColumn get memoryRecordPrompt => text().withDefault(const Constant(''))();

  // --- Sort & Timestamp ---
  IntColumn get sortOrder => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ConversationMcpServerRows extends Table {
  TextColumn get conversationId =>
      text().references(ConversationRows, #id, onDelete: KeyAction.cascade)();
  TextColumn get serverId => text()();
  IntColumn get ordinal => integer()();

  @override
  Set<Column<Object>> get primaryKey => {conversationId, serverId};
}

class ToolEventRows extends Table {
  TextColumn get messageId =>
      text().references(MessageRows, #id, onDelete: KeyAction.cascade)();
  TextColumn get eventsJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {messageId};
}

class GeminiThoughtSignatureRows extends Table {
  TextColumn get messageId =>
      text().references(MessageRows, #id, onDelete: KeyAction.cascade)();
  TextColumn get signature => text()();

  @override
  Set<Column<Object>> get primaryKey => {messageId};
}

class CacheRows extends Table {
  TextColumn get type => text()(); // e.g., 'ocr'
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {type, key};
}

class ChatStorageMetaRows extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    ConversationRows,
    MessageRows,
    AssistantRows,
    ConversationMcpServerRows,
    ToolEventRows,
    GeminiThoughtSignatureRows,
    CacheRows,
    ChatStorageMetaRows,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  static const databaseFileName = 'kelivo.sqlite';

  factory AppDatabase.open({File? file}) {
    final databaseFile = file;
    if (databaseFile != null) {
      return AppDatabase(_openExecutor(databaseFile));
    }
    return AppDatabase(
      LazyDatabase(() async {
        final dir = await AppDirectories.getAppDataDirectory();
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return _openExecutor(File('${dir.path}/$databaseFileName'));
      }),
    );
  }

  static QueryExecutor _openExecutor(File file) {
    return NativeDatabase.createInBackground(
      file,
      setup: (database) {
        database.execute('PRAGMA journal_mode = WAL;');
        database.execute('PRAGMA foreign_keys = ON;');
        database.execute('PRAGMA busy_timeout = 5000;');
      },
      readPool: 1,
    );
  }

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON;');
      await customStatement('PRAGMA busy_timeout = 5000;');
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(assistantRows);
        await migrator.createTable(cacheRows);
      }
    },
  );
}
