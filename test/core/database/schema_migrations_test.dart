import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/database/schema_migrations.dart';

import 'generated_schema/schema.dart';
import 'generated_schema/schema_v1.dart' as v1;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory workspace;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('schema-migrations-test');
  });

  tearDown(() async {
    if (await workspace.exists()) {
      await workspace.delete(recursive: true);
    }
  });

  File databasePath() =>
      File('${workspace.path}/${AppDatabase.databaseFileName}');

  /// Writes a real schema-1 database containing one conversation and returns it.
  Future<File> createV1Database({String conversationId = 'conv-1'}) async {
    final file = databasePath();
    final database = v1.DatabaseAtV1(NativeDatabase(file));
    try {
      await database.customStatement('PRAGMA user_version = 1;');
      await database.customStatement(
        'INSERT INTO conversation_rows '
        '(id, title, created_at, updated_at, is_pinned, truncate_index, '
        'version_selections_json, last_summarized_message_count, '
        'chat_suggestions_json, last_memory_extracted_order) '
        "VALUES ('$conversationId', 'Legacy chat', 1, 2, 0, -1, '{}', 0, "
        "'[]', -1);",
      );
    } finally {
      await database.close();
    }
    // NativeDatabase leaves the file in WAL mode; fold it back so the tests
    // below see a self-contained database, exactly like a shipped one.
    final raw = sqlite.sqlite3.open(file.path);
    try {
      raw.execute('PRAGMA wal_checkpoint(TRUNCATE);');
      raw.select('PRAGMA journal_mode = DELETE;');
    } finally {
      raw.close();
    }
    return file;
  }

  List<String> columnsOf(File file, String table) {
    final raw = sqlite.sqlite3.open(file.path, mode: sqlite.OpenMode.readOnly);
    try {
      return raw
          .select('PRAGMA table_info($table);')
          .map((row) => row['name'] as String)
          .toList(growable: false);
    } finally {
      raw.close();
    }
  }

  test('upgrades a schema 1 file to the current schema in place', () async {
    final file = await createV1Database();
    final before = columnsOf(file, 'conversation_rows');
    expect(before, isNot(contains('chat_model_provider')));

    final outcome = await SchemaMigrations.upgradeFileInPlace(file);

    expect(outcome.fromVersion, 1);
    expect(outcome.toVersion, AppDatabase.currentSchemaVersion);
    expect(outcome.upgraded, isTrue);
    expect(
      SchemaMigrations.readSchemaVersion(file),
      AppDatabase.currentSchemaVersion,
    );
    expect(columnsOf(file, 'conversation_rows'), [
      ...before,
      'chat_model_provider',
      'chat_model_id',
    ]);

    final raw = sqlite.sqlite3.open(file.path, mode: sqlite.OpenMode.readOnly);
    try {
      final rows = raw.select('SELECT * FROM conversation_rows;');
      expect(rows, hasLength(1));
      expect(rows.single['id'], 'conv-1');
      expect(rows.single['chat_model_provider'], isNull);
      expect(rows.single['chat_model_id'], isNull);
      expect(
        raw
            .select(
              "SELECT name FROM sqlite_master WHERE type = 'table' "
              "AND name = 'bridge_delivery_rows';",
            )
            .single['name'],
        'bridge_delivery_rows',
      );
      expect(
        raw
            .select(
              "SELECT name FROM sqlite_master WHERE type = 'index' "
              "AND name LIKE 'idx_bridge_deliveries_%' ORDER BY name;",
            )
            .map((row) => row['name']),
        [
          'idx_bridge_deliveries_conversation_created',
          'idx_bridge_deliveries_room_event',
        ],
      );
    } finally {
      raw.close();
    }
  });

  test('migrated shape matches a freshly created database', () async {
    final file = await createV1Database();
    final database = AppDatabase(AppDatabase.upgradeExecutor(file));
    try {
      await verifier.migrateAndValidate(
        database,
        AppDatabase.currentSchemaVersion,
        options: const ValidationOptions(validateDropped: true),
      );
    } finally {
      await database.close();
    }
  });

  test('upgrading is idempotent and does not rewrite a current file', () async {
    final file = await createV1Database();
    await SchemaMigrations.upgradeFileInPlace(file);
    final bytes = await file.readAsBytes();

    final second = await SchemaMigrations.upgradeFileInPlace(file);

    expect(second.upgraded, isFalse);
    expect(second.fromVersion, AppDatabase.currentSchemaVersion);
    expect(await file.readAsBytes(), bytes);
  });

  test('rejects an unpublished schema without touching the file', () async {
    final file = await createV1Database();
    final raw = sqlite.sqlite3.open(file.path);
    try {
      raw.userVersion = AppDatabase.currentSchemaVersion + 1;
    } finally {
      raw.close();
    }
    final bytes = await file.readAsBytes();

    await expectLater(
      SchemaMigrations.upgradeFileInPlace(file),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          'database_schema_version',
        ),
      ),
    );
    expect(await file.readAsBytes(), bytes);
  });

  group('migrateInstalledDatabase', () {
    test('upgrades and leaves no pre-migration copy behind', () async {
      final file = await createV1Database();

      final outcome = await ChatDatabaseRepository.migrateInstalledDatabase(
        file,
      );

      expect(outcome.fromVersion, 1);
      expect(outcome.upgraded, isTrue);
      expect(
        ChatDatabaseRepository.inspectInstalledDatabase(
          file,
          validateContents: true,
        ).schemaVersion,
        AppDatabase.currentSchemaVersion,
      );
      expect(
        await workspace
            .list()
            .where(
              (e) => e.path.contains(
                ChatDatabaseRepository.premigrationBackupPrefix,
              ),
            )
            .isEmpty,
        isTrue,
      );
    });

    test('a current-schema file is validated without being written', () async {
      final file = await createV1Database();
      await SchemaMigrations.upgradeFileInPlace(file);
      final modified = await file.lastModified();
      final bytes = await file.readAsBytes();

      final outcome = await ChatDatabaseRepository.migrateInstalledDatabase(
        file,
      );

      expect(outcome.upgraded, isFalse);
      expect(await file.readAsBytes(), bytes);
      expect(await file.lastModified(), modified);
    });

    test('rolls back to the original file when validation fails', () async {
      final file = await createV1Database();
      // Post-migration validation requires every table; dropping one makes the
      // upgraded database fail _validateRawStructure.
      final raw = sqlite.sqlite3.open(file.path);
      try {
        raw.execute('DROP TABLE preference_rows;');
        raw.execute('PRAGMA wal_checkpoint(TRUNCATE);');
      } finally {
        raw.close();
      }
      final bytes = await file.readAsBytes();

      await expectLater(
        ChatDatabaseRepository.migrateInstalledDatabase(file),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'database_migration_failed:1',
          ),
        ),
      );

      expect(SchemaMigrations.readSchemaVersion(file), 1);
      expect(await file.readAsBytes(), bytes);
      expect(
        await workspace
            .list()
            .where(
              (e) => e.path.contains(
                ChatDatabaseRepository.premigrationBackupPrefix,
              ),
            )
            .isEmpty,
        isTrue,
      );
    });
  });

  test('an ordinary open never migrates implicitly', () async {
    final file = await createV1Database();
    final database = AppDatabase.open(file: file);

    // The guard runs in drift's worker isolate, so the StateError arrives
    // wrapped in a DriftRemoteException.
    await expectLater(
      database.customSelect('SELECT 1;').getSingle(),
      throwsA(
        predicate(
          (e) => e.toString().contains('database_schema_version'),
          'reports database_schema_version',
        ),
      ),
    );
    await database.close();
    expect(SchemaMigrations.readSchemaVersion(file), 1);
  });
}
