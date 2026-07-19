import 'dart:convert';

import 'package:drift/drift.dart';

import 'app_database.dart';
import 'business_data.dart';

final class BusinessRepository {
  BusinessRepository(this._database);

  static const migrationReceiptKey = 'business_migration_complete_v1';

  final AppDatabase _database;

  /// Used by cross-domain coordinators to fail closed unless both
  /// repositories are backed by the exact same Drift database instance.
  bool sharesDatabaseIdentity(Object identity) =>
      identical(_database, identity);

  Future<List<BusinessEntityValue>> readEntities(BusinessEntityKind kind) =>
      _readEntities(kind);

  Future<List<BusinessEntityValue>> readMemoriesForAssistant(
    String assistantId,
  ) async {
    final normalizedId = assistantId.trim();
    if (normalizedId.isEmpty) return const <BusinessEntityValue>[];
    return _readEntities(
      BusinessEntityKind.assistantMemory,
      assistantId: normalizedId,
    );
  }

  Future<void> replaceEntities(
    BusinessEntityKind kind,
    List<BusinessEntityValue> rows,
  ) async {
    _validateRows(kind, rows);
    await _database.transaction(() => _replaceEntities(kind, rows));
  }

  Future<void> synchronizeEntities(
    BusinessEntityKind kind,
    List<BusinessEntityValue> rows,
  ) async {
    _validateRows(kind, rows);
    await _database.transaction(() async {
      final existing = await _readEntities(kind);
      final existingById = <String, BusinessEntityValue>{
        for (final row in existing) row.id: row,
      };
      final retainedIds = rows.map((row) => row.id).toSet();
      for (final row in existing) {
        if (!retainedIds.contains(row.id)) {
          await _deleteEntity(kind, row.id);
        }
      }
      final updatedAt = DateTime.now().toUtc().microsecondsSinceEpoch;
      for (final row in rows) {
        final previous = existingById[row.id];
        if (previous != null && _sameEntity(previous, row)) continue;
        await _upsertEntity(kind, row, updatedAt: updatedAt);
      }
    });
  }

  Future<void> upsertEntity(
    BusinessEntityKind kind,
    BusinessEntityValue row,
  ) async {
    _validateRows(kind, <BusinessEntityValue>[row]);
    await _upsertEntity(
      kind,
      row,
      updatedAt: DateTime.now().toUtc().microsecondsSinceEpoch,
    );
  }

  Future<void> deleteEntity(BusinessEntityKind kind, String id) async {
    if (id.isEmpty) return;
    await _deleteEntity(kind, id);
  }

  Future<Object?> getPreference(String key) async {
    final row = await _database
        .customSelect(
          'SELECT value FROM preference_rows WHERE key = ?;',
          variables: <Variable<Object>>[Variable<String>(key)],
          readsFrom: {_database.preferenceRows},
        )
        .getSingleOrNull();
    if (row == null) return null;
    return _decodePreference(key, row.read<String>('value'));
  }

  Future<void> setPreference(String key, Object value) async {
    if (key.isEmpty) throw ArgumentError.value(key, 'key');
    final normalized = _normalizePreference(key, value);
    await _database.customStatement(
      'INSERT INTO preference_rows (key, value, updated_at) VALUES (?, ?, ?) '
      'ON CONFLICT(key) DO UPDATE SET value = excluded.value, '
      'updated_at = excluded.updated_at;',
      <Object?>[
        key,
        jsonEncode(normalized),
        DateTime.now().toUtc().microsecondsSinceEpoch,
      ],
    );
  }

  Future<void> removePreference(String key) => _database.customStatement(
    'DELETE FROM preference_rows WHERE key = ?;',
    <Object?>[key],
  );

  Future<Map<String, Object>> preferenceSnapshot() async {
    final rows = await _database
        .customSelect(
          'SELECT key, value FROM preference_rows ORDER BY key;',
          readsFrom: {_database.preferenceRows},
        )
        .get();
    return Map<String, Object>.unmodifiable({
      for (final row in rows)
        row.read<String>('key'): _decodePreference(
          row.read<String>('key'),
          row.read<String>('value'),
        ),
    });
  }

  Future<BusinessSnapshot> readSnapshot() =>
      _database.transaction(_readSnapshot);

  Future<void> replaceSnapshot(
    BusinessSnapshot snapshot, {
    bool writeReceipt = false,
  }) async {
    final preferences = _validateSnapshot(snapshot);
    await _database.transaction(
      () => _replaceSnapshot(
        snapshot,
        preferences: preferences,
        writeReceipt: writeReceipt,
      ),
    );
  }

