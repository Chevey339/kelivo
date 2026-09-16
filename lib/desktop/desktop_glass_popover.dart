import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

class DesktopGlassPopoverHandle {
  DesktopGlassPopoverHandle._({
    required this.close,
    required this.setSuspended,
  });

  final Future<void> Function() close;
  final ValueChanged<bool> setSuspended;
}

/// Input-bar glass popover: clipped above [anchorRect], dismisses on
/// outside tap, and can suspend while a nested dialog is open.
Future<void> showDesktopGlassPopover(
  BuildContext context, {
  required Rect anchorRect,
  required double width,
  required Widget Function(
    BuildContext context,
    DesktopGlassPopoverHandle handle,
  )
  builder,
}) async {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;

  final completer = Completer<void>();
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => _DesktopGlassPopoverOverlay(
      anchorRect: anchorRect,
      width: width,
      builder: builder,
      onClose: () {
        try {
          entry.remove();
        } catch (_) {}
        if (!completer.isCompleted) completer.complete();
      },
    ),
  );
  overlay.insert(entry);
  return completer.future;
}

class DesktopGlassPanel extends StatelessWidget {
  const DesktopGlassPanel({super.key, required this.child, this.borderRadius});

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

class _DesktopGlassPopoverOverlay extends StatefulWidget {
  const _DesktopGlassPopoverOverlay({
    required this.anchorRect,
    required this.width,
    required this.builder,
    required this.onClose,
  });

  final Rect anchorRect;
  final double width;
  final Widget Function(BuildContext context, DesktopGlassPopoverHandle handle)
  builder;
  final VoidCallback onClose;

  @override
  State<_DesktopGlassPopoverOverlay> createState() =>
      _DesktopGlassPopoverOverlayState();
}

class _DesktopGlassPopoverOverlayState
    extends State<_DesktopGlassPopoverOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  late final DesktopGlassPopoverHandle _handle;
  bool _closing = false;
  bool _suspended = false;
  Offset _offset = const Offset(0, 0.12);

  @override
  void initState() {
    super.initState();
    _handle = DesktopGlassPopoverHandle._(
      close: _close,
      setSuspended: _setSuspended,
    );
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

  void _setSuspended(bool value) {
    if (!mounted || _suspended == value) return;
    setState(() => _suspended = value);
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
    final width = widget.width;
    final left =
        (widget.anchorRect.left + (widget.anchorRect.width - width) / 2).clamp(
          8.0,
          screen.width - width - 8.0,
        );
    final clipHeight = widget.anchorRect.top.clamp(0.0, screen.height);

    return IgnorePointer(
      ignoring: _suspended,
      child: Opacity(
        opacity: _suspended ? 0.0 : 1.0,
        child: Stack(
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
                          child: DesktopGlassPanel(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(14),
                            ),
                            child: widget.builder(context, _handle),
                          ),
                        ),
                      ),
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
