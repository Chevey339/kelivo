import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/models/assistant.dart';
import '../core/providers/settings_provider.dart';
import '../features/chat/widgets/reasoning_level_sheet.dart';
import 'desktop_glass_popover.dart';

Future<void> showDesktopReasoningLevelPopover(
  BuildContext context, {
  required GlobalKey anchorKey,
  required ProviderConfig config,
  required String modelId,
  Assistant? assistant,
  String? conversationId,
}) async {
  final box = anchorKey.currentContext?.findRenderObject() as RenderBox?;
  if (box == null) return;
  final anchorRect = box.localToGlobal(Offset.zero) & box.size;
  // A route lets nested speed menus and budget dialogs appear above the panel.
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.transparent,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    transitionDuration: const Duration(milliseconds: 180),
    transitionBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
          child: child,
        ),
    pageBuilder: (ctx, _, __) {
      final screen = MediaQuery.sizeOf(ctx);
      final safe = MediaQuery.paddingOf(ctx);
      final width = math.min(
        260.0,
        math.max(0.0, screen.width - safe.horizontal - 16),
      );
      final left = (anchorRect.center.dx - width / 2).clamp(
        safe.left + 8,
        screen.width - safe.right - width - 8,
      );
      final above = anchorRect.top - safe.top - 16;
      final below = screen.height - safe.bottom - anchorRect.bottom - 16;
      final placeAbove = above >= below;
      return Stack(
        children: [
          Positioned(
            left: left,
            width: width,
            bottom: placeAbove ? screen.height - anchorRect.top + 8 : null,
            top: placeAbove ? null : anchorRect.bottom + 8,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: math.max(0.0, placeAbove ? above : below),
              ),
              child: DesktopGlassPanel(
                borderRadius: BorderRadius.circular(16),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 10),
                  child: ReasoningLevelPicker(
                    config: config,
                    modelId: modelId,
                    assistant: assistant,
                    conversationId: conversationId,
                    compact: true,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}
