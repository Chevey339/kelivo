import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/tag_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../shared/widgets/ios_tactile.dart';

class TagsManagerPage extends StatefulWidget {
  const TagsManagerPage({super.key, required this.assistantId});
  final String assistantId;

  @override
  State<TagsManagerPage> createState() => _TagsManagerPageState();
}

class _TagsManagerPageState extends State<TagsManagerPage> {
  Future<void> _createTag(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final tp = context.read<TagProvider>();
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
      if (!context.mounted) return;
      final name = c.text.trim();
      if (name.isEmpty) return;
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
    final tp = context.read<TagProvider>();
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
      if (!context.mounted) return;
      final name = c.text.trim();
      if (name.isEmpty) return;
      if (tp.tags.any((t) => t.name == name && t.id != tagId)) return;
      await tp.renameTag(tagId, name);
    }
  }

  Future<void> _deleteTag(BuildContext context, String tagId) async {
    final l10n = AppLocalizations.of(context)!;
    final tp = context.read<TagProvider>();
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
      await tp.deleteTag(tagId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tp = context.watch<TagProvider>();
    final tags = tp.tags;
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 52,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: IosIconButton(
            icon: Lucide.ChevronLeft,
            minSize: 44,
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
        title: Text(l10n.assistantTagsManageTitle),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IosIconButton(
              icon: Lucide.Plus,
              minSize: 44,
              onTap: () => _createTag(context),
            ),
          ),
        ],
      ),
      body: ReorderableListView.builder(
        itemCount: tags.length,
        buildDefaultDragHandles: false,
        proxyDecorator: (child, index, animation) {
          // No shadow during drag; slight scale only
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
            key: ValueKey('tag-mobile-${t.id}'),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
              child: ReorderableDelayedDragStartListener(
                index: i,
                child: _MobileTagCard(
                  title: t.name,
                  onTap: () async {
                    await context.read<TagProvider>().assignAssistantToTag(
                      widget.assistantId,
                      t.id,
                    );
                    if (!context.mounted) return;
                    Navigator.of(context).maybePop();
                  },
                  onRename: () => _renameTag(context, t.id, t.name),
                  onDelete: () => _deleteTag(context, t.id),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MobileTagCard extends StatelessWidget {
  const _MobileTagCard({
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
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.white10 : const Color(0xFFF7F7F9);
    final borderColor = cs.outlineVariant.withValues(
      alpha: isDark ? 0.12 : 0.10,
    );
    Widget iconBtn(IconData icon, VoidCallback onPressed, {Color? color}) {
      return IosCardPress(
        baseColor: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        onTap: onPressed,
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 18, color: color ?? cs.onSurface),
      );
    }

    return IosCardPress(
      baseColor: bg,
      borderRadius: BorderRadius.circular(14),
      pressedBlendStrength: 0.06,
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1.0),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            iconBtn(Lucide.Pencil, onRename),
            const SizedBox(width: 4),
            iconBtn(Lucide.Trash2, onDelete, color: cs.error),
          ],
        ),
      ),
    );
  }
}
