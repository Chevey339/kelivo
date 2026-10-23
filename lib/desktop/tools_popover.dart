import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../core/providers/mcp_provider.dart';
import '../core/providers/assistant_provider.dart';
import '../features/home/services/local_tool_labels.dart';
import '../features/home/services/local_tool_toggle.dart';
import '../core/database/business_preferences.dart';
import '../core/models/workspace_binding.dart';
import '../core/providers/workspace_provider.dart';
import '../core/services/chat/chat_service.dart';
import '../features/chat/widgets/tools_section_header.dart';
import '../features/mcp/widgets/mcp_server_avatar.dart';
import '../features/workspace/widgets/workspace_section.dart';
import '../shared/widgets/ios_switch.dart';
import '../theme/app_semantic_colors.dart';
import 'desktop_settings_navigation_bus.dart';
import '../theme/design_tokens.dart';

Future<void> showDesktopToolsPopover(
  BuildContext context, {
  required GlobalKey anchorKey,
  required String assistantId,
  String? conversationId,
}) async {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;
  final keyContext = anchorKey.currentContext;
  if (keyContext == null) return;

  final box = keyContext.findRenderObject() as RenderBox?;
  if (box == null) return;
  final offset = box.localToGlobal(Offset.zero);
  final size = box.size;
  final anchorRect = Rect.fromLTWH(
    offset.dx,
    offset.dy,
    size.width,
    size.height,
  );

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => _ToolsPopover(
      anchorRect: anchorRect,
      anchorWidth: size.width,
      assistantId: assistantId,
      conversationId: conversationId,
      onClose: () {
        try {
          entry.remove();
        } catch (_) {}
      },
    ),
  );
  overlay.insert(entry);
}

class _ToolsPopover extends StatefulWidget {
  const _ToolsPopover({
    required this.anchorRect,
    required this.anchorWidth,
    required this.assistantId,
    required this.onClose,
    this.conversationId,
  });

  final Rect anchorRect;
  final double anchorWidth;
  final String assistantId;
  final String? conversationId;
  final VoidCallback onClose;

  @override
  State<_ToolsPopover> createState() => _ToolsPopoverState();
}

class _ToolsPopoverState extends State<_ToolsPopover>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  Offset _offset = const Offset(0, 0.12);
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      setState(() => _offset = Offset.zero);
      try {
        await _controller.forward();
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    setState(() => _offset = const Offset(0, 1.0));
    try {
      await _controller.reverse();
    } catch (_) {}
    if (mounted) widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final width = (widget.anchorWidth - 16).clamp(260.0, 720.0);
    final left =
        (widget.anchorRect.left + (widget.anchorRect.width - width) / 2).clamp(
          8.0,
          screen.width - width - 8.0,
        );
    final clipHeight = widget.anchorRect.top.clamp(0.0, screen.height);

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _close,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: clipHeight,
          child: ClipRect(
            child: Stack(
              children: [
                Positioned(
                  left: left,
                  width: width,
                  bottom: 0,
                  child: FadeTransition(
                    opacity: _fadeIn,
                    child: AnimatedSlide(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      offset: _offset,
                      child: _GlassPanel(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(14),
                        ),
                        child: _ToolsContent(
                          assistantId: widget.assistantId,
                          conversationId: widget.conversationId,
                          onDone: _close,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child, this.borderRadius});
  final Widget child;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final radius = borderRadius ?? BorderRadius.circular(14);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppOverlayColors.desktopPopoverSurface(cs),
            borderRadius: radius,
            border: Border(
              top: BorderSide(
                color: cs.onSurface.withValues(alpha: isDark ? 0.06 : 0.12),
                width: 0.7,
              ),
              left: BorderSide(
                color: cs.onSurface.withValues(alpha: isDark ? 0.06 : 0.12),
                width: 0.6,
              ),
              right: BorderSide(
                color: cs.onSurface.withValues(alpha: isDark ? 0.06 : 0.12),
                width: 0.6,
              ),
            ),
          ),
          child: Material(type: MaterialType.transparency, child: child),
        ),
      ),
    );
  }
}

class _ToolsContent extends StatefulWidget {
  const _ToolsContent({
    required this.assistantId,
    required this.onDone,
    this.conversationId,
  });
  final String assistantId;
  final String? conversationId;
  final VoidCallback onDone;

  @override
  State<_ToolsContent> createState() => _ToolsContentState();
}

class _ToolsContentState extends State<_ToolsContent> {
  late final preferences = context.read<BusinessPreferences>();
  late final expanded =
      (preferences.getStringList('display_chat_tools_expanded_groups_v1') ??
              ['mcp', 'workspace'])
          .toSet();

  void toggle(String group) {
    setState(() {
      if (!expanded.remove(group)) expanded.add(group);
    });
    unawaited(
      preferences.setStringList(
        'display_chat_tools_expanded_groups_v1',
        expanded.toList(),
      ),
    );
  }

