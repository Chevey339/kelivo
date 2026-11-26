import 'package:flutter/material.dart';

import '../../shared/widgets/ios_tactile.dart';
import '../../theme/design_tokens.dart';
import '../../theme/surface_ladder.dart';
import 'desktop_pointer_surface.dart';

/// The right-hand panel and anchored chat menus share the same menu material,
/// compact rows and pointer feedback.
class DesktopMenuSurface extends StatelessWidget {
  const DesktopMenuSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Color.alphaBlend(
        AppOverlayColors.desktopPopoverSurface(cs),
        cs.surface,
      ),
      elevation: 12,
      shadowColor: cs.shadow.withValues(alpha: .18),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: DesktopPointerSurface(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: child,
        ),
      ),
    );
  }
}

class DesktopMenuRow extends StatelessWidget {
  const DesktopMenuRow({
    super.key,
    required this.label,
    this.leading,
    this.trailing,
    this.tooltip,
    this.selected = false,
    this.onTap,
  });
  final String label;
  final String? tooltip;
  final Widget? leading, trailing;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IosCardPress(
      mouseCursor: SystemMouseCursors.basic,
      haptics: false,
      focusable: true,
      borderRadius: BorderRadius.circular(8),
      baseColor: selected
          ? SurfaceLadder.fromScheme(cs).surfaceFill
          : Colors.transparent,
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: SizedBox(
        height: 32,
        child: Row(
          children: [
            const SizedBox(width: 8),
            if (leading != null) ...[leading!, const SizedBox(width: 8)],
            Expanded(
              child: Tooltip(
                message: tooltip ?? '',
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: onTap == null ? cs.onSurfaceVariant : cs.onSurface,
                  ),
                ),
              ),
            ),
            if (trailing != null) trailing!,
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}
