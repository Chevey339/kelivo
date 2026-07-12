import 'package:drift/drift.dart';

import 'app_database.dart';
import 'generation_run.dart';

final class GenerationRunCommands {
  const GenerationRunCommands(this._db);

  final AppDatabase _db;

  Future<GenerationRun> create({
    required String id,
    required String conversationId,
    required String targetRevisionId,
    required DateTime createdAt,
  }) {
    return _db.transaction(() async {
      await _db
          .into(_db.generationRunRows)
          .insert(
            GenerationRunRowsCompanion.insert(
              id: id,
              conversationId: conversationId,
              targetRevisionId: targetRevisionId,
              state: GenerationRunState.preparing.databaseValue,
              createdAt: createdAt,
              updatedAt: createdAt,
            ),
          );
      return _readRequired(id);
    });
  }

  Future<GenerationRun?> get(String id) async {
    final row = await (_db.select(
      _db.generationRunRows,
    )..where((run) => run.id.equals(id))).getSingleOrNull();
    return row == null ? null : _map(row);
  }

  Future<GenerationRun> transition({
    required String id,
    required GenerationRunState expectedState,
    required int expectedStateRevision,
    required GenerationRunState nextState,
    required DateTime updatedAt,
    String? errorCode,
  }) {
    if (!_allowedTransitions[expectedState]!.contains(nextState)) {
      throw ArgumentError.value(
        nextState,
        'nextState',
        'invalid transition from ${expectedState.databaseValue}',
      );
    }
    if (errorCode != null &&
        nextState != GenerationRunState.failed &&
        nextState != GenerationRunState.cancelled &&
        nextState != GenerationRunState.interrupted) {
      throw ArgumentError.value(errorCode, 'errorCode');
    }

    return _db.transaction(() async {
      final updated =
          await (_db.update(_db.generationRunRows)..where(
                (run) =>
                    run.id.equals(id) &
                    run.state.equals(expectedState.databaseValue) &
                    run.stateRevision.equals(expectedStateRevision),
              ))
              .write(
                GenerationRunRowsCompanion(
                  state: Value(nextState.databaseValue),
                  stateRevision: Value(expectedStateRevision + 1),
                  errorCode: Value(errorCode),
                  updatedAt: Value(updatedAt),
                  terminalAt: Value(nextState.isTerminal ? updatedAt : null),
                ),
              );
      if (updated != 1) throw GenerationRunTransitionConflict();
      return _readRequired(id);
    });
  }

  Future<GenerationRun> _readRequired(String id) async {
    final row = await (_db.select(
      _db.generationRunRows,
    )..where((run) => run.id.equals(id))).getSingleOrNull();
    if (row == null) throw StateError('generation_run_missing');
    return _map(row);
  }

  static GenerationRun _map(GenerationRunRow row) => GenerationRun(
    id: row.id,
    conversationId: row.conversationId,
    targetRevisionId: row.targetRevisionId,
    state: GenerationRunState.fromDatabase(row.state),
    stateRevision: row.stateRevision,
    checkpointSeq: row.checkpointSeq,
    errorCode: row.errorCode,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    terminalAt: row.terminalAt,
  );

  static const Map<GenerationRunState, Set<GenerationRunState>>
  _allowedTransitions = {
    GenerationRunState.preparing: {
      GenerationRunState.requesting,
      GenerationRunState.failed,
      GenerationRunState.cancelled,
      GenerationRunState.interrupted,
    },
    GenerationRunState.requesting: {
      GenerationRunState.streaming,
      GenerationRunState.failed,
      GenerationRunState.cancelled,
      GenerationRunState.interrupted,
    },
    GenerationRunState.streaming: {
      GenerationRunState.waitingTool,
      GenerationRunState.completed,
      GenerationRunState.failed,
      GenerationRunState.cancelled,
      GenerationRunState.interrupted,
    },
    GenerationRunState.waitingTool: {
      GenerationRunState.streaming,
      GenerationRunState.failed,
      GenerationRunState.cancelled,
      GenerationRunState.interrupted,
    },
    GenerationRunState.completed: {},
    GenerationRunState.failed: {},
    GenerationRunState.cancelled: {},
    GenerationRunState.interrupted: {},
  };
}
