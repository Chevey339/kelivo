import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/services/model_catalog/model_catalog_service.dart';
import '../features/provider/widgets/model_catalog_panel.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_font_weights.dart';
import '../theme/design_tokens.dart';

const Key modelCatalogPopoverKey = ValueKey<String>('model-catalog-popover');

Future<void> showDesktopModelCatalogPopover(
  BuildContext context, {
  required GlobalKey anchorKey,
  ModelCatalogService? catalog,
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
    builder: (ctx) => _ModelCatalogPopoverOverlay(
      anchorRect: anchorRect,
      catalog: catalog ?? ModelCatalogService.instance,
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

class _ModelCatalogPopoverOverlay extends StatefulWidget {
  const _ModelCatalogPopoverOverlay({
    required this.anchorRect,
    required this.catalog,
    required this.onClose,
  });

  final Rect anchorRect;
  final ModelCatalogService catalog;
  final VoidCallback onClose;

  @override
  State<_ModelCatalogPopoverOverlay> createState() =>
      _ModelCatalogPopoverOverlayState();
}

class _ModelCatalogPopoverOverlayState
    extends State<_ModelCatalogPopoverOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  Offset _offset = const Offset(0, -0.08);
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
    setState(() => _offset = const Offset(0, -0.08));
    try {
      await _controller.reverse();
    } catch (_) {}
    if (mounted) widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    const width = 320.0;
    final screen = MediaQuery.of(context).size;
    final left = (widget.anchorRect.right - width).clamp(
      8.0,
      screen.width - width - 8.0,
    );
    final top = (widget.anchorRect.bottom + 8).clamp(8.0, screen.height - 8.0);

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _close,
          ),
        ),
        Positioned(
          left: left,
          top: top,
          width: width,
          child: FadeTransition(
            opacity: _fadeIn,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              offset: _offset,
              child: _GlassPanel(
                child: _ModelCatalogPopoverContent(catalog: widget.catalog),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(14);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppOverlayColors.desktopPopoverSurface(cs),
            borderRadius: radius,
            border: Border.all(
              color: cs.onSurface.withValues(alpha: isDark ? 0.06 : 0.12),
              width: 0.7,
            ),
          ),
          child: Material(type: MaterialType.transparency, child: child),
        ),
      ),
    );
  }
}

class _ModelCatalogPopoverContent extends StatelessWidget {
  const _ModelCatalogPopoverContent({required this.catalog});

  final ModelCatalogService catalog;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return ConstrainedBox(
      key: modelCatalogPopoverKey,
      constraints: const BoxConstraints(maxHeight: 420),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
              child: Text(
                l10n.modelCatalogTitle,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: AppFontWeights.semibold,
                  color: cs.onSurface,
                ),
              ),
            ),
            ModelCatalogPanel(catalog: catalog, compact: true),
          ],
        ),
      ),
    );
  }
}
