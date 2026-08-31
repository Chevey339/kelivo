import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/database/startup_failure_report.dart' show formatBytes;
import '../../../core/providers/local_snapshot_provider.dart';
import '../../../core/services/backup/local_copy_catalog.dart';
import '../../../core/services/backup/local_snapshot_schedule.dart';
import '../../../core/services/backup/local_snapshot_settings.dart';
import '../../../core/services/backup/local_snapshot_store.dart';
import '../../../core/services/native_file_save.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_switch.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/ios_tile_button.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../theme/app_font_weights.dart';
import '../../settings/widgets/custom_theme_widgets.dart';
import '../backup_restart_dialog.dart';
import '../backup_restore_error_message.dart';
import '../backup_task_runner.dart';

/// Lists every copy of the database that lives on this device, of either
/// kind, and lets the user restore, export or delete any of them.
class LocalSnapshotsPage extends StatefulWidget {
  const LocalSnapshotsPage({super.key});

  @override
  State<LocalSnapshotsPage> createState() => _LocalSnapshotsPageState();
}

class _LocalSnapshotsPageState extends State<LocalSnapshotsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<LocalSnapshotProvider>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final vm = context.watch<LocalSnapshotProvider>();
    final settings = vm.settings;

    Widget header(String text, {bool first = false}) => Padding(
      padding: EdgeInsets.fromLTRB(12, first ? 2 : 18, 12, 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: AppFontWeights.semibold,
          color: cs.onSurface.withValues(alpha: 0.8),
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        leading: IosIconButton(
          icon: Lucide.ArrowLeft,
          size: 22,
          minSize: 44,
          onTap: () => Navigator.of(context).maybePop(),
        ),
        title: Text(l10n.localSnapshotCopiesTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          header(l10n.localSnapshotSectionTitle, first: true),
          SectionCard(
            children: [
              _SwitchRow(
                icon: Lucide.Shield,
                label: l10n.localSnapshotEnabledTitle,
                value: settings.enabled,
                onChanged: (value) =>
                    vm.updateSettings(settings.copyWith(enabled: value)),
              ),
              if (settings.enabled) ...[
                const _Divider(),
                _NavRow(
                  icon: Lucide.Repeat,
                  label: l10n.localSnapshotIntervalTitle,
                  detail: _intervalLabel(l10n, settings.intervalDays),
                  onTap: () => _chooseInterval(context, vm),
                ),
                const _Divider(),
                _NavRow(
                  icon: Lucide.Layers,
                  label: l10n.localSnapshotKeepTitle,
                  detail: l10n.localSnapshotKeepValue(settings.keepRecent),
                  onTap: () => _chooseKeepRecent(context, vm),
                ),
                const _Divider(),
                _SwitchRow(
                  icon: Lucide.CalendarPlus,
                  label: l10n.localSnapshotKeepWeekly,
                  value: settings.keepWeekly,
                  onChanged: (value) =>
                      vm.updateSettings(settings.copyWith(keepWeekly: value)),
                ),
                const _Divider(),
                _SwitchRow(
                  icon: Lucide.Calendar,
                  label: l10n.localSnapshotKeepMonthly,
                  value: settings.keepMonthly,
                  onChanged: (value) =>
                      vm.updateSettings(settings.copyWith(keepMonthly: value)),
                ),
                const _Divider(),
                _NavRow(
                  icon: Lucide.HardDrive,
                  label: l10n.localSnapshotMaximumTitle,
                  detail: settings.maximumTotalBytes <= 0
                      ? l10n.localSnapshotMaximumUnlimited
                      : formatBytes(settings.maximumTotalBytes),
                  onTap: () => _chooseMaximum(context, vm),
                ),
                const _Divider(),
                _SwitchRow(
                  icon: Lucide.MessageSquare,
                  label: l10n.localSnapshotAnnounceTitle,
                  value: settings.announceResult,
                  onChanged: (value) => vm.updateSettings(
                    settings.copyWith(announceResult: value),
                  ),
                ),
              ],
            ],
          ),
          _Note(
            settings.enabled
                ? l10n.localSnapshotKeepProtectedNote
                : l10n.localSnapshotEnabledSubtitle,
          ),
          const SizedBox(height: 10),
          _StatusLine(state: vm.state),
          const SizedBox(height: 12),
          IosTileButton(
            icon: Lucide.Download,
            label: l10n.localSnapshotTakeNow,
            enabled: !vm.working,
            onTap: () => _takeNow(context, vm),
          ),
          header(
            '${l10n.localSnapshotCopiesTitle} · '
            '${l10n.localSnapshotUsage(vm.copies.length, formatBytes(vm.totalBytes))}',
          ),
          if (vm.copies.isEmpty)
            _EmptyState(loading: vm.loading)
          else
            for (final copy in vm.copies)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _CopyCard(
                  copy: copy,
                  onRestore: () => _restore(context, vm, copy),
                  onExport: () => _export(context, vm, copy),
                  onDelete: () => _delete(context, vm, copy),
                  onTogglePin: copy.kind == LocalCopyKind.snapshot
                      ? () => vm.setPinned(copy, !copy.pinned)
                      : null,
                ),
              ),
          const SizedBox(height: 8),
          _Note(l10n.localSnapshotCopiesScopeNote),
        ],
      ),
    );
  }

  static String _intervalLabel(AppLocalizations l10n, int days) => days <= 0
      ? l10n.localSnapshotIntervalAutomatic
      : l10n.localSnapshotIntervalDays(days);

  Future<void> _chooseInterval(
    BuildContext context,
    LocalSnapshotProvider vm,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final chosen = await _pickOption<int>(
      context,
      title: l10n.localSnapshotIntervalTitle,
      current: vm.settings.intervalDays,
      options: [
        for (final days in LocalSnapshotSettings.intervalPresets)
          (
            value: days,
            label: _intervalLabel(l10n, days),
            detail: days <= 0
                ? l10n.localSnapshotIntervalAutomaticDetail
                : null,
          ),
      ],
    );
    if (chosen == null) return;
    await vm.updateSettings(vm.settings.copyWith(intervalDays: chosen));
  }

  Future<void> _chooseKeepRecent(
    BuildContext context,
    LocalSnapshotProvider vm,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final chosen = await _pickOption<int>(
      context,
      title: l10n.localSnapshotKeepTitle,
      current: vm.settings.keepRecent,
      options: [
        for (
          var count = LocalSnapshotSettings.minimumKeepRecent;
          count <= LocalSnapshotSettings.maximumKeepRecent;
          count++
        )
          (
            value: count,
            label: l10n.localSnapshotKeepValue(count),
            detail: null,
          ),
      ],
    );
    if (chosen == null) return;
    await vm.updateSettings(vm.settings.copyWith(keepRecent: chosen));
  }

  Future<void> _chooseMaximum(
    BuildContext context,
    LocalSnapshotProvider vm,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final chosen = await _pickOption<int>(
      context,
      title: l10n.localSnapshotMaximumTitle,
      current: vm.settings.maximumTotalBytes,
      options: [
        for (final bytes in LocalSnapshotSettings.totalBytesPresets)
          (
            value: bytes,
            label: bytes <= 0
                ? l10n.localSnapshotMaximumUnlimited
                : formatBytes(bytes),
            detail: null,
          ),
      ],
    );
    if (chosen == null) return;
    await vm.updateSettings(vm.settings.copyWith(maximumTotalBytes: chosen));
  }

  Future<void> _takeNow(BuildContext context, LocalSnapshotProvider vm) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = context;
    final done = await runBackupTask(
      context,
      title: l10n.localSnapshotTakeNow,
      task: (handle) => vm.takeNow(
        onProgress: handle.report,
        cancelToken: handle.cancelToken,
      ),
      // A manual copy of a large database takes minutes; there is no reason to
      // hold the user at a modal for it.
      backgroundLabel: l10n.localSnapshotRunInBackground,
      backgroundedMessage: l10n.localSnapshotRunningInBackground,
      errorMessage: (error) =>
          l10n.localSnapshotTakeFailed(backupRestoreErrorMessage(l10n, error)),
    );
    if (!done || !messenger.mounted) return;
    showAppSnackBar(messenger, message: l10n.localSnapshotTakeDone);
  }

  Future<void> _export(
    BuildContext context,
    LocalSnapshotProvider vm,
    LocalCopy copy,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    MaterializedLocalCopy? materialized;
    final done = await runBackupTask(
      context,
      title: l10n.localSnapshotExportPreparing,
      task: (handle) async {
        materialized = await vm.materialize(
          copy,
          onProgress: handle.report,
          cancelToken: handle.cancelToken,
        );
      },
      errorMessage: (error) => l10n.localSnapshotExportFailed(
        backupRestoreErrorMessage(l10n, error),
      ),
    );
    final prepared = materialized;
    if (!done || prepared == null) return;
    final fileName = vm.exportFileNameFor(copy);
    try {
      // Held for the whole handover: the picker takes the file by path, and
      // on Android bringing it up resumes the app, which is exactly what arms
      // the schedule that could prune this copy.
      final saved = await vm.whileHoldingCopies(
        () => _saveExport(prepared.file, fileName, l10n),
      );
      if (!context.mounted) return;
      if (saved) {
        showAppSnackBar(context, message: l10n.localSnapshotExportDone);
      }
    } catch (error) {
      if (!context.mounted) return;
      showAppSnackBar(
        context,
        message: l10n.localSnapshotExportFailed(
          backupRestoreErrorMessage(l10n, error),
        ),
        type: NotificationType.error,
      );
    } finally {
      await vm.releaseMaterialized(prepared);
    }
  }

  /// Hands [source] to whichever save flow the platform actually has.
  ///
  /// Desktop has no native save channel, so it goes through the file picker
  /// the rest of the backup screen already uses; calling the mobile-only path
  /// there would throw and leave a recovered database with no way off the
  /// machine.
  Future<bool> _saveExport(
    File source,
    String fileName,
    AppLocalizations l10n,
  ) async {
    if (Platform.isAndroid || Platform.isIOS) {
      return NativeFileSave.saveFileFromPath(
        sourcePath: source.path,
        fileName: fileName,
      );
    }
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: l10n.localSnapshotActionExport,
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: const ['zip'],
    );
    if (savePath == null) return false;
    final target = File(savePath);
    await target.parent.create(recursive: true);
    await source.copy(target.path);
    return true;
  }

  Future<void> _restore(
    BuildContext context,
    LocalSnapshotProvider vm,
    LocalCopy copy,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await _confirm(
      context,
      title: l10n.localSnapshotRestoreTitle,
      message: l10n.localSnapshotRestoreMessage(_whenLabel(context, copy)),
      confirmLabel: l10n.localSnapshotActionRestore,
      icon: Lucide.RotateCcw,
    );
    if (confirmed != true || !context.mounted) return;

    MaterializedLocalCopy? materialized;
    final done = await runBackupTask(
      context,
      title: l10n.localSnapshotRestorePreparing,
      task: (handle) async {
        // The copy taken here is what makes the restore reversible, so it has
        // to succeed before anything replaces the live database.
        await vm.takeNow(
          origin: LocalSnapshotOrigin.beforeRestore,
          pinned: true,
          prune: false,
          onProgress: handle.report,
          cancelToken: handle.cancelToken,
        );
        materialized = await vm.materialize(
          copy,
          onProgress: handle.report,
          cancelToken: handle.cancelToken,
        );
        await vm.restoreArchive(
          materialized!.file,
          onProgress: handle.report,
          cancelToken: handle.cancelToken,
        );
      },
    );
    final prepared = materialized;
    if (prepared != null) await vm.releaseMaterialized(prepared);
    if (!done || !context.mounted) return;
    await showBackupRestartRequiredDialog(
      context,
      skippedConversations: vm.skippedConversations,
    );
  }

  Future<void> _delete(
    BuildContext context,
    LocalSnapshotProvider vm,
    LocalCopy copy,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final withContent = vm.copies.where(
      (candidate) => (candidate.messageCount ?? 1) > 0,
    );
    final isLastWithContent =
        withContent.length == 1 && withContent.single.id == copy.id;
    final confirmed = await _confirm(
      context,
      title: l10n.localSnapshotDeleteTitle,
      message: isLastWithContent
          ? '${l10n.localSnapshotDeleteLastWarning}\n\n'
                '${l10n.localSnapshotDeleteMessage}'
          : l10n.localSnapshotDeleteMessage,
      confirmLabel: l10n.localSnapshotActionDelete,
      icon: Lucide.Trash2,
      destructive: true,
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await vm.delete(copy);
      if (!context.mounted) return;
      showAppSnackBar(context, message: l10n.localSnapshotDeleteDone);
    } catch (error) {
      if (!context.mounted) return;
      showAppSnackBar(
        context,
        message: backupRestoreErrorMessage(l10n, error),
        type: NotificationType.error,
      );
    }
  }
}

