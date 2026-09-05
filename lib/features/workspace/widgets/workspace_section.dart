import 'dart:async';

import 'package:Kelivo/core/models/workspace.dart';
import 'package:Kelivo/core/models/workspace_binding.dart';
import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/core/providers/workspace_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/haptics.dart';
import 'package:Kelivo/core/services/sandbox/environment_manager.dart';
import 'package:Kelivo/core/services/workspace/workspace_binding_actions.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:Kelivo/features/chat/utils/ensure_conversation.dart';
import 'package:Kelivo/features/chat/utils/sheet_navigation.dart';
import 'package:Kelivo/features/chat/widgets/tools_sheet_row.dart';
import 'package:Kelivo/features/workspace/terminal/open_terminal.dart';
import 'package:Kelivo/features/workspace/widgets/environment/environment_labels.dart';
import 'package:Kelivo/features/workspace/widgets/files/conversation_files_panel.dart';
import 'package:Kelivo/features/workspace/widgets/files/file_browser_ops.dart';
import 'package:Kelivo/features/workspace/widgets/files/workspace_prompts.dart';
import 'package:Kelivo/features/workspace/widgets/workspace_picker.dart';
import 'package:Kelivo/features/workspace/workspace_layout.dart';
import 'package:Kelivo/features/workspace/workspace_navigation.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/action_sheet.dart';
import 'package:Kelivo/shared/widgets/ios_switch.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'desktop_workspace_button.dart';

class WorkspaceSection extends StatefulWidget {
  const WorkspaceSection({
    super.key,
    this.conversationId,
    this.assistantId,
    this.onClose,
    this.environmentManager,
  });

  final String? conversationId;
  final String? assistantId;
  final VoidCallback? onClose;
  final EnvironmentManager? environmentManager;

  static const Key bindKey = ValueKey<String>('workspace-section-bind');
  static const Key changeKey = ValueKey<String>('workspace-section-change');
  static const Key unbindKey = ValueKey<String>('workspace-section-unbind');
  static const Key cwdKey = ValueKey<String>('workspace-section-cwd');
  static const Key cwdErrorKey = ValueKey<String>(
    'workspace-section-cwd-error',
  );
  static const Key allowAllKey = ValueKey<String>(
    'workspace-section-allow-all',
  );
  static const Key nameKey = ValueKey<String>('workspace-section-name');
  static const Key filesKey = ValueKey<String>('workspace-section-files');
  static const Key terminalKey = ValueKey<String>('workspace-section-terminal');
  static const Key revealKey = ValueKey<String>('workspace-section-reveal');
  static const Key environmentKey = ValueKey<String>(
    'workspace-section-environment',
  );
  static const Key createKey = ValueKey<String>('workspace-section-create');
  static const Key manageKey = ValueKey<String>('workspace-section-manage');

  static Key pickKey(String id) =>
      ValueKey<String>('workspace-section-pick-$id');

  @override
  State<WorkspaceSection> createState() => _WorkspaceSectionState();
}

class _WorkspaceSectionState extends State<WorkspaceSection> {
  String? _localConversationId;

  String? get _conversationId => _localConversationId ?? widget.conversationId;

