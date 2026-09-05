import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/models/workspace.dart';
import 'package:Kelivo/core/providers/workspace_provider.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:Kelivo/features/workspace/pages/workspace_files_page.dart';
import 'package:Kelivo/features/workspace/pages/workspaces_page.dart';
import 'package:Kelivo/features/workspace/widgets/workspace_tools_pane.dart';
import 'package:Kelivo/features/workspace/widgets/desktop_workspace_button.dart';
import 'package:Kelivo/features/workspace/widgets/files/file_browser.dart';
import 'package:Kelivo/features/workspace/widgets/files/file_browser_ops.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';
import 'package:Kelivo/theme/app_font_weights.dart';

class WorkspaceFilesDesktopLayout extends StatelessWidget {
  const WorkspaceFilesDesktopLayout({
    super.key,
    required this.workspaceId,
    this.initialRelativePath,
  });

  final String workspaceId;
  final String? initialRelativePath;

  @override
  Widget build(BuildContext context) {
    final workspace = context.watch<WorkspaceProvider>().byId(workspaceId);
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        leading: IosIconButton(
          icon: Lucide.ArrowLeft,
          tooltip: l10n.settingsPageBackButton,
          onTap: () => Navigator.of(context).maybePop(),
        ),
        title: Text(l10n.workspacesTitle),
      ),
      body: workspace == null
          ? Center(child: Text(l10n.workspaceFilesMissingWorkspace))
          : DesktopWorkspaceFiles(
              workspace: workspace,
              initialRelativePath: initialRelativePath,
            ),
    );
  }
}

/// Shared desktop detail pane for settings, the manager and a standalone page.
class DesktopWorkspaceFiles extends StatefulWidget {
  const DesktopWorkspaceFiles({
    super.key,
    required this.workspace,
    this.initialRelativePath,
  });

  final Workspace workspace;
  final String? initialRelativePath;

  @override
  State<DesktopWorkspaceFiles> createState() => _DesktopWorkspaceFilesState();
}

class _DesktopWorkspaceFilesState extends State<DesktopWorkspaceFiles> {
  late Future<String> _root;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _loadRoot();
  }

  void _loadRoot() {
    _root = context.read<WorkspaceProvider>().hostRootFor(widget.workspace);
  }

  @override
  void didUpdateWidget(DesktopWorkspaceFiles oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspace.id != widget.workspace.id ||
        oldWidget.workspace.hostPath != widget.workspace.hostPath) {
      _loadRoot();
    }
  }

  Future<void> _systemAction(
    WorkspaceRuntime runtime, {
    required bool terminal,
  }) async {
    try {
      final root = await _root;
      final cwd =
          FileBrowserOps.joinInsideRoot(root, widget.workspace.defaultCwd) ??
          root;
      if (terminal) {
        await runtime.openInSystemTerminal(cwd);
      } else {
        await runtime.revealInFileManager(root);
      }
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: error.toString(),
        type: NotificationType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final workspace = widget.workspace;
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final runtime = context.watch<WorkspaceRuntimeProvider?>()?.runtime;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    workspace.kind == WorkspaceKind.linked
                        ? Lucide.Link
                        : Lucide.FolderCode,
                    size: 22,
                    color: cs.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      workspace.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: AppFontWeights.semibold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  WorkspaceKindBadge(kind: workspace.kind),
                ],
              ),
              const SizedBox(height: 8),
              FutureBuilder<String>(
                future: _root,
                builder: (context, snapshot) => SelectableText(
                  snapshot.data ??
                      (snapshot.hasError ? l10n.workspaceFilesError : ''),
                  maxLines: 2,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (runtime?.supportsSystemTerminal == true)
                    DesktopWorkspaceButton(
                      label: l10n.workspaceDeskOpenSystemTerminal,
                      icon: Lucide.Terminal,
                      onPressed: () =>
                          unawaited(_systemAction(runtime!, terminal: true)),
                    ),
                  if (runtime != null)
                    DesktopWorkspaceButton(
                      label: l10n.workspaceDeskReveal,
                      icon: Lucide.FolderOpen,
                      onPressed: () =>
                          unawaited(_systemAction(runtime, terminal: false)),
                    ),
                  DesktopWorkspaceButton(
                    label: l10n.workspacesSettings,
                    icon: Lucide.Settings2,
                    onPressed: () =>
                        showWorkspaceSettingsEditor(context, workspace),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              WorkspaceDetailTabs(
                index: _tab,
                desktop: true,
                onChanged: (index) => setState(() => _tab = index),
              ),
            ],
          ),
        ),
        Divider(
          height: 1,
          thickness: 0.5,
          color: cs.outlineVariant.withValues(alpha: 0.12),
        ),
        Expanded(
          child: IndexedStack(
            index: _tab,
            children: [
              TickerMode(
                enabled: _tab == 0,
                child: FutureBuilder<String>(
                  future: _root,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: DesktopWorkspaceButton(
                          label: l10n.workspaceFilesRetry,
                          icon: Lucide.RefreshCw,
                          onPressed: () => setState(_loadRoot),
                        ),
                      );
                    }
                    final root = snapshot.data;
                    if (root == null) {
                      return const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    }
                    return FileBrowser(
                      key: ValueKey('${workspace.id}-$root'),
                      root: Directory(root),
                      rootLabel: workspace.name,
                      initialRelativePath: widget.initialRelativePath,
                      modelPathOf: (host) =>
                          WorkspaceModelPaths.workspaceFile(host, root),
                    );
                  },
                ),
              ),
              WorkspaceToolsPane(
                key: ValueKey(workspace.id),
                workspaceId: workspace.id,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
