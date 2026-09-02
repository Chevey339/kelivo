import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/backup/restore_startup_gate.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/restore_progress_screen.dart';

void main() {
  testWidgets('shows the active stage and follows it', (tester) async {
    final stage = ValueNotifier(RestoreStartupStage.checkingBackup);
    addTearDown(stage.dispose);
    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: RestoreProgressScreen(stage: stage),
      ),
    );

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.restoreProgressTitle), findsOneWidget);
    expect(find.text(l10n.restoreProgressWarning), findsOneWidget);
    expect(find.text(l10n.restoreProgressStageCheckingBackup), findsOneWidget);

    stage.value = RestoreStartupStage.installingBackup;
    await tester.pump();

    expect(find.text(l10n.restoreProgressStageCheckingBackup), findsNothing);
    expect(
      find.text(l10n.restoreProgressStageInstallingBackup),
      findsOneWidget,
    );
  });
}
