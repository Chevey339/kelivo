import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/tag_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../icons/lucide_adapter.dart';

Future<void> showAssistantTagsManagerDialog(
  BuildContext context, {
  required String assistantId,
}) async {
  final cs = Theme.of(context).colorScheme;
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'tags-manager',
    barrierColor: Colors.black.withValues(alpha: 0.15),
    pageBuilder: (ctx, _, __) {
      // Use a full-screen tap area to allow closing by tapping outside the dialog.
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(ctx).maybePop(),
        child: Material(
          type: MaterialType.transparency,
          child: Center(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {}, // absorb taps inside the dialog
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 520,
                  maxHeight: 600,
                ),
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: Theme.of(ctx).colorScheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: Theme.of(ctx).brightness == Brightness.dark
                            ? Colors.white.withValues(alpha: 0.08)
                            : cs.outlineVariant.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                  child: _TagsManagerBody(
                    assistantId: assistantId,
                    isDialog: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
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

class _TagsManagerBody extends StatefulWidget {
  const _TagsManagerBody({required this.assistantId, required this.isDialog});
  final String assistantId;
  final bool isDialog;

  @override
  State<_TagsManagerBody> createState() => _TagsManagerBodyState();
}

class _TagsManagerBodyState extends State<_TagsManagerBody> {
  Future<void> _createTag(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final TextEditingController c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.assistantTagsCreateDialogTitle),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.assistantTagsNameHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.assistantTagsCreateDialogCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.assistantTagsCreateDialogOk),
          ),
        ],
      ),
    );
    if (ok == true) {
      final name = c.text.trim();
      if (name.isEmpty) return; // invalid; ignore silently in dialog
      if (!context.mounted) return;
      final tp = context.read<TagProvider>();
      // Prevent duplicates by name
      if (tp.tags.any((t) => t.name == name)) return;
      await tp.createTag(name);
    }
  }

  Future<void> _renameTag(
    BuildContext context,
    String tagId,
    String oldName,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final TextEditingController c = TextEditingController(text: oldName);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.assistantTagsRenameDialogTitle),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.assistantTagsNameHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.assistantTagsCreateDialogCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.assistantTagsRenameDialogOk),
          ),
        ],
      ),
    );
    if (ok == true) {
      final name = c.text.trim();
      if (name.isEmpty) return;
      if (!context.mounted) return;
      final tp = context.read<TagProvider>();
      if (tp.tags.any((t) => t.name == name && t.id != tagId)) return;
      await tp.renameTag(tagId, name);
    }
  }

  Future<void> _deleteTag(BuildContext context, String tagId) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.assistantTagsDeleteConfirmTitle),
        content: Text(l10n.assistantTagsDeleteConfirmContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.assistantTagsDeleteConfirmCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.assistantTagsDeleteConfirmOk),
          ),
        ],
      ),
    );
    if (ok == true) {
      if (!context.mounted) return;
      await context.read<TagProvider>().deleteTag(tagId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tp = context.watch<TagProvider>();
    final tags = tp.tags;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top bar without bottom divider; desktop small buttons, no ripples
        SizedBox(
          height: 48,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.assistantTagsManageTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _SmallIconBtn(
                  icon: Lucide.Plus,
                  onTap: () => _createTag(context),
                ),
                const SizedBox(width: 6),
                _SmallIconBtn(
                  icon: Lucide.X,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            itemCount: tags.length,
            buildDefaultDragHandles: false,
            proxyDecorator: (child, index, animation) {
              // No shadow/elevation while dragging; just return the card itself with subtle scale.
              return ScaleTransition(
                scale: Tween<double>(begin: 1.0, end: 1.02).animate(animation),
                child: child,
              );
            },
            onReorder: (oldIndex, newIndex) async {
              if (newIndex > oldIndex) newIndex -= 1;
              await context.read<TagProvider>().reorderTags(oldIndex, newIndex);
            },
            itemBuilder: (ctx, i) {
              final t = tags[i];
              return KeyedSubtree(
                key: ValueKey('tag-${t.id}'),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
                  child: ReorderableDragStartListener(
                    index: i,
                    child: _TagCard(
                      title: t.name,
                      onTap: () async {
                        await context.read<TagProvider>().assignAssistantToTag(
                          widget.assistantId,
                          t.id,
                        );
                        if (widget.isDialog && context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                      onRename: () => _renameTag(context, t.id, t.name),
                      onDelete: () => _deleteTag(context, t.id),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
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

class _TagCard extends StatefulWidget {
  const _TagCard({
    required this.title,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });
  final String title;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  @override
  State<_TagCard> createState() => _TagCardState();
}

class _TagCardState extends State<_TagCard> {
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
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1.0),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _SmallIconBtn(icon: Lucide.Pencil, onTap: widget.onRename),
              const SizedBox(width: 6),
              _SmallIconBtn(icon: Lucide.Trash2, onTap: widget.onDelete),
            ],
          ),
        ),
      ),
    );
  }
}
