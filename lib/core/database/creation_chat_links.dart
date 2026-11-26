part of 'media_repository.dart';

const _creationLinkMarker = 'creation_chat_originals_v1';
const _pendingCopyPrefix = 'creation-copy/';

typedef CreationOriginal = ({String uri, int bytes});
typedef CreationCopyCheck = ({Set<String> identical, Set<String> retry});

extension CreationChatLinks on MediaRepository {
  Future<void> invalidateChatOriginals() async {
    await (_db.delete(
      _db.chatStorageMetaRows,
    )..where((row) => row.key.equals(_creationLinkMarker))).go();
  }

  /// Verify files before changing their owner. File reads never hold a SQLite
  /// writer lock. A restore or failed file recovery leaves the work retryable.
  Future<Map<String, String>> adoptChatOriginals({
    required Future<Set<String>> Function(Map<String, CreationOriginal>)
    prepare,
    required Future<CreationCopyCheck> Function(Map<String, String>)
    identicalReferences,
  }) async {
    if (await (_db.select(
          _db.chatStorageMetaRows,
        )..where((r) => r.key.equals(_creationLinkMarker))).getSingleOrNull() !=
        null) {
      return _pendingCopies();
    }
    final rows = await _db.customSelect(r"""
      SELECT DISTINCT json_extract(p.payload,'$.uri') AS uri, i.path, i.byte_size
      FROM message_part_rows p JOIN generation_item_rows i ON i.id=(
        CASE WHEN p.kind='image' AND json_valid(p.payload) THEN json_extract(p.payload,'$.generationItemId') END
      )
      WHERE i.mode='image' AND i.status='ready' AND CASE WHEN p.kind='image' AND json_valid(p.payload) THEN
        json_type(p.payload,'$.uri')='text' AND (json_extract(p.payload,'$.uri')<>i.path OR json_extract(p.payload,'$.unavailable')=1) END
    """).get();
    final restoredReferences = await _restoredReferenceOriginals();
    final candidates = <String, CreationOriginal>{
      ...restoredReferences,
      for (final r in rows)
        r.read<String>('uri'): (
          uri: r.read<String>('path'),
          bytes: r.read<int>('byte_size'),
        ),
    };
    final prepared = candidates.isEmpty
        ? <String>{}
        : await prepare(candidates);
    final references = await _oldEditReferences();
    final matching = references.isEmpty
        ? (identical: <String>{}, retry: <String>{})
        : await identicalReferences(references);
    return _db.transaction(() async {
      final copies = {
        for (final uri in matching.identical) uri: references[uri]!,
      };
      final links = {
        ...copies,
        for (final entry in restoredReferences.entries)
          if (prepared.contains(entry.key)) entry.key: entry.value.uri,
      };
      if (links.isNotEmpty) {
        final mapping = Variable.withString(jsonEncode(links));
        await _db.customUpdate(
          r"""
          WITH links(old,path) AS (SELECT key,value FROM json_each(?))
          UPDATE generation_batch_rows SET references_json=(
            SELECT json_group_array(json(CASE WHEN l.path IS NULL THEN r.value ELSE json_remove(json_set(r.value,'$.path',l.path),'$.unavailable') END))
            FROM json_each(references_json) r LEFT JOIN links l ON l.old=json_extract(r.value,'$.path'))
          WHERE references_json<>'[]' AND json_valid(references_json) AND EXISTS(SELECT 1 FROM json_each(references_json) r
            WHERE json_extract(r.value,'$.path') IN (SELECT old FROM links))
        """,
          variables: [mapping],
          updates: {_db.generationBatchRows},
        );
      }
      final dirty = <String>{};
      final changes = await _db.customSelect(r"""
        SELECT p.part_id,p.revision_id,json_extract(p.payload,'$.generationItemId') AS id,
          json_extract(p.payload,'$.uri') AS uri,i.path,COALESCE(json_extract(p.payload,'$.unavailable'),0) AS unavailable
        FROM message_part_rows p LEFT JOIN generation_item_rows i ON i.id=(
          CASE WHEN p.kind='image' AND json_valid(p.payload) THEN json_extract(p.payload,'$.generationItemId') END
        ) AND i.mode='image' AND i.status='ready'
        WHERE p.kind='image' AND instr(p.payload,'generationItemId')>0 AND json_valid(p.payload)
          AND json_type(p.payload,'$.generationItemId')='text' AND json_type(p.payload,'$.uri')='text'
          AND (i.path IS NOT json_extract(p.payload,'$.uri') OR i.path IS NOT NULL AND json_extract(p.payload,'$.unavailable')=1)
      """).get();
      var complete =
          matching.retry.isEmpty &&
          restoredReferences.keys.every(prepared.contains);
      for (final r in changes) {
        final id = r.read<String>('id');
        final old = r.readNullable<String>('uri');
        if (old == null || !KelivoFileUri.isGenerationId(id)) continue;
        final path = r.readNullable<String>('path');
        final live =
            path != null && KelivoFileUri.generationImageItemId(path) == id;
        final target = live ? path : 'unavailable:creation/$id';
        final available =
            live && prepared.contains(old) && candidates[old]?.uri == path;
        if (old == target && (r.read<int>('unavailable') != 0) == !available) {
          continue;
        }
        if (live && KelivoFileUri.decodeToSegments(old)?.first == 'upload') {
          if (!available) {
            complete = false;
            continue;
          }
          copies[old] = path;
        }
        await _db.customUpdate(
          r"""
          UPDATE message_part_rows SET payload=json_set(json_remove(payload,'$.assetId'),'$.uri',?,'$.unavailable',json(?))
          WHERE part_id=?
        """,
          variables: [
            Variable.withString(target),
            Variable.withString(available ? 'false' : 'true'),
            Variable.withInt(r.read<int>('part_id')),
          ],
          updates: {_db.messagePartRows},
        );
        dirty.add(r.read<String>('revision_id'));
      }
      final tools = await _db.customSelect(r"""
        SELECT part_id, revision_id,json_extract(payload,'$.name') AS name,
          json_extract(payload,'$.metadata.generatedImage') AS generated,
          json_extract(payload,'$.metadata.chatImage.sourceKey') AS source,
          json_extract(payload,'$.metadata.mcpResult.imageUris') AS images
        FROM message_part_rows WHERE kind='tool_call' AND json_valid(payload)
          AND (instr(payload,'generatedImage')>0 OR (instr(payload,'chatImage')>0 AND instr(payload,'|creation:')>0))
      """).get();
      for (final r in tools) {
        final part = Variable.withInt(r.read<int>('part_id'));
        final name = r.readNullable<String>('name');
        if (name == 'generate_image') {
          final encoded = r.readNullable<String>('generated');
          if (encoded == null) continue;
          try {
            final value = jsonDecode(encoded);
            final list = value is List;
            var changed = false;
            Future<Object?> remap(Object? raw) async {
              final record = raw is String ? jsonDecode(raw) : raw;
              if (record is! Map ||
                  record['generationItemId'] is! String ||
                  record['uri'] is! String) {
                return raw;
              }
              final id = record['generationItemId'] as String;
              final old = record['uri'] as String;
              if (!KelivoFileUri.isGenerationId(id)) return raw;
              final row = await item(id);
              final live =
                  row?.status == GenerationItemStatus.ready &&
                  KelivoFileUri.generationImageItemId(row!.path) == id;
              final uri = live ? row.path : 'unavailable:creation/$id';
              if (uri == old ||
                  (live &&
                      KelivoFileUri.decodeToSegments(old)?.first == 'upload' &&
                      !prepared.contains(old))) {
                return raw;
              }
              record.remove('assetId');
              record['uri'] = uri;
              record['unavailable'] = !live;
              changed = true;
              return jsonEncode(record);
            }

            final mapped = list
                ? [for (final raw in value) await remap(raw)]
                : await remap(value);
            if (!changed) continue;
            await _db.customUpdate(
              list
                  ? r"""UPDATE message_part_rows SET payload=json_set(payload,'$.metadata.generatedImage',json(?)) WHERE part_id=?"""
                  : r"""UPDATE message_part_rows SET payload=json_set(payload,'$.metadata.generatedImage',?) WHERE part_id=?""",
              variables: [
                Variable.withString(
                  list ? jsonEncode(mapped) : mapped as String,
                ),
                part,
              ],
              updates: {_db.messagePartRows},
            );
          } on FormatException {
            continue;
          }
        } else if (name == 'view_image') {
          final id = creationItemFromSourceKey(
            r.readNullable<String>('source'),
          );
          final previous = r.readNullable<String>('images');
          if (id == null || previous == null) continue;
          final row = await item(id);
          final uris = jsonEncode([
            if (row?.status == GenerationItemStatus.ready &&
                KelivoFileUri.generationImageItemId(row!.path) == id)
              row.path,
          ]);
          if (uris == r.readNullable<String>('images')) continue;
          await _db.customUpdate(
            r"""UPDATE message_part_rows SET payload=json_set(payload,'$.metadata.mcpResult.imageUris',json(?)) WHERE part_id=?""",
            variables: [Variable.withString(uris), part],
            updates: {_db.messagePartRows},
          );
        } else {
          continue;
        }
        dirty.add(r.read<String>('revision_id'));
      }
      if (dirty.isNotEmpty) {
        await _db.customStatement(
          'INSERT OR IGNORE INTO asset_reference_dirty_rows(revision_id) SELECT value FROM json_each(?)',
          [jsonEncode(dirty.toList())],
        );
      }
      // A crash after relinking must not strand the superseded snapshot.
      if (copies.isNotEmpty) {
        await _db.batch((batch) {
          for (final entry in copies.entries) {
            batch.insert(
              _db.chatStorageMetaRows,
              ChatStorageMetaRowsCompanion.insert(
                key: '$_pendingCopyPrefix${entry.key}',
                value: entry.value,
              ),
              mode: InsertMode.insertOrReplace,
            );
          }
        });
      }
      if (complete) {
        await _db
            .into(_db.chatStorageMetaRows)
            .insertOnConflictUpdate(
              ChatStorageMetaRowsCompanion.insert(
                key: _creationLinkMarker,
                value: '1',
              ),
            );
      }
      return _pendingCopies();
    });
  }

