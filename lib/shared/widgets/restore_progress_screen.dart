import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/services/backup/backup_task_progress.dart';
import '../../core/services/backup/restore_startup_gate.dart';
import '../../l10n/app_localizations.dart';
import 'startup_progress_screen.dart';

typedef RestoreStartupProgress = ({
  RestoreStartupStage stage,
  BackupProgress? detail,
});

/// Shown while the startup gate converges a published restore.
///
/// That work happens before any business persistence is opened, so nothing
/// here may read settings, the database or the asset roots -- the whole point
/// is that they are mid-cutover. It exists because a large bundle keeps the
/// gate busy for seconds with no frame of its own: the user sees a black
/// screen, force-quits it, and the next launch starts the same work over.
class RestoreProgressScreen extends StatelessWidget {
  const RestoreProgressScreen({super.key, required this.progress});

  final ValueListenable<RestoreStartupProgress> progress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ValueListenableBuilder<RestoreStartupProgress>(
      valueListenable: progress,
      builder: (context, value, _) => StartupProgressScreen(
        title: value.stage == RestoreStartupStage.protectingData
            ? l10n.recoveryProtectingTitle
            : l10n.restoreProgressTitle,
        stageLabel: _stageLabel(l10n, value.stage),
        hint: l10n.restoreProgressWarning,
        detail: value.detail,
        elapsedKey: ValueKey((value.stage, value.detail?.phase)),
      ),
    );
  }

  static String _stageLabel(AppLocalizations l10n, RestoreStartupStage stage) =>
      switch (stage) {
        RestoreStartupStage.protectingData => l10n.recoveryProtectingData,
        RestoreStartupStage.checkingBackup =>
          l10n.restoreProgressStageCheckingBackup,
        RestoreStartupStage.preservingCurrentData =>
          l10n.restoreProgressStagePreservingCurrentData,
        RestoreStartupStage.installingBackup =>
          l10n.restoreProgressStageInstallingBackup,
        RestoreStartupStage.verifying => l10n.restoreProgressStageVerifying,
        RestoreStartupStage.rollingBack => l10n.restoreProgressStageRollingBack,
        RestoreStartupStage.finishing => l10n.restoreProgressStageFinishing,
      };
}
