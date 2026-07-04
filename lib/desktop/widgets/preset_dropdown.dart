import 'dart:async';
import 'package:Cuplivo/theme/app_font_weights.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/settings_provider.dart';
import '../../icons/lucide_adapter.dart' as lucide;
import 'desktop_select_dropdown.dart';
export 'desktop_select_dropdown.dart' show DesktopSelectOption;

/// Dropdown for selecting prompt presets (title, translate, summary, etc.).
///
/// Derived from [DesktopSelectDropdown]
/// (lib/desktop/widgets/desktop_select_dropdown.dart).
///
/// Key differences from the original:
/// - `value` is nullable (null = custom/unmatched prompt).
/// - `customLabel` is shown when `value` is null.
/// - The trigger has a fixed width range via [minWidth]/[maxWidth] to avoid
///   stretching across the parent layout while fitting Chinese text.
class PresetDropdown<T> extends StatefulWidget {
  const PresetDropdown({
    super.key,
    required this.value,
    required this.customLabel,
    required this.options,
    required this.onSelected,
    this.minWidth = 160,
    this.maxWidth = 210,
    this.minHeight = 34,
    this.padding = const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
    this.borderRadius = 10,
    this.triggerFillColor,
    this.menuBackgroundColor,
  });

  final T? value;
  final String customLabel;
  final List<DesktopSelectOption<T>> options;
  final FutureOr<void> Function(T value) onSelected;

  final double minWidth;
  final double maxWidth;
  final double minHeight;
  final EdgeInsets padding;
  final double borderRadius;
  final Color? triggerFillColor;
  final Color? menuBackgroundColor;

  @override
  State<PresetDropdown<T>> createState() => _PresetDropdownState<T>();
}

class _PresetDropdownState<T> extends State<PresetDropdown<T>> {
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

  String _labelForValue(T? v) {
    if (v == null) return widget.customLabel;
    for (final opt in widget.options) {
      if (opt.value == v) return opt.label;
    }
    return widget.customLabel;
  }

  Color _defaultMenuBackground(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    SettingsProvider? sp;
    try {
      sp = Provider.of<SettingsProvider>(context, listen: false);
    } catch (_) {
      sp = null;
    }
    final usePure = sp?.usePureBackground ?? false;
    if (usePure) return isDark ? Colors.black : Colors.white;
    return isDark ? const Color(0xFF1C1C1E) : Colors.white;
  }

  void _openMenu() {
    if (_entry != null) return;
    final rb = _triggerKey.currentContext?.findRenderObject() as RenderBox?;
    if (rb == null) return;
    final triggerSize = rb.size;
    final triggerWidth = triggerSize.width;

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
              offset: Offset(0, triggerSize.height + 6),
              child: _PresetDropdownOverlay<T>(
                width: triggerWidth,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final label = _labelForValue(widget.value);

    final baseBorder = cs.outlineVariant.withValues(alpha: 0.18);
    final hoverBorder = cs.primary;
    final borderColor = _open || _hover ? hoverBorder : baseBorder;

    final fillColor =
        widget.triggerFillColor ??
        (isDark ? const Color(0xFF141414) : Colors.white);

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
              maxWidth: widget.maxWidth,
              minHeight: widget.minHeight,
            ),
            decoration: BoxDecoration(
              color: fillColor,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(color: borderColor, width: 1),
              boxShadow: _open
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
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

class _PresetDropdownOverlay<T> extends StatefulWidget {
  const _PresetDropdownOverlay({
    required this.width,
    required this.backgroundColor,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final double width;
  final Color backgroundColor;
  final List<DesktopSelectOption<T>> options;
  final T? selected;
  final ValueChanged<T> onSelected;

  @override
  State<_PresetDropdownOverlay<T>> createState() =>
      _PresetDropdownOverlayState<T>();
}

class _PresetDropdownOverlayState<T> extends State<_PresetDropdownOverlay<T>>
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
            width: widget.width,
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 0.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.32 : 0.08),
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
                    selected:
                        widget.selected != null && widget.selected == opt.value,
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
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_DesktopSelectOptionTile> createState() =>
      _DesktopSelectOptionTileState();
}

class _DesktopSelectOptionTileState extends State<_DesktopSelectOptionTile> {
  bool _hover = false;
  bool _active = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = widget.selected
        ? cs.primary.withValues(alpha: 0.12)
        : (_hover
              ? (isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.04))
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
                Expanded(
                  child: Text(
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
                  ),
                ),
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
