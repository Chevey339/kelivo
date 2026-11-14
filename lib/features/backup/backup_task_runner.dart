import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../../core/providers/external_backup_auto_provider.dart';
import '../../core/services/backup/backup_activity.dart';
import '../../l10n/app_localizations.dart';
import 'widgets/backup_encryption_tile.dart';
import '../../shared/widgets/snackbar.dart';
import 'backup_restore_error_message.dart';
import 'widgets/backup_progress_dialog.dart';

Future<bool> runBackupTask(
  BuildContext context, {
  required String title,
  required Future<void> Function(BackupTaskHandle handle) task,
  String Function(Object error)? errorMessage,
  Future<void> Function()? onSuccess,
  String? backgroundLabel,
  String? backgroundedMessage,
  Future<void> Function(BackupTaskResult<void> result, bool detached)?
  onSettled,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final result = await showBackupProgressDialog<void>(
    context,
    title: title,
    task: task,
    backgroundLabel: backgroundLabel,
    onSettled: onSettled,
    errorMessage: errorMessage,
  );
  if (!context.mounted) return false;
  if (result.backgrounded) {
    // The work continues; the caller stops here because it no longer has an
    // outcome to act on.
    if (backgroundedMessage != null) {
      showAppSnackBar(
        context,
        message: backgroundedMessage,
        type: NotificationType.info,
      );
    }
    return false;
  }
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

Future<void> runExternalBackup(
  BuildContext context,
  BackupDestination target,
) async {
  final auto = context.read<ExternalBackupAutoProvider>();
  if (BackupActivity.isActive || auto.busy) {
    showAppSnackBar(
      context,
      message: AppLocalizations.of(context)!.localSnapshotBusyMessage,
      type: NotificationType.info,
    );
    return;
  }
  final root = Navigator.of(context, rootNavigator: true);
  final l10n = AppLocalizations.of(context)!;
  final local = target == BackupDestination.local;
  await runBackupTask(
    context,
    title: local ? l10n.backupAutoLocalNow : l10n.backupPageBackupNow,
    backgroundLabel: l10n.localSnapshotRunInBackground,
    backgroundedMessage: l10n.backupRunningInBackground,
    task: (handle) => auto.run(
      target,
      password: () => backupPasswordForExport(context),
      token: handle.cancelToken,
      onProgress: handle.report,
    ),
    onSettled: (result, detached) async {
      final overlay = root.overlay;
      if (overlay == null || !overlay.mounted) return;
      if (result.isSuccess) {
        showAppSnackBar(
          overlay.context,
          message: local
              ? l10n.backupAutoSucceeded
              : l10n.backupPageBackupUploaded,
          type: NotificationType.success,
        );
      } else if (detached) {
        showAppSnackBar(
          overlay.context,
          message: result.cancelled
              ? l10n.backupProgressCancelled
              : l10n.backupBackgroundFailed(
                  backupRestoreErrorMessage(l10n, result.error!),
                ),
          type: result.cancelled
              ? NotificationType.info
              : NotificationType.error,
        );
      }
    },
  );
}
