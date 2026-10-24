import 'package:drift/drift.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'app_database.dart';
import 'schema_versions.dart';

/// The index is disposable; all durable values live in the state table.
/// Definition SQL comes from the generated schema, shared with create/migrate.
abstract final class GenUiDerivedSchema {
  static const stateTable = 'gen_ui_surface_state_rows';
  static const searchTable = 'gen_ui_surface_search';
  static final _schema = Schema5(database: const _SchemaMetadataOnly());
  static final VirtualTableInfo _fts = _schema.genUiSurfaceSearch;
  static final String _searchDefinition =
      'CREATE VIRTUAL TABLE ${_identifier(_fts.entityName)} '
      'USING ${_fts.moduleAndArgs}';
  static final List<Trigger> _triggers = List.unmodifiable([
    _schema.genUiStateSearchInsert,
    _schema.genUiStateSearchUpdate,
    _schema.genUiStateSearchDelete,
  ]);

  static String _identifier(String value) => SqlDialect.sqlite.escape(value);

  static final _stateDefinition = _stateCreateSql();
  static String _stateCreateSql() {
    final table = _schema.genUiSurfaceStateRows;
    final context = GenerationContext(
      const DriftDatabaseOptions(),
      null,
      supportsVariables: false,
    );
    context.buffer.write('CREATE TABLE ${_identifier(stateTable)} (');
    for (var i = 0; i < table.$columns.length; i++) {
      if (i != 0) context.buffer.write(', ');
      table.$columns[i].writeColumnDefinition(context);
    }
    for (final constraint in table.asDslTable.customConstraints) {
      context.buffer.write(', $constraint');
    }
    context.buffer.write(')');
    final options = [
      if (table.asDslTable.withoutRowId) 'WITHOUT ROWID',
      if (table.asDslTable.isStrict) 'STRICT',
    ];
    if (options.isNotEmpty) context.buffer.write(' ${options.join(', ')}');
    return context.sql;
  }

  // Fresh Dart tables and generated migration tables differ in whitespace and
  // identifier quoting. Keep literal content and token boundaries intact while
  // comparing their complete definitions, including CHECK and rowid policy.
  static final _sqlTokens = RegExp(
    r''''(?:''|[^'])*'|"(?:""|[^"])*"|[A-Za-z_][A-Za-z_0-9$]*|[^\s]''',
  );
  static String _tableDefinition(String sql) {
    final tokens = _sqlTokens.allMatches(sql).map((match) {
      final token = match.group(0)!;
      if (token.startsWith("'")) return token;
      if (token.startsWith('"')) {
        return token
            .substring(1, token.length - 1)
            .replaceAll('""', '"')
            .toLowerCase();
      }
      return token.toLowerCase();
    }).toList();
    if (tokens.length > 4 &&
        tokens[0] == 'create' &&
        tokens[1] == 'table' &&
        tokens[2] == 'if' &&
        tokens[3] == 'not' &&
        tokens[4] == 'exists') {
      tokens.removeRange(2, 5);
    }
    if (tokens.isNotEmpty && tokens.last == ';') tokens.removeLast();
    return tokens.join('\u0000');
  }

  static String _canonicalCreate(String sql) => sql
      .trim()
      .replaceFirst(
        RegExp(
          r'^CREATE\s+(VIRTUAL\s+TABLE|TRIGGER)\s+(?:IF\s+NOT\s+EXISTS\s+)?',
          caseSensitive: false,
        ),
        sql.trimLeft().toUpperCase().startsWith('CREATE VIRTUAL')
            ? 'CREATE VIRTUAL TABLE '
            : 'CREATE TRIGGER ',
      )
      .replaceFirst(RegExp(r';\s*$'), '');

