import 'dart:io';
import 'dart:isolate';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/common.dart' show AllowedArgumentCount, CommonDatabase;

import '../../utils/app_directories.dart';
import 'schema_versions.dart';

part 'app_database.g.dart';

typedef SqliteExecutionIsolateProbeResult = ({
  int samples,
  int openingIsolateCalls,
  int backgroundIsolateCalls,
});

class MicrosecondDateTimeConverter extends TypeConverter<DateTime, int> {
  const MicrosecondDateTimeConverter();

  @override
  DateTime fromSql(int fromDb) => DateTime.fromMicrosecondsSinceEpoch(fromDb);

  @override
  int toSql(DateTime value) => value.microsecondsSinceEpoch;
}

@TableIndex(
  name: 'idx_conversations_updated_at',
  columns: {
    IndexedColumn(#updatedAt, orderBy: OrderingMode.desc),
    IndexedColumn(#id, orderBy: OrderingMode.asc),
  },
)
@TableIndex(name: 'idx_conversations_assistant', columns: {#assistantId})
class ConversationRows extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  IntColumn get createdAt =>
      integer().map(const MicrosecondDateTimeConverter())();
  IntColumn get updatedAt =>
      integer().map(const MicrosecondDateTimeConverter())();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  TextColumn get assistantId => text().nullable()();
  IntColumn get truncateIndex => integer()
      // ignore: recursive_getters
      .check(truncateIndex.isBiggerOrEqualValue(-1))
      .withDefault(const Constant(-1))();
  TextColumn get versionSelectionsJson =>
      text().withDefault(const Constant('{}'))();
  TextColumn get summary => text().nullable()();
  IntColumn get lastSummarizedMessageCount => integer()
      // ignore: recursive_getters
      .check(lastSummarizedMessageCount.isBiggerOrEqualValue(0))
      .withDefault(const Constant(0))();
  TextColumn get chatSuggestionsJson =>
      text().withDefault(const Constant('[]'))();
  TextColumn get injectedMemoryHash => text().nullable()();
  IntColumn get lastMemoryExtractedOrder => integer()
      // ignore: recursive_getters
      .check(lastMemoryExtractedOrder.isBiggerOrEqualValue(-1))
      .withDefault(const Constant(-1))();
  // Per-conversation model override; null means inherit from the assistant,
  // then from the global default. Declared last so ALTER TABLE ADD COLUMN on a
  // migrated database yields the same column order as createAll on a fresh one
  // — ChatDatabaseRepository validates column order exactly.
  TextColumn get chatModelProvider => text().nullable()();
  TextColumn get chatModelId => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(
  name: 'idx_messages_conversation_order',
  columns: {#conversationId, #messageOrder, #id},
)
@TableIndex(
  name: 'idx_messages_conversation_timestamp',
  columns: {#conversationId, #timestamp, #id},
)
@TableIndex(
  name: 'idx_messages_group',
  columns: {#conversationId, #groupId, #version, #id},
)
@TableIndex.sql(
  'CREATE INDEX idx_message_rows_streaming '
  'ON message_rows (id) WHERE is_streaming = 1',
)
class MessageRows extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId =>
      text().references(ConversationRows, #id, onDelete: KeyAction.cascade)();
  TextColumn get role =>
      text()
      // ignore: recursive_getters
      .check(role.isNotValue(''))();
  IntColumn get timestamp =>
      integer().map(const MicrosecondDateTimeConverter())();
  TextColumn get modelId => text().nullable()();
  TextColumn get providerId => text().nullable()();
  IntColumn get totalTokens => integer()
      // ignore: recursive_getters
      .check(totalTokens.isBiggerOrEqualValue(0))
      .nullable()();
  BoolColumn get isStreaming => boolean().withDefault(const Constant(false))();
  IntColumn get reasoningStartAt =>
      integer().map(const MicrosecondDateTimeConverter()).nullable()();
  IntColumn get reasoningFinishedAt =>
      integer().map(const MicrosecondDateTimeConverter()).nullable()();
  TextColumn get translation => text().nullable()();
  TextColumn get reasoningSegmentsJson => text().nullable()();
  TextColumn get groupId => text().nullable()();
  IntColumn get version => integer()
      // ignore: recursive_getters
      .check(version.isBiggerOrEqualValue(0))
      .withDefault(const Constant(0))();
  IntColumn get promptTokens => integer()
      // ignore: recursive_getters
      .check(promptTokens.isBiggerOrEqualValue(0))
      .nullable()();
  IntColumn get completionTokens => integer()
      // ignore: recursive_getters
      .check(completionTokens.isBiggerOrEqualValue(0))
      .nullable()();
  IntColumn get cachedTokens => integer()
      // ignore: recursive_getters
      .check(cachedTokens.isBiggerOrEqualValue(0))
      .nullable()();
  IntColumn get durationMs => integer()
      // ignore: recursive_getters
      .check(durationMs.isBiggerOrEqualValue(0))
      .nullable()();
  IntColumn get messageOrder =>
      integer()
      // ignore: recursive_getters
      .check(messageOrder.isBiggerOrEqualValue(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {conversationId, messageOrder},
    {conversationId, groupId, version},
  ];
}

class ConversationMcpServerRows extends Table {
  TextColumn get conversationId =>
      text().references(ConversationRows, #id, onDelete: KeyAction.cascade)();
  TextColumn get serverId => text()();
  IntColumn get ordinal =>
      integer()
      // ignore: recursive_getters
      .check(ordinal.isBiggerOrEqualValue(0))();

  @override
  Set<Column<Object>> get primaryKey => {conversationId, serverId};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {conversationId, ordinal},
  ];
}

class ChatStorageMetaRows extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@TableIndex(
  name: 'idx_message_parts_revision_ordinal',
  columns: {#conversationId, #revisionId, #ordinal},
)
class MessagePartRows extends Table {
  IntColumn get partId => integer().autoIncrement()();
  TextColumn get conversationId => text()();
  TextColumn get revisionId => text()();
  IntColumn get ordinal =>
      integer()
      // ignore: recursive_getters
      .check(ordinal.isBiggerOrEqualValue(0))();
  TextColumn get kind => text().check(
    // Forward-compat: unknown future kinds persist as UnknownPart.
    // ignore: recursive_getters
    kind.isNotValue(''),
  )();
  TextColumn get payload => text()();
  IntColumn get createdAt =>
      integer().map(const MicrosecondDateTimeConverter())();
  IntColumn get updatedAt =>
      integer().map(const MicrosecondDateTimeConverter())();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {revisionId, ordinal},
  ];

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (revision_id) '
        'REFERENCES message_rows (id) '
        'ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED',
    'CHECK (updated_at >= created_at)',
  ];
}

@TableIndex(
  name: 'idx_provider_artifacts_revision_kind',
  columns: {#conversationId, #revisionId, #kind},
)
class ProviderArtifactRows extends Table {
  TextColumn get conversationId => text()();
  TextColumn get revisionId => text()();
  TextColumn get kind => text().check(
    // ignore: recursive_getters
    kind.isNotValue(''),
  )();
  TextColumn get payload => text()();
  IntColumn get createdAt =>
      integer().map(const MicrosecondDateTimeConverter())();
  IntColumn get updatedAt =>
      integer().map(const MicrosecondDateTimeConverter())();

  @override
  Set<Column<Object>> get primaryKey => {revisionId, kind};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (revision_id) '
        'REFERENCES message_rows (id) '
        'ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED',
    'CHECK (updated_at >= created_at)',
  ];
}

class AssetRows extends Table {
  TextColumn get id => text()();
  TextColumn get contentHash => text().unique()();
  TextColumn get path => text()();
  IntColumn get byteSize =>
      integer()
      // ignore: recursive_getters
      .check(byteSize.isBiggerOrEqualValue(0))();
  IntColumn get width => integer()
      // ignore: recursive_getters
      .check(width.isBiggerThanValue(0))
      .nullable()();
  IntColumn get height => integer()
      // ignore: recursive_getters
      .check(height.isBiggerThanValue(0))
      .nullable()();
  TextColumn get thumbnailPath => text().nullable()();
  IntColumn get createdAt =>
      integer().map(const MicrosecondDateTimeConverter())();
  IntColumn get lastReferencedAt =>
      integer().map(const MicrosecondDateTimeConverter())();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(name: 'idx_message_assets_asset', columns: {#assetId, #revisionId})
class MessageAssetRows extends Table {
  TextColumn get conversationId => text()();
  TextColumn get revisionId =>
      text().references(MessageRows, #id, onDelete: KeyAction.cascade)();
  TextColumn get assetId =>
      text().references(AssetRows, #id, onDelete: KeyAction.cascade)();
  TextColumn get kind =>
      text()
      // ignore: recursive_getters
      .check(kind.isNotValue(''))();

  @override
  Set<Column<Object>> get primaryKey => {revisionId, assetId, kind};
}

class AssetGcRows extends Table {
  TextColumn get assetId =>
      text().references(AssetRows, #id, onDelete: KeyAction.cascade)();
  IntColumn get notBefore =>
      integer().map(const MicrosecondDateTimeConverter())();
  IntColumn get attempts => integer()
      // ignore: recursive_getters
      .check(attempts.isBiggerOrEqualValue(0))
      .withDefault(const Constant(0))();
  IntColumn get generation => integer()
      // ignore: recursive_getters
      .check(generation.isBiggerOrEqualValue(0))
      .withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {assetId};
}

class GcAuditRows extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get kind => text()();
  TextColumn get entityId => text()();
  IntColumn get completedAt =>
      integer().map(const MicrosecondDateTimeConverter())();
}

class AssetReferenceDirtyRows extends Table {
  TextColumn get revisionId =>
      text().references(MessageRows, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column<Object>> get primaryKey => {revisionId};
}

@TableIndex.sql(
  'CREATE UNIQUE INDEX idx_generation_runs_active_target '
  'ON generation_run_rows (conversation_id, target_revision_id) '
  "WHERE state IN ('preparing', 'requesting', 'streaming', 'waiting_tool')",
)
@TableIndex(
  name: 'idx_generation_runs_state_updated',
  columns: {#state, #updatedAt, #id},
)
class GenerationRunRows extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId =>
      text().references(ConversationRows, #id, onDelete: KeyAction.cascade)();
  TextColumn get targetRevisionId => text()();
  TextColumn get state => text().check(
    // ignore: recursive_getters
    state.isIn(const [
      'preparing',
      'requesting',
      'streaming',
      'waiting_tool',
      'completed',
      'failed',
      'cancelled',
      'interrupted',
    ]),
  )();
  IntColumn get stateRevision => integer()
      // ignore: recursive_getters
      .check(stateRevision.isBiggerOrEqualValue(0))
      .withDefault(const Constant(0))();
  IntColumn get checkpointSeq => integer()
      // ignore: recursive_getters
      .check(checkpointSeq.isBiggerOrEqualValue(0))
      .withDefault(const Constant(0))();
  TextColumn get errorCode => text().nullable()();
  IntColumn get createdAt =>
      integer().map(const MicrosecondDateTimeConverter())();
  IntColumn get updatedAt =>
      integer().map(const MicrosecondDateTimeConverter())();
  IntColumn get terminalAt =>
      integer().map(const MicrosecondDateTimeConverter()).nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (target_revision_id) '
        'REFERENCES message_rows (id) '
        'DEFERRABLE INITIALLY DEFERRED',
    'CHECK (updated_at >= created_at)',
    'CHECK (terminal_at IS NULL OR terminal_at >= created_at)',
    "CHECK ((state IN ('preparing', 'requesting', 'streaming', "
        "'waiting_tool') AND terminal_at IS NULL) OR "
        "(state IN ('completed', 'failed', 'cancelled', 'interrupted') "
        'AND terminal_at IS NOT NULL))',
    "CHECK (error_code IS NULL OR (length(error_code) BETWEEN 1 AND 128 "
        "AND state IN ('failed', 'cancelled', 'interrupted')))",
  ];
}

@TableIndex(
  name: 'idx_bridge_deliveries_room_event',
  columns: {#originInstanceId, #roomEventId},
)
@TableIndex(
  name: 'idx_bridge_deliveries_conversation_created',
  columns: {#conversationId, #createdAt},
)
class BridgeDeliveryRows extends Table {
  TextColumn get originSystem =>
      text()
      // ignore: recursive_getters
      .check(originSystem.isNotValue(''))();
  TextColumn get originInstanceId =>
      text()
      // ignore: recursive_getters
      .check(originInstanceId.isNotValue(''))();
  TextColumn get idempotencyKey =>
      text()
      // ignore: recursive_getters
      .check(idempotencyKey.isNotValue(''))();
  TextColumn get requestFingerprint => text()();
  TextColumn get roomEventId =>
      text()
      // ignore: recursive_getters
      .check(roomEventId.isNotValue(''))();
  TextColumn get roomId =>
      text()
      // ignore: recursive_getters
      .check(roomId.isNotValue(''))();
  TextColumn get conversationId =>
      text().references(ConversationRows, #id, onDelete: KeyAction.cascade)();
  @ReferenceName('bridgeUserDeliveries')
  TextColumn get userRevisionId =>
      text().references(MessageRows, #id, onDelete: KeyAction.cascade)();
  @ReferenceName('bridgeAssistantDeliveries')
  TextColumn get assistantRevisionId =>
      text().references(MessageRows, #id, onDelete: KeyAction.cascade)();
  TextColumn get generationRunId =>
      text().references(GenerationRunRows, #id, onDelete: KeyAction.cascade)();
  TextColumn get state => text().check(
    // ignore: recursive_getters
    state.isIn(const [
      'preparing',
      'requesting',
      'streaming',
      'waiting_tool',
      'completed',
      'failed',
      'cancelled',
      'interrupted',
    ]),
  )();
  IntColumn get createdAt =>
      integer().map(const MicrosecondDateTimeConverter())();
  IntColumn get updatedAt =>
      integer().map(const MicrosecondDateTimeConverter())();

  @override
  Set<Column<Object>> get primaryKey => {originInstanceId, idempotencyKey};

  @override
  List<String> get customConstraints => [
    'CHECK (length(request_fingerprint) = 64)',
    'CHECK (updated_at >= created_at)',
  ];
}

class AssistantRows extends Table {
  TextColumn get id => text()();
  IntColumn get sortOrder =>
      integer()
      // ignore: recursive_getters
      .check(sortOrder.isBiggerOrEqualValue(0))();
  TextColumn get payload => text()();
  IntColumn get updatedAt =>
      integer().map(const MicrosecondDateTimeConverter())();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ProviderRows extends Table {
  TextColumn get providerKey => text()();
  IntColumn get sortOrder =>
      integer()
      // ignore: recursive_getters
      .check(sortOrder.isBiggerOrEqualValue(0))();
  TextColumn get payload => text()();
  IntColumn get updatedAt =>
      integer().map(const MicrosecondDateTimeConverter())();

  @override
  Set<Column<Object>> get primaryKey => {providerKey};
}

class ProviderGroupRows extends Table {
  TextColumn get id => text()();
  IntColumn get sortOrder =>
      integer()
      // ignore: recursive_getters
      .check(sortOrder.isBiggerOrEqualValue(0))();
  TextColumn get payload => text()();
  IntColumn get updatedAt =>
      integer().map(const MicrosecondDateTimeConverter())();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class McpServerRows extends Table {
  TextColumn get id => text()();
  IntColumn get sortOrder =>
      integer()
      // ignore: recursive_getters
      .check(sortOrder.isBiggerOrEqualValue(0))();
  TextColumn get payload => text()();
  IntColumn get updatedAt =>
      integer().map(const MicrosecondDateTimeConverter())();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class WorldBookRows extends Table {
  TextColumn get id => text()();
  IntColumn get sortOrder =>
      integer()
      // ignore: recursive_getters
      .check(sortOrder.isBiggerOrEqualValue(0))();
  TextColumn get payload => text()();
  IntColumn get updatedAt =>
      integer().map(const MicrosecondDateTimeConverter())();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(
  name: 'idx_assistant_memories_assistant',
  columns: {#assistantId, #id},
)
class AssistantMemoryRows extends Table {
  TextColumn get id => text()();
  IntColumn get sortOrder =>
      integer()
      // ignore: recursive_getters
      .check(sortOrder.isBiggerOrEqualValue(0))();
  TextColumn get assistantId => text()();
  TextColumn get payload => text()();
  IntColumn get updatedAt =>
      integer().map(const MicrosecondDateTimeConverter())();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class QuickPhraseRows extends Table {
  TextColumn get id => text()();
  IntColumn get sortOrder =>
      integer()
      // ignore: recursive_getters
      .check(sortOrder.isBiggerOrEqualValue(0))();
  TextColumn get payload => text()();
  IntColumn get updatedAt =>
      integer().map(const MicrosecondDateTimeConverter())();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class SearchServiceRows extends Table {
  TextColumn get id => text()();
  IntColumn get sortOrder =>
      integer()
      // ignore: recursive_getters
      .check(sortOrder.isBiggerOrEqualValue(0))();
  TextColumn get payload => text()();
  IntColumn get updatedAt =>
      integer().map(const MicrosecondDateTimeConverter())();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class TtsServiceRows extends Table {
  TextColumn get id => text()();
  IntColumn get sortOrder =>
      integer()
      // ignore: recursive_getters
      .check(sortOrder.isBiggerOrEqualValue(0))();
  TextColumn get payload => text()();
  IntColumn get updatedAt =>
      integer().map(const MicrosecondDateTimeConverter())();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class InstructionInjectionRows extends Table {
  TextColumn get id => text()();
  IntColumn get sortOrder =>
      integer()
      // ignore: recursive_getters
      .check(sortOrder.isBiggerOrEqualValue(0))();
  TextColumn get payload => text()();
  IntColumn get updatedAt =>
      integer().map(const MicrosecondDateTimeConverter())();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class AssistantTagRows extends Table {
  TextColumn get id => text()();
  IntColumn get sortOrder =>
      integer()
      // ignore: recursive_getters
      .check(sortOrder.isBiggerOrEqualValue(0))();
  TextColumn get payload => text()();
  IntColumn get updatedAt =>
      integer().map(const MicrosecondDateTimeConverter())();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class PreferenceRows extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  IntColumn get updatedAt =>
      integer().map(const MicrosecondDateTimeConverter())();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@TableIndex(
  name: 'idx_memory_entries_visible',
  columns: {#status, #type, #scope, #assistantId},
)
@TableIndex(
  name: 'idx_memory_entries_recent',
  columns: {#status, #type, #entryUpdatedAt, #id},
)
@TableIndex(
  name: 'idx_memory_entries_dedupe',
  columns: {#scope, #assistantId, #type, #contentNormalized},
)
class MemoryEntryRows extends Table {
  TextColumn get id => text()();
  IntColumn get sortOrder =>
      integer()
      // ignore: recursive_getters
      .check(sortOrder.isBiggerOrEqualValue(0))();
  TextColumn get scope => text().check(
    // ignore: recursive_getters
    scope.isIn(const ['global', 'assistant']),
  )();
  TextColumn get assistantId => text().nullable()();
  TextColumn get type => text().check(
    // ignore: recursive_getters
    type.isIn(const ['identity', 'workflow', 'voice', 'instruction']),
  )();
  TextColumn get status => text().check(
    // ignore: recursive_getters
    status.isIn(const ['active', 'archived']),
  )();
  TextColumn get content => text()();
  TextColumn get contentNormalized => text()();
  IntColumn get entryCreatedAt =>
      integer().map(const MicrosecondDateTimeConverter())();
  IntColumn get entryUpdatedAt =>
      integer().map(const MicrosecondDateTimeConverter())();
  TextColumn get payload => text()();
  IntColumn get updatedAt =>
      integer().map(const MicrosecondDateTimeConverter())();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    "CHECK ((scope = 'global' AND assistant_id IS NULL) OR "
        "(scope = 'assistant' AND assistant_id IS NOT NULL))",
    'CHECK (entry_updated_at >= entry_created_at)',
  ];
}

class UserProfileFieldRows extends Table {
  TextColumn get id => text()(); // = field key, e.g. preferred_name
  IntColumn get sortOrder =>
      integer()
      // ignore: recursive_getters
      .check(sortOrder.isBiggerOrEqualValue(0))();
  TextColumn get payload => text()();
  IntColumn get updatedAt =>
      integer().map(const MicrosecondDateTimeConverter())();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(
  name: 'idx_message_prompts_conversation_snapshot',
  columns: {#conversationId, #carriesMemorySnapshot},
)
class MessagePromptRows extends Table {
  TextColumn get revisionId => text()();
  TextColumn get conversationId => text()();
  TextColumn get payload => text()();
  BoolColumn get carriesMemorySnapshot =>
      boolean().withDefault(const Constant(false))();
  IntColumn get createdAt =>
      integer().map(const MicrosecondDateTimeConverter())();

  @override
  Set<Column<Object>> get primaryKey => {revisionId};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (revision_id) '
        'REFERENCES message_rows (id) '
        'ON DELETE CASCADE',
  ];
}

@DriftDatabase(
  tables: [
    ConversationRows,
    MessageRows,
    ConversationMcpServerRows,
    ChatStorageMetaRows,
    MessagePartRows,
    ProviderArtifactRows,
    AssetRows,
    MessageAssetRows,
    AssetGcRows,
    GcAuditRows,
    AssetReferenceDirtyRows,
    GenerationRunRows,
    BridgeDeliveryRows,
    AssistantRows,
    ProviderRows,
    ProviderGroupRows,
    McpServerRows,
    WorldBookRows,
    AssistantMemoryRows,
    QuickPhraseRows,
    SearchServiceRows,
    TtsServiceRows,
    InstructionInjectionRows,
    AssistantTagRows,
    PreferenceRows,
    MemoryEntryRows,
    UserProfileFieldRows,
    MessagePromptRows,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  static const databaseFileName = 'kelivo.db';

  // Schema 1 is the first published SQLite contract; schema 2 adds the
  // per-conversation model override; schema 3 adds durable native-bridge
  // delivery mappings. Every version outside
  // [publishedSchemaVersions] belongs to an unpublished or future format and is
  // rejected.
  static const currentSchemaVersion = 3;

  /// Every schema that has ever shipped. A file at any of these can be
  /// upgraded by `SchemaMigrations`; anything else is rejected outright.
  static const publishedSchemaVersions = <int>{1, 2, 3};

  /// Whether a live application connection may use a file as-is: either freshly
  /// created (0) or already at the current schema.
  ///
  /// Upgrades never happen implicitly on an ordinary open — they are performed
  /// only by `SchemaMigrations`, through [upgradeExecutor].
  static bool acceptsLiveSchema(int userVersion) =>
      userVersion == 0 || userVersion == currentSchemaVersion;
  // Keep SQLite's established 1000-page cadence explicit. At the usual 4 KiB
  // page size this starts a checkpoint around 4 MiB, but page size remains the
  // source of truth.
  static const walAutoCheckpointPages = 1000;
  // This limits retained journal/WAL storage after reset/checkpoint; it is not
  // a promise that an active WAL can never temporarily exceed 16 MiB.
  static const journalSizeLimitBytes = 16 << 20;
  static const busyTimeoutMillis = 5000;
  // Under WAL, NORMAL still guarantees crash consistency; a power loss can
  // only drop transactions since the last checkpoint, which the
  // generation-run recovery path already tolerates. FULL would add an fsync
  // per write transaction on the streaming hot path.
  static const synchronousNormal = 1;
  static const _executionIsolateProbeFunction =
      'kelivo_sqlite_on_opening_isolate';
  static const _maxExecutionIsolateProbeSamples = 1000;

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
    final openingIsolatePort = Isolate.current.controlPort;
    return NativeDatabase.createInBackground(
      file,
      setup: (database) {
        if (!AppDatabase.acceptsLiveSchema(database.userVersion)) {
          throw StateError('database_schema_version');
        }
        // This callback is registered and invoked by SQLite on drift's worker
        // isolate. Keep it non-deterministic so a multi-row profile query
        // cannot be folded into a single callback by SQLite.
        database.createFunction(
          functionName: _executionIsolateProbeFunction,
          argumentCount: const AllowedArgumentCount(0),
          deterministic: false,
          directOnly: true,
          function: (_) =>
              Isolate.current.controlPort == openingIsolatePort ? 1 : 0,
        );
        database.execute('PRAGMA journal_mode = WAL;');
        database.execute('PRAGMA foreign_keys = ON;');
        database.execute('PRAGMA busy_timeout = $busyTimeoutMillis;');
        database.execute('PRAGMA synchronous = NORMAL;');
        database.execute(
          'PRAGMA wal_autocheckpoint = $walAutoCheckpointPages;',
        );
        database.execute('PRAGMA journal_size_limit = $journalSizeLimitBytes;');
      },
    );
  }

  /// An executor that admits any published schema so drift's migrator can run.
  ///
  /// Only `SchemaMigrations` may use this. Every other connection goes through
  /// [_openExecutor], which rejects a file that is not already current.
  static QueryExecutor upgradeExecutor(File file) =>
      NativeDatabase.createInBackground(file, setup: _migrationSetup);

  /// Setup for [upgradeExecutor].
  ///
  /// Must stay a capture-free static tear-off: `createInBackground` sends this
  /// closure to drift's worker isolate.
  ///
  /// Deliberately does not set `journal_mode = WAL`. A backup snapshot arrives
  /// in DELETE mode and has to leave in DELETE mode, and `synchronous = FULL`
  /// is the right trade for a one-shot structural rewrite.
  static void _migrationSetup(CommonDatabase database) {
    final installedSchema = database.userVersion;
    if (installedSchema != 0 &&
        !AppDatabase.publishedSchemaVersions.contains(installedSchema)) {
      throw StateError('database_schema_version');
    }
    database.execute('PRAGMA foreign_keys = ON;');
    database.execute('PRAGMA busy_timeout = $busyTimeoutMillis;');
    database.execute('PRAGMA synchronous = FULL;');
  }

  /// Samples the isolate executing callbacks on the live SQLite connection.
  ///
  /// The opening isolate is the Flutter UI isolate in the profile harness.
  Future<SqliteExecutionIsolateProbeResult> probeExecutionIsolate({
    int samples = 64,
  }) async {
    RangeError.checkValueInInterval(
      samples,
      1,
      _maxExecutionIsolateProbeSamples,
      'samples',
    );
    final row = await customSelect(
      '''
WITH RECURSIVE probe(sample) AS (
  VALUES (1)
  UNION ALL
  SELECT sample + 1 FROM probe WHERE sample < ?
)
SELECT
  COUNT(*) AS sample_count,
  COALESCE(SUM($_executionIsolateProbeFunction()), 0)
    AS opening_isolate_calls
FROM probe;
''',
      variables: [Variable.withInt(samples)],
    ).getSingle();
    final sampleCount = row.read<int>('sample_count');
    final openingIsolateCalls = row.read<int>('opening_isolate_calls');
    return (
      samples: sampleCount,
      openingIsolateCalls: openingIsolateCalls,
      backgroundIsolateCalls: sampleCount - openingIsolateCalls,
    );
  }

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    // Reachable only through [upgradeExecutor]; every other executor rejects a
    // non-current file before drift's migrator runs. See SchemaMigrations for
    // the procedure that adds a version. onDowngrade stays unset so drift's
    // default (throw) applies.
    onUpgrade: stepByStep(
      from1To2: (m, schema) async {
        await m.addColumn(
          schema.conversationRows,
          schema.conversationRows.chatModelProvider,
        );
        await m.addColumn(
          schema.conversationRows,
          schema.conversationRows.chatModelId,
        );
      },
      from2To3: (m, schema) async {
        await m.createTable(schema.bridgeDeliveryRows);
        await m.create(schema.idxBridgeDeliveriesRoomEvent);
        await m.create(schema.idxBridgeDeliveriesConversationCreated);
      },
    ),
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON;');
      await customStatement('PRAGMA busy_timeout = 5000;');
    },
  );
}
