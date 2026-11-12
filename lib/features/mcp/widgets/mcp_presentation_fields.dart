import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/mcp_presentation.dart';
import '../../../core/providers/mcp_provider.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/section_card.dart';
import 'mcp_group_picker.dart';
import 'mcp_icon_picker.dart';
import 'mcp_server_avatar.dart';

/// Shared draft fields: no provider writes until the enclosing form is saved.
class McpPresentationFields extends StatelessWidget {
  const McpPresentationFields({
    super.key,
    this.server,
    this.icon,
    this.groupId,
    this.desktop = false,
    required this.onIconChanged,
    required this.onGroupChanged,
  });
  final McpServerConfig? server;
  final McpServerIcon? icon;
  final String? groupId;
  final bool desktop;
  final ValueChanged<McpServerIcon?> onIconChanged;
  final ValueChanged<String?> onGroupChanged;

  @override
  Widget build(BuildContext context) {
    final mcp = context.watch<McpProvider>();
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final group = mcp.groups.where((g) => g.id == groupId).firstOrNull;
    Widget row({
      required Key key,
      required Widget leading,
      required String label,
      String? value,
      required void Function(BuildContext) onTap,
    }) => Builder(
      builder: (rowContext) => IosCardPress(
        focusable: true,
        key: key,
        baseColor: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        onTap: () => onTap(rowContext),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 36),
          child: Row(
            children: [
              SizedBox(width: 36, child: Center(child: leading)),
              const SizedBox(width: 12),
              Text(label, style: TextStyle(fontSize: 14, color: cs.onSurface)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value ?? '',
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurface.withValues(alpha: .6),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Lucide.ChevronRight,
                size: 16,
                color: cs.onSurface.withValues(alpha: .35),
              ),
            ],
          ),
        ),
      ),
    );
    return SectionCard(
      padding: EdgeInsets.zero,
      children: [
        row(
          key: const ValueKey('mcp-edit-icon'),
          leading: McpServerAvatar(
            server:
                server ??
                McpServerConfig(
                  id: '',
                  name: 'MCP',
                  enabled: true,
                  transport: McpTransportType.http,
                  url: '',
                ),
            size: 32,
            radius: 9,
            customIcon: icon,
            useCustomIcon: true,
          ),
          label: l10n.mcpIconTitle,
          onTap: (ctx) => showMcpIconPicker(
            ctx,
            desktop: desktop,
            currentIcon: icon,
            onSelected: onIconChanged,
          ),
        ),
        row(
          key: const ValueKey('mcp-edit-group'),
          leading: Icon(
            Lucide.Folder,
            size: 20,
            color: cs.onSurface.withValues(alpha: .55),
          ),
          label: l10n.providerGroupsGroupLabel,
          value: group?.name ?? l10n.providerGroupsOtherUngroupedOption,
          onTap: (ctx) async {
            final result = await showMcpGroupPicker(
              ctx,
              selectedGroupId: groupId,
              desktop: desktop,
            );
            if (ctx.mounted && result != null) onGroupChanged(result.groupId);
          },
        ),
      ],
    );
  }
}
