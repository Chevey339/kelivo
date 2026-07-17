import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/widgets/restart_app_action.dart';
import '../../utils/platform_utils.dart';

Future<void> showBackupRestartRequiredDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Theme.of(dialogContext).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(l10n.backupPageRestartRequired),
      content: Text(l10n.backupPageRestartContent),
      actions: [
        TextButton(
          onPressed: () async {
            if (await requestAppRestart(
                  dialogContext,
                  PlatformUtils.restartApp,
                ) &&
                dialogContext.mounted) {
              Navigator.of(dialogContext).pop();
            }
          },
          child: Text(l10n.backupPageOK),
        ),
      ],
    ),
  );
}
