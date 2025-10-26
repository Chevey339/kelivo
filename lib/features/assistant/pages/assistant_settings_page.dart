import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../theme/design_tokens.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../core/models/assistant.dart';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:characters/characters.dart';
import 'assistant_settings_edit_page.dart';
import '../../../utils/avatar_cache.dart';
import '../../../utils/sandbox_path_resolver.dart';
import '../../../core/services/haptics.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class AssistantSettingsPage extends StatelessWidget {
  const AssistantSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    final assistants = context.watch<AssistantProvider>().assistants;

    return Scaffold(
      appBar: AppBar(
        leading: Tooltip(
          message: l10n.settingsPageBackButton,
          child: _TactileIconButton(
            icon: Lucide.ArrowLeft,
            color: cs.onSurface,
            size: 22,
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
        title: Text(l10n.assistantSettingsPageTitle),
        actions: [
          Tooltip(
            message: l10n.assistantSettingsAddSheetSave,
            child: _TactileIconButton(
              icon: Lucide.Plus,
              color: cs.onSurface,
              size: 22,
              onTap: () async {
                final name = await _showAddAssistantSheet(context);
                if (name == null) return;
                final id = await context.read<AssistantProvider>().addAssistant(name: name.trim(), context: context);
                if (!context.mounted) return;
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => AssistantSettingsEditPage(assistantId: id)),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ReorderableListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
        itemCount: assistants.length,
        onReorder: (oldIndex, newIndex) async {
          if (newIndex > oldIndex) newIndex -= 1;
          // Immediately update UI for smooth experience
          final assistantProvider = context.read<AssistantProvider>();
          await assistantProvider.reorderAssistants(oldIndex, newIndex);
        },
        proxyDecorator: (child, index, animation) {
          return AnimatedBuilder(
            animation: animation,
            builder: (context, _) {
              final t = Curves.easeOutBack.transform(animation.value);
              return Transform.scale(
                scale: 0.98 + 0.02 * t,
                child: Material(
                  elevation: 0, // remove drag shadow
                  shadowColor: Colors.transparent,
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  child: child,
                ),
              );
            },
          );
        },
        itemBuilder: (context, index) {
          final item = assistants[index];
          return KeyedSubtree(
            key: ValueKey('reorder-assistant-${item.id}'),
            child: ReorderableDelayedDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AssistantCard(item: item),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AssistantCard extends StatelessWidget {
  const _AssistantCard({required this.item});
  final Assistant item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final baseBg = isDark ? Colors.white10 : Colors.white.withOpacity(0.96);
    final content = _TactileCard(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => AssistantSettingsEditPage(assistantId: item.id)),
        );
      },
      builder: (pressed, overlay) {
        return Container(
          decoration: BoxDecoration(
            color: Color.alphaBlend(overlay, baseBg),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(isDark ? 0.12 : 0.08), width: 0.8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AssistantAvatar(item: item, size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                ),
                              ),
                              if (!item.deletable)
                                _TagPill(text: l10n.assistantSettingsDefaultTag, color: cs.primary),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            (item.systemPrompt.trim().isEmpty
                                ? l10n.assistantSettingsNoPromptPlaceholder
                                : item.systemPrompt),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.7), height: 1.25),
                          ),
                        ],
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

    if (!item.deletable) return content;
    return Slidable(
      key: ValueKey('slidable-assistant-${item.id}'),
      endActionPane: ActionPane(
        motion: const StretchMotion(),
        extentRatio: 0.35,
        children: [
          CustomSlidableAction(
            autoClose: true,
            backgroundColor: Colors.transparent,
            onPressed: (_) async {
              final ok = await _confirmDelete(context, l10n);
              if (ok == true) {
                await context.read<AssistantProvider>().deleteAssistant(item.id);
              }
            },
            child: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                color: isDark
                    ? cs.error.withOpacity(0.22)
                    : cs.error.withOpacity(0.14),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.error.withOpacity(0.35)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              alignment: Alignment.center,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Lucide.Trash2, color: cs.error, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      l10n.assistantSettingsDeleteButton,
                      style: TextStyle(color: cs.error, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      child: content,
    );
  }

  String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final first = String.fromCharCode(trimmed.runes.first);
    return first.toUpperCase();
  }
}

// --- iOS-style tactile helpers ---

class _TactileIconButton extends StatefulWidget {
  const _TactileIconButton({required this.icon, required this.color, required this.onTap, this.onLongPress, this.semanticLabel, this.size = 22, this.haptics = true});
  final IconData icon; final Color color; final VoidCallback onTap; final VoidCallback? onLongPress; final String? semanticLabel; final double size; final bool haptics;
  @override State<_TactileIconButton> createState() => _TactileIconButtonState();
}

class _TactileIconButtonState extends State<_TactileIconButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final base = widget.color; final pressColor = base.withOpacity(0.7);
    final icon = Icon(widget.icon, size: widget.size, color: _pressed ? pressColor : base, semanticLabel: widget.semanticLabel);
    return Semantics(
      button: true, label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () { if (widget.haptics) Haptics.light(); widget.onTap(); },
        onLongPress: widget.onLongPress == null ? null : () { if (widget.haptics) Haptics.light(); widget.onLongPress!.call(); },
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6), child: icon),
      ),
    );
  }
}

class _TactileCard extends StatefulWidget {
  const _TactileCard({required this.builder, this.onTap, this.haptics = true, this.pressedScale = 0.98});
  final Widget Function(bool pressed, Color overlay) builder;
  final VoidCallback? onTap;
  final bool haptics;
  final double pressedScale;
  @override
  State<_TactileCard> createState() => _TactileCardState();
}

class _TactileCardState extends State<_TactileCard> {
  bool _pressed = false;
  void _set(bool v){ if (_pressed!=v) setState(()=>_pressed=v);} 
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlay = _pressed
        ? (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04))
        : Colors.transparent;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap==null?null:(_)=>_set(true),
      onTapUp: widget.onTap==null?null:(_)=>_set(false),
      onTapCancel: widget.onTap==null?null:()=>_set(false),
      onTap: widget.onTap==null?null:(){
        if(widget.haptics && context.read<SettingsProvider>().hapticsOnCardTap) Haptics.soft();
        widget.onTap!.call();
      },
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: widget.builder(_pressed, overlay),
        ),
      ),
    );
  }
}

