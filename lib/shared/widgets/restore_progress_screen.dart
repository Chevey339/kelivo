import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/services/backup/restore_startup_gate.dart';
import '../../l10n/app_localizations.dart';

/// Shown while the startup gate converges a published restore.
///
/// That work happens before any business persistence is opened, so nothing
/// here may read settings, the database or the asset roots -- the whole point
/// is that they are mid-cutover. It exists because a large bundle keeps the
/// gate busy for seconds with no frame of its own: the user sees a black
/// screen, force-quits it, and the next launch starts the same work over.
class RestoreProgressScreen extends StatelessWidget {
  const RestoreProgressScreen({super.key, required this.stage});

  final ValueListenable<RestoreStartupStage> stage;

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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    l10n.restoreProgressTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ValueListenableBuilder<RestoreStartupStage>(
                    valueListenable: stage,
                    builder: (context, value, _) => Text(
                      _stageLabel(l10n, value),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
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
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _stageLabel(AppLocalizations l10n, RestoreStartupStage stage) =>
      switch (stage) {
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
