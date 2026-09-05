import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import 'package:Kelivo/core/models/workspace.dart';
import 'package:Kelivo/core/providers/workspace_provider.dart';
import 'package:Kelivo/features/settings/widgets/custom_theme_widgets.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'desktop_workspace_text_field.dart';
import 'package:Kelivo/theme/app_font_weights.dart';

import 'desktop_workspace_button.dart';

class DesktopWorkspaceCreateDialog extends StatefulWidget {
  const DesktopWorkspaceCreateDialog({super.key, required this.provider});

  final WorkspaceProvider provider;

  @override
  State<DesktopWorkspaceCreateDialog> createState() =>
      _DesktopWorkspaceCreateDialogState();
}

class _DesktopWorkspaceCreateDialogState
    extends State<DesktopWorkspaceCreateDialog> {
  final _name = TextEditingController();
  final _path = TextEditingController();
  WorkspaceKind _kind = WorkspaceKind.managed;
  bool _busy = false;
  bool _picking = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _path.dispose();
    super.dispose();
  }

  bool get _canCreate =>
      !_busy &&
      !_picking &&
      _name.text.trim().isNotEmpty &&
      (_kind == WorkspaceKind.managed || _path.text.trim().isNotEmpty);

  Future<void> _pickFolder() async {
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final path = await FilePicker.platform.getDirectoryPath(
        dialogTitle: AppLocalizations.of(context)!.workspacesLinkFolder,
      );
      if (!mounted || path == null) return;
      setState(() {
        _path.text = path;
        if (_name.text.trim().isEmpty) _name.text = p.basename(path);
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _create() async {
    if (!_canCreate) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final path = _path.text.trim();
      if (_kind == WorkspaceKind.linked &&
          (!p.isAbsolute(path) || !await Directory(path).exists())) {
        if (mounted) {
          setState(
            () => _error = AppLocalizations.of(
              context,
            )!.workspaceDesktopFolderMissing,
          );
        }
        return;
      }
      final workspace = await widget.provider.create(
        name: _name.text.trim(),
        kind: _kind,
        hostPath: _kind == WorkspaceKind.linked ? p.normalize(path) : null,
      );
      if (mounted) Navigator.of(context).pop(workspace);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_busy && !_picking,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              Navigator.of(context).maybePop(),
          const SingleActivator(LogicalKeyboardKey.enter, control: true):
              _create,
          const SingleActivator(LogicalKeyboardKey.enter, meta: true): _create,
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppDialogHeader(title: l10n.workspacesCreateTitle),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DesktopWorkspaceTextField(
                      key: const ValueKey('workspace-desktop-name'),
                      label: l10n.workspacesNameLabel,
                      controller: _name,
                      hintText: l10n.workspacesNameHint,
                      autofocus: true,
                      enabled: !_busy,
                      onChanged: (_) => setState(() => _error = null),
                      onSubmitted: (_) => _create(),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l10n.workspaceMgmtKindSection,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: AppFontWeights.semibold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final kind in WorkspaceKind.values) ...[
                      Material(
                        color: _kind == kind
                            ? cs.primary.withValues(alpha: 0.07)
                            : cs.surfaceContainerLow,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: _kind == kind
                                ? cs.primary.withValues(alpha: 0.22)
                                : cs.outlineVariant.withValues(alpha: 0.12),
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          splashFactory: NoSplash.splashFactory,
                          hoverColor: cs.onSurface.withValues(alpha: 0.035),
                          highlightColor: cs.onSurface.withValues(alpha: 0.065),
                          focusColor: cs.primary.withValues(alpha: 0.08),
                          key: ValueKey('workspace-desktop-kind-${kind.name}'),
                          onTap: _busy
                              ? null
                              : () => setState(() {
                                  _kind = kind;
                                  _error = null;
                                }),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Icon(
                                  kind == WorkspaceKind.linked
                                      ? Lucide.Link
                                      : Lucide.FolderCode,
                                  size: 20,
                                  color: cs.primary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        kind == WorkspaceKind.linked
                                            ? l10n.workspaceMgmtKindLinkedTitle
                                            : l10n.workspaceMgmtKindManagedTitle,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: AppFontWeights.semibold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        kind == WorkspaceKind.linked
                                            ? l10n.workspaceMgmtKindLinkedSubtitle
                                            : l10n.workspaceDesktopManagedHint,
                                        style: TextStyle(
                                          fontSize: 12,
                                          height: 1.4,
                                          color: cs.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                if (_kind == kind)
                                  Icon(
                                    Lucide.CheckCircle,
                                    size: 18,
                                    color: cs.primary,
                                  )
                                else
                                  const SizedBox(width: 18),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (_kind == WorkspaceKind.linked) ...[
                      const SizedBox(height: 8),
                      DesktopWorkspaceTextField(
                        key: const ValueKey('workspace-desktop-path'),
                        label: l10n.workspaceDesktopFolderPath,
                        controller: _path,
                        enabled: !_busy && !_picking,
                        onChanged: (_) => setState(() => _error = null),
                        onSubmitted: (_) => _create(),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: DesktopWorkspaceButton(
                          label: l10n.workspacesLinkFolder,
                          icon: Lucide.FolderOpen,
                          onPressed: _busy || _picking ? null : _pickFolder,
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        key: const ValueKey('workspace-desktop-create-error'),
                        style: TextStyle(color: cs.error, fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_busy) const LinearProgressIndicator(minHeight: 2),
            Divider(
              height: 1,
              thickness: 0.5,
              color: cs.outlineVariant.withValues(alpha: 0.12),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  DesktopWorkspaceButton(
                    label: l10n.workspaceFilesCancel,
                    icon: Lucide.X,
                    onPressed: _busy || _picking
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  DesktopWorkspaceButton(
                    key: const ValueKey('workspaces-create-confirm'),
                    label: l10n.workspaceMgmtCreate,
                    icon: Lucide.Plus,
                    primary: true,
                    onPressed: _canCreate ? _create : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
