import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/workspace.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/workspace_provider.dart';
import 'package:Kelivo/features/workspace/pages/workspaces_page.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_settings_rows.dart';
import 'package:Kelivo/shared/widgets/ios_tile_button.dart';
import 'package:Kelivo/shared/widgets/option_sheet.dart';
import 'package:Kelivo/shared/widgets/section_card.dart';

class AssistantSettingsEditWorkspaceTab extends StatelessWidget {
  const AssistantSettingsEditWorkspaceTab({
    super.key,
    required this.assistantId,
  });

  final String assistantId;

  static const Key defaultWorkspaceKey = ValueKey<String>(
    'assistant-edit-default-workspace',
  );
  static const Key manageKey = ValueKey<String>(
    'assistant-edit-manage-workspaces',
  );

  String _defaultWorkspaceLabel(BuildContext context, Assistant assistant) {
    final l10n = AppLocalizations.of(context)!;
    final id = assistant.defaultWorkspaceId;
    if (id == null || id.isEmpty) return l10n.workspaceEntryNone;
    try {
      final workspace = context.watch<WorkspaceProvider>().byId(id);
      if (workspace == null) return l10n.workspaceEntryNone;
      return workspace.name;
    } catch (_) {
      return l10n.workspaceEntryNone;
    }
  }

  Future<void> _pickDefaultWorkspace(
    BuildContext context,
    Assistant assistant,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    List<Workspace> workspaces = const <Workspace>[];
    try {
      workspaces = context.read<WorkspaceProvider>().workspaces;
    } catch (_) {}
    final currentId = assistant.defaultWorkspaceId ?? '';

    final selected = await showOptionSheet<String>(
      context,
      title: l10n.workspaceEntryDefaultWorkspace,
      selected: currentId,
      items: [
        OptionSheetItem<String>(
          value: '',
          icon: Lucide.Ban,
          label: l10n.workspaceEntryNone,
        ),
        for (final workspace in workspaces)
          OptionSheetItem<String>(
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
    );
    if (selected == null || !context.mounted) return;
    await context.read<AssistantProvider>().updateAssistant(
      assistant.copyWith(
        clearDefaultWorkspaceId: selected.isEmpty,
        defaultWorkspaceId: selected.isEmpty ? null : selected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final assistant = context.watch<AssistantProvider>().getById(assistantId);
    if (assistant == null) return const SizedBox.shrink();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      children: [
        SectionCard(
          children: [
            IosNavRow(
              key: defaultWorkspaceKey,
              icon: Lucide.FolderCode,
              label: l10n.workspaceEntryDefaultWorkspace,
              subtitle: l10n.workspaceEntryDefaultWorkspaceSubtitle,
              detailText: _defaultWorkspaceLabel(context, assistant),
              onTap: () => unawaited(_pickDefaultWorkspace(context, assistant)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        IosTileButton(
          key: manageKey,
          icon: Lucide.FolderOpen,
          label: l10n.workspaceEntryManage,
          onTap: () => unawaited(openWorkspacesPage(context)),
        ),
      ],
    );
  }
}
