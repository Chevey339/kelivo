import 'package:flutter/material.dart';

import '../../core/database/chat_database_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/restart_app_action.dart';
import '../../utils/platform_utils.dart';

String backupRestartDialogContent(
  AppLocalizations l10n, {
  BackupMergeReport? mergeReport,
}) {
  if (mergeReport == null) return l10n.backupPageRestartContent;
  final summary = l10n.backupPageMergeReportSummary(
    mergeReport.importedConversations,
    mergeReport.deduplicatedConversations,
    mergeReport.remappedConversations,
  );
  return '$summary\n\n${l10n.backupPageRestartContent}';
}

Future<void> showBackupRestartRequiredDialog(
  BuildContext context, {
  BackupMergeReport? mergeReport,
}) {
  final l10n = AppLocalizations.of(context)!;
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Theme.of(dialogContext).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(l10n.backupPageRestartRequired),
      content: Text(backupRestartDialogContent(l10n, mergeReport: mergeReport)),
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
