import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import '../../../shared/widgets/sliding_segmented_tabs.dart';
import '../../../theme/app_semantic_colors.dart';
import '../../../shared/widgets/action_sheet.dart' show ActionSheetItem;
import '../../../shared/widgets/ios_tactile.dart';
import '../../../icons/lucide_adapter.dart';

/// Parameter controls share one responsive route. The desktop placement is in
/// the navigator overlay's coordinates, including when the tab has a side rail.
Future<T?> showCreationPicker<T>(
  BuildContext anchor, {
  required bool desktop,
  required String title,
  required WidgetBuilder builder,
  double width = 320,
  bool scroll = true,
  bool darkSheet = false,
}) {
  final nav = Navigator.of(anchor);
  final box = anchor.findRenderObject()! as RenderBox;
  final overlay = nav.overlay!.context.findRenderObject()! as RenderBox;
  final rect = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
  final themes = InheritedTheme.capture(from: anchor, to: nav.context);
  final duration = handoffDuration(anchor, desktop ? 200 : 420);
  final initialSize = MediaQuery.sizeOf(anchor);
  return nav.push<T>(
    RawDialogRoute<T>(
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(anchor).modalBarrierDismissLabel,
      barrierColor: desktop
          ? Colors.transparent
          : Colors.black.withValues(alpha: .32),
      transitionDuration: duration,
      pageBuilder: (context, animation, _) {
        if (desktop && MediaQuery.sizeOf(context) != initialSize) {
          final route = ModalRoute.of(context);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (route?.isCurrent == true && nav.mounted) nav.pop();
          });
          return const SizedBox.shrink();
        }
        final cs = darkSheet
            ? const ColorScheme.dark(surface: Color(0xff1c1c1e))
            : Theme.of(context).colorScheme;
        final dark = cs.brightness == Brightness.dark;
        final curve = animation.drive(CurveTween(curve: handoffCurve));
        final media = MediaQuery.of(context);
        final availableHeight = math.max(
          0.0,
          media.size.height - media.viewInsets.bottom - media.padding.top,
        );
        final shortSheet =
            !desktop && availableHeight < 220 * media.textScaler.scale(14) / 14;
        final content = builder(context);
        final paddedContent = Padding(
          padding: EdgeInsets.fromLTRB(
            desktop ? 8 : 16,
            4,
            desktop ? 8 : 16,
            desktop ? 8 : 16,
          ),
          child: scroll && !shortSheet
              ? SingleChildScrollView(child: content)
              : content,
        );
        final panel = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!desktop)
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 9),
                  height: 4,
                  width: 36,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: .20),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            if (title.isNotEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  desktop ? 14 : 20,
                  desktop ? 12 : 4,
                  16,
                  desktop ? 6 : 12,
                ),
                child: Text(
                  title,
                  style: TextStyle(
                    color: desktop ? cs.onSurfaceVariant : cs.onSurface,
                    fontSize: desktop ? 12.5 : 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (shortSheet) paddedContent else Flexible(child: paddedContent),
          ],
        );
        final body = Material(
          type: MaterialType.transparency,
          textStyle: Theme.of(context).textTheme.bodyMedium!.copyWith(
            color: cs.onSurface,
            fontSize: 13.5,
            letterSpacing: 0,
            decoration: TextDecoration.none,
          ),
          child: shortSheet ? SingleChildScrollView(child: panel) : panel,
        );
        if (!desktop) {
          final height = shortSheet ? availableHeight : availableHeight * .86;
          return themes.wrap(
            Padding(
              padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, 1),
                    end: Offset.zero,
                  ).animate(curve),
                  child: Container(
                    width: double.infinity,
                    constraints: BoxConstraints(maxHeight: height),
                    decoration: BoxDecoration(
                      color: darkSheet
                          ? const Color(0xff1c1c1e)
                          : dark
                          ? Color.alphaBlend(
                              cs.onSurface.withValues(alpha: .055),
                              cs.surface,
                            )
                          : context.appColors.surfaceCard,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(26),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: SafeArea(top: false, child: body),
                  ),
                ),
              ),
            ),
          );
        }
        final radius = BorderRadius.circular(14);
        return themes.wrap(
          CustomSingleChildLayout(
            delegate: _PickerPosition(rect, width, Directionality.of(context)),
            child: FadeTransition(
              opacity: curve,
              child: ScaleTransition(
                scale: Tween(begin: .98, end: 1.0).animate(curve),
                alignment: Alignment.bottomCenter,
                child: AnimatedBuilder(
                  animation: curve,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(0, (1 - curve.value) * 6),
                    child: child,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .16),
                          blurRadius: 48,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: radius,
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: context.appColors.surfaceCard.withValues(
                              alpha: .78,
                            ),
                            borderRadius: radius,
                            border: Border.all(
                              color: cs.onSurface.withValues(
                                alpha: dark ? .08 : .12,
                              ),
                              width: .7,
                            ),
                          ),
                          child: body,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (_, _, _, child) => child,
    ),
  );
}

