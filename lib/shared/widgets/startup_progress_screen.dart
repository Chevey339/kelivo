import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/database/schema_migrations.dart';
import '../../core/services/backup/backup_task_progress.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_font_weights.dart';
import '../utils/backup_progress_text.dart';
import 'animated_progress_bar.dart';

class DatabaseUpgradeProgressScreen extends StatelessWidget {
  const DatabaseUpgradeProgressScreen({super.key, required this.progress});

  final ValueListenable<DatabaseUpgradeStage> progress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ValueListenableBuilder<DatabaseUpgradeStage>(
      valueListenable: progress,
      builder: (context, stage, _) => StartupProgressScreen(
        title: l10n.databaseUpgradeTitle,
        stageLabel: switch (stage) {
          DatabaseUpgradeStage.checking => l10n.databaseUpgradeStageCheck,
          DatabaseUpgradeStage.backingUp => l10n.databaseUpgradeStageBackup,
          DatabaseUpgradeStage.updating => l10n.databaseUpgradeStageUpdate,
          DatabaseUpgradeStage.restoring => l10n.databaseUpgradeStageRestore,
          DatabaseUpgradeStage.opening => l10n.databaseUpgradeStageOpen,
        },
        hint: l10n.databaseUpgradeKeepOpen,
      ),
    );
  }
}

/// Displays startup work before any of the application's settings can be read.
class StartupProgressScreen extends StatelessWidget {
  const StartupProgressScreen({
    super.key,
    required this.title,
    required this.stageLabel,
    required this.hint,
    this.detail,
    this.elapsedKey,
  });

  final String title;
  final String stageLabel;
  final String hint;
  final BackupProgress? detail;
  final Key? elapsedKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = detail;
    final subtitle = progress == null
        ? null
        : backupProgressSubtitle(AppLocalizations.of(context)!, progress);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: AppFontWeights.semibold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        stageLabel,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    AnimatedProgressBar(fraction: progress?.fraction),
                    const SizedBox(height: 8),
                    if (subtitle != null)
                      Text(subtitle, style: theme.textTheme.bodySmall)
                    else
                      _StageElapsedTime(key: elapsedKey),
                    const SizedBox(height: 32),
                    Text(
                      hint,
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
      ),
    );
  }
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
