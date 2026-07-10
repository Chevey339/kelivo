import '../../core/services/backup/data_sync.dart';
import '../../l10n/app_localizations.dart';

String backupRestoreErrorMessage(AppLocalizations localizations, Object error) {
  if (error is VersionedBackupMergeUnsupportedException) {
    return localizations.backupPageSqliteMergeUnsupported;
  }
  return error.toString();
}
