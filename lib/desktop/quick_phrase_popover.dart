import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/models/quick_phrase.dart';
import '../icons/lucide_adapter.dart';

Future<QuickPhrase?> showDesktopQuickPhrasePopover(
  BuildContext context, {
  required GlobalKey anchorKey,
  required List<QuickPhrase> phrases,
}) async {
  if (phrases.isEmpty) return null;
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return null;
  final keyContext = anchorKey.currentContext;
  if (keyContext == null) return null;

  final box = keyContext.findRenderObject() as RenderBox?;
  if (box == null) return null;
  final offset = box.localToGlobal(Offset.zero);
  final size = box.size;
  final anchorRect = Rect.fromLTWH(
    offset.dx,
    offset.dy,
    size.width,
    size.height,
  );

  final completer = Completer<QuickPhrase?>();
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => _QuickPhrasePopover(
      anchorRect: anchorRect,
      anchorWidth: size.width,
      phrases: phrases,
      onSelect: (p) {
        try {
          entry.remove();
        } catch (_) {}
        if (!completer.isCompleted) completer.complete(p);
      },
      onClose: () {
        try {
          entry.remove();
        } catch (_) {}
        if (!completer.isCompleted) completer.complete(null);
      },
    ),
  );
  overlay.insert(entry);
  return completer.future;
}

class _QuickPhrasePopover extends StatefulWidget {
  const _QuickPhrasePopover({
    required this.anchorRect,
    required this.anchorWidth,
    required this.phrases,
    required this.onSelect,
    required this.onClose,
  });

  final Rect anchorRect;
  final double anchorWidth;
  final List<QuickPhrase> phrases;
  final ValueChanged<QuickPhrase> onSelect;
  final VoidCallback onClose;

  @override
  State<_QuickPhrasePopover> createState() => _QuickPhrasePopoverState();
}

class _QuickPhrasePopoverState extends State<_QuickPhrasePopover>
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
    final width = (widget.anchorWidth - 16).clamp(320.0, 720.0);
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
                        child: _QuickPhraseList(
                          phrases: widget.phrases,
                          onSelect: (p) async {
                            if (_closing) return;
                            widget.onSelect(p);
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
            color: (isDark ? Colors.black : Colors.white).withValues(
              alpha: isDark ? 0.28 : 0.56,
            ),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: isDark ? 0.06 : 0.18),
                width: 0.7,
              ),
              left: BorderSide(
                color: Colors.white.withValues(alpha: isDark ? 0.04 : 0.12),
                width: 0.6,
              ),
              right: BorderSide(
                color: Colors.white.withValues(alpha: isDark ? 0.04 : 0.12),
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

class _QuickPhraseList extends StatelessWidget {
  const _QuickPhraseList({required this.phrases, required this.onSelect});
  final List<QuickPhrase> phrases;
  final ValueChanged<QuickPhrase> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 420),
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
          shrinkWrap: true,
          itemCount: phrases.length,
          itemBuilder: (context, index) {
            final p = phrases[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 1),
              child: _RowItem(
                title: p.title,
                preview: p.content,
                isGlobal: p.isGlobal,
                onTap: () => onSelect(p),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RowItem extends StatefulWidget {
  const _RowItem({
    required this.title,
    required this.preview,
    required this.isGlobal,
    required this.onTap,
  });
  final String title;
  final String preview;
  final bool isGlobal;
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
    final hoverBg = (isDark ? Colors.white : Colors.black).withValues(
      alpha: isDark ? 0.12 : 0.10,
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
              // Left: icon + title
              Icon(
                widget.isGlobal ? Lucide.Zap : Lucide.botMessageSquare,
                size: 16,
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Right: content preview
              Expanded(
                flex: 1,
                child: Text(
                  widget.preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurface.withValues(alpha: 0.70),
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
