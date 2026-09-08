import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import 'package:Kelivo/core/models/external_mount.dart';
import 'package:Kelivo/core/models/workspace_directory_access.dart';
import 'package:Kelivo/core/providers/external_mounts_provider.dart';
import 'package:Kelivo/core/services/sandbox/workspace_channel.dart';
import 'package:Kelivo/features/settings/widgets/custom_theme_widgets.dart';
import 'package:Kelivo/features/workspace/widgets/files/file_browser.dart';
import 'package:Kelivo/features/workspace/widgets/files/file_browser_ops.dart';
import 'package:Kelivo/features/workspace/widgets/files/workspace_prompts.dart';
import 'package:Kelivo/features/workspace/workspace_layout.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/form_sheet.dart';
import 'package:Kelivo/shared/widgets/ios_form_text_field.dart';
import 'package:Kelivo/shared/widgets/ios_settings_rows.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/shared/widgets/ios_tile_button.dart';
import 'package:Kelivo/shared/widgets/section_card.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';

String _mountError(AppLocalizations l10n, Object error) {
  if (error is WorkspaceChannelException) {
    switch (error.code) {
      case 'external_folder_provider':
        return l10n.workspaceExternalLocalOnly;
      case 'external_storage_permission':
        return l10n.workspaceExternalStorageMessage;
      case 'external_mount_name':
        return l10n.workspaceMountInvalidName;
      case 'external_mount_duplicate':
        return l10n.workspaceMountDuplicate;
      case 'external_mount_limit':
        return l10n.workspaceMountLimit;
      case 'external_mount_overlap':
        return l10n.workspaceMountOverlap;
      case 'external_mount_target_occupied':
        return l10n.workspaceMountTargetOccupied;
    }
  }
  return l10n.workspaceExternalUnavailable;
}

Future<WorkspaceDirectory?> _pickDirectory(
  BuildContext context,
  ExternalMountsProvider provider,
) async {
  final l10n = AppLocalizations.of(context)!;
  if (!await provider.channel.hasDirectoryStorageAccess()) {
    if (!context.mounted) return null;
    final ok = await showWorkspaceConfirm(
      context: context,
      title: l10n.workspaceExternalStorageTitle,
      message: l10n.workspaceExternalStorageMessage,
      confirmLabel: l10n.workspaceExternalGrantAccess,
    );
    if (!ok || !context.mounted) return null;
    if (!await provider.channel.requestDirectoryStorageAccess()) {
      throw const WorkspaceChannelException(
        code: 'external_storage_permission',
      );
    }
  }
  if (!context.mounted) return null;
  return provider.channel.pickDirectory();
}

class ExternalMountsPage extends StatefulWidget {
  const ExternalMountsPage({super.key});
  @override
  State<ExternalMountsPage> createState() => _ExternalMountsPageState();
}

class _ExternalMountsPageState extends State<ExternalMountsPage> {
  bool _picking = false;

