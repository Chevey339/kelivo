import 'dart:async';
import 'dart:io';

import 'package:Kelivo/core/models/workspace.dart';
import 'package:Kelivo/core/models/workspace_binding.dart';
import 'package:Kelivo/core/providers/workspace_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/workspace/workspace_binding_actions.dart';
import 'package:Kelivo/core/services/haptics.dart';
import 'package:Kelivo/features/settings/widgets/custom_theme_widgets.dart';
import 'package:Kelivo/features/workspace/widgets/files/file_browser.dart';
import 'package:Kelivo/features/workspace/widgets/files/file_browser_ops.dart';
import 'package:Kelivo/features/workspace/widgets/workspace_picker.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/features/workspace/workspace_layout.dart';
import 'package:Kelivo/shared/widgets/custom_bottom_sheet.dart';
import 'package:Kelivo/shared/widgets/ios_tile_button.dart';
import 'package:Kelivo/shared/widgets/segmented_tabs.dart';
import 'package:Kelivo/theme/app_font_weights.dart';
import 'package:Kelivo/utils/app_directories.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

enum ConversationFilesTab { attachments, outputs, workspace }

Future<void> showConversationFilesPanel(
  BuildContext context, {
  required String conversationId,
  ConversationFilesTab initialTab = ConversationFilesTab.attachments,
}) {
  final l10n = AppLocalizations.of(context)!;
  if (useDesktopWorkspaceLayout(context)) {
    final height = MediaQuery.sizeOf(context).height * 0.8;
    return showAppDialog<void>(
      context,
      maxWidth: 760,
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            AppDialogHeader(title: l10n.workspaceFilesPanelTitle),
            Expanded(
              child: ConversationFilesPanel(
                conversationId: conversationId,
                initialTab: initialTab,
                embedded: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
  return showCustomBottomSheet<void>(
    context: context,
    title: l10n.workspaceFilesPanelTitle,
    partialHeightFactor: 0.90,
    expandedHeightFactor: 0.90,
    builder: (ctx, scrollController) {
      return ConversationFilesPanel(
        conversationId: conversationId,
        initialTab: initialTab,
        scrollController: scrollController,
      );
    },
  );
}

class ConversationFilesPanel extends StatefulWidget {
  const ConversationFilesPanel({
    super.key,
    required this.conversationId,
    this.embedded = false,
    this.initialTab = ConversationFilesTab.attachments,
    this.scrollController,
  });

  final String conversationId;

  /// When true, the dialog/sheet chrome is omitted so the tabs can sit in a
  /// desktop side bar or other host that already provides a header.
  final bool embedded;

  final ConversationFilesTab initialTab;

  /// Handed to whichever tab is showing, so the host sheet can tell a list
  /// scroll apart from a pull on the sheet itself.
  final ScrollController? scrollController;

  static const Key unboundHintKey = ValueKey<String>(
    'conversation-files-unbound',
  );
  static const Key tabsKey = ValueKey<String>('conversation-files-tabs');
  static const Key bindCtaKey = ValueKey<String>('conversation-files-bind');

  @override
  ConversationFilesPanelState createState() => ConversationFilesPanelState();
}

class ConversationFilesPanelState extends State<ConversationFilesPanel> {
  late int _index;
  Directory? _attachments;
  Directory? _outputs;
  Directory? _workspaceRoot;
  Workspace? _workspace;
  Object? _error;
  bool _bound = false;
  bool _loaded = false;

  ConversationFilesTab get currentTab => ConversationFilesTab.values[_index];

  @override
  void initState() {
    super.initState();
    _index = widget.initialTab.index;
    unawaited(load());
  }

  @override
  void didUpdateWidget(ConversationFilesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationId != widget.conversationId) {
      unawaited(load());
    }
  }

  Future<void> _pickAndBind() async {
    Haptics.light();
    final chosen = await pickWorkspaceForConversation(context);
    if (chosen == null || !mounted) return;
    final provider = context.read<WorkspaceProvider>();
    await bindConversationWorkspace(
      context,
      conversationId: widget.conversationId,
      workspace: chosen,
    );
    unawaited(provider.touchLastUsed(chosen.id));
    if (!mounted) return;
    await load();
  }

  @visibleForTesting
  Future<void> load() async {
    try {
      final chat = context.read<ChatService>();
      final provider = context.read<WorkspaceProvider>();
      final session = await AppDirectories.sessionDir(widget.conversationId);
      if (!mounted) return;
      final attachments = Directory('${session.path}/attachments');
      final outputs = Directory('${session.path}/outputs');
      final conversation = chat.getConversation(widget.conversationId);
      final binding = WorkspaceBinding.fromExtras(
        conversation?.extras ?? const <String, dynamic>{},
      );
      Directory? workspaceRoot;
      Workspace? workspace;
      if (binding.isBound) {
        workspace = provider.byId(binding.workspaceId!);
        if (workspace != null) {
          final host = await provider.hostRootFor(workspace);
          workspaceRoot = Directory(host);
        }
      }
      if (!mounted) return;
      setState(() {
        _attachments = attachments;
        _outputs = outputs;
        _workspaceRoot = workspaceRoot;
        _workspace = workspace;
        _bound = binding.isBound && workspace != null;
        _error = null;
        _loaded = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: SegmentedTabs(
            key: ConversationFilesPanel.tabsKey,
            tabs: [
              SegmentedTab(
                label: l10n.workspaceFilesTabAttachments,
                icon: Lucide.Paperclip,
              ),
              SegmentedTab(
                label: l10n.workspaceFilesTabOutputs,
                icon: Lucide.Sparkles,
              ),
              SegmentedTab(
                label: l10n.workspaceFilesTabWorkspace,
                icon: Lucide.FolderCode,
              ),
            ],
            index: _index,
            onChanged: (value) => setState(() => _index = value),
            expand: true,
            height: 40,
          ),
        ),
        Expanded(child: _buildTabBody(l10n, cs)),
      ],
    );
  }

  Widget _buildTabBody(AppLocalizations l10n, ColorScheme cs) {
    if (_error != null) {
      return Center(
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
                    _error = null;
                    _loaded = false;
                  });
                  unawaited(load());
                },
              ),
            ],
          ),
        ),
      );
    }
    if (!_loaded || _attachments == null || _outputs == null) {
      return const Center(child: CupertinoActivityIndicator(radius: 12));
    }

    switch (currentTab) {
      case ConversationFilesTab.attachments:
        return FileBrowser(
          root: _attachments!,
          rootLabel: l10n.workspaceFilesTabAttachments,
          readOnly: true,
          emptyIcon: Lucide.Paperclip,
          emptyTitle: l10n.workspaceFilesEmptyAttachments,
          scrollController: widget.scrollController,
          modelPathOf: (host) => WorkspaceModelPaths.chatFile(
            host,
            _attachments!.path,
            'attachments',
          ),
        );
      case ConversationFilesTab.outputs:
        return FileBrowser(
          root: _outputs!,
          rootLabel: l10n.workspaceFilesTabOutputs,
          readOnly: true,
          emptyIcon: Lucide.Sparkles,
          emptyTitle: l10n.workspaceFilesEmptyOutputs,
          scrollController: widget.scrollController,
          modelPathOf: (host) =>
              WorkspaceModelPaths.chatFile(host, _outputs!.path, 'outputs'),
        );
      case ConversationFilesTab.workspace:
        return _buildWorkspaceTab(l10n, cs);
    }
  }

  Widget _buildWorkspaceTab(AppLocalizations l10n, ColorScheme cs) {
    if (!_bound || _workspaceRoot == null || _workspace == null) {
      return Center(
        key: ConversationFilesPanel.unboundHintKey,
        child: Padding(
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
                l10n.workspaceFilesNoWorkspaceBound,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: AppFontWeights.semibold,
                  color: cs.onSurface.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(height: 16),
              IosTileButton(
                key: ConversationFilesPanel.bindCtaKey,
                icon: Lucide.FolderPlus,
                label: l10n.workspaceEntryBind,
                backgroundColor: cs.primary,
                onTap: () => unawaited(_pickAndBind()),
              ),
            ],
          ),
        ),
      );
    }
    final root = _workspaceRoot!;
    return FileBrowser(
      root: root,
      rootLabel: _workspace!.name,
      scrollController: widget.scrollController,
      modelPathOf: (host) => WorkspaceModelPaths.workspaceFile(host, root.path),
    );
  }
}
