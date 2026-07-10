import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/backup/data_sync.dart';
import 'package:Kelivo/features/backup/backup_restore_error_message.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

void main() {
  testWidgets('localizes the unsupported SQLite merge error', (tester) async {
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

    expect(
      backupRestoreErrorMessage(
        AppLocalizations.of(context)!,
        const VersionedBackupMergeUnsupportedException(),
      ),
      'SQLite backups cannot be merged yet. Choose Complete Overwrite, or '
      'use Legacy JSON Merge with an older JSON backup.',
    );
  });
}
