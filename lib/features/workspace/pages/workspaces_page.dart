import 'dart:async';
import 'dart:io';

import 'package:Kelivo/core/models/workspace.dart';
import 'package:Kelivo/core/providers/workspace_provider.dart';
import 'package:Kelivo/core/services/haptics.dart';
import 'package:Kelivo/desktop/menu_anchor.dart';
import 'package:Kelivo/features/settings/widgets/custom_theme_widgets.dart';
import 'package:Kelivo/features/workspace/pages/workspace_files_page.dart';
import 'package:Kelivo/features/workspace/pages/workspaces_desktop_layout.dart';
import 'package:Kelivo/features/workspace/pages/workspaces_mobile_layout.dart';
import 'package:Kelivo/features/workspace/widgets/files/workspace_prompts.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/responsive/screen_type_helper.dart';
import 'package:Kelivo/shared/widgets/action_sheet.dart';
import 'package:Kelivo/shared/widgets/form_sheet.dart';
import 'package:Kelivo/shared/widgets/ios_checkbox.dart';
import 'package:Kelivo/shared/widgets/ios_form_text_field.dart';
import 'package:Kelivo/shared/widgets/ios_settings_rows.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/shared/widgets/ios_tile_button.dart';
import 'package:Kelivo/shared/widgets/section_card.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';
import 'package:Kelivo/shared/widgets/task_progress_dialog.dart';
import 'package:Kelivo/theme/app_font_weights.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

enum _CreateWorkspaceMode { managed, linked, importFromFolder }

class _CreateWorkspaceDraft {
  const _CreateWorkspaceDraft({
    required this.name,
    required this.mode,
    this.linkedPath,
  });

  final String name;
  final _CreateWorkspaceMode mode;
  final String? linkedPath;
}

/// Opens the create-workspace sheet (mobile) or dialog (desktop).
Future<Workspace?> showCreateWorkspaceFlow(BuildContext context) async {
  final draft = await _promptCreateWorkspace(context);
  if (draft == null || !context.mounted) return null;
  return _materializeWorkspace(context, draft);
}

Future<void> openWorkspacesPage(BuildContext context) {
  if (ResponsiveHelper.isDesktop(context)) {
    final l10n = AppLocalizations.of(context)!;
    final height = MediaQuery.sizeOf(context).height * 0.8;
    return showAppDialog<void>(
      context,
      maxWidth: 640,
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            AppDialogHeader(
              title: l10n.workspacesTitle,
              actions: [
                IosIconButton(
                  key: WorkspacesPane.createKey,
                  icon: Lucide.Plus,
                  size: 18,
                  tooltip: l10n.workspaceMgmtNewWorkspace,
                  semanticLabel: l10n.workspaceMgmtNewWorkspace,
                  onTap: () {
                    Haptics.light();
                    unawaited(showCreateWorkspaceFlow(context));
                  },
                ),
              ],
            ),
            const Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: WorkspacesPane(showHeader: false),
              ),
            ),
          ],
        ),
      ),
    );
  }
  return Navigator.of(
    context,
  ).push<void>(MaterialPageRoute<void>(builder: (_) => const WorkspacesPage()));
}

class WorkspacesPage extends StatelessWidget {
  const WorkspacesPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (ResponsiveHelper.isDesktop(context)) {
      return const WorkspacesDesktopLayout();
    }
    return const WorkspacesMobileLayout();
  }
}

class WorkspacesPane extends StatefulWidget {
  const WorkspacesPane({super.key, this.showHeader = true});

  final bool showHeader;

  static const Key createKey = ValueKey<String>('workspaces-create');
  static const Key emptyKey = ValueKey<String>('workspaces-empty');
  static const Key listKey = ValueKey<String>('workspaces-list');

  static Key itemKey(String id) => ValueKey<String>('workspaces-item-$id');

  static Key itemMoreKey(String id) =>
      ValueKey<String>('workspaces-item-more-$id');

  static Key actionKey(String name) =>
      ValueKey<String>('workspaces-action-$name');

