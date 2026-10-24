import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/generation_run.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/message_part.dart';
import '../host/ui_source_map.dart';
import '../host/ui_source_selection.dart';
import '../protocol/ui_source_hash.dart';
import '../protocol/ui_stream_parser.dart';
import '../protocol/ui_validation.dart';
import '../runtime/ui_surface_state.dart';

enum UiTransferDatabase {
  main('main'),
  mergeSource('merge_source');

  const UiTransferDatabase(this.sql);
  final String sql;
}

typedef _Program = ({
  UiSourceFence fence,
  UiValidationResult program,
  String hash,
});
typedef _SavedState = ({
  UiSurfaceSnapshot snapshot,
  String searchText,
  DateTime updatedAt,
});

/// A frozen copy source. Only explicit copy/fork consumes temporary snapshots;
/// ordinary temporary edits never enter the database.
final class UiRevisionTransfer {
  UiRevisionTransfer._(this.message, this.run, this._programs, this._states);

  final ChatMessage message;
  final GenerationRunRow? run;
  final Map<String, _Program> _programs;
  final List<_SavedState> _states;

  static Map<String, _Program> _parsePrograms(ChatMessage message) {
    final result = <String, _Program>{};
    for (final fence in uiEligibleFences(message)) {
      if (!fence.node.closed) continue;
      final parsed = UiStreamParser().update(fence.body, closed: true);
      if (!parsed.invalid) {
        result[fence.surfaceKey] = (
          fence: fence,
          program: parsed.program,
          hash: uiSourceHash(parsed.source),
        );
      }
    }
    return result;
  }

  factory UiRevisionTransfer.temporary(
    ChatMessage message,
    Iterable<UiSurfaceSnapshot> snapshots,
  ) {
    message = message.copyWith();
    final programs = _parsePrograms(message);
    final states = <String, _SavedState>{};
    for (final snapshot in snapshots) {
      final source = programs[snapshot.owner.surfaceKey];
      if (snapshot.owner.revisionId != message.id ||
          source == null ||
          source.hash != snapshot.sourceHash) {
        continue;
      }
      states[snapshot.owner.surfaceKey] = (
        snapshot: UiSurfaceSnapshot(
          owner: snapshot.owner,
          sourceHash: source.hash,
          state: UiSurfaceState.decode(
            source.program,
            snapshot.state.json,
            stateVersion: snapshot.stateVersion,
          ),
        ),
        searchText: '',
        updatedAt: DateTime.now().toUtc(),
      );
    }
    return UiRevisionTransfer._(
      message,
      null,
      programs,
      states.values.toList(),
    );
  }

  GenerationRunState? get generation {
    final state = message.generationState;
    if (state == null) return null;
    return message.isStreaming || !state.isTerminal
        ? GenerationRunState.interrupted
        : state;
  }

  /// Keep ordinary message fingerprints unchanged. Cache-only/default rows do
  /// not create conflicts, but confirmed UI completion is part of its behavior.
  Object? get fingerprint {
    if (_programs.isEmpty) return null;
    final overrides = _states.where((s) => !s.snapshot.state.isDefault).toList()
      ..sort(
        (a, b) =>
            a.snapshot.owner.surfaceKey.compareTo(b.snapshot.owner.surfaceKey),
      );
    return [
      'genui',
      generation == GenerationRunState.completed,
      for (final saved in overrides)
        [
          saved.snapshot.owner.surfaceKey,
          saved.snapshot.sourceHash,
          saved.snapshot.stateVersion,
          saved.snapshot.state.json,
        ],
    ];
  }
}

/// Batch reads and writes belong to the caller's serialized transaction. SQL
/// source names are closed, and ownership always comes from actual message rows.
final class UiStateTransfer {
  const UiStateTransfer(this.db);
  final AppDatabase db;

  Future<Map<String, UiRevisionTransfer>> read({
    UiTransferDatabase source = UiTransferDatabase.main,
    String? conversationId,
    Iterable<String>? revisionIds,
  }) async {
    if ((conversationId == null) == (revisionIds == null)) {
      throw ArgumentError('Choose one source selector');
    }
    final result = <String, UiRevisionTransfer>{};
    if (conversationId != null) {
      result.addAll(
        await _read(source, 'm.conversation_id = ?', [conversationId]),
      );
    } else {
      final ids = revisionIds!.toSet().toList();
      for (var start = 0; start < ids.length; start += 400) {
        final batch = ids.skip(start).take(400).toList();
        result.addAll(
          await _read(
            source,
            'm.id IN (${List.filled(batch.length, '?').join(',')})',
            batch,
          ),
        );
      }
    }
    return result;
  }

