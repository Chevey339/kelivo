import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/services/backup/backup_task_progress.dart';
import '../../core/services/backup/restore_startup_gate.dart';
import '../../l10n/app_localizations.dart';
import 'package:Kelivo/theme/app_font_weights.dart';
import '../utils/backup_progress_text.dart';
import 'animated_progress_bar.dart';

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
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: ValueListenableBuilder<RestoreStartupProgress>(
                valueListenable: progress,
                builder: (context, value, _) {
                  final detail = value.detail;
                  final subtitle = detail == null
                      ? null
                      : backupProgressSubtitle(l10n, detail);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        value.stage == RestoreStartupStage.protectingData
                            ? l10n.recoveryProtectingTitle
                            : l10n.restoreProgressTitle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: AppFontWeights.semibold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _stageLabel(l10n, value.stage),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),
                      AnimatedProgressBar(fraction: detail?.fraction),
                      const SizedBox(height: 8),
                      if (subtitle != null)
                        Text(subtitle, style: theme.textTheme.bodySmall)
                      else
                        _StageElapsedTime(
                          key: ValueKey((value.stage, detail?.phase)),
                        ),
                      const SizedBox(height: 32),
                      Text(
                        l10n.restoreProgressWarning,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
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

class _StageElapsedTime extends StatefulWidget {
  const _StageElapsedTime({super.key});

  @override
  State<_StageElapsedTime> createState() => _StageElapsedTimeState();
}

class _StageElapsedTimeState extends State<_StageElapsedTime> {
  late final Timer _timer = Timer.periodic(const Duration(seconds: 1), (_) {
    setState(() {});
  });

  @override
  Widget build(BuildContext context) => Text(
    formatBackupElapsed(
      AppLocalizations.of(context)!,
      Duration(seconds: _timer.tick),
    ),
    style: Theme.of(context).textTheme.bodySmall,
  );

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
}
