import 'dart:async';
import 'dart:io';

import 'package:Kelivo/core/services/haptics.dart';
import 'package:Kelivo/core/providers/external_mounts_provider.dart';
import 'package:Kelivo/core/services/sandbox/workspace_channel.dart';
import 'package:Kelivo/features/settings/widgets/custom_theme_widgets.dart';
import 'package:Kelivo/features/chat/widgets/workspace_tool_ui.dart'
    show workspaceFileTypeIcon;
import 'package:Kelivo/features/workspace/widgets/desktop_workspace_button.dart';
import 'package:Kelivo/features/workspace/widgets/files/file_browser_ops.dart';
import 'package:Kelivo/features/workspace/widgets/files/workspace_prompts.dart';
import 'package:Kelivo/features/workspace/widgets/files/workspace_file_thumbnail.dart';
import 'package:Kelivo/features/workspace/widgets/preview/file_preview.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/features/workspace/workspace_layout.dart';
import 'package:Kelivo/shared/utils/format_bytes.dart';
import 'package:Kelivo/shared/utils/save_file_picker.dart';
import 'package:Kelivo/shared/widgets/action_sheet.dart';
import 'package:Kelivo/shared/widgets/custom_bottom_sheet.dart';
import 'package:Kelivo/shared/widgets/ios_settings_rows.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/shared/widgets/ios_tile_button.dart';
import 'package:Kelivo/shared/widgets/option_sheet.dart';
import 'package:Kelivo/shared/widgets/section_card.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';
import 'package:Kelivo/theme/app_font_weights.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

enum _FileItemAction { preview, rename, move, share, copyPath, export, delete }

typedef FileMutationRunner = Future<void> Function(FileMutation mutation);

/// AppBar actions for a page that hosts [FileBrowser] with `showToolbar: false`.
/// Phones get sort / ＋ / ⋯; desktop keeps the full icon row.
List<Widget> fileBrowserToolbarActions(FileBrowserState state) {
  return state.pageAppBarActions();
}

Future<String?> showWorkspaceFolderPicker(
  BuildContext context, {
  required String root,
  String? initialRelPath,
  required String title,
  String? rootLabel,
  String? excludePath,
}) {
  Widget browser(BuildContext ctx, [ScrollController? scrollController]) {
    return FileBrowser(
      root: Directory(root),
      rootLabel: rootLabel ?? title,
      initialRelativePath: initialRelPath,
      pickDirectoryMode: true,
      excludePath: excludePath,
      onPickDirectory: (rel) => Navigator.of(ctx).pop(rel),
      modelPathOf: (host) => host,
      scrollController: scrollController,
    );
  }

  if (useDesktopWorkspaceLayout(context)) {
    final height = (MediaQuery.sizeOf(context).height * 0.7).clamp(
      360.0,
      640.0,
    );
    return showAppDialog<String>(
      context,
      maxWidth: 520,
      child: SizedBox(
        height: height,
        child: Builder(
          builder: (ctx) {
            return Column(
              children: [
                AppDialogHeader(title: title),
                Expanded(child: browser(ctx)),
              ],
            );
          },
        ),
      ),
    );
  }

  return showCustomBottomSheet<String>(
    context: context,
    title: title,
    partialHeightFactor: 0.90,
    expandedHeightFactor: 0.90,
    builder: browser,
  );
}

class FileBrowser extends StatefulWidget {
  const FileBrowser({
    super.key,
    required this.root,
    required this.rootLabel,
    required this.modelPathOf,
    this.readOnly = false,
    this.pickDirectoryMode = false,
    this.onPickDirectory,
    this.mutationRunner,
    this.showToolbar = true,
    this.initialRelativePath,
    this.excludePath,
    this.emptyIcon,
    this.emptyTitle,
    this.emptyHint,
    this.onOpenTerminal,
    this.scrollController,
  });

  final Directory root;
  final String rootLabel;
  final String Function(String hostPath) modelPathOf;
  final bool readOnly;
  final bool pickDirectoryMode;
  final ValueChanged<String>? onPickDirectory;
  final FileMutationRunner? mutationRunner;
  final bool showToolbar;
  final String? initialRelativePath;
  final String? excludePath;
  final IconData? emptyIcon;
  final String? emptyTitle;
  final String? emptyHint;
  final VoidCallback? onOpenTerminal;

  /// The host's scroll controller, when it needs to read the list's offset —
  /// a bottom sheet decides from it whether a downward drag scrolls the list or
  /// pulls the sheet down.
  final ScrollController? scrollController;

  static const Key emptyKey = ValueKey<String>('file-browser-empty');
  static const Key errorKey = ValueKey<String>('file-browser-error');
  static const Key listKey = ValueKey<String>('file-browser-list');
  static const Key hiddenToggleKey = ValueKey<String>('file-browser-hidden');
  static const Key sortButtonKey = ValueKey<String>('file-browser-sort');
  static const Key refreshKey = ValueKey<String>('file-browser-refresh');
  static const Key newKey = ValueKey<String>('file-browser-new');
  static const Key newFolderKey = ValueKey<String>('file-browser-new-folder');
  static const Key newFileKey = ValueKey<String>('file-browser-new-file');
  static const Key importKey = ValueKey<String>('file-browser-import');
  static const Key exportKey = ValueKey<String>('file-browser-export');
  static const Key moreKey = ValueKey<String>('file-browser-more');
  static const Key terminalKey = ValueKey<String>('file-browser-terminal');
  static const Key pickBarKey = ValueKey<String>('file-browser-pick-bar');
  static const Key toolbarRowKey = ValueKey<String>('file-browser-toolbar-row');
  static const Key pickDirectoryKey = ValueKey<String>(
    'file-browser-pick-directory',
  );