  Future<Map<String, CreationOriginal>> _restoredReferenceOriginals() async {
    final unavailable = await _db.customSelect(r"""
      SELECT DISTINCT json_extract(r.value,'$.path') AS path
      FROM generation_batch_rows b, json_each(b.references_json) r
      WHERE instr(b.references_json,'"unavailable"')>0 AND json_extract(r.value,'$.unavailable')=1
        AND json_type(r.value,'$.path')='text'
    """).get();
    final ids = {
      for (final row in unavailable)
        if (row.read<String>('path') case final path)
          if (KelivoFileUri.generationImageItemId(path) case final id?)
            path: id,
    };
    if (ids.isEmpty) return {};
    final installed = await _db
        .customSelect(
          "SELECT j.key AS old,i.id,i.path,i.byte_size FROM json_each(?) j "
          "JOIN generation_item_rows i ON i.id=j.value WHERE i.mode='image' AND i.status='ready'",
          variables: [Variable.withString(jsonEncode(ids))],
        )
        .get();
    return {
      for (final row in installed)
        if (KelivoFileUri.generationImageItemId(row.read<String>('path')) ==
            row.read<String>('id'))
          row.read<String>('old'): (
            uri: row.read<String>('path'),
            bytes: row.read<int>('byte_size'),
          ),
    };
  }

