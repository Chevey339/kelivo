import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/services/backup/backup_cancel_token.dart';
import '../../../core/services/backup/backup_task_progress.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/format_bytes.dart';
import '../../../shared/widgets/task_progress_dialog.dart';
import '../../settings/widgets/custom_theme_widgets.dart';

final class BackupTaskHandle {
  BackupTaskHandle({required this.cancelToken, required this._progress});

  final BackupCancelToken cancelToken;
  final ValueNotifier<BackupProgress> _progress;

  BackupProgress get current => _progress.value;

  void report(BackupProgress progress) {
    _progress.value = progress;
    if (!progress.cancellable) {
      cancelToken.setCancellable(false);
    }
  }
}

final class BackupTaskResult<T> {
  const BackupTaskResult._({this.value, this.error, required this.cancelled});

  factory BackupTaskResult.success(T value) =>
      BackupTaskResult._(value: value, cancelled: false);

  factory BackupTaskResult.cancelled() =>
      const BackupTaskResult._(cancelled: true);

  factory BackupTaskResult.failure(Object error) =>
      BackupTaskResult._(error: error, cancelled: false);

  final T? value;
  final Object? error;
  final bool cancelled;

  bool get isSuccess => !cancelled && error == null;
}

Future<BackupTaskResult<T>> showBackupProgressDialog<T>(
  BuildContext context, {
  required String title,
  required Future<T> Function(BackupTaskHandle handle) task,
  bool cancellable = true,
}) async {
  final token = BackupCancelToken();
  final progress = ValueNotifier(
    BackupProgress(
      phase: BackupPhase.preparing,
      processed: 0,
      cancellable: cancellable,
    ),
  );
  final handle = BackupTaskHandle(cancelToken: token, progress: progress);
  try {
    final result = await showAppDialog<BackupTaskResult<T>>(
      context,
      dismissible: false,
      child: _BackupProgressDialogHost<T>(
        title: title,
        handle: handle,
        task: task,
        initiallyCancellable: cancellable,
      ),
    );
    return result ?? BackupTaskResult.cancelled();
  } finally {
    token.dispose();
    progress.dispose();
  }
}

class _BackupProgressDialogHost<T> extends StatefulWidget {
  const _BackupProgressDialogHost({
    required this.title,
    required this.handle,
    required this.task,
    required this.initiallyCancellable,
  });

  final String title;
  final BackupTaskHandle handle;
  final Future<T> Function(BackupTaskHandle handle) task;
  final bool initiallyCancellable;

  @override
  State<_BackupProgressDialogHost<T>> createState() =>
      _BackupProgressDialogHostState<T>();
}

class _BackupProgressDialogHostState<T>
    extends State<_BackupProgressDialogHost<T>> {
  var _outcome = TaskProgressOutcome.running;
  var _started = false;
  Object? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    unawaited(_run());
  }

  Future<void> _run() async {
    try {
      final value = await widget.task(widget.handle);
      if (!mounted) return;
      setState(() => _outcome = TaskProgressOutcome.success);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      Navigator.of(context).pop(BackupTaskResult.success(value));
    } on BackupCancelledException {
      if (!mounted) return;
      Navigator.of(context).pop(BackupTaskResult<T>.cancelled());
    } catch (error) {
      if (!mounted) return;
      _error = error;
      setState(() => _outcome = TaskProgressOutcome.failure);
      widget.handle.report(
        BackupProgress(
          phase: widget.handle.current.phase,
          processed: widget.handle.current.processed,
          total: widget.handle.current.total,
          unit: widget.handle.current.unit,
          cancellable: false,
          detail: widget.handle.current.detail,
        ),
      );
    }
  }

  void _cancel() {
    widget.handle.cancelToken.cancel();
  }

  void _acknowledgeFailure() {
    Navigator.of(context).pop(
      BackupTaskResult<T>.failure(_error ?? StateError('backup_task_failed')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ValueListenableBuilder<BackupProgress>(
      valueListenable: widget.handle._progress,
      builder: (context, progress, _) {
        final failure = _outcome == TaskProgressOutcome.failure;
        return TaskProgressDialogCard(
          title: widget.title,
          phaseLabel: backupPhaseLabel(l10n, progress.phase),
          fraction: _outcome == TaskProgressOutcome.success
              ? 1
              : progress.fraction,
          subtitle: backupProgressSubtitle(l10n, progress),
          phaseIcon: backupPhaseIcon(progress.phase),
          cancellable: progress.cancellable && widget.initiallyCancellable,
          onCancel: _cancel,
          onAcknowledge: failure ? _acknowledgeFailure : null,
          cancelLabel: l10n.backupProgressCancel,
          acknowledgeLabel: l10n.backupPageOK,
          outcome: _outcome,
        );
      },
    );
  }
}

IconData backupPhaseIcon(BackupPhase phase) {
  return switch (phase) {
    BackupPhase.preparing => Lucide.Loader,
    BackupPhase.snapshottingDatabase => Lucide.Database,
    BackupPhase.packing => Lucide.Folder,
    BackupPhase.verifying => Lucide.Shield,
    BackupPhase.uploading => Lucide.Upload,
    BackupPhase.downloading => Lucide.Download,
    BackupPhase.extracting => Lucide.FolderOpen,
    BackupPhase.validating => Lucide.Shield,
    BackupPhase.readingSettings => Lucide.Settings,
    BackupPhase.stagingCandidate => Lucide.HardDrive,
    BackupPhase.committing => Lucide.HardDrive,
    BackupPhase.importingSessions => Lucide.MessagesSquare,
    BackupPhase.importingMessages => Lucide.MessageSquare,
    BackupPhase.materializingFiles => Lucide.FileText,
    BackupPhase.listingRemote => Lucide.cloudDownload,
    BackupPhase.finalizing => Lucide.Check,
  };
}

String backupPhaseLabel(AppLocalizations l10n, BackupPhase phase) {
  return switch (phase) {
    BackupPhase.preparing => l10n.backupProgressPreparing,
    BackupPhase.snapshottingDatabase => l10n.backupProgressSnapshotting,
    BackupPhase.packing => l10n.backupProgressPacking,
    BackupPhase.verifying => l10n.backupProgressVerifying,
    BackupPhase.uploading => l10n.backupProgressUploading,
    BackupPhase.downloading => l10n.backupProgressDownloading,
    BackupPhase.extracting => l10n.backupProgressExtracting,
    BackupPhase.validating => l10n.backupProgressValidating,
    BackupPhase.readingSettings => l10n.backupProgressReadingSettings,
    BackupPhase.stagingCandidate => l10n.backupProgressStaging,
    BackupPhase.committing => l10n.backupProgressCommitting,
    BackupPhase.importingSessions => l10n.backupProgressImportingSessions,
    BackupPhase.importingMessages => l10n.backupProgressImportingMessages,
    BackupPhase.materializingFiles => l10n.backupProgressMaterializingFiles,
    BackupPhase.listingRemote => l10n.backupProgressListingRemote,
    BackupPhase.finalizing => l10n.backupProgressFinalizing,
  };
}

String? backupProgressSubtitle(AppLocalizations l10n, BackupProgress progress) {
  final total = progress.total;
  if (total == null) return null;
  switch (progress.unit) {
    case BackupProgressUnit.bytes:
      return l10n.backupProgressBytes(
        formatBytes(progress.processed),
        formatBytes(total),
      );
    case BackupProgressUnit.items:
      final format = NumberFormat.decimalPattern();
      return l10n.backupProgressItems(
        format.format(progress.processed),
        format.format(total),
      );
    case BackupProgressUnit.none:
      return null;
  }
}
