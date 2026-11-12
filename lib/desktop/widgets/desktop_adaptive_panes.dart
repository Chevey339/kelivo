import 'package:flutter/material.dart';

import '../../icons/lucide_adapter.dart';
import '../../shared/widgets/ios_tactile.dart';

/// Keeps both panes mounted when a desktop window switches between a split
/// view and list/detail navigation. Hidden panes cannot receive keyboard focus.
class DesktopAdaptivePanes extends StatelessWidget {
  const DesktopAdaptivePanes({
    super.key,
    required this.sidebar,
    required this.detail,
    required this.showDetail,
    required this.onBack,
    required this.backLabel,
    this.sidebarWidth = 250,
  });

  final Widget sidebar;
  final Widget detail;
  final bool showDetail;
  final VoidCallback onBack;
  final String backLabel;
  final double sidebarWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < sidebarWidth + 360;
      return ClipRect(
        child: Stack(
          children: [
            Positioned(
              top: 0,
              bottom: 0,
              left: 0,
              width: compact ? constraints.maxWidth : sidebarWidth,
              child: ExcludeFocus(
                excluding: compact && showDetail,
                child: Offstage(
                  offstage: compact && showDetail,
                  child: sidebar,
                ),
              ),
            ),
            Positioned.fill(
              left: compact ? 0 : sidebarWidth,
              child: ExcludeFocus(
                excluding: compact && !showDetail,
                child: Offstage(
                  offstage: compact && !showDetail,
                  child: Column(
                    children: [
                      if (compact)
                        SizedBox(
                          height: 40,
                          child: Row(
                            children: [
                              IosIconButton(
                                key: const ValueKey('desktop-pane-back'),
                                icon: Lucide.ChevronLeft,
                                tooltip: MaterialLocalizations.of(
                                  context,
                                ).backButtonTooltip,
                                minSize: 40,
                                onTap: onBack,
                              ),
                              Expanded(
                                child: Text(
                                  backLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Expanded(child: detail),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
