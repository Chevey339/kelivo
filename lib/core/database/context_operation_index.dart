import 'dart:convert';

import 'package:drift/drift.dart';

import '../models/context_operation.dart';

/// Disposable metadata over the canonical extension record. Triggers change
/// its opaque revision for every payload mutation, including raw import SQL.
/// Approval checks never need to read or hash the compaction payload.
final class ContextOperationIndex {
  ContextOperationIndex(this.database);
  final GeneratedDatabase database;

  static const _kind = ContextOperation.entityKind;
  static const discardStatements = [
    'DROP TRIGGER IF EXISTS context_operation_insert',
    'DROP TRIGGER IF EXISTS context_operation_update',
    'DROP TRIGGER IF EXISTS context_operation_delete',
    'DROP TABLE IF EXISTS context_operation_state',
  ];

  // json_each and projection run on SQLite's worker. Only dependency metadata
  // crosses back to the UI isolate, even when the source holds megabytes.
  static String _metadata(String id) =>
      '''
COALESCE((SELECT json_group_array(json_object(
  'id',json_extract(j.value,'\$.id'),
  'kind',json_extract(j.value,'\$.kind'),
  'anchor',json_extract(j.value,'\$.anchor'),
  'appliedAfter',json_extract(j.value,'\$.appliedAfter'),
  'groups',json_extract(j.value,'\$.groups'),
  'dependencies',json_extract(j.value,'\$.dependencies'),
  'createdAt',json_extract(j.value,'\$.createdAt'),
  'revoked',json(CASE WHEN json_extract(j.value,'\$.revoked') THEN 'true' ELSE 'false' END)
)) FROM extension_entity_rows e, json_each(e.payload) j
WHERE e.kind='$_kind' AND e.id=$id), '[]')
''';

  static Future<void> install(GeneratedDatabase database) async {
    await database.transaction(() async {
      await database.customStatement('''
CREATE TABLE IF NOT EXISTS context_operation_state(
  conversation_id TEXT PRIMARY KEY REFERENCES conversation_rows(id) ON DELETE CASCADE,
  revision TEXT NOT NULL,
  metadata TEXT NOT NULL
) WITHOUT ROWID
''');
      for (final event in ['INSERT', 'UPDATE', 'DELETE']) {
        final condition = switch (event) {
          'INSERT' => "NEW.kind='$_kind'",
          'DELETE' => "OLD.kind='$_kind'",
          _ =>
            "(OLD.kind='$_kind' OR NEW.kind='$_kind') AND "
                '(OLD.payload IS NOT NEW.payload OR OLD.id IS NOT NEW.id OR OLD.kind IS NOT NEW.kind)',
        };
        final ids = switch (event) {
          'INSERT' => 'NEW.id',
          'DELETE' => 'OLD.id',
          _ => 'OLD.id,NEW.id',
        };
        await database.customStatement('''
CREATE TRIGGER IF NOT EXISTS context_operation_${event.toLowerCase()}
AFTER $event ON extension_entity_rows WHEN $condition
BEGIN
  UPDATE context_operation_state SET revision=lower(hex(randomblob(16))),
    metadata=${_metadata('context_operation_state.conversation_id')}
  WHERE conversation_id IN ($ids);
END
''');
      }
    });
  }

  Future<void> ensure(String id) async {
    // A caller may roll back the transaction that first creates this index.
    // Check its presence instead of caching an installation Future in Dart.
    if (await database
            .customSelect(
              "SELECT 1 FROM sqlite_master WHERE type='table' AND name='context_operation_state'",
            )
            .getSingleOrNull() ==
        null) {
      await install(database);
    }
    // Lazy per-conversation materialization keeps startup independent of the
    // number and size of stored compression records.
    await database.customStatement(
      '''
INSERT OR IGNORE INTO context_operation_state(conversation_id,revision,metadata)
SELECT c.id,lower(hex(randomblob(16))),${_metadata('c.id')}
FROM conversation_rows c WHERE c.id=?
AND NOT EXISTS(SELECT 1 FROM context_operation_state s WHERE s.conversation_id=c.id)
''',
      [id],
    );
  }

  Future<ContextMutationState> read(String id) async {
    await ensure(id);
    final row = await database
        .customSelect(
          'SELECT revision,metadata FROM context_operation_state WHERE conversation_id=?',
          variables: [Variable<String>(id)],
        )
        .getSingleOrNull();
    if (row == null) throw StateError('conversation_not_found');
    return (
      revision: row.read<String>('revision'),
      operations: [
        for (final value in jsonDecode(row.read<String>('metadata')) as List)
          ContextOperationMetadata.fromJson(
            Map<String, dynamic>.from(value as Map),
          ),
      ],
    );
  }
}
