import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../../../core/models/workspace_file_owner.dart';
import '../../../../core/providers/external_mounts_provider.dart';
import '../../../../core/providers/workspace_provider.dart';
import '../../../../core/services/sandbox/workspace_channel.dart';
import '../../../../core/services/workspace/workspace_text_file.dart';
import '../../../../icons/lucide_adapter.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/ios_tile_button.dart';
import '../../../../shared/widgets/ios_text_button.dart';
import '../../../../shared/widgets/snackbar.dart';
import '../../../../theme/app_font_weights.dart';
import '../../../settings/widgets/custom_theme_widgets.dart';
import '../../../../utils/platform_utils.dart';
import '../desktop_workspace_button.dart';
import 'preview_text_document.dart';

enum _EditChoice { keep, save, discard, copy, reload }

/// A tab owns this small session across panel and conversation switches. Only
/// an explicitly opened draft retains a snapshot and an editing value.
class WorkspaceTextEditing extends ChangeNotifier {
  WorkspaceTextEditing(this.file, this.owner, {this.onPathChanged});
  final VoidCallback? onPathChanged;
  File file;
  final WorkspaceFileOwner owner;
  WorkspaceTextSnapshot? _snapshot;
  PreviewTextDocument? _reloaded;
  Object? _pendingError;
  TextEditingValue value = TextEditingValue.empty;
  bool busy = false;
  bool _asking = false;
  bool dirty = false;
  int revision = 0;
  bool startEditingOnOpen = false;
  bool get editing => _snapshot != null;
  bool get needsCloseGuard => busy || dirty || _asking;

  bool get hasPendingError => _pendingError != null;

  void showPendingError(BuildContext context) {
    final error = _pendingError;
    _pendingError = null;
    if (error != null) _showError(context, error);
  }

  PreviewTextDocument? takeReloadedDocument() {
    final document = _reloaded;
    _reloaded = null;
    return document;
  }

  Future<String> Function(String directory) _authorize(BuildContext context) {
    final workspaces = context.read<WorkspaceProvider?>();
    final mounts = context.read<ExternalMountsProvider?>();
    // Saving replaces a directory entry. Its leaf can become a dangling link;
    // the editor never follows that link to read or write a replacement target.
    return (directory) async {
      if (mounts != null) {
        await mounts.loaded;
        if (mounts.entries.isNotEmpty) {
          await mounts.requireWritableHostPaths([directory]);
        }
      }
      if (owner.kind == WorkspaceFileOwnerKind.mount) {
        final mount = mounts?.activeMounts
            .where((m) => m.externalId == owner.id)
            .firstOrNull;
        if (mount == null || mount.readOnly || mounts?.byId(owner.id) == null) {
          throw WorkspaceTextProblem.readOnly;
        }
        return mount.host;
      }
      await workspaces?.loaded;
      final workspace = workspaces?.byId(owner.id);
      if (workspace == null) throw WorkspaceTextProblem.readOnly;
      return workspaces!.hostRootFor(workspace);
    };
  }

  Future<bool> canEdit(BuildContext context) async {
    try {
      final root = await _authorize(context)(file.parent.path);
      await WorkspaceTextSnapshot.checkWritable(root, file.path);
      return true;
    } on Exception {
      return false;
    } on StateError {
      return false;
    }
  }

  void updateValue(TextEditingValue next) {
    final previous = value;
    value = next;
    if (identical(next.text, previous.text)) return;
    final changed = next.text != _snapshot?.text;
    if (dirty == changed) return;
    dirty = changed;
    notifyListeners();
  }

