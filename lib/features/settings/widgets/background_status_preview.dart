import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/models/mobile_background_settings.dart';

/// Native-free preview. Logical-pixel geometry mirrors BackgroundOverlay on
/// Android, including shrinking artwork to fit very small user-defined cards.
class BackgroundStatusPreview extends StatelessWidget {
  const BackgroundStatusPreview({
    super.key,
    required this.title,
    required this.detail,
    this.artwork,
    this.appearance = const BackgroundOverlayAppearance(),
  });

  final String title;
  final String detail;
  final Widget? artwork;
  final BackgroundOverlayAppearance appearance;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final a = BackgroundOverlayAppearance.fromJson(appearance.toJson());
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(a.width, constraints.maxWidth);
        final padding = a.isIconOnly ? 0.0 : math.min(10.0, width / 8);
        final innerWidth = width - padding * 2;
        final innerHeight = a.height - padding * 2;
        final closeWidth = a.showClose ? math.min(32.0, innerWidth * .3) : 0.0;
        final gap = a.hasText ? math.min(9.0, innerWidth * .08) : 0.0;
        final textReserve = a.hasText ? math.min(40.0, innerWidth * .3) : 0.0;
        final badge = math.min(
          a.badgeSize,
          math.min(innerHeight, innerWidth - closeWidth - gap - textReserve),
        );
        final scale = badge / a.badgeSize;
        final textHeight =
            (a.showTitle ? 16.0 : 0.0) +
            (a.showSubtitle ? 28.0 : 0.0) +
            (a.showTime ? 14.0 : 0.0);
        final textScale = textHeight > 0
            ? math.min(1.0, innerHeight / textHeight)
            : 1.0;
        final icon = SizedBox(
          key: const ValueKey('overlayPreviewIcon'),
          width: badge,
          height: badge,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: a.iconSize * scale,
                height: a.iconSize * scale,
                child: ClipOval(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child:
                        artwork ??
                        Icon(LucideIcons.sparkles, color: cs.primary),
                  ),
                ),
              ),
              if (a.showProgress)
                SizedBox(
                  key: const ValueKey('overlayPreviewProgress'),
                  width: a.progressSize * scale,
                  height: a.progressSize * scale,
                  child: CircularProgressIndicator(
                    value: .75,
                    strokeWidth: a.progressStrokeWidth * scale,
                    strokeAlign: -1,
                    strokeCap: StrokeCap.round,
                    color: cs.primary,
                  ),
                ),
            ],
          ),
        );
        Widget line(
          String text,
          String key,
          double height,
          double fontSize, {
          bool bold = false,
          int maxLines = 1,
        }) => SizedBox(
          key: ValueKey(key),
          height: height * textScale,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              text,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: fontSize * textScale,
                height: 1.15,
                fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
                color: bold ? cs.onSurface : cs.onSurfaceVariant,
              ),
            ),
          ),
        );
        return MediaQuery.withNoTextScaling(
          child: SizedBox(
            key: const ValueKey('overlayPreviewFrame'),
            width: width,
            height: a.height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: a.showBackground ? cs.surfaceContainerHigh : null,
                borderRadius: BorderRadius.circular(a.cornerRadius),
                border: a.showBorder
                    ? Border.all(color: cs.outlineVariant)
                    : null,
              ),
              child: Padding(
                padding: EdgeInsets.all(padding),
                child: a.isIconOnly
                    ? Center(child: icon)
                    : Row(
                        children: [
                          icon,
                          SizedBox(width: gap),
                          Expanded(
                            child: ClipRect(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (a.showTitle)
                                    line(
                                      title,
                                      'overlayPreviewTitle',
                                      16,
                                      13,
                                      bold: true,
                                    ),
                                  if (a.showSubtitle)
                                    line(
                                      detail,
                                      'overlayPreviewSubtitle',
                                      28,
                                      11,
                                      maxLines: 2,
                                    ),
                                  if (a.showTime)
                                    line('0:42', 'overlayPreviewTime', 14, 10),
                                ],
                              ),
                            ),
                          ),
                          if (a.showClose)
                            SizedBox(
                              key: const ValueKey('overlayPreviewClose'),
                              width: closeWidth,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Icon(
                                  LucideIcons.x,
                                  size: 18,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

@Preview(name: 'Background card', size: Size(340, 160))
Widget backgroundCapsulePreview() => const MaterialApp(
  home: Scaffold(
    body: Center(
      child: BackgroundStatusPreview(
        title: 'Kelivo task',
        detail: 'Generating reply',
        artwork: Text('🐱', style: TextStyle(fontSize: 32)),
      ),
    ),
  ),
);

@Preview(name: 'Circular background icon', size: Size(180, 160))
Widget backgroundCirclePreview() => const MaterialApp(
  home: Scaffold(
    body: Center(
      child: BackgroundStatusPreview(
        title: 'Kelivo task',
        detail: 'Generating reply',
        appearance: BackgroundOverlayAppearance.circle,
        artwork: Text('🐱', style: TextStyle(fontSize: 32)),
      ),
    ),
  ),
);
