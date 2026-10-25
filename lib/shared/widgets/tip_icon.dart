import 'package:flutter/material.dart';

import '../../icons/lucide_adapter.dart';

/// Compact info icon: tap or long-press shows [message].
class TipIcon extends StatefulWidget {
  const TipIcon({super.key, required this.message});

  final String message;

  @override
  State<TipIcon> createState() => _TipIconState();
}

class _TipIconState extends State<TipIcon> {
  final _tooltipKey = GlobalKey<TooltipState>();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      key: _tooltipKey,
      message: widget.message,
      triggerMode: TooltipTriggerMode.tap,
      waitDuration: const Duration(milliseconds: 250),
      showDuration: const Duration(seconds: 8),
      preferBelow: true,
      constraints: const BoxConstraints(maxWidth: 280),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: () => _tooltipKey.currentState?.ensureTooltipVisible(),
        child: SizedBox(
          width: 28,
          height: 28,
          child: Center(
            child: Icon(
              Lucide.BadgeInfo,
              size: 16,
              color: cs.onSurface.withValues(alpha: 0.45),
              semanticLabel: widget.message,
            ),
          ),
        ),
      ),
    );
  }
}
