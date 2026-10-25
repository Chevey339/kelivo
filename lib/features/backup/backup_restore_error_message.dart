import '../../l10n/app_localizations.dart';
import '../../core/services/backup/backup_cancel_token.dart';
import '../../core/services/backup/backup_encryption.dart';

String backupRestoreErrorMessage(AppLocalizations localizations, Object error) {
  if (error is BackupCancelledException) {
    return localizations.backupProgressCancelled;
  }
  if (error is BackupDecryptionException) {
    return localizations.backupEncryptionFailed;
  }
  if (error is FormatException) {
    switch (error.message) {
      case 'backup_encryption_version':
        return localizations.backupEncryptionUnsupported;
      case 'backup_password_required':
        return localizations.backupEncryptionUnlockHint;
      case 'backup_encryption_header':
      case 'backup_encryption_size':
        return localizations.backupEncryptionInvalid;
    }
  }
  return error.toString();
}
