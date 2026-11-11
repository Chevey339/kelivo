import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_font_weights.dart';

/// A text action with color-only feedback and a full-sized touch target.
class IosTextButton extends StatefulWidget {
  const IosTextButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
    this.fontSize = 14,
    this.padding = const EdgeInsets.symmetric(horizontal: 10),
    this.mainAxisAlignment = MainAxisAlignment.center,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;
  final double fontSize;
  final EdgeInsets padding;
  final MainAxisAlignment mainAxisAlignment;

  @override
  State<IosTextButton> createState() => _IosTextButtonState();
}

class _IosTextButtonState extends State<IosTextButton> {
  bool _focused = false;
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = widget.onPressed != null;
    final base = widget.color ?? cs.primary;
    final foreground = base.withValues(
      alpha:
          base.a *
          (!enabled
              ? .4
              : _pressed
              ? .55
              : 1),
    );
    return FocusableActionDetector(
      enabled: enabled,
      mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onPressed?.call();
            return null;
          },
        ),
      },
      child: Semantics(
        button: true,
        enabled: enabled,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          onTapDown: enabled ? (_) => _setPressed(true) : null,
          onTapUp: enabled ? (_) => _setPressed(false) : null,
          onTapCancel: () => _setPressed(false),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
            child: Padding(
              padding: widget.padding,
              child: TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: foreground),
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 120),
                builder: (context, color, _) => Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: widget.mainAxisAlignment,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, size: 17, color: color),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        widget.label,
                        textAlign: switch (widget.mainAxisAlignment) {
                          MainAxisAlignment.start => TextAlign.start,
                          MainAxisAlignment.end => TextAlign.end,
                          _ => TextAlign.center,
                        },
                        style: TextStyle(
                          color: color,
                          decoration: _focused
                              ? TextDecoration.underline
                              : null,
                          decorationColor: color,
                          fontSize: widget.fontSize,
                          fontWeight: AppFontWeights.medium,
                        ),
                      ),
                    ),
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
