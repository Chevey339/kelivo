import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../utils/platform_utils.dart';

Future<void> showRestartRequiredDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final cs = Theme.of(context).colorScheme;
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dctx) => AlertDialog(
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(l10n.backupPageRestartRequired),
      content: Text(l10n.backupPageRestartContent),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(dctx).pop();
            PlatformUtils.restartApp();
          },
          child: Text(l10n.backupPageOK),
        ),
      ],
    ),
  );
}
