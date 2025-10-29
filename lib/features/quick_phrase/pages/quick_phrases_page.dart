import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/design_tokens.dart';
import '../../../core/models/quick_phrase.dart';
import '../../../core/providers/quick_phrase_provider.dart';
import 'package:uuid/uuid.dart';
import '../../../core/services/haptics.dart';

class QuickPhrasesPage extends StatefulWidget {
  const QuickPhrasesPage({super.key, this.assistantId, this.embedded = false});

  final String?
  assistantId; // null = global phrases, non-null = assistant-specific

  /// Whether this page is embedded in a desktop settings layout (no Scaffold/AppBar)
  final bool embedded;

  @override
  State<QuickPhrasesPage> createState() => _QuickPhrasesPageState();
}

class _QuickPhrasesPageState extends State<QuickPhrasesPage> {
  @override
  void initState() {
    super.initState();
    // Provider will handle loading
  }

  Future<void> _showAddEditSheet({QuickPhrase? phrase}) async {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final result = await showModalBottomSheet<Map<String, String>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return _QuickPhraseEditSheet(
          phrase: phrase,
          assistantId: widget.assistantId,
        );
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
          isGlobal: widget.assistantId == null,
          assistantId: widget.assistantId,
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

  Future<void> _deletePhrase(QuickPhrase phrase) async {
    await context.read<QuickPhraseProvider>().delete(phrase.id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final quickPhraseProvider = context.watch<QuickPhraseProvider>();
    final phrases = widget.assistantId == null
        ? quickPhraseProvider.globalPhrases
        : quickPhraseProvider.getForAssistant(widget.assistantId!);

    final bodyContent = phrases.isEmpty
        ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Lucide.Zap,
                    size: 64,
                    color: cs.onSurface.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.quickPhraseEmptyMessage,
                    style: TextStyle(
                      color: cs.onSurface.withOpacity(0.6),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: phrases.length,
              buildDefaultDragHandles: false,
              proxyDecorator: (child, index, animation) {
                // Smooth scale, no shadow/elevation
                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, _) {
                    final t = Curves.easeOut.transform(animation.value);
                    return Transform.scale(
                      scale: 0.98 + 0.02 * t,
                      child: child,
                    );
                  },
                );
              },
              onReorder: (oldIndex, newIndex) {
                if (newIndex > oldIndex) newIndex -= 1;
                // Update immediately for smooth drop animation
                context.read<QuickPhraseProvider>().reorderPhrases(
                      oldIndex: oldIndex,
                      newIndex: newIndex,
                      assistantId: widget.assistantId,
                    );
              },
              itemBuilder: (context, index) {
                final phrase = phrases[index];
                return KeyedSubtree(
                  key: ValueKey('reorder-quick-phrase-${phrase.id}'),
                  child: ReorderableDelayedDragStartListener(
                    index: index,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
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
                              onPressed: (_) => _deletePhrase(phrase),
                            ),
                          ],
                        ),
                        child: _TactileCard(
                          pressedScale: 0.98,
                          onTap: () => _showAddEditSheet(phrase: phrase),
                          builder: (pressed, overlay) {
                            final baseBg = isDark ? Colors.white10 : Colors.white.withOpacity(0.96);
                            return Container(
                              decoration: BoxDecoration(
                                color: Color.alphaBlend(overlay, baseBg),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: cs.outlineVariant.withOpacity(isDark ? 0.1 : 0.08), width: 0.6),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Lucide.Zap, size: 18, color: cs.primary),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  phrase.title,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            phrase.content,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(Lucide.ChevronRight, size: 16, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
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
            );

    // If embedded, return body content directly without Scaffold
    if (widget.embedded) {
      return bodyContent;
    }

    // Otherwise, return full page with Scaffold and AppBar
    return Scaffold(
      appBar: AppBar(
        leading: Tooltip(
          message: l10n.quickPhraseBackTooltip,
          child: _TactileIconButton(
            icon: Lucide.ArrowLeft,
            color: Theme.of(context).colorScheme.onSurface,
            size: 22,
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
        title: Text(
          widget.assistantId == null
              ? l10n.quickPhraseGlobalTitle
              : l10n.quickPhraseAssistantTitle,
        ),
        actions: [
          Tooltip(
            message: l10n.quickPhraseAddTooltip,
            child: _TactileIconButton(
              icon: Lucide.Plus,
              color: Theme.of(context).colorScheme.onSurface,
              size: 22,
              onTap: () => _showAddEditSheet(),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: bodyContent,
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
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
                  child: _IosOutlineButton(
                    label: l10n.quickPhraseCancelButton,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _IosFilledButton(
                    label: l10n.quickPhraseSaveButton,
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
          ],
        ),
      ),
    );
  }
}

// --- iOS tactile helpers (no ripple) ---

class _TactileIconButton extends StatefulWidget {
  const _TactileIconButton({required this.icon, required this.color, required this.onTap, this.size = 22});
  final IconData icon; final Color color; final VoidCallback onTap; final double size;
  @override State<_TactileIconButton> createState() => _TactileIconButtonState();
}

class _TactileIconButtonState extends State<_TactileIconButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final base = widget.color; final press = base.withOpacity(0.7);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(()=>_pressed=true),
      onTapUp: (_) => setState(()=>_pressed=false),
      onTapCancel: () => setState(()=>_pressed=false),
      onTap: () { Haptics.light(); widget.onTap(); },
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(widget.icon, size: widget.size, color: _pressed ? press : base),
      ),
    );
  }
}

class _TactileCard extends StatefulWidget {
  const _TactileCard({required this.builder, this.onTap, this.pressedScale = 0.98});
  final Widget Function(bool pressed, Color overlay) builder; final VoidCallback? onTap; final double pressedScale;
  @override State<_TactileCard> createState() => _TactileCardState();
}

class _TactileCardState extends State<_TactileCard> {
  bool _pressed = false;
  void _set(bool v){ if(_pressed!=v) setState(()=>_pressed=v);} 
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlay = _pressed ? (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05)) : Colors.transparent;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap==null?null:(_)=>_set(true),
      onTapUp: widget.onTap==null?null:(_)=>Future.delayed(const Duration(milliseconds: 120), ()=>_set(false)),
      onTapCancel: widget.onTap==null?null:()=>_set(false),
      onTap: widget.onTap==null?null:(){ Haptics.soft(); widget.onTap!.call(); },
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: const Duration(milliseconds: 110), curve: Curves.easeOutCubic,
        child: widget.builder(_pressed, overlay),
      ),
    );
  }
}

