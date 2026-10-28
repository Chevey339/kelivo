import 'package:flutter/material.dart';

import '../../features/chat/widgets/frosted/chat_frosted_backdrop.dart';
import '../../features/chat/widgets/frosted/frosted_surface.dart';
import '../../theme/chat_bubble_style.dart';
import '../../theme/app_semantic_colors.dart';

/// Desktop chrome samples the same wallpaper as the chat, without recropping
/// it separately for each pane or filtering the native browser contents.
class DesktopPaneSurface extends StatelessWidget {
  const DesktopPaneSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final wallpaper =
        ChatFrostedBackdropScope.maybeOf(context)?.backgroundActive ?? false;
    final colors = context.appColors;
    final dark = cs.brightness == Brightness.dark;
    // The pane and its controls share one material. Flattened surface tokens
    // would cover the wallpaper again inside search fields, tabs and buttons.
    final controls = colors.copyWith(
      surfaceFill: cs.onSurface.withValues(alpha: dark ? .10 : .045),
      surfaceCard: cs.surface.withValues(alpha: dark ? .12 : .18),
      surfaceCardFill: cs.onSurface.withValues(alpha: dark ? .08 : .035),
    );
    return FrostedSurface(
      borderRadius: BorderRadius.zero,
      style: ResolvedBubbleStyle(
        background: cs.surface.withValues(alpha: wallpaper ? .60 : 1),
        border: Colors.transparent,
        text: cs.onSurface,
        borderWidth: 0,
        radius: 0,
        blurSigma: wallpaper ? 6 : 0,
      ),
      child: AppSurfaceColorsScope(
        colors: wallpaper ? controls : colors,
        child: child,
      ),
    );
  }
}
