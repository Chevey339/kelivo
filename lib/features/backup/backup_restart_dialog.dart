import 'package:flutter/material.dart';

import '../../icons/lucide_adapter.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/ios_tile_button.dart';
import '../../shared/widgets/restart_app_action.dart';
import '../../theme/app_font_weights.dart';
import '../../utils/platform_utils.dart';
import '../settings/widgets/custom_theme_widgets.dart';

Future<void> showBackupRestartRequiredDialog(
  BuildContext context, {
  int skippedConversations = 0,
  String? details,
}) {
  final l10n = AppLocalizations.of(context)!;
  final content = skippedConversations > 0
      ? l10n.backupPageRestartContentWithSkipped(skippedConversations)
      : l10n.backupPageRestartContent;
  return showAppDialog<void>(
    context,
    dismissible: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.backupPageRestartRequired,
            style: TextStyle(fontSize: 16, fontWeight: AppFontWeights.emphasis),
          ),
          const SizedBox(height: 10),
          Text(
            details == null ? content : '$details\n\n$content',
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 16),
          IosTileButton(
            icon: Lucide.Check,
            label: l10n.backupPageOK,
            onTap: () async {
              if (await requestAppRestart(context, PlatformUtils.restartApp) &&
                  context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
    ),
  );
}
