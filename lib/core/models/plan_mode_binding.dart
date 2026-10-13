/// Conversation extras view for per-chat Plan Mode (计划模式).
///
/// In Plan Mode:
/// - Tools are restricted to read-only inspection (no write/edit or modifying commands).
/// - System prompt guides the model to explore first and produce a <proposed_plan>.
/// - A plan can be approved to resume execution in the current chat,
///   or implemented in a fresh conversation (Clear Context & Implement).
class PlanModeBinding {
  static const String keyEnabled = 'plan_mode.enabled';
  static const String keyCurrentPlan = 'plan_mode.current_plan';

  final bool isPlanMode;
  final String? currentPlanMarkdown;

  const PlanModeBinding({
    this.isPlanMode = false,
    this.currentPlanMarkdown,
  });

  factory PlanModeBinding.fromExtras(Map<String, dynamic> extras) {
    final enabled = extras[keyEnabled] as bool? ?? false;
    final plan = extras[keyCurrentPlan] as String?;
    return PlanModeBinding(
      isPlanMode: enabled,
      currentPlanMarkdown: plan,
    );
  }

  /// Writes or removes Plan Mode state in [extras].
  Map<String, dynamic> applyTo(Map<String, dynamic> extras) {
    final next = Map<String, dynamic>.from(extras);
    if (!isPlanMode) {
      next.remove(keyEnabled);
      // We optionally retain currentPlanMarkdown as reference or remove if desired.
      // Retaining it allows users to inspect the last approved plan.
    } else {
      next[keyEnabled] = true;
    }
    if (currentPlanMarkdown != null && currentPlanMarkdown!.trim().isNotEmpty) {
      next[keyCurrentPlan] = currentPlanMarkdown;
    } else {
      next.remove(keyCurrentPlan);
    }
    return next;
  }

  PlanModeBinding copyWith({
    bool? isPlanMode,
    String? currentPlanMarkdown,
    bool clearPlan = false,
  }) {
    return PlanModeBinding(
      isPlanMode: isPlanMode ?? this.isPlanMode,
      currentPlanMarkdown:
          clearPlan ? null : (currentPlanMarkdown ?? this.currentPlanMarkdown),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlanModeBinding &&
          runtimeType == other.runtimeType &&
          isPlanMode == other.isPlanMode &&
          currentPlanMarkdown == other.currentPlanMarkdown;

  @override
  int get hashCode => Object.hash(isPlanMode, currentPlanMarkdown);
}
