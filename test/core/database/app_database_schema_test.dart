import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:Kelivo/core/database/app_database.dart';

import 'generated_schema/schema.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('frozen schemas cover every published version', () async {
    // Guards the release procedure in SchemaMigrations: bumping
    // currentSchemaVersion without re-running `drift_dev schema dump` and
    // `schema generate` fails here rather than at a user's next launch.
    expect(
      GeneratedHelper.versions.toSet(),
      AppDatabase.publishedSchemaVersions,
    );
    expect(GeneratedHelper.versions.last, AppDatabase.currentSchemaVersion);
    expect(
      AppDatabase.publishedSchemaVersions,
      contains(AppDatabase.currentSchemaVersion),
    );
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

  /// Opens a database file stamped at [version] through the real application
  /// executor and returns the error it reports, or null if it opened.
  ///
  /// `NativeDatabase.memory` bypasses the guard in `_openExecutor`, so only a
  /// file-backed open exercises it.
  Future<Object?> openAtVersion(int version) async {
    final directory = await Directory.systemTemp.createTemp('kelivo_schema_');
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final file = File(p.join(directory.path, AppDatabase.databaseFileName));
    final raw = sqlite.sqlite3.open(file.path);
    raw.execute('CREATE TABLE placeholder (value TEXT);');
    raw.userVersion = version;
    raw.close();

    final database = AppDatabase.open(file: file);
    try {
      await database.customSelect('SELECT 1;').getSingle();
      return null;
    } catch (error) {
      return error;
    } finally {
      await database.close();
    }
  }

  test('a published older schema is never opened directly', () async {
    // Upgrades happen only through SchemaMigrations, never as a side effect of
    // an ordinary open.
    final older = AppDatabase.publishedSchemaVersions
        .where((v) => v != AppDatabase.currentSchemaVersion)
        .toList(growable: false);
    expect(older, isNotEmpty);
    for (final version in older) {
      // The guard runs on drift's worker isolate, so the StateError arrives
      // wrapped in a DriftRemoteException.
      expect(
        (await openAtVersion(version)).toString(),
        contains('database_schema_version'),
      );
    }
  });

  test(
    'a new database creates every business and asset persistence table',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      try {
        final rows = await database
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'table';",
            )
            .get();
        final tables = rows.map((row) => row.read<String>('name')).toSet();

        expect(
          tables,
          containsAll(const {
            'assistant_rows',
            'provider_rows',
            'provider_group_rows',
            'mcp_server_rows',
            'world_book_rows',
            'assistant_memory_rows',
            'quick_phrase_rows',
            'search_service_rows',
            'tts_service_rows',
            'instruction_injection_rows',
            'assistant_tag_rows',
            'preference_rows',
            'memory_entry_rows',
            'user_profile_field_rows',
            'message_prompt_rows',
            'asset_rows',
            'message_asset_rows',
            'asset_gc_rows',
            'gc_audit_rows',
            'asset_reference_dirty_rows',
          }),
        );
      } finally {
        await database.close();
      }
    },
  );

  test('unpublished schema is rejected instead of migrated', () async {
    final unpublished = AppDatabase.currentSchemaVersion + 1;
    expect(AppDatabase.publishedSchemaVersions, isNot(contains(unpublished)));
    expect(
      (await openAtVersion(unpublished)).toString(),
      contains('database_schema_version'),
    );
  });
}
