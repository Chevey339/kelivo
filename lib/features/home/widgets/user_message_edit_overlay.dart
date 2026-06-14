import 'package:flutter/material.dart';

import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../theme/app_font_weights.dart';

class UserMessageEditOverlay extends StatelessWidget {
  const UserMessageEditOverlay({
    super.key,
    required this.visible,
    required this.previewText,
    required this.topInset,
    required this.bottomInset,
    required this.onCancel,
    required this.onSaveOnly,
    required this.onPreviewTap,
  });

  final bool visible;
  final String previewText;
  final double topInset;
  final double bottomInset;
  final VoidCallback onCancel;
  final VoidCallback onSaveOnly;
  final VoidCallback onPreviewTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Positioned(
      left: 0,
      top: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: Duration(milliseconds: visible ? 250 : 200),
          curve: Curves.easeOutCubic,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onCancel,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: isDark ? 0.78 : 0.82),
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.0, 0.85, 1.0],
                          colors: [
                            cs.surface.withValues(alpha: isDark ? 0.86 : 0.90),
                            cs.surface.withValues(alpha: isDark ? 0.80 : 0.84),
                            cs.surface.withValues(alpha: isDark ? 0.78 : 0.82),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: topInset,
                right: 0,
                bottom: bottomInset,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const actionTop = 10.0;
                    const actionRight = 18.0;
                    const actionHeight = 36.0;
                    const actionPreviewGap = 12.0;
                    const previewLeft = 69.0;
                    const previewRight = 24.0;
                    const previewBottom = 14.0;
                    const previewVerticalPadding = 20.0;
                    const previewLineHeight = 21.75;
                    const minPreviewHeight = 44.0;

                    final availablePreviewHeight =
                        constraints.maxHeight -
                        actionTop -
                        actionHeight -
                        actionPreviewGap -
                        previewBottom;
                    var previewMaxLines =
                        ((availablePreviewHeight - previewVerticalPadding) /
                                previewLineHeight)
                            .floor();
                    if (previewMaxLines < 1) {
                      previewMaxLines = 1;
                    } else if (previewMaxLines > 6) {
                      previewMaxLines = 6;
                    }
                    final showPreview =
                        previewText.trim().isNotEmpty &&
                        availablePreviewHeight >= minPreviewHeight;

                    return Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        Positioned(
                          top: actionTop,
                          right: actionRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IosCardPress(
                                onTap: onSaveOnly,
                                borderRadius: BorderRadius.circular(18),
                                baseColor: cs.primary.withValues(
                                  alpha: isDark ? 0.18 : 0.12,
                                ),
                                pressedBlendStrength: isDark ? 0.18 : 0.12,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 13,
                                  vertical: 8,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Lucide.Check,
                                      size: 16,
                                      color: cs.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      l10n.userMessageEditSaveOnly,
                                      style: TextStyle(
                                        color: cs.primary,
                                        fontSize: 13,
                                        fontWeight: AppFontWeights.semibold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              IosCardPress(
                                onTap: onCancel,
                                borderRadius: BorderRadius.circular(18),
                                baseColor: cs.surface.withValues(alpha: 0.56),
                                pressedBlendStrength: isDark ? 0.18 : 0.10,
                                padding: const EdgeInsets.all(8),
                                child: Icon(
                                  Lucide.X,
                                  size: 18,
                                  color: cs.onSurface.withValues(alpha: 0.78),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (showPreview)
                          Positioned(
                            left: previewLeft,
                            right: previewRight,
                            bottom: previewBottom,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: _PreviewBubble(
                                text: previewText,
                                maxLines: previewMaxLines,
                                onTap: onPreviewTap,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewBubble extends StatelessWidget {
  const _PreviewBubble({
    required this.text,
    required this.maxLines,
    required this.onTap,
  });

  final String text;
  final int maxLines;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark
        ? cs.primary.withValues(alpha: 0.20)
        : cs.primary.withValues(alpha: 0.10);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.76,
      ),
      child: IosCardPress(
        onTap: onTap,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(6),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
        baseColor: background,
        pressedBlendStrength: isDark ? 0.18 : 0.10,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Text(
          text,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 15,
            height: 1.45,
            fontWeight: AppFontWeights.regular,
          ),
        ),
      ),
    );
  }
}
