import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/database/schema_migrations.dart';
import 'package:Kelivo/core/services/backup/backup_task_progress.dart';
import 'package:Kelivo/core/services/backup/restore_startup_gate.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/animated_progress_bar.dart';
import 'package:Kelivo/shared/widgets/restore_progress_screen.dart';
import 'package:Kelivo/shared/widgets/startup_progress_screen.dart';

void main() {
  testWidgets('database upgrade shows its stages and total elapsed time', (
    tester,
  ) async {
    final progress = ValueNotifier(DatabaseUpgradeStage.backingUp);
    addTearDown(progress.dispose);
    const locale = Locale('zh');
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: DatabaseUpgradeProgressScreen(progress: progress),
      ),
    );
    final l10n = await AppLocalizations.delegate.load(locale);
    expect(find.text(l10n.databaseUpgradeTitle), findsOneWidget);
    expect(find.text(l10n.databaseUpgradeKeepOpen), findsOneWidget);
    expect(find.text(l10n.databaseUpgradeStageBackup), findsOneWidget);
    expect(find.byKey(AnimatedProgressBar.indeterminateKey), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    for (final (stage, label) in [
      (DatabaseUpgradeStage.updating, l10n.databaseUpgradeStageUpdate),
      (DatabaseUpgradeStage.checking, l10n.databaseUpgradeStageCheck),
      (DatabaseUpgradeStage.restoring, l10n.databaseUpgradeStageRestore),
      (DatabaseUpgradeStage.opening, l10n.databaseUpgradeStageOpen),
    ]) {
      progress.value = stage;
      await tester.pump();
      expect(find.text(label), findsOneWidget);
      expect(find.text(l10n.backupProgressElapsed('0:02')), findsOneWidget);
    }
    await tester.pumpWidget(const SizedBox());
    expect(tester.binding.transientCallbackCount, 0);
  });

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