  Future<Map<String, UiRevisionTransfer>> _read(
    UiTransferDatabase source,
    String where,
    List<String> values,
  ) async {
    final schema = source.sql;
    final variables = values.map(Variable<String>.new).toList();
    final messages = await db
        .customSelect(
          'SELECT m.* FROM $schema.message_rows m WHERE $where;',
          variables: variables,
        )
        .get();
    if (messages.isEmpty) return {};
    final parts = await db
        .customSelect(
          'SELECT p.revision_id, p.kind, p.payload FROM $schema.message_part_rows p '
          'JOIN $schema.message_rows m ON m.id = p.revision_id WHERE $where '
          'ORDER BY p.revision_id, p.ordinal;',
          variables: variables,
        )
        .get();
    final states = await db
        .customSelect(
          'SELECT s.* FROM $schema.gen_ui_surface_state_rows s '
          'JOIN $schema.message_rows m ON m.id = s.revision_id WHERE $where;',
          variables: variables,
        )
        .get();
    final runs = await db
        .customSelect(
          'SELECT r.* FROM $schema.generation_run_rows r '
          'JOIN $schema.message_rows m ON m.id = r.target_revision_id WHERE $where '
          'ORDER BY r.created_at DESC, r.updated_at DESC, r.id DESC;',
          variables: variables,
        )
        .get();
    final partsById = <String, List<MessagePart>>{};
    for (final part in parts) {
      final kind = part.read<String>('kind');
      final payload = part.read<String>('payload');
      partsById.putIfAbsent(part.read<String>('revision_id'), () => []).add(
        switch (kind) {
          'text' => TextPart(payload),
          'reasoning' => ReasoningPart(payload),
          _ => UnknownPart(rawKind: kind, payload: payload),
        },
      );
    }
    final latest = <String, GenerationRunRow>{};
    for (final raw in runs) {
      final run = db.generationRunRows.map(raw.data);
      latest.putIfAbsent(run.targetRevisionId, () => run);
    }
    final byId = <String, List<GenUiSurfaceStateRow>>{};
    for (final raw in states) {
      final state = db.genUiSurfaceStateRows.map(raw.data);
      byId.putIfAbsent(state.revisionId, () => []).add(state);
    }
    final result = <String, UiRevisionTransfer>{};
    for (final raw in messages) {
      final row = db.messageRows.map(raw.data);
      final messageParts = partsById[row.id] ?? const <MessagePart>[];
      final run = latest[row.id];
      final message =
          ChatMessage(
            id: row.id,
            conversationId: row.conversationId,
            role: row.role,
            timestamp: row.timestamp,
            isStreaming: row.isStreaming,
            parts: messageParts,
            reasoningSegmentsJson: row.reasoningSegmentsJson,
            reasoningText: messageParts
                .whereType<ReasoningPart>()
                .map((p) => p.text)
                .join('\n'),
          )..hydrateGenerationState(
            run == null ? null : GenerationRunState.fromDatabase(run.state),
          );
      final programs = UiRevisionTransfer._parsePrograms(message);
      final saved = <_SavedState>[];
      for (final state in byId[row.id] ?? const <GenUiSurfaceStateRow>[]) {
        final program = programs[state.surfaceKey];
        if (program == null || program.hash != state.sourceHash) continue;
        // Matching malformed private data is an error, never a default reset.
        saved.add((
          snapshot: UiSurfaceSnapshot(
            owner: UiSurfaceOwner(
              revisionId: row.id,
              surfaceKey: state.surfaceKey,
            ),
            sourceHash: state.sourceHash,
            state: UiSurfaceState.decode(
              program.program,
              state.stateJson,
              stateVersion: state.stateVersion,
            ),
          ),
          searchText: state.searchText,
          updatedAt: state.updatedAt,
        ));
      }
      result[row.id] = UiRevisionTransfer._(message, run, programs, saved);
    }
    return result;
  }

  Future<void> copy({
    required Map<String, UiRevisionTransfer> sources,
    required Map<String, String> messageIdMap,
    required String targetConversationId,
  }) async {
    final targets = await read(revisionIds: messageIdMap.values);
    for (final entry in messageIdMap.entries) {
      final source = sources[entry.key];
      if (source == null) continue; // Synthetic summary has no source owner.
      final target = targets[entry.value];
      if (target == null ||
          target.message.conversationId != targetConversationId) {
        throw StateError('genui_copy_target_missing');
      }
      if (source.message.role != 'assistant' ||
          target.message.role != 'assistant' ||
          source.message.content != target.message.content) {
        continue;
      }
      final generation = source.generation;
      if (generation != null) {
        if (target.run != null) throw StateError('genui_copy_target_not_new');
        final now = DateTime.now().toUtc();
        final oldRun = source.run;
        final createdAt = oldRun?.createdAt ?? source.message.timestamp;
        final terminalAt = [
          now,
          createdAt,
          if (oldRun != null) oldRun.updatedAt,
        ].reduce((a, b) => a.isAfter(b) ? a : b);
        await db
            .into(db.generationRunRows)
            .insert(
              GenerationRunRowsCompanion.insert(
                id: const Uuid().v4(),
                conversationId: targetConversationId,
                targetRevisionId: entry.value,
                state: generation.databaseValue,
                createdAt: createdAt,
                updatedAt: oldRun?.terminalAt == null
                    ? terminalAt
                    : oldRun!.updatedAt,
                terminalAt: Value(oldRun?.terminalAt ?? terminalAt),
                errorCode: Value(
                  generation == GenerationRunState.completed
                      ? null
                      : oldRun?.errorCode,
                ),
              ),
            );
      }
      for (final saved in source._states) {
        final original = source._programs[saved.snapshot.owner.surfaceKey]!;
        final from =
            original.fence.run.joinedStart + original.fence.node.span.start;
        final to =
            original.fence.run.joinedStart + original.fence.node.span.end;
        _Program? matching;
        for (final candidate in target._programs.values) {
          final fence = candidate.fence;
          if (fence.run.joinedStart + fence.node.span.start == from &&
              fence.run.joinedStart + fence.node.span.end == to &&
              fence.source == original.fence.source &&
              candidate.hash == original.hash) {
            matching = candidate;
            break;
          }
        }
        if (matching == null) continue;
        final normalized = UiSurfaceState.decode(
          matching.program,
          saved.snapshot.state.json,
          stateVersion: saved.snapshot.stateVersion,
        );
        await db
            .into(db.genUiSurfaceStateRows)
            .insert(
              GenUiSurfaceStateRowsCompanion.insert(
                revisionId: entry.value,
                surfaceKey: matching.fence.surfaceKey,
                sourceHash: matching.hash,
                stateJson: Value(normalized.json),
                searchText: Value(saved.searchText),
                updatedAt: saved.updatedAt,
              ),
            );
      }
    }
  }
}
