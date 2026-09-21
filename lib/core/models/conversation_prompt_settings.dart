import 'assistant.dart';

/// Prompt overrides owned by a conversation, persisted in its Drift extras.
class ConversationPromptSettings {
  static const systemPromptKey = 'prompt.system';
  static const instructionIdsKey = 'prompt.instructionIds';
  static const worldBookIdsKey = 'prompt.worldBookIds';

  final String systemPrompt;
  final List<String> instructionIds;
  final List<String> worldBookIds;

  const ConversationPromptSettings({
    this.systemPrompt = '',
    this.instructionIds = const [],
    this.worldBookIds = const [],
  });

  factory ConversationPromptSettings.fromExtras(Map<String, dynamic> extras) {
    List<String> ids(String key) {
      final raw = extras[key];
      return raw is List ? raw.whereType<String>().toSet().toList() : const [];
    }

    return ConversationPromptSettings(
      systemPrompt: extras[systemPromptKey] is String
          ? extras[systemPromptKey] as String
          : '',
      instructionIds: ids(instructionIdsKey),
      worldBookIds: ids(worldBookIdsKey),
    );
  }

  String effectiveSystemPrompt(Assistant? assistant) =>
      assistant?.allowConversationSystemPrompt == true &&
          systemPrompt.trim().isNotEmpty
      ? systemPrompt
      : assistant?.systemPrompt ?? '';

  Map<String, dynamic> applyTo(Map<String, dynamic> extras) {
    final next = Map<String, dynamic>.from(extras);
    for (final key in [systemPromptKey, instructionIdsKey, worldBookIdsKey]) {
      next.remove(key);
    }
    if (systemPrompt.isNotEmpty) next[systemPromptKey] = systemPrompt;
    if (instructionIds.isNotEmpty) {
      next[instructionIdsKey] = List<String>.from(instructionIds);
    }
    if (worldBookIds.isNotEmpty) {
      next[worldBookIdsKey] = List<String>.from(worldBookIds);
    }
    return next;
  }
}
