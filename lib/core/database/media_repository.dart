import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import '../../utils/kelivo_file_uri.dart';

import '../models/media_creation.dart';
import '../models/image_context.dart' show ContextImageIdentity;
import '../utils/chat_image_result.dart' show creationItemFromSourceKey;
import 'app_database.dart';

part 'creation_chat_links.dart';

class MediaRepository {
  MediaRepository(this._db);

  final AppDatabase _db;
  int _replacementVersion = 0;
  bool _writesPaused = false;

  int get replacementVersion => _replacementVersion;
  bool get canWrite => !_writesPaused;

  void pauseWrites() => _writesPaused = true;
  void resumeWrites() => _writesPaused = false;

  Stream<List<GenerationTopicRow>> watchTopics() => (_db.select(
    _db.generationTopicRows,
  )..orderBy([(row) => OrderingTerm.desc(row.updatedAt)])).watch();

  Stream<List<GenerationBatchRow>> watchBatches() => (_db.select(
    _db.generationBatchRows,
  )..orderBy([(row) => OrderingTerm.asc(row.createdAt)])).watch();

  Stream<List<GenerationItemRow>> watchItems() =>
      (_db.select(_db.generationItemRows)..orderBy([
            (row) => OrderingTerm.desc(row.createdAt),
            (row) => OrderingTerm.asc(row.ordinal),
          ]))
          .watch();

  Future<GenerationBatchRow?> batch(String id) => (_db.select(
    _db.generationBatchRows,
  )..where((row) => row.id.equals(id))).getSingleOrNull();

  Future<List<GenerationItemRow>> itemsForBatch(String id) =>
      (_db.select(_db.generationItemRows)
            ..where((row) => row.batchId.equals(id))
            ..orderBy([(row) => OrderingTerm.asc(row.ordinal)]))
          .get();

  Future<List<String>> batchesForTopic(String id) async {
    final rows = await (_db.select(
      _db.generationBatchRows,
    )..where((row) => row.topicId.equals(id))).get();
    return [for (final row in rows) row.id];
  }

  Future<List<String>> completedBatchIdsBefore(DateTime cutoff) async {
    final table = _db.generationBatchRows;
    final rows =
        await (_db.selectOnly(table)
              ..addColumns([table.id])
              ..where(
                table.createdAt.isSmallerThanValue(
                      cutoff.microsecondsSinceEpoch,
                    ) &
                    table.status.isIn([
                      for (final status in GenerationStatus.values)
                        if (!status.isActive) status.name,
                    ]),
              ))
            .get();
    return [for (final row in rows) row.read(table.id)!];
  }

  Future<void> enqueue(
    GenerationBatchRowsCompanion batch, {
    GenerationTopicRowsCompanion? topic,
  }) => _db.transaction(() async {
    _requireWritable();
    if (topic != null) await _db.into(_db.generationTopicRows).insert(topic);
    await _db.into(_db.generationBatchRows).insert(batch);
    final topicId = batch.topicId.value;
    if (topicId != null && topic == null) {
      await (_db.update(_db.generationTopicRows)
            ..where((row) => row.id.equals(topicId)))
          .write(GenerationTopicRowsCompanion(updatedAt: batch.createdAt));
    }
  });

  Future<void> updateBatch(
    String id,
    GenerationBatchRowsCompanion values,
  ) async {
    _requireWritable();
    await (_db.update(
      _db.generationBatchRows,
    )..where((row) => row.id.equals(id))).write(values);
  }

  Future<void> addItem(GenerationItemRow item) async {
    _requireWritable();
    await _db.into(_db.generationItemRows).insert(item);
  }

  Future<List<String>> markInterrupted() => _db.transaction(() async {
    final table = _db.generationBatchRows;
    final active = table.status.isIn([
      GenerationStatus.queued.name,
      GenerationStatus.running.name,
      GenerationStatus.downloading.name,
    ]);
    final rows =
        await (_db.selectOnly(table)
              ..addColumns([table.id])
              ..where(
                active | table.status.equals(GenerationStatus.interrupted.name),
              ))
            .get();
    if (rows.isNotEmpty) {
      await (_db.update(table)..where((_) => active)).write(
        GenerationBatchRowsCompanion(
          status: const Value(GenerationStatus.interrupted),
          finishedAt: Value(DateTime.now()),
        ),
      );
    }
    return [for (final row in rows) row.read(table.id)!];
  });

