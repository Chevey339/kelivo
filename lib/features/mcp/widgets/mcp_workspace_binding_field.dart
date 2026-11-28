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
    required this.followConversation,
    required this.onFollowChanged,
  });

  final String? workspaceId;
  final bool followConversation;
  final ValueChanged<bool> onFollowChanged;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final supported = context
        .watch<McpProvider>()
        .supportsStdioWorkspaceBinding;
    if (!supported && workspaceId == null && !followConversation) {
      return const SizedBox.shrink();
    }
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
            if (!followConversation)
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
            if (!followConversation && workspaceId != null)
              IosNavRow(
                key: const ValueKey('mcp-workspace-unbind'),
                icon: Lucide.Unlink,
                label: l10n.workspaceEntryUnbind,
                onTap: () => onChanged(null),
              ),
            if (supported || followConversation)
              IosSwitchRow(
                key: const ValueKey('mcp-follow-workspace'),
                label: l10n.mcpFollowConversationWorkspace,
                value: followConversation,
                onChanged: onFollowChanged,
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          !supported
              ? l10n.mcpWorkspaceBindingMobileOnly
              : followConversation
              ? l10n.mcpFollowConversationWorkspaceHint(
                  McpProvider.workspaceProcessLimit,
                )
              : l10n.mcpWorkspaceBindingHint,
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
