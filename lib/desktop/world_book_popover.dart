import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/world_book.dart';
import '../core/providers/world_book_provider.dart';
import '../icons/lucide_adapter.dart';
import '../l10n/app_localizations.dart';

Future<void> showDesktopWorldBookPopover(
  BuildContext context, {
  required GlobalKey anchorKey,
  required List<WorldBook> books,
  String? assistantId,
}) async {
  if (books.isEmpty) return;
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
    builder: (ctx) => _WorldBookPopover(
      anchorRect: anchorRect,
      anchorWidth: size.width,
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

class _WorldBookPopover extends StatefulWidget {
  const _WorldBookPopover({
    required this.anchorRect,
    required this.anchorWidth,
    required this.assistantId,
    required this.onClose,
  });

  final Rect anchorRect;
  final double anchorWidth;
  final String? assistantId;
  final VoidCallback onClose;

  @override
  State<_WorldBookPopover> createState() => _WorldBookPopoverState();
}

class _WorldBookPopoverState extends State<_WorldBookPopover>
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
                        child: _WorldBookList(
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

class _WorldBookList extends StatelessWidget {
  const _WorldBookList({required this.assistantId, required this.onClose});

  final String? assistantId;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 420),
        child: _WorldBookListInner(assistantId: assistantId, onClose: onClose),
      ),
    );
  }
}

class _WorldBookListInner extends StatelessWidget {
  const _WorldBookListInner({required this.assistantId, required this.onClose});

  final String? assistantId;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final provider = context.watch<WorldBookProvider>();
    final books = provider.books;
    final selected = provider.activeBookIdsFor(assistantId).toSet();

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
                  await context.read<WorldBookProvider>().setActiveBookIds(
                    const <String>[],
                    assistantId: assistantId,
                  );
                } catch (_) {}
                onClose();
              },
            ),
          ),
          for (final book in books)
            Padding(
              padding: const EdgeInsets.only(bottom: 1),
              child: _RowItem(
                title: book.name.trim().isEmpty
                    ? l10n.worldBookUnnamed
                    : book.name,
                preview: book.description,
                active: selected.contains(book.id),
                disabled: !book.enabled,
                onTap: () async {
                  final isActive = selected.contains(book.id);
                  if (!book.enabled && !isActive) return;
                  try {
                    await context.read<WorldBookProvider>().toggleActiveBookId(
                      book.id,
                      assistantId: assistantId,
                    );
                  } catch (_) {}
                },
              ),
            ),
        ],
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
    required this.disabled,
    required this.onTap,
  });

  final String title;
  final String preview;
  final bool active;
  final bool disabled;
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

    final opacity = widget.disabled ? 0.55 : 1.0;
    final canTap = !widget.disabled || widget.active;

    return MouseRegion(
      cursor: canTap ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: canTap ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: _hovered && canTap ? hoverBg : baseBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Lucide.BookOpen,
                size: 16,
                color: widget.active
                    ? cs.primary.withOpacity(opacity)
                    : cs.onSurface.withOpacity(0.7 * opacity),
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
                    color: widget.active
                        ? cs.primary.withOpacity(opacity)
                        : cs.onSurface.withOpacity(opacity),
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
                        widget.preview.trim().isEmpty
                            ? (widget.disabled
                                  ? AppLocalizations.of(
                                      context,
                                    )!.worldBookDisabledTag
                                  : '')
                            : widget.preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: cs.onSurface.withOpacity(0.70 * opacity),
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    if (widget.active) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Lucide.Check,
                        size: 14,
                        color: cs.primary.withOpacity(opacity),
                      ),
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