  @override
  State<WorkspacesPane> createState() => WorkspacesPaneState();
}

class WorkspacesPaneState extends State<WorkspacesPane> {
  @visibleForTesting
  Future<Workspace> createManaged(String name) {
    return context.read<WorkspaceProvider>().create(name: name);
  }

  List<Workspace> _sorted(List<Workspace> workspaces) {
    final copy = List<Workspace>.from(workspaces);
    copy.sort((a, b) {
      final aUsed = a.lastUsedAt;
      final bUsed = b.lastUsedAt;
      if (aUsed == null && bUsed == null) {
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
      if (aUsed == null) return 1;
      if (bUsed == null) return -1;
      return bUsed.compareTo(aUsed);
    });
    return copy;
  }

  Future<void> _createWorkspace() async {
    await showCreateWorkspaceFlow(context);
  }

  Future<void> _rename(Workspace workspace) async {
    final l10n = AppLocalizations.of(context)!;
    final name = await showWorkspaceNamePrompt(
      context: context,
      title: l10n.workspaceFilesRename,
      label: l10n.workspacesNameLabel,
      hint: l10n.workspacesNameHint,
      confirmLabel: l10n.workspaceFilesSave,
      initial: workspace.name,
    );
    if (name == null || !mounted) return;
    await context.read<WorkspaceProvider>().update(
      workspace.copyWith(name: name),
    );
  }

  Future<void> _editSettings(Workspace workspace) async {
    await showWorkspaceSettingsEditor(context, workspace);
  }

  Future<void> _delete(Workspace workspace) async {
    final l10n = AppLocalizations.of(context)!;
    final linked = workspace.kind == WorkspaceKind.linked;
    var deleteFiles = !linked;
    final confirmed = await showWorkspaceConfirm(
      context: context,
      title: linked ? l10n.workspacesUnlinkTitle : l10n.workspacesDeleteTitle,
      message: linked
          ? l10n.workspacesUnlinkMessage(workspace.name)
          : l10n.workspacesDeleteMessage(workspace.name),
      confirmLabel: linked ? l10n.workspacesUnlink : l10n.workspaceFilesDelete,
      destructive: true,
      extra: linked
          ? null
          : _DeleteFilesToggle(
              label: l10n.workspacesDeleteAlsoFiles,
              value: deleteFiles,
              onChanged: (value) => deleteFiles = value,
            ),
    );
    if (!confirmed || !mounted) return;
    await context.read<WorkspaceProvider>().delete(
      workspace.id,
      deleteFiles: linked ? false : deleteFiles,
    );
  }

  void _openFiles(Workspace workspace) {
    unawaited(WorkspaceFilesPage.open(context, workspaceId: workspace.id));
  }

  Future<void> _showItemActions(
    Workspace workspace, {
    Offset? globalPosition,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    await showAdaptiveActionMenu(
      context,
      anchor: globalPosition ?? DesktopMenuAnchor.positionOrCenter(context),
      title: l10n.workspacesItemMore,
      items: [
        ActionSheetItem(
          icon: Lucide.Pencil,
          label: l10n.workspaceFilesRename,
          onTap: () => unawaited(_rename(workspace)),
        ),
        ActionSheetItem(
          icon: Lucide.Settings,
          label: l10n.workspacesSettings,
          onTap: () => unawaited(_editSettings(workspace)),
        ),
        ActionSheetItem(
          icon: Lucide.Trash,
          label: workspace.kind == WorkspaceKind.linked
              ? l10n.workspacesUnlink
              : l10n.workspaceFilesDelete,
          destructive: true,
          onTap: () => unawaited(_delete(workspace)),
        ),
      ],
    );
  }

  Widget _header(AppLocalizations l10n, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.workspacesTitle,
              style: TextStyle(
                fontSize: 16,
                fontWeight: AppFontWeights.emphasis,
                color: cs.onSurface,
              ),
            ),
          ),
          IosIconButton(
            key: WorkspacesPane.createKey,
            icon: Lucide.Plus,
            tooltip: l10n.workspaceMgmtNewWorkspace,
            semanticLabel: l10n.workspaceMgmtNewWorkspace,
            onTap: () {
              Haptics.light();
              unawaited(_createWorkspace());
            },
          ),
        ],
      ),
    );
  }

  Widget _emptyState(AppLocalizations l10n, ColorScheme cs) {
    final child = Padding(
      key: WorkspacesPane.emptyKey,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Lucide.FolderCode,
            size: 44,
            color: cs.onSurface.withValues(alpha: 0.26),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.workspacesEmpty,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: AppFontWeights.semibold,
              color: cs.onSurface.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.workspaceMgmtEmptyHint,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: cs.onSurface.withValues(alpha: 0.52),
            ),
          ),
          const SizedBox(height: 16),
          IosTileButton(
            icon: Lucide.Plus,
            label: l10n.workspaceMgmtNewWorkspace,
            onTap: () => unawaited(_createWorkspace()),
          ),
        ],
      ),
    );
    return child.animate().fadeIn(duration: 200.ms);
  }

  Widget _list(List<Workspace> workspaces, AppLocalizations l10n) {
    return SectionCard(
      key: WorkspacesPane.listKey,
      children: [
        for (var i = 0; i < workspaces.length; i++) ...[
          if (i > 0) const IosRowDivider(),
          _WorkspaceRow(
            workspace: workspaces[i],
            onOpen: () => _openFiles(workspaces[i]),
            onMore: (pos) =>
                unawaited(_showItemActions(workspaces[i], globalPosition: pos)),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final provider = context.watch<WorkspaceProvider>();
    final workspaces = _sorted(provider.workspaces);

    return LayoutBuilder(
      builder: (context, constraints) {
        final header = widget.showHeader ? _header(l10n, cs) : null;
        if (workspaces.isEmpty) {
          final empty = _emptyState(l10n, cs);
          if (!constraints.hasBoundedHeight) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [if (header != null) header, empty],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (header != null) header,
              Expanded(
                child: LayoutBuilder(
                  builder: (context, inner) {
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: inner.maxHeight),
                        child: Center(child: empty),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        }

        final list = _list(workspaces, l10n);
        if (!constraints.hasBoundedHeight) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [if (header != null) header, list],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (header != null) header,
            Expanded(child: SingleChildScrollView(child: list)),
          ],
        );
      },
    );
  }
}

class _WorkspaceRow extends StatelessWidget {
  const _WorkspaceRow({
    required this.workspace,
    required this.onOpen,
    required this.onMore,
  });

  final Workspace workspace;
  final VoidCallback onOpen;
  final ValueChanged<Offset?> onMore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final kind = workspace.kind == WorkspaceKind.linked
        ? l10n.workspaceFilesKindLinked
        : l10n.workspaceFilesKindManaged;
    final used = workspace.lastUsedAt;
    final detail = used == null
        ? l10n.workspaceMgmtRowDetailNever(kind)
        : l10n.workspaceMgmtRowDetail(
            kind,
            workspaceMgmtRelativeTime(l10n, used),
          );

    final row = IosNavRow(
      key: WorkspacesPane.itemKey(workspace.id),
      icon: workspace.kind == WorkspaceKind.linked
          ? Lucide.Link
          : Lucide.FolderCode,
      label: workspace.name,
      labelWeight: AppFontWeights.medium,
      subtitle: detail,
      onTap: onOpen,
      onLongPress: () => onMore(null),
      trailing: Builder(
        builder: (buttonContext) {
          return IosIconButton(
            key: WorkspacesPane.itemMoreKey(workspace.id),
            icon: Lucide.Ellipsis,
            size: 18,
            tooltip: l10n.workspacesItemMore,
            semanticLabel: l10n.workspacesItemMore,
            onTap: () {
              final box = buttonContext.findRenderObject();
              if (box is RenderBox) {
                onMore(box.localToGlobal(box.size.center(Offset.zero)));
              } else {
                onMore(null);
              }
            },
          );
        },
      ),
    );
    return GestureDetector(
      onSecondaryTapDown: (details) {
        DesktopMenuAnchor.setPosition(details.globalPosition);
        onMore(details.globalPosition);
      },
      child: row,
    );
  }
}

class _DeleteFilesToggle extends StatefulWidget {
  const _DeleteFilesToggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  State<_DeleteFilesToggle> createState() => _DeleteFilesToggleState();
}

class _DeleteFilesToggleState extends State<_DeleteFilesToggle> {
  late bool _value = widget.value;

  @override
  Widget build(BuildContext context) {
    return IosCardPress(
      onTap: () {
        setState(() => _value = !_value);
        widget.onChanged(_value);
      },
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          IosCheckbox(
            value: _value,
            semanticLabel: widget.label,
            onChanged: (value) {
              setState(() => _value = value);
              widget.onChanged(value);
            },
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(widget.label)),
        ],
      ),
    );
  }
}

