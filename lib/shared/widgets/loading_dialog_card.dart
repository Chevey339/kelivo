import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';

import '../animations/widgets.dart';

class LoadingDialogCard extends StatelessWidget {
  const LoadingDialogCard({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasLabel = label != null && label!.trim().isNotEmpty;

    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.96, end: 1),
        duration: kAnimSlow,
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          final opacity = ((value - 0.96) / 0.04).clamp(0.0, 1.0).toDouble();
          return Opacity(
            opacity: opacity,
            child: Transform.scale(scale: value, child: child),
          );
        },
        child: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 96, maxWidth: 240),
            child: Container(
              decoration: BoxDecoration(
                color: context.overlaySurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.appColors.hairline),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  hasLabel ? 16 : 18,
                  20,
                  hasLabel ? 16 : 18,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CupertinoActivityIndicator(radius: 16),
                    if (hasLabel) ...[
                      const SizedBox(height: 12),
                      Text(
                        label!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: cs.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
