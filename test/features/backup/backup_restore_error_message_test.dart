import 'package:Kelivo/core/services/backup/backup_secure_password_store.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/backup/backup_cancel_token.dart';
import 'package:Kelivo/core/services/backup/chatbox_backup_archive.dart';
import 'package:Kelivo/core/services/backup/cherry_direct_backup_reader.dart';
import 'package:Kelivo/features/backup/backup_restore_error_message.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

void main() {
  test(
    'toolbox errors reference the actual backup actions in every locale',
    () {
      for (final locale in AppLocalizations.supportedLocales) {
        final l10n = lookupAppLocalizations(locale);
        for (final error in [
          ChatboxUnsupportedBackupVersionException(4),
          const CherryUnsupportedBackupVersionException(8),
        ]) {
          final failure = describeBackupTaskFailure(l10n, error);
          expect(failure.showToolbox, isTrue);
          expect(
            failure.message,
            contains(l10n.backupPageImportBackupFile),
            reason: '$locale',
          );
          expect(
            failure.message,
            contains(l10n.backupPageMergeMode),
            reason: '$locale',
          );
        }
        const invalid = ChatboxImportException('missing manifest.json');
        expect(describeBackupTaskFailure(l10n, invalid), (
          message: invalid.message,
          showToolbox: false,
        ));
      }
    },
  );

  testWidgets('returns a generic restore error message', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xFFFFFFFF),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (buildContext, child) {
          context = buildContext;
          return const SizedBox.shrink();
        },
      ),
    );

    final l10n = AppLocalizations.of(context)!;
    expect(
      backupRestoreErrorMessage(
        l10n,
        const BackupMacKeychainAccessError(MacBackupAuthorization.denied),
      ),
      l10n.backupMacKeychainAccessDenied,
    );
    expect(
      backupRestoreErrorMessage(
        l10n,
        const BackupMacKeychainAccessError(MacBackupAuthorization.cancelled),
      ),
      l10n.backupProgressCancelled,
    );
    expect(
      backupRestoreErrorMessage(
        l10n,
        const BackupMacKeychainAccessError(MacBackupAuthorization.locked),
      ),
      l10n.backupMacKeychainNeedsUnlock,
    );
    expect(
      automaticBackupErrorMessage(
        l10n,
        const BackupMacKeychainAccessError(MacBackupAuthorization.locked),
      ),
      l10n.backupMacKeychainNeedsUnlock,
    );
    expect(
      backupRestoreErrorMessage(
        AppLocalizations.of(context)!,
        const FormatException('invalid backup'),
      ),
      'FormatException: invalid backup',
    );
    expect(
      backupRestoreErrorMessage(
        AppLocalizations.of(context)!,
        const BackupCancelledException(),
      ),
      'Cancelled',
    );
    expect(
      backupRestoreErrorMessage(
        AppLocalizations.of(context)!,
        PlatformException(code: 'backup_destination_inside_app'),
      ),
      AppLocalizations.of(context)!.backupPageChooseExternalFolder,
    );
    expect(
      backupRestoreErrorMessage(
        l10n,
        PlatformException(code: 'backup_destination_needs_new_file'),
      ),
      l10n.backupPageChooseNewFile,
    );
    expect(
      backupRestoreErrorMessage(
        l10n,
        const FormatException('zip_entry_size:upload/movie.mp4'),
      ),
      l10n.backupArchiveFileSizeLimit('upload/movie.mp4', '8.00 GB'),
    );
    expect(
      backupRestoreErrorMessage(l10n, const FormatException('zip_total_size')),
      l10n.backupArchiveTotalSizeLimit('16.00 GB'),
    );
  });
}
