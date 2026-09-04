import 'dart:async';
import 'dart:io';

import 'package:Kelivo/core/models/workspace.dart';
import 'package:Kelivo/core/providers/workspace_provider.dart';
import 'package:Kelivo/features/workspace/pages/workspace_files_page.dart';
import 'package:Kelivo/features/workspace/terminal/open_terminal.dart';
import 'package:Kelivo/features/workspace/widgets/files/file_browser.dart';
import 'package:Kelivo/features/workspace/widgets/files/file_browser_ops.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class WorkspaceFilesMobileLayout extends StatelessWidget {
  const WorkspaceFilesMobileLayout({
    super.key,
    required this.workspaceId,
    this.initialRelativePath,
  });

  final String workspaceId;
  final String? initialRelativePath;

  @override
  Widget build(BuildContext context) {
    return WorkspaceFilesScaffold(
      workspaceId: workspaceId,
      initialRelativePath: initialRelativePath,
    );
  }
}

class WorkspaceFilesScaffold extends StatefulWidget {
  const WorkspaceFilesScaffold({
    super.key,
    required this.workspaceId,
    this.initialRelativePath,
    this.constrainWidth = false,
  });

  final String workspaceId;
  final String? initialRelativePath;
  final bool constrainWidth;

  @override
  State<WorkspaceFilesScaffold> createState() => _WorkspaceFilesScaffoldState();
}

class _WorkspaceFilesScaffoldState extends State<WorkspaceFilesScaffold> {
  final GlobalKey<FileBrowserState> _browserKey = GlobalKey<FileBrowserState>();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final workspace = workspaceOrNull(context, widget.workspaceId);
    final browser = _browserKey.currentState;
    final body = workspace == null
        ? Center(child: Text(l10n.workspaceFilesMissingWorkspace))
        : WorkspaceFilesBody(
            workspace: workspace,
            initialRelativePath: widget.initialRelativePath,
            browserKey: _browserKey,
            showToolbar: false,
            onBrowserReady: () {
              if (mounted) setState(() {});
            },
          );
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        leading: Tooltip(
          message: l10n.settingsPageBackButton,
          child: IosIconButton(
            icon: Lucide.ArrowLeft,
            color: cs.onSurface,
            size: 22,
            minSize: 44,
            semanticLabel: l10n.settingsPageBackButton,
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
        title: workspace == null
            ? Text(l10n.workspaceFilesMissingWorkspace)
            : WorkspaceFilesTitle(workspace: workspace),
        actions: [
          if (browser != null) ...fileBrowserToolbarActions(browser),
          const SizedBox(width: 12),
        ],
      ),
      body: widget.constrainWidth
          ? Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: body,
              ),
            )
          : body,
    );
  }
}

class WorkspaceFilesBody extends StatefulWidget {
  const WorkspaceFilesBody({
    super.key,
    required this.workspace,
    this.initialRelativePath,
    this.browserKey,
    this.showToolbar = true,
    this.onBrowserReady,
  });

  final Workspace workspace;
  final String? initialRelativePath;
  final GlobalKey<FileBrowserState>? browserKey;
  final bool showToolbar;
  final VoidCallback? onBrowserReady;

  @override
  State<WorkspaceFilesBody> createState() => WorkspaceFilesBodyState();
}

class WorkspaceFilesBodyState extends State<WorkspaceFilesBody> {
  Directory? _root;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant WorkspaceFilesBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspace.id != widget.workspace.id ||
        oldWidget.workspace.hostPath != widget.workspace.hostPath) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    try {
      final provider = context.read<WorkspaceProvider>();
      final path = await provider.hostRootFor(widget.workspace);
      if (!mounted) return;
      setState(() {
        _root = Directory(path);
        _error = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onBrowserReady?.call();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    if (_error != null) {
      return Center(
        child: Text(
          l10n.workspaceFilesError,
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
      );
    }
    final root = _root;
    if (root == null) {
      return const Center(child: CupertinoActivityIndicator(radius: 12));
    }
    return FileBrowser(
      key: widget.browserKey,
      root: root,
      rootLabel: widget.workspace.name,
      initialRelativePath: widget.initialRelativePath,
      showToolbar: widget.showToolbar,
      modelPathOf: (host) => WorkspaceModelPaths.workspaceFile(host, root.path),
      onOpenTerminal: () {
        unawaited(openTerminal(context, workspaceId: widget.workspace.id));
      },
    );
  }
}
