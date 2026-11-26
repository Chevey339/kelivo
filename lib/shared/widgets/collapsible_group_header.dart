import 'package:flutter/material.dart';

import '../../icons/lucide_adapter.dart';
import '../../theme/app_font_weights.dart';
import 'ios_tactile.dart';

class CollapsibleGroupHeader extends StatelessWidget {
  const CollapsibleGroupHeader({
    super.key,
    required this.title,
    required this.count,
    required this.collapsed,
    required this.onToggle,
    this.actions = const [],
  });

  final String title;
  final String count;
  final bool collapsed;
  final VoidCallback? onToggle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              expanded: onToggle == null ? null : !collapsed,
              child: IosCardPress(
                focusable: true,
                haptics: false,
                baseColor: Colors.transparent,
                pressedBlendStrength: 0,
                borderRadius: BorderRadius.circular(10),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                onTap: onToggle,
                child: SizedBox(
                  height: 44,
                  child: Row(
                    children: [
                      if (onToggle == null)
                        const SizedBox(width: 14)
                      else
                        AnimatedRotation(
                          turns: collapsed ? 0 : .25,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          child: Icon(
                            Lucide.ChevronRight,
                            size: 14,
                            color: color.withValues(alpha: .45),
                          ),
                        ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: AppFontWeights.medium,
                            color: color.withValues(alpha: .65),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        count,
                        style: TextStyle(
                          fontSize: 12,
                          color: color.withValues(alpha: .4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}