Future<_CreateWorkspaceDraft?> _promptCreateWorkspace(
  BuildContext context,
) async {
  final l10n = AppLocalizations.of(context)!;
  final desktop = ResponsiveHelper.isDesktop(context);
  if (desktop) {
    return showAppDialog<_CreateWorkspaceDraft>(
      context,
      maxWidth: 480,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppDialogHeader(title: l10n.workspacesCreateTitle),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: _CreateWorkspaceForm(desktop: true),
          ),
        ],
      ),
    );
  }
  return showFormSheet<_CreateWorkspaceDraft>(
    context,
    builder: (ctx) => const _CreateWorkspaceForm(desktop: false),
  );
}

class _CreateWorkspaceForm extends StatefulWidget {
  const _CreateWorkspaceForm({required this.desktop});

  final bool desktop;

  @override
  State<_CreateWorkspaceForm> createState() => _CreateWorkspaceFormState();
}

class _CreateWorkspaceFormState extends State<_CreateWorkspaceForm> {
  final TextEditingController _nameController = TextEditingController();
  _CreateWorkspaceMode _mode = _CreateWorkspaceMode.managed;
  String? _linkedPath;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickLinkedFolder() async {
    final l10n = AppLocalizations.of(context)!;
    String? path;
    try {
      path = await FilePicker.platform.getDirectoryPath(
        dialogTitle: l10n.workspacesLinkFolder,
      );
    } catch (_) {
      path = null;
    }
    if (!mounted) return;
    if (path == null) {
      showAppSnackBar(
        context,
        message: l10n.workspaceMgmtFolderPickerUnavailable,
        type: NotificationType.info,
      );
      return;
    }
    setState(() {
      _linkedPath = path;
      _mode = _CreateWorkspaceMode.linked;
      if (_nameController.text.trim().isEmpty) {
        _nameController.text = p.basename(path!);
      }
    });
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(
      _CreateWorkspaceDraft(name: name, mode: _mode, linkedPath: _linkedPath),
    );
  }