  Future<void> _add() async {
    if (_picking) return;
    setState(() => _picking = true);
    final provider = context.read<ExternalMountsProvider>();
    WorkspaceDirectory? directory;
    try {
      await provider.loaded;
      if (provider.entries.length >= ExternalMountsProvider.maxMounts) {
        throw const WorkspaceChannelException(code: 'external_mount_limit');
      }
      if (!mounted) return;
      directory = await _pickDirectory(context, provider);
      if (directory == null || !mounted) return;
      await _editMount(context, directory: directory);
    } catch (error) {
      if (mounted) {
        showAppSnackBar(
          context,
          message: _mountError(AppLocalizations.of(context)!, error),
          type: NotificationType.error,
        );
      }
    } finally {
      if (directory != null) await provider.releaseIfUnused(directory.access);
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final provider = context.watch<ExternalMountsProvider>();
    return Scaffold(
      appBar: AppBar(
        leading: IosIconButton(
          icon: Lucide.ArrowLeft,
          color: cs.onSurface,
          size: 22,
          minSize: 44,
          tooltip: l10n.settingsPageBackButton,
          semanticLabel: l10n.settingsPageBackButton,
          onTap: () => Navigator.of(context).maybePop(),
        ),
        title: Text(l10n.workspaceExternalMount),
        actions: [
          IosIconButton(
            icon: Lucide.Plus,
            color: cs.onSurface,
            size: 22,
            minSize: 44,
            tooltip: l10n.workspaceMountAdd,
            semanticLabel: l10n.workspaceMountAdd,
            onTap: () => unawaited(_add()),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: FutureBuilder<void>(
            future: provider.loaded,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text(l10n.workspaceExternalUnavailable));
              }
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SectionCard(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(l10n.workspaceExternalMountSubtitle),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (provider.entries.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 72),
                      child: Column(
                        children: [
                          const Icon(Lucide.FolderOpen, size: 44),
                          const SizedBox(height: 16),
                          Text(l10n.workspaceMountEmpty),
                          const SizedBox(height: 16),
                          IosTileButton(
                            icon: Lucide.Plus,
                            label: l10n.workspaceMountAdd,
                            onTap: () => unawaited(_add()),
                          ),
                        ],
                      ),
                    )
                  else
                    SectionCard(
                      children: [
                        for (var i = 0; i < provider.entries.length; i++) ...[
                          if (i > 0) const IosRowDivider(),
                          IosNavRow(
                            icon: provider.entries[i].readOnly
                                ? Lucide.Lock
                                : Lucide.FolderOpen,
                            label: provider.entries[i].name,
                            subtitle:
                                '${provider.entries[i].guestPath}\n${provider.errorFor(provider.entries[i].id) != null
                                    ? l10n.workspaceMountInactive
                                    : provider.entries[i].readOnly
                                    ? l10n.workspaceMountReadOnly
                                    : l10n.workspaceMountReadWrite}',
                            onTap: () =>
                                _editMount(context, mount: provider.entries[i]),
                          ),
                        ],
                      ],
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

Future<void> _editMount(
  BuildContext context, {
  ExternalMount? mount,
  WorkspaceDirectory? directory,
}) async {
  final editor = _MountEditor(mount: mount, directory: directory);
  if (useDesktopWorkspaceLayout(context)) {
    await showAppDialog<void>(context, maxWidth: 540, child: editor);
  } else {
    await showFormSheet<void>(context, builder: (_) => editor);
  }
}

class _MountEditor extends StatefulWidget {
  const _MountEditor({this.mount, this.directory});
  final ExternalMount? mount;
  final WorkspaceDirectory? directory;
  @override
  State<_MountEditor> createState() => _MountEditorState();
}

class _MountEditorState extends State<_MountEditor> {
  late final _name = TextEditingController(
    text: widget.mount?.name ?? p.basename(widget.directory!.path),
  );
  late bool _readOnly = widget.mount?.readOnly ?? false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final provider = context.read<ExternalMountsProvider>();
    try {
      if (widget.mount case final mount?) {
        await provider.update(
          mount.id,
          name: _name.text.trim(),
          readOnly: _readOnly,
        );
      } else {
        await provider.add(
          widget.directory!,
          name: _name.text.trim(),
          readOnly: _readOnly,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = _mountError(AppLocalizations.of(context)!, error),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reconnect() async {
    final provider = context.read<ExternalMountsProvider>();
    WorkspaceDirectory? directory;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      directory = await _pickDirectory(context, provider);
      if (directory == null) return;
      await provider.update(
        widget.mount!.id,
        name: _name.text.trim(),
        readOnly: _readOnly,
        directory: directory,
      );
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = _mountError(AppLocalizations.of(context)!, error),
        );
      }
    } finally {
      if (directory != null) await provider.releaseIfUnused(directory.access);
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    final provider = context.read<ExternalMountsProvider>();
    final l10n = AppLocalizations.of(context)!;
    final ok = await showWorkspaceConfirm(
      context: context,
      title: l10n.workspaceMountUnmount,
      message: l10n.workspaceMountUnmountMessage,
      confirmLabel: l10n.workspaceMountUnmount,
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await provider.remove(widget.mount!.id);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) setState(() => _error = _mountError(l10n, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<ExternalMountsProvider>();
    final mount = widget.mount == null ? null : provider.byId(widget.mount!.id);
    final source = mount?.sourcePath ?? widget.directory?.path ?? '';
    return FormSheet(
      title: l10n.workspaceMountEdit,
      actions: FormSheetActions(
        cancelLabel: l10n.workspaceFilesCancel,
        confirmLabel: l10n.workspaceFilesSave,
        onCancel: () {
          if (!_busy) Navigator.of(context).pop();
        },
        onConfirm: _busy ? null : () => unawaited(_save()),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${ExternalMount.root}/${_name.text.trim()}',
                style: const TextStyle(fontFamily: 'monospace'),
              ),
              const SizedBox(height: 4),
              Text(
                source,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        SectionCard(
          children: [
            IosFormTextField(
              label: l10n.workspacesNameLabel,
              controller: _name,
              inlineLabel: false,
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SectionCard(
          children: [
            FormSheetSwitchRow(
              label: l10n.workspaceMountAllowWrite,
              value: !_readOnly,
              onChanged: (value) {
                if (!_busy) setState(() => _readOnly = !value);
              },
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(l10n.workspaceMountPermissionsHint),
        ),
        if (mount != null)
          SectionCard(
            children: [
              IosNavRow(
                icon: Lucide.FolderOpen,
                label: l10n.workspaceMountBrowse,
                onTap: _busy
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => _MountFilesPage(mountId: mount.id),
                        ),
                      ),
              ),
              const IosRowDivider(),
              IosNavRow(
                icon: Lucide.RefreshCw,
                label: l10n.workspaceExternalReconnect,
                onTap: _busy ? null : () => unawaited(_reconnect()),
              ),
              const IosRowDivider(),
              IosNavRow(
                icon: Lucide.Unlink,
                label: l10n.workspaceMountUnmount,
                onTap: _busy ? null : () => unawaited(_remove()),
              ),
            ],
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }
}

class _MountFilesPage extends StatefulWidget {
  const _MountFilesPage({required this.mountId});
  final String mountId;
  @override
  State<_MountFilesPage> createState() => _MountFilesPageState();
}

class _MountFilesPageState extends State<_MountFilesPage> {
  late final Future<void> _ready;
  @override
  void initState() {
    super.initState();
    _ready = context.read<ExternalMountsProvider>().resolveMounts().then(
      (_) {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExternalMountsProvider>();
    final mount = provider.byId(widget.mountId);
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IosIconButton(
          icon: Lucide.ArrowLeft,
          color: cs.onSurface,
          size: 22,
          minSize: 44,
          tooltip: l10n.settingsPageBackButton,
          semanticLabel: l10n.settingsPageBackButton,
          onTap: () => Navigator.of(context).maybePop(),
        ),
        title: Text(mount?.name ?? l10n.workspaceMountBrowse),
      ),
      body: FutureBuilder<void>(
        future: _ready,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError ||
              mount == null ||
              provider.errorFor(mount.id) != null) {
            return Center(child: Text(l10n.workspaceExternalUnavailable));
          }
          return FileBrowser(
            key: ValueKey(
              '${mount.sourcePath}:${mount.readOnly}:${mount.name}',
            ),
            root: Directory(mount.sourcePath),
            rootLabel: mount.name,
            readOnly: mount.readOnly,
            mutationRunner: (mutation) async {
              // FileBrowser has refreshed the registry and checked all targets.
              final current = provider.byId(mount.id);
              if (current == null ||
                  provider.errorFor(mount.id) != null ||
                  current.sourcePath != mount.sourcePath) {
                throw StateError(l10n.workspaceExternalUnavailable);
              }
              if (current.readOnly && mutation is! ZipDirectoryMutation) {
                throw StateError(l10n.workspaceMountReadOnly);
              }
              await FileBrowserOps.runMutation(mutation);
            },
            modelPathOf: (path) => p.posix.join(
              mount.guestPath,
              p.relative(path, from: mount.sourcePath).replaceAll('\\', '/'),
            ),
          );
        },
      ),
    );
  }
}
