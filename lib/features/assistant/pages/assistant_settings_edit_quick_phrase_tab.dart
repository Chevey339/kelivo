part of 'assistant_settings_edit_page.dart';

class _QuickPhraseTab extends StatelessWidget {
  const _QuickPhraseTab({required this.assistantId});
  final String assistantId;

  Future<void> _showAddEditSheet(
    BuildContext context, {
    QuickPhrase? phrase,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    // Desktop: custom dialog; Mobile: bottom sheet
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
          final titleCtrl = TextEditingController(text: phrase?.title ?? '');
          final contentCtrl = TextEditingController(
            text: phrase?.content ?? '',
          );
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
                              phrase == null
                                  ? l10n.quickPhraseAddTitle
                                  : l10n.quickPhraseEditTitle,
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
                          controller: titleCtrl,
                          decoration: InputDecoration(
                            labelText: l10n.quickPhraseTitleLabel,
                            filled: true,
                            fillColor:
                                Theme.of(ctx).brightness == Brightness.dark
                                ? Colors.white10
                                : const Color(0xFFF2F3F5),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: cs.outlineVariant.withOpacity(0.4),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: cs.primary.withOpacity(0.5),
                              ),
                            ),
                          ),
                          autofocus: true,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: contentCtrl,
                          maxLines: 5,
                          decoration: InputDecoration(
                            labelText: l10n.quickPhraseContentLabel,
                            alignLabelWithHint: true,
                            filled: true,
                            fillColor:
                                Theme.of(ctx).brightness == Brightness.dark
                                ? Colors.white10
                                : const Color(0xFFF2F3F5),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: cs.outlineVariant.withOpacity(0.4),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: cs.primary.withOpacity(0.5),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _IosButton(
                              label: l10n.quickPhraseCancelButton,
                              onTap: () => Navigator.of(ctx).pop(),
                              filled: false,
                              neutral: true,
                              dense: true,
                            ),
                            const SizedBox(width: 8),
                            _IosButton(
                              label: l10n.quickPhraseSaveButton,
                              onTap: () async {
                                final title = titleCtrl.text.trim();
                                final content = contentCtrl.text.trim();
                                if (title.isEmpty || content.isEmpty) return;
                                if (phrase == null) {
                                  final newPhrase = QuickPhrase(
                                    id: const Uuid().v4(),
                                    title: title,
                                    content: content,
                                    isGlobal: false,
                                    assistantId: assistantId,
                                  );
                                  await context.read<QuickPhraseProvider>().add(
                                    newPhrase,
                                  );
                                } else {
                                  await context
                                      .read<QuickPhraseProvider>()
                                      .update(
                                        phrase.copyWith(
                                          title: title,
                                          content: content,
                                        ),
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
    final result = await showModalBottomSheet<Map<String, String>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return _QuickPhraseEditSheet(phrase: phrase, assistantId: assistantId);
      },
    );

    if (result != null) {
      final title = result['title']?.trim() ?? '';
      final content = result['content']?.trim() ?? '';

      if (title.isEmpty || content.isEmpty) return;

      if (phrase == null) {
        // Add new
        final newPhrase = QuickPhrase(
          id: const Uuid().v4(),
          title: title,
          content: content,
          isGlobal: false,
          assistantId: assistantId,
        );
        await context.read<QuickPhraseProvider>().add(newPhrase);
      } else {
        // Update existing
        await context.read<QuickPhraseProvider>().update(
          phrase.copyWith(title: title, content: content),
        );
      }
    }
  }

  Future<void> _deletePhrase(BuildContext context, QuickPhrase phrase) async {
    await context.read<QuickPhraseProvider>().delete(phrase.id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final quickPhraseProvider = context.watch<QuickPhraseProvider>();
    final phrases = quickPhraseProvider.getForAssistant(assistantId);

    if (phrases.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Lucide.Zap, size: 64, color: cs.primary.withOpacity(0.6)),
              const SizedBox(height: 16),
              Text(
                l10n.assistantEditQuickPhraseDescription,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: cs.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 24),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 200),
                child: _IosButton(
                  label: l10n.assistantEditAddQuickPhraseButton,
                  icon: Lucide.Plus,
                  filled: true,
                  neutral: false,
                  onTap: () => _showAddEditSheet(context),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        ReorderableListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
          itemCount: phrases.length,
          buildDefaultDragHandles: false,
          proxyDecorator: (child, index, animation) {
            return AnimatedBuilder(
              animation: animation,
              builder: (context, _) {
                final t = Curves.easeOut.transform(animation.value);
                return Transform.scale(scale: 0.98 + 0.02 * t, child: child);
              },
            );
          },
          onReorder: (oldIndex, newIndex) {
            if (newIndex > oldIndex) newIndex -= 1;
            // Update immediately for smooth drop animation
            context.read<QuickPhraseProvider>().reorderPhrases(
              oldIndex: oldIndex,
              newIndex: newIndex,
              assistantId: assistantId,
            );
          },
          itemBuilder: (context, index) {
            final phrase = phrases[index];
            return KeyedSubtree(
              key: ValueKey('reorder-assistant-quick-phrase-${phrase.id}'),
              child: ReorderableDelayedDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Slidable(
                    key: ValueKey(phrase.id),
                    endActionPane: ActionPane(
                      motion: const StretchMotion(),
                      extentRatio: 0.35,
                      children: [
                        CustomSlidableAction(
                          autoClose: true,
                          backgroundColor: Colors.transparent,
                          child: Container(
                            width: double.infinity,
                            height: double.infinity,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? cs.error.withOpacity(0.22)
                                  : cs.error.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: cs.error.withOpacity(0.35),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            alignment: Alignment.center,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Lucide.Trash2,
                                    color: cs.error,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    l10n.quickPhraseDeleteButton,
                                    style: TextStyle(
                                      color: cs.error,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          onPressed: (_) => _deletePhrase(context, phrase),
                        ),
                      ],
                    ),
                    child: _TactileRow(
                      onTap: () => _showAddEditSheet(context, phrase: phrase),
                      pressedScale: 0.98,
                      builder: (pressed) {
                        final bg = isDark
                            ? Colors.white10
                            : Colors.white.withOpacity(0.96);
                        final overlay = isDark
                            ? Colors.white.withOpacity(0.06)
                            : Colors.black.withOpacity(0.05);
                        final pressedBg = Color.alphaBlend(overlay, bg);
                        return Container(
                          decoration: BoxDecoration(
                            color: pressed ? pressedBg : bg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: cs.outlineVariant.withOpacity(
                                isDark ? 0.08 : 0.06,
                              ),
                              width: 0.6,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Lucide.botMessageSquare,
                                      size: 18,
                                      color: cs.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        phrase.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Lucide.ChevronRight,
                                      size: 18,
                                      color: cs.onSurface.withOpacity(0.4),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  phrase.content,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: cs.onSurface.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        // Glass circular add button (icon-only), matching providers multi-select style
        Positioned(
          left: 0,
          right: 0,
          bottom: 60,
          child: Center(
            child: _GlassCircleButtonQP(
              icon: Lucide.Plus,
              color: cs.primary,
              onTap: () => _showAddEditSheet(context),
            ),
          ),
        ),
      ],
    );
  }
}

// Local glass circle button for Quick Phrase (icon-only, frosted background)
class _GlassCircleButtonQP extends StatefulWidget {
  const _GlassCircleButtonQP({
    required this.icon,
    required this.color,
    required this.onTap,
    this.size = 48,
  });
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final double size; // diameter

  @override
  State<_GlassCircleButtonQP> createState() => _GlassCircleButtonQPState();
}

class _GlassCircleButtonQPState extends State<_GlassCircleButtonQP> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final glassBase = isDark
        ? Colors.black.withOpacity(0.06)
        : Colors.white.withOpacity(0.06);
    final overlay = isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.black.withOpacity(0.05);
    final tileColor = _pressed
        ? Color.alphaBlend(overlay, glassBase)
        : glassBase;
    final borderColor = cs.outlineVariant.withOpacity(isDark ? 0.10 : 0.10);

    final child = SizedBox(
      width: widget.size,
      height: widget.size,
      child: Center(child: Icon(widget.icon, size: 18, color: widget.color)),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        Haptics.light();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 36, sigmaY: 36),
            child: Container(
              decoration: BoxDecoration(
                color: tileColor,
                shape: BoxShape.circle,
                border: Border.all(color: borderColor, width: 1.0),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickPhraseEditSheet extends StatefulWidget {
  const _QuickPhraseEditSheet({
    required this.phrase,
    required this.assistantId,
  });

  final QuickPhrase? phrase;
  final String? assistantId;

  @override
  State<_QuickPhraseEditSheet> createState() => _QuickPhraseEditSheetState();
}

class _QuickPhraseEditSheetState extends State<_QuickPhraseEditSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.phrase?.title ?? '');
    _contentController = TextEditingController(
      text: widget.phrase?.content ?? '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                widget.phrase == null
                    ? l10n.quickPhraseAddTitle
                    : l10n.quickPhraseEditTitle,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.quickPhraseTitleLabel,
                filled: true,
                fillColor: isDark ? Colors.white10 : const Color(0xFFF2F3F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: cs.outlineVariant.withOpacity(0.4),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: cs.outlineVariant.withOpacity(0.4),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cs.primary.withOpacity(0.5)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contentController,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: l10n.quickPhraseContentLabel,
                alignLabelWithHint: true,
                filled: true,
                fillColor: isDark ? Colors.white10 : const Color(0xFFF2F3F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: cs.outlineVariant.withOpacity(0.4),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: cs.outlineVariant.withOpacity(0.4),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cs.primary.withOpacity(0.5)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: _IosButton(
                      label: l10n.quickPhraseCancelButton,
                      onTap: () => Navigator.of(context).pop(),
                      filled: false,
                      neutral: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: _IosButton(
                      label: l10n.quickPhraseSaveButton,
                      onTap: () {
                        Navigator.of(context).pop({
                          'title': _titleController.text,
                          'content': _contentController.text,
                        });
                      },
                      icon: Lucide.Check,
                      filled: true,
                      neutral: false,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
