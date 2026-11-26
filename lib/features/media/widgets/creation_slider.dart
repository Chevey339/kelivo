import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A full-height pointer/keyboard target for the small track used in Creation.
class CreationSlider extends StatefulWidget {
  const CreationSlider({
    super.key,
    required this.value,
    required this.max,
    required this.onChanged,
    required this.label,
    this.min = 0,
    this.divisions,
    this.thumb = true,
    this.activeColor,
    this.trackColor,
    this.formatValue,
  });
  final double value, min, max;
  final int? divisions;
  final bool thumb;
  final ValueChanged<double>? onChanged;
  final Color? activeColor, trackColor;
  final String label;
  final String Function(double)? formatValue;
  @override
  State<CreationSlider> createState() => _CreationSliderState();
}

class _CreationSliderState extends State<CreationSlider> {
  final _node = FocusNode();
  bool _focus = false;
  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = widget.activeColor ?? cs.primary;
    final range = widget.max - widget.min;
    final enabled = widget.onChanged != null && range > 0;
    final unit = range > 0
        ? ((widget.value - widget.min) / range).clamp(0.0, 1.0)
        : 0.0;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final steps = widget.divisions;
    void change(double fraction) {
      double next = fraction.clamp(0.0, 1.0);
      if (steps != null && steps > 0) next = (next * steps).round() / steps;
      widget.onChanged?.call(widget.min + next * range);
    }

    final step = steps != null && steps > 0 ? 1 / steps : .05;
    String spoken(double fraction) =>
        widget.formatValue?.call(widget.min + fraction * range) ??
        '${(fraction * 100).round()}%';
    return Semantics(
      label: widget.label,
      slider: true,
      enabled: enabled,
      value: spoken(unit),
      increasedValue: enabled && unit < 1
          ? spoken((unit + step).clamp(0, 1))
          : null,
      decreasedValue: enabled && unit > 0
          ? spoken((unit - step).clamp(0, 1))
          : null,
      onIncrease: enabled && unit < 1 ? () => change(unit + step) : null,
      onDecrease: enabled && unit > 0 ? () => change(unit - step) : null,
      child: Focus(
        focusNode: _node,
        onFocusChange: (v) => setState(() => _focus = v),
        canRequestFocus: enabled,
        onKeyEvent: (_, event) {
          if (!enabled || event is KeyUpEvent) return KeyEventResult.ignored;
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.home) {
            change(0);
          } else if (key == LogicalKeyboardKey.end) {
            change(1);
          } else if (key == LogicalKeyboardKey.arrowLeft ||
              key == LogicalKeyboardKey.arrowRight) {
            change(
              unit +
                  ((key == LogicalKeyboardKey.arrowRight) != rtl
                      ? step
                      : -step),
            );
          } else if (key == LogicalKeyboardKey.arrowUp ||
              key == LogicalKeyboardKey.arrowDown) {
            change(unit + (key == LogicalKeyboardKey.arrowUp ? step : -step));
          } else {
            return KeyEventResult.ignored;
          }
          return KeyEventResult.handled;
        },
        child: LayoutBuilder(
          builder: (context, box) {
            final inset = widget.thumb ? 7.0 : 0.0;
            final width = (box.maxWidth - 2 * inset).clamp(
              0.0,
              double.infinity,
            );
            void at(Offset local) {
              if (width <= 0) return;
              _node.requestFocus();
              final f = (local.dx - inset) / width;
              change(rtl ? 1 - f : f);
            }

            return MouseRegion(
              cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                excludeFromSemantics: true,
                onTapUp: enabled ? (d) => at(d.localPosition) : null,
                onHorizontalDragStart: enabled
                    ? (d) => at(d.localPosition)
                    : null,
                onHorizontalDragUpdate: enabled
                    ? (d) => at(d.localPosition)
                    : null,
                child: SizedBox(
                  height: 32,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        left: inset,
                        right: inset,
                        child: Container(
                          height: _focus ? 5 : 4,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            color:
                                widget.trackColor ??
                                cs.onSurface.withValues(alpha: .14),
                          ),
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: FractionallySizedBox(
                              widthFactor: unit,
                              heightFactor: 1,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (widget.thumb)
                        PositionedDirectional(
                          start: width * unit,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              boxShadow: const [
                                BoxShadow(color: Colors.black12, blurRadius: 3),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
