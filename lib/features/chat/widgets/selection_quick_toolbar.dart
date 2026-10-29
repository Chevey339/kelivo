import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../l10n/app_localizations.dart';

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
    final cs = Theme.of(context).colorScheme;
    final buttonStyle = TextButton.styleFrom(
      foregroundColor: cs.onSurface,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      minimumSize: const Size(0, 32),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    );
    return Material(
      elevation: 6,
      color: cs.surface,
      borderRadius: BorderRadius.circular(9),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: TextButton(
                onPressed: onQuote,
                style: buttonStyle,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.messageCircleMore, size: 15),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        labels.selectionQuote,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      quoteKeyboardHint,
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              height: 20,
              child: VerticalDivider(width: 9, color: cs.outlineVariant),
            ),
            Flexible(
              child: TextButton.icon(
                onPressed: onTranslate,
                style: buttonStyle,
                icon: const Icon(LucideIcons.languages, size: 15),
                label: Text(
                  labels.selectionTranslate,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
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
    child: Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(10),
      color: Theme.of(context).colorScheme.surface,
      child: SizedBox(
        width: 230,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var group = 0; group < groups.length; group++) ...[
                if (group != 0) const Divider(height: 9),
                for (final item in groups[group])
                  TextButton(
                    onPressed: item.onPressed,
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: AlignmentDirectional.centerStart,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            AdaptiveTextSelectionToolbar.getButtonLabel(
                              context,
                              item,
                            ),
                          ),
                        ),
                        if (item.label ==
                            AppLocalizations.of(context)!.selectionQuote)
                          Text(
                            quoteKeyboardHint,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
