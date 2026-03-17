part of 'assistant_settings_edit_page.dart';

class _MemoryTab extends StatelessWidget {
  const _MemoryTab({required this.assistantId});
  final String assistantId;

  Future<void> _showAddEditSheet(
    BuildContext context, {
    int? id,
    String initial = '',
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final controller = TextEditingController(text: initial);
    // Desktop: custom dialog; Mobile: keep bottom sheet
    final platform = Theme.of(context).platform;
    final isDesktop =
        platform == TargetPlatform.macOS ||
        platform == TargetPlatform.linux ||
        platform == TargetPlatform.windows;
    if (isDesktop) {
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) {
          return Dialog(
            backgroundColor: cs.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 44,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.assistantEditMemoryDialogTitle,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: MaterialLocalizations.of(
                              ctx,
                            ).closeButtonTooltip,
                            icon: const Icon(Lucide.X, size: 18),
                            color: cs.onSurface,
                            onPressed: () => Navigator.of(ctx).maybePop(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: controller,
                          minLines: 3,
                          maxLines: 8,
                          decoration: InputDecoration(
                            hintText: l10n.assistantEditMemoryDialogHint,
                            filled: true,
                            fillColor:
                                Theme.of(ctx).brightness == Brightness.dark
                                ? Colors.white10
                                : const Color(0xFFF7F7F9),
                            border: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: cs.outlineVariant.withValues(alpha: 0.2),
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: cs.primary.withValues(alpha: 0.5),
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          autofocus: true,
                          onSubmitted: (_) async {
                            final text = controller.text.trim();
                            if (text.isEmpty) return;
                            final mp = context.read<MemoryProvider>();
                            if (id == null) {
                              await mp.add(
                                assistantId: assistantId,
                                content: text,
                              );
                            } else {
                              await mp.update(id: id, content: text);
                            }
                            if (context.mounted) Navigator.of(ctx).pop();
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _IosButton(
                              label: l10n.assistantEditEmojiDialogCancel,
                              onTap: () => Navigator.of(ctx).pop(),
                              filled: false,
                              neutral: true,
                              dense: true,
                            ),
                            const SizedBox(width: 8),
                            _IosButton(
                              label: l10n.assistantEditEmojiDialogSave,
                              onTap: () async {
                                final text = controller.text.trim();
                                if (text.isEmpty) return;
                                final mp = context.read<MemoryProvider>();
                                if (id == null) {
                                  await mp.add(
                                    assistantId: assistantId,
                                    content: text,
                                  );
                                } else {
                                  await mp.update(id: id, content: text);
                                }
                                if (context.mounted) Navigator.of(ctx).pop();
                              },
                              filled: true,
                              neutral: false,
                              dense: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final media = MediaQuery.of(ctx);
        final bottom = media.viewInsets.bottom;
        final maxSheetHeight =
            (media.size.height -
                    media.padding.top -
                    media.viewInsets.bottom -
                    24)
                .clamp(0.0, 560.0)
                .toDouble();
        return SafeArea(
          top: false,
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxSheetHeight),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Lucide.Library, size: 18, color: cs.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.assistantEditMemoryDialogTitle,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    fit: FlexFit.loose,
                    child: TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: 16,
                      decoration: InputDecoration(
                        hintText: l10n.assistantEditMemoryDialogHint,
                        filled: true,
                        fillColor: Theme.of(ctx).brightness == Brightness.dark
                            ? Colors.white10
                            : const Color(0xFFF7F7F9),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: cs.outlineVariant.withValues(alpha: 0.2),
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: cs.primary.withValues(alpha: 0.5),
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _IosButton(
                          label: l10n.assistantEditEmojiDialogCancel,
                          icon: Lucide.X,
                          onTap: () => Navigator.of(ctx).pop(),
                          filled: false,
                          neutral: true,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _IosButton(
                          label: l10n.assistantEditEmojiDialogSave,
                          icon: Lucide.Check,
                          onTap: () async {
                            final text = controller.text.trim();
                            if (text.isEmpty) return;
                            final mp = context.read<MemoryProvider>();
                            if (id == null) {
                              await mp.add(
                                assistantId: assistantId,
                                content: text,
                              );
                            } else {
                              await mp.update(id: id, content: text);
                            }
                            if (context.mounted) Navigator.of(ctx).pop();
                          },
                          filled: true,
                          neutral: false,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ap = context.watch<AssistantProvider>();
    final a = ap.getById(assistantId)!;
    final mp = context.watch<MemoryProvider>();
    // Ensure provider loads persisted memories once
    try {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        mp.initialize();
      });
    } catch (_) {}
    final memories = mp.getForAssistant(assistantId);

    // Align the section card visuals with the basic settings page iOS-style list cards
    Widget sectionCard({
      required Widget child,
      EdgeInsets padding = const EdgeInsets.symmetric(vertical: 6),
    }) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          // Match Settings page: Light uses translucent white; Dark uses subtle white10
          color: isDark ? Colors.white10 : Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: isDark ? 0.08 : 0.06),
            width: 0.6,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: padding, child: child),
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
      children: [
        // Feature switches
        sectionCard(
          child: Column(
            children: [
              _iosSwitchRow(
                context,
                icon: Lucide.bookHeart,
                label: l10n.assistantEditMemorySwitchTitle,
                value: a.enableMemory,
                onChanged: (v) async {
                  await context.read<AssistantProvider>().updateAssistant(
                    a.copyWith(enableMemory: v),
                  );
                },
              ),
              _iosDivider(context),
              _iosSwitchRow(
                context,
                icon: Lucide.History,
                label: l10n.assistantEditRecentChatsSwitchTitle,
                value: a.enableRecentChatsReference,
                onChanged: (v) async {
                  await context.read<AssistantProvider>().updateAssistant(
                    a.copyWith(enableRecentChatsReference: v),
                  );
                },
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                child: a.enableRecentChatsReference
                    ? Column(
                        children: [
                          _iosDivider(context),
                          _RecentChatsSummaryFrequencySection(assistant: a),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),

        // Manage memories header with add button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.assistantEditManageMemoryTitle,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _TactileRow(
                onTap: () => _showAddEditSheet(context),
                pressedScale: 0.97,
                builder: (pressed) {
                  final color = pressed
                      ? cs.primary.withValues(alpha: 0.7)
                      : cs.primary;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Lucide.Plus, size: 16, color: color),
                      const SizedBox(width: 4),
                      Text(
                        l10n.assistantEditAddMemoryButton,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),

        if (memories.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              l10n.assistantEditMemoryEmpty,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
          ),

        // Memory list
        ...memories.map((m) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white10
                    : Colors.white.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: cs.outlineVariant.withValues(
                    alpha: isDark ? 0.08 : 0.06,
                  ),
                  width: 0.6,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        m.content,
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _TactileIconButton(
                      icon: Lucide.Pencil,
                      size: 18,
                      color: cs.primary,
                      onTap: () => _showAddEditSheet(
                        context,
                        id: m.id,
                        initial: m.content,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _TactileIconButton(
                      icon: Lucide.Trash2,
                      size: 18,
                      color: cs.error,
                      onTap: () async {
                        await context.read<MemoryProvider>().delete(id: m.id);
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        }),

        // Summaries section
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.assistantEditManageSummariesTitle,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),

        Builder(
          builder: (context) {
            final chatService = context.watch<ChatService>();
            final summaries = chatService
                .getConversationsWithSummaryForAssistant(assistantId);

            if (summaries.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  l10n.assistantEditSummaryEmpty,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              );
            }

            return Column(
              children: summaries.map((conv) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white10
                          : Colors.white.withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: cs.outlineVariant.withValues(
                          alpha: isDark ? 0.08 : 0.06,
                        ),
                        width: 0.6,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Lucide.MessageSquare,
                                size: 14,
                                color: cs.onSurface.withValues(alpha: 0.5),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  conv.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onSurface.withValues(alpha: 0.6),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  conv.summary ?? '',
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                              const SizedBox(width: 6),
                              _TactileIconButton(
                                icon: Lucide.Pencil,
                                size: 18,
                                color: cs.primary,
                                onTap: () => _showEditSummarySheet(
                                  context,
                                  conv,
                                  chatService,
                                ),
                              ),
                              const SizedBox(width: 6),
                              _TactileIconButton(
                                icon: Lucide.Trash2,
                                size: 18,
                                color: cs.error,
                                onTap: () => _confirmDeleteSummary(
                                  context,
                                  conv.id,
                                  chatService,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  Future<void> _showEditSummarySheet(
    BuildContext context,
    Conversation conversation,
    ChatService chatService,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final controller = TextEditingController(text: conversation.summary ?? '');
    final platform = Theme.of(context).platform;
    final isDesktop =
        platform == TargetPlatform.macOS ||
        platform == TargetPlatform.linux ||
        platform == TargetPlatform.windows;

    if (isDesktop) {
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) {
          return Dialog(
            backgroundColor: cs.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 44,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.assistantEditSummaryDialogTitle,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: MaterialLocalizations.of(
                              ctx,
                            ).closeButtonTooltip,
                            icon: const Icon(Lucide.X, size: 18),
                            color: cs.onSurface,
                            onPressed: () => Navigator.of(ctx).maybePop(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      conversation.title,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: controller,
                          minLines: 3,
                          maxLines: 8,
                          decoration: InputDecoration(
                            hintText: l10n.assistantEditSummaryDialogHint,
                            filled: true,
                            fillColor:
                                Theme.of(ctx).brightness == Brightness.dark
                                ? Colors.white10
                                : const Color(0xFFF7F7F9),
                            border: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: cs.outlineVariant.withValues(alpha: 0.2),
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: cs.primary.withValues(alpha: 0.5),
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          autofocus: true,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _IosButton(
                              label: l10n.assistantEditEmojiDialogCancel,
                              onTap: () => Navigator.of(ctx).pop(),
                              filled: false,
                              neutral: true,
                              dense: true,
                            ),
                            const SizedBox(width: 8),
                            _IosButton(
                              label: l10n.assistantEditEmojiDialogSave,
                              onTap: () async {
                                final text = controller.text.trim();
                                if (text.isEmpty) {
                                  await chatService.clearConversationSummary(
                                    conversation.id,
                                  );
                                } else {
                                  await chatService.updateConversationSummary(
                                    conversation.id,
                                    text,
                                    conversation.lastSummarizedMessageCount,
                                  );
                                }
                                if (context.mounted) Navigator.of(ctx).pop();
                              },
                              filled: true,
                              neutral: false,
                              dense: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
      return;
    }

    // Mobile: BottomSheet
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Lucide.FileText, size: 18, color: cs.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.assistantEditSummaryDialogTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  conversation.title,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 16,
                  decoration: InputDecoration(
                    hintText: l10n.assistantEditSummaryDialogHint,
                    filled: true,
                    fillColor: Theme.of(ctx).brightness == Brightness.dark
                        ? Colors.white10
                        : const Color(0xFFF7F7F9),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: cs.outlineVariant.withValues(alpha: 0.2),
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: cs.primary.withValues(alpha: 0.5),
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _IosButton(
                        label: l10n.assistantEditEmojiDialogCancel,
                        icon: Lucide.X,
                        onTap: () => Navigator.of(ctx).pop(),
                        filled: false,
                        neutral: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _IosButton(
                        label: l10n.assistantEditEmojiDialogSave,
                        icon: Lucide.Check,
                        onTap: () async {
                          final text = controller.text.trim();
                          if (text.isEmpty) {
                            await chatService.clearConversationSummary(
                              conversation.id,
                            );
                          } else {
                            await chatService.updateConversationSummary(
                              conversation.id,
                              text,
                              conversation.lastSummarizedMessageCount,
                            );
                          }
                          if (context.mounted) Navigator.of(ctx).pop();
                        },
                        filled: true,
                        neutral: false,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteSummary(
    BuildContext context,
    String conversationId,
    ChatService chatService,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.assistantEditDeleteSummaryTitle),
        content: Text(l10n.assistantEditDeleteSummaryContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.homePageCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(l10n.assistantEditClearButton),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await chatService.clearConversationSummary(conversationId);
    }
  }
}

class _RecentChatsSummaryFrequencySection extends StatelessWidget {
  const _RecentChatsSummaryFrequencySection({required this.assistant});

  final Assistant assistant;

  Future<void> _showCustomCountInput(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final controller = TextEditingController(
      text: assistant.recentChatsSummaryMessageCount.toString(),
    );
    final ap = context.read<AssistantProvider>();
    final platform = Theme.of(context).platform;
    final isDesktop =
        platform == TargetPlatform.macOS ||
        platform == TargetPlatform.linux ||
        platform == TargetPlatform.windows;

    int? parseValue() {
      final value = int.tryParse(controller.text.trim());
      if (value == null || value < 1) return null;
      return value;
    }

    Future<void> submit(BuildContext sheetContext) async {
      final parsed = parseValue();
      if (parsed == null) return;
      if (parsed != assistant.recentChatsSummaryMessageCount) {
        await ap.updateAssistant(
          assistant.copyWith(recentChatsSummaryMessageCount: parsed),
        );
      }
      if (sheetContext.mounted) Navigator.of(sheetContext).pop();
    }

    if (isDesktop) {
      await showDialog<void>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setLocal) {
              final parsed = parseValue();
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Text(
                  l10n.assistantEditRecentChatsSummaryFrequencyCustomTitle,
                ),
                content: SizedBox(
                  width: 360,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.assistantEditRecentChatsSummaryFrequencyCustomDescription,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: cs.onSurface.withValues(alpha: 0.68),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: controller,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          labelText: l10n
                              .assistantEditRecentChatsSummaryFrequencyCustomLabel,
                          hintText: l10n
                              .assistantEditRecentChatsSummaryFrequencyCustomHint,
                        ),
                        onChanged: (_) => setLocal(() {}),
                        onSubmitted: (_) async {
                          if (parsed != null) await submit(ctx);
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(l10n.assistantEditEmojiDialogCancel),
                  ),
                  TextButton(
                    onPressed: parsed == null ? null : () => submit(ctx),
                    child: Text(l10n.assistantEditEmojiDialogSave),
                  ),
                ],
              );
            },
          );
        },
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final parsed = parseValue();
            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  MediaQuery.of(ctx).viewInsets.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Lucide.FileClock, size: 18, color: cs.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.assistantEditRecentChatsSummaryFrequencyCustomTitle,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.assistantEditRecentChatsSummaryFrequencyCustomDescription,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: cs.onSurface.withValues(alpha: 0.68),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: l10n
                            .assistantEditRecentChatsSummaryFrequencyCustomLabel,
                        hintText: l10n
                            .assistantEditRecentChatsSummaryFrequencyCustomHint,
                        filled: true,
                        fillColor: Theme.of(ctx).brightness == Brightness.dark
                            ? Colors.white10
                            : const Color(0xFFF7F7F9),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: cs.outlineVariant.withValues(alpha: 0.2),
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: cs.primary.withValues(alpha: 0.5),
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onChanged: (_) => setLocal(() {}),
                      onSubmitted: (_) async {
                        if (parsed != null) await submit(ctx);
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _IosButton(
                            label: l10n.assistantEditEmojiDialogCancel,
                            icon: Lucide.X,
                            onTap: () => Navigator.of(ctx).pop(),
                            filled: false,
                            neutral: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _IosButton(
                            label: l10n.assistantEditEmojiDialogSave,
                            icon: Lucide.Check,
                            onTap: parsed == null
                                ? () {
                                    showAppSnackBar(
                                      context,
                                      message: l10n
                                          .assistantEditRecentChatsSummaryFrequencyCustomInvalid,
                                      type: NotificationType.error,
                                    );
                                  }
                                : () => submit(ctx),
                            filled: true,
                            neutral: false,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final ap = context.read<AssistantProvider>();
    final selected = assistant.recentChatsSummaryMessageCount;
    final options = <int>{
      ...Assistant.recentChatsSummaryMessageCountOptions,
      selected,
    }.toList()..sort();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 36,
                child: Icon(
                  Lucide.FileClock,
                  size: 20,
                  color: cs.onSurface.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.assistantEditRecentChatsSummaryFrequencyTitle,
                      style: TextStyle(
                        fontSize: 15,
                        color: cs.onSurface.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.assistantEditRecentChatsSummaryFrequencyDescription,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: cs.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 48),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...options.map((count) {
                  final isSelected = count == selected;
                  return _FrequencyChipButton(
                    label: l10n.assistantEditRecentChatsSummaryFrequencyOption(
                      count,
                    ),
                    selected: isSelected,
                    onTap: isSelected
                        ? null
                        : () async {
                            await ap.updateAssistant(
                              assistant.copyWith(
                                recentChatsSummaryMessageCount: count,
                              ),
                            );
                          },
                  );
                }),
                _FrequencyChipButton(
                  label:
                      l10n.assistantEditRecentChatsSummaryFrequencyCustomButton,
                  icon: Lucide.Pencil,
                  emphasized: true,
                  onTap: () => _showCustomCountInput(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FrequencyChipButton extends StatelessWidget {
  const _FrequencyChipButton({
    required this.label,
    required this.onTap,
    this.selected = false,
    this.emphasized = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final bool emphasized;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseBackground = selected
        ? cs.primary.withValues(alpha: isDark ? 0.22 : 0.12)
        : (isDark ? Colors.white10 : const Color(0xFFF2F3F5));
    final borderColor = selected
        ? cs.primary.withValues(alpha: 0.38)
        : (emphasized
              ? cs.primary.withValues(alpha: isDark ? 0.24 : 0.18)
              : cs.outlineVariant.withValues(alpha: isDark ? 0.18 : 0.14));
    final foregroundColor = selected || emphasized
        ? cs.primary
        : cs.onSurface.withValues(alpha: 0.8);

    return MouseRegion(
      cursor: onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: _TactileRow(
        onTap: onTap,
        haptics: true,
        pressedScale: 0.985,
        releaseDelayMs: 0,
        builder: (pressed) {
          return AnimatedOpacity(
            duration: const Duration(milliseconds: 90),
            curve: Curves.easeOutCubic,
            opacity: pressed ? (selected ? 0.94 : 0.82) : 1.0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: baseBackground,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 14, color: foregroundColor),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: foregroundColor,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
