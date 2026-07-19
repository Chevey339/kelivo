import 'package:flutter/material.dart';
import '../../icons/lucide_adapter.dart';
import 'ios_tactile.dart';

class VersionSwitcher extends StatelessWidget {
  const VersionSwitcher({
    super.key,
    required this.index,
    required this.total,
    this.onPrev,
    this.onNext,
    this.buttonSize = 28,
    this.iconSize = 16,
    this.fontSize = 12,
    this.fontWeight,
  });

  final int index;
  final int total;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final double buttonSize;
  final double iconSize;
  final double fontSize;
  final FontWeight? fontWeight;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: buttonSize,
          height: buttonSize,
          child: Center(
            child: IosIconButton(
              icon: Lucide.ChevronLeft,
              size: iconSize,
              enabled: onPrev != null,
              color: cs.onSurface,
              onTap: onPrev,
            ),
          ),
        ),
        SizedBox(
          width: buttonSize,
          height: buttonSize,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${index + 1}/$total',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: fontWeight,
                  color: cs.onSurface.withValues(alpha: 0.7),
                ),
                maxLines: 1,
                softWrap: false,
              ),
            ),
          ),
        ),
        SizedBox(
          width: buttonSize,
          height: buttonSize,
          child: Center(
            child: IosIconButton(
              icon: Lucide.ChevronRight,
              size: iconSize,
              enabled: onNext != null,
              color: cs.onSurface,
              onTap: onNext,
            ),
          ),
        ),
      ],
    );
  }
}
