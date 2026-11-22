import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/mcp_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/group_picker.dart';
import '../../../shared/widgets/text_input_dialog.dart';

Future<GroupChoice?> showMcpGroupPicker(
  BuildContext context, {
  String? selectedGroupId,
  bool? desktop,
}) {
  final l10n = AppLocalizations.of(context)!;
  return showGroupPicker(
    context,
    title: l10n.providerGroupsPickerTitle,
    ungroupedLabel: l10n.providerGroupsOtherUngroupedOption,
    createLabel: l10n.providerGroupsCreateNewGroupAction,
    groups: (context) => {
      for (final group in context.watch<McpProvider>().groups)
        group.id: group.name,
    },
    selected: (groupId: selectedGroupId),
    desktop: desktop,
    createGroup: (context) async {
      final mcp = context.read<McpProvider>();
      final name = await showDialog<String>(
        context: context,
        builder: (_) => TextInputDialog(
          title: l10n.providerGroupsCreateDialogTitle,
          hint: l10n.providerGroupsNameHint,
          submitLabel: l10n.providerGroupsCreateDialogOk,
          cancelLabel: l10n.mcpPageCancel,
          invalidMessage: l10n.mcpGroupNameInvalid,
          valid: (value) =>
              value.isNotEmpty &&
              !mcp.groups.any(
                (group) => group.name.toLowerCase() == value.toLowerCase(),
              ),
        ),
      );
      if (name == null ||
          !context.mounted ||
          ModalRoute.isCurrentOf(context) != true) {
        return null;
      }
      return mcp.createGroup(name);
    },
  );
}