  /// Embedded toolbars narrower than this collapse actions to ＋ / ⋯.
  static const double compactToolbarBreakpoint = 360;
  static const Key foldersFirstKey = ValueKey<String>(
    'file-browser-folders-first',
  );

  static Key itemKey(String name) =>
      ValueKey<String>('file-browser-item-$name');

  static Key itemMoreKey(String name) =>
      ValueKey<String>('file-browser-item-more-$name');

  static Key breadcrumbKey(String label) =>
      ValueKey<String>('file-browser-crumb-$label');

  static Key actionKey(String name) =>
      ValueKey<String>('file-browser-action-$name');

  @override
  FileBrowserState createState() => FileBrowserState();
}

class FileBrowserState extends State<FileBrowser> {
  final ScrollController _desktopScroll = ScrollController();
  final List<String> _segments = <String>[];
  final GlobalKey _sortAnchorKey = GlobalKey();
  final GlobalKey _newAnchorKey = GlobalKey();
  final GlobalKey _moreAnchorKey = GlobalKey();
  List<FileBrowserEntry> _entries = const <FileBrowserEntry>[];
  Object? _error;
  bool _loading = true;
  bool _showHidden = false;
  FileBrowserSortField _sort = FileBrowserSortField.name;
  bool _ascending = true;
  bool _foldersFirst = true;

  String get _rootPath => FileBrowserOps.canonicalize(widget.root.path);

  String get currentRelPath => _segments.join('/');

  Directory get _currentDir {
    final rel = _segments.isEmpty ? '.' : _segments.join('/');
    final resolved = FileBrowserOps.joinInsideRoot(_rootPath, rel);
    if (resolved == null) return Directory(_rootPath);
    return Directory(resolved);
  }

  bool get _canCreateFolder => !widget.readOnly || widget.pickDirectoryMode;

  bool get _canMutateFiles => !widget.readOnly && !widget.pickDirectoryMode;

  @override
  void initState() {
    super.initState();
    _applyInitialPath();
    unawaited(refreshEntries());
  }

