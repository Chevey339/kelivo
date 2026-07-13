import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/features/backup/backup_restart_dialog.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

void main() {
  testWidgets('merge completion uses restart dialog with merge report', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showBackupRestartRequiredDialog(
                context,
                mergeReport: const BackupMergeReport(
                  importedConversations: 3,
                  deduplicatedConversations: 2,
                  remappedConversationIds: {'old': 'new'},
                ),
              ),
              child: const Text('Import'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();

    expect(find.text('Restart Required'), findsOneWidget);
    expect(find.textContaining('3 imported'), findsOneWidget);
    expect(find.textContaining('2 identical skipped'), findsOneWidget);
    expect(find.textContaining('1 conflicts remapped'), findsOneWidget);
    expect(find.textContaining('Restart Kelivo'), findsOneWidget);
  });
}
