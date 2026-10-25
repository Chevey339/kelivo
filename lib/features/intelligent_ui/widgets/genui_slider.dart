import '../text/ui_number.dart';
import '../runtime/ui_numeric_step.dart';
import 'genui_control_region.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_form_validation.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_resolved_node.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'genui_field_frame.dart';
import 'genui_interactions.dart';
import 'genui_localizations.dart';
import 'genui_theme.dart';

class GenUiSlider extends StatefulWidget {
  const GenUiSlider({
    super.key,
    required this.id,
    required this.node,
    required this.token,
  });
  final String id;
  final UiResolvedNode node;
  final UiRuntimeToken token;
  @override
  State<GenUiSlider> createState() => _GenUiSliderState();
}

class _GenUiSliderState extends State<GenUiSlider> {
  final _focus = FocusNode();
  GenUiInteractions? _scope;
  VoidCallback? _unsubscribe, _unregister;
  bool _focused = false;
  Map<String, Object?> get _props =>
      _scope?.controller.surface.nodes[widget.id]?.properties ??
      widget.node.properties;
  double get _min => (_props['min'] as num).toDouble();
  double get _max => (_props['max'] as num).toDouble();
  double get _value => (_props['bind'] as num).toDouble();
  double get _step => (_props['step'] as num).toDouble();
  bool get _enabled =>
      _scope!.controller.surface.accepts(widget.token) &&
      _scope!.controller.tree.enabled[widget.id] == true;
  bool get _interactive => _enabled && !_scope!.readOnly && _min < _max;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = GenUiInteractions.of(context);
    if (scope.controller != _scope?.controller ||
        scope.registrationOwner != _scope?.registrationOwner) {
      _unsubscribe?.call();
      _unregister?.call();
      _unsubscribe = scope.controller.listen(widget.id, () {
        if (mounted) setState(() {});
      });
      _unregister = scope.registerFocus(widget.id, _focus, context);
    }
    _scope = scope;
  }

  @override
  void dispose() {
    _unsubscribe?.call();
    _unregister?.call();
    _focus.dispose();
    super.dispose();
  }

  double _snapped(double value) {
    if (value <= _min) return _min;
    if (value >= _max) return _max;
    final steps = (value - _min) / _step;
    if (!steps.isFinite) return value;
    final snapped = uiNumericStep(_min, _step, steps.roundToDouble());
    return snapped.isFinite ? snapped.clamp(_min, _max) : value;
  }

  void _set(double value, {bool flush = true}) {
    if (!_interactive) return;
    _focus.requestFocus();
    _scope!.controller.setValue(
      widget.id,
      _snapped(value),
      token: widget.token,
      flush: flush,
    );
  }

  void _point(double dx, double width, bool rtl) {
    if (width <= 22) return;
    var ratio = ((dx - 11) / (width - 22)).clamp(0.0, 1.0);
    if (rtl) ratio = 1 - ratio;
    // Same-sign endpoints use their delta to avoid cancellation on narrow
    // ranges; opposite signs use weights to avoid overflowing max - min.
    _set(
      ratio == 0
          ? _min
          : ratio == 1
          ? _max
          : (_min >= 0 && _max >= 0) || (_min <= 0 && _max <= 0)
          ? _min + (_max - _min) * ratio
          : (1 - ratio) * _min + ratio * _max,
      flush: false,
    );
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (!_interactive || event is KeyUpEvent) return KeyEventResult.ignored;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final key = event.logicalKey;
    final next = switch (key) {
      LogicalKeyboardKey.arrowLeft => _value + (rtl ? _step : -_step),
      LogicalKeyboardKey.arrowRight => _value + (rtl ? -_step : _step),
      LogicalKeyboardKey.pageUp => _value + (_max / 10 - _min / 10),
      LogicalKeyboardKey.pageDown => _value - (_max / 10 - _min / 10),
      LogicalKeyboardKey.home => _min,
      LogicalKeyboardKey.end => _max,
      _ => null,
    };
    if (next == null) return KeyEventResult.ignored;
    _set(next);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = GenUiTheme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final label = _props['label'] as String;
    final unit = _props['unit'] as String?;
    String format(double n) =>
        '${genUiNumber(n, digits: (_props['digits'] as num?)?.toInt())}${unit == null || unit.isEmpty ? '' : ' $unit'}';
    final range = l10n.genuiNumberRange(genUiNumber(_min), genUiNumber(_max));
    final issue =
        _scope!.controller.issue(widget.id) ??
        validateUiField(widget.node, _scope!.controller.surface.parsed.program);
    final error = issue == null ? null : genUiFieldIssueMessage(l10n, issue);
    final span = _max - _min;
    final fraction = _max == _min
        ? 0.0
        : (span.isFinite
                  ? (_value - _min) / span
                  : (_value / 2 - _min / 2) / (_max / 2 - _min / 2))
              .clamp(0.0, 1.0);
    final intervals = span / _step;
    final tickCount = intervals.isFinite && intervals >= 1 && intervals <= 20
        ? intervals.floor()
        : 0;
    return GenUiFieldFrame(
      label: '',
      error: error,
      child: Focus(
        focusNode: _focus,
        canRequestFocus: _enabled && !_scope!.readOnly,
        onKeyEvent: _key,
        onFocusChange: (value) {
          if (value) {
            _scope!.controller.surface.noteInteraction(token: widget.token);
          }
          setState(() => _focused = value);
        },
        child: Semantics(
          slider: true,
          label: label,
          value: format(_value),
          hint: [range, if (error != null) error].join('. '),
          enabled: _interactive,
          increasedValue: _interactive && _value < _max
              ? format(_snapped(_value + _step))
              : null,
          decreasedValue: _interactive && _value > _min
              ? format(_snapped(_value - _step))
              : null,
          onIncrease: _interactive && _value < _max
              ? () => _set(_value + _step)
              : null,
          onDecrease: _interactive && _value > _min
              ? () => _set(_value - _step)
              : null,
          child: ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: theme.xs,
                  children: [
                    Text(label, style: theme.fieldLabel),
                    Text(
                      format(_value),
                      textDirection: TextDirection.ltr,
                      style: theme.header.copyWith(
                        color: _enabled ? theme.ink : theme.disabledInk,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                GenUiControlRegion(
                  child: LayoutBuilder(
                    builder: (context, constraints) => RawGestureDetector(
                      behavior: HitTestBehavior.opaque,
                      excludeFromSemantics: true,
                      gestures: _interactive
                          ? {
                              TapGestureRecognizer:
                                  GestureRecognizerFactoryWithHandlers<
                                    TapGestureRecognizer
                                  >(
                                    () => TapGestureRecognizer(),
                                    (instance) => instance.onTapUp = (d) {
                                      _point(
                                        d.localPosition.dx,
                                        constraints.maxWidth,
                                        rtl,
                                      );
                                      _scope!.controller.surface.flushQuietly();
                                    },
                                  ),
                              HorizontalDragGestureRecognizer:
                                  GestureRecognizerFactoryWithHandlers<
                                    HorizontalDragGestureRecognizer
                                  >(() => HorizontalDragGestureRecognizer(), (
                                    instance,
                                  ) {
                                    instance.onlyAcceptDragOnThreshold = true;
                                    instance.onEnd = (_) => _scope!
                                        .controller
                                        .surface
                                        .flushQuietly();
                                    instance.onCancel = () => _scope!
                                        .controller
                                        .surface
                                        .flushQuietly();
                                    instance.onStart = (d) => _point(
                                      d.localPosition.dx,
                                      constraints.maxWidth,
                                      rtl,
                                    );
                                    instance.onUpdate = (d) => _point(
                                      d.localPosition.dx,
                                      constraints.maxWidth,
                                      rtl,
                                    );
                                  }),
                            }
                          : {},
                      child: CustomPaint(
                        painter: _SliderPainter(
                          theme,
                          fraction: fraction,
                          rtl: rtl,
                          enabled: _enabled,
                          focused: _focused,
                          tickCount: tickCount,
                          tickFraction: span > 0 ? _step / span : 0,
                        ),
                        child: const SizedBox(
                          height: 44,
                          width: double.infinity,
                        ),
                      ),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      genUiNumber(_min),
                      textDirection: TextDirection.ltr,
                      style: theme.caption,
                    ),
                    Text(
                      genUiNumber(_max),
                      textDirection: TextDirection.ltr,
                      style: theme.caption,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SliderPainter extends CustomPainter {
  const _SliderPainter(
    this.theme, {
    required this.fraction,
    required this.rtl,
    required this.enabled,
    required this.focused,
    required this.tickCount,
    required this.tickFraction,
  });
  final GenUiTheme theme;
  final double fraction, tickFraction;
  final bool rtl, enabled, focused;
  final int tickCount;
  @override
  void paint(Canvas canvas, Size size) {
    final width = math.max(0.0, size.width - 22);
    double x(double ratio) => 11 + width * (rtl ? 1 - ratio : ratio);
    final y = size.height / 2;
    final track = Paint()
      ..color = theme.fill
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(11, y), Offset(size.width - 11, y), track);
    track.color = enabled ? theme.primary : theme.disabledInk;
    canvas.drawLine(Offset(x(0), y), Offset(x(fraction), y), track);
    for (var i = 0; i <= tickCount && tickCount > 0; i++) {
      canvas.drawCircle(
        Offset(x(i * tickFraction), y),
        2,
        Paint()..color = theme.hairlineStrong,
      );
    }
    final center = Offset(x(fraction), y);
    for (final shadow in theme.softShadow) {
      canvas.drawCircle(
        center + shadow.offset,
        11 + shadow.spreadRadius,
        shadow.toPaint(),
      );
    }
    canvas.drawCircle(center, 11, Paint()..color = theme.sliderThumb);
    canvas.drawCircle(
      center,
      11,
      Paint()
        ..color = focused ? theme.primary : theme.hairline
        ..style = PaintingStyle.stroke
        ..strokeWidth = focused ? 2 : 1,
    );
  }

  @override
  bool shouldRepaint(_SliderPainter oldDelegate) =>
      oldDelegate.theme != theme ||
      oldDelegate.fraction != fraction ||
      oldDelegate.rtl != rtl ||
      oldDelegate.enabled != enabled ||
      oldDelegate.focused != focused ||
      oldDelegate.tickCount != tickCount ||
      oldDelegate.tickFraction != tickFraction;
}
