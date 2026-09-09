/// Conversation extras view for per-chat skill overrides.
///
/// [skillIds] is `null` when the conversation inherits [Assistant.skillIds]
/// (or every enabled skill when the assistant also leaves the list unset).
class SkillsBinding {
  static const String keyIds = 'skills.ids';

  final List<String>? skillIds;

  const SkillsBinding({this.skillIds});

  factory SkillsBinding.fromExtras(Map<String, dynamic> extras) {
    if (!extras.containsKey(keyIds)) {
      return const SkillsBinding();
    }
    final raw = extras[keyIds];
    if (raw == null) return const SkillsBinding();
    if (raw is List) {
      return SkillsBinding(skillIds: [for (final item in raw) item.toString()]);
    }
    return const SkillsBinding();
  }

  /// Writes or removes [keyIds]. A `null` [skillIds] inherits the assistant.
  Map<String, dynamic> applyTo(Map<String, dynamic> extras) {
    final next = Map<String, dynamic>.from(extras);
    if (skillIds == null) {
      next.remove(keyIds);
      return next;
    }
    next[keyIds] = List<String>.from(skillIds!);
    return next;
  }
}
