import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../pages/provider_groups_page.dart';

Future<String?> showProviderGroupSelectSheet(
  BuildContext context, {
  required BuildContext rootContext,
}) async {
  final cs = Theme.of(context).colorScheme;
  return showModalBottomSheet<String?>(
    context: context,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) => ProviderGroupSelectSheet(rootContext: rootContext),
  );
}

class ProviderGroupSelectSheet extends StatelessWidget {
  const ProviderGroupSelectSheet({
    super.key,
    required this.rootContext,
  });

  final BuildContext rootContext;

  Future<void> _createGroup(BuildContext context, SettingsProvider sp) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.providerGroupsCreateDialogTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.providerGroupsNameHint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l10n.providerGroupsCreateDialogCancel)),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(l10n.providerGroupsCreateDialogOk)),
        ],
      ),
    );
    if (ok != true) return;
    final name = controller.text.trim();
    if (name.isEmpty) return;
    final id = await sp.createGroup(name);
    if (id.isEmpty) return;
    if (context.mounted) Navigator.of(context).pop(id);
  }

  Future<void> _openGroupManager(BuildContext context) async {
    if (context.mounted) Navigator.of(context).pop();
    await Navigator.of(rootContext).push(
      MaterialPageRoute(builder: (_) => const ProviderGroupsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final sp = context.watch<SettingsProvider>();
    final groups = sp.providerGroups;

    Widget tile({
      required String title,
      required VoidCallback onTap,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: SizedBox(
          height: 48,
          child: IosCardPress(
            borderRadius: BorderRadius.circular(14),
            baseColor: cs.surface,
            duration: const Duration(milliseconds: 260),
            onTap: onTap,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: cs.onSurface),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: cs.onSurface.withOpacity(0.2), borderRadius: BorderRadius.circular(999)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.providerGroupsPickerTitle,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                IosIconButton(
                  icon: Lucide.Plus,
                  minSize: 40,
                  size: 20,
                  semanticLabel: l10n.providerGroupsCreateNewGroupAction,
                  onTap: () => unawaited(_createGroup(context, sp)),
                ),
                IosIconButton(
                  icon: Lucide.Settings,
                  minSize: 40,
                  size: 20,
                  semanticLabel: l10n.providerGroupsManageAction,
                  onTap: () => unawaited(_openGroupManager(context)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                children: [
                  tile(
                    title: l10n.providerGroupsOtherUngroupedOption,
                    onTap: () => Navigator.of(context).pop(SettingsProvider.providerUngroupedGroupKey),
                  ),
                  for (final g in groups)
                    tile(
                      title: g.name,
                      onTap: () => Navigator.of(context).pop(g.id),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

