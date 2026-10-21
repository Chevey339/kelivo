import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/mcp_provider.dart';
import 'package:Kelivo/core/providers/workspace_provider.dart';
import 'package:Kelivo/core/models/workspace_binding.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/haptics.dart';
import 'package:Kelivo/features/home/services/local_tool_labels.dart';
import 'package:Kelivo/features/home/services/local_tool_toggle.dart';
import 'package:Kelivo/features/home/services/local_tools_service.dart';
import 'package:Kelivo/features/workspace/widgets/workspace_section.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_switch.dart';
import 'package:Kelivo/theme/app_font_weights.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';

import 'tools_sheet_row.dart';

/// Everything the model can call in this chat: device-local tools, connected
/// MCP servers, and the workspace binding. Replaces the MCP-only sheet that
/// used to sit behind the composer's tool button.
Future<void> showChatToolsSheet(
  BuildContext context, {
  required String assistantId,
  String? conversationId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.overlaySurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => ChatToolsSheet(
      assistantId: assistantId,
      conversationId: conversationId,
      onClose: () => Navigator.of(sheetContext).maybePop(),
    ),
  );
}

class ChatToolsSheet extends StatefulWidget {
  const ChatToolsSheet({
    super.key,
    required this.assistantId,
    this.conversationId,
    this.onClose,
  });

  final String assistantId;
  final String? conversationId;
  final VoidCallback? onClose;

  static const Key localGroupKey = ValueKey<String>('chat-tools-group-local');
  static const Key mcpGroupKey = ValueKey<String>('chat-tools-group-mcp');
  static const Key workspaceGroupKey = ValueKey<String>(
    'chat-tools-group-workspace',
  );
  static Key localToolKey(String id) =>
      ValueKey<String>('chat-tools-local-$id');

  static Key mcpServerKey(String id) => ValueKey<String>('chat-tools-mcp-$id');

  @override
  State<ChatToolsSheet> createState() => _ChatToolsSheetState();
}

enum _ToolsGroupId { local, mcp, workspace }

/// Which groups are open, remembered across sheets and restarts.
const String _expandedGroupsKey = 'display_chat_tools_expanded_groups_v1';

/// Until the user folds something themselves: local tools are the longest
/// list, so they start folded; the two groups the sheet is usually opened for
/// start open.
const Set<_ToolsGroupId> _defaultExpandedGroups = <_ToolsGroupId>{
  _ToolsGroupId.mcp,
  _ToolsGroupId.workspace,
};

class _ChatToolsSheetState extends State<ChatToolsSheet> {
  late final BusinessPreferences _preferences = context
      .read<BusinessPreferences>();
  late final Set<_ToolsGroupId> _expanded = _readExpanded();

  Set<_ToolsGroupId> _readExpanded() {
    final stored = _preferences.getStringList(_expandedGroupsKey);
    if (stored == null) return <_ToolsGroupId>{..._defaultExpandedGroups};
    return <_ToolsGroupId>{
      for (final group in _ToolsGroupId.values)
        if (stored.contains(group.name)) group,
    };
  }