  Widget _kindCheck(bool selected) {
    final cs = Theme.of(context).colorScheme;
    return selected
        ? Icon(Lucide.Check, size: 18, color: cs.primary)
        : const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final canCreate = _nameController.text.trim().isNotEmpty;
    final children = <Widget>[
      SectionCard(
        children: [
          IosFormTextField(
            label: l10n.workspacesNameLabel,
            controller: _nameController,
            hintText: l10n.workspacesNameHint,
            inlineLabel: false,
            autofocus: true,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      IosSectionHeader(text: l10n.workspaceMgmtKindSection),
      SectionCard(
        children: [
          IosNavRow(
            icon: Lucide.FolderCode,
            label: l10n.workspaceMgmtKindManagedTitle,
            subtitle: l10n.workspaceMgmtKindManagedSubtitle,
            labelWeight: AppFontWeights.medium,
            trailing: _kindCheck(_mode == _CreateWorkspaceMode.managed),
            onTap: () => setState(() => _mode = _CreateWorkspaceMode.managed),
          ),
          const IosRowDivider(),
          if (widget.desktop)
            IosNavRow(
              icon: Lucide.Link,
              label: l10n.workspaceMgmtKindLinkedTitle,
              subtitle: _linkedPath ?? l10n.workspaceMgmtKindLinkedSubtitle,
              labelWeight: AppFontWeights.medium,
              trailing: _kindCheck(_mode == _CreateWorkspaceMode.linked),
              onTap: () => unawaited(_pickLinkedFolder()),
            )
          else
            IosNavRow(
              icon: Lucide.FolderInput,
              label: l10n.workspaceMgmtImportFromFolder,
              subtitle: l10n.workspaceMgmtImportFromFolderSubtitle,
              labelWeight: AppFontWeights.medium,
              trailing: _kindCheck(
                _mode == _CreateWorkspaceMode.importFromFolder,
              ),
              onTap: () =>
                  setState(() => _mode = _CreateWorkspaceMode.importFromFolder),
            ),
        ],
      ),
    ];
    final actions = FormSheetActions(
      key: const ValueKey<String>('workspaces-create-confirm'),
      cancelLabel: l10n.workspaceFilesCancel,
      confirmLabel: l10n.workspaceMgmtCreate,
      onCancel: () => Navigator.of(context).pop(),
      onConfirm: canCreate ? _submit : null,
    );

    if (widget.desktop) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [...children, const SizedBox(height: 16), actions],
      );
    }

    return FormSheet(
      title: l10n.workspacesCreateTitle,
      actions: actions,
      children: children,
    );
  }
}

Future<Workspace?> _materializeWorkspace(
  BuildContext context,
  _CreateWorkspaceDraft draft,
) async {
  final provider = context.read<WorkspaceProvider>();
  final l10n = AppLocalizations.of(context)!;
  switch (draft.mode) {
    case _CreateWorkspaceMode.managed:
      return provider.create(name: draft.name);
    case _CreateWorkspaceMode.linked:
      var path = draft.linkedPath;
      if (path == null || path.isEmpty) {
        try {
          path = await FilePicker.platform.getDirectoryPath(
            dialogTitle: l10n.workspacesLinkFolder,
          );
        } catch (_) {
          path = null;
        }
      }
      if (!context.mounted) return null;
      if (path == null) {
        showAppSnackBar(
          context,
          message: l10n.workspaceMgmtFolderPickerUnavailable,
          type: NotificationType.info,
        );
        return null;
      }
      final name = draft.name.isEmpty ? p.basename(path) : draft.name;
      return provider.create(
        name: name,
        kind: WorkspaceKind.linked,
        hostPath: path,
      );
    case _CreateWorkspaceMode.importFromFolder:
      return _importFromFolder(context, draft.name);
  }
}

Future<Workspace?> _importFromFolder(BuildContext context, String name) async {
  final l10n = AppLocalizations.of(context)!;
  String? path;
  try {
    path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: l10n.workspaceMgmtImportFromFolder,
    );
  } catch (_) {
    path = null;
  }
  if (!context.mounted) return null;
  if (path == null) {
    showAppSnackBar(
      context,
      message: l10n.workspaceMgmtFolderPickerUnavailable,
      type: NotificationType.info,
    );
    return null;
  }

