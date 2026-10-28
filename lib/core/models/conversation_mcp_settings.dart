import 'assistant.dart';
import 'conversation.dart';

/// An explicit override distinguishes disabling every server from inheriting.
abstract final class ConversationMcpSettings {
  static const overrideKey = 'mcp.override';

  static bool isOverridden(Conversation? conversation) =>
      conversation?.extras[overrideKey] == true;

  /// [assistant] is the resolved assistant, including unbound/recovered chats.
  static List<String> effectiveServerIds(
    Assistant? assistant,
    Conversation? conversation,
  ) {
    if (assistant?.allowConversationMcp == true &&
        conversation != null &&
        isOverridden(conversation)) {
      return conversation.mcpServerIds;
    }
    return assistant?.mcpServerIds ?? const [];
  }

  static Map<String, dynamic> updateExtras(
    Map<String, dynamic> extras, {
    required bool override,
  }) {
    final next = Map<String, dynamic>.from(extras)..remove(overrideKey);
    if (override) next[overrideKey] = true;
    return next;
  }
}