Future<String?> _showAddAssistantSheet(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final controller = TextEditingController();
  String? result;
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
      return SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(left: 16, right: 16, top: 12, bottom: bottomInset + 16),
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
                  l10n.assistantSettingsAddSheetTitle,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.assistantSettingsAddSheetHint,
                  filled: true,
                  fillColor: isDark ? Colors.white10 : const Color(0xFFF2F3F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.4)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.4)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: cs.primary.withOpacity(0.5)),
                  ),
                ),
                onSubmitted: (_) => Navigator.of(ctx).pop(controller.text.trim()),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _IosOutlineButton(
                      label: l10n.assistantSettingsAddSheetCancel,
                      onTap: () => Navigator.of(ctx).pop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _IosFilledButton(
                      label: l10n.assistantSettingsAddSheetSave,
                      onTap: () => Navigator.of(ctx).pop(controller.text.trim()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  ).then((val) => result = val as String?);
  final trimmed = (result ?? '').trim();
  if (trimmed.isEmpty) return null;
  return trimmed;
}

Future<bool?> _confirmDelete(BuildContext context, AppLocalizations l10n) async {
  return showDialog<bool>(
    context: context,
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      return AlertDialog(
        title: Text(l10n.assistantSettingsDeleteDialogTitle),
        content: Text(l10n.assistantSettingsDeleteDialogContent),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l10n.assistantSettingsDeleteDialogCancel)),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.assistantSettingsDeleteDialogConfirm, style: TextStyle(color: cs.error)),
          ),
        ],
      );
    },
  );
}

class _AssistantAvatar extends StatelessWidget {
  const _AssistantAvatar({required this.item, this.size = 40});
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
              if (p != null && !kIsWeb && File(p).existsSync()) {
              return ClipOval(
                child: Image(
                  image: FileImage(File(p)),
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                ),
              );
            }
              if (p != null && kIsWeb && p.startsWith('data:')) {
                return ClipOval(
                  child: Image.network(p, width: size, height: size, fit: BoxFit.cover),
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
        } else if (!kIsWeb && (av.startsWith('/') || av.contains(':'))) {
        final fixed = SandboxPathResolver.fix(av);
        return ClipOval(
          child: Image(
            image: FileImage(File(fixed)),
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        );
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
      child: Text(emoji.characters.take(1).toString(), style: TextStyle(fontSize: size * 0.5)),
    );
  }
}

class _IosOutlineButton extends StatefulWidget {
  const _IosOutlineButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  State<_IosOutlineButton> createState() => _IosOutlineButtonState();
}

class _IosOutlineButtonState extends State<_IosOutlineButton> {
  bool _pressed = false;
  void _set(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => Future.delayed(const Duration(milliseconds: 80), () => _set(false)),
      onTapCancel: () => _set(false),
      onTap: () { Haptics.soft(); widget.onTap(); },
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
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
  final String label;
  final VoidCallback onTap;
  @override
  State<_IosFilledButton> createState() => _IosFilledButtonState();
}

class _IosFilledButtonState extends State<_IosFilledButton> {
  bool _pressed = false;
  void _set(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => Future.delayed(const Duration(milliseconds: 80), () => _set(false)),
      onTapCancel: () => _set(false),
      onTap: () { Haptics.soft(); widget.onTap(); },
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
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

class _TagPill extends StatelessWidget {
  const _TagPill({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
