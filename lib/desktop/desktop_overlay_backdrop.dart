import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../features/browser/browser_panel_controller.dart';

/// macOS splits Flutter overlays above native WebViews into separate backing
/// stores. Their BackdropFilters cannot reliably sample the earlier scene.
/// Use an opaque theme surface while the browser pane is open, without adding
/// native material views, screenshots, or another blur pass.
class DesktopOverlayBackdrop extends StatelessWidget {
  const DesktopOverlayBackdrop({
    super.key,
    required this.sigma,
    required this.child,
  });

  final double sigma;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final filter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma);
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) {
      return BackdropFilter(filter: filter, child: child);
    }
    return ListenableBuilder(
      listenable: BrowserPanelController.instance,
      child: child,
      builder: (context, content) {
        final opaque = BrowserPanelController.instance.isOpen;
        return BackdropFilter(
          enabled: !opaque,
          filter: filter,
          child: ColoredBox(
            color: opaque
                ? Theme.of(context).colorScheme.surface
                : Colors.transparent,
            // Keep menu/input state at the same element path on pane toggles.
            child: content!,
          ),
        );
      },
    );
  }
}
