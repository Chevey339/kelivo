import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/backup/backup_task_progress.dart';
import 'package:Kelivo/core/services/backup/restore_startup_gate.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/animated_progress_bar.dart';
import 'package:Kelivo/shared/widgets/restore_progress_screen.dart';

void main() {
  testWidgets('shows the active stage and follows it', (tester) async {
    final progress = ValueNotifier<RestoreStartupProgress>((
      stage: RestoreStartupStage.checkingBackup,
      detail: null,
    ));
    addTearDown(progress.dispose);
    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: RestoreProgressScreen(progress: progress),
      ),
    );

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.restoreProgressTitle), findsOneWidget);
    expect(find.text(l10n.restoreProgressWarning), findsOneWidget);
    expect(find.text(l10n.restoreProgressStageCheckingBackup), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text(l10n.backupProgressElapsed('0:02')), findsOneWidget);
    progress.value = (
      stage: RestoreStartupStage.verifying,
      detail: const BackupProgress(
        phase: BackupPhase.validating,
        processed: 123,
        total: 246,
        unit: BackupProgressUnit.items,
      ),
    );
    await tester.pump();
    expect(find.text(l10n.backupProgressItems('123', '246')), findsOneWidget);
    expect(
      tester
          .widget<AnimatedProgressBar>(find.byType(AnimatedProgressBar))
          .fraction,
      0.5,
    );

    progress.value = (
      stage: RestoreStartupStage.installingBackup,
      detail: null,
    );
    await tester.pump();

    expect(find.text(l10n.restoreProgressStageCheckingBackup), findsNothing);
    expect(find.text(l10n.backupProgressItems('123', '246')), findsNothing);
    expect(find.text(l10n.backupProgressElapsed('0:00')), findsOneWidget);
    expect(
      find.text(l10n.restoreProgressStageInstallingBackup),
      findsOneWidget,
    );
  });
}
