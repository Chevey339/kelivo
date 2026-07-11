import 'dart:io';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/database/database_installation_gate.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'generated_schema/schema.dart';
import 'generated_schema/schema_v1.dart' as v1;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('AppDatabase migrations', () {
    test('every frozen schema upgrades and validates step by step', () async {
      const versions = GeneratedHelper.versions;
      expect(versions, orderedEquals([1, AppDatabase.currentSchemaVersion]));

      for (final (index, fromVersion) in versions.indexed) {
        for (final toVersion in versions.skip(index + 1)) {
          final schema = await verifier.schemaAt(fromVersion);
          final database = AppDatabase(schema.newConnection());
          try {
            await verifier.migrateAndValidate(database, toVersion);
          } finally {
            await database.close();
            schema.close();
          }
        }
      }
    });

    test('v1 to v2 migration preserves user data', () async {
      final schema = await verifier.schemaAt(1);
      schema.rawDatabase.execute(
        'INSERT INTO conversation_rows ('
        'id, title, created_at, updated_at, is_pinned, truncate_index, '
        'version_selections_json, last_summarized_message_count, '
        'chat_suggestions_json) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);',
        ['conversation-1', 'Keep me', 100, 200, 0, -1, '{}', 0, '[]'],
      );
      schema.rawDatabase.execute(
        'INSERT INTO chat_storage_meta_rows (key, value) VALUES (?, ?);',
        ['migration_sentinel', 'keep'],
      );

      final database = AppDatabase(schema.newConnection());
      try {
        await verifier.migrateAndValidate(
          database,
          AppDatabase.currentSchemaVersion,
        );
        expect(
          await database
              .customSelect(
                'SELECT title FROM conversation_rows WHERE id = ?;',
                variables: [const Variable('conversation-1')],
              )
              .map((row) => row.read<String>('title'))
              .getSingle(),
          'Keep me',
        );
        expect(
          await database
              .customSelect(
                'SELECT value FROM chat_storage_meta_rows WHERE key = ?;',
                variables: [const Variable('migration_sentinel')],
              )
              .map((row) => row.read<String>('value'))
              .getSingle(),
          'keep',
        );
      } finally {
        await database.close();
        schema.close();
      }
    });

    test('installation gate upgrades an on-disk v1 database', () async {
      final directory = await Directory.systemTemp.createTemp(
        'kelivo_schema_migration_',
      );
      addTearDown(() async {
        if (await directory.exists()) await directory.delete(recursive: true);
      });
      final file = File(p.join(directory.path, AppDatabase.databaseFileName));
      final oldDatabase = v1.DatabaseAtV1(NativeDatabase(file));
      await oldDatabase.customStatement(
        'INSERT INTO chat_storage_meta_rows (key, value) VALUES (?, ?);',
        ['migration_sentinel', 'keep'],
      );
      await oldDatabase.close();

      final before = sqlite.sqlite3.open(
        file.path,
        mode: sqlite.OpenMode.readOnly,
      );
      expect(before.userVersion, 1);
      before.close();

      await DatabaseInstallationGate.ensureReady(appDataDirectory: directory);

      final after = sqlite.sqlite3.open(
        file.path,
        mode: sqlite.OpenMode.readOnly,
      );
      try {
        expect(after.userVersion, AppDatabase.currentSchemaVersion);
        expect(
          after.select(
            'SELECT value FROM chat_storage_meta_rows WHERE key = ?;',
            ['migration_sentinel'],
          ).single['value'],
          'keep',
        );
      } finally {
        after.close();
      }
      expect(
        ChatDatabaseRepository.inspectInstalledDatabase(file).databaseId,
        isA<String>(),
      );
    });
  });
}
