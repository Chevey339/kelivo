enum GenerationRunState {
  preparing('preparing'),
  requesting('requesting'),
  streaming('streaming'),
  waitingTool('waiting_tool'),
  completed('completed'),
  failed('failed'),
  cancelled('cancelled'),
  interrupted('interrupted');

  const GenerationRunState(this.databaseValue);

  final String databaseValue;

  bool get isTerminal => switch (this) {
    completed || failed || cancelled || interrupted => true,
    preparing || requesting || streaming || waitingTool => false,
  };

  static GenerationRunState fromDatabase(String value) {
    for (final state in values) {
      if (state.databaseValue == value) return state;
    }
    throw StateError('generation_run_state_unknown');
  }
}

final class GenerationRun {
  const GenerationRun({
    required this.id,
    required this.conversationId,
    required this.targetRevisionId,
    required this.state,
    required this.stateRevision,
    required this.checkpointSeq,
    required this.errorCode,
    required this.createdAt,
    required this.updatedAt,
    required this.terminalAt,
  });

  final String id;
  final String conversationId;
  final String targetRevisionId;
  final GenerationRunState state;
  final int stateRevision;
  final int checkpointSeq;
  final String? errorCode;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? terminalAt;
}

final class GenerationRunTransitionConflict extends StateError {
  GenerationRunTransitionConflict()
    : super('generation_run_transition_conflict');
}
