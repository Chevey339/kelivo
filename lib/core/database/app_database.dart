import 'dart:io';
import 'dart:isolate';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/common.dart' show AllowedArgumentCount;

import '../../utils/app_directories.dart';
import 'app_database.steps.dart';

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
  name: 'idx_message_slots_conversation_created',
  columns: {#conversationId, #createdAt, #id},
)
class MessageSlotRows extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId =>
      text().references(ConversationRows, #id, onDelete: KeyAction.cascade)();
  TextColumn get role =>
      text()
      // ignore: recursive_getters
      .check(role.isIn(const ['user', 'assistant', 'system', 'tool']))();
  IntColumn get createdAt =>
      integer().map(const MicrosecondDateTimeConverter())();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {conversationId, id},
  ];
}

@TableIndex(
  name: 'idx_message_revisions_parent',
  columns: {#conversationId, #parentRevisionId, #id},
)
@TableIndex(
  name: 'idx_message_revisions_slot_version',
  columns: {
    #conversationId,
    #slotId,
    IndexedColumn(#revisionNo, orderBy: OrderingMode.desc),
    #id,
  },
)
class MessageRevisionRows extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId =>
      text().references(ConversationRows, #id, onDelete: KeyAction.cascade)();
  TextColumn get slotId => text()();
  TextColumn get parentRevisionId => text().nullable()();
  IntColumn get revisionNo =>
      integer()
      // ignore: recursive_getters
      .check(revisionNo.isBiggerOrEqualValue(0))();
  IntColumn get createdAt =>
      integer().map(const MicrosecondDateTimeConverter())();
  IntColumn get updatedAt =>
      integer().map(const MicrosecondDateTimeConverter())();
  IntColumn get finalizedAt =>
      integer().map(const MicrosecondDateTimeConverter()).nullable()();
  IntColumn get deletedAt =>
      integer().map(const MicrosecondDateTimeConverter()).nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {conversationId, id},
    {conversationId, slotId, revisionNo},
  ];

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (conversation_id, slot_id) '
        'REFERENCES message_slot_rows (conversation_id, id) '
        'DEFERRABLE INITIALLY DEFERRED',
    'FOREIGN KEY (conversation_id, parent_revision_id) '
        'REFERENCES message_revision_rows (conversation_id, id) '
        'DEFERRABLE INITIALLY DEFERRED',
    'CHECK (parent_revision_id IS NULL OR parent_revision_id <> id)',
    'CHECK (updated_at >= created_at)',
    'CHECK (finalized_at IS NULL OR finalized_at >= created_at)',
    'CHECK (deleted_at IS NULL OR deleted_at >= created_at)',
  ];
}

@TableIndex(
  name: 'idx_conversation_branches_leaf',
  columns: {#conversationId, #leafRevisionId, #id},
)
@TableIndex(
  name: 'idx_conversation_branches_parent',
  columns: {#conversationId, #parentBranchId, #id},
)
class ConversationBranchRows extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId =>
      text().references(ConversationRows, #id, onDelete: KeyAction.cascade)();
  TextColumn get parentBranchId => text().nullable()();
  TextColumn get forkedFromRevisionId => text().nullable()();
  TextColumn get leafRevisionId => text().nullable()();
  TextColumn get causalityKind => text().check(
    // ignore: recursive_getters
    causalityKind.isIn(const [
      'native',
      'legacy_visible_projection',
      'legacy_ambiguous',
    ]),
  )();
  IntColumn get createdAt =>
      integer().map(const MicrosecondDateTimeConverter())();
  IntColumn get deletedAt =>
      integer().map(const MicrosecondDateTimeConverter()).nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {conversationId, id},
  ];

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (conversation_id, parent_branch_id) '
        'REFERENCES conversation_branch_rows (conversation_id, id) '
        'DEFERRABLE INITIALLY DEFERRED',
    'FOREIGN KEY (conversation_id, forked_from_revision_id) '
        'REFERENCES message_revision_rows (conversation_id, id) '
        'DEFERRABLE INITIALLY DEFERRED',
    'FOREIGN KEY (conversation_id, leaf_revision_id) '
        'REFERENCES message_revision_rows (conversation_id, id) '
        'DEFERRABLE INITIALLY DEFERRED',
    'CHECK (parent_branch_id IS NULL OR parent_branch_id <> id)',
    'CHECK (deleted_at IS NULL OR deleted_at >= created_at)',
  ];
}

