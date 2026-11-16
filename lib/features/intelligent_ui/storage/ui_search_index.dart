import 'dart:isolate';

import 'package:drift/drift.dart';
import 'package:drift/isolate.dart' show DriftRemoteException;
import 'package:sqlite3/common.dart' show SqliteException, SqlError;
import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/gen_ui_derived_schema.dart';
import 'package:Kelivo/core/database/generation_run.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import '../text/ui_search_text.dart';

enum _IndexReadiness { unchecked, needsRebuild, ready }

/// Derived text lives on the existing state row. Rebuilding touches only its
/// search_text, preserving inputs, view, state_version and updated_at verbatim.
final class UiSearchIndex {
  UiSearchIndex(
    this.db, {
    required this.readMessages,
    required this.transaction,
  });
  final AppDatabase db;
  final Future<List<ChatMessage>> Function(List<String>) readMessages;
  final Future<void> Function(Future<void> Function()) transaction;
  _IndexReadiness _state = _IndexReadiness.unchecked;
  Future<void>? _preparing;

  Future<void> ensure() => _state == _IndexReadiness.ready
      ? Future<void>.value()
      : _preparing ??= _prepare();

  Future<void> rebuild() {
    _state = _IndexReadiness.needsRebuild;
    return ensure();
  }

  Future<bool> _canReuse() async {
    final receipt =
        await (db.select(
              db.chatStorageMetaRows,
            )..where((r) => r.key.equals(GenUiDerivedSchema.searchBackfillKey)))
            .getSingleOrNull();
    return receipt?.value == '1' && await GenUiDerivedSchema.hasSearchIndex(db);
  }

  Future<void> _prepare() async {
    try {
      final reusable = _state == _IndexReadiness.unchecked && await _canReuse();
      // An explicit repair can also arrive while the receipt is being checked.
      if (!reusable || _state == _IndexReadiness.needsRebuild) {
        _state = _IndexReadiness.needsRebuild;
        await _rebuild();
      }
      _state = _IndexReadiness.ready;
    } finally {
      _preparing = null;
    }
  }

  static bool _isSqliteCorruption(Object error) {
    final cause = error is DriftRemoteException ? error.remoteCause : error;
    return cause is SqliteException &&
        cause.resultCode == SqlError.SQLITE_CORRUPT;
  }

  Future<T> retryOnFtsCorruption<T>(Future<T> Function() query) async {
    try {
      return await query();
    } catch (error) {
      if (!_isSqliteCorruption(error)) rethrow;
    }
    // MATCH also reads the ordinary message FTS. Only recreate the GenUI
    // index if its own integrity check fails, using the durable state rows.
    await transaction(() async {
      const fts = GenUiDerivedSchema.searchTable;
      try {
        await db.customStatement(
          "INSERT INTO $fts($fts) VALUES('integrity-check')",
        );
      } catch (error) {
        if (!_isSqliteCorruption(error)) rethrow;
        await GenUiDerivedSchema.resetSearch(db);
      }
    });
    // A concurrent query may have repaired the index before our check.
    return query();
  }

  static const _candidate = """
    (INSTR((SELECT GROUP_CONCAT(payload, '') FROM (
      SELECT payload FROM message_part_rows p WHERE p.revision_id=m.id
      AND p.kind='text' ORDER BY p.ordinal)), 'kelivo-ui') > 0
    OR EXISTS (SELECT 1 FROM gen_ui_surface_state_rows s WHERE s.revision_id=m.id))
  """;

  Future<void> sealRevisions(Iterable<String> revisionIds) async {
    final ids = revisionIds.toSet().toList();
    for (var start = 0; start < ids.length; start += 32) {
      final batch = ids.skip(start).take(32).toList();
      final rows = await db
          .customSelect(
            "SELECT m.id FROM message_rows m WHERE m.role='assistant' AND m.id IN (${List.filled(batch.length, '?').join(',')}) AND $_candidate",
            variables: batch.map(Variable<String>.new).toList(),
          )
          .get();
      for (final message in await readMessages(
        rows.map((r) => r.read<String>('id')).toList(),
      )) {
        await seal(message);
      }
    }
  }

