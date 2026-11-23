import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../desktop/desktop_context_menu.dart' show DesktopContextMenuItem;
import '../../../icons/lucide_adapter.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/sliding_segmented_tabs.dart';
import '../../../theme/app_semantic_colors.dart';

Future<void> showCreationMenu(
  BuildContext context, {
  required Offset globalPosition,
  required List<DesktopContextMenuItem> items,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final overlay = navigator.overlay?.context.findRenderObject() as RenderBox?;
  if (overlay == null) return;
  final origin = overlay.globalToLocal(globalPosition);
  final duration = handoffDuration(context, 170);
  final selection = await showGeneralDialog<DesktopContextMenuItem>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: duration,
    pageBuilder: (ctx, animation, _) {
      final cs = Theme.of(ctx).colorScheme;
      final radius = BorderRadius.circular(14);
      final anim = animation.drive(CurveTween(curve: handoffCurve));
      return CustomSingleChildLayout(
        delegate: _MenuPosition(origin),
        child: FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween(begin: .94, end: 1.0).animate(anim),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: ctx.appColors.surfaceCard,
                borderRadius: radius,
                border: Border.all(
                  color: cs.onSurface.withValues(alpha: .08),
                  width: .5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: cs.brightness == Brightness.dark ? .48 : .14,
                    ),
                    offset: const Offset(0, 12),
                    blurRadius: 32,
                  ),
                ],
              ),
              child: Material(
                type: MaterialType.transparency,
                textStyle: TextStyle(
                  color: cs.onSurface,
                  fontSize: 13.5,
                  letterSpacing: 0,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final it in items) ...[
                        if (it.startsGroup)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            child: ColoredBox(
                              color: cs.onSurface.withValues(alpha: .08),
                              child: const SizedBox(height: 1),
                            ),
                          ),
                        if (it.groupLabel case final label?)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
                            child: Text(
                              label,
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        Semantics(
                          button: it.onTap != null,
                          selected: it.checked,
                          child: IosCardPress(
                            focusable: it.onTap != null,
                            baseColor: it.checked
                                ? cs.primary.withValues(alpha: .10)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(9),
                            duration: handoffDuration(ctx, 140),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            onTap: it.onTap == null
                                ? null
                                : () => Navigator.of(ctx).pop(it),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 28),
                              child: Row(
                                children: [
                                  if (it.icon case final icon?) ...[
                                    Icon(
                                      icon,
                                      size: 16,
                                      color: it.danger
                                          ? cs.error
                                          : cs.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 10),
                                  ],
                                  Expanded(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          it.label,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            color: it.danger
                                                ? cs.error
                                                : it.onTap == null
                                                ? cs.onSurfaceVariant
                                                : cs.onSurface,
                                          ),
                                        ),
                                        if (it.subtitle case final sub?)
                                          Text(
                                            sub,
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: cs.onSurfaceVariant,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (it.checked)
                                    Icon(
                                      Lucide.Check,
                                      size: 15,
                                      color: cs.primary,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (_, _, _, child) => child,
  );
  if (context.mounted) selection?.onTap?.call();
}

class _MenuPosition extends SingleChildLayoutDelegate {
  const _MenuPosition(this.origin);
  final Offset origin;
  @override
  BoxConstraints getConstraintsForChild(BoxConstraints c) =>
      BoxConstraints.tightFor(
        width: math.min(236, math.max(0, c.maxWidth - 16)),
      ).copyWith(maxHeight: math.max(0, c.maxHeight - 16));
  @override
  Offset getPositionForChild(Size size, Size child) {
    final below = origin.dy + 6;
    return Offset(
      origin.dx.clamp(8, math.max(8.0, size.width - child.width - 8)),
      (below + child.height <= size.height - 8
              ? below
              : origin.dy - child.height - 6)
          .clamp(8, math.max(8.0, size.height - child.height - 8)),
    );
  }

  @override
  bool shouldRelayout(_MenuPosition old) => old.origin != origin;
}
