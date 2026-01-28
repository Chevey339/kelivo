import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

class FileDuplicateDialog {
  static Future<bool> show(BuildContext context, String fileName) async {
    final l10n = AppLocalizations.of(context)!;
    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.fileUploadDuplicateTitle),
        content: Text(l10n.fileUploadDuplicateContent(fileName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.fileUploadDuplicateUseExisting),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.fileUploadDuplicateUploadNew),
          ),
        ],
      ),
    );
    return res == true;
  }
}
