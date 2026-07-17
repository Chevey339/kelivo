import 'dart:io';
import 'dart:isolate';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/common.dart' show AllowedArgumentCount;

import '../../utils/app_directories.dart';

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
class MessageRows extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId =>
      text().references(ConversationRows, #id, onDelete: KeyAction.cascade)();
  TextColumn get role =>
      text()
      // ignore: recursive_getters
      .check(role.isNotValue(''))();
  TextColumn get content => text()();
  IntColumn get timestamp =>
      integer().map(const MicrosecondDateTimeConverter())();
  TextColumn get modelId => text().nullable()();
  TextColumn get providerId => text().nullable()();
  IntColumn get totalTokens => integer()
      // ignore: recursive_getters
      .check(totalTokens.isBiggerOrEqualValue(0))
      .nullable()();
  BoolColumn get isStreaming => boolean().withDefault(const Constant(false))();
  TextColumn get reasoningText => text().nullable()();
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
  TextColumn get conversationId => text()();
  TextColumn get revisionId => text()();
  IntColumn get ordinal =>
      integer()
      // ignore: recursive_getters
      .check(ordinal.isBiggerOrEqualValue(0))();
  TextColumn get kind => text().check(
    // ignore: recursive_getters
    kind.isIn(const ['text', 'reasoning', 'tool_call', 'tool_result']),
  )();
  TextColumn get payload => text()();
  IntColumn get createdAt =>
      integer().map(const MicrosecondDateTimeConverter())();
  IntColumn get updatedAt =>
      integer().map(const MicrosecondDateTimeConverter())();

  @override
  Set<Column<Object>> get primaryKey => {revisionId, ordinal};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {conversationId, revisionId, ordinal},
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

class MigrationRunRows extends Table {
  TextColumn get id => text()();
  TextColumn get sourceKind =>
      text()
      // ignore: recursive_getters
      .check(sourceKind.isIn(const ['hive', 'legacy_json']))();
  TextColumn get sourceHash => text()();
  TextColumn get status =>
      text()
      // ignore: recursive_getters
      .check(status.isIn(const ['building', 'completed', 'failed']))();
  IntColumn get startedAt =>
      integer().map(const MicrosecondDateTimeConverter())();
  IntColumn get completedAt =>
      integer().map(const MicrosecondDateTimeConverter()).nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {sourceKind, sourceHash},
  ];

  @override
  List<String> get customConstraints => [
    'CHECK (completed_at IS NULL OR completed_at >= started_at)',
  ];
}

@TableIndex(
  name: 'idx_migration_issues_run_kind',
  columns: {#migrationRunId, #kind, #id},
)
class MigrationIssueRows extends Table {
  TextColumn get id => text()();
  TextColumn get migrationRunId =>
      text().references(MigrationRunRows, #id, onDelete: KeyAction.cascade)();
  TextColumn get conversationId => text().nullable()();
  TextColumn get sourceEntityId => text().nullable()();
  TextColumn get kind => text()();
  TextColumn get severity =>
      text()
      // ignore: recursive_getters
      .check(severity.isIn(const ['warning', 'recovered', 'rejected']))();
  TextColumn get detailsJson => text().withDefault(const Constant('{}'))();
  IntColumn get createdAt =>
      integer().map(const MicrosecondDateTimeConverter())();

  @override
  Set<Column<Object>> get primaryKey => {id};
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

@DriftDatabase(
  tables: [
    ConversationRows,
    MessageRows,
    ConversationMcpServerRows,
    ToolEventRows,
    GeminiThoughtSignatureRows,
    ChatStorageMetaRows,
    MessagePartRows,
    ProviderArtifactRows,
    MigrationRunRows,
    MigrationIssueRows,
    GenerationRunRows,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  static const databaseFileName = 'kelivo.db';

  // Schema 11 is the first release-candidate SQLite contract. It deliberately
  // separates the final format from every unpublished schema 1-10 database.
  static const currentSchemaVersion = 11;
  // Keep SQLite's established 1000-page cadence explicit. At the usual 4 KiB
  // page size this starts a checkpoint around 4 MiB, but page size remains the
  // source of truth.
  static const walAutoCheckpointPages = 1000;
  // This limits retained journal/WAL storage after reset/checkpoint; it is not
  // a promise that an active WAL can never temporarily exceed 16 MiB.
  static const journalSizeLimitBytes = 16 << 20;
  static const busyTimeoutMillis = 5000;
  static const synchronousFull = 2;
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
        final installedSchema = database.userVersion;
        if (installedSchema != 0 &&
            installedSchema != AppDatabase.currentSchemaVersion) {
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
        database.execute('PRAGMA synchronous = FULL;');
        database.execute(
          'PRAGMA wal_autocheckpoint = $walAutoCheckpointPages;',
        );
        database.execute('PRAGMA journal_size_limit = $journalSizeLimitBytes;');
      },
    );
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
    onUpgrade: (_, _, _) async {
      throw StateError('database_schema_version');
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON;');
      await customStatement('PRAGMA busy_timeout = 5000;');
    },
  );
}
