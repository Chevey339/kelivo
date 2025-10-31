import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../core/providers/settings_provider.dart';
import '../icons/lucide_adapter.dart';
import '../l10n/app_localizations.dart';

Future<void> showDesktopReasoningBudgetPopover(
  BuildContext context, {
  required GlobalKey anchorKey,
}) async {
  final overlay = Overlay.of(context);
  if (overlay == null) return;
  final keyContext = anchorKey.currentContext;
  if (keyContext == null) return;

  final box = keyContext.findRenderObject() as RenderBox?;
  if (box == null) return;
  final offset = box.localToGlobal(Offset.zero);
  final size = box.size;
  final anchorRect = Rect.fromLTWH(offset.dx, offset.dy, size.width, size.height);

  final completer = Completer<void>();

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => _ReasoningPopoverOverlay(
      anchorRect: anchorRect,
      anchorWidth: size.width,
      onClose: () {
        try { entry.remove(); } catch (_) {}
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
    required this.onClose,
  });

  final Rect anchorRect;
  final double anchorWidth;
  final VoidCallback onClose;

  @override
  State<_ReasoningPopoverOverlay> createState() => _ReasoningPopoverOverlayState();
}

class _ReasoningPopoverOverlayState extends State<_ReasoningPopoverOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  bool _closing = false;
  Offset _offset = const Offset(0, 0.12);

  @override
  void initState() {
    super.initState();
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

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    setState(() => _offset = const Offset(0, 1.0));
    try { await _controller.reverse(); } catch (_) {}
    if (mounted) widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    // Slightly narrower than input width
    final width = (widget.anchorWidth - 16).clamp(260.0, 720.0);
    final left = (widget.anchorRect.left + (widget.anchorRect.width - width) / 2)
        .clamp(8.0, screen.width - width - 8.0);
    final clipHeight = widget.anchorRect.top.clamp(0.0, screen.height);

    return Stack(
      children: [
        // tap outside to close
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
                        child: _ReasoningContent(onDone: _close),
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
            // Match the preferred grey smudge style
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

class _ReasoningContent extends StatelessWidget {
  const _ReasoningContent({required this.onDone});
  final VoidCallback onDone;

  int _bucket(int? n) {
    if (n == null) return -1;
    if (n == -1) return -1;
    if (n < 1024) return 0;
    if (n < 16000) return 1024;
    if (n < 32000) return 16000;
    return 32000;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sp = context.watch<SettingsProvider>();
    final selected = _bucket(sp.thinkingBudget);

    Widget tile({
      required Widget Function(Color color) leadingBuilder,
      required String label,
      required int value,
    }) {
      final cs = Theme.of(context).colorScheme;
      final active = selected == value;
      final onColor = active ? cs.primary : cs.onSurface;
      final iconColor = active ? cs.primary : cs.onSurface;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
        child: _HoverRow(
          leading: leadingBuilder(iconColor),
          label: label,
          selected: active,
          onTap: () async {
            await context.read<SettingsProvider>().setThinkingBudget(value);
            onDone();
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
            tile(
              leadingBuilder: (c) => Icon(Lucide.X, size: 16, color: c),
              label: l10n.reasoningBudgetSheetOff,
              value: 0,
            ),
            tile(
              leadingBuilder: (c) => Icon(Lucide.Settings2, size: 16, color: c),
              label: l10n.reasoningBudgetSheetAuto,
              value: -1,
            ),
            tile(
              leadingBuilder: (c) => SvgPicture.asset('assets/icons/deepthink.svg', width: 16, height: 16, colorFilter: ColorFilter.mode(c, BlendMode.srcIn)),
              label: l10n.reasoningBudgetSheetLight,
              value: 1024,
            ),
            tile(
              leadingBuilder: (c) => SvgPicture.asset('assets/icons/deepthink.svg', width: 16, height: 16, colorFilter: ColorFilter.mode(c, BlendMode.srcIn)),
              label: l10n.reasoningBudgetSheetMedium,
              value: 16000,
            ),
            tile(
              leadingBuilder: (c) => SvgPicture.asset('assets/icons/deepthink.svg', width: 16, height: 16, colorFilter: ColorFilter.mode(c, BlendMode.srcIn)),
              label: l10n.reasoningBudgetSheetHeavy,
              value: 32000,
            ),
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
    final baseBg = Colors.transparent;
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
            color: _hovered ? hoverBg : baseBg,
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
