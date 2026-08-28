import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/database/schema_migrations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory workspace;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('forward-compat-test');
  });

  tearDown(() async {
    if (await workspace.exists()) await workspace.delete(recursive: true);
  });

  /// Builds a current-schema database, then mutates it the way a hypothetical
  /// future build would: extra columns, an extra table, an extra index, and a
  /// bumped user_version.
  Future<File> createFutureDatabase() async {
    final file = File('${workspace.path}/${AppDatabase.databaseFileName}');
    final database = AppDatabase(NativeDatabase(file));
    await database.customSelect('SELECT 1;').getSingle();
    await database.customStatement(
      'INSERT INTO conversation_rows '
      '(id, title, created_at, updated_at, is_pinned, truncate_index, '
      'version_selections_json, last_summarized_message_count, '
      'chat_suggestions_json, last_memory_extracted_order) '
      "VALUES ('conv-1', 'Future chat', 1, 2, 0, -1, '{}', 0, '[]', -1);",
    );
    // A real exported snapshot carries this receipt; inspectPreparedSnapshot
    // requires it.
    await database.customStatement(
      'INSERT INTO chat_storage_meta_rows (key, value) '
      "VALUES ('hive_migration_complete_v1', 'true');",
    );
    await database.close();

    final raw = sqlite.sqlite3.open(file.path);
    raw.execute('ALTER TABLE conversation_rows ADD COLUMN future_flag TEXT;');
    raw.execute('ALTER TABLE conversation_rows ADD COLUMN future_note TEXT;');
    raw.execute(
      "UPDATE conversation_rows SET future_flag = 'x', future_note = 'y';",
    );
    raw.execute(
      'CREATE INDEX idx_future_flag ON conversation_rows (future_flag);',
    );
    raw.execute(
      'CREATE TABLE future_rows ('
      'id TEXT PRIMARY KEY, '
      'conversation_id TEXT REFERENCES conversation_rows (id) '
      'ON DELETE CASCADE);',
    );
    raw.execute("INSERT INTO future_rows VALUES ('f1', 'conv-1');");
    raw.execute('PRAGMA wal_checkpoint(TRUNCATE);');
    raw.select('PRAGMA journal_mode = DELETE;');
    raw.userVersion = AppDatabase.currentSchemaVersion + 1;
    raw.close();
    for (final suffix in const ['-wal', '-shm']) {
      final sidecar = File('${file.path}$suffix');
      if (await sidecar.exists()) await sidecar.delete();
    }
    return file;
  }

  group('classifyBackup', () {
    final current = AppDatabase.currentSchemaVersion;

    test('same version restores as-is', () {
      expect(
        SchemaMigrations.classifyBackup(schemaVersion: current),
        BackupSchemaVerdict.current,
      );
    });

    test('an older published version is migrated forward', () {
      expect(
        SchemaMigrations.classifyBackup(schemaVersion: 1),
        BackupSchemaVerdict.needsUpgrade,
      );
    });

    test('a newer version that vouches for us is forward compatible', () {
      expect(
        SchemaMigrations.classifyBackup(
          schemaVersion: current + 5,
          declaredMinimumReadable: current,
        ),
        BackupSchemaVerdict.forwardCompatible,
      );
      expect(
        SchemaMigrations.classifyBackup(
          schemaVersion: current + 1,
          declaredMinimumReadable: current - 1,
        ),
        BackupSchemaVerdict.forwardCompatible,
      );
    });

    test('a newer version that demands a newer build is unreadable', () {
      expect(
        SchemaMigrations.classifyBackup(
          schemaVersion: current + 2,
          declaredMinimumReadable: current + 1,
        ),
        BackupSchemaVerdict.unreadable,
      );
    });

    test('a newer version with no declaration needs consent', () {
      // Backups written before the declaration existed, or by a build that
      // omitted it: readable only on the user\'s say-so.
      expect(
        SchemaMigrations.classifyBackup(schemaVersion: current + 1),
        BackupSchemaVerdict.forwardUndeclared,
      );
    });

    test('an unpublished older version is refused, not guessed at', () {
      expect(
        SchemaMigrations.classifyBackup(schemaVersion: 0),
        BackupSchemaVerdict.unreadable,
      );
    });

    test('this build declares a minimum it can actually honour', () {
      // Shipping a declaration above our own version would tell every future
      // build we are unreadable.
      expect(
        SchemaMigrations.minimumReadableSchemaVersion,
        lessThanOrEqualTo(current),
      );
      expect(
        SchemaMigrations.isPublished(
          SchemaMigrations.minimumReadableSchemaVersion,
        ),
        isTrue,
      );
    });
  });

  test('strips a newer database down to this build\'s schema', () async {
    final file = await createFutureDatabase();
    expect(
      SchemaMigrations.readSchemaVersion(file),
      AppDatabase.currentSchemaVersion + 1,
    );

    await ChatDatabaseRepository.normalizeForwardCompatibleSnapshot(file);

    expect(
      SchemaMigrations.readSchemaVersion(file),
      AppDatabase.currentSchemaVersion,
    );

    final raw = sqlite.sqlite3.open(file.path, mode: sqlite.OpenMode.readOnly);
    try {
      final columns = raw
          .select('PRAGMA table_info(conversation_rows);')
          .map((row) => row['name'])
          .toList();
      expect(columns, isNot(contains('future_flag')));
      expect(columns, isNot(contains('future_note')));
      expect(
        columns,
        ChatDatabaseRepository.currentSchemaColumns['conversation_rows'],
        reason: 'exactly this build\'s columns, in order',
      );

      final tables = raw
          .select("SELECT name FROM sqlite_master WHERE type = 'table';")
          .map((row) => row['name'])
          .toList();
      expect(tables, isNot(contains('future_rows')));

      // The rows themselves survive: only the parts this build cannot
      // understand are dropped.
      final rows = raw.select('SELECT id, title FROM conversation_rows;');
      expect(rows, hasLength(1));
      expect(rows.single['id'], 'conv-1');
      expect(rows.single['title'], 'Future chat');
    } finally {
      raw.close();
    }
  });

  test('the normalized snapshot passes the ordinary validators', () async {
    final file = await createFutureDatabase();

    await ChatDatabaseRepository.normalizeForwardCompatibleSnapshot(file);

    // The whole point of normalizing: the single-version validators can now
    // run unchanged.
    final info = await ChatDatabaseRepository.inspectPreparedSnapshot(file);
    expect(info.schemaVersion, AppDatabase.currentSchemaVersion);
    expect(info.conversationCount, 1);
  });

  test('a normalized snapshot opens as an ordinary database', () async {
    final file = await createFutureDatabase();
    await ChatDatabaseRepository.normalizeForwardCompatibleSnapshot(file);

    final repository = ChatDatabaseRepository.open(file: file);
    try {
      await repository.ensureReady();
      final conversation = await repository.getConversation('conv-1');
      expect(conversation?.title, 'Future chat');
      expect(conversation?.chatModelProvider, isNull);
    } finally {
      await repository.close();
    }
  });

  test('normalizing leaves a current-schema database alone', () async {
    final file = File('${workspace.path}/${AppDatabase.databaseFileName}');
    final database = AppDatabase(NativeDatabase(file));
    await database.customSelect('SELECT 1;').getSingle();
    await database.customStatement(
      'INSERT INTO conversation_rows '
      '(id, title, created_at, updated_at, is_pinned, truncate_index, '
      'version_selections_json, last_summarized_message_count, '
      'chat_suggestions_json, last_memory_extracted_order) '
      "VALUES ('keep', 'Keep me', 1, 2, 0, -1, '{}', 0, '[]', -1);",
    );
    await database.close();
    await ChatDatabaseRepository.normalizeSnapshotJournal(file);

    await ChatDatabaseRepository.normalizeForwardCompatibleSnapshot(file);

    expect(
      SchemaMigrations.readSchemaVersion(file),
      AppDatabase.currentSchemaVersion,
    );
    final raw = sqlite.sqlite3.open(file.path, mode: sqlite.OpenMode.readOnly);
    try {
      // Structure and contents both untouched. (Byte equality would be wrong:
      // opening read-write bumps the file change counter.)
      for (final entry in ChatDatabaseRepository.currentSchemaColumns.entries) {
        expect(
          raw
              .select('PRAGMA table_info("${entry.key}");')
              .map((row) => row['name'])
              .toList(),
          entry.value,
          reason: entry.key,
        );
      }
      final rows = raw.select('SELECT id, title FROM conversation_rows;');
      expect(rows, hasLength(1));
      expect(rows.single['title'], 'Keep me');
    } finally {
      raw.close();
    }
  });
}
