import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/snackbar.dart';

class ProviderGroupsPage extends StatefulWidget {
  const ProviderGroupsPage({super.key});

  @override
  State<ProviderGroupsPage> createState() => _ProviderGroupsPageState();
}

class _ProviderGroupsPageState extends State<ProviderGroupsPage> {
  Future<void> _createGroup(BuildContext context) async {
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
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l10n.providerGroupsCreateDialogCancel)),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(l10n.providerGroupsCreateDialogOk)),
        ],
      ),
    );
    if (ok == true) {
      final name = c.text.trim();
      if (name.isEmpty) return;
      final id = await context.read<SettingsProvider>().createGroup(name);
      if (id.isEmpty && mounted) {
        showAppSnackBar(context, message: l10n.providerGroupsCreateFailedToast, type: NotificationType.error);
      }
    }
  }

  Future<void> _renameGroup(BuildContext context, String groupId, String oldName) async {
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
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l10n.providerGroupsCreateDialogCancel)),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(l10n.sideDrawerSave)),
        ],
      ),
    );
    if (ok == true) {
      final name = c.text.trim();
      if (name.isEmpty) return;
      await context.read<SettingsProvider>().renameGroup(groupId, name);
    }
  }

  Future<void> _deleteGroup(BuildContext context, String groupId) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.providerGroupsDeleteConfirmTitle),
        content: Text(l10n.providerGroupsDeleteConfirmContent),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l10n.providerGroupsDeleteConfirmCancel)),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.providerGroupsDeleteConfirmOk, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await context.read<SettingsProvider>().deleteGroup(groupId);
      if (mounted) {
        showAppSnackBar(context, message: l10n.providerGroupsDeletedToast, type: NotificationType.success);
      }
    }
  }

  int _countProvidersInGroup(SettingsProvider settings, String groupId) {
    int count = 0;
    for (final k in settings.providersOrder) {
      if (settings.groupIdForProvider(k) == groupId) count++;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    final groups = settings.providerGroups;

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
              onTap: () => _createGroup(context),
            ),
          ),
        ],
      ),
      body: groups.isEmpty
          ? Center(
              child: Text(
                l10n.providerGroupsEmptyState,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
              ),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              itemCount: groups.length,
              buildDefaultDragHandles: false,
              proxyDecorator: (child, index, animation) {
                return ScaleTransition(scale: Tween<double>(begin: 1.0, end: 1.02).animate(animation), child: child);
              },
              onReorder: (oldIndex, newIndex) async {
                if (newIndex > oldIndex) newIndex -= 1;
                await context.read<SettingsProvider>().reorderProviderGroups(oldIndex, newIndex);
              },
              itemBuilder: (ctx, i) {
                final g = groups[i];
                final count = _countProvidersInGroup(settings, g.id);
                return KeyedSubtree(
                  key: ValueKey('provider-group-${g.id}'),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ReorderableDelayedDragStartListener(
                      index: i,
                      child: _ProviderGroupCard(
                        title: g.name,
                        count: count,
                        onEdit: () => _renameGroup(context, g.id, g.name),
                        onDelete: () => _deleteGroup(context, g.id),
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
    required this.onEdit,
    required this.onDelete,
  });
  final String title;
  final int count;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.white10 : const Color(0xFFF7F7F9);
    final borderColor = cs.outlineVariant.withOpacity(isDark ? 0.12 : 0.10);
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
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          _CountPill(count: count),
          const SizedBox(width: 10),
          IosCardPress(
            baseColor: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            onTap: onEdit,
            padding: const EdgeInsets.all(8),
            child: Icon(Lucide.Pencil, size: 18, color: cs.onSurface),
          ),
          const SizedBox(width: 4),
          IosCardPress(
            baseColor: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            onTap: onDelete,
            padding: const EdgeInsets.all(8),
            child: Icon(Lucide.Trash2, size: 18, color: cs.error),
          ),
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
    final bg = cs.primary.withOpacity(0.12);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        '$count',
        style: TextStyle(fontSize: 12, color: cs.primary, fontWeight: FontWeight.w700),
      ),
    );
  }
}
