import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/providers/workspace_provider.dart';
import 'package:Kelivo/core/services/workspace/workspace_tools_service.dart';
import 'package:Kelivo/features/chat/widgets/workspace_tool_ui.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_settings_rows.dart';
import 'package:Kelivo/shared/widgets/ios_switch.dart';
import 'package:Kelivo/shared/widgets/section_card.dart';
import 'package:Kelivo/shared/widgets/segmented_tabs.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';

class WorkspaceDetailTabs extends StatelessWidget {
  const WorkspaceDetailTabs({
    super.key,
    required this.index,
    required this.onChanged,
    this.desktop = false,
  });

  final int index;
  final ValueChanged<int> onChanged;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Align(
      alignment: Alignment.centerLeft,
      child: SegmentedTabs(
        key: const ValueKey('workspace-detail-tabs'),
        index: index,
        onChanged: onChanged,
        expand: !desktop,
        height: desktop ? 36 : 40,
        tabs: [
          SegmentedTab(label: l10n.workspaceEntryFiles, icon: Lucide.Folder),
          SegmentedTab(label: l10n.workspaceToolsTitle, icon: Lucide.Wrench),
        ],
      ),
    );
  }
}

class WorkspaceToolsPane extends StatefulWidget {
  const WorkspaceToolsPane({super.key, required this.workspaceId});

  final String workspaceId;

  static Key toggleKey(String name) => ValueKey('workspace-tool-toggle-$name');

  @override
  State<WorkspaceToolsPane> createState() => _WorkspaceToolsPaneState();
}

class _WorkspaceToolsPaneState extends State<WorkspaceToolsPane> {
  bool _saving = false;

  Future<void> _setEnabled(String name, bool enabled) async {
    if (_saving) return;
    final provider = context.read<WorkspaceProvider>();
    final workspace = provider.byId(widget.workspaceId);
    if (workspace == null) return;
    final disabled = {...workspace.disabledTools};
    enabled ? disabled.remove(name) : disabled.add(name);
    setState(() => _saving = true);
    try {
      await provider.update(workspace.copyWith(disabledTools: disabled));
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          message: AppLocalizations.of(context)!.workspaceFilesError,
          type: NotificationType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final workspace = context.watch<WorkspaceProvider>().byId(
      widget.workspaceId,
    );
    if (workspace == null) {
      return Center(child: Text(l10n.workspaceFilesMissingWorkspace));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        IosSectionFooter(text: l10n.workspaceToolsDescription),
        SectionCard(
          children: [
            for (final name in WorkspaceToolsService.toolNames) ...[
              if (name != WorkspaceToolsService.toolNames.first)
                const IosRowDivider(),
              IosNavRow(
                icon: workspaceToolIcon(name),
                label: workspaceToolTitle(l10n, name),
                subtitle: _description(l10n, name),
                trailing: IosSwitch(
                  key: WorkspaceToolsPane.toggleKey(name),
                  semanticLabel: workspaceToolTitle(l10n, name),
                  value: workspace.isToolEnabled(name),
                  onChanged: _saving
                      ? null
                      : (enabled) => unawaited(_setEnabled(name, enabled)),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  String _description(AppLocalizations l10n, String name) => switch (name) {
    'shell' => l10n.workspaceToolHelpShell,
    'read_file' => l10n.workspaceToolHelpRead,
    'write_file' => l10n.workspaceToolHelpWrite,
    'edit_file' => l10n.workspaceToolHelpEdit,
    'list_dir' => l10n.workspaceToolHelpList,
    'glob' => l10n.workspaceToolHelpGlob,
    'grep' => l10n.workspaceToolHelpGrep,
    _ => name,
  };
}