String _whenLabel(BuildContext context, LocalCopy copy) {
  final at = copy.createdAt?.toLocal();
  if (at == null) return '—';
  return DateFormat('yyyy-MM-dd HH:mm').format(at);
}

Future<T?> _pickOption<T>(
  BuildContext context, {
  required String title,
  required T current,
  required List<({T value, String label, String? detail})> options,
}) {
  final cs = Theme.of(context).colorScheme;
  return showAppDialog<T>(
    context,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: AppFontWeights.emphasis,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final option in options)
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => Navigator.of(context).pop(option.value),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 11,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    option.label,
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                  if (option.detail != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        option.detail!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: cs.onSurface.withValues(
                                            alpha: 0.6,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (option.value == current)
                              Icon(Lucide.Check, size: 18, color: cs.primary),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<bool?> _confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required IconData icon,
  bool destructive = false,
}) {
  final cs = Theme.of(context).colorScheme;
  final l10n = AppLocalizations.of(context)!;
  return showAppDialog<bool>(
    context,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 16, fontWeight: AppFontWeights.emphasis),
          ),
          const SizedBox(height: 10),
          Text(message, style: const TextStyle(fontSize: 14, height: 1.4)),
          const SizedBox(height: 16),
          IosTileButton(
            icon: icon,
            label: confirmLabel,
            backgroundColor: destructive ? cs.error : null,
            onTap: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: 8),
          IosTileButton(
            icon: Lucide.X,
            label: l10n.backupPageCancel,
            onTap: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    ),
  );
}