  Future<GenerationItemRow?> item(String id) => (_db.select(
    _db.generationItemRows,
  )..where((row) => row.id.equals(id))).getSingleOrNull();

  Future<bool> ownsImage(String uri) async {
    final id = KelivoFileUri.generationImageItemId(uri);
    if (id == null) return false;
    final image = await item(id);
    return image != null &&
        image.path == uri &&
        image.mode == MediaMode.image &&
        image.status == GenerationItemStatus.ready;
  }

  Future<bool> hasItem(String id) async =>
      await (_db.select(
        _db.generationItemRows,
      )..where((row) => row.id.equals(id))).getSingleOrNull() !=
      null;

  Future<void> renameTopic(
    String id,
    String title,
    GenerationTitleSource source,
  ) async {
    _requireWritable();
    await (_db.update(
      _db.generationTopicRows,
    )..where((row) => row.id.equals(id))).write(
      GenerationTopicRowsCompanion(
        title: Value(title),
        titleSource: Value(source),
      ),
    );
  }

  Future<void> finishAutoTitle(
    String id,
    String title,
    GenerationTitleSource source,
  ) async {
    _requireWritable();
    await (_db.update(_db.generationTopicRows)..where(
          (row) =>
              row.id.equals(id) &
              row.titleSource.equals(GenerationTitleSource.auto.name),
        ))
        .write(
          GenerationTopicRowsCompanion(
            title: Value(title),
            titleSource: Value(source),
          ),
        );
  }

  Future<void> deleteTopic(String id) => _db.transaction(() async {
    _requireWritable();
    await _retireImages(
      await _db
          .customSelect(
            'SELECT i.id,i.path FROM generation_item_rows i JOIN generation_batch_rows b ON b.id=i.batch_id WHERE b.topic_id=? AND i.mode=\'image\'',
            variables: [Variable.withString(id)],
          )
          .get(),
    );
    await (_db.delete(
      _db.generationTopicRows,
    )..where((row) => row.id.equals(id))).go();
  });

  Future<void> deleteItem(String id) => _db.transaction(() async {
    _requireWritable();
    await _retireImages(
      await _db
          .customSelect(
            "SELECT id,path FROM generation_item_rows WHERE id=? AND mode='image'",
            variables: [Variable.withString(id)],
          )
          .get(),
    );
    await (_db.delete(
      _db.generationItemRows,
    )..where((row) => row.id.equals(id))).go();
  });

  Future<void> setFavorite(String id, bool favorite) async {
    _requireWritable();
    await (_db.update(_db.generationItemRows)
          ..where((row) => row.id.equals(id)))
        .write(GenerationItemRowsCompanion(favorite: Value(favorite)));
  }

  Future<void> deleteBatch(String id) => _db.transaction(() async {
    _requireWritable();
    final existing = await batch(id);
    if (existing == null) return;
    await _retireImages(
      await _db
          .customSelect(
            "SELECT id,path FROM generation_item_rows WHERE batch_id=? AND mode='image'",
            variables: [Variable.withString(id)],
          )
          .get(),
    );
    await (_db.delete(
      _db.generationBatchRows,
    )..where((row) => row.id.equals(id))).go();
    final topicId = existing.topicId;
    if (topicId == null) return;
    final newest =
        await (_db.select(_db.generationBatchRows)
              ..where((row) => row.topicId.equals(topicId))
              ..orderBy([(row) => OrderingTerm.desc(row.createdAt)])
              ..limit(1))
            .getSingleOrNull();
    final topic = await (_db.select(
      _db.generationTopicRows,
    )..where((row) => row.id.equals(topicId))).getSingleOrNull();
    if (topic != null) {
      await (_db.update(
        _db.generationTopicRows,
      )..where((row) => row.id.equals(topicId))).write(
        GenerationTopicRowsCompanion(
          updatedAt: Value(newest?.createdAt ?? topic.createdAt),
        ),
      );
    }
  });

