import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../core/services/backup/import_toolbox.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/snackbar.dart';
import '../../utils/url_launcher_ext.dart';

Future<void> openImportToolbox(BuildContext context) async {
  if (await context.openUrl(importToolboxUrl) || !context.mounted) return;
  final l10n = AppLocalizations.of(context)!;
  showAppSnackBar(
    context,
    message: l10n.backupPageImportToolboxOpenFailed(importToolboxUrl),
    type: NotificationType.error,
    duration: const Duration(seconds: 8),
    actionLabel: l10n.browserCopyLink,
    onAction: () =>
        Clipboard.setData(const ClipboardData(text: importToolboxUrl)),
  );
}