class _CopyCard extends StatelessWidget {
  const _CopyCard({
    required this.copy,
    required this.onRestore,
    required this.onExport,
    required this.onDelete,
    this.onTogglePin,
  });

  final LocalCopy copy;
  final VoidCallback onRestore;
  final VoidCallback onExport;
  final VoidCallback onDelete;
  final VoidCallback? onTogglePin;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final conversations = copy.conversationCount;
    final messages = copy.messageCount;

    return SectionCard(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    copy.kind == LocalCopyKind.snapshot
                        ? Lucide.Database
                        : Lucide.Shield,
                    size: 18,
                    color: cs.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _whenLabel(context, copy),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: AppFontWeights.semibold,
                      ),
                    ),
                  ),
                  Text(
                    formatBytes(copy.bytes),
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                copy.kind == LocalCopyKind.displaced
                    ? l10n.localSnapshotKindRecovered
                    : switch (copy.origin) {
                        LocalSnapshotOrigin.manual =>
                          l10n.localSnapshotOriginManual,
                        LocalSnapshotOrigin.beforeRestore =>
                          l10n.localSnapshotOriginBeforeRestore,
                        _ => l10n.localSnapshotOriginAutomatic,
                      },
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                conversations == null || messages == null
                    ? l10n.localSnapshotCopyContentsUnknown
                    : l10n.localSnapshotCopyContents(conversations, messages),
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: IosTileButton(
                      icon: Lucide.RotateCcw,
                      label: l10n.localSnapshotActionRestore,
                      fontSize: 13,
                      onTap: onRestore,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: IosTileButton(
                      icon: Lucide.Share2,
                      label: l10n.localSnapshotActionExport,
                      fontSize: 13,
                      onTap: onExport,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: IosTileButton(
                      icon: Lucide.Trash2,
                      label: l10n.localSnapshotActionDelete,
                      fontSize: 13,
                      backgroundColor: cs.error,
                      onTap: onDelete,
                    ),
                  ),
                ],
              ),
              if (onTogglePin != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: IosTileButton(
                    icon: copy.pinned ? Lucide.PinOff : Lucide.Pin,
                    label: copy.pinned
                        ? l10n.localSnapshotActionUnpin
                        : l10n.localSnapshotActionPin,
                    fontSize: 13,
                    onTap: onTogglePin!,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.state});

  final LocalSnapshotState state;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final failure = state.lastFailureAt;
    final (String text, bool warning) = () {
      if (failure != null) {
        return (
          l10n.localSnapshotStatusFailure(
            _relative(context, failure),
            state.lastFailureMessage ?? '',
          ),
          true,
        );
      }
      if (state.lastSkipReason == LocalSnapshotSkipReason.insufficientSpace) {
        return (l10n.localSnapshotStatusSkippedSpace, true);
      }
      final success = state.lastSuccessAt;
      if (success == null) return (l10n.localSnapshotStatusNever, false);
      return (
        l10n.localSnapshotStatusSuccess(_relative(context, success)),
        false,
      );
    }();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            warning ? Lucide.TriangleAlert : Lucide.Check,
            size: 14,
            color: warning ? cs.error : cs.onSurface.withValues(alpha: 0.55),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: warning ? cs.error : cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _relative(BuildContext context, DateTime at) =>
      DateFormat('yyyy-MM-dd HH:mm').format(at.toLocal());
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          if (loading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else ...[
            Icon(
              Lucide.Database,
              size: 28,
              color: cs.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.localSnapshotCopiesEmpty,
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                l10n.localSnapshotCopiesEmptyHint,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: cs.onSurface.withValues(alpha: 0.45),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          height: 1.45,
          color: cs.onSurface.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Divider(
      height: 6,
      thickness: 0.6,
      indent: 54,
      endIndent: 12,
      color: cs.outlineVariant.withValues(alpha: 0.18),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = cs.onSurface.withValues(alpha: 0.9);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 36, child: Icon(icon, size: 20, color: color)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 15, color: color)),
          ),
          IosSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.detail,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = cs.onSurface.withValues(alpha: 0.9);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: [
            SizedBox(width: 36, child: Icon(icon, size: 20, color: color)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 15, color: color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (detail != null)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  detail!,
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            Icon(Lucide.ChevronRight, size: 16, color: color),
          ],
        ),
      ),
    );
  }
}