class _PickerPosition extends SingleChildLayoutDelegate {
  const _PickerPosition(this.anchor, this.width, this.direction);
  final Rect anchor;
  final double width;
  final TextDirection direction;
  bool _above(Size size) => anchor.top >= size.height - anchor.bottom;
  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final size = constraints.biggest;
    final available = (_above(size) ? anchor.top : size.height - anchor.bottom)
        .clamp(0.0, size.height);
    return BoxConstraints.tightFor(
      width: math.min(width, math.max(0, size.width - 16)),
    ).copyWith(maxHeight: math.max(0, available - 16));
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final left = direction == TextDirection.ltr
        ? anchor.left
        : anchor.right - childSize.width;
    return Offset(
      left.clamp(8.0, math.max(8.0, size.width - childSize.width - 8)),
      (_above(size) ? anchor.top - 8 - childSize.height : anchor.bottom + 8)
          .clamp(8.0, math.max(8.0, size.height - childSize.height - 8)),
    );
  }

  @override
  bool shouldRelayout(_PickerPosition old) =>
      old.anchor != anchor || old.width != width || old.direction != direction;
}

Future<T?> showCreationDialog<T>(
  BuildContext context, {
  required Widget child,
  double maxWidth = 420,
}) {
  final duration = handoffDuration(context, 220);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: .32),
    transitionDuration: duration,
    pageBuilder: (ctx, _, _) {
      final cs = Theme.of(ctx).colorScheme;
      final radius = BorderRadius.circular(18);
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxWidth,
                maxHeight: MediaQuery.sizeOf(ctx).height * .86,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: ctx.appColors.surfaceCard,
                  borderRadius: radius,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .24),
                      offset: const Offset(0, 24),
                      blurRadius: 64,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: radius,
                  child: Material(
                    type: MaterialType.transparency,
                    textStyle: Theme.of(ctx).textTheme.bodyMedium!.copyWith(
                      color: cs.onSurface,
                      letterSpacing: 0,
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (_, animation, _, child) {
      final curve = animation.drive(CurveTween(curve: handoffCurve));
      return FadeTransition(
        opacity: curve,
        child: ScaleTransition(
          scale: Tween(begin: .98, end: 1.0).animate(curve),
          child: child,
        ),
      );
    },
  );
}

Future<void> showCreationActions(
  BuildContext context, {
  String? title,
  required List<ActionSheetItem> items,
  bool darkSheet = false,
}) async {
  final selected = await showCreationPicker<ActionSheetItem>(
    context,
    desktop: false,
    title: title ?? '',
    darkSheet: darkSheet,
    builder: (sheet) {
      final cs = darkSheet
          ? const ColorScheme.dark()
          : Theme.of(sheet).colorScheme;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final item in items) ...[
            if (item.startsGroup) const SizedBox(height: 9),
            if (item.groupLabel case final label?)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            Semantics(
              selected: item.checked,
              button: true,
              child: IosCardPress(
                key: item.key,
                focusable: true,
                onTap: () => Navigator.of(sheet).pop(item),
                baseColor: Colors.transparent,
                pressedBlendStrength: .055,
                borderRadius: BorderRadius.circular(12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 2,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 42),
                  child: Row(
                    children: [
                      Icon(
                        item.icon,
                        size: 18,
                        color: item.destructive
                            ? cs.error
                            : cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item.label,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: item.checked
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: item.destructive
                                    ? cs.error
                                    : cs.onSurface,
                              ),
                            ),
                            if (item.subtitle case final subtitle?) ...[
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (item.checked)
                        Icon(Lucide.Check, size: 17, color: cs.primary),
                    ],
                  ),
                ),
              ),
            ),
            if (!identical(item, items.last)) const SizedBox(height: 3),
          ],
        ],
      );
    },
  );
  if (context.mounted) selected?.onTap();
}
