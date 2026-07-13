import 'dart:io';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/database/database_installation_gate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  test(
    'installation gate creates and validates only the current schema',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'kelivo_current_schema_',
      );
      addTearDown(() async {
        if (await directory.exists()) await directory.delete(recursive: true);
      });

      await DatabaseInstallationGate.ensureReady(appDataDirectory: directory);

      final file = File(p.join(directory.path, AppDatabase.databaseFileName));
      final installed = ChatDatabaseRepository.inspectInstalledDatabase(file);
      expect(installed.schemaVersion, AppDatabase.currentSchemaVersion);
      expect(installed.databaseId, isNotEmpty);
    },
  );

  test(
    'installation gate rejects an unpublished SQLite schema without mutation',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'kelivo_reject_intermediate_schema_',
      );
      addTearDown(() async {
        if (await directory.exists()) await directory.delete(recursive: true);
      });
      final file = File(p.join(directory.path, AppDatabase.databaseFileName));
      final database = sqlite.sqlite3.open(file.path);
      database.execute('CREATE TABLE intermediate_only (value TEXT);');
      database.userVersion = AppDatabase.currentSchemaVersion - 1;
      database.close();

      await expectLater(
        DatabaseInstallationGate.ensureReady(appDataDirectory: directory),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'database_schema_version',
          ),
        ),
      );

      final after = sqlite.sqlite3.open(
        file.path,
        mode: sqlite.OpenMode.readOnly,
      );
      try {
        expect(after.userVersion, AppDatabase.currentSchemaVersion - 1);
        expect(
          after.select(
            "SELECT name FROM sqlite_master WHERE type='table' AND name=?;",
            ['intermediate_only'],
          ),
          hasLength(1),
        );
      } finally {
        after.close();
      }
    },
  );
}