  final provider = context.read<WorkspaceProvider>();
  var fraction = 0.0;
  var outcome = TaskProgressOutcome.running;
  var phase = l10n.workspaceMgmtImportProgressPhase;
  Object? error;
  VoidCallback? refresh;

  final dialogFuture = showAppDialog<void>(
    context,
    dismissible: false,
    child: StatefulBuilder(
      builder: (ctx, setLocal) {
        refresh = () => setLocal(() {});
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: TaskProgressDialogCard(
            title: l10n.workspaceMgmtImportProgressTitle,
            phaseLabel: phase,
            fraction: fraction,
            phaseIcon: Lucide.FolderInput,
            cancellable: false,
            outcome: outcome,
            onAcknowledge: outcome == TaskProgressOutcome.failure
                ? () => Navigator.of(ctx).pop()
                : null,
            acknowledgeLabel: l10n.workspaceFilesCancel,
          ),
        );
      },
    ),
  );

  Workspace? created;
  try {
    created = await provider.create(name: name);
    final dest = await provider.hostRootFor(created);
    await _copyDirectoryTree(
      Directory(path),
      Directory(dest),
      onProgress: (value) {
        fraction = value;
        refresh?.call();
      },
    );
    outcome = TaskProgressOutcome.success;
    phase = l10n.workspaceMgmtImportDone(name);
    refresh?.call();
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    if (context.mounted) {
      showAppSnackBar(
        context,
        message: l10n.workspaceMgmtImportDone(name),
        type: NotificationType.success,
      );
    }
  } catch (e) {
    error = e;
    outcome = TaskProgressOutcome.failure;
    phase = l10n.workspaceMgmtImportFailed;
    refresh?.call();
    if (created != null) {
      await provider.delete(created.id, deleteFiles: true);
      created = null;
    }
  }
  await dialogFuture;
  if (error != null && context.mounted) {
    showAppSnackBar(
      context,
      message: l10n.workspaceMgmtImportFailed,
      type: NotificationType.error,
    );
  }
  return created;
}

