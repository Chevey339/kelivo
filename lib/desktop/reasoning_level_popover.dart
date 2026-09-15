import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/models/assistant.dart';
import '../core/providers/settings_provider.dart';
import '../features/chat/widgets/reasoning_level_sheet.dart';
import '../theme/design_tokens.dart';

Future<void> showDesktopReasoningLevelPopover(
  BuildContext context, {
  required GlobalKey anchorKey,
  required ProviderConfig config,
  required String modelId,
  Assistant? assistant,
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

  final completer = Completer<void>();

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => _ReasoningPopoverOverlay(
      anchorRect: anchorRect,
      anchorWidth: size.width,
      config: config,
      modelId: modelId,
      assistant: assistant,
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

class _ReasoningPopoverOverlay extends StatefulWidget {
  const _ReasoningPopoverOverlay({
    required this.anchorRect,
    required this.anchorWidth,
    required this.config,
    required this.modelId,
    this.assistant,
    required this.onClose,
  });

  final Rect anchorRect;
  final double anchorWidth;
  final ProviderConfig config;
  final String modelId;
  final Assistant? assistant;
  final VoidCallback onClose;

  @override
  State<_ReasoningPopoverOverlay> createState() =>
      _ReasoningPopoverOverlayState();
}

class _ReasoningPopoverOverlayState extends State<_ReasoningPopoverOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  bool _closing = false;
  bool _suspended = false;
  Offset _offset = const Offset(0, 0.12);

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
                          child: _GlassPanel(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(14),
                            ),
                            child: ReasoningLevelPicker(
                              config: widget.config,
                              modelId: widget.modelId,
                              assistant: widget.assistant,
                              compact: true,
                              onClose: _close,
                              onSuspendedChanged: (v) {
                                if (_suspended == v) return;
                                setState(() => _suspended = v);
                              },
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
        ),
      ),
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
