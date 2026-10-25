import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/mcp_provider.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/ios_text_button.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/snackbar.dart';
import 'mcp_form.dart';
import 'mcp_text_dialog.dart';

/// A record distinguishes choosing Ungrouped from dismissing the picker.
Future<({String? groupId})?> showMcpGroupPicker(
  BuildContext context, {
  String? selectedGroupId,
  bool? desktop,
}) => showMcpForm<({String? groupId})>(
  context,
  desktop: desktop,
  builder: (_) =>
      _GroupPicker(selectedGroupId: selectedGroupId, desktop: desktop),
);

class _GroupPicker extends StatefulWidget {
  const _GroupPicker({this.selectedGroupId, this.desktop});
  final String? selectedGroupId;
  final bool? desktop;

  @override
  State<_GroupPicker> createState() => _GroupPickerState();
}

class _GroupPickerState extends State<_GroupPicker> {
  bool _creating = false;

  Future<void> _createGroup() async {
    if (_creating) return;
    final route = ModalRoute.of(context);
    final mcp = context.read<McpProvider>();
    final l10n = AppLocalizations.of(context)!;
    setState(() => _creating = true);
    try {
      final name = await showDialog<String>(
        context: context,
        builder: (_) => McpTextDialog(
          title: l10n.providerGroupsCreateDialogTitle,
          hint: l10n.providerGroupsNameHint,
          submitLabel: l10n.providerGroupsCreateDialogOk,
          invalidMessage: l10n.mcpGroupNameInvalid,
          valid: (value) =>
              value.isNotEmpty &&
              !mcp.groups.any(
                (g) => g.name.toLowerCase() == value.toLowerCase(),
              ),
        ),
      );
      if (name == null || !mounted || route?.isCurrent != true) return;
      final id = await mcp.createGroup(name);
      // A dismissed picker stays mounted during its reverse animation.
      // A late save must not pop the editor underneath it.
      if (mounted && route?.isCurrent == true) {
        Navigator.of(context).pop((groupId: id));
      }
    } catch (error) {
      if (mounted && route?.isCurrent == true) {
        showAppSnackBar(
          context,
          message: error.toString(),
          type: NotificationType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mcp = context.watch<McpProvider>();
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return McpForm(
      title: l10n.providerGroupsPickerTitle,
      desktop: widget.desktop,
      children: [
        for (final group in [
          (id: null, name: l10n.providerGroupsOtherUngroupedOption),
          ...mcp.groups.map((g) => (id: g.id, name: g.name)),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: IosCardPress(
              focusable: true,
              key: ValueKey('mcp-group-option-${group.id ?? 'other'}'),
              baseColor: sheetTileColor(context),
              onTap: _creating
                  ? null
                  : () => Navigator.of(context).pop((groupId: group.id)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    Lucide.Folder,
                    size: 18,
                    color: cs.onSurface.withValues(alpha: .5),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      group.name,
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                  if (widget.selectedGroupId == group.id)
                    Icon(Lucide.Check, size: 18, color: cs.primary),
                ],
              ),
            ),
          ),
        IosTextButton(
          icon: Lucide.Plus,
          label: l10n.providerGroupsCreateNewGroupAction,
          onPressed: _creating ? null : _createGroup,
        ),
      ],
    );
  }
}
