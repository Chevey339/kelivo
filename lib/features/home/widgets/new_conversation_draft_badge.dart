import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/assistant_provider.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../l10n/app_localizations.dart';

/// The new-chat entry has a draft even before it appears in chat history.
class NewConversationDraftBadge extends StatelessWidget {
  const NewConversationDraftBadge({
    super.key,
    required this.child,
    this.enabled = true,
  });
  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final assistantId = context.select<AssistantProvider, String?>(
      (value) => value.currentAssistantId,
    );
    final hasDraft = context.select<ChatService, bool>((chat) {
      final store = chat.composerDrafts;
      final entry = store?.newEntry(assistantId);
      return entry != null && store!.hasDraft(entry.id);
    });
    if (!enabled || !hasDraft) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                AppLocalizations.of(context)!.composerDraftLabel,
                style: TextStyle(
                  fontSize: 9,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