  void _toggleGroup(_ToolsGroupId group) {
    Haptics.light();
    setState(() {
      if (!_expanded.remove(group)) _expanded.add(group);
    });
    unawaited(
      _preferences.setStringList(_expandedGroupsKey, <String>[
        for (final id in _ToolsGroupId.values)
          if (_expanded.contains(id)) id.name,
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.8;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 34,
              child: Center(
                child: Text(
                  l10n.chatInputBarToolsTooltip,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: AppFontWeights.emphasis,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _LocalToolsGroup(
                      assistantId: widget.assistantId,
                      expanded: _expanded.contains(_ToolsGroupId.local),
                      onToggle: () => _toggleGroup(_ToolsGroupId.local),
                    ),
                    _McpGroup(
                      assistantId: widget.assistantId,
                      expanded: _expanded.contains(_ToolsGroupId.mcp),
                      onToggle: () => _toggleGroup(_ToolsGroupId.mcp),
                    ),
                    _WorkspaceGroup(
                      assistantId: widget.assistantId,
                      conversationId: widget.conversationId,
                      expanded: _expanded.contains(_ToolsGroupId.workspace),
                      onToggle: () => _toggleGroup(_ToolsGroupId.workspace),
                      onClose: widget.onClose,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Foldable block: a quiet section header over a column of [ToolsSheetRow]
/// tiles.
///
/// The header borrows the tile's own geometry so the sheet reads as three
/// columns and nothing else: the disclosure chevron sits in the tiles' 20px
/// icon column, the title on their label baseline, and the folded summary ends
/// on the same right edge as every switch and chevron below it.
class _ToolsGroup extends StatelessWidget {
  const _ToolsGroup({
    super.key,
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.children,
    this.summary,
    this.isFirst = false,
  });

  /// Matches `ToolsSheetRow`: horizontal padding 12, 20px icon, 10px gap.
  static const double _rowPadding = 12;
  static const double _iconColumn = 20;
  static const double _iconGap = 10;

  final String title;
  final String? summary;
  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> children;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final summaryText = summary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isFirst) const SizedBox(height: 14),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: _rowPadding),
            child: SizedBox(
              height: 32,
              child: Row(
                children: [
                  SizedBox(
                    width: _iconColumn,
                    child: Center(
                      child: AnimatedRotation(
                        turns: expanded ? 0.25 : 0,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        child: Icon(
                          Lucide.ChevronRight,
                          size: 14,
                          color: cs.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: _iconGap),
                  // Expanded (not Flexible + Spacer): the title has to absorb
                  // all the slack, or the trailing text gets a share of it and
                  // floats away from the right edge the rows align to.
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: AppFontWeights.semibold,
                        color: cs.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!expanded &&
                      summaryText != null &&
                      summaryText.isNotEmpty)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: Text(
                        summaryText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: expanded
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < children.length; i++) ...[
                      if (i > 0) const SizedBox(height: 8),
                      children[i],
                    ],
                  ],
                )
              : const SizedBox(width: double.infinity, height: 0),
        ),
      ],
    );
  }
}

class _LocalToolsGroup extends StatelessWidget {
  const _LocalToolsGroup({
    required this.assistantId,
    required this.expanded,
    required this.onToggle,
  });

  final String assistantId;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    if (DeviceLocalTools.iosDeviceToolsSupported) {
      // Weather / health availability is only known after the capability
      // prefetch resolves; rebuild once it does so those rows can appear.
      return FutureBuilder<bool>(
        future: DeviceLocalTools.prefetchIosCapabilities(),
        builder: (context, _) => _build(context),
      );
    }
    return _build(context);
  }

  Widget _build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final assistant = context.select<AssistantProvider, Assistant?>(
      (provider) => provider.getById(assistantId),
    );
    if (assistant == null) return const SizedBox.shrink();
    final ids = availableLocalToolIds();
    final enabled = assistant.localToolIds.toSet();
    final enabledCount = ids.where(enabled.contains).length;

    return _ToolsGroup(
      key: ChatToolsSheet.localGroupKey,
      isFirst: true,
      title: l10n.assistantEditPageLocalToolsTab,
      summary: '$enabledCount/${ids.length}',
      expanded: expanded,
      onToggle: onToggle,
      children: [
        for (final id in ids)
          ToolsSheetRow(
            key: ChatToolsSheet.localToolKey(id),
            icon: localToolIcon(id),
            label: localToolTitle(l10n, id),
            selected: enabled.contains(id),
            onTap: () => unawaited(
              setLocalToolEnabled(
                context,
                assistant: assistant,
                toolId: id,
                value: !enabled.contains(id),
              ),
            ),
            trailing: IosSwitch(
              value: enabled.contains(id),
              semanticLabel: localToolTitle(l10n, id),
              onChanged: (value) => unawaited(
                setLocalToolEnabled(
                  context,
                  assistant: assistant,
                  toolId: id,
                  value: value,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _McpGroup extends StatelessWidget {
  const _McpGroup({
    required this.assistantId,
    required this.expanded,
    required this.onToggle,
  });

  final String assistantId;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final mcp = context.watch<McpProvider>();
    final assistant = context.select<AssistantProvider, Assistant?>(
      (provider) => provider.getById(assistantId),
    );
    if (assistant == null) return const SizedBox.shrink();
    final servers = mcp.servers
        .where((server) => mcp.statusFor(server.id) == McpStatus.connected)
        .toList(growable: false);
    // Nothing connected means nothing to choose from — skip the empty block.
    if (servers.isEmpty) return const SizedBox.shrink();

    final selected = assistant.mcpServerIds.toSet();
    final selectedCount = servers
        .where((server) => selected.contains(server.id))
        .length;

    Future<void> setIds(Iterable<String> ids) {
      return context.read<AssistantProvider>().updateAssistant(
        assistant.copyWith(mcpServerIds: ids.toList(growable: false)),
      );
    }

    Future<void> setSelected(String id, bool value) {
      final next = assistant.mcpServerIds.toSet();
      if (value) {
        next.add(id);
      } else {
        next.remove(id);
      }
      return setIds(next);
    }

    return _ToolsGroup(
      key: ChatToolsSheet.mcpGroupKey,
      title: l10n.mcpAssistantSheetTitle,
      summary: '$selectedCount/${servers.length}',
      expanded: expanded,
      onToggle: onToggle,
      children: [
        for (final server in servers)
          ToolsSheetRow(
            key: ChatToolsSheet.mcpServerKey(server.id),
            icon: Lucide.Hammer,
            label: server.name,
            selected: selected.contains(server.id),
            detail: l10n.assistantEditMcpToolsCountTag(
              server.tools.where((tool) => tool.enabled).length.toString(),
              server.tools.length.toString(),
            ),
            onTap: () => unawaited(
              setSelected(server.id, !selected.contains(server.id)),
            ),
            trailing: IosSwitch(
              value: selected.contains(server.id),
              semanticLabel: server.name,
              onChanged: (value) => unawaited(setSelected(server.id, value)),
            ),
          ),
      ],
    );
  }
}

class _WorkspaceGroup extends StatelessWidget {
  const _WorkspaceGroup({
    required this.assistantId,
    required this.conversationId,
    required this.expanded,
    required this.onToggle,
    this.onClose,
  });

  final String assistantId;
  final String? conversationId;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _ToolsGroup(
      key: ChatToolsSheet.workspaceGroupKey,
      title: l10n.workspacesTitle,
      // Only read while folded, where the section's own first row is hidden.
      summary: _boundName(context),
      expanded: expanded,
      onToggle: onToggle,
      children: [
        WorkspaceSection(
          key: ValueKey<String?>(conversationId),
          conversationId: conversationId,
          assistantId: assistantId,
          onClose: onClose,
        ),
      ],
    );
  }

  String? _boundName(BuildContext context) {
    final id = conversationId;
    if (id == null || id.isEmpty) return null;
    Map<String, dynamic> extras = const <String, dynamic>{};
    try {
      extras = context.select<ChatService, Map<String, dynamic>>(
        (chat) => chat.getConversation(id)?.extras ?? const <String, dynamic>{},
      );
    } catch (_) {
      return null;
    }
    final binding = WorkspaceBinding.fromExtras(extras);
    if (!binding.isBound) return null;
    try {
      return context
          .watch<WorkspaceProvider>()
          .byId(binding.workspaceId!)
          ?.name;
    } catch (_) {
      return null;
    }
  }
}
