import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../icons/lucide_adapter.dart' as lucide;
import '../../l10n/app_localizations.dart';
import '../../core/models/quick_phrase.dart';
import '../../core/providers/quick_phrase_provider.dart';

class DesktopQuickPhrasesPane extends StatefulWidget {
  const DesktopQuickPhrasesPane({super.key});

  @override
  State<DesktopQuickPhrasesPane> createState() =>
      _DesktopQuickPhrasesPaneState();
}

class _DesktopQuickPhrasesPaneState extends State<DesktopQuickPhrasesPane> {
  @override
  void initState() {
    super.initState();
    // Ensure phrases are loaded on first open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<QuickPhraseProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final phrases = context.watch<QuickPhraseProvider>().globalPhrases;

    return Container(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 36,
                  child: Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            l10n.quickPhraseGlobalTitle,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: cs.onSurface.withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                      ),
                      _SmallIconBtn(
                        icon: lucide.Lucide.Plus,
                        onTap: () => _showAddEditDialog(context),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),

              if (phrases.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            lucide.Lucide.Zap,
                            size: 56,
                            color: cs.onSurface.withValues(alpha: 0.28),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            l10n.quickPhraseEmptyMessage,
                            style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.65),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverReorderableList(
                  itemCount: phrases.length,
                  itemBuilder: (context, index) {
                    final phrase = phrases[index];
                    return KeyedSubtree(
                      key: ValueKey('desktop-quick-phrase-${phrase.id}'),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ReorderableDragStartListener(
                          index: index,
                          child: _QuickPhraseCard(
                            phrase: phrase,
                            onTap: () =>
                                _showAddEditDialog(context, phrase: phrase),
                            onEdit: () =>
                                _showAddEditDialog(context, phrase: phrase),
                            onDelete: () async {
                              await context.read<QuickPhraseProvider>().delete(
                                phrase.id,
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                  onReorder: (oldIndex, newIndex) async {
                    if (newIndex > oldIndex) newIndex -= 1;
                    await context.read<QuickPhraseProvider>().reorderPhrases(
                      oldIndex: oldIndex,
                      newIndex: newIndex,
                      assistantId: null,
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAddEditDialog(
    BuildContext context, {
    QuickPhrase? phrase,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<QuickPhraseProvider>();
    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (ctx) => _QuickPhraseEditDialog(
        title: phrase == null
            ? l10n.quickPhraseAddTitle
            : l10n.quickPhraseEditTitle,
        initTitle: phrase?.title ?? '',
        initContent: phrase?.content ?? '',
      ),
    );
    if (result == null) return;
    final title = (result['title'] ?? '').trim();
    final content = (result['content'] ?? '').trim();
    if (title.isEmpty || content.isEmpty) return;

    if (phrase == null) {
      final newPhrase = QuickPhrase(
        id: const Uuid().v4(),
        title: title,
        content: content,
        isGlobal: true,
        assistantId: null,
      );
      await provider.add(newPhrase);
    } else {
      await provider.update(phrase.copyWith(title: title, content: content));
    }
  }
}

class _QuickPhraseCard extends StatefulWidget {
  const _QuickPhraseCard({
    required this.phrase,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });
  final QuickPhrase phrase;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  @override
  State<_QuickPhraseCard> createState() => _QuickPhraseCardState();
}

class _QuickPhraseCardState extends State<_QuickPhraseCard> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseBg = isDark
        ? Colors.white10
        : Colors.white.withValues(alpha: 0.96);
    final borderColor = _hover
        ? cs.primary.withValues(alpha: isDark ? 0.35 : 0.45)
        : cs.outlineVariant.withValues(alpha: isDark ? 0.12 : 0.08);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: baseBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 1.0),
          ),
          padding: const EdgeInsets.all(14),
          constraints: const BoxConstraints(minHeight: 64),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(lucide.Lucide.Zap, size: 20, color: cs.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.phrase.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.phrase.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurface.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _SmallIconBtn(
                icon: lucide.Lucide.Settings2,
                onTap: widget.onEdit,
              ),
              const SizedBox(width: 6),
              _SmallIconBtn(icon: lucide.Lucide.Trash2, onTap: widget.onDelete),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickPhraseEditDialog extends StatefulWidget {
  const _QuickPhraseEditDialog({
    required this.title,
    required this.initTitle,
    required this.initContent,
  });
  final String title;
  final String initTitle;
  final String initContent;
  @override
  State<_QuickPhraseEditDialog> createState() => _QuickPhraseEditDialogState();
}

class _QuickPhraseEditDialogState extends State<_QuickPhraseEditDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initTitle);
    _contentController = TextEditingController(text: widget.initContent);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Dialog(
      backgroundColor: cs.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 58),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _SmallIconBtn(
                        icon: lucide.Lucide.X,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _titleController,
                    decoration: _deskInputDecoration(
                      context,
                    ).copyWith(hintText: l10n.quickPhraseTitleLabel),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _contentController,
                    maxLines: 8,
                    decoration: _deskInputDecoration(
                      context,
                    ).copyWith(hintText: l10n.quickPhraseContentLabel),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: _DeskIosButton(
                label: l10n.quickPhraseSaveButton,
                filled: true,
                dense: true,
                onTap: () {
                  Navigator.of(context).pop({
                    'title': _titleController.text,
                    'content': _contentController.text,
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallIconBtn extends StatefulWidget {
  const _SmallIconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  State<_SmallIconBtn> createState() => _SmallIconBtnState();
}

class _SmallIconBtnState extends State<_SmallIconBtn> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = _hover
        ? (isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05))
        : Colors.transparent;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Icon(widget.icon, size: 18, color: cs.onSurface),
        ),
      ),
    );
  }
}

class _DeskIosButton extends StatefulWidget {
  const _DeskIosButton({
    required this.label,
    required this.filled,
    required this.dense,
    required this.onTap,
  });
  final String label;
  final bool filled;
  final bool dense;
  final VoidCallback onTap;
  @override
  State<_DeskIosButton> createState() => _DeskIosButtonState();
}

class _DeskIosButtonState extends State<_DeskIosButton> {
  bool _hover = false;
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = widget.filled
        ? cs.onPrimary
        : cs.onSurface.withValues(alpha: 0.9);
    final bg = widget.filled
        ? (_hover ? cs.primary.withValues(alpha: 0.92) : cs.primary)
        : (_hover
              ? (isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.05))
              : Colors.transparent);
    final borderColor = widget.filled
        ? Colors.transparent
        : cs.outlineVariant.withValues(alpha: isDark ? 0.22 : 0.18);
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
          scale: _pressed ? 0.98 : 1.0,
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

InputDecoration _deskInputDecoration(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final cs = Theme.of(context).colorScheme;
  return InputDecoration(
    isDense: false,
    filled: true,
    fillColor: isDark ? Colors.white10 : const Color(0xFFF7F7F9),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: cs.outlineVariant.withValues(alpha: 0.2),
        width: 0.8,
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: cs.outlineVariant.withValues(alpha: 0.2),
        width: 0.8,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: cs.primary.withValues(alpha: 0.45),
        width: 1.0,
      ),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );
}
