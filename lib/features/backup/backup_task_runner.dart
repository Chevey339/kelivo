import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/widgets/snackbar.dart';
import 'backup_restore_error_message.dart';
import 'widgets/backup_progress_dialog.dart';

Future<bool> runBackupTask(
  BuildContext context, {
  required String title,
  required Future<void> Function(BackupTaskHandle handle) task,
  String Function(Object error)? errorMessage,
  Future<void> Function()? onSuccess,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final result = await showBackupProgressDialog<void>(
    context,
    title: title,
    task: task,
  );
  if (!context.mounted) return false;
  if (result.cancelled) {
    showAppSnackBar(
      context,
      message: l10n.backupProgressCancelled,
      type: NotificationType.info,
    );
    return false;
  }
  if (result.error != null) {
    showAppSnackBar(
      context,
      message:
          errorMessage?.call(result.error!) ??
          backupRestoreErrorMessage(l10n, result.error!),
      type: NotificationType.error,
    );
    return false;
  }
  if (onSuccess != null) {
    await onSuccess();
  }
  return true;
}
