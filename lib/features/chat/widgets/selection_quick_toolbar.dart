import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../theme/app_font_weights.dart';
import '../../../theme/app_semantic_colors.dart';

String get quoteKeyboardHint =>
    defaultTargetPlatform == TargetPlatform.macOS ? '⌘L' : 'Ctrl+L';

class SelectionQuickToolbar extends StatelessWidget {
  const SelectionQuickToolbar({
    super.key,
    required this.onQuote,
    required this.onTranslate,
  });
  final VoidCallback onQuote, onTranslate;
  @override
  Widget build(BuildContext context) {
    final labels = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final radius = BorderRadius.circular(8);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? context.appColors.surfaceFill
            : context.overlaySurface,
        borderRadius: radius,
        border: Border.all(
          color: context.appColors.hairlineStrong.withValues(alpha: .16),
        ),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: .12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: _SelectionAction(
                  onTap: onQuote,
                  label: labels.selectionQuote,
                  shortcut: quoteKeyboardHint,
                ),
              ),
              Container(
                width: 1,
                height: 16,
                color: context.appColors.hairlineStrong.withValues(alpha: .16),
              ),
              Flexible(
                child: _SelectionAction(
                  onTap: onTranslate,
                  label: labels.selectionTranslate,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionAction extends StatelessWidget {
  const _SelectionAction({
    required this.label,
    required this.onTap,
    this.shortcut,
  });
  final String label;
  final VoidCallback onTap;
  final String? shortcut;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      child: IosCardPress(
        focusable: true,
        haptics: false,
        onTap: onTap,
        mouseCursor: SystemMouseCursors.basic,
        baseColor: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.2,
                  fontWeight: AppFontWeights.medium,
                  color: cs.onSurface,
                ),
              ),
            ),
            if (shortcut != null) ...[
              const SizedBox(width: 8),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: .06),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 3,
                    vertical: 1,
                  ),
                  child: Text(
                    shortcut!,
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.2,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SelectionToolbarPositionDelegate extends SingleChildLayoutDelegate {
  const SelectionToolbarPositionDelegate({
    required this.anchor,
    required this.viewport,
  });
  final Rect anchor, viewport;
  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        maxWidth: math.max(0, viewport.width - 16),
        maxHeight: viewport.height,
      );
  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final above = anchor.top - childSize.height - 8;
    final top = above >= viewport.top + 8 ? above : anchor.bottom + 8;
    return Offset(
      anchor.left.clamp(
        viewport.left + 8,
        math.max(viewport.left + 8, viewport.right - childSize.width - 8),
      ),
      top.clamp(
        viewport.top + 8,
        math.max(viewport.top + 8, viewport.bottom - childSize.height - 8),
      ),
    );
  }

  @override
  bool shouldRelayout(SelectionToolbarPositionDelegate oldDelegate) =>
      anchor != oldDelegate.anchor || viewport != oldDelegate.viewport;
}
