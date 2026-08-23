import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:reel_text/reel_text.dart';

import '../../core/services/haptics.dart';
import '../../icons/lucide_adapter.dart';
import '../../theme/app_font_weights.dart';
import '../../theme/app_semantic_colors.dart';
import '../animations/widgets.dart';
import 'animated_progress_bar.dart';
import 'ios_tile_button.dart';
import 'throttled_progress_label.dart';

enum TaskProgressOutcome { running, success, failure }

class TaskProgressDialogCard extends StatelessWidget {
  const TaskProgressDialogCard({
    super.key,
    required this.title,
    required this.phaseLabel,
    required this.fraction,
    this.subtitle,
    this.phaseIcon,
    this.cancellable = true,
    this.onCancel,
    this.onAcknowledge,
    this.cancelLabel = 'Cancel',
    this.acknowledgeLabel = 'OK',
    this.outcome = TaskProgressOutcome.running,
  });

  final String title;
  final String phaseLabel;
  final double? fraction;
  final String? subtitle;
  final IconData? phaseIcon;
  final bool cancellable;
  final VoidCallback? onCancel;
  final VoidCallback? onAcknowledge;
  final String cancelLabel;
  final String acknowledgeLabel;
  final TaskProgressOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final showCancel =
        outcome == TaskProgressOutcome.running && cancellable && onCancel != null;
    final showAck = outcome == TaskProgressOutcome.failure;
    final resolvedFraction = switch (outcome) {
      TaskProgressOutcome.success => 1.0,
      TaskProgressOutcome.failure => fraction,
      TaskProgressOutcome.running => fraction,
    };
    final leadingIcon = switch (outcome) {
      TaskProgressOutcome.success => Lucide.Check,
      TaskProgressOutcome.failure => Lucide.TriangleAlert,
      TaskProgressOutcome.running => phaseIcon,
    };

    return PopScope(
      key: const Key('task_progress_pop_scope'),
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || outcome != TaskProgressOutcome.running) return;
        if (cancellable) {
          onCancel?.call();
        } else {
          Haptics.light();
        }
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (leadingIcon != null) ...[
                  Icon(
                    leadingIcon,
                    size: 18,
                    color: switch (outcome) {
                      TaskProgressOutcome.success =>
                        context.appColors.success,
                      TaskProgressOutcome.failure => cs.error,
                      TaskProgressOutcome.running => cs.onSurface,
                    },
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: AppFontWeights.emphasis,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            AnimatedProgressBar(fraction: resolvedFraction, height: 6),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: AnimatedTextSwap(
                    text: phaseLabel,
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                if (resolvedFraction == null)
                  const CupertinoActivityIndicator(radius: 8)
                else
                  ThrottledProgressLabel(
                    text: '${((resolvedFraction.clamp(0.0, 1.0)) * 100).round()}%',
                    forceImmediate: resolvedFraction >= 1,
                    builder: (context, displayText) {
                      return ReelText(
                        displayText,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: AppFontWeights.emphasis,
                          color: cs.primary,
                        ),
                        options: const ReelTextOptions(
                          direction: ReelTextDirection.up,
                          duration: Duration(milliseconds: 320),
                        ),
                      );
                    },
                  ),
              ],
            ),
            AnimatedSize(
              duration: kAnimFast,
              curve: Curves.easeOutCubic,
              child: (subtitle == null || subtitle!.isEmpty)
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
            ),
            AnimatedSize(
              duration: kAnim,
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                duration: kAnim,
                curve: Curves.easeOutCubic,
                opacity: (showCancel || showAck) ? 1 : 0,
                child: (showCancel || showAck)
                    ? Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: SizedBox(
                          width: double.infinity,
                          child: IosTileButton(
                            icon: showAck ? Lucide.Check : Lucide.X,
                            label: showAck ? acknowledgeLabel : cancelLabel,
                            onTap: showAck
                                ? () => onAcknowledge?.call()
                                : () => onCancel?.call(),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
