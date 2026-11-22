import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/world_book_provider.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/group_picker.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../shared/widgets/text_input_dialog.dart';

Future<String?> promptWorldBookGroupName(
  BuildContext context, {
  String? groupId,
}) {
  final provider = context.read<WorldBookProvider>();
  final l10n = AppLocalizations.of(context)!;
  return showDialog<String>(
    context: context,
    builder: (_) => TextInputDialog(
      title: groupId == null
          ? l10n.worldBookGroupNew
          : l10n.worldBookGroupRename,
      hint: l10n.worldBookGroupName,
      initialValue: provider.groups[groupId] ?? '',
      cancelLabel: l10n.worldBookCancel,
      submitLabel: l10n.worldBookSave,
      invalidMessage: l10n.worldBookGroupNameInvalid,
      valid: (value) => provider.isGroupNameAvailable(value, exceptId: groupId),
    ),
  );
}

Future<GroupChoice?> chooseWorldBookGroup(
  BuildContext context, {
  required bool desktop,
  GroupChoice? selected,
  bool moving = false,
}) {
  final l10n = AppLocalizations.of(context)!;
  return showGroupPicker(
    context,
    title: moving ? l10n.worldBookGroupMove : l10n.worldBookGroupLabel,
    ungroupedLabel: l10n.worldBookGroupUngrouped,
    createLabel: l10n.worldBookGroupNew,
    groups: (context) => context.watch<WorldBookProvider>().groups,
    errorMessage: (_) => l10n.worldBookGroupSaveFailed,
    selected: selected,
    desktop: desktop,
    createGroup: (context) async {
      final provider = context.read<WorldBookProvider>();
      final name = await promptWorldBookGroupName(context);
      if (name == null ||
          !context.mounted ||
          ModalRoute.isCurrentOf(context) != true) {
        return null;
      }
      return provider.createGroup(name);
    },
  );
}

Future<void> moveWorldBookToGroup(
  BuildContext context,
  String bookId, {
  required bool desktop,
}) async {
  final provider = context.read<WorldBookProvider>();
  final destination = await chooseWorldBookGroup(
    context,
    desktop: desktop,
    moving: true,
    selected: (groupId: provider.groupIdForBook(bookId)),
  );
  if (!context.mounted || destination == null) return;
  try {
    await provider.moveBooksToGroup({bookId}, destination.groupId);
  } catch (_) {
    if (context.mounted) {
      showAppSnackBar(
        context,
        message: AppLocalizations.of(context)!.worldBookGroupSaveFailed,
        type: NotificationType.error,
      );
    }
  }
}

class WorldBookGroupButton extends StatelessWidget {
  const WorldBookGroupButton({
    super.key,
    required this.desktop,
    required this.onPressed,
  });

  final bool desktop;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IosIconButton(
    icon: Lucide.FolderInput,
    size: 16,
    minSize: desktop ? 32 : 44,
    tooltip: AppLocalizations.of(context)!.worldBookGroupMove,
    onTap: onPressed,
  );
}
