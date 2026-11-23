import 'dart:convert';

import 'package:drift/drift.dart';

import '../models/media_creation.dart';
import 'app_database.dart';

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

  Future<void> markInterrupted() async {
    await (_db.update(_db.generationBatchRows)..where(
          (row) => row.status.isIn([
            GenerationStatus.queued.name,
            GenerationStatus.running.name,
            GenerationStatus.downloading.name,
          ]),
        ))
        .write(
          GenerationBatchRowsCompanion(
            status: const Value(GenerationStatus.interrupted),
            finishedAt: Value(DateTime.now()),
          ),
        );
  }

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

  Future<void> deleteTopic(String id) async {
    _requireWritable();
    await (_db.delete(
      _db.generationTopicRows,
    )..where((row) => row.id.equals(id))).go();
  }

  Future<void> deleteItem(String id) async {
    _requireWritable();
    await (_db.delete(
      _db.generationItemRows,
    )..where((row) => row.id.equals(id))).go();
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
          if (reference case {'path': final String path}) path,
    };
  });

  Future<void> clear() => _db.transaction(() async {
    _requireWritable();
    await _db.delete(_db.generationBatchRows).go();
    await _db.delete(_db.generationTopicRows).go();
  });

  Future<void> importFrom(
    MediaRepository? source, {
    required bool overwrite,
    Map<String, String> restoredPaths = const {},
  }) async {
    _requireWritable();
    if (source == null) {
      if (overwrite) {
        await clear();
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
    await _db.transaction(() async {
      if (overwrite) await clear();
      await _db.batch((batch) {
        batch.insertAll(
          _db.generationTopicRows,
          topics,
          mode: InsertMode.insertOrIgnore,
        );
        batch.insertAll(_db.generationBatchRows, [
          for (final row in batches)
            row.copyWith(
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
