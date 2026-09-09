import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';

/// Returns [conversationId] when it already names a chat, otherwise creates a
/// draft conversation so per-conversation state (workspace binding, session
/// skills) has somewhere to live before the first message is sent.
///
/// Returns null when the draft cannot be created.
Future<String?> ensureConversationId(
  BuildContext context, {
  String? conversationId,
  String? assistantId,
}) async {
  if (conversationId != null && conversationId.isNotEmpty) {
    return conversationId;
  }
  final chat = context.read<ChatService>();
  var resolvedAssistantId = assistantId;
  if (resolvedAssistantId == null) {
    try {
      resolvedAssistantId = context
          .read<AssistantProvider>()
          .currentAssistantId;
    } catch (_) {}
  }
  try {
    final draft = await chat.createDraftConversation(
      assistantId: resolvedAssistantId,
    );
    return draft.id;
  } catch (_) {
    return null;
  }
}