  /// Replaces business state, validates the persisted projection and only
  /// then publishes the migration receipt, all within one SQLite transaction.
  Future<void> replaceSnapshotForMigration(
    BusinessSnapshot snapshot, {
    required void Function(BusinessSnapshot persisted) validatePersisted,
  }) async {
    final preferences = _validateSnapshot(snapshot);
    await _database.transaction(() async {
      await _replaceSnapshot(
        snapshot,
        preferences: preferences,
        writeReceipt: false,
      );
      validatePersisted(await _readSnapshot());
      await _writeMigrationReceipt();
    });
  }

  Future<void> transformSnapshot(
    BusinessSnapshot Function(BusinessSnapshot current) transform, {
    bool writeReceipt = false,
  }) => _database.transaction(() async {
    final next = transform(await _readSnapshot());
    final preferences = _validateSnapshot(next);
    await _replaceSnapshot(
      next,
      preferences: preferences,
      writeReceipt: writeReceipt,
    );
  });

  Future<BusinessSnapshot> _readSnapshot() async {
    final entities = <BusinessEntityKind, List<BusinessEntityValue>>{};
    for (final kind in BusinessEntityKind.values) {
      entities[kind] = await _readEntities(kind);
    }
    return BusinessSnapshot(
      entities: entities,
      preferences: await preferenceSnapshot(),
    );
  }

  static Map<String, Object> _validateSnapshot(BusinessSnapshot snapshot) {
    for (final kind in BusinessEntityKind.values) {
      _validateRows(kind, snapshot.entities[kind]!);
    }
    final preferences = <String, Object>{};
    for (final entry in snapshot.preferences.entries) {
      if (entry.key.isEmpty) throw ArgumentError.value(entry.key, 'key');
      preferences[entry.key] = _normalizePreference(entry.key, entry.value);
    }
    return preferences;
  }

  Future<void> _replaceSnapshot(
    BusinessSnapshot snapshot, {
    required Map<String, Object> preferences,
    required bool writeReceipt,
  }) async {
    for (final kind in BusinessEntityKind.values) {
      await _replaceEntities(kind, snapshot.entities[kind]!);
    }
    await _replacePreferences(preferences);
    if (writeReceipt) await _writeMigrationReceipt();
  }

  Future<void> clearAll() async {
    await _database.transaction(() async {
      for (final kind in BusinessEntityKind.values) {
        await _database.customStatement('DELETE FROM ${kind.tableName};');
      }
      await _database.customStatement('DELETE FROM preference_rows;');
    });
  }

  Future<bool> hasMigrationReceipt() async {
    final row = await _database
        .customSelect(
          'SELECT value FROM chat_storage_meta_rows WHERE key = ?;',
          variables: const <Variable<Object>>[
            Variable<String>(migrationReceiptKey),
          ],
          readsFrom: {_database.chatStorageMetaRows},
        )
        .getSingleOrNull();
    if (row == null) return false;
    if (row.read<String>('value') != 'true') {
      throw StateError('business_migration_receipt');
    }
    return true;
  }

  Future<void> writeMigrationReceipt() =>
      _database.transaction(_writeMigrationReceipt);

  Future<void> clearMigrationReceipt() => _database.customStatement(
    'DELETE FROM chat_storage_meta_rows WHERE key = ?;',
    <Object?>[migrationReceiptKey],
  );

  Future<List<BusinessEntityValue>> _readEntities(
    BusinessEntityKind kind, {
    String? assistantId,
  }) async {
    final isMemory = kind == BusinessEntityKind.assistantMemory;
    final filter = assistantId == null ? '' : ' WHERE assistant_id = ?';
    final rows = await _database
        .customSelect(
          'SELECT ${kind.idColumn} AS entity_id, sort_order, payload'
          '${isMemory ? ', assistant_id' : ''} FROM ${kind.tableName}'
          '$filter ORDER BY sort_order, ${kind.idColumn};',
          variables: assistantId == null
              ? const <Variable<Object>>[]
              : <Variable<Object>>[Variable<String>(assistantId)],
        )
        .get();
    return List<BusinessEntityValue>.unmodifiable(
      rows.map(
        (row) => BusinessEntityValue(
          id: row.read<String>('entity_id'),
          sortOrder: row.read<int>('sort_order'),
          payload: row.read<String>('payload'),
          assistantId: isMemory ? row.read<String>('assistant_id') : null,
        ),
      ),
    );
  }

