part of '../desktop_settings_page.dart';

// ===== Assistants (Desktop right content) =====

class _DesktopAssistantsBody extends StatelessWidget {
  const _DesktopAssistantsBody({super.key});
  @override
  Widget build(BuildContext context) {
    final assistants = context.watch<AssistantProvider>().assistants;
    final cs = Theme.of(context).colorScheme;
    return Container(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            children: [
              SizedBox(
                height: 36,
                child: Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          AppLocalizations.of(
                            context,
                          )!.desktopAssistantsListTitle,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: cs.onSurface.withOpacity(0.9),
                          ),
                        ),
                      ),
                    ),
                    _AddAssistantButton(),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor.withOpacity(0.0),
                  ),
                  child: ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    padding: EdgeInsets.zero,
                    itemCount: assistants.length,
                    onReorder: (oldIndex, newIndex) async {
                      if (newIndex > oldIndex) newIndex -= 1;
                      await context.read<AssistantProvider>().reorderAssistants(
                        oldIndex,
                        newIndex,
                      );
                    },
                    proxyDecorator: (child, index, animation) {
                      return AnimatedBuilder(
                        animation: animation,
                        builder: (context, _) {
                          final t = Curves.easeOutCubic.transform(
                            animation.value,
                          );
                          return Transform.scale(
                            scale: 0.98 + 0.02 * t,
                            child: Material(
                              elevation: 0,
                              shadowColor: Colors.transparent,
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(18),
                              child: child,
                            ),
                          );
                        },
                      );
                    },
                    itemBuilder: (context, index) {
                      final item = assistants[index];
                      return KeyedSubtree(
                        key: ValueKey('desktop-assistant-${item.id}'),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ReorderableDragStartListener(
                            index: index,
                            child: _DesktopAssistantCard(
                              item: item,
                              onTap: () => showAssistantDesktopDialog(
                                context,
                                assistantId: item.id,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddAssistantButton extends StatefulWidget {
  @override
  State<_AddAssistantButton> createState() => _AddAssistantButtonState();
}

class _AddAssistantButtonState extends State<_AddAssistantButton> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = _hover
        ? (isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.05))
        : Colors.transparent;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () async {
          final name = await _showAddAssistantDesktopDialog(context);
          if (name == null || name.trim().isEmpty) return;
          await context.read<AssistantProvider>().addAssistant(
            name: name.trim(),
            context: context,
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(lucide.Lucide.Plus, size: 16, color: cs.primary),
        ),
      ),
    );
  }
}

Future<String?> _showAddAssistantDesktopDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final cs = Theme.of(context).colorScheme;
  final controller = TextEditingController();
  String? result;
  await showDialog<String>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return Dialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
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
                          l10n.assistantSettingsAddSheetTitle,
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
                        icon: const Icon(lucide.Lucide.X, size: 18),
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
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: l10n.assistantSettingsAddSheetHint,
                        filled: true,
                        fillColor: Theme.of(ctx).brightness == Brightness.dark
                            ? Colors.white10
                            : const Color(0xFFF7F7F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: cs.outlineVariant.withOpacity(0.2),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: cs.primary.withOpacity(0.4),
                          ),
                        ),
                      ),
                      onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _DeskIosButton(
                          label: l10n.assistantSettingsAddSheetCancel,
                          filled: false,
                          dense: true,
                          onTap: () => Navigator.of(ctx).pop(),
                        ),
                        const SizedBox(width: 8),
                        _DeskIosButton(
                          label: l10n.assistantSettingsAddSheetSave,
                          filled: true,
                          dense: true,
                          onTap: () =>
                              Navigator.of(ctx).pop(controller.text.trim()),
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
  ).then((v) => result = v);
  final s = (result ?? '').trim();
  if (s.isEmpty) return null;
  return s;
}

class _DeleteAssistantIcon extends StatefulWidget {
  const _DeleteAssistantIcon({required this.onConfirm});
  final Future<void> Function() onConfirm;
  @override
  State<_DeleteAssistantIcon> createState() => _DeleteAssistantIconState();
}