class _IosOutlineButton extends StatefulWidget {
  const _IosOutlineButton({required this.label, required this.onTap});
  final String label; final VoidCallback onTap;
  @override
  State<_IosOutlineButton> createState() => _IosOutlineButtonState();
}

class _IosOutlineButtonState extends State<_IosOutlineButton> {
  bool _pressed = false;
  void _set(bool v){ if(_pressed!=v) setState(()=>_pressed=v);} 
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => Future.delayed(const Duration(milliseconds: 80), ()=>_set(false)),
      onTapCancel: () => _set(false),
      onTap: () { Haptics.soft(); widget.onTap(); },
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 110), curve: Curves.easeOutCubic,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.primary.withOpacity(0.5)),
          ),
          child: Text(widget.label, style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

class _IosFilledButton extends StatefulWidget {
  const _IosFilledButton({required this.label, required this.onTap});
  final String label; final VoidCallback onTap;
  @override
  State<_IosFilledButton> createState() => _IosFilledButtonState();
}

class _IosFilledButtonState extends State<_IosFilledButton> {
  bool _pressed = false;
  void _set(bool v){ if(_pressed!=v) setState(()=>_pressed=v);} 
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => Future.delayed(const Duration(milliseconds: 80), ()=>_set(false)),
      onTapCancel: () => _set(false),
      onTap: () { Haptics.soft(); widget.onTap(); },
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 110), curve: Curves.easeOutCubic,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(12)),
          child: Text(widget.label, style: TextStyle(color: cs.onPrimary, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
