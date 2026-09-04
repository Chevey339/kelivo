import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/models/workspace.dart';
import 'package:Kelivo/core/providers/workspace_provider.dart';
import 'package:Kelivo/features/workspace/pages/workspaces_page.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_settings_rows.dart';
import 'package:Kelivo/shared/widgets/option_sheet.dart';
import 'package:Kelivo/shared/widgets/section_card.dart';
import 'package:Kelivo/theme/app_font_weights.dart';

const String kCreateWorkspacePickerValue = '__kelivo_create_workspace__';

/// Presents workspaces in [showOptionSheet] and returns the chosen
/// record, or a newly created workspace from the footer row.
Future<Workspace?> pickWorkspaceForConversation(
  BuildContext context, {
  String? selectedId,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final provider = context.read<WorkspaceProvider>();
  final sorted = List<Workspace>.from(provider.workspaces)
    ..sort((a, b) {
      final aUsed = a.lastUsedAt;
      final bUsed = b.lastUsedAt;
      if (aUsed == null && bUsed == null) {
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
      if (aUsed == null) return 1;
      if (bUsed == null) return -1;
      return bUsed.compareTo(aUsed);
    });

  final chosen = await showOptionSheet<String>(
    context,
    title: l10n.workspaceEntryBind,
    selected: selectedId,
    items: [
      for (final workspace in sorted)
        OptionSheetItem(
          key: ValueKey<String>('workspace-section-pick-${workspace.id}'),
          value: workspace.id,
          icon: workspace.kind == WorkspaceKind.linked
              ? Lucide.Link
              : Lucide.FolderCode,
          label: workspace.name,
          subtitle: workspace.kind == WorkspaceKind.linked
              ? l10n.workspaceFilesKindLinked
              : l10n.workspaceFilesKindManaged,
        ),
    ],
    footer: Builder(
      builder: (sheetCtx) {
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: SectionCard(
            children: [
              IosNavRow(
                key: const ValueKey<String>('workspace-section-create'),
                icon: Lucide.Plus,
                label: l10n.workspaceEntryCreate,
                labelWeight: AppFontWeights.medium,
                onTap: () =>
                    Navigator.of(sheetCtx).pop(kCreateWorkspacePickerValue),
              ),
            ],
          ),
        );
      },
    ),
  );
  if (!context.mounted || chosen == null) return null;
  if (chosen == kCreateWorkspacePickerValue) {
    return showCreateWorkspaceFlow(context);
  }
  return provider.byId(chosen);
}
