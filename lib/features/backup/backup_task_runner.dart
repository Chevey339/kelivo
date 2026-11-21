import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../../core/providers/backup_provider.dart';
import '../../core/providers/backup_reminder_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/services/backup/backup_cancel_token.dart';
import '../../core/services/backup/backup_file_export.dart';
import '../../core/services/backup/backup_task_progress.dart';
import '../../core/services/backup/data_sync.dart';
import '../../core/services/native_file_save.dart';
import '../../core/providers/external_backup_auto_provider.dart';
import '../../core/services/backup/backup_activity.dart';
import '../../l10n/app_localizations.dart';
import 'widgets/backup_encryption_tile.dart';
import '../../shared/widgets/snackbar.dart';
import 'backup_restore_error_message.dart';
import 'import_toolbox_link.dart';
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
    final failure = describeBackupTaskFailure(
      l10n,
      result.error!,
      errorMessage: errorMessage,
    );
    showAppSnackBar(
      context,
      message: failure.message,
      type: NotificationType.error,
      actionLabel: failure.showToolbox
          ? l10n.backupPageOpenImportToolbox
          : null,
      onAction: failure.showToolbox ? () => openImportToolbox(context) : null,
    );
    return false;
  }
  if (onSuccess != null) {
    await onSuccess();
  }
  return true;
}

Future<void> runLocalFileBackup(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final backup = context.read<BackupProvider>();
  final reminder = context.read<BackupReminderProvider>();
  final config = context.read<SettingsProvider>().webDavConfig;
  await runBackupTask(
    context,
    title: l10n.backupPageExportToFile,
    errorMessage: (error) => l10n.backupPageExportFailedMessage(
      backupRestoreErrorMessage(l10n, error),
    ),
    task: (handle) async {
      final file = await backup.exportToFile(
        config,
        password: await backupPasswordForExport(context),
        onProgress: handle.report,
        cancelToken: handle.cancelToken,
      );
      await DataSync.completeLocalFileExport(
        exported: file,
        persist: (file) async {
          handle.cancelToken.throwIfCancelled();
          handle.report(
            const BackupProgress(
              phase: BackupPhase.choosingDestination,
              processed: 0,
            ),
          );
          final name = file.uri.pathSegments.last;
          if (Platform.isAndroid || Platform.isIOS) {
            final saved = await NativeFileSave.saveFileFromPath(
              sourcePath: file.path,
              fileName: name,
              requireOutsideAppContainer: Platform.isIOS,
              dialogTitle: l10n.backupPageChooseBackupFolder,
              whenCancelled: handle.cancelToken.whenCancelled,
              onProgress: (written, total) {
                if (written == total) {
                  handle.report(
                    const BackupProgress(
                      phase: BackupPhase.finalizing,
                      processed: 0,
                      cancellable: false,
                    ),
                  );
                } else {
                  handle.report(
                    BackupProgress(
                      phase: BackupPhase.saving,
                      processed: written,
                      total: total,
                      unit: BackupProgressUnit.bytes,
                    ),
                  );
                }
              },
            );
            if (!saved) throw const BackupCancelledException();
          } else {
            final path = await FilePicker.platform.saveFile(
              dialogTitle: l10n.backupPageExportToFile,
              fileName: name,
              type: FileType.custom,
              allowedExtensions: [
                name.endsWith('.kbackup') ? 'kbackup' : 'zip',
              ],
            );
            if (path == null) throw const BackupCancelledException();
            await saveBackupToPath(
              file,
              path,
              cancelToken: handle.cancelToken,
              onProgress: handle.report,
            );
          }
          await reminder.recordBackupCompleted();
        },
      );
    },
  );
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
