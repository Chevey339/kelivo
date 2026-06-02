import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../utils/provider_grouping_logic.dart';
import '../../../theme/app_font_weights.dart';

class ProviderGroupsPage extends StatefulWidget {
  const ProviderGroupsPage({super.key});

  @override
  State<ProviderGroupsPage> createState() => _ProviderGroupsPageState();
}

class _ProviderGroupsPageState extends State<ProviderGroupsPage> {
  Future<void> _createGroup() async {
    final l10n = AppLocalizations.of(context)!;
    final TextEditingController c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.providerGroupsCreateDialogTitle),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.providerGroupsNameHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.providerGroupsCreateDialogCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.providerGroupsCreateDialogOk),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (ok == true) {
      final name = c.text.trim();
      if (name.isEmpty) return;
      final id = await context.read<SettingsProvider>().createGroup(name);
      if (!mounted) return;
      if (id.isEmpty) {
        showAppSnackBar(
          context,
          message: l10n.providerGroupsCreateFailedToast,
          type: NotificationType.error,
        );
      }
    }
  }

  Future<void> _renameGroup(String groupId, String oldName) async {
    final l10n = AppLocalizations.of(context)!;
    final TextEditingController c = TextEditingController(text: oldName);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.providerDetailPageEditTooltip),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.providerGroupsNameHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.providerGroupsCreateDialogCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.sideDrawerSave),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (ok == true) {
      final name = c.text.trim();
      if (name.isEmpty) return;
      await context.read<SettingsProvider>().renameGroup(groupId, name);
    }
  }

  Future<void> _deleteGroup(String groupId) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.providerGroupsDeleteConfirmTitle),
        content: Text(l10n.providerGroupsDeleteConfirmContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.providerGroupsDeleteConfirmCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              l10n.providerGroupsDeleteConfirmOk,
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (ok == true) {
      await context.read<SettingsProvider>().deleteGroup(groupId);
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: l10n.providerGroupsDeletedToast,
        type: NotificationType.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    final groups = settings.providerGroups;
    final counts = <String, int>{};
    int ungroupedCount = 0;
    for (final key in settings.providersOrder) {
      final gid = settings.groupIdForProvider(key);
      if (gid == null) {
        ungroupedCount++;
      } else {
        counts[gid] = (counts[gid] ?? 0) + 1;
      }
    }
    final displayKeys = buildProviderGroupDisplayKeys(
      groups: groups,
      ungroupedIndex: settings.providerUngroupedDisplayIndex,
    );
    final displayRows = [
      for (final key in displayKeys)
        (
          key: key,
          title: key == SettingsProvider.providerUngroupedGroupKey
              ? l10n.providerGroupsOther
              : (settings.groupById(key)?.name ?? ''),
          count: key == SettingsProvider.providerUngroupedGroupKey
              ? ungroupedCount
              : (counts[key] ?? 0),
          isUngrouped: key == SettingsProvider.providerUngroupedGroupKey,
        ),
    ];

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
        title: Text(l10n.providerGroupsManageTitle),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IosIconButton(
              icon: Lucide.Plus,
              minSize: 44,
              onTap: _createGroup,
            ),
          ),
        ],
      ),
      body: displayRows.isEmpty
          ? Center(
              child: Text(
                l10n.providerGroupsEmptyState,
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              itemCount: displayRows.length,
              buildDefaultDragHandles: false,
              proxyDecorator: (child, index, animation) {
                return ScaleTransition(
                  scale: Tween<double>(
                    begin: 1.0,
                    end: 1.02,
                  ).animate(animation),
                  child: child,
                );
              },
              onReorder: (oldIndex, newIndex) async {
                await context
                    .read<SettingsProvider>()
                    .reorderProviderGroupsWithUngrouped(oldIndex, newIndex);
              },
              itemBuilder: (ctx, i) {
                final row = displayRows[i];
                return KeyedSubtree(
                  key: ValueKey('provider-group-${row.key}'),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ReorderableDelayedDragStartListener(
                      index: i,
                      child: _ProviderGroupCard(
                        title: row.title,
                        count: row.count,
                        onEdit: row.isUngrouped
                            ? null
                            : () => _renameGroup(row.key, row.title),
                        onDelete: row.isUngrouped
                            ? null
                            : () => _deleteGroup(row.key),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _ProviderGroupCard extends StatelessWidget {
  const _ProviderGroupCard({
    required this.title,
    required this.count,
    this.onEdit,
    this.onDelete,
  });
  final String title;
  final int count;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.white10 : const Color(0xFFF7F7F9);
    final borderColor = cs.outlineVariant.withValues(
      alpha: isDark ? 0.12 : 0.10,
    );
    final editAction = onEdit;
    final deleteAction = onDelete;
    return Container(
      decoration: BoxDecoration(
        color: bg,
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
              style: TextStyle(
                fontSize: 15,
                fontWeight: AppFontWeights.semibold,
              ),
            ),
          ),
          _CountPill(count: count),
          if (editAction != null) ...[
            const SizedBox(width: 10),
            IosCardPress(
              baseColor: Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              onTap: editAction,
              padding: const EdgeInsets.all(8),
              child: Icon(Lucide.Pencil, size: 18, color: cs.onSurface),
            ),
          ],
          if (deleteAction != null) ...[
            const SizedBox(width: 4),
            IosCardPress(
              baseColor: Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              onTap: deleteAction,
              padding: const EdgeInsets.all(8),
              child: Icon(Lucide.Trash2, size: 18, color: cs.error),
            ),
          ],
        ],
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = cs.primary.withValues(alpha: 0.12);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 12,
          color: cs.primary,
          fontWeight: AppFontWeights.emphasis,
        ),
      ),
    );
  }
}
