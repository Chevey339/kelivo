import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/database/app_database.dart';

import 'generated_schema/schema.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('frozen schema includes and matches current schema 11', () async {
    expect(GeneratedHelper.versions.last, AppDatabase.currentSchemaVersion);
    final database = AppDatabase(NativeDatabase.memory());
    try {
      await database.customSelect('SELECT 1;').getSingle();
      await verifier.migrateAndValidate(
        database,
        AppDatabase.currentSchemaVersion,
        options: const ValidationOptions(validateDropped: true),
      );
    } finally {
      await database.close();
    }
  });

  test('schema 10 migrates to the frozen schema 11 constraint', () async {
    final schema = await verifier.schemaAt(10);
    schema.rawDatabase.execute('''
      INSERT INTO migration_run_rows(
        id, source_kind, source_hash, status, started_at, completed_at
      ) VALUES ('run', 'hive', 'hash', 'completed', 1, 2);
    ''');
    final database = AppDatabase(schema.newConnection());
    try {
      await verifier.migrateAndValidate(
        database,
        AppDatabase.currentSchemaVersion,
        options: const ValidationOptions(validateDropped: true),
      );
      final row = await database
          .customSelect(
            "SELECT source_kind FROM migration_run_rows WHERE id = 'run';",
          )
          .getSingle();
      expect(row.read<String>('source_kind'), 'hive');
      await expectLater(
        database.customStatement('''
          INSERT INTO migration_run_rows(
            id, source_kind, source_hash, status, started_at
          ) VALUES ('old', 'sqlite_v1', 'old-hash', 'building', 1);
        '''),
        throwsA(isA<SqliteException>()),
      );
    } finally {
      await database.close();
      schema.close();
    }
  });
}