  Future<void> _rebuild() async {
    // Commit invalidation first so rolling back a failed FTS reset cannot
    // restore the old receipt on the next launch.
    await transaction(() async {
      await (db.delete(
        db.chatStorageMetaRows,
      )..where((r) => r.key.equals(GenUiDerivedSchema.searchBackfillKey))).go();
    });
    await transaction(() => GenUiDerivedSchema.resetSearch(db));
    String? after;
    while (true) {
      final rows = await db
          .customSelect(
            '''
        SELECT m.id FROM message_rows m
        WHERE m.role = 'assistant' AND m.id > ? AND $_candidate ORDER BY m.id LIMIT 32
      ''',
            variables: [Variable<String>(after ?? '')],
          )
          .get();
      if (rows.isEmpty) break;
      final ids = rows.map((r) => r.read<String>('id')).toList();
      await transaction(() async {
        // Read inside the same coordinated write, never resurrect a deleted
        // revision or overwrite a concurrent source edit with an earlier read.
        final messages = await readMessages(ids);
        final projections = await _projectBatch(messages);
        final stored = await (db.select(
          db.genUiSurfaceStateRows,
        )..where((r) => r.revisionId.isIn(ids))).get();
        final byRevision = <String, List<GenUiSurfaceStateRow>>{};
        for (final row in stored) {
          (byRevision[row.revisionId] ??= []).add(row);
        }
        for (final message in messages) {
          await _store(
            message,
            projections[message.id]!,
            byRevision[message.id] ?? const [],
          );
        }
      });
      after = ids.last;
      // Bound both hydration and each transaction; let pending input saves run.
      await Future<void>.delayed(Duration.zero);
    }
    // Source edits and generation completion maintain the projection from here.
    // A failed or interrupted backfill leaves the database eligible for retry.
    await db
        .into(db.chatStorageMetaRows)
        .insertOnConflictUpdate(
          ChatStorageMetaRowsCompanion.insert(
            key: GenUiDerivedSchema.searchBackfillKey,
            value: '1',
          ),
        );
  }

  static Map<String, UiSearchSurfaceText> _projection(ChatMessage message) =>
      !message.isStreaming &&
          message.generationState == GenerationRunState.completed
      ? initialUiSearchText(message)
      : const {};

  static Future<Map<String, Map<String, UiSearchSurfaceText>>> _projectBatch(
    List<ChatMessage> messages,
  ) => Isolate.run(
    () => {for (final message in messages) message.id: _projection(message)},
  );

  /// Caller holds the repository's coordinated transaction and supplies actual
  /// persisted source plus generation evidence, not a widget's stale message.
  Future<void> seal(ChatMessage message) async {
    final table = db.genUiSurfaceStateRows;
    final rows = await (db.select(
      table,
    )..where((s) => s.revisionId.equals(message.id))).get();
    await _store(message, _projection(message), rows);
  }

  Future<void> _store(
    ChatMessage message,
    Map<String, UiSearchSurfaceText> text,
    List<GenUiSurfaceStateRow> rows,
  ) async {
    final table = db.genUiSurfaceStateRows;
    for (final row in rows) {
      final next = text[row.surfaceKey];
      // A source edit invalidates the entire row; ordinary rebuilds do not.
      if (next != null && next.sourceHash != row.sourceHash) {
        await (db.delete(table)..where(
              (s) =>
                  s.revisionId.equals(message.id) &
                  s.surfaceKey.equals(row.surfaceKey),
            ))
            .go();
      } else if (row.searchText != (next?.text ?? '')) {
        await (db.update(table)..where(
              (s) =>
                  s.revisionId.equals(message.id) &
                  s.surfaceKey.equals(row.surfaceKey),
            ))
            .write(
              GenUiSurfaceStateRowsCompanion(
                searchText: Value(next?.text ?? ''),
              ),
            );
      }
    }
    for (final entry in text.entries) {
      if (rows.any(
        (r) =>
            r.surfaceKey == entry.key && r.sourceHash == entry.value.sourceHash,
      )) {
        continue;
      }
      await db
          .into(table)
          .insert(
            GenUiSurfaceStateRowsCompanion.insert(
              revisionId: message.id,
              surfaceKey: entry.key,
              sourceHash: entry.value.sourceHash,
              searchText: Value(entry.value.text),
              updatedAt: message.timestamp.toUtc(),
            ),
          );
    }
  }

  Future<Map<String, Map<String, UiSearchSurfaceText>>> read(
    Iterable<String> revisionIds,
  ) async {
    final ids = revisionIds.toSet().toList();
    final result = <String, Map<String, UiSearchSurfaceText>>{};
    for (var start = 0; start < ids.length; start += 400) {
      final rows = await (db.select(
        db.genUiSurfaceStateRows,
      )..where((s) => s.revisionId.isIn(ids.skip(start).take(400)))).get();
      for (final row in rows) {
        if (row.searchText.isEmpty) continue;
        result.putIfAbsent(
          row.revisionId,
          () => {},
        )[row.surfaceKey] = UiSearchSurfaceText(
          sourceHash: row.sourceHash,
          text: row.searchText,
        );
      }
    }
    return result;
  }
}
