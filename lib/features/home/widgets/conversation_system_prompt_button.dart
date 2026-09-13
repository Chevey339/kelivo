import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/conversation_prompt_settings.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../theme/chat_bubble_style.dart';
import '../../chat/utils/ensure_conversation.dart';
import '../../chat/widgets/frosted/frosted_surface.dart';
import 'conversation_system_prompt_editor.dart';

/// A quiet action at the end of the scrollable conversation.
class ConversationSystemPromptButton extends StatelessWidget {
  const ConversationSystemPromptButton({
    super.key,
    this.conversationId,
    required this.assistantId,
    this.backgroundImageActive = false,
  });
  final String? conversationId;
  final String assistantId;
  final bool backgroundImageActive;

  @override
  Widget build(BuildContext context) {
    final customized = context.select<ChatService, bool>(
      (chat) => ConversationPromptSettings.fromExtras(
        chat.getConversation(conversationId ?? '')?.extras ?? const {},
      ).systemPrompt.trim().isNotEmpty,
    );
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final color = customized ? cs.primary : cs.onSurfaceVariant;
    const borderRadius = BorderRadius.all(Radius.circular(10));
    Widget button = IosCardPress(
      key: const ValueKey('conversation-system-prompt-button'),
      baseColor: Colors.transparent,
      borderRadius: borderRadius,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      onTap: () async {
        final id = await ensureConversationId(
          context,
          conversationId: conversationId,
          assistantId: assistantId,
        );
        if (id == null || !context.mounted) return;
        await editConversationSystemPrompt(context, conversationId: id);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Lucide.FileText, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              l10n.conversationSystemPromptTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: color),
            ),
          ),
          if (customized) ...[
            const SizedBox(width: 5),
            Icon(Lucide.Check, size: 13, color: color),
          ],
        ],
      ),
    );
    if (backgroundImageActive) {
      button = FrostedSurface(
        style: ResolvedBubbleStyle(
          background: cs.surface.withValues(alpha: 0.10),
          border: Colors.transparent,
          text: color,
          borderWidth: 0,
          radius: 10,
          blurSigma: 3,
        ),
        borderRadius: borderRadius,
        child: button,
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: button,
      ),
    );
  }
}
