import 'package:flutter/material.dart';

import '../../../core/models/conversation.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/form_sheet.dart';
import '../../../shared/widgets/ios_form_text_field.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../theme/app_font_weights.dart';

/// Null means cancel; an empty id means a new conversation.
Future<String?> showShareDestinationSheet(
  BuildContext context, {
  required List<Conversation> conversations,
}) => showFormSheet<String>(
  context,
  builder: (_) => ShareDestinationSheet(conversations: conversations),
);

class ShareDestinationSheet extends StatefulWidget {
  const ShareDestinationSheet({super.key, required this.conversations});
  final List<Conversation> conversations;
  @override
  State<ShareDestinationSheet> createState() => _ShareDestinationSheetState();
}

class _ShareDestinationSheetState extends State<ShareDestinationSheet> {
  final _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final query = _search.text.trim().toLowerCase();
    final items = widget.conversations
        .where((c) => c.title.toLowerCase().contains(query))
        .toList();
    Widget row(String id, String title, IconData icon, {String? subtitle}) =>
        IosCardPress(
          borderRadius: BorderRadius.circular(12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          onTap: () => Navigator.pop(context, id),
          child: Row(
            children: [
              Icon(icon, size: 20, color: cs.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: AppFontWeights.medium,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Lucide.ChevronRight, size: 16, color: cs.onSurfaceVariant),
            ],
          ),
        );
    return FormSheet(
      title: l10n.incomingShareMoveTo,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            l10n.incomingShareMoveHint,
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 12),
        IosFormTextField(
          label: '',
          hintText: l10n.chatHistoryPageSearchHint,
          controller: _search,
          inlineLabel: false,
          outerPadding: EdgeInsets.zero,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        SectionCard(
          children: [row('', l10n.incomingShareNewChat, Lucide.Plus)],
        ),
        const SizedBox(height: 10),
        if (items.isNotEmpty)
          SizedBox(
            height: (items.length * 64.0).clamp(
              64.0,
              MediaQuery.sizeOf(context).height * 0.42,
            ),
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return row(
                  item.id,
                  item.title,
                  Lucide.MessageCircle,
                  subtitle: MaterialLocalizations.of(
                    context,
                  ).formatMediumDate(item.updatedAt),
                );
              },
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                l10n.incomingShareNoConversations,
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ),
          ),
      ],
    );
  }
}