  Future<void> begin(BuildContext context) async {
    if (busy || editing) return;
    busy = true;
    notifyListeners();
    try {
      final root = await _authorize(context)(file.parent.path);
      final snapshot = await WorkspaceTextSnapshot.open(root, file.path);
      _snapshot = snapshot;
      value = TextEditingValue(
        text: snapshot.text,
        selection: const TextSelection.collapsed(offset: 0),
      );
      dirty = false;
    } catch (error) {
      revision++;
      if (context.mounted) _showError(context, error);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  void _finish() {
    revision++;
    _snapshot = null;
    dirty = false;
    value = TextEditingValue.empty;
    notifyListeners();
  }

  Future<bool> leave(BuildContext context) async {
    if (busy || _asking) return false;
    if (!dirty) {
      _finish();
      return true;
    }
    _asking = true;
    final l = AppLocalizations.of(context)!;
    final choice = await _ask(
      context,
      l.workspaceEditorUnsaved,
      l.workspaceEditorLeavePrompt(p.basename(file.path)),
      [
        (_EditChoice.save, l.workspaceFilesSave, Lucide.Check),
        (_EditChoice.keep, l.workspaceEditorKeepEditing, Lucide.Pencil),
        (_EditChoice.discard, l.workspaceEditorDiscard, Lucide.Trash),
      ],
    ).whenComplete(() => _asking = false);
    if (choice == _EditChoice.discard) {
      _finish();
      return true;
    }
    return choice == _EditChoice.save && context.mounted && await save(context);
  }

  Future<bool> save(BuildContext context) async {
    final snapshot = _snapshot;
    if (busy || snapshot == null || !dirty) return false;
    final writableRoot = _authorize(context);
    final path = file.path;
    final text = value.text;
    busy = true;
    notifyListeners();
    try {
      String? published;
      try {
        published = await snapshot.save(
          path: path,
          draft: text,
          writableRoot: writableRoot,
        );
      } on WorkspaceTextProblem catch (error) {
        if (error != WorkspaceTextProblem.conflict || !context.mounted) rethrow;
        final l = AppLocalizations.of(context)!;
        final choice = await _ask(
          context,
          l.workspaceEditorConflict,
          l.workspaceEditorConflictMessage,
          [
            (_EditChoice.copy, l.workspaceEditorSaveCopy, Lucide.Copy),
            (_EditChoice.keep, l.workspaceEditorKeepEditing, Lucide.Pencil),
            (_EditChoice.reload, l.workspaceEditorReload, Lucide.RefreshCw),
          ],
        );
        if (choice == _EditChoice.copy) {
          published = await snapshot.save(
            path: path,
            draft: text,
            writableRoot: writableRoot,
            copy: true,
          );
          file = File(published);
        } else if (choice == _EditChoice.reload) {
          final latest = await snapshot.pathForReload(
            await writableRoot(file.parent.path),
            path,
          );
          _reloaded = await loadPreviewTextDocument(File(latest));
        } else {
          return false;
        }
      }
      if (published != null && value.text != text) {
        _snapshot = await snapshot.afterSave(published, text);
        dirty = value.text != _snapshot!.text;
        revision++;
        if (path != file.path) onPathChanged?.call();
        return false;
      }
      _finish();
      if (path != file.path) onPathChanged?.call();
      return true;
    } catch (error) {
      if (context.mounted) {
        _showError(context, error);
      } else {
        _pendingError = error;
      }
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  void _showError(BuildContext context, Object error) {
    final l = AppLocalizations.of(context)!;
    final message = switch (error) {
      WorkspaceTextProblem.large => l.workspaceEditorLargePreview,
      WorkspaceTextProblem.encoding => l.workspaceEditorEncoding,
      WorkspaceTextProblem.readOnly => l.workspaceEditorReadOnly,
      WorkspaceChannelException(code: 'mount_readonly') =>
        l.workspaceEditorReadOnly,
      PathNotFoundException() => l.workspaceFileMissing,
      WorkspaceTextProblem.conflict => l.workspaceEditorConflict,
      _ => l.workspaceFilesOperationFailed('$error'),
    };
    showAppSnackBar(context, message: message, type: NotificationType.error);
  }

  Future<_EditChoice?> _ask(
    BuildContext context,
    String title,
    String message,
    List<(_EditChoice, String, IconData)> actions,
  ) {
    final cs = Theme.of(context).colorScheme;
    final desktop = PlatformUtils.isDesktopTarget;
    return showAppDialog<_EditChoice>(
      context,
      maxWidth: desktop ? 460 : 380,
      child: Builder(
        builder: (dialogContext) => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: AppFontWeights.emphasis,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              if (desktop)
                Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final (choice, label, _)
                        in actions.skip(1).toList().reversed)
                      IosTextButton(
                        label: label,
                        fontSize: 13,
                        color: choice == _EditChoice.discard
                            ? cs.error
                            : cs.onSurfaceVariant,
                        onPressed: () =>
                            Navigator.of(dialogContext).pop(choice),
                      ),
                    DesktopWorkspaceButton(
                      label: actions.first.$2,
                      icon: actions.first.$3,
                      primary: true,
                      onPressed: () =>
                          Navigator.of(dialogContext).pop(actions.first.$1),
                    ),
                  ],
                )
              else
                for (final (choice, label, icon) in actions)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: IosTileButton(
                      label: label,
                      icon: icon,
                      backgroundColor: choice == actions.first.$1
                          ? cs.primary
                          : null,
                      foregroundColor: choice == _EditChoice.discard
                          ? cs.error
                          : null,
                      onTap: () => Navigator.of(dialogContext).pop(choice),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
