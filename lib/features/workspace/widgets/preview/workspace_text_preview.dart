import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show BoxWidthStyle;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../../../core/providers/settings_provider.dart';
import '../../../../core/services/workspace/workspace_text_file.dart';
import '../../../../desktop/widgets/desktop_menu.dart';
import '../../../../icons/lucide_adapter.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/action_sheet.dart';
import '../../../../shared/widgets/ios_tactile.dart';
import '../../../../shared/widgets/ios_text_button.dart';
import '../../../../shared/widgets/long_message_editor.dart';
import '../../../../utils/platform_utils.dart';
import '../../../side_panel/widgets/side_panel_file_toolbar.dart';
import '../../../side_panel/widgets/side_panel_tab_bar.dart'
    show SidePanelIconButton;
import 'file_preview_frame.dart';
import 'preview_file_type.dart';
import 'code_file_preview.dart';
import 'markdown_file_preview.dart';
import 'preview_actions.dart';
import 'preview_states.dart';
import 'preview_text_document.dart';
import 'workspace_text_editing.dart';

enum WorkspacePreviewSurface { page, dialog, panel }

class WorkspaceTextPreview extends StatefulWidget {
  const WorkspaceTextPreview({
    super.key,
    required this.session,
    required this.surface,
    required this.markdown,
    this.startEditing = false,
    this.title,
  });
  final WorkspaceTextEditing session;
  final WorkspacePreviewSurface surface;
  final bool markdown;
  final bool startEditing;
  final String? title;

  @override
  State<WorkspaceTextPreview> createState() => _WorkspaceTextPreviewState();
}

class _WorkspaceTextPreviewState extends State<WorkspaceTextPreview> {
  WorkspaceTextEditing get session => widget.session;
  PreviewTextDocument? _document;
  WorkspaceTextProblem? _problem;
  bool _editable = false;
  bool _failed = false;
  int _generation = 0;
  final _moreMenu = MenuController();
  final _moreFocus = FocusNode(debugLabel: 'Workspace file actions');
  late int _revision;
  @override
  void initState() {
    super.initState();
    _revision = session.revision;
    session.addListener(_changed);
    _reportSaveError();
    final start = widget.startEditing || session.startEditingOnOpen;
    session.startEditingOnOpen = false;
    unawaited(_load(startEditing: start));
  }

  @override
  void dispose() {
    session.removeListener(_changed);
    _moreFocus.dispose();
    super.dispose();
  }

  void _changed() {
    _reportSaveError();
    if (session.revision != _revision) {
      _revision = session.revision;
      _editable = false;
      unawaited(_load());
    }
    setState(() {});
  }

