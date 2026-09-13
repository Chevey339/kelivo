import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/mcp_provider.dart';
import '../../../core/providers/workspace_provider.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_settings_rows.dart';
import '../../../shared/widgets/section_card.dart';
import '../../workspace/widgets/workspace_picker.dart';

class McpWorkspaceBindingField extends StatelessWidget {
  const McpWorkspaceBindingField({
    super.key,
    required this.workspaceId,
    required this.onChanged,
  });

  final String? workspaceId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final supported = context
        .watch<McpProvider>()
        .supportsStdioWorkspaceBinding;
    if (!supported && workspaceId == null) return const SizedBox.shrink();
    final workspaces = context.watch<WorkspaceProvider?>();
    final workspace = workspaceId == null
        ? null
        : workspaces?.byId(workspaceId!);
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionCard(
          children: [
            IosNavRow(
              key: const ValueKey('mcp-workspace-binding'),
              icon: Lucide.FolderCode,
              label: l10n.mcpWorkspaceBindingLabel,
              subtitle:
                  workspace?.name ??
                  (workspaceId == null
                      ? l10n.workspaceEntryNone
                      : l10n.workspaceFilesMissingWorkspace),
              onTap: !supported
                  ? null
                  : () async {
                      await workspaces!.loaded;
                      if (!context.mounted) return;
                      final chosen = await pickWorkspaceForConversation(
                        context,
                        selectedId: workspaceId,
                      );
                      if (context.mounted && chosen != null) {
                        onChanged(chosen.id);
                      }
                    },
            ),
            if (workspaceId != null)
              IosNavRow(
                key: const ValueKey('mcp-workspace-unbind'),
                icon: Lucide.Unlink,
                label: l10n.workspaceEntryUnbind,
                onTap: () => onChanged(null),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          supported
              ? l10n.mcpWorkspaceBindingHint
              : l10n.mcpWorkspaceBindingMobileOnly,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}
