import 'dart:convert';

import 'package:drift/drift.dart';

import 'app_database.dart';

class ExtensionEntity {
  final String kind;
  final String id;
  final Map<String, dynamic> payload;
  final int sortOrder;
  final String? ownerId;
  final DateTime updatedAt;

  const ExtensionEntity({
    required this.kind,
    required this.id,
    required this.payload,
    required this.sortOrder,
    this.ownerId,
    required this.updatedAt,
  });
}

/// Typed access to the schema-3 `extension_entity_rows` table.
class ExtensionEntityStore {
  ExtensionEntityStore(this._db);

  static const String kindWorkspace = 'workspace';
  static const String kindSkill = 'skill';

  final AppDatabase _db;

  Future<List<ExtensionEntity>> listByKind(String kind) async {
    final rows =
        await (_db.select(_db.extensionEntityRows)
              ..where((t) => t.kind.equals(kind))
              ..orderBy([
                (t) => OrderingTerm.asc(t.sortOrder),
                (t) => OrderingTerm.asc(t.id),
              ]))
            .get();
    return [for (final row in rows) _fromRow(row)];
  }

  Future<ExtensionEntity?> get(String kind, String id) async {
    final row = await (_db.select(
      _db.extensionEntityRows,
    )..where((t) => t.kind.equals(kind) & t.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    return _fromRow(row);
  }

  Future<void> upsert(
    String kind,
    String id,
    Map<String, dynamic> payload, {
    int? sortOrder,
    String? ownerId,
  }) async {
    final existing = await get(kind, id);
    final resolvedSort =
        sortOrder ?? existing?.sortOrder ?? await _nextSortOrder(kind);
    await _db
        .into(_db.extensionEntityRows)
        .insertOnConflictUpdate(
          ExtensionEntityRowsCompanion.insert(
            kind: kind,
            id: id,
            sortOrder: resolvedSort,
            ownerId: Value(ownerId ?? existing?.ownerId),
            payload: jsonEncode(payload),
            updatedAt: DateTime.now().toUtc(),
          ),
        );
  }

  Future<void> delete(String kind, String id) async {
    await (_db.delete(
      _db.extensionEntityRows,
    )..where((t) => t.kind.equals(kind) & t.id.equals(id))).go();
  }

  Stream<List<ExtensionEntity>> watchKind(String kind) {
    return (_db.select(_db.extensionEntityRows)
          ..where((t) => t.kind.equals(kind))
          ..orderBy([
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .watch()
        .map((rows) => [for (final row in rows) _fromRow(row)]);
  }

  Future<int> _nextSortOrder(String kind) async {
    final maxOrder = _db.extensionEntityRows.sortOrder.max();
    final row =
        await (_db.selectOnly(_db.extensionEntityRows)
              ..addColumns([maxOrder])
              ..where(_db.extensionEntityRows.kind.equals(kind)))
            .getSingle();
    return (row.read(maxOrder) ?? -1) + 1;
  }

  ExtensionEntity _fromRow(ExtensionEntityRow row) {
    return ExtensionEntity(
      kind: row.kind,
      id: row.id,
      payload: _decodePayload(row.payload),
      sortOrder: row.sortOrder,
      ownerId: row.ownerId,
      updatedAt: row.updatedAt,
    );
  }

  static Map<String, dynamic> _decodePayload(String raw) {
    if (raw.isEmpty || raw == '{}') return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (_) {}
    return <String, dynamic>{};
  }
}
