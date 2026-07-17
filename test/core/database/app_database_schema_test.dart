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
    expect(GeneratedHelper.versions, [AppDatabase.currentSchemaVersion]);
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

  test('unpublished schema is rejected instead of migrated', () async {
    final database = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDatabase) {
          rawDatabase.userVersion = AppDatabase.currentSchemaVersion - 1;
        },
      ),
    );
    try {
      await expectLater(
        database.customSelect('SELECT 1;').getSingle(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'database_schema_version',
          ),
        ),
      );
    } finally {
      await database.close();
    }
  });
}
