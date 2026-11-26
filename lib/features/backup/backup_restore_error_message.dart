import 'package:flutter/services.dart';
import '../../core/services/backup/backup_archive_limits.dart';
import '../../core/services/backup/backup_folder_access.dart';
import '../../core/services/backup/backup_secure_password_store.dart';
import '../../core/providers/external_backup_auto_provider.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/utils/format_bytes.dart';
import '../../core/services/backup/backup_cancel_token.dart';
import '../../core/services/backup/backup_encryption.dart';
import '../../core/services/backup/chatbox_backup_archive.dart';
import '../../core/services/backup/cherry_direct_backup_reader.dart';

typedef BackupTaskFailure = ({String message, bool showToolbox});

BackupTaskFailure describeBackupTaskFailure(
  AppLocalizations l10n,
  Object error, {
  String Function(Object)? errorMessage,
}) {
  final toolboxMessage = switch (error) {
    ChatboxUnsupportedBackupVersionException(:final version) =>
      l10n.backupPageChatboxUnsupportedBackupVersion('$version'),
    CherryUnsupportedBackupVersionException(:final version) =>
      l10n.backupPageCherryStudioUnsupportedBackupVersion('$version'),
    _ => null,
  };
  return (
    message:
        toolboxMessage ??
        errorMessage?.call(error) ??
        backupRestoreErrorMessage(l10n, error),
    showToolbox: toolboxMessage != null,
  );
}

String backupRestoreErrorMessage(AppLocalizations localizations, Object error) {
  if (error is BackupMacKeychainAccessError) {
    return switch (error.reason) {
      MacBackupAuthorization.locked =>
        localizations.backupMacKeychainNeedsUnlock,
      MacBackupAuthorization.denied =>
        localizations.backupMacKeychainAccessDenied,
      MacBackupAuthorization.cancelled => localizations.backupProgressCancelled,
    };
  }
  if (error is BackupKeychainUnavailable) {
    return localizations.backupAutoKeychainUnavailable;
  }
  if (error is BackupFolderError) {
    return switch (error) {
      BackupFolderError.invalid => localizations.backupAutoLocalFolderInvalid,
      BackupFolderError.unavailable =>
        localizations.backupAutoLocalDirUnavailable,
      BackupFolderError.permission =>
        localizations.backupAutoLocalDirPermission,
      BackupFolderError.full => localizations.backupAutoLocalDirFull,
      BackupFolderError.bookmark => localizations.backupAutoLocalBookmarkLost,
    };
  }
  if (error is BackupDestinationError) {
    return switch (error) {
      BackupDestinationError.remote => localizations.backupAutoNeedRemoteHint,
      BackupDestinationError.destination =>
        localizations.backupAutoNeedDestinationHint,
      BackupDestinationError.folder => localizations.backupAutoNeedFolderHint,
    };
  }
  if (error is PlatformException &&
      error.code == 'backup_destination_inside_app') {
    return localizations.backupPageChooseExternalFolder;
  }
  if (error is PlatformException &&
      error.code == 'backup_destination_needs_new_file') {
    return localizations.backupPageChooseNewFile;
  }
  if (error is BackupCancelledException) {
    return localizations.backupProgressCancelled;
  }
  if (error is BackupDecryptionException) {
    return localizations.backupEncryptionFailed;
  }
  if (error is FormatException) {
    const entrySizePrefix = 'zip_entry_size:';
    if (error.message.startsWith(entrySizePrefix)) {
      return localizations.backupArchiveFileSizeLimit(
        error.message.substring(entrySizePrefix.length),
        formatBytes(BackupArchiveLimits.entryBytes),
      );
    }
    switch (error.message) {
      case 'zip_total_size':
        return localizations.backupArchiveTotalSizeLimit(
          formatBytes(BackupArchiveLimits.totalBytes),
        );
      case 'backup_encryption_version':
        return localizations.backupEncryptionUnsupported;
      case 'backup_password_required':
        return localizations.backupEncryptionUnlockHint;
      case 'backup_encryption_header':
      case 'backup_encryption_size':
        return localizations.backupEncryptionInvalid;
    }
  }
  final message = error.toString();
  return message.replaceFirst(RegExp(r'^(?:Exception: )+'), '');
}

String automaticBackupErrorMessage(AppLocalizations l10n, Object error) {
  if (error is BackupDecryptionException) return l10n.backupAutoFailedPassword;
  final reason = backupRestoreErrorMessage(l10n, error);
  return error is BackupFolderError ||
          error is BackupDestinationError ||
          error is BackupKeychainUnavailable
      ? reason
      : l10n.backupAutoFailed(reason);
}
