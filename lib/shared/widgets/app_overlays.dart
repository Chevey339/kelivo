import 'package:flutter/material.dart';

import 'snackbar.dart';
import 'tts_floating_player.dart';

class AppOverlays extends StatelessWidget {
  const AppOverlays({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Overlay.wrap(
      child: Stack(
        children: [
          AppSnackBarOverlay(child: child),
          const Material(
            type: MaterialType.transparency,
            child: TtsFloatingPlayer(),
          ),
        ],
      ),
    );
  }
}