  @override
  void dispose() {
    _desktopScroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant FileBrowser oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.root.path != widget.root.path) {
      _segments.clear();
      _applyInitialPath();
      unawaited(refreshEntries());
    }
  }

  void _applyInitialPath() {
    final rel = widget.initialRelativePath;
    if (rel == null || rel.isEmpty) return;
    final resolved = FileBrowserOps.joinInsideRoot(_rootPath, rel);
    if (resolved == null) return;
    if (!Directory(resolved).existsSync()) return;
    final relative = FileBrowserOps.posixRelative(_rootPath, resolved);
    if (relative == null || relative.isEmpty) return;
    _segments
      ..clear()
      ..addAll(relative.split('/').where((part) => part.isNotEmpty));
  }

  @visibleForTesting
  Future<void> refreshEntries() => _reload();

  Future<void> _runMutation(FileMutation mutation) async {
    final mounts = context.read<ExternalMountsProvider?>();
    final readOnlyMessage = AppLocalizations.of(
      context,
    )!.workspaceMountReadOnly;
    try {
      await mounts?.requireWritableHostPaths(mutation.writePaths);
    } on WorkspaceChannelException catch (error) {
      if (error.code == 'mount_readonly') throw StateError(readOnlyMessage);
      rethrow;
    }
    final runner = widget.mutationRunner ?? FileBrowserOps.runMutation;
    await runner(mutation);
  }

  Future<void> _reload() async {
    try {
      var dir = _currentDir;
      while (_segments.isNotEmpty && !await dir.exists()) {
        _segments.removeLast();
        dir = _currentDir;
      }
      if (!await Directory(_rootPath).exists()) {
        throw StateError('root missing');
      }
      final entries = await FileBrowserOps.listDir(
        dir,
        rootPath: _rootPath,
        showHidden: _showHidden,
        sort: _sort,
        ascending: _ascending,
        foldersFirst: _foldersFirst,
        directoriesOnly: widget.pickDirectoryMode,
        excludePath: widget.excludePath,
      );
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _entries = const <FileBrowserEntry>[];
        _loading = false;
      });
    }
  }

  void _jumpTo(int depth) {
    setState(() {
      if (depth <= 0) {
        _segments.clear();
      } else if (depth < _segments.length) {
        _segments.removeRange(depth, _segments.length);
      }
    });
    unawaited(_reload());
  }

  bool _popStack() {
    if (_segments.isEmpty) return false;
    setState(() => _segments.removeLast());
    unawaited(_reload());
    return true;
  }

  Future<void> _openEntry(FileBrowserEntry entry) async {
    if (entry.isDirectory) {
      final resolved = FileBrowserOps.resolveInsideRoot(
        _rootPath,
        entry.hostPath,
      );
      if (resolved == null) {
        _showEscapeRefused();
        return;
      }
      setState(() => _segments.add(entry.name));
      await _reload();
      return;
    }
    if (widget.pickDirectoryMode) return;
    if (!mounted) return;
    await showFilePreview(context, File(entry.hostPath), title: entry.name);
  }

  void _showSnack(String message, NotificationType type) {
    showAppSnackBar(context, message: message, type: type);
  }

  void _showEscapeRefused() {
    final l10n = AppLocalizations.of(context)!;
    _showSnack(l10n.workspaceFilesInvalidPath, NotificationType.error);
  }

  Future<void> _handleError(Object error) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    _showSnack(
      l10n.workspaceFilesOperationFailed('$error'),
      NotificationType.error,
    );
  }

  Future<void> _promptNewFolder() async {
    if (!_canCreateFolder) return;
    final l10n = AppLocalizations.of(context)!;
    final name = await showWorkspaceNamePrompt(
      context: context,
      title: l10n.workspaceFilesNewFolder,
      label: l10n.workspaceFilesNameLabel,
      hint: l10n.workspaceFilesNameHint,
      confirmLabel: l10n.workspaceFilesCreate,
    );
    if (name == null || !mounted) return;
    if (!FileBrowserOps.isValidFileName(name)) {
      _showSnack(l10n.workspaceFilesInvalidName, NotificationType.error);
      return;
    }
    try {
      await _runMutation(
        CreateFolderMutation(
          rootPath: _rootPath,
          parentPath: _currentDir.path,
          name: name,
        ),
      );
      await _reload();
    } catch (e) {
      await _handleError(e);
    }
  }

  Future<void> _promptNewFile() async {
    if (!_canMutateFiles) return;
    final l10n = AppLocalizations.of(context)!;
    final name = await showWorkspaceNamePrompt(
      context: context,
      title: l10n.workspaceFilesNewFile,
      label: l10n.workspaceFilesNameLabel,
      hint: l10n.workspaceFilesNameHint,
      confirmLabel: l10n.workspaceFilesCreate,
    );
    if (name == null || !mounted) return;
    if (!FileBrowserOps.isValidFileName(name)) {
      _showSnack(l10n.workspaceFilesInvalidName, NotificationType.error);
      return;
    }
    try {
      await _runMutation(
        CreateFileMutation(
          rootPath: _rootPath,
          parentPath: _currentDir.path,
          name: name,
        ),
      );
      await _reload();
    } catch (e) {
      await _handleError(e);
    }
  }

  Future<void> _importFiles() async {
    if (!_canMutateFiles) return;
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(allowMultiple: true);
    } catch (e) {
      await _handleError(e);
      return;
    }
    if (result == null || !mounted) return;
    try {
      for (final file in result.files) {
        final path = file.path;
        if (path == null || path.isEmpty) continue;
        await _runMutation(
          CopyIntoMutation(
            rootPath: _rootPath,
            sourcePath: path,
            destDirPath: _currentDir.path,
          ),
        );
      }
      await _reload();
    } catch (e) {
      await _handleError(e);
    }
  }

  Future<({File file, String fileName})?> _zipDirectory(
    Directory dir, {
    required String name,
  }) async {
    final zipName = _safeFileName(name.isEmpty ? widget.rootLabel : name);
    final temp = File(
      p.join(
        Directory.systemTemp.path,
        'kelivo-$zipName-${DateTime.now().microsecondsSinceEpoch}.zip',
      ),
    );
    await _runMutation(
      ZipDirectoryMutation(
        rootPath: _rootPath,
        sourcePath: dir.path,
        destPath: temp.path,
      ),
    );
    if (!mounted) return null;
    return (file: temp, fileName: '$zipName.zip');
  }

  Future<void> _exportDirectory(Directory dir, {required String name}) async {
    try {
      final zipped = await _zipDirectory(dir, name: name);
      if (zipped == null) return;
      await _exportFile(zipped.file, fileName: zipped.fileName);
    } catch (e) {
      await _handleError(e);
    }
  }

  Future<void> _shareDirectory(Directory dir, {required String name}) async {
    try {
      final zipped = await _zipDirectory(dir, name: name);
      if (zipped == null) return;
      await _shareFile(zipped.file, fileName: zipped.fileName);
    } catch (e) {
      await _handleError(e);
    }
  }

  Future<void> _shareFile(File file, {required String fileName}) async {
    if (!mounted) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, name: fileName)],
        sharePositionOrigin: _shareAnchor(context),
      ),
    );
  }

  Future<void> _exportFile(File file, {required String fileName}) async {
    final l10n = AppLocalizations.of(context)!;
    final savePath = await saveHostFileWithPicker(
      file: file,
      fileName: fileName,
      dialogTitle: l10n.workspaceFilesExport,
    );
    if (savePath == null || !mounted) return;
    _showSnack(
      l10n.messageExportSheetExportedAs(p.basename(savePath)),
      NotificationType.success,
    );
  }

  Future<void> _performAction(
    _FileItemAction action,
    FileBrowserEntry entry,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    switch (action) {
      case _FileItemAction.preview:
        await _openEntry(entry);
      case _FileItemAction.rename:
        await _rename(entry);
      case _FileItemAction.move:
        await _move(entry);
      case _FileItemAction.share:
        try {
          if (entry.isDirectory) {
            await _shareDirectory(Directory(entry.hostPath), name: entry.name);
          } else {
            await _shareFile(File(entry.hostPath), fileName: entry.name);
          }
        } catch (e) {
          await _handleError(e);
        }
      case _FileItemAction.copyPath:
        await Clipboard.setData(
          ClipboardData(text: widget.modelPathOf(entry.hostPath)),
        );
        if (!mounted) return;
        _showSnack(l10n.workspaceFilesPathCopied, NotificationType.success);
      case _FileItemAction.export:
        try {
          if (entry.isDirectory) {
            await _exportDirectory(Directory(entry.hostPath), name: entry.name);
          } else {
            await _exportFile(File(entry.hostPath), fileName: entry.name);
          }
        } catch (e) {
          await _handleError(e);
        }
      case _FileItemAction.delete:
        await _delete(entry);
    }
  }

  Future<void> _rename(FileBrowserEntry entry) async {
    if (!_canMutateFiles) return;
    final l10n = AppLocalizations.of(context)!;
    final name = await showWorkspaceNamePrompt(
      context: context,
      title: l10n.workspaceFilesRename,
      label: l10n.workspaceFilesNameLabel,
      hint: l10n.workspaceFilesNameHint,
      confirmLabel: l10n.workspaceFilesSave,
      initial: entry.name,
    );
    if (name == null || !mounted) return;
    if (!FileBrowserOps.isValidFileName(name)) {
      _showSnack(l10n.workspaceFilesInvalidName, NotificationType.error);
      return;
    }
    try {
      await _runMutation(
        RenameMutation(
          rootPath: _rootPath,
          hostPath: entry.hostPath,
          newName: name,
        ),
      );
      await _reload();
    } catch (e) {
      await _handleError(e);
    }
  }

  Future<void> _move(FileBrowserEntry entry) async {
    if (!_canMutateFiles) return;
    final l10n = AppLocalizations.of(context)!;
    final destRel = await showWorkspaceFolderPicker(
      context,
      root: _rootPath,
      rootLabel: widget.rootLabel,
      initialRelPath: currentRelPath,
      title: l10n.workspaceFilesMoveTitle,
      excludePath: entry.isDirectory ? entry.hostPath : null,
    );
    if (destRel == null || !mounted) return;
    final destPath = FileBrowserOps.joinInsideRoot(_rootPath, destRel);
    if (destPath == null) {
      _showEscapeRefused();
      return;
    }
    try {
      await _runMutation(
        MoveMutation(
          rootPath: _rootPath,
          hostPath: entry.hostPath,
          destDirPath: destPath,
        ),
      );
      await _reload();
    } catch (e) {
      await _handleError(e);
    }
  }

  Future<void> _delete(FileBrowserEntry entry) async {
    if (!_canMutateFiles) return;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showWorkspaceConfirm(
      context: context,
      title: l10n.workspaceFilesDeleteTitle,
      message: entry.isDirectory
          ? l10n.workspaceFilesDeleteFolderMessage(entry.name)
          : l10n.workspaceFilesDeleteMessage(entry.name),
      confirmLabel: l10n.workspaceFilesDelete,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await _runMutation(
        DeleteMutation(rootPath: _rootPath, hostPath: entry.hostPath),
      );
      await _reload();
    } catch (e) {
      await _handleError(e);
    }
  }

  Offset _anchorFromKey(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return Offset.zero;
    return box.localToGlobal(box.size.center(Offset.zero));
  }

  Future<void> _showItemActions(FileBrowserEntry entry, Offset anchor) async {
    if (widget.pickDirectoryMode) return;
    final l10n = AppLocalizations.of(context)!;
    await showAdaptiveActionMenu(
      context,
      anchor: anchor,
      title: l10n.workspaceFilesActions,
      items: [
        for (final item in _actionsFor(entry, l10n))
          ActionSheetItem(
            key: FileBrowser.actionKey(item.action.name),
            icon: item.icon,
            label: item.label,
            destructive: item.danger,
            onTap: () => unawaited(_performAction(item.action, entry)),
          ),
      ],
    );
  }

  List<_ActionSpec> _actionsFor(FileBrowserEntry entry, AppLocalizations l10n) {
    final actions = <_ActionSpec>[
      _ActionSpec(
        _FileItemAction.preview,
        Lucide.Eye,
        l10n.workspaceFilesPreview,
      ),
    ];
    if (_canMutateFiles) {
      actions.addAll([
        _ActionSpec(
          _FileItemAction.rename,
          Lucide.Pencil,
          l10n.workspaceFilesRename,
        ),
        _ActionSpec(
          _FileItemAction.move,
          Lucide.FolderInput,
          l10n.workspaceFilesMoveTo,
        ),
      ]);
    }
    actions.addAll([
      _ActionSpec(
        _FileItemAction.share,
        Lucide.Share2,
        l10n.workspaceFilesShare,
      ),
      _ActionSpec(
        _FileItemAction.copyPath,
        Lucide.Copy,
        l10n.workspaceFilesCopyPath,
      ),
      _ActionSpec(
        _FileItemAction.export,
        Lucide.Download,
        l10n.workspaceFilesExportItem,
      ),
    ]);
    if (_canMutateFiles) {
      actions.add(
        _ActionSpec(
          _FileItemAction.delete,
          Lucide.Trash,
          l10n.workspaceFilesDelete,
          danger: true,
        ),
      );
    }
    return actions;
  }

  List<Widget> pageAppBarActions() {
    if (useDesktopWorkspaceLayout(context)) {
      return _fullToolbarActions();
    }
    if (!_canMutateFiles) {
      return [_sortButton(), _hiddenButton()];
    }
    return [_sortButton(), _newButton(), _moreButton(includeSort: false)];
  }

  List<Widget> toolbarActions() => pageAppBarActions();

  List<Widget> _fullToolbarActions() {
    final desktop = useDesktopWorkspaceLayout(context);
    return [
      _sortButton(),
      _hiddenButton(),
      if (_canMutateFiles) ...[_newButton(), _importButton(), _exportButton()],
      if (desktop && !widget.pickDirectoryMode) _refreshButton(),
      if (widget.onOpenTerminal != null && !widget.pickDirectoryMode)
        _terminalButton(),
    ];
  }

  List<Widget> _compactEmbeddedActions() {
    return [if (_canMutateFiles) _newButton(), _moreButton(includeSort: true)];
  }

  Widget _toolbarIcon({
    required Key key,
    required String tooltip,
    required IconData icon,
    required VoidCallback onTap,
    GlobalKey? anchorKey,
  }) {
    return Tooltip(
      message: tooltip,
      child: IosIconButton(
        key: key,
        icon: icon,
        semanticLabel: tooltip,
        minSize: useDesktopWorkspaceLayout(context) ? 34 : 44,
        builder: anchorKey == null
            ? null
            : (color) => KeyedSubtree(
                key: anchorKey,
                child: Icon(icon, size: 20, color: color),
              ),
        onTap: () {
          Haptics.light();
          onTap();
        },
      ),
    );
  }

  Widget _sortButton() {
    final l10n = AppLocalizations.of(context)!;
    return _toolbarIcon(
      key: FileBrowser.sortButtonKey,
      tooltip: l10n.workspaceFilesSort,
      icon: Lucide.ChevronsUpDown,
      anchorKey: _sortAnchorKey,
      onTap: () {
        unawaited(_openSortMenu());
      },
    );
  }

  Widget _hiddenButton() {
    final l10n = AppLocalizations.of(context)!;
    return _toolbarIcon(
      key: FileBrowser.hiddenToggleKey,
      tooltip: _showHidden
          ? l10n.workspaceFilesHideHidden
          : l10n.workspaceFilesShowHidden,
      icon: _showHidden ? Lucide.Eye : Lucide.EyeOff,
      onTap: _toggleHidden,
    );
  }

  Widget _newButton() {
    final l10n = AppLocalizations.of(context)!;
    return _toolbarIcon(
      key: FileBrowser.newKey,
      tooltip: l10n.workspaceFilesNew,
      icon: Lucide.Plus,
      anchorKey: _newAnchorKey,
      onTap: () {
        unawaited(_openNewMenu());
      },
    );
  }

  Widget _importButton() {
    final l10n = AppLocalizations.of(context)!;
    return _toolbarIcon(
      key: FileBrowser.importKey,
      tooltip: l10n.workspaceFilesImport,
      icon: Lucide.Import,
      onTap: () => unawaited(_importFiles()),
    );
  }

  Widget _exportButton() {
    final l10n = AppLocalizations.of(context)!;
    return _toolbarIcon(
      key: FileBrowser.exportKey,
      tooltip: l10n.workspaceFilesExportFolder,
      icon: Lucide.Download,
      onTap: () => unawaited(_exportCurrent()),
    );
  }

  Widget _terminalButton() {
    final l10n = AppLocalizations.of(context)!;
    return _toolbarIcon(
      key: FileBrowser.terminalKey,
      tooltip: l10n.workspaceEntryTerminal,
      icon: Lucide.Terminal,
      onTap: widget.onOpenTerminal!,
    );
  }

  Widget _refreshButton() {
    final l10n = AppLocalizations.of(context)!;
    return _toolbarIcon(
      key: FileBrowser.refreshKey,
      tooltip: l10n.workspaceFilesRefresh,
      icon: Lucide.RefreshCw,
      onTap: () => unawaited(_reload()),
    );
  }

  Widget _moreButton({required bool includeSort}) {
    final l10n = AppLocalizations.of(context)!;
    return _toolbarIcon(
      key: FileBrowser.moreKey,
      tooltip: l10n.workspaceFilesMore,
      icon: Lucide.Ellipsis,
      anchorKey: _moreAnchorKey,
      onTap: () {
        unawaited(_openMoreMenu(includeSort: includeSort));
      },
    );
  }

  void _toggleHidden() {
    setState(() => _showHidden = !_showHidden);
    unawaited(_reload());
  }

  Future<void> _exportCurrent() {
    return _exportDirectory(
      _currentDir,
      name: _segments.isEmpty ? widget.rootLabel : _segments.last,
    );
  }

  Future<void> _openSortMenu() async {
    final l10n = AppLocalizations.of(context)!;
    var foldersFirst = _foldersFirst;
    final field = await showOptionSheet<FileBrowserSortField>(
      context,
      title: l10n.workspaceFilesSort,
      selected: _sort,
      items: [
        OptionSheetItem(
          value: FileBrowserSortField.name,
          label: l10n.workspaceFilesSortName,
        ),
        OptionSheetItem(
          value: FileBrowserSortField.modified,
          label: l10n.workspaceFilesSortModified,
        ),
        OptionSheetItem(
          value: FileBrowserSortField.size,
          label: l10n.workspaceFilesSortSize,
        ),
      ],
      footer: StatefulBuilder(
        builder: (ctx, setLocal) {
          final cs = Theme.of(ctx).colorScheme;
          Widget check(bool selected) => selected
              ? Icon(Lucide.Check, size: 18, color: cs.primary)
              : const SizedBox.shrink();
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              SectionCard(
                children: [
                  IosNavRow(
                    label: l10n.workspaceFilesSortAscending,
                    labelWeight: AppFontWeights.medium,
                    trailing: check(_ascending),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _setAscending(true);
                    },
                  ),
                  const IosRowDivider(),
                  IosNavRow(
                    label: l10n.workspaceFilesSortDescending,
                    labelWeight: AppFontWeights.medium,
                    trailing: check(!_ascending),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _setAscending(false);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SectionCard(
                children: [
                  IosSwitchRow(
                    key: FileBrowser.foldersFirstKey,
                    label: l10n.workspaceFilesFoldersFirst,
                    value: foldersFirst,
                    onChanged: (value) {
                      setLocal(() => foldersFirst = value);
                      setState(() => _foldersFirst = value);
                      unawaited(_reload());
                    },
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
    if (field == null || !mounted) return;
    _setSortField(field);
  }

  void _setSortField(FileBrowserSortField field) {
    setState(() {
      if (_sort == field) {
        _ascending = !_ascending;
      } else {
        _sort = field;
        _ascending = true;
      }
    });
    unawaited(_reload());
  }

  void _setAscending(bool ascending) {
    setState(() => _ascending = ascending);
    unawaited(_reload());
  }

  Future<void> _openNewMenu() async {
    final l10n = AppLocalizations.of(context)!;
    final desktop = useDesktopWorkspaceLayout(context);
    await showAdaptiveActionMenu(
      context,
      anchor: _anchorFromKey(_newAnchorKey),
      title: l10n.workspaceFilesNew,
      items: [
        ActionSheetItem(
          key: FileBrowser.newFolderKey,
          icon: Lucide.FolderPlus,
          label: l10n.workspaceFilesNewFolder,
          onTap: () => unawaited(_promptNewFolder()),
        ),
        ActionSheetItem(
          key: FileBrowser.newFileKey,
          icon: Lucide.FilePlus,
          label: l10n.workspaceFilesNewFile,
          onTap: () => unawaited(_promptNewFile()),
        ),
        if (!desktop)
          ActionSheetItem(
            key: const ValueKey<String>('file-browser-import-sheet'),
            icon: Lucide.Import,
            label: l10n.workspaceFilesImport,
            onTap: () => unawaited(_importFiles()),
          ),
      ],
    );
  }

  Future<void> _openMoreMenu({required bool includeSort}) async {
    final l10n = AppLocalizations.of(context)!;
    final hiddenLabel = _showHidden
        ? l10n.workspaceFilesHideHidden
        : l10n.workspaceFilesShowHidden;
    await showAdaptiveActionMenu(
      context,
      anchor: _anchorFromKey(_moreAnchorKey),
      title: l10n.workspaceFilesMore,
      items: [
        if (widget.onOpenTerminal != null && !widget.pickDirectoryMode)
          ActionSheetItem(
            key: FileBrowser.terminalKey,
            icon: Lucide.Terminal,
            label: l10n.workspaceEntryTerminal,
            onTap: widget.onOpenTerminal!,
          ),
        if (includeSort)
          ActionSheetItem(
            key: const ValueKey<String>('file-browser-more-sort'),
            icon: Lucide.ChevronsUpDown,
            label: l10n.workspaceFilesSort,
            onTap: () => unawaited(_openSortMenu()),
          ),
        ActionSheetItem(
          key: const ValueKey<String>('file-browser-more-hidden'),
          icon: _showHidden ? Lucide.Eye : Lucide.EyeOff,
          label: hiddenLabel,
          onTap: _toggleHidden,
        ),
        if (useDesktopWorkspaceLayout(context) && _canMutateFiles)
          ActionSheetItem(
            key: FileBrowser.importKey,
            icon: Lucide.Import,
            label: l10n.workspaceFilesImport,
            onTap: () => unawaited(_importFiles()),
          ),
        if (!widget.pickDirectoryMode)
          ActionSheetItem(
            key: FileBrowser.exportKey,
            icon: Lucide.Download,
            label: l10n.workspaceFilesExportFolder,
            onTap: () => unawaited(_exportCurrent()),
          ),
        ActionSheetItem(
          key: FileBrowser.refreshKey,
          icon: Lucide.RefreshCw,
          label: l10n.workspaceFilesRefresh,
          onTap: () => unawaited(_reload()),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final desktop = useDesktopWorkspaceLayout(context);
    return PopScope(
      canPop: desktop || _segments.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _popStack();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            key: FileBrowser.toolbarRowKey,
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact =
                    widget.showToolbar &&
                    constraints.maxWidth < FileBrowser.compactToolbarBreakpoint;
                return Row(
                  children: [
                    Expanded(
                      child: _BreadcrumbBar(
                        rootLabel: widget.rootLabel,
                        segments: _segments,
                        onJump: _jumpTo,
                      ),
                    ),
                    if (widget.showToolbar)
                      ...compact
                          ? _compactEmbeddedActions()
                          : _fullToolbarActions(),
                  ],
                );
              },
            ),
          ),
          Expanded(
            child:
                desktop && (_error != null || (!_loading && _entries.isEmpty))
                ? LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: _buildBody(desktop),
                      ),
                    ),
                  )
                : _buildBody(desktop),
          ),
          if (widget.pickDirectoryMode) _pickBar(),
        ],
      ),
    );
  }

  Widget _pickBar() {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    if (useDesktopWorkspaceLayout(context)) {
      return Padding(
        key: FileBrowser.pickBarKey,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (_canCreateFolder)
              DesktopWorkspaceButton(
                key: FileBrowser.newFolderKey,
                label: l10n.workspaceFilesNewFolder,
                icon: Lucide.FolderPlus,
                onPressed: () => unawaited(_promptNewFolder()),
              ),
            const Spacer(),
            DesktopWorkspaceButton(
              key: FileBrowser.pickDirectoryKey,
              label: l10n.workspaceFilesSelectDirectory,
              icon: Lucide.Check,
              primary: true,
              onPressed: () => widget.onPickDirectory?.call(currentRelPath),
            ),
          ],
        ),
      );
    }
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return Padding(
      key: FileBrowser.pickBarKey,
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IosTileButton(
            key: FileBrowser.pickDirectoryKey,
            icon: Lucide.Check,
            label: l10n.workspaceFilesSelectDirectory,
            backgroundColor: cs.primary,
            onTap: () => widget.onPickDirectory?.call(currentRelPath),
          ),
          if (_canCreateFolder) ...[
            const SizedBox(height: 8),
            IosTileButton(
              key: FileBrowser.newFolderKey,
              icon: Lucide.FolderPlus,
              label: l10n.workspaceFilesNewFolder,
              onTap: () => unawaited(_promptNewFolder()),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody(bool desktop) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    if (_error != null) {
      return Center(
        key: FileBrowser.errorKey,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Lucide.TriangleAlert,
                size: 44,
                color: cs.onSurface.withValues(alpha: 0.26),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.workspaceFilesError,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: AppFontWeights.semibold,
                  color: cs.onSurface.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(height: 16),
              IosTileButton(
                icon: Lucide.RefreshCw,
                label: l10n.workspaceFilesRetry,
                onTap: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  unawaited(_reload());
                },
              ),
            ],
          ),
        ),
      );
    }
    if (_loading) {
      return const Center(child: CupertinoActivityIndicator(radius: 12));
    }
    if (_entries.isEmpty) {
      final hint =
          widget.emptyHint ??
          (widget.pickDirectoryMode
              ? l10n.workspaceFilesEmptyPickerHint
              : (widget.readOnly ? null : l10n.workspaceFilesEmptyHint));
      return Center(
        key: FileBrowser.emptyKey,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.emptyIcon ?? Lucide.FolderOpen,
                size: 44,
                color: cs.onSurface.withValues(alpha: 0.26),
              ),
              const SizedBox(height: 12),
              Text(
                widget.emptyTitle ?? l10n.workspaceFilesEmpty,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: AppFontWeights.semibold,
                  color: cs.onSurface.withValues(alpha: 0.72),
                ),
              ),
              if (hint != null) ...[
                const SizedBox(height: 6),
                Text(
                  hint,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: cs.onSurface.withValues(alpha: 0.52),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (desktop) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 540;
          Widget heading(String label, FileBrowserSortField field) =>
              TextButton(
                onPressed: () => _setSortField(field),
                style: TextButton.styleFrom(
                  splashFactory: NoSplash.splashFactory,
                  overlayColor: cs.onSurface.withValues(alpha: 0.05),
                  alignment: Alignment.centerLeft,
                  foregroundColor: cs.onSurfaceVariant,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    if (_sort == field) ...[
                      const SizedBox(width: 4),
                      Icon(
                        _ascending ? Lucide.ChevronUp : Lucide.ChevronDown,
                        size: 12,
                      ),
                    ],
                  ],
                ),
              );
          return Column(
            children: [
              if (columns)
                SizedBox(
                  height: 34,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: heading(
                            l10n.workspaceFilesSortName,
                            FileBrowserSortField.name,
                          ),
                        ),
                        SizedBox(
                          width: 132,
                          child: heading(
                            l10n.workspaceFilesSortModified,
                            FileBrowserSortField.modified,
                          ),
                        ),
                        SizedBox(
                          width: 92,
                          child: heading(
                            l10n.workspaceFilesSortSize,
                            FileBrowserSortField.size,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Divider(
                height: 1,
                thickness: 0.5,
                color: cs.outlineVariant.withValues(alpha: 0.12),
              ),
              Expanded(
                child: Scrollbar(
                  controller: _desktopScroll,
                  child: ListView.builder(
                    key: FileBrowser.listKey,
                    controller: _desktopScroll,
                    padding: const EdgeInsets.all(8),
                    itemCount: _entries.length,
                    itemBuilder: (context, index) {
                      final entry = _entries[index];
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          splashFactory: NoSplash.splashFactory,
                          hoverColor: cs.onSurface.withValues(alpha: 0.035),
                          highlightColor: cs.onSurface.withValues(alpha: 0.065),
                          focusColor: cs.primary.withValues(alpha: 0.08),
                          key: FileBrowser.itemKey(entry.name),
                          borderRadius: BorderRadius.circular(6),
                          onTap: () => unawaited(_openEntry(entry)),
                          onSecondaryTapDown: widget.pickDirectoryMode
                              ? null
                              : (details) => unawaited(
                                  _showItemActions(
                                    entry,
                                    details.globalPosition,
                                  ),
                                ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                SizedBox.square(
                                  dimension: 24,
                                  child: WorkspaceFileThumbnail.supports(entry)
                                      ? WorkspaceFileThumbnail(
                                          entry: entry,
                                          size: 24,
                                          iconSize: 18,
                                          iconColor: cs.onSurfaceVariant,
                                        )
                                      : Icon(
                                          entry.isDirectory
                                              ? Lucide.Folder
                                              : workspaceFileTypeIcon(
                                                  entry.name,
                                                ),
                                          size: 18,
                                          color: entry.isDirectory
                                              ? cs.primary
                                              : cs.onSurfaceVariant,
                                        ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    entry.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                                if (columns) ...[
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: 132,
                                    child: Text(
                                      _relativeMtime(
                                        entry.modified,
                                        l10n,
                                        MaterialLocalizations.of(context),
                                      ),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 80,
                                    child: Text(
                                      entry.isDirectory
                                          ? '—'
                                          : formatBytes(entry.size),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: SectionCard(
        padding: EdgeInsets.zero,
        child: ListView.separated(
          key: FileBrowser.listKey,
          controller: widget.scrollController,
          primary: false,
          padding: EdgeInsets.zero,
          itemCount: _entries.length,
          separatorBuilder: (_, _) => const IosRowDivider(),
          itemBuilder: (context, index) {
            final entry = _entries[index];
            return _FileRow(
              entry: entry,
              onOpen: () => unawaited(_openEntry(entry)),
              onMore: desktop || widget.pickDirectoryMode
                  ? null
                  : (pos) => unawaited(_showItemActions(entry, pos)),
              onLongPress: desktop || widget.pickDirectoryMode
                  ? null
                  : (pos) => unawaited(_showItemActions(entry, pos)),
              onSecondaryTap: desktop && !widget.pickDirectoryMode
                  ? (pos) => unawaited(_showItemActions(entry, pos))
                  : null,
            );
          },
        ),
      ),
    );
  }
}

class _ActionSpec {
  const _ActionSpec(this.action, this.icon, this.label, {this.danger = false});

  final _FileItemAction action;
  final IconData icon;
  final String label;
  final bool danger;
}

class _BreadcrumbBar extends StatefulWidget {
  const _BreadcrumbBar({
    required this.rootLabel,
    required this.segments,
    required this.onJump,
  });

  final String rootLabel;
  final List<String> segments;
  final ValueChanged<int> onJump;

  @override
  State<_BreadcrumbBar> createState() => _BreadcrumbBarState();
}

class _BreadcrumbBarState extends State<_BreadcrumbBar> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    if (!_controller.hasClients) return;
    _controller.jumpTo(_controller.position.maxScrollExtent);
  }

  @override
  void didUpdateWidget(covariant _BreadcrumbBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.segments.length != widget.segments.length ||
        oldWidget.rootLabel != widget.rootLabel) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToEnd();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToEnd();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final crumbs = <(int, String)>[
      (0, widget.rootLabel),
      for (var i = 0; i < widget.segments.length; i++)
        (i + 1, widget.segments[i]),
    ];
    return SizedBox(
      height: 28,
      child: ListView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        children: [
          for (var i = 0; i < crumbs.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  Lucide.ChevronRight,
                  size: 14,
                  color: cs.onSurface.withValues(alpha: 0.4),
                ),
              ),
            IosCardPress(
              key: FileBrowser.breadcrumbKey(crumbs[i].$2),
              onTap: () => widget.onJump(crumbs[i].$1),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 28,
                child: Center(
                  child: Text(
                    crumbs[i].$2,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: i == crumbs.length - 1
                          ? AppFontWeights.emphasis
                          : AppFontWeights.medium,
                      color: i == crumbs.length - 1
                          ? cs.onSurface
                          : cs.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.entry,
    required this.onOpen,
    this.onMore,
    this.onLongPress,
    this.onSecondaryTap,
  });

  final FileBrowserEntry entry;
  final VoidCallback onOpen;
  final ValueChanged<Offset>? onMore;
  final ValueChanged<Offset>? onLongPress;
  final ValueChanged<Offset>? onSecondaryTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final loc = MaterialLocalizations.of(context);
    final meta = _metaLabel(context, loc, l10n);
    final cs = Theme.of(context).colorScheme;
    final more = onMore;
    final row = IosNavRow(
      key: FileBrowser.itemKey(entry.name),
      icon: entry.isDirectory
          ? Lucide.Folder
          : workspaceFileTypeIcon(entry.name),
      leading: WorkspaceFileThumbnail.supports(entry)
          ? WorkspaceFileThumbnail(
              entry: entry,
              iconColor: cs.onSurface.withValues(alpha: 0.9),
            )
          : null,
      label: entry.name,
      labelWeight: AppFontWeights.medium,
      subtitle: meta,
      trailing: more == null
          ? (entry.isDirectory ? null : const SizedBox.shrink())
          : IosIconButton(
              key: FileBrowser.itemMoreKey(entry.name),
              icon: Lucide.Ellipsis,
              semanticLabel: l10n.workspaceFilesActions,
              size: 18,
              minSize: 36,
              color: cs.onSurface.withValues(alpha: 0.55),
              onTap: () {
                Haptics.light();
                final box = context.findRenderObject() as RenderBox?;
                final pos = box == null
                    ? Offset.zero
                    : box.localToGlobal(box.size.center(Offset.zero));
                more(pos);
              },
            ),
      onTap: onOpen,
      onLongPress: onLongPress == null
          ? null
          : () {
              final box = context.findRenderObject() as RenderBox?;
              final pos = box == null
                  ? Offset.zero
                  : box.localToGlobal(box.size.center(Offset.zero));
              onLongPress!(pos);
            },
    );
    if (onSecondaryTap == null) return row;
    return GestureDetector(
      onSecondaryTapDown: (details) => onSecondaryTap!(details.globalPosition),
      child: row,
    );
  }

  String _metaLabel(
    BuildContext context,
    MaterialLocalizations loc,
    AppLocalizations l10n,
  ) {
    final mtime = _relativeMtime(entry.modified, l10n, loc);
    if (entry.isDirectory) {
      final count = entry.childCount;
      if (count != null) {
        return '${l10n.workspaceFilesItemCount(count)} · $mtime';
      }
      return mtime;
    }
    return '${formatBytes(entry.size)} · $mtime';
  }
}

String _relativeMtime(
  DateTime modified,
  AppLocalizations l10n,
  MaterialLocalizations loc,
) {
  final local = modified.toLocal();
  final diff = DateTime.now().difference(local);
  if (diff.inMinutes < 1) return l10n.workspaceFilesJustNow;
  if (diff.inHours < 1) return l10n.workspaceFilesMinutesAgo(diff.inMinutes);
  if (diff.inDays < 1) return l10n.workspaceFilesHoursAgo(diff.inHours);
  if (diff.inDays < 7) return l10n.workspaceFilesDaysAgo(diff.inDays);
  return loc.formatMediumDate(local);
}

String _safeFileName(String name) {
  final cleaned = name
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (cleaned.isEmpty) return 'folder';
  return cleaned.length > 80 ? cleaned.substring(0, 80) : cleaned;
}

Rect _shareAnchor(BuildContext context) {
  try {
    final box = context.findRenderObject() as RenderBox?;
    if (box != null &&
        box.hasSize &&
        box.size.width > 0 &&
        box.size.height > 0) {
      return box.localToGlobal(Offset.zero) & box.size;
    }
  } catch (_) {}
  final size = MediaQuery.sizeOf(context);
  return Rect.fromCenter(
    center: Offset(size.width / 2, size.height / 2),
    width: 1,
    height: 1,
  );
}
