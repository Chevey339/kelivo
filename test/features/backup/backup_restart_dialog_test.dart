import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/features/backup/backup_restart_dialog.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

void main() {
  testWidgets('successful import uses restart dialog without merge counts', (
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
              onPressed: () => showBackupRestartRequiredDialog(context),
              child: const Text('Import'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();

    expect(find.text('Restart Required'), findsOneWidget);
    expect(
      find.text('Import successful. Restart Kelivo to apply it safely.'),
      findsOneWidget,
    );
    expect(find.textContaining('identical skipped'), findsNothing);
    expect(find.textContaining('conflicts remapped'), findsNothing);
    expect(find.textContaining('Restart Kelivo'), findsOneWidget);
  });
}
