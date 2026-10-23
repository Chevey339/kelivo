import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../l10n/app_localizations.dart';
import '../widgets/browser_progressive_edge.dart';
import '../widgets/browser_scroll_configuration.dart';
import '../widgets/browser_surface_controls.dart';

/// Mobile management content scrolls beneath a safe-area-aware floating header.
class BrowserManagementPage extends StatelessWidget {
  const BrowserManagementPage({
    super.key,
    required this.title,
    required this.child,
    this.onDone,
    this.showHeader = true,
    this.trailing,
    this.trailingWidth = 48,
  });
  final String title;
  final Widget child;
  final VoidCallback? onDone;
  final bool showHeader;

  /// One trailing control or a shared capsule. Reserve its full width on both
  /// sides so the title stays centered even when Back is only 48 points wide.
  final Widget? trailing;
  final double trailingWidth;

  /// Apply these insets to scroll padding, never to the viewport itself.
  /// Desktop dialogs and independently laid-out pages have no such insets.
  static EdgeInsets contentInsetsOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_ManagementInsets>()
          ?.padding ??
      EdgeInsets.zero;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = theme.colorScheme.surface;
    return BrowserScrollConfiguration(
      child: Theme(
        data: theme.copyWith(
          colorScheme: theme.colorScheme.copyWith(surface: background),
        ),
        child: ClipRect(
          key: const ValueKey('browserManagementViewportClip'),
          child: Scaffold(
            backgroundColor: background,
            body: DefaultTextStyle(
              style: theme.textTheme.bodyMedium!.copyWith(
                color: theme.colorScheme.onSurface,
                decoration: TextDecoration.none,
              ),
              child: !showHeader
                  ? child
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final safe = MediaQuery.paddingOf(context);
                        final horizontal = math.max(safe.left, safe.right) + 16;
                        final style = DefaultTextStyle.of(context).style
                            .copyWith(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            );
                        final actionWidth = trailing == null
                            ? 0.0
                            : trailingWidth;
                        final sideWidth = math.max(48.0, actionWidth) + 8;
                        final titleWidth = math.max(
                          0.0,
                          constraints.maxWidth - horizontal * 2 - sideWidth * 2,
                        );
                        final painter = TextPainter(
                          text: TextSpan(text: title, style: style),
                          textDirection: Directionality.of(context),
                          textScaler: MediaQuery.textScalerOf(context),
                          maxLines: 2,
                          ellipsis: '\u2026',
                        )..layout(maxWidth: math.max(0, titleWidth));
                        // At accessibility sizes, give the title a second row
                        // rather than squeezing it between the actions.
                        final stackedTitle = painter.didExceedMaxLines;
                        if (stackedTitle) {
                          painter.layout(
                            maxWidth: math.max(
                              0,
                              constraints.maxWidth - horizontal * 2,
                            ),
                          );
                        }
                        final titleHeight = painter.height;
                        final headerHeight = stackedTitle
                            ? 56 + titleHeight
                            : math.max(48.0, titleHeight);
                        painter.dispose();
                        final titleWidget = Text(
                          title,
                          key: const ValueKey('browserManagementTitle'),
                          style: style,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        );
                        final back = BrowserSurfaceIconButton(
                          key: const ValueKey('browserManagementBack'),
                          surface: true,
                          label: AppLocalizations.of(context)!.browserBack,
                          icon: Directionality.of(context) == TextDirection.rtl
                              ? LucideIcons.chevronRight
                              : LucideIcons.chevronLeft,
                          size: 48,
                          iconSize: 23,
                          onPressed:
                              onDone ?? () => Navigator.of(context).pop(),
                        );
                        final trailingControl = SizedBox(
                          key: const ValueKey('browserManagementActions'),
                          width: actionWidth,
                          height: 48,
                          child: trailing,
                        );
                        final contentTop = safe.top + headerHeight + 20;
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            Positioned.fill(
                              child: _ManagementInsets(
                                padding: EdgeInsets.fromLTRB(
                                  safe.left,
                                  contentTop,
                                  safe.right,
                                  safe.bottom,
                                ),
                                child: child,
                              ),
                            ),
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              height: math.min(
                                contentTop + 24,
                                constraints.maxHeight / 2,
                              ),
                              child: const BrowserProgressiveEdge(
                                key: ValueKey('browserManagementTopEdge'),
                                top: true,
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              height: math.min(
                                safe.bottom + 44,
                                constraints.maxHeight / 2,
                              ),
                              child: const BrowserProgressiveEdge(
                                key: ValueKey('browserManagementBottomEdge'),
                                top: false,
                              ),
                            ),
                            Positioned(
                              top: safe.top + 8,
                              left: horizontal,
                              right: horizontal,
                              height: headerHeight,
                              child: stackedTitle
                                  ? Column(
                                      children: [
                                        SizedBox(
                                          height: 48,
                                          child: Row(
                                            children: [
                                              back,
                                              const Spacer(),
                                              trailingControl,
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        titleWidget,
                                      ],
                                    )
                                  : Row(
                                      children: [
                                        SizedBox(
                                          width: sideWidth,
                                          child: Align(
                                            alignment: AlignmentDirectional
                                                .centerStart,
                                            child: back,
                                          ),
                                        ),
                                        Expanded(child: titleWidget),
                                        SizedBox(
                                          width: sideWidth,
                                          child: Align(
                                            alignment:
                                                AlignmentDirectional.centerEnd,
                                            child: trailingControl,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ManagementInsets extends InheritedWidget {
  const _ManagementInsets({required this.padding, required super.child});
  final EdgeInsets padding;
  @override
  bool updateShouldNotify(_ManagementInsets oldWidget) =>
      padding != oldWidget.padding;
}
