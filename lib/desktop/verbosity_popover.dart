import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../icons/lucide_adapter.dart';
import '../l10n/app_localizations.dart';
import '../features/chat/widgets/verbosity_sheet.dart';

Future<String?> showDesktopVerbosityPopover(
  BuildContext context, {
  required GlobalKey anchorKey,
  String? initialValue,
}) async {
  final overlay = Overlay.of(context);
  final keyContext = anchorKey.currentContext;
  if (keyContext == null) return null;

  final box = keyContext.findRenderObject() as RenderBox?;
  if (box == null) return null;
  final offset = box.localToGlobal(Offset.zero);
  final size = box.size;
  final anchorRect = Rect.fromLTWH(offset.dx, offset.dy, size.width, size.height);

  final completer = Completer<String?>();

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => _VerbosityPopoverOverlay(
      anchorRect: anchorRect,
      anchorWidth: size.width,
      initialValue: initialValue,
      onClose: (value) {
        try { entry.remove(); } catch (_) {}
        if (!completer.isCompleted) completer.complete(value);
      },
    ),
  );
  overlay.insert(entry);
  return completer.future;
}

class _VerbosityPopoverOverlay extends StatefulWidget {
  const _VerbosityPopoverOverlay({
    required this.anchorRect,
    required this.anchorWidth,
    required this.initialValue,
    required this.onClose,
  });

  final Rect anchorRect;
  final double anchorWidth;
  final String? initialValue;
  final ValueChanged<String?> onClose;

  @override
  State<_VerbosityPopoverOverlay> createState() => _VerbosityPopoverOverlayState();
}

class _VerbosityPopoverOverlayState extends State<_VerbosityPopoverOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  bool _closing = false;
  Offset _offset = const Offset(0, 0.12);
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialValue ?? kVerbosityDefaultSelection;
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      setState(() => _offset = Offset.zero);
      try { await _controller.forward(); } catch (_) {}
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _close({String? value}) async {
    if (_closing) return;
    _closing = true;
    setState(() => _offset = const Offset(0, 1.0));
    try { await _controller.reverse(); } catch (_) {}
    if (mounted) widget.onClose(value);
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final width = (widget.anchorWidth - 16).clamp(260.0, 720.0);
    final left = (widget.anchorRect.left + (widget.anchorRect.width - width) / 2)
        .clamp(8.0, screen.width - width - 8.0);
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
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                        child: _VerbosityContent(
                          selected: _selected,
                          onSelect: (value) => _close(value: value),
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
            color: (isDark ? Colors.black : Colors.white).withOpacity(isDark ? 0.28 : 0.56),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(isDark ? 0.06 : 0.18), width: 0.7),
              left: BorderSide(color: Colors.white.withOpacity(isDark ? 0.04 : 0.12), width: 0.6),
              right: BorderSide(color: Colors.white.withOpacity(isDark ? 0.04 : 0.12), width: 0.6),
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _VerbosityContent extends StatelessWidget {
  const _VerbosityContent({
    required this.selected,
    required this.onSelect,
  });

  final String selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    Widget tile({
      required String label,
      required String value,
    }) {
      final cs = Theme.of(context).colorScheme;
      final active = selected == value;
      final onColor = active ? cs.primary : cs.onSurface;
      final iconColor = active ? cs.primary : cs.onSurface;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
        child: _HoverRow(
          leading: Icon(Lucide.MessageCircleMore, size: 16, color: iconColor),
          label: label,
          selected: active,
          onTap: () async {
            onSelect(value);
          },
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400, decoration: TextDecoration.none)
              .copyWith(color: onColor),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(0, 10, 0, 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            tile(label: l10n.verbosityDefault, value: kVerbosityDefaultSelection),
            tile(label: l10n.verbosityLow, value: 'low'),
            tile(label: l10n.verbosityMedium, value: 'medium'),
            tile(label: l10n.verbosityHigh, value: 'high'),
          ],
        ),
      ),
    );
  }
}

class _HoverRow extends StatefulWidget {
  const _HoverRow({
    required this.leading,
    required this.label,
    required this.selected,
    required this.onTap,
    this.labelStyle,
  });
  final Widget leading;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final TextStyle? labelStyle;

  @override
  State<_HoverRow> createState() => _HoverRowState();
}

class _HoverRowState extends State<_HoverRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final hoverBg = (isDark ? Colors.white : Colors.black).withOpacity(isDark ? 0.12 : 0.10);

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
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              SizedBox(width: 22, height: 22, child: Center(child: widget.leading)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: widget.labelStyle ?? const TextStyle(fontSize: 13, fontWeight: FontWeight.w400, decoration: TextDecoration.none),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: widget.selected
                    ? Icon(Lucide.Check, key: const ValueKey('check'), size: 16, color: cs.primary)
                    : const SizedBox(width: 16, key: ValueKey('space')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