  void _reportSaveError() {
    if (session.hasPendingError) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) session.showPendingError(context);
      });
    }
  }

  Future<void> _load({bool startEditing = false}) async {
    final generation = ++_generation;
    try {
      final document =
          session.takeReloadedDocument() ??
          await loadPreviewTextDocument(session.file);
      if (!mounted || generation != _generation) return;
      setState(() {
        _document = document;
        _problem = document.editProblem;
        _editable = false;
        _failed = false;
      });
      // Render immediately. A paged document never opens an editor or waits on mounts.
      if (document.editProblem != null) return;
      final writable = await session.canEdit(context);
      if (!mounted || generation != _generation) return;
      setState(() {
        _editable = writable;
        if (!writable) _problem = WorkspaceTextProblem.readOnly;
      });
      if (startEditing && writable) await session.begin(context);
    } catch (_) {
      if (mounted && generation == _generation) setState(() => _failed = true);
    }
  }

  Future<void> _handleBack() async {
    final closeDialog = widget.surface == WorkspacePreviewSurface.dialog;
    final route = ModalRoute.of(context);
    if (await session.leave(context) &&
        closeDialog &&
        mounted &&
        route?.isCurrent == true) {
      Navigator.of(context).pop();
    }
  }

  List<ActionSheetItem> _fileActions(AppLocalizations l) {
    final file = session.file;
    return [
      ActionSheetItem(
        icon: Lucide.Copy,
        label: l.workspaceFilesCopyPath,
        onTap: () => copyFilePath(context, file),
      ),
      ActionSheetItem(
        icon: Lucide.Download,
        label: l.workspaceFilesExportItem,
        onTap: () => exportPreviewFile(context, file),
      ),
      ActionSheetItem(
        icon: Lucide.Share2,
        label: l.workspacePreviewShare,
        onTap: () => sharePreviewFile(context, file),
      ),
      ActionSheetItem(
        icon: Lucide.ExternalLink,
        label: l.workspacePreviewOpenWith,
        onTap: () => openPreviewFileExternally(context, file),
      ),
      if (canRevealPreviewFileInFileManager)
        ActionSheetItem(
          icon: Lucide.FolderOpen,
          label: revealInFileManagerLabel(l),
          onTap: () => revealPreviewFileInFileManager(context, file),
        ),
    ];
  }

  Widget _moreButton(AppLocalizations l, {required bool desktop}) {
    if (!desktop) {
      return IosIconButton(
        icon: Lucide.Ellipsis,
        tooltip: l.workspaceFilesMore,
        minSize: 44,
        visualSize: 36,
        onTap: () => showMobileActionSheet(
          context,
          title: l.workspaceFilesActions,
          items: _fileActions(l),
        ),
      );
    }
    final scale = MediaQuery.textScalerOf(context).scale(13) / 13;
    final width = math.min(
      216.0 * math.max(1.0, scale),
      math.max(0.0, MediaQuery.sizeOf(context).width - 16),
    );
    return MenuAnchor(
      controller: _moreMenu,
      childFocusNode: _moreFocus,
      useRootOverlay: true,
      consumeOutsideTap: true,
      clipBehavior: Clip.none,
      alignmentOffset: Offset(-width, 4),
      style: const MenuStyle(
        alignment: AlignmentDirectional.bottomEnd,
        padding: WidgetStatePropertyAll(EdgeInsets.zero),
        backgroundColor: WidgetStatePropertyAll(Colors.transparent),
        surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
        elevation: WidgetStatePropertyAll(0),
      ),
      menuChildren: [
        SizedBox(
          width: width,
          child: DesktopMenuSurface(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final item in _fileActions(l))
                  DesktopMenuRow(
                    label: item.label,
                    tooltip: item.label,
                    leading: Icon(
                      item.icon,
                      size: 15,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    onTap: () {
                      _moreMenu.close();
                      item.onTap();
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
      builder: (_, menu, _) => SidePanelIconButton(
        icon: Lucide.Ellipsis,
        label: l.workspaceFilesMore,
        focusNode: _moreFocus,
        onTap: () => menu.isOpen ? menu.close() : menu.open(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context)!;
    final page = widget.surface == WorkspacePreviewSurface.page;
    final desktop = PlatformUtils.isDesktopTarget;
    final name = session.revision == 0
        ? widget.title ?? p.basename(session.file.path)
        : p.basename(session.file.path);
    final VoidCallback? save = session.dirty && !session.busy
        ? () => session.save(context)
        : null;
    Widget toolbarIcon(IconData icon, String label, VoidCallback? onTap) =>
        desktop
        ? SidePanelIconButton(icon: icon, label: label, onTap: onTap)
        : IosIconButton(
            icon: icon,
            tooltip: label,
            minSize: 44,
            visualSize: 36,
            enabled: onTap != null,
            onTap: onTap,
          );
    final actions = <Widget>[
      if (session.editing) ...[
        if (!page)
          toolbarIcon(
            widget.surface == WorkspacePreviewSurface.dialog
                ? Lucide.ArrowLeft
                : Lucide.X,
            l.workspaceFilesCancel,
            session.busy ? null : () => session.leave(context),
          ),
        if (desktop) ...[
          const SizedBox(width: 4),
          SidePanelIconButton(
            icon: Lucide.Check,
            label: l.workspaceFilesSave,
            color: save == null ? null : cs.primary,
            onTap: save,
          ),
        ] else
          IosTextButton(label: l.workspaceFilesSave, onPressed: save),
      ] else ...[
        if (!_failed && _editable)
          toolbarIcon(
            Lucide.Pencil,
            l.workspacePreviewEdit,
            session.busy ? null : () => session.begin(context),
          ),
        if (desktop && _editable) const SizedBox(width: 4),
        _moreButton(l, desktop: desktop),
      ],
    ];
    final document = _document;
    final preview = _failed
        ? PreviewError(onRetry: _load)
        : document == null
        ? const PreviewLoading()
        : widget.markdown
        ? MarkdownFilePreview(file: session.file, document: document)
        : CodeFilePreview(file: session.file, document: document);
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!session.editing && !_failed && _problem != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 7, 16, 3),
            child: Row(
              children: [
                Icon(Lucide.info, size: 14, color: cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    switch (_problem) {
                      WorkspaceTextProblem.large =>
                        l.workspaceEditorLargePreview,
                      WorkspaceTextProblem.encoding =>
                        l.workspaceEditorEncoding,
                      _ => l.workspaceEditorReadOnly,
                    },
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Offstage(offstage: session.editing, child: preview),
              if (session.editing)
                _TextInput(
                  session: session,
                  desktop: desktop,
                  markdown: widget.markdown,
                ),
            ],
          ),
        ),
      ],
    );
    late final Widget content;
    if (widget.surface != WorkspacePreviewSurface.panel) {
      content = FilePreviewFrame(
        file: session.file,
        title: name,
        kind: widget.markdown ? FilePreviewKind.markdown : FilePreviewKind.code,
        dialog: !page,
        centerTitle: page,
        modified: session.dirty,
        actions: actions,
        leading: page && session.editing
            ? IosIconButton(
                icon: Lucide.X,
                tooltip: l.workspaceFilesCancel,
                semanticLabel: l.workspaceFilesCancel,
                enabled: !session.busy,
                minSize: 44,
                visualSize: 36,
                onTap: () => session.leave(context),
              )
            : null,
        child: page ? SafeArea(top: false, child: body) : body,
      );
    } else {
      content = Column(
        children: [
          SidePanelFileToolbar(
            label: '${l.workspaceFilesTabWorkspace} › $name',
            path: session.file.path,
            actions: actions,
          ),
          Expanded(child: body),
        ],
      );
    }
    if (widget.surface == WorkspacePreviewSurface.panel) return content;
    return PopScope<Object?>(
      canPop: !session.editing && !session.busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && session.editing) unawaited(_handleBack());
      },
      child: content,
    );
  }
}

class _TextInput extends StatefulWidget {
  const _TextInput({
    required this.session,
    required this.desktop,
    required this.markdown,
  });
  final bool desktop;
  final WorkspaceTextEditing session;
  final bool markdown;
  @override
  State<_TextInput> createState() => _TextInputState();
}

class _TextInputState extends State<_TextInput> {
  late final _input = TextEditingController.fromValue(widget.session.value);
  @override
  void initState() {
    super.initState();
    _input.addListener(_inputChanged);
  }

  void _inputChanged() {
    if (widget.session.editing) widget.session.updateValue(_input.value);
  }

  @override
  void dispose() {
    _input.removeListener(_inputChanged);
    if (widget.session.editing) {
      widget.session.value = _input.value.copyWith(composing: TextRange.empty);
    }
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final session = widget.session;
    final path = session.file.path;
    final code =
        !widget.markdown &&
        (languageForPath(path) != 'text' ||
            p.extension(path).toLowerCase() == '.log');
    final bodyStyle = theme.textTheme.bodyLarge!;
    final codeFamily = code
        ? context.select<SettingsProvider?, String?>((s) => s?.codeFontFamily)
        : null;
    final style = bodyStyle.copyWith(
      fontFamily: code ? codeFamily ?? 'monospace' : bodyStyle.fontFamily,
      fontSize: code
          ? (widget.desktop ? 13.5 : 15)
          : (widget.desktop ? 14 : 16),
      height: 1.5,
      letterSpacing: 0,
      color: cs.onSurface,
    );
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true): () =>
            session.save(context),
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () =>
            session.save(context),
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            session.leave(context),
      },
      child: ColoredBox(
        // Keep wallpaper in the pane chrome and give the document its own surface.
        color: cs.surface.withValues(alpha: 1),
        child: LongMessageEditor(
          controller: _input,
          autofocus: true,
          expands: true,
          minLines: null,
          maxLines: null,
          readOnly: session.busy,
          style: style,
          cursorColor: cs.primary,
          selectionWidthStyle: BoxWidthStyle.tight,
          lineScrollbarBuilder: widget.desktop
              ? ScrollConfiguration.of(context).buildScrollbar
              : null,
          decoration: InputDecoration(
            isCollapsed: true,
            filled: false,
            border: InputBorder.none,
            focusedBorder: InputBorder.none,
            enabledBorder: InputBorder.none,
            contentPadding: widget.desktop
                ? const EdgeInsets.fromLTRB(16, 14, 16, 18)
                : const EdgeInsets.fromLTRB(20, 12, 20, 24),
          ),
        ),
      ),
    );
  }
}
