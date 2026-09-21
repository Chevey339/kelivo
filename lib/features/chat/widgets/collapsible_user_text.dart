import 'package:flutter/material.dart';

import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../theme/app_font_weights.dart';
import 'chat_surface.dart';

/// Clips an over-long user message to [collapsedHeight], fading the cut edge
/// out and offering an expand/collapse toggle underneath.
///
/// The fade is a [BlendMode.dstIn] shader over the content itself rather than a
/// gradient painted in the bubble colour, so it works for every bubble style
/// (default, solid, frosted) without knowing the background.
class CollapsibleUserText extends StatefulWidget {
  const CollapsibleUserText({
    super.key,
    required this.child,
    required this.collapsedHeight,
  });

  final Widget child;
  final double collapsedHeight;

  @override
  State<CollapsibleUserText> createState() => _CollapsibleUserTextState();
}

class _CollapsibleUserTextState extends State<CollapsibleUserText> {
  /// Keeps the message content one element across every state change.
  ///
  /// Collapsing, expanding and turning the fade on each nest the content under
  /// a different wrapper, which would otherwise rebuild the subtree from
  /// scratch and reset whatever state lives inside the bubble — a `<details>`
  /// block or a code block the reader just expanded. A global key reparents the
  /// existing element instead.
  final GlobalKey _contentKey = GlobalKey();

  bool _expanded = false;

  /// Whether the clipped content actually spills past [collapsedHeight].
  ///
  /// The caller only builds this widget past a character threshold, so the
  /// content overflows in practice; the clip box reports back to drop the
  /// toggle for the rare wide-bubble message that happens to fit.
  bool _overflowing = true;

  /// Re-measures whenever the clip box's extents change, not just when this
  /// widget rebuilds: content inside the bubble grows on its own when, say, a
  /// collapsed code block is expanded.
  bool _handleClipMetrics(ScrollMetricsNotification notification) {
    // Scrollables nested in the message (wide code blocks) bubble through here
    // with a non-zero depth; only the clip box itself measures the overflow.
    if (notification.depth == 0) {
      final overflowing = notification.metrics.maxScrollExtent > 0.5;
      if (overflowing != _overflowing && mounted) {
        setState(() => _overflowing = overflowing);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final content = KeyedSubtree(key: _contentKey, child: widget.child);
    if (_expanded) {
      return _wrap(context, content);
    }

    Widget clipped = ConstrainedBox(
      key: const ValueKey('collapsible-user-text-clip'),
      constraints: BoxConstraints(maxHeight: widget.collapsedHeight),
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: _handleClipMetrics,
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: content,
        ),
      ),
    );
    if (_overflowing) {
      clipped = ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Colors.white, Colors.transparent],
          stops: [0.0, 0.72, 1.0],
        ).createShader(rect),
        child: clipped,
      );
    }
    return _wrap(context, clipped);
  }

  Widget _wrap(BuildContext context, Widget body) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: body,
        ),
        if (_overflowing || _expanded) ...[
          const SizedBox(height: 4),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Semantics(
              button: true,
              expanded: _expanded,
              child: _ToggleButton(
                expanded: _expanded,
                onTap: () => setState(() => _expanded = !_expanded),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = chatSurfaceForegroundPalette(context, isUser: true);
    final label = expanded
        ? l10n.chatMessageCollapseLongText
        : l10n.chatMessageExpandLongText;
    return IosCardPress(
      key: const ValueKey('collapsible-user-text-toggle'),
      baseColor: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: AppFontWeights.medium,
                color: palette.body,
              ),
            ),
            const SizedBox(width: 4),
            AnimatedRotation(
              turns: expanded ? 0.5 : 0.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: Icon(Lucide.ChevronDown, size: 15, color: palette.body),
            ),
          ],
        ),
      ),
    );
  }
}
