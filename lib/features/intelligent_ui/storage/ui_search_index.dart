import 'package:drift/drift.dart';
import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/gen_ui_derived_schema.dart';
import 'package:Kelivo/core/database/generation_run.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import '../text/ui_search_text.dart';

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
  Future<void>? _ready;
  Future<void> ensure() =>
      _ready ??= rebuild().catchError((Object error, StackTrace stack) {
        _ready = null;
        Error.throwWithStackTrace(error, stack);
      });

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

  Future<void> rebuild() async {
    // Recreate disposable FTS before any UPDATE trigger can touch a corrupt or
    // absent index. All DDL remains the v5 definition, on GenUI's own table.
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
      if (rows.isEmpty) return;
      final ids = rows.map((r) => r.read<String>('id')).toList();
      await transaction(() async {
        // Read inside the same coordinated write, never resurrect a deleted
        // revision or overwrite a concurrent source edit with an earlier read.
        for (final message in await readMessages(ids)) {
          await seal(message);
        }
      });
      after = ids.last;
      // Bound both hydration and each transaction; let pending input saves run.
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// Caller holds the repository's coordinated transaction and supplies actual
  /// persisted source plus generation evidence, not a widget's stale message.
  Future<void> seal(ChatMessage message) async {
    final complete =
        !message.isStreaming &&
        message.generationState == GenerationRunState.completed;
    final text = complete
        ? initialUiSearchText(message)
        : const <String, UiSearchSurfaceText>{};
    final table = db.genUiSurfaceStateRows;
    final rows = await (db.select(
      table,
    )..where((s) => s.revisionId.equals(message.id))).get();
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
