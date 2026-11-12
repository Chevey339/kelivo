import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/services/storage/windows_data_directory.dart';
import '../../../core/services/app_exit_flush.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tile_button.dart';
import '../../../shared/widgets/restart_app_action.dart';
import '../../../utils/platform_utils.dart';
import 'custom_theme_widgets.dart';

String dataDirectoryErrorMessage(AppLocalizations l10n, Object error) {
  final code = error is StateError ? error.message : '';
  return switch (code) {
    'data_directory_unavailable' => l10n.dataDirectoryUnavailable,
    'data_directory_identity' => l10n.dataDirectoryIdentityMismatch,
    'data_directory_not_empty' => l10n.dataDirectoryNotEmpty,
    'data_directory_overlap' => l10n.dataDirectoryOverlap,
    'data_directory_local_only' => l10n.dataDirectoryLocalOnly,
    'data_directory_finish_previous' => l10n.dataDirectoryFinishPrevious,
    'data_directory_pending_restore' => l10n.dataDirectoryPendingRestore,
    'data_directory_source_changed' => l10n.dataDirectorySourceChanged,
    'data_directory_copy_changed' => l10n.dataDirectoryCopyChanged,
    _ => l10n.dataDirectoryGenericError,
  };
}

class WindowsDataDirectoryTile extends StatefulWidget {
  const WindowsDataDirectoryTile({super.key});

  @override
  State<WindowsDataDirectoryTile> createState() =>
      _WindowsDataDirectoryTileState();
}

class _WindowsDataDirectoryTileState extends State<WindowsDataDirectoryTile> {
  final _storage = WindowsDataDirectory.instance;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FutureBuilder<WindowsDataDirectory>(
      future: _storage,
      builder: (context, snapshot) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: IosTileButton(
          icon: Lucide.Folder,
          label: l10n.dataDirectoryTitle,
          enabled: snapshot.hasData,
          onTap: () async {
            if (!snapshot.hasData) return;
            await showAppDialog<void>(
              context,
              child: WindowsDataDirectoryDialog(storage: snapshot.data!),
            );
          },
        ),
      ),
    );
  }
}

class WindowsDataDirectoryDialog extends StatefulWidget {
  const WindowsDataDirectoryDialog({
    super.key,
    required this.storage,
    this.pickDirectory,
    this.restart,
  });

  final WindowsDataDirectory storage;
  final Future<String?> Function()? pickDirectory;
  final Future<void> Function()? restart;

  @override
  State<WindowsDataDirectoryDialog> createState() =>
      _WindowsDataDirectoryDialogState();
}

class _WindowsDataDirectoryDialogState
    extends State<WindowsDataDirectoryDialog> {
  WindowsDataDirectoryState? _state;
  Object? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final state = await widget.storage.state;
      if (mounted) setState(() => _state = state);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await operation();
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _choose() async {
    final path =
        await (widget.pickDirectory?.call() ??
            FilePicker.platform.getDirectoryPath(
              dialogTitle: AppLocalizations.of(context)!.dataDirectoryChoose,
            ));
    if (!mounted || path == null) return;
    await widget.storage.schedule(Directory(path));
  }

  Future<void> _clean() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showAppDialog<bool>(
      context,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.dataDirectoryCleanConfirm),
            const SizedBox(height: 8),
            SelectableText(_state!.previous!.path),
            const SizedBox(height: 16),
            IosTileButton(
              icon: Lucide.Trash2,
              label: l10n.dataDirectoryCleanPrevious,
              onTap: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: 8),
            IosTileButton(
              icon: Lucide.X,
              label: l10n.homePageCancel,
              onTap: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true) await widget.storage.cleanPrevious();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = _state;
    return PopScope(
      canPop: !_busy,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.dataDirectoryTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              SelectableText(
                state?.active?.path ?? widget.storage.supportDirectory.path,
              ),
              if (state?.pending == null && state?.previous == null) ...[
                const SizedBox(height: 12),
                Text(l10n.dataDirectoryHint),
              ],
              if (state?.pending case final pending?) ...[
                const SizedBox(height: 16),
                Text(l10n.dataDirectoryPendingHint),
                const SizedBox(height: 8),
                SelectableText(pending.path),
                const SizedBox(height: 16),
                IosTileButton(
                  icon: Lucide.RotateCw,
                  label: l10n.dataDirectoryRestart,
                  enabled: !_busy,
                  onTap: () => _run(() async {
                    await AppExitFlush.flushAll();
                    if (!context.mounted) return;
                    await requestAppRestart(
                      context,
                      widget.restart ?? PlatformUtils.restartApp,
                    );
                  }),
                ),
                const SizedBox(height: 8),
                Text(l10n.dataDirectoryCancelHint),
                const SizedBox(height: 8),
                IosTileButton(
                  icon: Lucide.X,
                  label: l10n.dataDirectoryCancelMove,
                  enabled: !_busy,
                  onTap: () => _run(widget.storage.cancel),
                ),
              ] else if (state?.previous case final previous?) ...[
                const SizedBox(height: 16),
                Text(l10n.dataDirectoryPreviousHint),
                const SizedBox(height: 8),
                SelectableText(previous.path),
                const SizedBox(height: 16),
                IosTileButton(
                  icon: Lucide.Trash2,
                  label: l10n.dataDirectoryCleanPrevious,
                  enabled: !_busy && state!.confirmed,
                  onTap: () => _run(_clean),
                ),
              ] else ...[
                const SizedBox(height: 16),
                IosTileButton(
                  icon: Lucide.FolderOpen,
                  label: l10n.dataDirectoryChange,
                  enabled: !_busy && state != null,
                  onTap: () => _run(_choose),
                ),
              ],
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),
              if (_error case final error?) ...[
                const SizedBox(height: 12),
                Text(
                  dataDirectoryErrorMessage(l10n, error),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 6),
                SelectableText(
                  error.toString(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 12),
              IosTileButton(
                icon: Lucide.Check,
                label: l10n.backupPageOK,
                enabled: !_busy,
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