  Future<void> _replaceEntities(
    BusinessEntityKind kind,
    List<BusinessEntityValue> rows,
  ) async {
    await _database.customStatement('DELETE FROM ${kind.tableName};');
    final updatedAt = DateTime.now().toUtc().microsecondsSinceEpoch;
    for (final row in rows) {
      await _upsertEntity(kind, row, updatedAt: updatedAt);
    }
  }

  Future<void> _upsertEntity(
    BusinessEntityKind kind,
    BusinessEntityValue row, {
    required int updatedAt,
  }) {
    if (kind == BusinessEntityKind.assistantMemory) {
      return _database.customStatement(
        'INSERT INTO assistant_memory_rows '
        '(id, sort_order, assistant_id, payload, updated_at) '
        'VALUES (?, ?, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET '
        'sort_order = excluded.sort_order, '
        'assistant_id = excluded.assistant_id, payload = excluded.payload, '
        'updated_at = excluded.updated_at;',
        <Object?>[
          row.id,
          row.sortOrder,
          row.assistantId,
          row.payload,
          updatedAt,
        ],
      );
    }
    return _database.customStatement(
      'INSERT INTO ${kind.tableName} '
      '(${kind.idColumn}, sort_order, payload, updated_at) '
      'VALUES (?, ?, ?, ?) ON CONFLICT(${kind.idColumn}) DO UPDATE SET '
      'sort_order = excluded.sort_order, payload = excluded.payload, '
      'updated_at = excluded.updated_at;',
      <Object?>[row.id, row.sortOrder, row.payload, updatedAt],
    );
  }

  Future<void> _deleteEntity(BusinessEntityKind kind, String id) =>
      _database.customStatement(
        'DELETE FROM ${kind.tableName} WHERE ${kind.idColumn} = ?;',
        <Object?>[id],
      );

  Future<void> _replacePreferences(Map<String, Object> preferences) async {
    await _database.customStatement('DELETE FROM preference_rows;');
    final updatedAt = DateTime.now().toUtc().microsecondsSinceEpoch;
    for (final entry in preferences.entries) {
      await _database.customStatement(
        'INSERT INTO preference_rows (key, value, updated_at) '
        'VALUES (?, ?, ?);',
        <Object?>[entry.key, jsonEncode(entry.value), updatedAt],
      );
    }
  }

  Future<void> _writeMigrationReceipt() => _database.customStatement(
    'INSERT INTO chat_storage_meta_rows (key, value) VALUES (?, ?) '
    'ON CONFLICT(key) DO UPDATE SET value = excluded.value;',
    <Object?>[migrationReceiptKey, 'true'],
  );

  static void _validateRows(
    BusinessEntityKind kind,
    List<BusinessEntityValue> rows,
  ) {
    final ids = <String>{};
    for (final row in rows) {
      if (row.id.isEmpty) throw ArgumentError.value(row.id, 'id');
      if (row.sortOrder < 0) {
        throw ArgumentError.value(row.sortOrder, 'sortOrder');
      }
      if (!ids.add(row.id)) throw ArgumentError.value(row.id, 'duplicateId');
      final Object? decoded;
      try {
        decoded = jsonDecode(row.payload);
      } on FormatException {
        throw ArgumentError.value(row.payload, 'payload');
      }
      if (decoded is! Map) {
        throw ArgumentError.value(row.payload, 'payload');
      }
      if (kind == BusinessEntityKind.assistantMemory) {
        final assistantId = row.assistantId;
        if (assistantId == null || assistantId.trim().isEmpty) {
          throw ArgumentError.value(assistantId, 'assistantId');
        }
        if (decoded['assistantId'] != assistantId) {
          throw ArgumentError.value(row.payload, 'payload');
        }
      }
    }
  }

  static bool _sameEntity(
    BusinessEntityValue left,
    BusinessEntityValue right,
  ) =>
      left.id == right.id &&
      left.sortOrder == right.sortOrder &&
      left.payload == right.payload &&
      left.assistantId == right.assistantId;

  static Object _normalizePreference(String key, Object value) {
    if (value is bool || value is int || value is double || value is String) {
      jsonEncode(value);
      return value;
    }
    if (value is List && value.every((item) => item is String)) {
      return List<String>.unmodifiable(value.cast<String>());
    }
    throw ArgumentError.value(value, key);
  }

  static Object _decodePreference(String key, String encoded) {
    final Object? decoded;
    try {
      decoded = jsonDecode(encoded);
    } on FormatException {
      throw StateError('business_preference_value:$key');
    }
    if (decoded == null) throw StateError('business_preference_value:$key');
    try {
      return _normalizePreference(key, decoded);
    } on ArgumentError {
      throw StateError('business_preference_value:$key');
    }
  }
}