  static void validate(sqlite.Database database) {
    final stateSql = database.select(
      "SELECT sql FROM sqlite_schema WHERE type = 'table' AND name = ?;",
      [stateTable],
    );
    if (stateSql.length != 1 ||
        _tableDefinition(stateSql.single['sql'] as String? ?? '') !=
            _tableDefinition(_stateDefinition)) {
      throw StateError('table_definition_schema:$stateTable');
    }
    final definitions = _schema.genUiSurfaceStateRows.$columns;
    final actualColumns = database.select('PRAGMA table_info($stateTable);');
    final context = GenerationContext(const DriftDatabaseOptions(), null);
    if (actualColumns.length != definitions.length) {
      throw StateError('table_schema:$stateTable');
    }
    for (var i = 0; i < definitions.length; i++) {
      final expected = definitions[i];
      final actual = actualColumns[i];
      final expectedDefault = switch (expected.$name) {
        'state_version' => '1',
        'state_json' => "'{\"inputs\":{},\"view\":{}}'",
        'search_text' => "''",
        _ => null,
      };
      if (actual['dflt_value'] != expectedDefault ||
          actual['name'] != expected.$name ||
          actual['type'] != expected.type.sqlTypeName(context) ||
          actual['notnull'] != (expected.$nullable ? 0 : 1)) {
        throw StateError('column_schema:$stateTable.${expected.$name}');
      }
    }
    final primary = database
        .select('PRAGMA index_list($stateTable);')
        .where((row) => row['origin'] == 'pk');
    if (primary.length != 1 ||
        primary.single['unique'] != 1 ||
        primary.single['partial'] != 0) {
      throw StateError('index_schema:$stateTable.primary_key');
    }
    final keyColumns = database.select(
      'SELECT name FROM pragma_index_info(?) ORDER BY seqno;',
      [primary.single['name']],
    );
    if (keyColumns.length != 2 ||
        keyColumns[0]['name'] != 'revision_id' ||
        keyColumns[1]['name'] != 'surface_key') {
      throw StateError('index_schema:$stateTable.primary_key');
    }
    final tables = database.select(
      'SELECT type, tbl_name, sql FROM sqlite_schema WHERE name = ?;',
      [searchTable],
    );
    if (tables.length != 1 ||
        tables.single['type'] != 'table' ||
        tables.single['tbl_name'] != searchTable ||
        _canonicalCreate(tables.single['sql'] as String? ?? '') !=
            _canonicalCreate(_searchDefinition)) {
      throw StateError('index_schema:$searchTable');
    }
    final columns = database.select('PRAGMA table_info($searchTable);');
    if (columns.length != 1 || columns.single['name'] != 'search_text') {
      throw StateError('index_schema:$searchTable');
    }
    final actual = database.select(
      "SELECT name, tbl_name, sql FROM sqlite_schema WHERE type = 'trigger' "
      "AND (tbl_name = ? OR name GLOB 'gen_ui_*');",
      [stateTable],
    );
    if (actual.length != _triggers.length) {
      throw StateError('trigger_schema:$stateTable');
    }
    for (final expected in _triggers) {
      final found = actual.where((row) => row['name'] == expected.entityName);
      if (found.length != 1 ||
          found.single['tbl_name'] != stateTable ||
          _canonicalCreate(found.single['sql'] as String? ?? '') !=
              _canonicalCreate(
                expected.createStatementsByDialect[SqlDialect.sqlite]!,
              )) {
        throw StateError('trigger_schema:${expected.entityName}');
      }
    }
  }

  /// Called only while explicitly normalizing a staged future snapshot.
  /// Remove owned triggers before dropping their index or unknown columns:
  /// SQLite validates surviving trigger bodies during ALTER TABLE.
  static void discard(sqlite.Database database) {
    final triggers = database.select(
      "SELECT name FROM sqlite_schema WHERE type = 'trigger' AND tbl_name = ?;",
      [stateTable],
    );
    for (final trigger in triggers) {
      database.execute(
        'DROP TRIGGER ${_identifier(trigger['name'] as String)};',
      );
    }
    database.execute('DROP TABLE IF EXISTS $searchTable;');
  }

  /// Repair only our disposable search objects, using the published v5 DDL.
  static Future<void> resetSearch(AppDatabase database) async {
    for (final trigger in _triggers) {
      await database.customStatement(
        'DROP TRIGGER IF EXISTS ${_identifier(trigger.entityName)};',
      );
    }
    await database.customStatement('DROP TABLE IF EXISTS $searchTable;');
    await rebuild(database);
  }

  /// Uses the caller's connection/transaction. It does not overwrite overrides,
  /// state versions or save timestamps, and cannot create missing parent rows.
  static Future<void> rebuild(AppDatabase database) async {
    final migrator = Migrator(database);
    await migrator.create(_fts);
    for (final trigger in _triggers) {
      await migrator.create(trigger);
    }
    await database.customStatement(
      'INSERT INTO $searchTable(rowid, search_text) '
      'SELECT rowid, search_text FROM $stateTable;',
    );
  }

  /// Rebuild only a validated, private export copy after VACUUM INTO.
  ///
  /// VACUUM puts FTS shadow tables before the virtual table in sqlite_schema.
  /// The frozen v3 reader drops unknown tables in that order, which SQLite
  /// rejects for a shadow table. Recreating the index naturally restores the
  /// virtual-table-first order without editing sqlite_schema. Refill from the
  /// current state rowids as VACUUM may also renumber implicit rowids.
  static void rebuildExportIndex(sqlite.Database database) {
    database.execute('BEGIN IMMEDIATE;');
    try {
      discard(database);
      database.execute(_searchDefinition);
      for (final trigger in _triggers) {
        database.execute(trigger.createStatementsByDialect[SqlDialect.sqlite]!);
      }
      database.execute(
        'INSERT INTO $searchTable(rowid, search_text) '
        'SELECT rowid, search_text FROM $stateTable;',
      );
      validate(database);
      database.execute('COMMIT;');
    } catch (_) {
      database.execute('ROLLBACK;');
      rethrow;
    }
  }
}

/// VersionedSchema requires an owner even for definition-only inspection.
/// This implements rather than constructs a connection user: no connection,
/// executor or stream store exists. Accidental runtime access fails explicitly.
final class _SchemaMetadataOnly implements DatabaseConnectionUser {
  const _SchemaMetadataOnly();
  @override
  Never noSuchMethod(Invocation invocation) =>
      throw StateError('Schema metadata cannot access a database connection');
}
