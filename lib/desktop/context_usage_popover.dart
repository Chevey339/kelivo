import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/home/services/context_usage_service.dart';
import '../icons/lucide_adapter.dart';
import '../l10n/app_localizations.dart';
import '../shared/widgets/context_usage_details.dart';
import '../shared/widgets/context_usage_ring.dart';
import '../shared/widgets/ios_tactile.dart';
import '../theme/app_font_weights.dart';
import '../theme/design_tokens.dart';
import 'model_spec_edit_dialog.dart';

const Key contextUsagePopoverKey = ValueKey<String>('context-usage-popover');

Future<void> showContextUsagePopover(
  BuildContext context, {
  required Rect anchorRect,
  required String conversationId,
  required String draftText,
  VoidCallback? onCompress,
  VoidCallback? onClear,
}) async {
  final usage = context.read<ContextUsageService>();
  unawaited(usage.refresh(conversationId, draftText: draftText));

  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;

  var requestSetWindow = false;
  final completer = Completer<void>();
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => _ContextUsagePopoverOverlay(
      anchorRect: anchorRect,
      conversationId: conversationId,
      draftText: draftText,
      onCompress: onCompress,
      onClear: onClear,
      onRequestSetWindow: () => requestSetWindow = true,
      onClose: () {
        try {
          entry.remove();
        } catch (_) {}
        if (!completer.isCompleted) completer.complete();
      },
    ),
  );
  overlay.insert(entry);
  await completer.future;
  if (!context.mounted || !requestSetWindow) return;

  final snap = usage.snapshot(conversationId) ?? usage.current;
  if (snap == null || snap.providerKey.isEmpty || snap.modelId.isEmpty) {
    return;
  }
  final saved = await showDesktopModelSpecEditDialog(
    context,
    providerKey: snap.providerKey,
    modelKey: snap.modelId,
  );
  if (saved == true && context.mounted) {
    await usage.refresh(conversationId, draftText: draftText, force: true);
  }
}

class _ContextUsagePopoverOverlay extends StatefulWidget {
  const _ContextUsagePopoverOverlay({
    required this.anchorRect,
    required this.conversationId,
    required this.draftText,
    required this.onClose,
    required this.onRequestSetWindow,
    this.onCompress,
    this.onClear,
  });

  final Rect anchorRect;
  final String conversationId;
  final String draftText;
  final VoidCallback onClose;
  final VoidCallback onRequestSetWindow;
  final VoidCallback? onCompress;
  final VoidCallback? onClear;

  @override
  State<_ContextUsagePopoverOverlay> createState() =>
      _ContextUsagePopoverOverlayState();
}

class _ContextUsagePopoverOverlayState
    extends State<_ContextUsagePopoverOverlay>
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
    const width = 300.0;
    final screen = MediaQuery.of(context).size;
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
                        child: _ContextUsagePopoverContent(
                          conversationId: widget.conversationId,
                          draftText: widget.draftText,
                          onCompress: widget.onCompress,
                          onClear: widget.onClear,
                          onClose: _close,
                          onRequestSetWindow: () async {
                            widget.onRequestSetWindow();
                            await _close();
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

class _ContextUsagePopoverContent extends StatelessWidget {
  const _ContextUsagePopoverContent({
    required this.conversationId,
    required this.draftText,
    required this.onClose,
    required this.onRequestSetWindow,
    this.onCompress,
    this.onClear,
  });

  final String conversationId;
  final String draftText;
  final VoidCallback onClose;
  final VoidCallback onRequestSetWindow;
  final VoidCallback? onCompress;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final usage = context.watch<ContextUsageService>();
    final snapshot = usage.snapshot(conversationId) ?? usage.current;
    final showSetWindow =
        snapshot != null &&
        snapshot.contextWindow == null &&
        snapshot.providerKey.isNotEmpty &&
        snapshot.modelId.isNotEmpty;

    return ConstrainedBox(
      key: contextUsagePopoverKey,
      constraints: const BoxConstraints(maxHeight: 420),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ContextUsageRing(snapshot: snapshot, onTap: () {}, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.contextUsageTitle,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: AppFontWeights.semibold,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                IosIconButton(
                  tooltip: l10n.contextUsageRefresh,
                  semanticLabel: l10n.contextUsageRefresh,
                  icon: Lucide.RefreshCw,
                  size: 16,
                  onTap: () => usage.refresh(
                    conversationId,
                    draftText: draftText,
                    force: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              contextUsageSummaryText(l10n, snapshot),
              style: TextStyle(
                fontSize: 15,
                fontWeight: AppFontWeights.semibold,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              contextUsageStateLabel(l10n, snapshot),
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withValues(alpha: 0.55),
              ),
            ),
            if (snapshot?.state == ContextUsageState.estimated) ...[
              const SizedBox(height: 12),
              ContextUsageBucketBars(snapshot: snapshot!),
            ],
            if (snapshot?.state == ContextUsageState.exact) ...[
              const SizedBox(height: 10),
              Text(
                l10n.contextUsageExactNote,
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ],
            if (showSetWindow) ...[
              const SizedBox(height: 8),
              _ActionRow(
                key: const ValueKey('context-usage-set-window'),
                icon: Lucide.Settings2,
                label: l10n.contextUsageSetWindow,
                onTap: onRequestSetWindow,
              ),
            ],
            if (onCompress != null) ...[
              const SizedBox(height: 4),
              _ActionRow(
                icon: Lucide.package2,
                label: l10n.compressContext,
                onTap: () {
                  onClose();
                  onCompress!();
                },
              ),
            ],
            if (onClear != null) ...[
              const SizedBox(height: 4),
              _ActionRow(
                icon: Lucide.Eraser,
                label: l10n.bottomToolsSheetClearContext,
                onTap: () {
                  onClose();
                  onClear!();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatefulWidget {
  const _ActionRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_ActionRow> createState() => _ActionRowState();
}

class _ActionRowState extends State<_ActionRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
            color: _hovered
                ? cs.onSurface.withValues(alpha: isDark ? 0.12 : 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 16, color: cs.onSurface),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: AppFontWeights.regular,
                    color: cs.onSurface,
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
