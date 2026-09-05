import 'dart:async';

import 'package:Kelivo/core/models/workspace.dart';
import 'package:Kelivo/core/models/workspace_binding.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/workspace_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/workspace/tool_run_registry.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:Kelivo/features/workspace/pages/workspace_files_page.dart';
import 'package:Kelivo/features/workspace/pages/workspaces_page.dart';
import 'package:Kelivo/features/workspace/widgets/desktop_workspace_button.dart';
import 'package:Kelivo/features/workspace/widgets/files/conversation_files_panel.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';
import 'package:Kelivo/theme/app_font_weights.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Fixed-width desktop side bar for the conversation's workspace files.
class DesktopWorkspaceBar extends StatelessWidget {
  const DesktopWorkspaceBar({super.key, required this.conversationId});

  final String? conversationId;

  static const double width = 320;

  static const Key emptyStateKey = ValueKey<String>('workspace-desk-bar-empty');
  static const Key openTerminalKey = ValueKey<String>(
    'workspace-desk-bar-open-terminal',
  );
  static const Key revealKey = ValueKey<String>('workspace-desk-bar-reveal');
  static const Key closeKey = ValueKey<String>('workspace-desk-bar-close');
  static const Key runningKey = ValueKey<String>('workspace-desk-bar-running');
  static const Key headerTitleKey = ValueKey<String>(
    'workspace-desk-bar-title',
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final chat = context.watch<ChatService>();
    final workspaces = context.watch<WorkspaceProvider>();
    final runtime = context.watch<WorkspaceRuntimeProvider>().runtime;
    ToolRunRegistry? registry;
    try {
      registry = context.watch<ToolRunRegistry>();
    } on ProviderNotFoundException {
      registry = null;
    }

    final conversation = conversationId == null
        ? null
        : chat.getConversation(conversationId!);
    final binding = WorkspaceBinding.fromExtras(
      conversation?.extras ?? const <String, dynamic>{},
    );
    final workspace = binding.isBound
        ? workspaces.byId(binding.workspaceId!)
        : null;
    final bound = workspace != null;
    final showSystemActions =
        bound && runtime != null && runtime.supportsSystemTerminal;
    final running = registry?.running.isNotEmpty ?? false;

    return Material(
      color: Colors.transparent,
      child: Semantics(
        label: l10n.workspaceDeskBarTitle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              title: bound ? workspace.name : l10n.workspaceDeskBarNoWorkspace,
              kind: workspace?.kind,
              running: running,
              showSystemActions: showSystemActions,
              onOpenTerminal: () =>
                  unawaited(_openSystemTerminal(context, workspace!)),
              onReveal: () => unawaited(_reveal(context, workspace!)),
              onClose: () {
                unawaited(
                  context.read<SettingsProvider>().setDesktopWorkspaceBarOpen(
                    false,
                  ),
                );
              },
            ),
            Divider(
              height: 1,
              thickness: 0.5,
              color: cs.outlineVariant.withValues(alpha: 0.16),
            ),
            Expanded(
              child: conversationId != null
                  ? ConversationFilesPanel(
                      key: ValueKey<String>('$conversationId-${workspace?.id}'),
                      conversationId: conversationId!,
                      embedded: true,
                      initialTab: ConversationFilesTab.workspace,
                    )
                  : _EmptyState(hint: l10n.workspaceDeskBarEmptyHint),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _hostDir(BuildContext context, Workspace workspace) async {
    try {
      return await context.read<WorkspaceProvider>().hostRootFor(workspace);
    } catch (_) {
      return null;
    }
  }

  Future<void> _openSystemTerminal(
    BuildContext context,
    Workspace workspace,
  ) async {
    final runtime = context.read<WorkspaceRuntimeProvider>().runtime;
    if (runtime == null) return;
    final hostDir = await _hostDir(context, workspace);
    if (!context.mounted) return;
    if (hostDir == null || hostDir.isEmpty) {
      showAppSnackBar(
        context,
        message: AppLocalizations.of(context)!.terminalNotAvailable,
        type: NotificationType.error,
      );
      return;
    }
    try {
      await runtime.openInSystemTerminal(hostDir);
    } catch (error) {
      if (!context.mounted) return;
      showAppSnackBar(
        context,
        message: error.toString(),
        type: NotificationType.error,
      );
    }
  }

  Future<void> _reveal(BuildContext context, Workspace workspace) async {
    final runtime = context.read<WorkspaceRuntimeProvider>().runtime;
    if (runtime == null) return;
    final hostDir = await _hostDir(context, workspace);
    if (!context.mounted) return;
    if (hostDir == null || hostDir.isEmpty) return;
    try {
      await runtime.revealInFileManager(hostDir);
    } catch (error) {
      if (!context.mounted) return;
      showAppSnackBar(
        context,
        message: error.toString(),
        type: NotificationType.error,
      );
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.kind,
    required this.running,
    required this.showSystemActions,
    required this.onOpenTerminal,
    required this.onReveal,
    required this.onClose,
  });

  final String title;
  final WorkspaceKind? kind;
  final bool running;
  final bool showSystemActions;
  final VoidCallback onOpenTerminal;
  final VoidCallback onReveal;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
      child: Row(
        children: [
          if (running)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(
                key: DesktopWorkspaceBar.runningKey,
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    key: DesktopWorkspaceBar.headerTitleKey,
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: AppFontWeights.semibold,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                if (kind != null) ...[
                  const SizedBox(width: 8),
                  WorkspaceKindBadge(kind: kind!),
                ],
              ],
            ),
          ),
          if (showSystemActions) ...[
            Tooltip(
              message: l10n.workspaceDeskOpenSystemTerminal,
              child: IosIconButton(
                key: DesktopWorkspaceBar.openTerminalKey,
                icon: Lucide.Terminal,
                size: 16,
                minSize: 32,
                semanticLabel: l10n.workspaceDeskOpenSystemTerminal,
                onTap: onOpenTerminal,
              ),
            ),
            Tooltip(
              message: l10n.workspaceDeskReveal,
              child: IosIconButton(
                key: DesktopWorkspaceBar.revealKey,
                icon: Lucide.FolderOpen,
                size: 16,
                minSize: 32,
                semanticLabel: l10n.workspaceDeskReveal,
                onTap: onReveal,
              ),
            ),
          ],
          Tooltip(
            message: l10n.workspaceDeskBarClose,
            child: IosIconButton(
              key: DesktopWorkspaceBar.closeKey,
              icon: Lucide.ChevronRight,
              size: 16,
              minSize: 32,
              semanticLabel: l10n.workspaceDeskBarClose,
              onTap: onClose,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hint});

  final String hint;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      key: DesktopWorkspaceBar.emptyStateKey,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Lucide.Folder,
              size: 40,
              color: cs.onSurface.withValues(alpha: 0.28),
            ),
            const SizedBox(height: 12),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: cs.onSurface.withValues(alpha: 0.62),
              ),
            ),
            const SizedBox(height: 16),
            DesktopWorkspaceButton(
              label: AppLocalizations.of(context)!.workspaceEntryManage,
              icon: Lucide.FolderPlus,
              onPressed: () => openWorkspacesPage(context),
            ),
          ],
        ),
      ),
    );
  }
}
