import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/database/gen_ui_derived_schema.dart';
import 'package:Kelivo/core/database/schema_migrations.dart';
import 'package:Kelivo/features/intelligent_ui/catalog/ui_budgets.dart';

import 'generated_schema/schema.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('genui-schema-');
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });

  Future<File> createDatabase({int version = 5}) async {
    final file = File('${directory.path}/fixture-$version.db');
    final GeneratedDatabase db = version == 5
        ? AppDatabase(NativeDatabase(file))
        : GeneratedHelper().databaseForVersion(NativeDatabase(file), version);
    try {
      await db.customStatement(
        'INSERT INTO conversation_rows (id, title, created_at, updated_at) '
        "VALUES ('c', 'Schema fixture', 1, 2);",
      );
      await db.customStatement(
        'INSERT INTO message_rows (id, conversation_id, role, timestamp, '
        "message_order) VALUES ('m', 'c', 'assistant', 3, 0);",
      );
      await db.customStatement(
        'INSERT INTO message_part_rows (part_id, conversation_id, revision_id, '
        'ordinal, kind, payload, created_at, updated_at) '
        "VALUES (1, 'c', 'm', 0, 'text', 'Original fence text', 3, 3);",
      );
    } finally {
      await db.close();
    }
    return file;
  }

  sqlite.Database open(File file) {
    final db = sqlite.sqlite3.open(file.path);
    db.execute('PRAGMA foreign_keys = ON;');
    addTearDown(db.close);
    return db;
  }

  void insertState(sqlite.Database db, {String key = '0:0'}) => db.execute(
    'INSERT INTO gen_ui_surface_state_rows '
    '(revision_id, surface_key, source_hash, search_text, updated_at) '
    "VALUES ('m', ?, ?, 'alpha beta', 42);",
    [key, 'a' * 64],
  );

  int matchCount(sqlite.Database db, String term) =>
      db.select(
            'SELECT COUNT(*) AS n FROM gen_ui_surface_search '
            'WHERE gen_ui_surface_search MATCH ?;',
            [term],
          ).single['n']
          as int;

  test(
    'export preserves state and makes FTS removable by the frozen reader',
    () async {
      final sourceFile = await createDatabase();
      final source = open(sourceFile);
      for (final key in ['0:0', '0:1', '0:2']) {
        insertState(source, key: key);
      }
      source.execute(
        "DELETE FROM gen_ui_surface_state_rows WHERE surface_key = '0:1';",
      );
      source.execute(
        'UPDATE gen_ui_surface_state_rows SET state_json = ?, search_text = ? '
        "WHERE surface_key = '0:2';",
        ['{"inputs":{"n":9},"view":{}}', 'retained sparse row'],
      );
      List<Map<String, Object?>> states(sqlite.Database database) => database
          .select(
            'SELECT * FROM gen_ui_surface_state_rows ORDER BY surface_key;',
          )
          .map((row) => Map<String, Object?>.from(row))
          .toList();
      final before = states(source);
      final sourceRowids = source
          .select('SELECT rowid FROM gen_ui_surface_state_rows ORDER BY rowid;')
          .map((row) => row['rowid'])
          .toList();
      expect(sourceRowids, [1, 3]);
      final snapshotFile = File('${directory.path}/portable.db');
      await ChatDatabaseRepository.createConsistentSnapshot(
        sourceFile: sourceFile,
        destinationFile: snapshotFile,
      );
      final snapshot = open(snapshotFile);
      GenUiDerivedSchema.validate(snapshot);
      expect(states(snapshot), before);
      expect(
        snapshot
            .select(
              'SELECT s.surface_key FROM gen_ui_surface_search f '
              'JOIN gen_ui_surface_state_rows s ON s.rowid = f.rowid '
              "WHERE gen_ui_surface_search MATCH 'sparse';",
            )
            .single['surface_key'],
        '0:2',
      );
      expect(matchCount(snapshot, 'alpha'), 1);
      snapshot.execute(
        "UPDATE gen_ui_surface_state_rows SET search_text = 'changed term' "
        "WHERE surface_key = '0:2';",
      );
      expect(matchCount(snapshot, 'sparse'), 0);
      expect(matchCount(snapshot, 'changed'), 1);
      snapshot.execute(
        "DELETE FROM gen_ui_surface_state_rows WHERE surface_key = '0:0';",
      );
      expect(matchCount(snapshot, 'alpha'), 0);
      snapshot.execute('PRAGMA foreign_keys = OFF;');
      final tables = snapshot
          .select("SELECT name FROM sqlite_master WHERE type = 'table';")
          .map((row) => row['name'] as String)
          .where((name) => name.startsWith('gen_ui_'))
          .toList();
      // Same unknown-table loop as the frozen v3 normalizer. It must encounter
      // the virtual table before its protected shadow tables, even after VACUUM.
      for (final table in tables) {
        snapshot.execute('DROP TABLE IF EXISTS "$table";');
      }
      expect(
        snapshot.select(
          "SELECT name FROM sqlite_master WHERE name GLOB 'gen_ui_*';",
        ),
        isEmpty,
      );
      expect(states(source), before);
      expect(
        source
            .select(
              'SELECT rowid FROM gen_ui_surface_state_rows ORDER BY rowid;',
            )
            .map((row) => row['rowid'])
            .toList(),
        sourceRowids,
      );
      expect(matchCount(source, 'sparse'), 1);
    },
  );

  for (final version in [1, 2, 3]) {
    test(
      'published v$version upgrades to complete v5 with retained text',
      () async {
        final file = await createDatabase(version: version);
        final before = sqlite.sqlite3.open(file.path);
        final Map<String, Object?> oldSql;
        try {
          oldSql = {
            for (final row in before.select(
              "SELECT name, sql FROM sqlite_schema WHERE name NOT LIKE 'sqlite_%';",
            ))
              row['name'] as String: row['sql'],
          };
        } finally {
          before.close();
        }
        final outcome = await ChatDatabaseRepository.migrateInstalledDatabase(
          file,
        );
        expect(outcome.fromVersion, version);
        expect(outcome.toVersion, 5);
        expect(outcome.upgraded, isTrue);
        final raw = open(file);
        GenUiDerivedSchema.validate(raw);
        expect(raw.select('PRAGMA foreign_key_check;'), isEmpty);
        expect(
          raw
              .select('SELECT payload FROM message_part_rows;')
              .single['payload'],
          'Original fence text',
        );
        if (version == 3) {
          for (final entry in oldSql.entries) {
            expect(
              raw.select('SELECT sql FROM sqlite_schema WHERE name = ?;', [
                entry.key,
              ]).single['sql'],
              entry.value,
              reason: entry.key,
            );
          }
        }
        insertState(raw);
        expect(matchCount(raw, 'alpha'), 1);
        expect(
          raw
              .select(
                "SELECT tbl_name FROM sqlite_schema WHERE type='trigger' "
                "AND name GLOB 'gen_ui_*';",
              )
              .map((r) => r['tbl_name'])
              .toSet(),
          {'gen_ui_surface_state_rows'},
        );
        final db = AppDatabase.open(file: file);
        try {
          await SchemaVerifier(GeneratedHelper()).migrateAndValidate(
            db,
            5,
            options: const ValidationOptions(validateDropped: true),
          );
        } finally {
          await db.close();
        }
      },
    );
  }

  test('fresh state has defaults and composite owner uniqueness', () async {
    final raw = open(await createDatabase());
    GenUiDerivedSchema.validate(raw);
    insertState(raw);
    final row = raw.select('SELECT * FROM gen_ui_surface_state_rows;').single;
    expect(row['state_version'], 1);
    expect(row['state_json'], '{"inputs":{},"view":{}}');
    expect(() => insertState(raw), throwsA(isA<sqlite.SqliteException>()));
    insertState(raw, key: '0:1');
    expect(
      raw
          .select('SELECT COUNT(*) AS n FROM gen_ui_surface_search;')
          .single['n'],
      2,
    );
    expect(
      () => raw.execute(
        "INSERT INTO gen_ui_surface_state_rows "
        "(revision_id,surface_key,source_hash,updated_at) VALUES ('absent','0:0','hash',1);",
      ),
      throwsA(isA<sqlite.SqliteException>()),
    );
  });

  test('JSON shape and UTF-8 limits are enforced by the database', () async {
    final raw = open(await createDatabase());
    insertState(raw);
    for (final invalid in [
      '{',
      '{}',
      '[]',
      '{"inputs":{},"view":null}',
      '{"inputs":1,"view":{}}',
      jsonEncode({
        'inputs': {'x': '界' * UiBudgets.stateBytes},
        'view': {},
      }),
    ]) {
      expect(
        () => raw.execute(
          'UPDATE gen_ui_surface_state_rows SET state_json = ?;',
          [invalid],
        ),
        throwsA(isA<sqlite.SqliteException>()),
        reason: 'invalid or oversized state',
      );
    }
    for (final version in [0, -1, 1.5]) {
      expect(
        () => raw.execute(
          'UPDATE gen_ui_surface_state_rows SET state_version = ?;',
          [version],
        ),
        throwsA(isA<sqlite.SqliteException>()),
      );
    }
    raw.execute('UPDATE gen_ui_surface_state_rows SET search_text = ?;', [
      'x' * UiBudgets.searchTextBytes,
    ]);
    expect(
      () => raw.execute(
        'UPDATE gen_ui_surface_state_rows SET search_text = ?;',
        ['界' * (UiBudgets.searchTextBytes ~/ 3 + 1)],
      ),
      throwsA(isA<sqlite.SqliteException>()),
    );
  });

  test(
    'only changed search text retokenizes; parent deletes clear FTS',
    () async {
      final raw = open(await createDatabase());
      insertState(raw);
      // Autocommit has drained the FTS writes from the preceding insert.
      final before =
          raw.select('SELECT total_changes() AS n;').single['n'] as int;
      raw.execute(
        'UPDATE gen_ui_surface_state_rows SET state_json = ?, updated_at = 43;',
        ['{"inputs":{"a":2},"view":{}}'],
      );
      expect(
        (raw.select('SELECT total_changes() AS n;').single['n'] as int) -
            before,
        1,
      );
      final same =
          raw.select('SELECT total_changes() AS n;').single['n'] as int;
      raw.execute(
        "UPDATE gen_ui_surface_state_rows SET search_text = 'alpha beta';",
      );
      expect(
        (raw.select('SELECT total_changes() AS n;').single['n'] as int) - same,
        1,
      );
      raw.execute(
        "UPDATE gen_ui_surface_state_rows SET search_text = 'gamma delta';",
      );
      expect(matchCount(raw, 'alpha'), 0);
      expect(matchCount(raw, 'gamma'), 1);
      raw.execute("DELETE FROM message_rows WHERE id = 'm';");
      expect(raw.select('SELECT * FROM gen_ui_surface_state_rows;'), isEmpty);
      expect(raw.select('SELECT * FROM gen_ui_surface_search;'), isEmpty);
    },
  );

  test(
    'deleting a conversation clears every child state and search row',
    () async {
      final raw = open(await createDatabase());
      insertState(raw);
      insertState(raw, key: '0:1');
      raw.execute("DELETE FROM conversation_rows WHERE id = 'c';");
      expect(raw.select('SELECT * FROM gen_ui_surface_state_rows;'), isEmpty);
      expect(raw.select('SELECT * FROM gen_ui_surface_search;'), isEmpty);
      expect(raw.select('PRAGMA foreign_key_check;'), isEmpty);
    },
  );

  for (final damage in ['missing checks', 'without rowid', 'changed literal']) {
    test('strict inspection rejects state table with $damage', () async {
      final file = await createDatabase();
      final raw = open(file);
      final original =
          raw
                  .select(
                    "SELECT sql FROM sqlite_schema WHERE name = 'gen_ui_surface_state_rows';",
                  )
                  .single['sql']
              as String;
      final derived = raw
          .select(
            "SELECT sql FROM sqlite_schema WHERE name = 'gen_ui_surface_search' "
            "OR (type = 'trigger' AND tbl_name = 'gen_ui_surface_state_rows');",
          )
          .map((row) => row['sql'] as String)
          .toList();
      final beforeColumns = raw
          .select('PRAGMA table_info(gen_ui_surface_state_rows);')
          .map((row) => Map<String, Object?>.from(row))
          .toList();
      final beforeForeignKeys = raw
          .select('PRAGMA foreign_key_list(gen_ui_surface_state_rows);')
          .map((row) => Map<String, Object?>.from(row))
          .toList();
      GenUiDerivedSchema.discard(raw);
      raw.execute('DROP TABLE gen_ui_surface_state_rows;');
      final replacement = switch (damage) {
        'missing checks' =>
          '''
CREATE TABLE gen_ui_surface_state_rows (
  revision_id TEXT NOT NULL REFERENCES message_rows(id) ON DELETE CASCADE,
  surface_key TEXT NOT NULL,
  source_hash TEXT NOT NULL,
  state_version INTEGER NOT NULL DEFAULT 1,
  state_json TEXT NOT NULL DEFAULT '{"inputs":{},"view":{}}',
  search_text TEXT NOT NULL DEFAULT '',
  updated_at INTEGER NOT NULL,
  PRIMARY KEY(revision_id, surface_key)
);
''',
        'without rowid' =>
          '${original.replaceFirst(RegExp(r';\s*$'), '')} WITHOUT ROWID;',
        _ => original.replaceFirst(r"'$.view'", r"'$.VIEW'"),
      };
      expect(replacement, isNot(original));
      raw.execute(replacement);
      for (final sql in derived) {
        raw.execute(sql);
      }
      expect(
        raw
            .select('PRAGMA table_info(gen_ui_surface_state_rows);')
            .map((row) => Map<String, Object?>.from(row))
            .toList(),
        beforeColumns,
      );
      expect(
        raw
            .select('PRAGMA foreign_key_list(gen_ui_surface_state_rows);')
            .map((row) => Map<String, Object?>.from(row))
            .toList(),
        beforeForeignKeys,
      );
      if (damage == 'missing checks') {
        raw.execute(
          'INSERT INTO gen_ui_surface_state_rows '
          '(revision_id,surface_key,source_hash,state_version,state_json,search_text,updated_at) '
          "VALUES ('m','0:0',?,1.5,'{}',?,42);",
          ['a' * 64, 'x' * (UiBudgets.searchTextBytes + 1)],
        );
      }
      expect(
        () => ChatDatabaseRepository.inspectInstalledDatabase(file),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'reason',
            'table_definition_schema:gen_ui_surface_state_rows',
          ),
        ),
      );
    });
  }

  for (final damage in ['missing trigger', 'wrong body', 'ordinary table']) {
    test('strict inspection rejects $damage', () async {
      final file = await createDatabase();
      final raw = open(file);
      if (damage == 'ordinary table') {
        raw.execute('DROP TABLE gen_ui_surface_search;');
        raw.execute('CREATE TABLE gen_ui_surface_search(search_text TEXT);');
      } else {
        raw.execute('DROP TRIGGER gen_ui_state_search_insert;');
        if (damage == 'wrong body') {
          raw.execute(
            'CREATE TRIGGER gen_ui_state_search_insert '
            'AFTER INSERT ON gen_ui_surface_state_rows BEGIN SELECT 1; END;',
          );
        }
      }
      expect(
        () => ChatDatabaseRepository.inspectInstalledDatabase(file),
        throwsStateError,
      );
    });
  }

  test('v3 migration restores the pre-migration file on DDL failure', () async {
    final file = await createDatabase(version: 3);
    final raw = sqlite.sqlite3.open(file.path);
    raw.execute('CREATE TABLE gen_ui_surface_search (sentinel TEXT);');
    raw.execute('PRAGMA wal_checkpoint(TRUNCATE);');
    raw.select('PRAGMA journal_mode = DELETE;');
    raw.close();
    final bytes = await file.readAsBytes();
    await expectLater(
      ChatDatabaseRepository.migrateInstalledDatabase(file),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'reason',
          'database_migration_failed:3',
        ),
      ),
    );
    expect(await file.readAsBytes(), bytes);
    expect(SchemaMigrations.readSchemaVersion(file), 3);
  });

  test(
    'future normalization rebuilds only the index and retains overrides',
    () async {
      final file = await createDatabase();
      final raw = sqlite.sqlite3.open(file.path);
      insertState(raw);
      const state = '{"inputs":{"a":2},"view":{"table":{"page":2}}}';
      raw.execute(
        'UPDATE gen_ui_surface_state_rows SET state_json = ?, updated_at = 99;',
        [state],
      );
      raw.execute(
        'ALTER TABLE gen_ui_surface_state_rows ADD COLUMN future TEXT;',
      );
      raw.execute(
        'CREATE INDEX future_index ON gen_ui_surface_state_rows(future);',
      );
      raw.execute('CREATE TABLE future_rows (value TEXT);');
      raw.execute(
        'CREATE TRIGGER future_owned_trigger AFTER UPDATE OF future '
        'ON gen_ui_surface_state_rows BEGIN INSERT INTO future_rows VALUES (new.future); END;',
      );
      raw.userVersion = 6;
      raw.close();
      await ChatDatabaseRepository.normalizeForwardCompatibleSnapshot(file);
      final after = open(file);
      GenUiDerivedSchema.validate(after);
      expect(after.userVersion, 5);
      final row = after
          .select('SELECT * FROM gen_ui_surface_state_rows;')
          .single;
      expect(row['state_json'], state);
      expect(row['state_version'], 1);
      expect(row['updated_at'], 99);
      expect(row.containsKey('future'), isFalse);
      expect(matchCount(after, 'alpha'), 1);
      expect(
        after.select(
          "SELECT name FROM sqlite_schema WHERE name GLOB 'future*';",
        ),
        isEmpty,
      );
      ChatDatabaseRepository.inspectInstalledDatabase(file);
    },
  );

  test(
    'failed future normalization rolls back derived DDL and version',
    () async {
      final file = await createDatabase();
      final raw = sqlite.sqlite3.open(file.path);
      raw.execute('DROP TABLE gen_ui_surface_state_rows;');
      raw.userVersion = 6;
      raw.close();
      final before = await file.readAsBytes();
      await expectLater(
        ChatDatabaseRepository.normalizeForwardCompatibleSnapshot(file),
        throwsStateError,
      );
      expect(SchemaMigrations.readSchemaVersion(file), 6);
      expect(await file.readAsBytes(), before);
    },
  );
}