  @override
  void didUpdateWidget(covariant WorkspaceSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.conversationId != oldWidget.conversationId ||
        widget.assistantId != oldWidget.assistantId) {
      _localConversationId = null;
    }
  }

  Future<String?> _ensureConversationId() async {
    final existing = _conversationId;
    if (existing != null && existing.isNotEmpty) return existing;
    final created = await ensureConversationId(
      context,
      assistantId: widget.assistantId,
    );
    if (created == null || !mounted) return created;
    setState(() => _localConversationId = created);
    return created;
  }

  Future<void> _writeBinding(WorkspaceBinding binding) async {
    final id = await _ensureConversationId();
    if (id == null || !mounted) return;
    await context.read<ChatService>().updateConversationExtras(
      id,
      binding.applyTo,
    );
  }

  void _afterClose(void Function(BuildContext ctx) action) {
    afterSheetClose(context, onClose: widget.onClose, action: action);
  }

  Future<void> _bind(Workspace workspace) async {
    final provider = context.read<WorkspaceProvider>();
    final id = await _ensureConversationId();
    if (id == null || !mounted) return;
    await bindConversationWorkspace(
      context,
      conversationId: id,
      workspace: workspace,
    );
    if (!mounted) return;
    unawaited(provider.touchLastUsed(workspace.id));
  }

  Future<void> _unbind() async {
    final id = await _ensureConversationId();
    if (id == null || !mounted) return;
    await unbindConversationWorkspace(context, conversationId: id);
  }

  Future<void> _pickWorkspace({String? selectedId}) async {
    Haptics.light();
    final chosen = await pickWorkspaceForConversation(
      context,
      selectedId: selectedId,
    );
    if (chosen == null || !mounted) return;
    await _bind(chosen);
  }

  Future<void> _editCwd(Workspace workspace, WorkspaceBinding binding) async {
    Haptics.light();
    final l10n = AppLocalizations.of(context)!;
    late final String root;
    try {
      root = await context.read<WorkspaceProvider>().hostRootFor(workspace);
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: l10n.workspaceEntryCwdInvalid,
        type: NotificationType.error,
      );
      return;
    }
    if (!mounted) return;
    final picked = await showWorkspaceFolderPicker(
      context,
      root: root,
      initialRelPath: binding.cwd,
      title: l10n.workspaceEntryCwd,
      rootLabel: workspace.name,
    );
    if (picked == null || !mounted) return;
    if (!FileBrowserOps.isValidRelativePath(picked)) {
      showAppSnackBar(
        context,
        message: l10n.workspaceEntryCwdInvalid,
        type: NotificationType.error,
      );
      return;
    }
    await _writeBinding(
      WorkspaceBinding(
        workspaceId: workspace.id,
        cwd: picked,
        toolsUsed: binding.toolsUsed,
        allowAll: binding.allowAll,
      ),
    );
  }

  Future<void> _setAllowAll(WorkspaceBinding binding, bool value) async {
    if (!binding.isBound) return;
    await _writeBinding(
      WorkspaceBinding(
        workspaceId: binding.workspaceId,
        cwd: binding.cwd,
        toolsUsed: binding.toolsUsed,
        allowAll: value,
      ),
    );
  }

  EnvironmentManager? _resolvedEnvManager() {
    if (widget.environmentManager != null) return widget.environmentManager;
    try {
      return context.watch<EnvironmentManager?>();
    } catch (_) {
      return null;
    }
  }

  void _openBoundMenu(
    BuildContext buttonContext,
    Workspace workspace,
    WorkspaceBinding binding,
  ) {
    Haptics.light();
    final l10n = AppLocalizations.of(context)!;
    final box = buttonContext.findRenderObject() as RenderBox?;
    final anchor = box == null
        ? Offset.zero
        : box.localToGlobal(Offset.zero) +
              Offset(box.size.width / 2, box.size.height / 2);
    unawaited(
      showAdaptiveActionMenu(
        context,
        anchor: anchor,
        title: workspace.name,
        items: [
          ActionSheetItem(
            key: WorkspaceSection.changeKey,
            icon: Lucide.RefreshCw,
            label: l10n.workspaceEntryChange,
            onTap: () => unawaited(
              _confirmToolsUsedThen(
                binding,
                title: l10n.workspaceEntryChangeConfirmTitle,
                confirmLabel: l10n.workspaceEntryChange,
                action: () => _pickWorkspace(selectedId: binding.workspaceId),
              ),
            ),
          ),
          ActionSheetItem(
            key: WorkspaceSection.unbindKey,
            icon: Lucide.Unlink,
            label: l10n.workspaceEntryUnbind,
            destructive: true,
            onTap: () => unawaited(
              _confirmToolsUsedThen(
                binding,
                title: l10n.workspaceEntryUnbindConfirmTitle,
                confirmLabel: l10n.workspaceEntryUnbind,
                action: _unbind,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmToolsUsedThen(
    WorkspaceBinding binding, {
    required String title,
    required String confirmLabel,
    required Future<void> Function() action,
  }) async {
    if (binding.toolsUsed) {
      final l10n = AppLocalizations.of(context)!;
      final ok = await showWorkspaceConfirm(
        context: context,
        title: title,
        message: l10n.workspaceEntryChangeConfirmBody,
        confirmLabel: confirmLabel,
        destructive: true,
      );
      if (!ok || !mounted) return;
    }
    await action();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final workspaces = context.watch<WorkspaceProvider>();
    final conversationId = _conversationId;
    Map<String, dynamic> extras = const <String, dynamic>{};
    try {
      extras = context.select<ChatService, Map<String, dynamic>>((chat) {
        if (conversationId == null) return const <String, dynamic>{};
        final conversation = chat.getConversation(conversationId);
        return conversation?.extras ?? const <String, dynamic>{};
      });
    } catch (_) {}
    final binding = WorkspaceBinding.fromExtras(extras);
    final workspace = binding.isBound
        ? workspaces.byId(binding.workspaceId!)
        : null;
    final runtime = context.watch<WorkspaceRuntimeProvider>().runtime;
    final env = context.watch<EnvironmentProvider>();
    final envManager = _resolvedEnvManager();
    final desktop = useDesktopWorkspaceLayout(context);
    final showEnvironment = envManager != null && !desktop;
    final envStatus = workspaceEnvPhaseLabel(l10n, env.state.phase);
    final chevron = ToolsSheetRow.chevron(context);

    if (desktop) {
      return _desktopPanel(l10n, workspace, binding, runtime);
    }

    final rows = <Widget>[];
    if (!binding.isBound || workspace == null) {
      rows.add(
        ToolsSheetRow(
          key: WorkspaceSection.bindKey,
          icon: Lucide.FolderPlus,
          label: l10n.workspaceEntryBind,
          onTap: () => unawaited(_pickWorkspace()),
          trailing: chevron,
        ),
      );
    } else {
      rows.add(_boundRow(l10n, workspace, binding, runtime));
      rows.add(
        ToolsSheetRow(
          key: WorkspaceSection.cwdKey,
          icon: Lucide.Folder,
          label: l10n.workspaceEntryCwd,
          detail: binding.cwd.isEmpty ? '/' : binding.cwd,
          onTap: () => _editCwd(workspace, binding),
          trailing: chevron,
        ),
      );
      if (showEnvironment) {
        rows.add(
          ToolsSheetRow(
            key: WorkspaceSection.environmentKey,
            icon: Lucide.HardDrive,
            label: l10n.workspaceEntryEnvironment,
            detail: envStatus,
            onTap: () {
              Haptics.light();
              _afterClose(WorkspaceNavigation.openEnvironmentPage);
            },
            trailing: chevron,
          ),
        );
      }
      rows.add(_allowAllRow(l10n, binding));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          rows[i],
        ],
      ],
    );
  }

  Widget _desktopPanel(
    AppLocalizations l10n,
    Workspace? workspace,
    WorkspaceBinding binding,
    WorkspaceRuntime? runtime,
  ) {
    final cs = Theme.of(context).colorScheme;
    if (workspace == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.workspaceDeskBarEmptyHint,
            style: TextStyle(color: cs.onSurfaceVariant, height: 1.5),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: DesktopWorkspaceButton(
              key: WorkspaceSection.bindKey,
              label: l10n.workspaceEntryBind,
              icon: Lucide.FolderPlus,
              primary: true,
              onPressed: () => unawaited(_pickWorkspace()),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Lucide.FolderCode, color: cs.primary, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                workspace.name,
                key: WorkspaceSection.nameKey,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Builder(
              builder: (buttonContext) => IosIconButton(
                icon: Lucide.Ellipsis,
                tooltip: l10n.workspacesItemMore,
                onTap: () => _openBoundMenu(buttonContext, workspace, binding),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            DesktopWorkspaceButton(
              key: WorkspaceSection.filesKey,
              label: l10n.workspaceEntryFiles,
              icon: Lucide.FolderOpen,
              onPressed: _openFiles,
            ),
            if (runtime != null &&
                (runtime.supportsSystemTerminal || runtime.supportsPty))
              DesktopWorkspaceButton(
                key: WorkspaceSection.terminalKey,
                label: runtime.supportsSystemTerminal
                    ? l10n.workspaceEntryOpenSystemTerminal
                    : l10n.workspaceEntryTerminal,
                icon: Lucide.Terminal,
                onPressed: runtime.supportsSystemTerminal
                    ? () => unawaited(
                        _openSystemThenClose(runtime, workspace, binding),
                      )
                    : _openTerminal,
              ),
            if (runtime != null)
              DesktopWorkspaceButton(
                key: WorkspaceSection.revealKey,
                label: l10n.workspaceEntryReveal,
                icon: Lucide.ExternalLink,
                onPressed: () =>
                    unawaited(_revealThenClose(runtime, workspace, binding)),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Divider(
          height: 1,
          thickness: 0.5,
          color: cs.outlineVariant.withValues(alpha: 0.12),
        ),
        const SizedBox(height: 12),
        ToolsSheetRow(
          key: WorkspaceSection.cwdKey,
          icon: Lucide.Folder,
          label: l10n.workspaceEntryCwd,
          detail: binding.cwd.isEmpty ? '/' : binding.cwd,
          trailing: ToolsSheetRow.chevron(context),
          onTap: () => _editCwd(workspace, binding),
        ),
        const SizedBox(height: 12),
        _allowAllRow(l10n, binding),
      ],
    );
  }

  /// The bound workspace itself. Tapping the row switches or unbinds it, and
  /// the shortcuts that only exist while something is bound — files, terminal,
  /// reveal — ride along as icon buttons instead of costing a row each.
  Widget _boundRow(
    AppLocalizations l10n,
    Workspace workspace,
    WorkspaceBinding binding,
    WorkspaceRuntime? runtime,
  ) {
    final cs = Theme.of(context).colorScheme;
    final tint = cs.onSurface.withValues(alpha: 0.7);

    Widget action({
      required Key key,
      required IconData icon,
      required String label,
      required VoidCallback onTap,
    }) {
      return IosIconButton(
        key: key,
        icon: icon,
        size: 18,
        padding: const EdgeInsets.all(6),
        color: tint,
        semanticLabel: label,
        tooltip: label,
        onTap: onTap,
      );
    }

    return Builder(
      builder: (rowContext) => ToolsSheetRow(
        key: WorkspaceSection.nameKey,
        icon: Lucide.FolderCode,
        label: workspace.name,
        onTap: () => _openBoundMenu(rowContext, workspace, binding),
        // Shift out the last button's own tap padding so the icons end on the
        // same edge as the switches and chevrons on the rows below.
        trailing: Transform.translate(
          offset: const Offset(6, 0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox.shrink(key: WorkspaceSection.unbindKey),
              const SizedBox.shrink(key: WorkspaceSection.changeKey),
              action(
                key: WorkspaceSection.filesKey,
                icon: Lucide.FolderOpen,
                label: l10n.workspaceEntryFiles,
                onTap: _openFiles,
              ),
              if (runtime != null && runtime.supportsPty)
                action(
                  key: WorkspaceSection.terminalKey,
                  icon: Lucide.Terminal,
                  label: l10n.workspaceEntryTerminal,
                  onTap: _openTerminal,
                )
              else if (runtime != null && runtime.supportsSystemTerminal)
                action(
                  key: WorkspaceSection.terminalKey,
                  icon: Lucide.Terminal,
                  label: l10n.workspaceEntryOpenSystemTerminal,
                  onTap: () => unawaited(
                    _openSystemThenClose(runtime, workspace, binding),
                  ),
                ),
              if (runtime != null && useDesktopWorkspaceLayout(context))
                action(
                  key: WorkspaceSection.revealKey,
                  icon: Lucide.ExternalLink,
                  label: l10n.workspaceEntryReveal,
                  onTap: () =>
                      unawaited(_revealThenClose(runtime, workspace, binding)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openFiles() {
    Haptics.light();
    final id = _conversationId;
    if (id == null) return;
    _afterClose((ctx) {
      unawaited(
        showConversationFilesPanel(
          ctx,
          conversationId: id,
          initialTab: ConversationFilesTab.workspace,
        ),
      );
    });
  }

  void _openTerminal() {
    Haptics.light();
    final id = _conversationId;
    _afterClose((ctx) {
      unawaited(openTerminal(ctx, conversationId: id));
    });
  }

  Future<String> _hostCwd(Workspace workspace, WorkspaceBinding binding) async {
    final root = await context.read<WorkspaceProvider>().hostRootFor(workspace);
    final resolved = FileBrowserOps.joinInsideRoot(root, binding.cwd);
    return resolved ?? root;
  }

  Future<void> _openSystemThenClose(
    WorkspaceRuntime runtime,
    Workspace workspace,
    WorkspaceBinding binding,
  ) async {
    try {
      final cwd = await _hostCwd(workspace, binding);
      if (!mounted) return;
      _afterClose((ctx) {
        unawaited(() async {
          try {
            await runtime.openInSystemTerminal(cwd);
          } catch (error) {
            if (!ctx.mounted) return;
            showAppSnackBar(
              ctx,
              message: error.toString(),
              type: NotificationType.error,
            );
          }
        }());
      });
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: error.toString(),
        type: NotificationType.error,
      );
    }
  }

  Future<void> _revealThenClose(
    WorkspaceRuntime runtime,
    Workspace workspace,
    WorkspaceBinding binding,
  ) async {
    try {
      final cwd = await _hostCwd(workspace, binding);
      if (!mounted) return;
      _afterClose((ctx) {
        unawaited(() async {
          try {
            await runtime.revealInFileManager(cwd);
          } catch (error) {
            if (!ctx.mounted) return;
            showAppSnackBar(
              ctx,
              message: error.toString(),
              type: NotificationType.error,
            );
          }
        }());
      });
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: error.toString(),
        type: NotificationType.error,
      );
    }
  }

  Widget _allowAllRow(AppLocalizations l10n, WorkspaceBinding binding) {
    return ToolsSheetRow(
      icon: Lucide.Shield,
      label: l10n.workspaceEntryAllowAll,
      subtitle: l10n.workspaceEntryAllowAllSubtitle,
      trailing: IosSwitch(
        key: WorkspaceSection.allowAllKey,
        value: binding.allowAll,
        semanticLabel: l10n.workspaceEntryAllowAll,
        onChanged: (value) => unawaited(_setAllowAll(binding, value)),
      ),
    );
  }
}
