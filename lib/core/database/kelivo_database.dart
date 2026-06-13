import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import '../../utils/app_directories.dart';

part 'kelivo_database.g.dart';

// ── Tables ──────────────────────────────────────────────────────────────────

@DataClassName('ConversationRow')
class Conversations extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get messageIds => text()();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  TextColumn get mcpServerIds => text()();
  TextColumn? get assistantId => text().nullable()();
  IntColumn get truncateIndex => integer().withDefault(const Constant(-1))();
  TextColumn get versionSelections => text()();
  TextColumn? get summary => text().nullable()();
  IntColumn get lastSummarizedMessageCount =>
      integer().withDefault(const Constant(0))();
  TextColumn get chatSuggestions => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('MessageRow')
class Messages extends Table {
  TextColumn get id => text()();
  TextColumn get role => text()();
  TextColumn get content => text()();
  IntColumn get timestamp => integer()();
  TextColumn? get modelId => text().nullable()();
  TextColumn? get providerId => text().nullable()();
  IntColumn? get totalTokens => integer().nullable()();
  TextColumn get conversationId =>
      text().references(Conversations, #id, onDelete: KeyAction.cascade)();
  BoolColumn get isStreaming => boolean().withDefault(const Constant(false))();
  TextColumn? get reasoningText => text().nullable()();
  IntColumn? get reasoningStartAt => integer().nullable()();
  IntColumn? get reasoningFinishedAt => integer().nullable()();
  TextColumn? get translation => text().nullable()();
  TextColumn? get reasoningSegmentsJson => text().nullable()();
  TextColumn? get groupId => text().nullable()();
  IntColumn get version => integer().withDefault(const Constant(0))();
  IntColumn? get promptTokens => integer().nullable()();
  IntColumn? get completionTokens => integer().nullable()();
  IntColumn? get cachedTokens => integer().nullable()();
  IntColumn? get durationMs => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ToolEventRow')
class ToolEvents extends Table {
  TextColumn get messageId =>
      text().references(Messages, #id, onDelete: KeyAction.cascade)();
  TextColumn get data => text()();
  TextColumn? get geminiThoughtSig => text().nullable()();

  @override
  Set<Column> get primaryKey => {messageId};
}

@DataClassName('MigrationMetaRow')
class MigrationMeta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

// ── Database ───────────────────────────────────────────────────────────────

@DriftDatabase(tables: [Conversations, Messages, ToolEvents, MigrationMeta])
class KelivoDatabase extends _$KelivoDatabase {
  KelivoDatabase() : super(_openConnection());

  KelivoDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA journal_mode = WAL');
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<bool> migrationCompleted() async {
    final rows =
        await (selectOnly(migrationMeta)
              ..addColumns([migrationMeta.value])
              ..where(migrationMeta.key.equals('migration_version')))
            .get();
    if (rows.isEmpty) return false;
    final val = rows.first.read<String>(migrationMeta.value);
    return val == '1';
  }

  Future<void> markMigrationCompleted() async {
    await into(migrationMeta).insert(
      MigrationMetaCompanion.insert(key: 'migration_version', value: '1'),
      mode: InsertMode.replace,
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await AppDirectories.getAppDataDirectory();
    final file = File(p.join(dir.path, 'kelivo.sqlite'));
    return NativeDatabase(file);
  });
}
