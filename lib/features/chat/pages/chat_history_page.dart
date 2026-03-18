import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:animations/animations.dart';
import '../../../shared/animations/widgets.dart';
import '../../../shared/widgets/snackbar.dart';
import 'package:provider/provider.dart';

import '../../../icons/lucide_adapter.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../core/models/conversation.dart';
import '../../../l10n/app_localizations.dart';

class ChatHistoryPage extends StatefulWidget {
  const ChatHistoryPage({super.key, this.assistantId});
  final String? assistantId;

  @override
  State<ChatHistoryPage> createState() => _ChatHistoryPageState();
}

class _ChatHistoryPageState extends State<ChatHistoryPage>
    with TickerProviderStateMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chatService = context.watch<ChatService>();
    final List<Conversation> all = chatService
        .getAllConversations()
        .where(
          (c) =>
              widget.assistantId == null ||
              c.assistantId == widget.assistantId ||
              c.assistantId == null,
        )
        .toList();

    final q = _searchCtrl.text.trim().toLowerCase();
    final filtered = q.isEmpty
        ? all
        : all.where((c) => c.title.toLowerCase().contains(q)).toList();
    final pinned = filtered.where((c) => c.isPinned).toList();
    final others = filtered.where((c) => !c.isPinned).toList();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Lucide.ArrowLeft),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(l10n.chatHistoryPageTitle),
        actions: [
          IconButton(
            tooltip: l10n.chatHistoryPageSearchTooltip,
            icon: AnimatedIconSwap(
              child: Icon(
                _searching ? Lucide.X : Lucide.Search,
                key: ValueKey(_searching ? 'x' : 'search'),
              ),
            ),
            onPressed: () {
              setState(() {
                if (_searching) _searchCtrl.clear();
                _searching = !_searching;
              });
            },
          ),
          IconButton(
            tooltip: l10n.chatHistoryPageDeleteAllTooltip,
            icon: const Icon(Lucide.Trash2),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(l10n.chatHistoryPageDeleteAllDialogTitle),
                  content: Text(l10n.chatHistoryPageDeleteAllDialogContent),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: Text(l10n.chatHistoryPageCancel),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: Text(
                        l10n.chatHistoryPageDelete,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
              if (!context.mounted) return;
              if (confirm == true) {
                final svc = context.read<ChatService>();
                final idsToDelete = svc
                    .getAllConversations()
                    .where(
                      (c) => c.assistantId == widget.assistantId && !c.isPinned,
                    )
                    .map((c) => c.id)
                    .toList();
                for (final id in idsToDelete) {
                  await svc.deleteConversation(id);
                }
                if (!context.mounted) return;
                showAppSnackBar(
                  context,
                  message: l10n.chatHistoryPageDeletedAllSnackbar,
                  type: NotificationType.success,
                );
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSize(
              duration: kAnim,
              alignment: Alignment.topCenter,
              curve: Curves.easeOutCubic,
              child: PageTransitionSwitcher(
                duration: kAnim,
                reverse: !_searching,
                transitionBuilder: (child, anim, sec) => SharedAxisTransition(
                  animation: anim,
                  secondaryAnimation: sec,
                  transitionType: SharedAxisTransitionType.vertical,
                  child: child,
                ),
                child: !_searching
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TextField(
                          controller: _searchCtrl,
                          autofocus: true,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: l10n.chatHistoryPageSearchHint,
                            filled: true,
                            fillColor: isDark
                                ? Colors.white10
                                : const Color(0xFFF2F3F5),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(50),
                              borderSide: const BorderSide(
                                color: Colors.transparent,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(50),
                              borderSide: const BorderSide(
                                color: Colors.transparent,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(50),
                              borderSide: BorderSide(
                                color: cs.primary.withValues(alpha: 0.3),
                              ),
                            ),
                            prefixIcon: Icon(
                              Lucide.Search,
                              color: cs.onSurface.withValues(alpha: 0.7),
                              size: 18,
                            ),
                            suffixIcon: (q.isNotEmpty)
                                ? IconButton(
                                    icon: Icon(
                                      Lucide.X,
                                      size: 16,
                                      color: cs.onSurface.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      setState(() {});
                                    },
                                  )
                                : null,
                          ),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
              ),
            ),

            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        l10n.chatHistoryPageNoConversations,
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    )
                  : ListView(
                      children: [
                        if (pinned.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                            child: Text(
                              l10n.chatHistoryPagePinnedSection,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: cs.primary,
                              ),
                            ),
                          ),
                          for (final c in pinned)
                            _buildConversationTile(context, c),
                          const SizedBox(height: 8),
                        ],
                        for (final c in others)
                          _buildConversationTile(context, c),
                        const SizedBox(height: 8),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationTile(BuildContext context, Conversation c) {
    final tile = _ConversationCard(
      conversation: c,
      onTap: () => Navigator.of(context).pop(c.id),
    );

    final platform = Theme.of(context).platform;
    final isMobilePlatform =
        platform == TargetPlatform.android || platform == TargetPlatform.iOS;
    if (!isMobilePlatform) return tile;

    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    return Dismissible(
      key: ValueKey('history-${c.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: cs.errorContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              l10n.chatHistoryPageDelete,
              style: TextStyle(
                color: cs.onErrorContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Lucide.Trash2, color: cs.onErrorContainer, size: 18),
          ],
        ),
      ),
      onDismissed: (_) async {
        await context.read<ChatService>().deleteConversation(c.id);
        if (!context.mounted) return;
        showAppSnackBar(
          context,
          message: l10n.sideDrawerDeleteSnackbar(c.title),
          type: NotificationType.success,
          duration: const Duration(seconds: 3),
        );
      },
      child: tile,
    );
  }
}

class _ConversationCard extends StatelessWidget {
  const _ConversationCard({required this.conversation, this.onTap});
  final Conversation conversation;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.white12 : const Color(0xFFF7F7F9);
    final border = cs.outlineVariant.withValues(alpha: 0.16);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border, width: 1),
            ),
            child: Row(
              children: [
                // Leading icon/avatar
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Lucide.MessageCircle,
                    size: 18,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(width: 10),
                // Title and time
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conversation.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Lucide.History,
                            size: 14,
                            color: cs.onSurface.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _format(context, conversation.updatedAt),
                            style: TextStyle(
                              fontSize: 12.5,
                              color: cs.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Pin toggle
                _PinButton(conversation: conversation),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _format(BuildContext context, DateTime dt) {
    final locale = Localizations.localeOf(context);
    final fmt = locale.languageCode == 'zh'
        ? DateFormat('yyyy年M月d日 HH:mm:ss')
        : DateFormat('yyyy-MM-dd HH:mm:ss');
    return fmt.format(dt);
  }
}

class _PinButton extends StatelessWidget {
  const _PinButton({required this.conversation});
  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final pinned = conversation.isPinned;
    return InkResponse(
      onTap: () async {
        await context.read<ChatService>().togglePinConversation(
          conversation.id,
        );
      },
      radius: 20,
      child: AnimatedContainer(
        duration: kAnim,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: pinned ? cs.primary.withValues(alpha: 0.12) : cs.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedIconSwap(
              child: Icon(
                pinned ? Lucide.PinOff : Lucide.Pin,
                key: ValueKey(pinned ? 'pinOff' : 'pin'),
                size: 16,
                color: pinned
                    ? cs.primary
                    : cs.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(width: 6),
            AnimatedTextSwap(
              text: pinned
                  ? l10n.chatHistoryPagePinned
                  : l10n.chatHistoryPagePin,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: pinned
                    ? cs.primary
                    : cs.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