  Future<void> _retireImages(List<QueryRow> items) async {
    if (items.isEmpty) return;
    final originals = jsonEncode({
      for (final r in items) r.read<String>('id'): r.read<String>('path'),
    });
    await _db.customUpdate(
      r"""
      UPDATE message_part_rows SET payload=json_set(payload,'$.unavailable',json('true'))
      WHERE kind='image' AND instr(payload,'generationItemId')>0 AND json_valid(payload) AND
        json_extract(payload,'$.generationItemId') IN (SELECT key FROM json_each(?))
    """,
      variables: [Variable.withString(originals)],
      updates: {_db.messagePartRows},
    );
    await _db.customUpdate(
      r"""
      UPDATE message_part_rows SET payload=json_set(payload,'$.metadata.mcpResult.imageUris',json('[]'))
      WHERE kind='tool_call' AND instr(payload,'chatImage')>0 AND json_valid(payload) AND json_extract(payload,'$.name')='view_image' AND
        json_type(payload,'$.metadata.chatImage')='object' AND EXISTS(
          SELECT 1 FROM json_each(payload,'$.metadata.mcpResult.imageUris')
          WHERE value IN(SELECT value FROM json_each(?)))
    """,
      variables: [Variable.withString(originals)],
      updates: {_db.messagePartRows},
    );
    await _db.customUpdate(
      r"""
      WITH retired(path) AS (SELECT value FROM json_each(?))
      UPDATE generation_batch_rows SET references_json=(
        SELECT json_group_array(json(CASE WHEN json_extract(r.value,'$.path') IN retired
          THEN json_set(r.value,'$.unavailable',json('true')) ELSE r.value END))
        FROM json_each(references_json) r)
      WHERE references_json<>'[]' AND json_valid(references_json) AND EXISTS(SELECT 1 FROM json_each(references_json) r WHERE json_extract(r.value,'$.path') IN retired)
    """,
      variables: [Variable.withString(originals)],
      updates: {_db.generationBatchRows},
    );
  }

  Future<List<RecentMediaImage>> recentImages(
    RecentImageSource source, {
    required int offset,
    required int limit,
  }) async {
    final rows = await _db
        .customSelect(
          r"""
      SELECT path, thumbnail, title, source
      FROM (
        SELECT i.path, i.thumbnail_path AS thumbnail, COALESCE(t.title, '') AS title,
               'creation' AS source, i.created_at AS time, i.id AS tie
        FROM generation_item_rows AS i
        JOIN generation_batch_rows AS b ON b.id = i.batch_id
        LEFT JOIN generation_topic_rows AS t ON t.id = b.topic_id
        WHERE ? IN ('all', 'creation') AND i.mode = 'image' AND i.status = 'ready'
        UNION ALL
        SELECT COALESCE(i.path, a.path, json_extract(p.payload, '$.uri')) AS path,
               COALESCE(i.thumbnail_path, a.thumbnail_path) AS thumbnail, c.title, 'chat' AS source,
               p.created_at AS time, CAST(p.part_id AS TEXT) AS tie
        FROM message_part_rows AS p
        JOIN conversation_rows AS c ON c.id = p.conversation_id
        LEFT JOIN generation_item_rows AS i
          ON i.id = CASE WHEN json_valid(p.payload) THEN json_extract(p.payload, '$.generationItemId') END
          AND i.mode='image' AND i.status='ready'
        LEFT JOIN asset_rows AS a
          ON a.id = CASE WHEN json_valid(p.payload) THEN json_extract(p.payload, '$.assetId') END
        WHERE ? IN ('all', 'chat') AND p.kind = 'image' AND json_valid(p.payload)
          AND COALESCE(json_extract(p.payload, '$.unavailable'), 0) = 0
          AND (json_extract(p.payload,'$.generationItemId') IS NULL OR
              (? = 'chat' AND i.id IS NOT NULL))
      )
      WHERE path IS NOT NULL AND length(path) > 0
        AND path NOT LIKE 'data:%'
      ORDER BY time DESC, source, tie DESC
      LIMIT ? OFFSET ?
      """,
          variables: [
            Variable.withString(source.name),
            Variable.withString(source.name),
            Variable.withString(source.name),
            Variable.withInt(limit),
            Variable.withInt(offset),
          ],
        )
        .get();
    return [
      for (final row in rows)
        RecentMediaImage(
          path: row.read<String>('path'),
          title: row.read<String>('title'),
          source: RecentImageSource.values.byName(row.read<String>('source')),
          thumbnailPath: row.readNullable<String>('thumbnail'),
        ),
    ];
  }

