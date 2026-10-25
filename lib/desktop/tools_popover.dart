import 'dart:ui' as ui;
import 'dart:async';
import '../core/database/business_preferences.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../features/mcp/widgets/mcp_server_avatar.dart';
import '../features/mcp/utils/mcp_tool_groups.dart';
import '../features/workspace/widgets/workspace_section.dart';
import 'package:provider/provider.dart';

import '../icons/lucide_adapter.dart';
import '../l10n/app_localizations.dart';
import '../core/providers/mcp_provider.dart';
import '../core/providers/assistant_provider.dart';
import '../features/home/services/local_tool_labels.dart';
import '../features/home/services/local_tool_toggle.dart';
import 'package:Kelivo/theme/app_font_weights.dart';
import '../theme/design_tokens.dart';
import '../shared/widgets/ios_tactile.dart';

Future<void> showDesktopToolsPopover(
  BuildContext context, {
  required GlobalKey anchorKey,
  required String assistantId,
  required bool supportsModelTools,
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
      supportsModelTools: supportsModelTools,
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
    required this.supportsModelTools,
    required this.onClose,
    this.conversationId,
  });

  final Rect anchorRect;
  final double anchorWidth;
  final String assistantId;
  final bool supportsModelTools;
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
                          supportsModelTools: widget.supportsModelTools,
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
    required this.supportsModelTools,
    required this.onDone,
    this.conversationId,
  });
  final String? conversationId;
  final String assistantId;
  final bool supportsModelTools;
  final VoidCallback onDone;

  @override
  State<_ToolsContent> createState() => _ToolsContentState();
}

class _ToolsContentState extends State<_ToolsContent> {
  late final _preferences = context.read<BusinessPreferences>();
  late bool _workspaceExpanded =
      (_preferences.getStringList('display_chat_tools_expanded_groups_v1') ??
              ['mcp', 'workspace'])
          .contains('workspace');

  void _toggleWorkspace() {
    setState(() => _workspaceExpanded = !_workspaceExpanded);
    final expanded =
        (_preferences.getStringList('display_chat_tools_expanded_groups_v1') ??
                ['mcp', 'workspace'])
            .toSet();
    if (_workspaceExpanded) {
      expanded.add('workspace');
    } else {
      expanded.remove('workspace');
    }
    unawaited(
      _preferences.setStringList(
        'display_chat_tools_expanded_groups_v1',
        expanded.toList(),
      ),
    );
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
    final groups = [if (widget.supportsModelTools) ...mcpToolGroups(mcp)];

    final localToolIds = widget.supportsModelTools
        ? availableLocalToolIds()
        : const <String>[];
    final enabledLocalTools = a.localToolIds.toSet();

    final rows = <WidgetBuilder>[];
    if (localToolIds.isNotEmpty) {
      rows.add(
        (context) => _SectionLabel(text: l10n.assistantEditPageLocalToolsTab),
      );
      for (final id in localToolIds) {
        final isEnabled = enabledLocalTools.contains(id);
        rows.add(
          (context) => _RowItem(
            leading: Icon(
              localToolIcon(id),
              size: 16,
              color: isEnabled ? cs.primary : cs.onSurface,
            ),
            label: localToolTitle(l10n, id),
            selected: isEnabled,
            onTap: () async {
              await setLocalToolEnabled(
                context,
                assistant: a,
                toolId: id,
                value: !isEnabled,
              );
              // Do not close; allow multi-select
            },
          ),
        );
      }
    }

    if (groups.isNotEmpty) {
      rows.add((context) => _SectionLabel(text: l10n.mcpAssistantSheetTitle));
      rows.add(
        (context) => _RowItem(
          leading: Icon(Lucide.CircleX, size: 16, color: cs.onSurface),
          label: l10n.mcpAssistantSheetClearAll,
          onTap: () async {
            await context.read<AssistantProvider>().updateAssistant(
              a.copyWith(mcpServerIds: const <String>[]),
            );
            widget.onDone();
          },
        ),
      );
    }

    for (final group in groups) {
      if (mcp.groups.isNotEmpty) {
        rows.add(
          (context) => _SectionLabel(
            text: group.group?.name ?? l10n.providerGroupsOther,
            subgroup: true,
          ),
        );
      }
      for (final s in group.servers) {
        final isSelected = selected.contains(s.id);
        rows.add(
          (context) => _RowItem(
            key: ValueKey('desktop-tools-mcp-${s.id}'),
            leading: McpServerAvatar(
              server: s,
              size: 16,
              radius: 7,
              showBackground: false,
            ),
            detail:
                '${s.tools.where((t) => t.enabled).length}/${s.tools.length}',
            label: s.name,
            selected: isSelected,
            onTap: () async {
              final set = a.mcpServerIds.toSet();
              if (isSelected) {
                set.remove(s.id);
              } else {
                set.add(s.id);
              }
              await context.read<AssistantProvider>().updateAssistant(
                a.copyWith(mcpServerIds: set.toList()),
              );
              // Do not close; allow multi-select
            },
          ),
        );
      }
    }

    rows.add(
      (context) => Semantics(
        button: true,
        expanded: _workspaceExpanded,
        child: IosCardPress(
          focusable: true,
          haptics: false,
          baseColor: Colors.transparent,
          pressedBlendStrength: 0,
          onTap: _toggleWorkspace,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SizedBox(
              height: 32,
              child: Row(
                children: [
                  AnimatedRotation(
                    turns: _workspaceExpanded ? .25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Lucide.ChevronRight,
                      size: 12,
                      color: cs.onSurface.withValues(alpha: .5),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l10n.workspacesTitle,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: AppFontWeights.semibold,
                      color: cs.onSurface.withValues(alpha: .5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (_workspaceExpanded) {
      rows.add(
        (context) => WorkspaceSection(
          assistantId: widget.assistantId,
          conversationId: widget.conversationId,
          onClose: widget.onDone,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 420),
        child: ListView.builder(
          shrinkWrap: true,
          addRepaintBoundaries: false,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
          itemCount: rows.length,
          itemBuilder: (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: 1),
            child: rows[index](context),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, this.subgroup = false});
  final bool subgroup;

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: subgroup
              ? AppFontWeights.regular
              : AppFontWeights.semibold,
          decoration: TextDecoration.none,
          color: cs.onSurface.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

class _RowItem extends StatefulWidget {
  const _RowItem({
    super.key,
    required this.leading,
    this.detail,
    required this.label,
    this.selected,
    required this.onTap,
  });
  final Widget leading;
  final String? detail;
  final String label;
  final bool? selected;
  final VoidCallback onTap;

  @override
  State<_RowItem> createState() => _RowItemState();
}

class _RowItemState extends State<_RowItem> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final onColor = widget.selected == true ? cs.primary : cs.onSurface;
    final baseBg = Colors.transparent;
    final hoverBg = cs.onSurface.withValues(alpha: isDark ? 0.12 : 0.10);
    return Semantics(
      button: true,
      toggled: widget.selected,
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
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: _hovered || _focused ? hoverBg : baseBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: Center(child: widget.leading),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: AppFontWeights.regular,
                        decoration: TextDecoration.none,
                      ).copyWith(color: onColor),
                    ),
                  ),
                  if (widget.detail != null) ...[
                    Text(
                      widget.detail!,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: .5),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    child: widget.selected == true
                        ? Icon(
                            Lucide.Check,
                            key: const ValueKey('check'),
                            size: 16,
                            color: cs.primary,
                          )
                        : const SizedBox(width: 16, key: ValueKey('space')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
