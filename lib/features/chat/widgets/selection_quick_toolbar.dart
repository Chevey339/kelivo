import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../theme/app_font_weights.dart';
import '../../../theme/app_semantic_colors.dart';
import 'selection_panel.dart';

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
    return SelectionPopoverSurface(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: _SelectionAction(
                onTap: onQuote,
                icon: LucideIcons.messageCircleMore,
                label: labels.selectionQuote,
                shortcut: quoteKeyboardHint,
              ),
            ),
            Container(width: 1, height: 16, color: context.appColors.hairline),
            Flexible(
              child: _SelectionAction(
                onTap: onTranslate,
                icon: LucideIcons.languages,
                label: labels.selectionTranslate,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionAction extends StatelessWidget {
  const _SelectionAction({
    required this.label,
    required this.onTap,
    this.icon,
    this.shortcut,
    this.expanded = false,
  });
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final String? shortcut;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Text(
      label,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 13,
        fontWeight: AppFontWeights.medium,
        color: cs.onSurface,
      ),
    );
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: IosCardPress(
        focusable: true,
        haptics: false,
        onTap: onTap,
        baseColor: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Row(
          mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: cs.onSurfaceVariant),
              const SizedBox(width: 8),
            ],
            if (expanded) Expanded(child: text) else Flexible(child: text),
            if (shortcut != null) ...[
              const SizedBox(width: 14),
              Text(
                shortcut!,
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
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

class SelectionDesktopContextMenu extends StatelessWidget {
  const SelectionDesktopContextMenu({
    super.key,
    required this.anchors,
    required this.groups,
  });
  final TextSelectionToolbarAnchors anchors;
  final List<List<ContextMenuButtonItem>> groups;
  @override
  Widget build(BuildContext context) => CustomSingleChildLayout(
    delegate: TextSelectionToolbarLayoutDelegate(
      anchorAbove: anchors.primaryAnchor,
      anchorBelow: anchors.secondaryAnchor ?? anchors.primaryAnchor,
    ),
    child: SelectionPopoverSurface(
      child: SizedBox(
        width: 244,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var group = 0; group < groups.length; group++) ...[
                if (group != 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Divider(
                      height: 1,
                      color: context.appColors.hairline,
                    ),
                  ),
                for (final item in groups[group])
                  _SelectionAction(
                    expanded: true,
                    label: AdaptiveTextSelectionToolbar.getButtonLabel(
                      context,
                      item,
                    ),
                    onTap: item.onPressed,
                    shortcut:
                        item.label ==
                            AppLocalizations.of(context)!.selectionQuote
                        ? quoteKeyboardHint
                        : null,
                  ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