class _DeleteAssistantIconState extends State<_DeleteAssistantIcon> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = _hover
        ? (isDark ? cs.error.withOpacity(0.18) : cs.error.withOpacity(0.14))
        : Colors.transparent;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => widget.onConfirm(),
        child: Container(
          margin: const EdgeInsets.only(left: 8),
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Icon(lucide.Lucide.Trash2, size: 15, color: cs.error),
        ),
      ),
    );
  }
}

class _CopyAssistantIcon extends StatefulWidget {
  const _CopyAssistantIcon({required this.onCopy});
  final Future<void> Function() onCopy;
  @override
  State<_CopyAssistantIcon> createState() => _CopyAssistantIconState();
}

class _CopyAssistantIconState extends State<_CopyAssistantIcon> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = _hover
        ? (isDark ? cs.primary.withOpacity(0.16) : cs.primary.withOpacity(0.12))
        : Colors.transparent;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => widget.onCopy(),
        child: Container(
          margin: const EdgeInsets.only(left: 8),
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Icon(lucide.Lucide.Copy, size: 15, color: cs.primary),
        ),
      ),
    );
  }
}

Future<bool?> _confirmDeleteDesktop(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final cs = Theme.of(context).colorScheme;
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'assistant-delete',
    barrierColor: Colors.black.withOpacity(0.15),
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (ctx, _, __) {
      final dialog = Material(
        color: Colors.transparent,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: cs.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: Theme.of(ctx).brightness == Brightness.dark
                        ? Colors.white.withOpacity(0.08)
                        : cs.outlineVariant.withOpacity(0.25),
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 44,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.assistantSettingsDeleteDialogTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: MaterialLocalizations.of(
                              ctx,
                            ).closeButtonTooltip,
                            icon: const Icon(lucide.Lucide.X, size: 18),
                            color: cs.onSurface,
                            onPressed: () => Navigator.of(ctx).maybePop(false),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    color: cs.outlineVariant.withOpacity(0.12),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.assistantSettingsDeleteDialogContent,
                          style: TextStyle(
                            color: cs.onSurface.withOpacity(0.9),
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _DeskIosButton(
                              label: l10n.assistantSettingsDeleteDialogCancel,
                              filled: false,
                              dense: true,
                              onTap: () => Navigator.of(ctx).pop(false),
                            ),
                            const SizedBox(width: 8),
                            _DeskIosButton(
                              label: l10n.assistantSettingsDeleteDialogConfirm,
                              filled: true,
                              danger: true,
                              dense: true,
                              onTap: () => Navigator.of(ctx).pop(true),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      return dialog;
    },
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _DeskIosButton extends StatefulWidget {
  const _DeskIosButton({
    required this.label,
    required this.onTap,
    this.filled = false,
    this.danger = false,
    this.dense = false,
  });
  final String label;
  final VoidCallback onTap;
  final bool filled;
  final bool danger;
  final bool dense;
  @override
  State<_DeskIosButton> createState() => _DeskIosButtonState();
}

class _DeskIosButtonState extends State<_DeskIosButton> {
  bool _pressed = false;
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = widget.danger ? cs.error : cs.primary;
    final textColor = widget.filled
        ? (widget.danger ? cs.onError : cs.onPrimary)
        : baseColor;
    final baseBg = widget.filled
        ? baseColor
        : (isDark ? Colors.white10 : Colors.transparent);
    final hoverBg = widget.filled
        ? baseColor.withOpacity(0.92)
        : (isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.04));
    final bg = _hover ? hoverBg : baseBg;
    final borderColor = widget.filled
        ? Colors.transparent
        : baseColor.withOpacity(isDark ? 0.6 : 0.5);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOutCubic,
          child: Container(
            padding: EdgeInsets.symmetric(
              vertical: widget.dense ? 8 : 12,
              horizontal: 12,
            ),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: widget.dense ? 13 : 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopAssistantCard extends StatefulWidget {
  const _DesktopAssistantCard({required this.item, required this.onTap});
  final Assistant item;
  final VoidCallback onTap;
  @override
  State<_DesktopAssistantCard> createState() => _DesktopAssistantCardState();
}

class _DesktopAssistantCardState extends State<_DesktopAssistantCard> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseBg = isDark ? Colors.white10 : Colors.white.withOpacity(0.96);
    final borderColor = _hover
        ? cs.primary.withOpacity(isDark ? 0.35 : 0.45)
        : cs.outlineVariant.withOpacity(isDark ? 0.12 : 0.08);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: _CardPress(
        onTap: widget.onTap,
        pressedScale: 1.0,
        builder: (pressed, overlay) => Container(
          decoration: BoxDecoration(
            color: Color.alphaBlend(overlay, baseBg),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 1.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _AssistantAvatarDesktop(item: widget.item, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (!widget.item.deletable)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: cs.primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: cs.primary.withOpacity(0.35),
                                ),
                              ),
                              child: Text(
                                AppLocalizations.of(
                                  context,
                                )!.assistantSettingsDefaultTag,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: cs.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          _CopyAssistantIcon(
                            onCopy: () async {
                              final l10n = AppLocalizations.of(context)!;
                              final newId = await context
                                  .read<AssistantProvider>()
                                  .duplicateAssistant(
                                    widget.item.id,
                                    l10n: l10n,
                                  );
                              if (!mounted) return;
                              if (newId != null) {
                                showAppSnackBar(
                                  context,
                                  message: l10n.assistantSettingsCopySuccess,
                                  type: NotificationType.success,
                                );
                              }
                            },
                          ),
                          _DeleteAssistantIcon(
                            onConfirm: () async {
                              final l10n = AppLocalizations.of(context)!;
                              final count = context
                                  .read<AssistantProvider>()
                                  .assistants
                                  .length;
                              if (count <= 1) {
                                showAppSnackBar(
                                  context,
                                  message: l10n
                                      .assistantSettingsAtLeastOneAssistantRequired,
                                  type: NotificationType.warning,
                                );
                                return;
                              }
                              final ok = await _confirmDeleteDesktop(context);
                              if (ok == true) {
                                final success = await context
                                    .read<AssistantProvider>()
                                    .deleteAssistant(widget.item.id);
                                if (success != true) {
                                  showAppSnackBar(
                                    context,
                                    message: l10n
                                        .assistantSettingsAtLeastOneAssistantRequired,
                                    type: NotificationType.warning,
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        (widget.item.systemPrompt.trim().isEmpty
                            ? AppLocalizations.of(
                                context,
                              )!.assistantSettingsNoPromptPlaceholder
                            : widget.item.systemPrompt),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurface.withOpacity(0.7),
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AssistantAvatarDesktop extends StatelessWidget {
  const _AssistantAvatarDesktop({required this.item, this.size = 40});
  final Assistant item;
  final double size;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final av = (item.avatar ?? '').trim();
    if (av.isNotEmpty) {
      if (av.startsWith('http')) {
        return FutureBuilder<String?>(
          future: AvatarCache.getPath(av),
          builder: (ctx, snap) {
            final p = snap.data;
            if (p != null && File(p).existsSync()) {
              return ClipOval(
                child: Image(
                  image: FileImage(File(p)),
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                ),
              );
            }
            return ClipOval(
              child: Image.network(
                av,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => _initial(cs),
              ),
            );
          },
        );
      } else if (av.startsWith('/') || av.contains(':')) {
        final fixed = SandboxPathResolver.fix(av);
        final f = File(fixed);
        if (f.existsSync()) {
          return ClipOval(
            child: Image(
              image: FileImage(f),
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
          );
        }
        return _initial(cs);
      } else {
        return _emoji(cs, av);
      }
    }
    return _initial(cs);
  }

  Widget _initial(ColorScheme cs) {
    final letter = item.name.isNotEmpty ? item.name.characters.first : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          color: cs.primary,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.42,
        ),
      ),
    );
  }

  Widget _emoji(ColorScheme cs, String emoji) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        emoji.characters.take(1).toString(),
        style: TextStyle(fontSize: size * 0.5),
      ),
    );
  }
}

