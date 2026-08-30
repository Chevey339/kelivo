import 'dart:async';
import 'package:Kelivo/theme/app_font_weights.dart';

import 'package:flutter/material.dart';

import '../../icons/lucide_adapter.dart' as lucide;
import '../../theme/app_semantic_colors.dart';

class DesktopSelectOption<T> {
  const DesktopSelectOption({
    required this.value,
    required this.label,
    this.subtitle,
  });

  final T value;
  final String label;
  final String? subtitle;
}

bool _optionHasSubtitle<T>(DesktopSelectOption<T> option) {
  final subtitle = option.subtitle;
  return subtitle != null && subtitle.isNotEmpty;
}

class DesktopSelectDropdown<T> extends StatefulWidget {
  const DesktopSelectDropdown({
    super.key,
    required this.value,
    required this.options,
    required this.onSelected,
    this.minWidth = 100,
    this.minHeight = 34,
    this.padding = const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
    this.borderRadius = 10,
    this.maxLabelWidth = 240,
    this.triggerFillColor,
    this.menuBackgroundColor,
    this.embedded = false,
  });

  final T value;
  final List<DesktopSelectOption<T>> options;
  final FutureOr<void> Function(T value) onSelected;

  final double minWidth;
  final double minHeight;
  final EdgeInsets padding;
  final double borderRadius;
  final double maxLabelWidth;
  final Color? triggerFillColor;
  final Color? menuBackgroundColor;

  /// Hide the trigger chrome so a parent field (for example
  /// [InputDecorator]) can supply the border and fill.
  final bool embedded;

  @override
  State<DesktopSelectDropdown<T>> createState() =>
      _DesktopSelectDropdownState<T>();
}

class _DesktopSelectDropdownState<T> extends State<DesktopSelectDropdown<T>> {
  bool _hover = false;
  bool _open = false;
  final LayerLink _link = LayerLink();
  final GlobalKey _triggerKey = GlobalKey();
  OverlayEntry? _entry;

  @override
  void dispose() {
    _removeEntry();
    super.dispose();
  }

  void _removeEntry() {
    _entry?.remove();
    _entry = null;
  }

  void _toggle() {
    if (_open) {
      _close();
    } else {
      _openMenu();
    }
  }

  void _close() {
    _removeEntry();
    if (mounted) setState(() => _open = false);
  }

  String _labelForValue(T v) {
    for (final opt in widget.options) {
      if (opt.value == v) return opt.label;
    }
    return widget.options.isNotEmpty ? widget.options.first.label : '';
  }

  Color _defaultMenuBackground(BuildContext context) {
    return context.overlaySurface;
  }

