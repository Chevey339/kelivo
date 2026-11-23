import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../shared/widgets/sliding_segmented_tabs.dart';
import '../../../shared/responsive/screen_type_helper.dart';
import 'creation_controls.dart';

final _activeCreationToast = Expando<VoidCallback>();

void showCreationToast(
  BuildContext context, {
  required String message,
  IconData icon = LucideIcons.info,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  _activeCreationToast[overlay]?.call();
  late final OverlayEntry entry;
  Timer? timer;
  var closed = false;
  void remove() {
    if (closed) return;
    closed = true;
    timer?.cancel();
    entry.remove();
    entry.dispose();
    _activeCreationToast[overlay] = null;
  }

  entry = OverlayEntry(
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      final isMobile = ResponsiveHelper.isMobile(ctx);
      final box = Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: cs.onSurface.withValues(alpha: .90),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: cs.surface),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  message,
                  style: TextStyle(
                    color: cs.surface,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              if (onAction != null && actionLabel != null)
                CreationAction(
                  small: true,
                  foreground: cs.surface,
                  onPressed: () {
                    remove();
                    onAction();
                  },
                  child: Text(actionLabel),
                ),
            ],
          ),
        ),
      );
      final duration = handoffDuration(ctx, 260);
      return Positioned(
        top: isMobile ? MediaQuery.paddingOf(ctx).top + 60 : 58,
        left: 16,
        right: 16,
        child: Center(
          child: duration == Duration.zero
              ? box
              : box
                    .animate()
                    .fadeIn(duration: duration, curve: handoffCurve)
                    .moveY(
                      begin: -8,
                      end: 0,
                      duration: duration,
                      curve: handoffCurve,
                    ),
        ),
      );
    },
  );
  overlay.insert(entry);
  _activeCreationToast[overlay] = remove;
  timer = Timer(Duration(seconds: onAction == null ? 3 : 6), remove);
}