class ConversationStateRows extends Table {
  TextColumn get conversationId =>
      text().references(ConversationRows, #id, onDelete: KeyAction.cascade)();
  TextColumn get activeBranchId => text().nullable()();
  TextColumn get contextStartRevisionId => text().nullable()();
  IntColumn get stateRevision => integer()
      // ignore: recursive_getters
      .check(stateRevision.isBiggerOrEqualValue(0))
      .withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {conversationId};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (conversation_id, active_branch_id) '
        'REFERENCES conversation_branch_rows (conversation_id, id) '
        'DEFERRABLE INITIALLY DEFERRED',
    'FOREIGN KEY (conversation_id, context_start_revision_id) '
        'REFERENCES message_revision_rows (conversation_id, id) '
        'DEFERRABLE INITIALLY DEFERRED',
  ];
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
    'FOREIGN KEY (conversation_id, revision_id) '
        'REFERENCES message_revision_rows (conversation_id, id) '
        'ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED',
    'CHECK (updated_at >= created_at)',
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
    MessageSlotRows,
    MessageRevisionRows,
    ConversationBranchRows,
    ConversationStateRows,
    MessagePartRows,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  static const databaseFileName = 'kelivo.sqlite';

  // Version 2 established the Database Kernel v2 format boundary. Version 3
  // adds enforced invariants, stable ordering indexes, and microsecond time.
  // Version 4 adds the Message Graph identity and ancestry kernel while the
  // v3 rows remain available as an unpublished legacy migration source.
  static const messageGraphSchemaVersion = 4;
  static const messagePartsSchemaVersion = 5;
  static const currentSchemaVersion = messagePartsSchemaVersion;
  static const oldestMigratableSchemaVersion = 1;
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
    onUpgrade: stepByStep(
      from1To2: (migrator, schema) async {
        // No physical schema change: v2 freezes the first supported migration
        // boundary before later kernel versions add constraints and indexes.
      },
      from2To3: (migrator, schema) async {
        final foreignKeysEnabled = (await customSelect(
          'PRAGMA foreign_keys;',
        ).getSingle()).read<bool>('foreign_keys');
        if (foreignKeysEnabled) {
          await customStatement('PRAGMA foreign_keys = OFF;');
        }
        try {
          await transaction(() async {
            await migrator.alterTable(
              TableMigration(
                conversationRows,
                columnTransformer: {
                  conversationRows.createdAt: const CustomExpression<int>(
                    'created_at * 1000000',
                  ),
                  conversationRows.updatedAt: const CustomExpression<int>(
                    'updated_at * 1000000',
                  ),
                },
              ),
            );
            await migrator.alterTable(
              TableMigration(
                messageRows,
                columnTransformer: {
                  messageRows.timestamp: const CustomExpression<int>(
                    'timestamp * 1000000',
                  ),
                  messageRows.reasoningStartAt: const CustomExpression<int>(
                    'reasoning_start_at * 1000000',
                  ),
                  messageRows.reasoningFinishedAt: const CustomExpression<int>(
                    'reasoning_finished_at * 1000000',
                  ),
                },
              ),
            );
            await migrator.alterTable(
              TableMigration(conversationMcpServerRows),
            );

            await migrator.drop(idxConversationsUpdatedAt);
            await migrator.drop(idxMessagesConversationOrder);
            await migrator.drop(idxMessagesConversationTimestamp);
            await migrator.drop(idxMessagesGroup);
            await migrator.createIndex(idxConversationsUpdatedAt);
            await migrator.createIndex(idxMessagesConversationOrder);
            await migrator.createIndex(idxMessagesConversationTimestamp);
            await migrator.createIndex(idxMessagesGroup);
          });
        } finally {
          if (foreignKeysEnabled) {
            await customStatement('PRAGMA foreign_keys = ON;');
          }
        }
      },
      from3To4: (migrator, schema) async {
        await transaction(() async {
          await migrator.createTable(messageSlotRows);
          await migrator.createTable(messageRevisionRows);
          await migrator.createTable(conversationBranchRows);
          await migrator.createTable(conversationStateRows);
          await migrator.createIndex(idxMessageSlotsConversationCreated);
          await migrator.createIndex(idxMessageRevisionsParent);
          await migrator.createIndex(idxMessageRevisionsSlotVersion);
          await migrator.createIndex(idxConversationBranchesLeaf);
          await migrator.createIndex(idxConversationBranchesParent);
        });
      },
      from4To5: (migrator, schema) async {
        await transaction(() async {
          await migrator.createTable(messagePartRows);
          await migrator.createIndex(idxMessagePartsRevisionOrdinal);
        });
      },
    ),
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON;');
      await customStatement('PRAGMA busy_timeout = 5000;');
    },
  );
}