  void _openMenu() {
    if (_entry != null) return;
    final rb = _triggerKey.currentContext?.findRenderObject() as RenderBox?;
    if (rb == null) return;
    final triggerSize = rb.size;
    final triggerWidth = triggerSize.width;
    final hasSubtitles = widget.options.any(_optionHasSubtitle);
    var overlayWidth = triggerWidth;
    var overlayDx = 0.0;
    if (hasSubtitles) {
      overlayWidth = triggerWidth < 360 ? 360.0 : triggerWidth;
      if (overlayWidth > 440) overlayWidth = 440.0;
      overlayDx = triggerWidth - overlayWidth;
    }

    _entry = OverlayEntry(
      builder: (ctx) {
        final bgColor =
            widget.menuBackgroundColor ?? _defaultMenuBackground(ctx);
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _close,
                child: const SizedBox.expand(),
              ),
            ),
            CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              offset: Offset(overlayDx, triggerSize.height + 6),
              child: _DesktopSelectOverlay<T>(
                width: overlayWidth,
                backgroundColor: bgColor,
                options: widget.options,
                selected: widget.value,
                onSelected: (v) async {
                  _close();
                  await widget.onSelected(v);
                },
              ),
            ),
          ],
        );
      },
    );
    Overlay.of(context).insert(_entry!);
    setState(() => _open = true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = _labelForValue(widget.value);

    final baseBorder = widget.embedded
        ? Colors.transparent
        : cs.outlineVariant.withValues(alpha: 0.18);
    final hoverBorder = widget.embedded ? Colors.transparent : cs.primary;
    final borderColor = _open || _hover ? hoverBorder : baseBorder;

    final fillColor =
        widget.triggerFillColor ??
        (widget.embedded
            ? Colors.transparent
            : Theme.of(context).colorScheme.surfaceContainerHigh);

    return CompositedTransformTarget(
      link: _link,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: _toggle,
          child: AnimatedContainer(
            key: _triggerKey,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            padding: widget.padding,
            constraints: BoxConstraints(
              minWidth: widget.minWidth,
              minHeight: widget.minHeight,
            ),
            decoration: BoxDecoration(
              color: fillColor,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(color: borderColor, width: 1),
              boxShadow: !widget.embedded && _open
                  ? [
                      BoxShadow(
                        color: cs.primary.withValues(alpha: 0.10),
                        blurRadius: 0,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final availableWidth = constraints.hasBoundedWidth
                        ? constraints.maxWidth
                        : widget.maxLabelWidth + 24;
                    final labelMaxWidth = (availableWidth - 24)
                        .clamp(0.0, widget.maxLabelWidth)
                        .toDouble();
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: labelMaxWidth),
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color: cs.onSurface.withValues(alpha: 0.88),
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                      ],
                    );
                  },
                ),
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: AnimatedRotation(
                      turns: _open ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        lucide.Lucide.ChevronDown,
                        size: 16,
                        color: cs.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopSelectOverlay<T> extends StatefulWidget {
  const _DesktopSelectOverlay({
    required this.width,
    required this.backgroundColor,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final double width;
  final Color backgroundColor;
  final List<DesktopSelectOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  State<_DesktopSelectOverlay<T>> createState() =>
      _DesktopSelectOverlayState<T>();
}

class _DesktopSelectOverlayState<T> extends State<_DesktopSelectOverlay<T>>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    WidgetsBinding.instance.addPostFrameCallback((_) => _ctrl.forward());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = cs.outlineVariant.withValues(alpha: 0.12);

    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(
              minWidth: widget.width,
              maxWidth: widget.width,
            ),
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 0.5),
              boxShadow: [
                BoxShadow(
                  color: cs.shadow.withValues(alpha: isDark ? 0.32 : 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final opt in widget.options)
                  _DesktopSelectOptionTile(
                    label: opt.label,
                    subtitle: opt.subtitle,
                    selected: widget.selected == opt.value,
                    onTap: () => widget.onSelected(opt.value),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopSelectOptionTile extends StatefulWidget {
  const _DesktopSelectOptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_DesktopSelectOptionTile> createState() =>
      _DesktopSelectOptionTileState();
}

class _DesktopSelectOptionTileState extends State<_DesktopSelectOptionTile> {
  bool _hover = false;
  bool _active = false;

  Widget _labelColumn(ColorScheme cs) {
    final label = Text(
      widget.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 14,
        color: cs.onSurface.withValues(alpha: 0.88),
        fontWeight: widget.selected
            ? AppFontWeights.semibold
            : AppFontWeights.regular,
      ),
    );
    final subtitle = widget.subtitle;
    if (subtitle == null || subtitle.isEmpty) return label;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        label,
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12.5,
            height: 1.3,
            color: cs.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = widget.selected
        ? cs.primary.withValues(alpha: 0.12)
        : (_hover
              ? (cs.onSurface.withValues(alpha: isDark ? 0.08 : 0.04))
              : Colors.transparent);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _active = true),
        onTapCancel: () => setState(() => _active = false),
        onTapUp: (_) => setState(() => _active = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _active ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(child: _labelColumn(cs)),
                const SizedBox(width: 8),
                Opacity(
                  opacity: widget.selected ? 1 : 0,
                  child: Icon(lucide.Lucide.Check, size: 14, color: cs.primary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
