import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/conversation.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../core/providers/memory_provider.dart';
import '../../../core/providers/world_book_provider.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tile_button.dart';
import '../../../theme/app_font_weights.dart';
import '../diagnostic_service.dart';
import 'diagnostic_result_page.dart';

/// Page that lists all conversations for the user to pick one to diagnose.
class ConversationSelectPage extends StatefulWidget {
  const ConversationSelectPage({super.key, this.embedded = false});

  /// When true, the page renders without its own AppBar so it can be
  /// embedded in a host page (e.g. desktop settings panes).
  final bool embedded;

  @override
  State<ConversationSelectPage> createState() => _ConversationSelectPageState();
}

class _ConversationSelectPageState extends State<ConversationSelectPage> {
  String? _selectedId;
  bool _computing = false;
  // Conversation id -> availability summary.
  final Map<String, _DiagAvailability> _availability = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _evaluateAll();
    });
  }

  Future<void> _evaluateAll() async {
    if (!mounted) return;
    setState(() => _computing = true);
    try {
      final chatService = context.read<ChatService>();
      final assistantProvider = context.read<AssistantProvider>();
      final memoryProvider = context.read<MemoryProvider>();
      final worldBookProvider = context.read<WorldBookProvider>();
      final diag = CacheDiagnosticService(
        chatService: chatService,
        assistantProvider: assistantProvider,
        memoryProvider: memoryProvider,
        worldBookProvider: worldBookProvider,
      );
      final all = chatService.getAllConversations();
      final next = <String, _DiagAvailability>{};
      final cutoff = DateTime.now().subtract(const Duration(hours: 24));
      for (final c in all) {
        final hasData = diag.hasSufficientData(c);
        final hasRecent = chatService
            .getMessages(c.id)
            .where((m) => m.role == 'assistant' && m.timestamp.isAfter(cutoff))
            .isNotEmpty;
        next[c.id] = _DiagAvailability(
          hasData: hasData,
          hasRecentRequest: hasRecent,
        );
      }
      if (!mounted) return;
      setState(() {
        _availability
          ..clear()
          ..addAll(next);
      });
    } finally {
      if (mounted) setState(() => _computing = false);
    }
  }

  Future<void> _onDiagnoseTap() async {
    if (_selectedId == null) return;
    final chatService = context.read<ChatService>();
    final assistantProvider = context.read<AssistantProvider>();
    final memoryProvider = context.read<MemoryProvider>();
    final worldBookProvider = context.read<WorldBookProvider>();
    final conv = chatService.getAllConversations().firstWhere(
      (c) => c.id == _selectedId,
    );
    final diag = CacheDiagnosticService(
      chatService: chatService,
      assistantProvider: assistantProvider,
      memoryProvider: memoryProvider,
      worldBookProvider: worldBookProvider,
    );
    final report = await diag.analyze(conv);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DiagnosticResultPage(report: report)),
    );
    if (mounted) _evaluateAll();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final chatService = context.watch<ChatService>();
    final conversations = chatService.getAllConversations()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: Text(l10n.diagSelectTitle),
              leading: IconButton(
                icon: const Icon(Lucide.ArrowLeft),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
      body: conversations.isEmpty
          ? _EmptyState(message: l10n.diagSelectEmpty)
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
              itemCount: conversations.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final c = conversations[i];
                final avail = _availability[c.id];
                final disabled = avail == null
                    ? _computing
                    : (!avail.hasData || !avail.hasRecentRequest);
                final selected = _selectedId == c.id;
                return _ConversationTile(
                  conversation: c,
                  available: avail,
                  selected: selected,
                  disabled: disabled,
                  onTap: disabled
                      ? null
                      : () => setState(() => _selectedId = c.id),
                );
              },
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: IosTileButton(
            label: l10n.diagSelectButton,
            icon: Lucide.Activity,
            onTap: (_selectedId == null || _computing) ? () {} : _onDiagnoseTap,
            enabled: _selectedId != null && !_computing,
          ),
        ),
      ),
      backgroundColor: cs.surface,
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.available,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  final Conversation conversation;
  final _DiagAvailability? available;
  final bool selected;
  final bool disabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final title = conversation.title.trim().isEmpty
        ? l10n.diagUntitled
        : conversation.title;
    final subtitle = _formatDate(conversation.updatedAt);
    final baseBg = disabled
        ? cs.onSurface.withValues(alpha: 0.03)
        : (selected ? cs.primary.withValues(alpha: 0.10) : cs.surface);
    final border = selected
        ? cs.primary.withValues(alpha: 0.7)
        : cs.outlineVariant.withValues(alpha: 0.4);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: baseBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Icon(
              Lucide.MessagesSquare,
              size: 18,
              color: disabled
                  ? cs.onSurface.withValues(alpha: 0.35)
                  : cs.onSurface.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: AppFontWeights.semibold,
                      color: disabled
                          ? cs.onSurface.withValues(alpha: 0.4)
                          : cs.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            if (available != null && !available!.hasData) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  l10n.diagInsufficientBadge,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: cs.onSurface.withValues(alpha: 0.55),
                    fontWeight: AppFontWeights.medium,
                  ),
                ),
              ),
            ],
            if (selected) ...[
              const SizedBox(width: 6),
              Icon(Lucide.Check, size: 18, color: cs.primary),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

class _DiagAvailability {
  const _DiagAvailability({
    required this.hasData,
    required this.hasRecentRequest,
  });
  final bool hasData;
  final bool hasRecentRequest;
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Lucide.MessageCircle,
              size: 40,
              color: cs.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }
}
