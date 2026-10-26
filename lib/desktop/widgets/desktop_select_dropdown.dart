import 'dart:async';
import 'dart:math' as math;
import 'package:Kelivo/theme/app_font_weights.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    this.triggerForegroundColor,
    this.menuBackgroundColor,
    this.embedded = false,
    this.enabled = true,
    this.focusNode,
    this.placeholder = '',
    this.semanticLabel,
    this.semanticHint,
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
  final Color? triggerForegroundColor;
  final Color? menuBackgroundColor;
  final bool enabled;
  final FocusNode? focusNode;
  final String placeholder;
  final String? semanticLabel, semanticHint;

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
  bool _focused = false;
  final FocusNode _ownFocus = FocusNode();
  FocusNode get _focus => widget.focusNode ?? _ownFocus;
  final LayerLink _link = LayerLink();
  final GlobalKey _triggerKey = GlobalKey();
  OverlayEntry? _entry;

  @override
  void dispose() {
    _removeEntry();
    _ownFocus.dispose();
    super.dispose();
  }

  void _removeEntry() {
    _entry?.remove();
    _entry?.dispose();
    _entry = null;
  }

  void _toggle() {
    if (!widget.enabled || widget.options.isEmpty) return;
    if (_open) {
      _close();
    } else {
      _openMenu();
    }
  }

  void _close() {
    _removeEntry();
    if (mounted) {
      setState(() => _open = false);
      if (widget.enabled) _focus.requestFocus();
    }
  }

  @override
  void didUpdateWidget(DesktopSelectDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final sameOptions =
        oldWidget.options.length == widget.options.length &&
        List.generate(
          widget.options.length,
          (i) =>
              oldWidget.options[i].value == widget.options[i].value &&
              oldWidget.options[i].label == widget.options[i].label &&
              oldWidget.options[i].subtitle == widget.options[i].subtitle,
        ).every((same) => same);
    if (_open && (!widget.enabled || !sameOptions)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _open) _close();
      });
    } else if (_open &&
        (oldWidget.value != widget.value ||
            oldWidget.menuBackgroundColor != widget.menuBackgroundColor)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _entry?.markNeedsBuild();
      });
    }
  }

  String _labelForValue(T v) {
    for (final opt in widget.options) {
      if (opt.value == v) return opt.label;
    }
    return widget.placeholder;
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
    final overlay = Overlay.of(context);
    final overlayBox = overlay.context.findRenderObject()! as RenderBox;
    final origin = rb.localToGlobal(Offset.zero, ancestor: overlayBox);
    final size = overlayBox.size;
    overlayWidth = overlayWidth.clamp(0, math.max(0, size.width - 16));
    final left = (origin.dx + overlayDx).clamp(
      8.0,
      math.max(8, size.width - overlayWidth - 8),
    );
    overlayDx = left - origin.dx;
    final below = size.height - origin.dy - triggerSize.height - 14;
    final above = origin.dy - 14;
    final upward = below < 180 && above > below;
    final maxHeight = math.min(360.0, math.max(44.0, upward ? above : below));

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
              targetAnchor: upward ? Alignment.topLeft : Alignment.bottomLeft,
              followerAnchor: upward ? Alignment.bottomLeft : Alignment.topLeft,
              offset: Offset(overlayDx, upward ? -6 : 6),
              child: _DesktopSelectOverlay<T>(
                width: overlayWidth,
                maxHeight: maxHeight,
                onClose: _close,
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
    overlay.insert(_entry!);
    setState(() => _open = true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final label = _labelForValue(widget.value);

    final baseBorder = widget.embedded
        ? Colors.transparent
        : cs.outlineVariant.withValues(alpha: 0.18);
    final hoverBorder = widget.embedded ? Colors.transparent : cs.primary;
    final borderColor = _open || _hover || _focused ? hoverBorder : baseBorder;

    final fillColor =
        widget.triggerFillColor ??
        (widget.embedded
            ? Colors.transparent
            : Theme.of(context).colorScheme.surfaceContainerHigh);

    return FocusableActionDetector(
      focusNode: _focus,
      enabled: widget.enabled,
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.arrowDown): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _toggle();
            return null;
          },
        ),
      },
      child: Semantics(
        button: true,
        enabled: widget.enabled,
        expanded: _open,
        label: widget.semanticLabel ?? label,
        value: widget.semanticLabel == null ? null : label,
        hint: widget.semanticHint,
        onTap: widget.enabled ? _toggle : null,
        child: ExcludeSemantics(
          child: CompositedTransformTarget(
            link: _link,
            child: MouseRegion(
              cursor: widget.enabled
                  ? SystemMouseCursors.click
                  : MouseCursor.defer,
              onEnter: (_) => setState(() => _hover = true),
              onExit: (_) => setState(() => _hover = false),
              child: GestureDetector(
                onTap: widget.enabled ? _toggle : null,
                child: AnimatedContainer(
                  key: _triggerKey,
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 160),
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
                    alignment: AlignmentDirectional.centerStart,
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
                                constraints: BoxConstraints(
                                  maxWidth: labelMaxWidth,
                                ),
                                child: Text(
                                  label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color:
                                        (widget.triggerForegroundColor ??
                                                cs.onSurface)
                                            .withValues(alpha: 0.88),
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
                          alignment: AlignmentDirectional.centerEnd,
                          child: AnimatedRotation(
                            turns: _open ? 0.5 : 0.0,
                            duration: reduceMotion
                                ? Duration.zero
                                : const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            child: Icon(
                              lucide.Lucide.ChevronDown,
                              size: 16,
                              color:
                                  (widget.triggerForegroundColor ??
                                          cs.onSurface)
                                      .withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ),
                    ],
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

class _DesktopSelectOverlay<T> extends StatefulWidget {
  const _DesktopSelectOverlay({
    required this.width,
    required this.maxHeight,
    required this.onClose,
    required this.backgroundColor,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final double width;
  final double maxHeight;
  final VoidCallback onClose;
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
  late final List<FocusNode> _focus;
  late final List<GlobalKey> _keys;
  late int _active;

  @override
  void initState() {
    super.initState();
    _focus = List.generate(widget.options.length, (_) => FocusNode());
    _keys = List.generate(widget.options.length, (_) => GlobalKey());
    _active = math.max(
      0,
      widget.options.indexWhere((o) => o.value == widget.selected),
    );
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _ctrl.value = 1;
      } else {
        _ctrl.forward();
      }
      _move(_active);
    });
  }

  void _move(int index) {
    if (_focus.isEmpty) return;
    _active = index % _focus.length;
    _focus[_active].requestFocus();
    final target = _keys[_active].currentContext;
    if (target != null) Scrollable.ensureVisible(target, alignment: .5);
  }

  KeyEventResult _key(FocusNode _, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.escape:
        widget.onClose();
      case LogicalKeyboardKey.arrowDown:
        _move(_active + 1);
      case LogicalKeyboardKey.arrowUp:
        _move(_active - 1);
      case LogicalKeyboardKey.home:
        _move(0);
      case LogicalKeyboardKey.end:
        _move(_focus.length - 1);
      case LogicalKeyboardKey.tab:
        _move(_active + (HardwareKeyboard.instance.isShiftPressed ? -1 : 1));
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    for (final node in _focus) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = cs.outlineVariant.withValues(alpha: 0.12);

    final content = FocusScope(
      onKeyEvent: _key,
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(
            minWidth: widget.width,
            maxWidth: widget.width,
            maxHeight: widget.maxHeight,
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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < widget.options.length; i++)
                  _DesktopSelectOptionTile(
                    key: _keys[i],
                    focusNode: _focus[i],
                    onFocused: () => _active = i,
                    label: widget.options[i].label,
                    subtitle: widget.options[i].subtitle,
                    selected: widget.selected == widget.options[i].value,
                    onTap: () => widget.onSelected(widget.options[i].value),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (MediaQuery.disableAnimationsOf(context)) return content;
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: content),
    );
  }
}

class _DesktopSelectOptionTile extends StatefulWidget {
  const _DesktopSelectOptionTile({
    super.key,
    required this.focusNode,
    required this.onFocused,
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  final FocusNode focusNode;
  final VoidCallback onFocused;

  @override
  State<_DesktopSelectOptionTile> createState() =>
      _DesktopSelectOptionTileState();
}

class _DesktopSelectOptionTileState extends State<_DesktopSelectOptionTile> {
  bool _hover = false;
  bool _active = false;
  bool _focused = false;

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
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final bg = widget.selected
        ? cs.primary.withValues(alpha: 0.12)
        : (_hover || _focused
              ? (cs.onSurface.withValues(alpha: isDark ? 0.08 : 0.04))
              : Colors.transparent);
    return FocusableActionDetector(
      focusNode: widget.focusNode,
      onFocusChange: (value) {
        if (value) widget.onFocused();
      },
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
      child: Semantics(
        button: true,
        selected: widget.selected,
        label: widget.label,
        hint: widget.subtitle,
        onTap: widget.onTap,
        child: ExcludeSemantics(
          child: MouseRegion(
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
                duration: reducedMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                child: AnimatedContainer(
                  duration: reducedMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 160),
                  constraints: const BoxConstraints(minHeight: 32),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: _labelColumn(cs)),
                      const SizedBox(width: 8),
                      Icon(
                        lucide.Lucide.Check,
                        size: 14,
                        color: cs.primary.withValues(
                          alpha: widget.selected ? 1 : 0,
                        ),
                      ),
                    ],
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
