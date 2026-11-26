import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../core/services/chat/chat_service.dart';
import '../../../l10n/app_localizations.dart';

class ConversationTitleBuilder extends StatelessWidget {
  const ConversationTitleBuilder({
    super.key,
    required this.conversationId,
    required this.isTemporary,
    required this.builder,
  });

  final String? conversationId;
  final bool isTemporary;
  final Widget Function(BuildContext context, String title) builder;

  @override
  Widget build(BuildContext context) {
    // Selecting null replaces the previous chat's title subscription.
    final id = isTemporary ? null : conversationId;
    final title = context.select<ChatService, String?>(
      (chat) => id == null ? null : chat.getConversation(id)?.title,
    );
    final l10n = AppLocalizations.of(context)!;
    if (isTemporary) return builder(context, l10n.temporaryChatTitle);
    return builder(
      context,
      title == null || title.trim().isEmpty ? l10n.titleForLocale : title,
    );
  }
}