  Future<bool> get hasCreations async {
    final result = await _db
        .customSelect(
          'SELECT EXISTS (SELECT 1 FROM generation_topic_rows) OR '
          'EXISTS (SELECT 1 FROM generation_batch_rows) AS present',
        )
        .getSingle();
    return result.read<int>('present') != 0;
  }

  Future<Set<String>> referencedFiles() => _db.transaction(() async {
    final items =
        await (_db.selectOnly(_db.generationItemRows)..addColumns([
              _db.generationItemRows.path,
              _db.generationItemRows.thumbnailPath,
            ]))
            .get();
    final batches = await (_db.selectOnly(
      _db.generationBatchRows,
    )..addColumns([_db.generationBatchRows.referencesJson])).get();
    return {
      for (final item in items) ...[
        item.read(_db.generationItemRows.path)!,
        ?item.read(_db.generationItemRows.thumbnailPath),
      ],
      for (final batch in batches)
        for (final reference in _references(
          batch.read(_db.generationBatchRows.referencesJson)!,
        ))
          if (reference case {
            'path': final String path,
          } when reference['unavailable'] != true)
            path,
    };
  });

  Future<void> clear() => _db.transaction(() async {
    _requireWritable();
    await _db.delete(_db.generationBatchRows).go();
    await _db.delete(_db.generationTopicRows).go();
  });

  static void validateSnapshotPaths(sqlite.Database database) {
    final batches = database.prepare(
      'SELECT id, references_json FROM generation_batch_rows',
    );
    final items = database.prepare(
      'SELECT id, batch_id, path, thumbnail_path FROM generation_item_rows',
    );
    try {
      final batchRows = batches.selectCursor();
      while (batchRows.moveNext()) {
        final row = batchRows.current;
        referencePaths(row['id'] as String, row['references_json'] as String);
      }
      final itemRows = items.selectCursor();
      while (itemRows.moveNext()) {
        final row = itemRows.current;
        _validateItemPaths(
          row['id'] as String,
          row['batch_id'] as String,
          row['path'] as String,
          row['thumbnail_path'] as String?,
        );
      }
    } finally {
      batches.close();
      items.close();
    }
  }

  /// Only ownership and file paths matter when preserving interrupted writes.
  /// Request parameters and reference roles are interpreted when a job runs.
  static Set<String> referencePaths(String id, String referencesJson) {
    final refs = jsonDecode(referencesJson);
    if (!KelivoFileUri.isGenerationId(id) || refs is! List) {
      throw const FormatException('Invalid stored creation references');
    }
    final paths = <String>{};
    for (final ref in refs) {
      if (ref case {
        'path': final String path,
      } when KelivoFileUri.isGenerationReference(path, id)) {
        if (ref['unavailable'] != true) paths.add(path);
      } else {
        throw const FormatException('Invalid stored creation reference');
      }
    }
    return paths;
  }

  static void _validateItemPaths(
    String itemId,
    String batchId,
    String path,
    String? thumbnail,
  ) {
    if (!KelivoFileUri.isGenerationId(itemId) ||
        !KelivoFileUri.isGenerationFile(path, batchId) ||
        thumbnail != null &&
            !KelivoFileUri.isGenerationFile(thumbnail, batchId)) {
      throw const FormatException('Invalid stored creation file');
    }
  }

