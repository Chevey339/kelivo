import '../../../core/models/chat_message.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/api/chat_api_service.dart';

class ChatSuggestionService {
  static const int maxSuggestionCount = 3;
  static const int maxSuggestionChars = 300;

  const ChatSuggestionService();

  static List<String> parseSuggestions(
    String raw, {
    int maxCount = maxSuggestionCount,
    int maxChars = maxSuggestionChars,
  }) {
    final seen = <String>{};
    final suggestions = <String>[];
    final lines = raw
        .split(RegExp(r'[\r\n]+'))
        .expand((line) => line.split(RegExp(r'(?<=[。！？!?])\s+')));

    for (final line in lines) {
      var text = line.trim();
      if (text.isEmpty) continue;
      text = text
          .replaceFirst(RegExp(r'^\s*[-*•]\s*'), '')
          .replaceFirst(RegExp(r'^\s*\d+[.)、]\s*'), '')
          .trim();
      if ((text.startsWith('"') && text.endsWith('"')) ||
          (text.startsWith("'") && text.endsWith("'")) ||
          (text.startsWith('“') && text.endsWith('”'))) {
        text = text.substring(1, text.length - 1).trim();
      }
      if (text.isEmpty || text.length > maxChars) continue;
      if (!seen.add(text)) continue;
      suggestions.add(text);
      if (suggestions.length >= maxCount) break;
    }
    return suggestions;
  }

  static String buildContent(
    List<ChatMessage> messages, {
    int truncateIndex = -1,
    int maxMessages = 8,
    int maxChars = 4000,
  }) {
    final effectiveMessages =
        truncateIndex >= 0 && truncateIndex < messages.length
        ? messages.skip(truncateIndex).toList()
        : messages;
    final recent = effectiveMessages
        .where(
          (m) =>
              (m.role == 'user' || m.role == 'assistant') &&
              m.content.trim().isNotEmpty,
        )
        .toList();
    final selected = recent.length > maxMessages
        ? recent.sublist(recent.length - maxMessages)
        : recent;
    final joined = selected
        .map((m) {
          final role = m.role == 'user' ? 'User' : 'Assistant';
          return '$role: ${m.content.trim()}';
        })
        .join('\n\n');
    if (joined.length <= maxChars) return joined;
    return joined.substring(joined.length - maxChars);
  }

  Future<List<String>> generate({
    required SettingsProvider settings,
    required String providerKey,
    required String modelId,
    required List<ChatMessage> messages,
    required int truncateIndex,
    required String locale,
    int? thinkingBudget,
  }) async {
    final content = buildContent(messages, truncateIndex: truncateIndex);
    if (content.trim().isEmpty) return const <String>[];
    final prompt = settings.suggestionPrompt
        .replaceAll('{content}', content)
        .replaceAll('{locale}', locale);
    final raw = await ChatApiService.generateText(
      config: settings.getProviderConfig(providerKey),
      modelId: modelId,
      prompt: prompt,
      thinkingBudget: thinkingBudget,
    );
    return parseSuggestions(raw);
  }
}
