import '../../l10n/app_localizations.dart';
import '../../core/services/backup/backup_cancel_token.dart';

String backupRestoreErrorMessage(AppLocalizations localizations, Object error) {
  if (error is BackupCancelledException) {
    return localizations.backupProgressCancelled;
  }
  return error.toString();
}