Future<void> _copyDirectoryTree(
  Directory source,
  Directory dest, {
  required ValueChanged<double> onProgress,
}) async {
  if (!await dest.exists()) {
    await dest.create(recursive: true);
  }
  final files = <File>[];
  await for (final entity in source.list(recursive: true, followLinks: false)) {
    if (entity is File) files.add(entity);
    if (entity is Directory) {
      final rel = p.relative(entity.path, from: source.path);
      await Directory(p.join(dest.path, rel)).create(recursive: true);
    }
  }
  if (files.isEmpty) {
    onProgress(1);
    return;
  }
  var done = 0;
  for (final file in files) {
    final rel = p.relative(file.path, from: source.path);
    final target = File(p.join(dest.path, rel));
    await target.parent.create(recursive: true);
    await file.copy(target.path);
    done += 1;
    onProgress(done / files.length);
  }
}

Future<void> showWorkspaceSettingsEditor(
  BuildContext context,
  Workspace workspace,
) async {
  final l10n = AppLocalizations.of(context)!;
  if (ResponsiveHelper.isDesktop(context)) {
    await showAppDialog<void>(
      context,
      maxWidth: 480,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppDialogHeader(title: l10n.workspacesSettingsTitle),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: _WorkspaceSettingsForm(
              workspaceId: workspace.id,
              desktop: true,
            ),
          ),
        ],
      ),
    );
    return;
  }
  await showFormSheet<void>(
    context,
    builder: (ctx) =>
        _WorkspaceSettingsForm(workspaceId: workspace.id, desktop: false),
  );
}

class _WorkspaceSettingsForm extends StatefulWidget {
  const _WorkspaceSettingsForm({
    required this.workspaceId,
    required this.desktop,
  });

  final String workspaceId;
  final bool desktop;

  @override
  State<_WorkspaceSettingsForm> createState() => _WorkspaceSettingsFormState();
}

class _WorkspaceSettingsFormState extends State<_WorkspaceSettingsForm> {
  TextEditingController? _nameController;
  bool? _shellNeedsApproval;
  String? _defaultCwd;
  bool _cwdBusy = false;

