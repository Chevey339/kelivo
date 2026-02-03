import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/instruction_injection.dart';
import '../core/providers/instruction_injection_group_provider.dart';
import '../core/providers/instruction_injection_provider.dart';
import '../icons/lucide_adapter.dart';
import '../l10n/app_localizations.dart';

Future<void> showDesktopInstructionInjectionPopover(
  BuildContext context, {
  required GlobalKey anchorKey,
  required List<InstructionInjection> items,
  String? assistantId,
}) async {
  if (items.isEmpty) return;
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
    builder: (ctx) => _InstructionInjectionPopover(
      anchorRect: anchorRect,
      anchorWidth: size.width,
      items: items,
      assistantId: assistantId,
      onClose: () {
        try {
          entry.remove();
        } catch (_) {}
      },
    ),
  );
  overlay.insert(entry);
}

class _InstructionInjectionPopover extends StatefulWidget {
  const _InstructionInjectionPopover({
    required this.anchorRect,
    required this.anchorWidth,
    required this.items,
    required this.assistantId,
    required this.onClose,
  });

  final Rect anchorRect;
  final double anchorWidth;
  final List<InstructionInjection> items;
  final String? assistantId;
  final VoidCallback onClose;

  @override
  State<_InstructionInjectionPopover> createState() =>
      _InstructionInjectionPopoverState();
}

class _InstructionInjectionPopoverState
    extends State<_InstructionInjectionPopover>
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
    // Match search popover width behavior
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
                        child: _InstructionInjectionList(
                          items: widget.items,
                          assistantId: widget.assistantId,
                          onClose: _close,
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
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: (isDark ? Colors.black : Colors.white).withOpacity(
              isDark ? 0.28 : 0.56,
            ),
            border: Border(
              top: BorderSide(
                color: Colors.white.withOpacity(isDark ? 0.06 : 0.18),
                width: 0.7,
              ),
              left: BorderSide(
                color: Colors.white.withOpacity(isDark ? 0.04 : 0.12),
                width: 0.6,
              ),
              right: BorderSide(
                color: Colors.white.withOpacity(isDark ? 0.04 : 0.12),
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

class _InstructionInjectionList extends StatelessWidget {
  const _InstructionInjectionList({
    required this.items,
    required this.assistantId,
    required this.onClose,
  });
  final List<InstructionInjection> items;
  final String? assistantId;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 420),
        child: _InstructionInjectionListInner(
          items: items,
          assistantId: assistantId,
          onClose: onClose,
        ),
      ),
    );
  }
}

class _InstructionInjectionListInner extends StatelessWidget {
  const _InstructionInjectionListInner({
    required this.items,
    required this.assistantId,
    required this.onClose,
  });
  final List<InstructionInjection> items;
  final String? assistantId;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final provider = context.watch<InstructionInjectionProvider>();
    final groupUi = context.watch<InstructionInjectionGroupProvider>();
    final selected = provider.activeIdsFor(assistantId).toSet();

    final Map<String, List<InstructionInjection>> grouped =
        <String, List<InstructionInjection>>{};
    for (final item in items) {
      final g = item.group.trim();
      (grouped[g] ??= <InstructionInjection>[]).add(item);
    }
    final groupNames = grouped.keys.toList()
      ..sort((a, b) {
        final aa = a.trim();
        final bb = b.trim();
        if (aa.isEmpty && bb.isNotEmpty) return -1;
        if (aa.isNotEmpty && bb.isEmpty) return 1;
        return aa.toLowerCase().compareTo(bb.toLowerCase());
      });

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 1),
            child: _CancelRow(
              leading: Icon(Lucide.CircleX, size: 16, color: cs.onSurface),
              label: l10n.homePageCancel,
              onTap: () async {
                try {
                  await context
                      .read<InstructionInjectionProvider>()
                      .setActiveIds(const <String>[], assistantId: assistantId);
                } catch (_) {}
                onClose();
              },
            ),
          ),
          for (final groupName in groupNames) ...[
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 2),
              child: _GroupHeaderRow(
                title: groupName.trim().isEmpty
                    ? l10n.instructionInjectionUngroupedGroup
                    : groupName.trim(),
                collapsed: groupUi.isCollapsed(groupName),
                onTap: () => context
                    .read<InstructionInjectionGroupProvider>()
                    .toggleCollapsed(groupName),
              ),
            ),
            if (!groupUi.isCollapsed(groupName))
              for (final p
                  in grouped[groupName] ?? const <InstructionInjection>[])
                Padding(
                  padding: const EdgeInsets.only(bottom: 1),
                  child: _RowItem(
                    title: p.title.trim().isEmpty
                        ? l10n.instructionInjectionDefaultTitle
                        : p.title,
                    preview: p.prompt,
                    active: selected.contains(p.id),
                    onTap: () async {
                      try {
                        final prov = context
                            .read<InstructionInjectionProvider>();
                        await prov.toggleActiveId(
                          p.id,
                          assistantId: assistantId,
                        );
                      } catch (_) {}
                    },
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _GroupHeaderRow extends StatefulWidget {
  const _GroupHeaderRow({
    required this.title,
    required this.collapsed,
    required this.onTap,
  });

  final String title;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  State<_GroupHeaderRow> createState() => _GroupHeaderRowState();
}

class _GroupHeaderRowState extends State<_GroupHeaderRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hoverBg = (isDark ? Colors.white : Colors.black).withOpacity(
      isDark ? 0.10 : 0.06,
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: _hovered ? hoverBg : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: Center(
                  child: AnimatedRotation(
                    turns: widget.collapsed ? 0.0 : 0.25, // right -> down
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: Icon(
                      Lucide.ChevronRight,
                      size: 16,
                      color: cs.onSurface.withOpacity(0.7),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface.withOpacity(0.85),
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CancelRow extends StatefulWidget {
  const _CancelRow({
    required this.leading,
    required this.label,
    required this.onTap,
  });
  final Widget leading;
  final String label;
  final VoidCallback onTap;

  @override
  State<_CancelRow> createState() => _CancelRowState();
}

class _CancelRowState extends State<_CancelRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hoverBg = (isDark ? Colors.white : Colors.black).withOpacity(
      isDark ? 0.10 : 0.06,
    );
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: _hovered ? hoverBg : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
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
                    fontWeight: FontWeight.w400,
                    color: cs.onSurface.withOpacity(0.75),
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RowItem extends StatefulWidget {
  const _RowItem({
    required this.title,
    required this.preview,
    required this.active,
    required this.onTap,
  });
  final String title;
  final String preview;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_RowItem> createState() => _RowItemState();
}

class _RowItemState extends State<_RowItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final baseBg = Colors.transparent;
    final hoverBg = (isDark ? Colors.white : Colors.black).withOpacity(
      isDark ? 0.12 : 0.10,
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: _hovered ? hoverBg : baseBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Lucide.Layers,
                size: 16,
                color: widget.active
                    ? cs.primary
                    : cs.onSurface.withOpacity(0.7),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: widget.active ? cs.primary : cs.onSurface,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        widget.preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: cs.onSurface.withOpacity(0.70),
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    if (widget.active) ...[
                      const SizedBox(width: 6),
                      Icon(Lucide.Check, size: 14, color: cs.primary),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