  /// Merge keeps the installed row for an existing item ID. Its files may
  /// have been renamed by an earlier overwrite restore.
  Future<Map<String, String>> existingPathsForMerge(
    MediaRepository source,
  ) async {
    final incoming = source._db.generationItemRows;
    final incomingRows = await (source._db.selectOnly(
      incoming,
    )..addColumns([incoming.id, incoming.path, incoming.thumbnailPath])).get();
    if (incomingRows.isEmpty) return {};
    final byId = {for (final row in incomingRows) row.read(incoming.id)!: row};
    final existing = await _db
        .customSelect(
          'SELECT id, path, thumbnail_path FROM generation_item_rows '
          'WHERE id IN (SELECT value FROM json_each(?))',
          variables: [Variable.withString(jsonEncode(byId.keys.toList()))],
        )
        .get();
    final paths = <String, String>{};
    for (final row in existing) {
      final sourceRow = byId[row.read<String>('id')]!;
      final path = sourceRow.read(incoming.path)!;
      final target = row.read<String>('path');
      if (path != target) paths[path] = target;
      final thumb = sourceRow.read(incoming.thumbnailPath);
      final targetThumb = row.readNullable<String>('thumbnail_path');
      if (thumb != null && targetThumb != null && thumb != targetThumb) {
        paths[thumb] = targetThumb;
      }
    }
    return paths;
  }

  Future<void> importFrom(
    MediaRepository? source, {
    required bool overwrite,
    Map<String, String> restoredPaths = const {},
    Map<String, String> remappedConversations = const {},
    Map<String, String>? mergedMessages,
  }) async {
    _requireWritable();
    if (source == null) {
      if (overwrite) {
        await _db.transaction(() async {
          await clear();
          await invalidateChatOriginals();
        });
        _replacementVersion++;
      }
      return;
    }
    final (topics, batches, items) = await source._db.transaction(
      () async => (
        await source._db.select(source._db.generationTopicRows).get(),
        await source._db.select(source._db.generationBatchRows).get(),
        await source._db.select(source._db.generationItemRows).get(),
      ),
    );
    for (final row in batches) {
      referencePaths(row.id, row.referencesJson);
    }
    for (final item in items) {
      _validateItemPaths(item.id, item.batchId, item.path, item.thumbnailPath);
    }
    await _db.transaction(() async {
      if (overwrite) await clear();
      await invalidateChatOriginals();
      await _db.batch((batch) {
        batch.insertAll(
          _db.generationTopicRows,
          topics,
          mode: InsertMode.insertOrIgnore,
        );
        batch.insertAll(_db.generationBatchRows, [
          for (final row in batches)
            row.copyWith(
              conversationId: Value(
                mergedMessages != null &&
                        row.messageId != null &&
                        !mergedMessages.containsKey(row.messageId)
                    ? null
                    : remappedConversations[row.conversationId] ??
                          row.conversationId,
              ),
              messageId: Value(
                mergedMessages == null
                    ? row.messageId
                    : mergedMessages[row.messageId],
              ),
              status: row.status.isActive
                  ? GenerationStatus.interrupted
                  : row.status,
              finishedAt: row.status.isActive
                  ? Value(DateTime.now())
                  : const Value.absent(),
              referencesJson: _remapReferences(
                row.referencesJson,
                restoredPaths,
              ),
            ),
        ], mode: InsertMode.insertOrIgnore);
        batch.insertAll(_db.generationItemRows, [
          for (final item in items)
            item.copyWith(
              path: restoredPaths[item.path] ?? item.path,
              thumbnailPath: Value(
                restoredPaths[item.thumbnailPath] ?? item.thumbnailPath,
              ),
            ),
        ], mode: InsertMode.insertOrIgnore);
      });
    });
    if (overwrite) _replacementVersion++;
  }

  static List<Object?> _references(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is List) return decoded;
    } on FormatException {
      // An invalid reference record cannot name a managed file.
    }
    return const [];
  }

  void _requireWritable() {
    if (_writesPaused) throw StateError('Creation history is awaiting restore');
  }

  static String _remapReferences(String json, Map<String, String> paths) {
    if (paths.isEmpty) return json;
    return jsonEncode([
      for (final reference in _references(json))
        if (reference case {
          'path': final String path,
        } when paths.containsKey(path))
          {...reference as Map, 'path': paths[path]!}
        else
          reference,
    ]);
  }
}
