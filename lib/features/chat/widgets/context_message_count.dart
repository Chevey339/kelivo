import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/assistant.dart';
import '../../../core/models/context_operation.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/app_font_weights.dart';

/// Counts the effective history using the same projection as model requests.
/// Summaries are separate from the assistant's ordinary-message limit.
class ContextMessageCount extends StatefulWidget {
  const ContextMessageCount({super.key, this.conversationId});

  final String? conversationId;

  @override
  State<ContextMessageCount> createState() => _ContextMessageCountState();
}

class _ContextMessageCountState extends State<ContextMessageCount> {
  (ChatService, String?, int, int?)? _request;
  Future<({int actual, int? configured})>? _count;

  Future<({int actual, int? configured})> _load(
    ChatService chat,
    String? id,
    int? limit,
  ) async {
    if (id == null) return (actual: 0, configured: limit);
    final counts = await chat.loadContextMessageCounts(
      id,
      limit: limit ?? 0x7fffffff,
    );
    final fixedStart = ContextHistory.fixedStart(
      await chat.loadContextOperations(id),
    );
    return (
      actual: counts.messages,
      configured: fixedStart == null ? limit : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.conversationId;
    final (chat, revision, assistantId) = context
        .select<ChatService, (ChatService, int, String?)>(
          (chat) => (
            chat,
            id == null ? 0 : chat.contextRevision(id),
            id == null ? null : chat.getConversation(id)?.assistantId,
          ),
        );
    final limit = context.select<AssistantProvider, int?>((assistants) {
      final assistant = assistants.resolveConversationAssistant(assistantId);
      return assistant?.limitContextMessages == true &&
              assistant!.contextMessageSize > 0
          ? assistant.contextMessageSize.clamp(
              Assistant.minContextMessageSize,
              Assistant.maxContextMessageSize,
            )
          : null;
    });
    final request = (chat, id, revision, limit);
    if (_request != request) {
      _request = request;
      _count = _load(chat, id, limit);
    }
    return FutureBuilder<({int actual, int? configured})>(
      future: _count,
      builder: (context, snapshot) {
        // Never present a previous conversation/revision's count as current.
        if (snapshot.connectionState != ConnectionState.done ||
            !snapshot.hasData) {
          return const SizedBox.shrink();
        }
        final count = snapshot.data!;
        final l10n = AppLocalizations.of(context)!;
        return Text(
          count.configured == null
              ? l10n.contextMessageCount(count.actual)
              : l10n.contextMessageCountLimited(
                  count.actual,
                  count.configured!,
                ),
          style: TextStyle(
            fontSize: 13,
            fontWeight: AppFontWeights.medium,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: .55),
          ),
        );
      },
    );
  }
}