  String? workspaceName() {
    final id = widget.conversationId;
    if (id == null) return null;
    final extras =
        context.watch<ChatService>().getConversation(id)?.extras ?? {};
    final binding = WorkspaceBinding.fromExtras(extras);
    return binding.isBound
        ? context.watch<WorkspaceProvider>().byId(binding.workspaceId!)?.name
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final mcp = context.watch<McpProvider>();
    final ap = context.watch<AssistantProvider>();
    final a = ap.getById(widget.assistantId);
    if (a == null) return const SizedBox.shrink();
    final selected = a.mcpServerIds.toSet();
    final servers = mcp.servers
        .where((s) => mcp.statusFor(s.id) == McpStatus.connected)
        .toList();
    final localToolIds = availableLocalToolIds();
    final enabledLocalTools = a.localToolIds.toSet();

    void selectServer(String id, bool value) {
      final next = {...a.mcpServerIds};
      if (value) {
        next.add(id);
      } else {
        next.remove(id);
      }
      unawaited(ap.updateAssistant(a.copyWith(mcpServerIds: next.toList())));
    }

    final workspaceSummary = workspaceName() ?? l10n.toolsSheetWorkspaceUnbound;
    final rows = <WidgetBuilder>[
      if (localToolIds.isNotEmpty) ...[
        (context) => _SectionLabel(
          text: l10n.assistantEditPageLocalToolsTab,
          summary: l10n.toolsSheetEnabledCount(
            localToolIds.where(enabledLocalTools.contains).length,
          ),
          expanded: expanded.contains('local'),
          onToggle: () => toggle('local'),
        ),
        if (expanded.contains('local'))
          for (final id in localToolIds)
            (context) => _RowItem(
              leading: Icon(
                localToolIcon(id),
                size: 16,
                color: cs.onSurface.withValues(alpha: .55),
              ),
              label: localToolTitle(l10n, id),
              selected: enabledLocalTools.contains(id),
              onTap: () => unawaited(
                setLocalToolEnabled(
                  context,
                  assistant: a,
                  toolId: id,
                  value: !enabledLocalTools.contains(id),
                ),
              ),
            ),
      ],
      if (servers.isNotEmpty) ...[
        (context) => const SizedBox(height: 6),
        (context) => _SectionLabel(
          text: l10n.mcpAssistantSheetTitle,
          summary: l10n.toolsSheetEnabledCount(
            servers.where((s) => selected.contains(s.id)).length,
          ),
          expanded: expanded.contains('mcp'),
          onToggle: () => toggle('mcp'),
          onManage: () {
            widget.onDone();
            DesktopSettingsNavigationBus.instance.openMcp();
          },
        ),
        if (expanded.contains('mcp'))
          for (final server in servers)
            (context) => _RowItem(
              key: ValueKey('desktop-tools-mcp-${server.id}'),
              leading: McpServerAvatar(server: server, size: 24, radius: 7),
              label: server.name,
              count:
                  '${server.tools.where((tool) => tool.enabled).length}/${server.tools.length}',
              selected: selected.contains(server.id),
              onTap: () =>
                  selectServer(server.id, !selected.contains(server.id)),
            ),
      ],
      (context) => const SizedBox(height: 6),
      (context) => _SectionLabel(
        text: l10n.workspacesTitle,
        summary: workspaceSummary,
        expanded: expanded.contains('workspace'),
        onToggle: () => toggle('workspace'),
      ),
      if (expanded.contains('workspace'))
        (context) => WorkspaceSection(
          assistantId: widget.assistantId,
          conversationId: widget.conversationId,
          onClose: widget.onDone,
        ),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 420),
        child: ListView.builder(
          shrinkWrap: true,
          addRepaintBoundaries: false,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
          itemCount: rows.length,
          itemBuilder: (context, index) => rows[index](context),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.text,
    required this.summary,
    required this.expanded,
    required this.onToggle,
    this.onManage,
  });
  final String text;
  final String summary;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback? onManage;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
    child: ToolsSectionHeader(
      title: text,
      summary: summary,
      expanded: expanded,
      onToggle: onToggle,
      onManage: onManage,
      compact: true,
    ),
  );
}

class _RowItem extends StatefulWidget {
  const _RowItem({
    super.key,
    required this.leading,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });
  final Widget leading;
  final String label;
  final String? count;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_RowItem> createState() => _RowItemState();
}

class _RowItemState extends State<_RowItem> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: FocusableActionDetector(
            onShowFocusHighlight: (value) => setState(() => _focused = value),
            shortcuts: const {
              SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
              SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
            },
            actions: {
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) {
                  widget.onTap();
                  return null;
                },
              ),
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    constraints: const BoxConstraints(minHeight: 38),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: _hovered || _focused
                          ? context.appColors.surfaceFill
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Center(child: widget.leading),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 14, color: cs.onSurface),
                          ),
                        ),
                        if (widget.count != null) ...[
                          Text(
                            widget.count!,
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurface.withValues(alpha: .5),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        IosSwitch(
                          value: widget.selected,
                          onChanged: (_) => widget.onTap(),
                          semanticLabel: widget.label,
                          width: 32,
                          height: 20,
                          hitTestSize: 38,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
