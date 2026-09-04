import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/workspace.dart';
import 'package:Kelivo/core/models/workspace_binding.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/core/providers/workspace_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/haptics.dart';
import 'package:Kelivo/core/services/sandbox/environment_manager.dart';
import 'package:Kelivo/core/services/workspace/workspace_binding_actions.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:Kelivo/features/chat/widgets/tools_sheet_row.dart';
import 'package:Kelivo/features/workspace/terminal/open_terminal.dart';
import 'package:Kelivo/features/workspace/widgets/environment/environment_labels.dart';
import 'package:Kelivo/features/workspace/widgets/files/conversation_files_panel.dart';
import 'package:Kelivo/features/workspace/widgets/files/file_browser_ops.dart';
import 'package:Kelivo/features/workspace/widgets/files/workspace_prompts.dart';
import 'package:Kelivo/features/workspace/widgets/skills/conversation_skills_sheet.dart';
import 'package:Kelivo/features/workspace/widgets/workspace_picker.dart';
import 'package:Kelivo/features/workspace/workspace_navigation.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/responsive/screen_type_helper.dart';
import 'package:Kelivo/shared/widgets/action_sheet.dart';
import 'package:Kelivo/shared/widgets/ios_switch.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';

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
  static const Key moreKey = ValueKey<String>('workspace-section-more');
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
  static const Key skillsKey = ValueKey<String>('workspace-section-skills');
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
    final chat = context.read<ChatService>();
    String? assistantId = widget.assistantId;
    if (assistantId == null) {
      try {
        assistantId = context.read<AssistantProvider>().currentAssistantId;
      } catch (_) {}
    }
    try {
      final draft = await chat.createDraftConversation(
        assistantId: assistantId,
      );
      if (!mounted) return draft.id;
      setState(() => _localConversationId = draft.id);
      return draft.id;
    } catch (_) {
      return null;
    }
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
    // Pop the tools sheet first and wait until its route is gone. Pushing the
    // files (or skills) dialog in a microtask races `maybePop`: the delayed
    // `pop()` can remove the new dialog instead, leaving its transparent
    // `ModalBarrier` on screen so the home UI looks fine but ignores taps.
    final navigator = Navigator.of(context);
    final route = ModalRoute.of(context);
    final waitForPopup = route is PopupRoute ? route.completed : null;
    widget.onClose?.call();
    unawaited(() async {
      if (waitForPopup != null) {
        await waitForPopup;
      }
      await WidgetsBinding.instance.endOfFrame;
      if (!navigator.mounted) return;
      action(navigator.context);
    }());
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

  Assistant? _assistant() {
    try {
      final ap = context.read<AssistantProvider>();
      final id = widget.assistantId;
      if (id != null) return ap.getById(id);
      return ap.currentAssistant;
    } catch (_) {
      return null;
    }
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
    final desktop = ResponsiveHelper.isDesktop(context);
    final showEnvironment = envManager != null && !desktop;
    final envStatus = workspaceEnvPhaseLabel(l10n, env.state.phase);
    final chevron = ToolsSheetRow.chevron(context);

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
      rows.add(_boundHeader(l10n, workspace, binding, envStatus));
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
      rows.add(
        ToolsSheetRow(
          key: WorkspaceSection.filesKey,
          icon: Lucide.FolderOpen,
          label: l10n.workspaceEntryFiles,
          onTap: () {
            Haptics.light();
            final id = conversationId;
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
          },
          trailing: chevron,
        ),
      );
      if (conversationId != null) {
        rows.add(
          ToolsSheetRow(
            key: WorkspaceSection.skillsKey,
            icon: Lucide.Sparkles,
            label: l10n.workspaceEntrySessionSkills,
            onTap: () {
              Haptics.light();
              final assistant = _assistant();
              _afterClose((ctx) {
                unawaited(
                  showConversationSkillsSheet(
                    ctx,
                    conversationId: conversationId,
                    assistant: assistant,
                  ),
                );
              });
            },
            trailing: chevron,
          ),
        );
      }
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
      if (runtime != null) {
        rows.addAll(_terminalRows(l10n, runtime, workspace, binding, chevron));
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

  Widget _boundHeader(
    AppLocalizations l10n,
    Workspace workspace,
    WorkspaceBinding binding,
    String envStatus,
  ) {
    final cs = Theme.of(context).colorScheme;

    return ToolsSheetRow(
      key: WorkspaceSection.nameKey,
      icon: Lucide.FolderCode,
      label: workspace.name,
      subtitle: envStatus,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox.shrink(key: WorkspaceSection.unbindKey),
          Builder(
            builder: (buttonContext) {
              return IosIconButton(
                key: WorkspaceSection.moreKey,
                icon: Lucide.Ellipsis,
                size: 18,
                padding: const EdgeInsets.all(6),
                color: cs.onSurface.withValues(alpha: 0.7),
                semanticLabel: l10n.workspaceFilesMore,
                tooltip: l10n.workspaceFilesMore,
                onTap: () => _openBoundMenu(buttonContext, workspace, binding),
              );
            },
          ),
          const SizedBox.shrink(key: WorkspaceSection.changeKey),
        ],
      ),
    );
  }

  List<Widget> _terminalRows(
    AppLocalizations l10n,
    WorkspaceRuntime runtime,
    Workspace workspace,
    WorkspaceBinding binding,
    Widget chevron,
  ) {
    final rows = <Widget>[];
    if (runtime.supportsPty) {
      rows.add(
        ToolsSheetRow(
          key: WorkspaceSection.terminalKey,
          icon: Lucide.Terminal,
          label: l10n.workspaceEntryTerminal,
          onTap: () {
            Haptics.light();
            final id = _conversationId;
            _afterClose((ctx) {
              unawaited(openTerminal(ctx, conversationId: id));
            });
          },
          trailing: chevron,
        ),
      );
    } else if (runtime.supportsSystemTerminal) {
      rows.add(
        ToolsSheetRow(
          key: WorkspaceSection.terminalKey,
          icon: Lucide.Terminal,
          label: l10n.workspaceEntryOpenSystemTerminal,
          onTap: () {
            Haptics.light();
            unawaited(_openSystemThenClose(runtime, workspace, binding));
          },
          trailing: chevron,
        ),
      );
    }
    if (ResponsiveHelper.isDesktop(context)) {
      rows.add(
        ToolsSheetRow(
          key: WorkspaceSection.revealKey,
          icon: Lucide.FolderOpen,
          label: l10n.workspaceEntryReveal,
          onTap: () {
            Haptics.light();
            unawaited(_revealThenClose(runtime, workspace, binding));
          },
          trailing: chevron,
        ),
      );
    }
    return rows;
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