  Future<Map<String, String>> _pendingCopies() async {
    final rows = await (_db.select(
      _db.chatStorageMetaRows,
    )..where((r) => r.key.like('$_pendingCopyPrefix%'))).get();
    return {
      for (final row in rows)
        if (row.key.startsWith(_pendingCopyPrefix) &&
            KelivoFileUri.generationImageItemId(row.value) != null)
          if (row.key.substring(_pendingCopyPrefix.length) case final old
              when KelivoFileUri.decodeToSegments(old)?.first == 'upload' ||
                  KelivoFileUri.isGenerationReferenceSnapshot(old))
            old: row.value,
    };
  }

  Future<void> finishCopyCleanup(Map<String, String> copies) =>
      _db.batch((batch) {
        for (final entry in copies.entries) {
          batch.deleteWhere(
            _db.chatStorageMetaRows,
            (r) =>
                r.key.equals('$_pendingCopyPrefix${entry.key}') &
                r.value.equals(entry.value),
          );
        }
      });

  /// Only link an old snapshot when an edit names its parent or the chat tool
  /// explicitly received the corresponding generated handle in that slot.
  Future<Map<String, String>> _oldEditReferences() async {
    final rows = await _db.customSelect(r"""
      SELECT b.id,b.references_json,i.path AS parent,b.conversation_id,
        CASE WHEN p.kind='tool_call' AND json_valid(p.payload) THEN json_extract(p.payload,'$.arguments.image_ids') END AS handles
      FROM generation_batch_rows b LEFT JOIN generation_item_rows i ON i.id=b.parent_item_id AND i.status='ready' AND i.mode='image'
      LEFT JOIN message_part_rows p ON b.message_id=p.revision_id AND p.kind='tool_call'
        AND CASE WHEN json_valid(p.payload) THEN json_extract(p.payload,'$.metadata.generationBatchId') END=b.id
        AND json_extract(p.payload,'$.name')='generate_image'
      WHERE instr(b.references_json,'/refs/')>0 AND (i.path IS NOT NULL OR p.part_id IS NOT NULL)
    """).get();
    if (rows.isEmpty) return {};
    final visible = <(String, String), String>{};
    final chats = {
      for (final row in rows)
        if (row.readNullable<String>('handles') != null &&
            row.readNullable<String>('conversation_id') != null)
          row.read<String>('conversation_id'),
    };
    if (chats.isNotEmpty) {
      final outputs = await _db
          .customSelect(
            r"""
        SELECT b.conversation_id,i.id,i.path FROM generation_item_rows i JOIN generation_batch_rows b ON b.id=i.batch_id
        WHERE b.conversation_id IN (SELECT value FROM json_each(?)) AND i.status='ready' AND i.mode='image'
      """,
            variables: [Variable.withString(jsonEncode(chats.toList()))],
          )
          .get();
      for (final r in outputs) {
        final id = r.read<String>('id'), path = r.read<String>('path');
        if (KelivoFileUri.generationImageItemId(path) == id) {
          visible[(
                r.read<String>('conversation_id'),
                ContextImageIdentity('', 'creation:$id').handle,
              )] =
              path;
        }
      }
    }
    final result = <String, String>{};
    for (final row in rows) {
      final batch = row.read<String>('id'),
          parent = row.readNullable<String>('parent');
      final raw = row.readNullable<String>('handles');
      final handles = raw == null
          ? const <Object?>[]
          : MediaRepository._references(raw);
      final chat = row.readNullable<String>('conversation_id');
      final refs = MediaRepository._references(
        row.read<String>('references_json'),
      );
      for (final (index, ref) in refs.indexed) {
        if (ref is! Map || ref['unavailable'] == true) continue;
        final path = ref['path'];
        if (path is! String ||
            !KelivoFileUri.isGenerationReferenceSnapshot(path, batch: batch)) {
          continue;
        }
        final source =
            chat != null && index < handles.length && handles[index] is String
            ? visible[(chat, handles[index] as String)]
            : refs.length == 1
            ? parent
            : null;
        if (source != null &&
            KelivoFileUri.generationImageItemId(source) != null) {
          result[path] = source;
        }
      }
    }
    return result;
  }
}