  Workspace? get _workspace =>
      context.read<WorkspaceProvider>().byId(widget.workspaceId);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final workspace = context.read<WorkspaceProvider>().byId(
      widget.workspaceId,
    );
    if (workspace == null) return;
    _nameController ??= TextEditingController(text: workspace.name);
    _shellNeedsApproval ??= workspace.shellNeedsApproval;
    _defaultCwd ??= workspace.defaultCwd;
  }

  @override
  void dispose() {
    _nameController?.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final workspace = _workspace;
    final controller = _nameController;
    if (workspace == null || controller == null) return;
    final name = controller.text.trim();
    if (name.isEmpty) return;
    await context.read<WorkspaceProvider>().update(
      workspace.copyWith(
        name: name,
        shellNeedsApproval: _shellNeedsApproval ?? workspace.shellNeedsApproval,
        defaultCwd: _defaultCwd ?? workspace.defaultCwd,
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickCwd() async {
    final workspace = _workspace;
    if (workspace == null || _cwdBusy) return;
    setState(() => _cwdBusy = true);
    try {
      final l10n = AppLocalizations.of(context)!;
      final root = await context.read<WorkspaceProvider>().hostRootFor(
        workspace,
      );
      if (!mounted) return;
      final picked = await showWorkspaceFolderPicker(
        context,
        root: root,
        initialRelPath: _defaultCwd ?? workspace.defaultCwd,
        title: l10n.workspaceMgmtPickCwdTitle,
      );
      if (picked == null || !mounted) return;
      setState(() => _defaultCwd = picked);
    } finally {
      if (mounted) setState(() => _cwdBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final workspace = context.watch<WorkspaceProvider>().byId(
      widget.workspaceId,
    );
    if (workspace == null) {
      return const SizedBox.shrink();
    }
    final controller = _nameController;
    final approval = _shellNeedsApproval ?? workspace.shellNeedsApproval;
    final cwdRaw = _defaultCwd ?? workspace.defaultCwd;
    if (controller == null) {
      return const Center(child: CupertinoActivityIndicator(radius: 12));
    }
    final cwd = cwdRaw.trim().isEmpty
        ? l10n.workspaceMgmtDefaultCwdRoot
        : cwdRaw;
    final canSave = controller.text.trim().isNotEmpty;
    final children = <Widget>[
      SectionCard(
        children: [
          IosFormTextField(
            label: l10n.workspacesNameLabel,
            controller: controller,
            hintText: l10n.workspacesNameHint,
            inlineLabel: false,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      const SizedBox(height: 12),
      SectionCard(
        children: [
          FormSheetSwitchRow(
            label: l10n.workspacesShellNeedsApproval,
            value: approval,
            onChanged: (value) => setState(() => _shellNeedsApproval = value),
          ),
          const IosRowDivider(),
          IosNavRow(
            icon: Lucide.FolderCode,
            label: l10n.workspacesDefaultCwd,
            detailText: cwd,
            trailing: _cwdBusy
                ? const CupertinoActivityIndicator(radius: 8)
                : null,
            onTap: _cwdBusy ? null : () => unawaited(_pickCwd()),
          ),
        ],
      ),
    ];
    final actions = FormSheetActions(
      cancelLabel: l10n.workspaceFilesCancel,
      confirmLabel: l10n.workspaceFilesSave,
      onCancel: () => Navigator.of(context).pop(),
      onConfirm: canSave ? () => unawaited(_save()) : null,
    );

    if (widget.desktop) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [...children, const SizedBox(height: 16), actions],
      );
    }

    return FormSheet(
      title: l10n.workspacesSettingsTitle,
      actions: actions,
      children: children,
    );
  }
}

String workspaceMgmtRelativeTime(AppLocalizations l10n, DateTime at) {
  final delta = DateTime.now().difference(at.toLocal());
  if (delta.inMinutes < 1) return l10n.workspaceMgmtLastUsedJustNow;
  if (delta.inHours < 1) {
    return l10n.workspaceMgmtLastUsedMinutesAgo(delta.inMinutes);
  }
  if (delta.inDays < 1) {
    return l10n.workspaceMgmtLastUsedHoursAgo(delta.inHours);
  }
  return l10n.workspaceMgmtLastUsedDaysAgo(delta.inDays);
}

List<Widget> workspaceMgmtCreateActions(BuildContext context, {Key? key}) {
  final l10n = AppLocalizations.of(context)!;
  final cs = Theme.of(context).colorScheme;
  return [
    IosIconButton(
      key: key ?? WorkspacesPane.createKey,
      icon: Lucide.Plus,
      color: cs.onSurface,
      size: 22,
      minSize: 44,
      tooltip: l10n.workspaceMgmtNewWorkspace,
      semanticLabel: l10n.workspaceMgmtNewWorkspace,
      onTap: () {
        Haptics.light();
        unawaited(showCreateWorkspaceFlow(context));
      },
    ),
    const SizedBox(width: 12),
  ];
}
