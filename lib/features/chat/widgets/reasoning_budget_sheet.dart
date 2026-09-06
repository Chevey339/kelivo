import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../icons/reasoning_icons.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/dialogs/reasoning_budget_custom_dialog.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../core/services/haptics.dart';
import 'package:Kelivo/theme/app_font_weights.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';
import '../../../shared/widgets/section_card.dart';

Future<void> showReasoningBudgetSheet(
  BuildContext context, {
  String? modelProvider,
  String? modelId,
  int? initialBudget,
  ValueChanged<int>? onChanged,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.overlaySurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _ReasoningBudgetSheet(
      modelProvider: modelProvider,
      modelId: modelId,
      initialBudget: initialBudget,
      onChanged: onChanged,
    ),
  );
}

class _EffortStop {
  const _EffortStop({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.icon,
  });
  final String title;
  final String subtitle;
  final int value;
  final int icon;
}

class _ReasoningBudgetSheet extends StatefulWidget {
  const _ReasoningBudgetSheet({
    this.modelProvider,
    this.modelId,
    this.initialBudget,
    this.onChanged,
  });
  final String? modelProvider;
  final String? modelId;

  /// Selection to display when opening, without writing it into global
  /// settings first. Lets callers seed the assistant's budget without a
  /// synchronous [SettingsProvider] notify mid route-animation.
  final int? initialBudget;

  /// Fires only when the user actually picks a value inside the sheet.
  final ValueChanged<int>? onChanged;
  @override
  State<_ReasoningBudgetSheet> createState() => _ReasoningBudgetSheetState();
}

class _ReasoningBudgetSheetState extends State<_ReasoningBudgetSheet>
    with SingleTickerProviderStateMixin {
  static const SpringDescription _spring = SpringDescription(
    mass: 1,
    stiffness: 320,
    damping: 28,
  );

  late int _selected;
  late final AnimationController _snap;

  /// Fractional stop index driving the thumb / fill; animated when not dragged.
  double _position = 0;
  bool _dragging = false;
  bool _positionInitialized = false;
  List<_EffortStop> _stops = const [];

  @override
  void initState() {
    super.initState();
    _selected = widget.initialBudget ??
        context.read<SettingsProvider>().thinkingBudget ??
        -1;
    _snap = AnimationController.unbounded(vsync: this)
      ..addListener(() {
        final last = (_stops.length - 1).toDouble();
        setState(() => _position = _snap.value.clamp(0.0, last).toDouble());
      });
  }

  @override
  void dispose() {
    _snap.dispose();
    super.dispose();
  }

  List<_EffortStop> _buildStops(
    AppLocalizations l10n, {
    required bool showXhigh,
    required bool showMax,
  }) {
    return [
      _EffortStop(
        title: l10n.reasoningBudgetSheetOff,
        subtitle: l10n.reasoningBudgetSheetOffSubtitle,
        value: 0,
        icon: ReasoningIcons.offBudget,
      ),
      _EffortStop(
        title: l10n.reasoningBudgetSheetAuto,
        subtitle: l10n.reasoningBudgetSheetAutoSubtitle,
        value: -1,
        icon: ReasoningIcons.autoBudget,
      ),
      _EffortStop(
        title: l10n.reasoningBudgetSliderLow,
        subtitle: l10n.reasoningBudgetSheetLightSubtitle,
        value: 1024,
        icon: ReasoningIcons.lightBudget,
      ),
      _EffortStop(
        title: l10n.reasoningBudgetSliderMedium,
        subtitle: l10n.reasoningBudgetSheetMediumSubtitle,
        value: 16000,
        icon: ReasoningIcons.mediumBudget,
      ),
      _EffortStop(
        title: l10n.reasoningBudgetSliderHigh,
        subtitle: l10n.reasoningBudgetSheetHeavySubtitle,
        value: 32000,
        icon: ReasoningIcons.heavyBudget,
      ),
      if (showXhigh)
        _EffortStop(
          title: l10n.reasoningBudgetSliderXhigh,
          subtitle: l10n.reasoningBudgetSheetXhighSubtitle,
          value: 64000,
          icon: ReasoningIcons.xhighBudget,
        ),
      if (showMax)
        _EffortStop(
          title: l10n.reasoningBudgetSliderMax,
          subtitle: l10n.reasoningBudgetSheetXhighSubtitle,
          value: 128000,
          icon: ReasoningIcons.maxBudget,
        ),
    ];
  }

  int _indexForSelection() {
    for (var i = 0; i < _stops.length; i++) {
      if (_stops[i].value == _selected) return i;
    }
    // Custom value: park the thumb at the numerically closest preset.
    var best = 0;
    var bestDiff = double.infinity;
    for (var i = 0; i < _stops.length; i++) {
      final diff = (_stops[i].value - _selected).abs().toDouble();
      if (diff < bestDiff) {
        best = i;
        bestDiff = diff;
      }
    }
    return best;
  }

  bool get _isCustomSelected => !_stops.any((stop) => stop.value == _selected);

  void _commitIndex(int index) {
    if (index < 0 || index >= _stops.length) return;
    final value = _stops[index].value;
    if (value == _selected) return;
    Haptics.soft();
    setState(() => _selected = value);
    widget.onChanged?.call(value);
    // Fire-and-forget: persistence is not interactive-blocking.
    // ignore: discarded_futures
    context.read<SettingsProvider>().setThinkingBudget(value);
  }

  void _animateTo(int index) {
    _snap.stop();
    _snap.value = _position;
    // ignore: discarded_futures
    _snap.animateWith(
      SpringSimulation(_spring, _position, index.toDouble(), 0),
    );
  }

  void _onDragPosition(double position) {
    setState(() => _position = position);
    _commitIndex(position.round());
  }

  void _onSnap(int index) {
    _commitIndex(index);
    _animateTo(index);
  }

  Future<void> _openCustomBudget() async {
    Haptics.light();
    final initialValue = _isCustomSelected ? _selected : 2048;
    final chosen = await ReasoningBudgetCustomDialog.show(
      context,
      initialValue: initialValue,
    );
    if (!mounted || chosen == null) return;
    setState(() {
      _selected = chosen;
      _position = _indexForSelection().toDouble();
    });
    widget.onChanged?.call(chosen);
    // ignore: discarded_futures
    context.read<SettingsProvider>().setThinkingBudget(chosen);
  }

  bool _showXhighOption(SettingsProvider settings) {
    final assistant = context.read<AssistantProvider>().currentAssistant;
    final currentProvider =
        widget.modelProvider ??
        assistant?.chatModelProvider ??
        settings.currentModelProvider;
    final currentModelId =
        widget.modelId ?? assistant?.chatModelId ?? settings.currentModelId;
    if (currentProvider == null || currentModelId == null) return false;
    return settings.supportsXhighReasoning(currentProvider, currentModelId);
  }

  bool _showMaxOption(SettingsProvider settings) {
    final assistant = context.read<AssistantProvider>().currentAssistant;
    final currentProvider =
        widget.modelProvider ??
        assistant?.chatModelProvider ??
        settings.currentModelProvider;
    final currentModelId =
        widget.modelId ?? assistant?.chatModelId ?? settings.currentModelId;
    if (currentProvider == null || currentModelId == null) return false;
    return settings.supportsMaxReasoning(currentProvider, currentModelId);
  }

  Widget _buildLabelPill(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final custom = _isCustomSelected;
    final activeIndex = _position.round().clamp(0, _stops.length - 1).toInt();
    final activeStop = _stops[activeIndex];
    final title = custom
        ? l10nOf(context).reasoningBudgetSheetCustomLabel
        : activeStop.title;
    final subtitle = custom ? _selected.toString() : activeStop.subtitle;

    final titleStyle = TextStyle(
      fontSize: 17,
      fontWeight: AppFontWeights.semibold,
      color: cs.primary,
    );
    final subtitleStyle = TextStyle(
      fontSize: 12,
      color: cs.onSurface.withValues(alpha: 0.55),
    );

    Widget iconSwitcher(Widget child) => AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => ClipRect(
        child: SlideTransition(
          position: animation.drive(
            Tween(begin: const Offset(0, 0.5), end: Offset.zero),
          ),
          child: FadeTransition(opacity: animation, child: child),
        ),
      ),
      child: child,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            iconSwitcher(
              KeyedSubtree(
                key: ValueKey(custom ? -2 : activeStop.value),
                child: custom
                    ? Icon(Lucide.Hash, size: 18, color: cs.primary)
                    : ReasoningIcons.budgetIcon(
                        activeStop.icon,
                        size: 18,
                        color: cs.primary,
                      ),
              ),
            ),
            const SizedBox(width: 8),
            _AnimatedWidthText(
              text: title,
              style: titleStyle,
              switchKey: ValueKey('t:$title'),
            ),
          ],
        ),
        const SizedBox(height: 2),
        _AnimatedWidthText(
          text: subtitle,
          style: subtitleStyle,
          switchKey: ValueKey('s:$subtitle'),
        ),
      ],
    );
  }

  Widget _buildCustomRow(BuildContext context) {
    final l10n = l10nOf(context);
    final cs = Theme.of(context).colorScheme;
    final custom = _isCustomSelected;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SizedBox(
        height: 48,
        child: IosCardPress(
          borderRadius: BorderRadius.circular(14),
          baseColor: sheetTileColor(context),
          duration: const Duration(milliseconds: 260),
          onTap: _openCustomBudget,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(
                Lucide.Hash,
                size: 20,
                color: custom
                    ? cs.primary
                    : cs.onSurface.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.reasoningBudgetSheetCustomLabel,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: AppFontWeights.medium,
                    color: custom ? cs.primary : cs.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (custom)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _selected.toString(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: AppFontWeights.semibold,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Lucide.Check, size: 18, color: cs.primary),
                  ],
                )
              else
                Icon(
                  Lucide.ChevronRight,
                  size: 18,
                  color: cs.onSurface.withValues(alpha: 0.45),
                ),
            ],
          ),
        ),
      ),
    );
  }

  AppLocalizations l10nOf(BuildContext context) =>
      AppLocalizations.of(context)!;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final showXhigh = _showXhighOption(settings);
    final showMax = _showMaxOption(settings);
    final cs = Theme.of(context).colorScheme;
    _stops = _buildStops(
      l10nOf(context),
      showXhigh: showXhigh,
      showMax: showMax,
    );
    if (_position > _stops.length - 1) {
      _position = (_stops.length - 1).toDouble();
    }
    if (!_positionInitialized) {
      _positionInitialized = true;
      _position = _indexForSelection().toDouble();
    }
    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 16),
            Center(child: _buildLabelPill(context)),
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: _EffortSlider(
                position: _position,
                stopCount: _stops.length,
                stopKeys: [for (final s in _stops) 'reasoning-stop-${s.value}'],
                dragging: _dragging,
                semanticsValue: _isCustomSelected
                    ? l10nOf(context).reasoningBudgetSheetCustomLabel
                    : _stops[_position
                              .round()
                              .clamp(0, _stops.length - 1)
                              .toInt()]
                          .title,
                onDragStart: () {
                  _snap.stop();
                  setState(() => _dragging = true);
                },
                onDragEnd: () => setState(() => _dragging = false),
                onPositionChanged: _onDragPosition,
                onSnap: _onSnap,
              ),
            ),
            const SizedBox(height: 20),
            _buildCustomRow(context),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

/// Discrete-step slider for the reasoning effort presets.
///
/// Purely presentational: the parent owns [position] and animates it; this
/// widget reports raw drag positions and snap targets.
class _EffortSlider extends StatelessWidget {
  const _EffortSlider({
    required this.position,
    required this.stopCount,
    required this.stopKeys,
    required this.dragging,
    required this.semanticsValue,
    required this.onDragStart,
    required this.onDragEnd,
    required this.onPositionChanged,
    required this.onSnap,
  });

  final double position;
  final int stopCount;
  final List<String> stopKeys;
  final bool dragging;
  final String semanticsValue;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;
  final ValueChanged<double> onPositionChanged;
  final ValueChanged<int> onSnap;

  static const double _height = 56;
  static const double _thumbRadius = 19;
  // Stops sit exactly one thumb radius from each end, so at the extremes the
  // thumb is flush with the track edge and fully covers the fill — no
  // visible track/fill sliver beside the thumb.
  static const double _stopInset = _thumbRadius;

  double _indexForDx(double dx, double width) {
    final span = width - 2 * _stopInset;
    if (span <= 0 || stopCount <= 1) return 0;
    return (((dx - _stopInset) / span) * (stopCount - 1))
        .clamp(0.0, (stopCount - 1).toDouble())
        .toDouble();
  }

  double _thumbX(double width) {
    final span = width - 2 * _stopInset;
    final t = stopCount <= 1 ? 0.0 : position / (stopCount - 1);
    return _stopInset + span * t;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      slider: true,
      value: semanticsValue,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (_) => onDragStart(),
            onHorizontalDragUpdate: (details) =>
                onPositionChanged(_indexForDx(details.localPosition.dx, width)),
            onHorizontalDragEnd: (_) {
              onDragEnd();
              onSnap(position.round());
            },
            onHorizontalDragCancel: () {
              onDragEnd();
              onSnap(position.round());
            },
            onTapDown: (details) {
              final index = _indexForDx(
                details.localPosition.dx,
                width,
              ).round();
              onSnap(index);
            },
            child: SizedBox(
              height: _height,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: Size(width, _height),
                    painter: _SliderPainter(
                      position: position,
                      stopCount: stopCount,
                      thumbX: _thumbX(width),
                      stopInset: _stopInset,
                      primary: cs.primary,
                      trackColor: cs.onSurface.withValues(alpha: 0.10),
                      upcomingDotColor: cs.onSurface.withValues(alpha: 0.25),
                    ),
                  ),
                  // Invisible per-stop anchors: a11y landmarks + test hooks.
                  Positioned.fill(
                    child: Row(
                      children: [
                        for (final key in stopKeys)
                          Expanded(child: SizedBox(key: ValueKey(key))),
                      ],
                    ),
                  ),
                  Positioned(
                    left: _thumbX(width) - _thumbRadius,
                    top: (_height - _thumbRadius * 2) / 2,
                    child: IgnorePointer(
                      child: AnimatedScale(
                        scale: dragging ? 1.14 : 1.0,
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutBack,
                        child: Container(
                          width: _thumbRadius * 2,
                          height: _thumbRadius * 2,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SliderPainter extends CustomPainter {
  _SliderPainter({
    required this.position,
    required this.stopCount,
    required this.thumbX,
    required this.stopInset,
    required this.primary,
    required this.trackColor,
    required this.upcomingDotColor,
  });

  final double position;
  final int stopCount;
  final double thumbX;
  final double stopInset;
  final Color primary;
  final Color trackColor;
  final Color upcomingDotColor;

  static const double _trackHeight = 34;
  static const double _dotRadius = 3.5;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final trackRect = Rect.fromLTWH(
      0,
      cy - _trackHeight / 2,
      size.width,
      _trackHeight,
    );
    final trackRRect = RRect.fromRectAndRadius(
      trackRect,
      const Radius.circular(_trackHeight / 2),
    );

    canvas.drawRRect(trackRRect, Paint()..color = trackColor);

    if (thumbX > 0) {
      final fillRect = Rect.fromLTWH(
        0,
        cy - _trackHeight / 2,
        thumbX.clamp(0.0, size.width),
        _trackHeight,
      );
      final fillPaint = Paint()
        ..shader = LinearGradient(
          colors: [primary.withValues(alpha: 0.5), primary],
        ).createShader(fillRect);
      canvas.save();
      canvas.clipRRect(trackRRect);
      canvas.drawRect(fillRect, fillPaint);
      canvas.restore();
    }

    if (stopCount > 1) {
      final passedPaint = Paint()..color = Colors.white.withValues(alpha: 0.9);
      final upcomingPaint = Paint()..color = upcomingDotColor;
      for (var i = 0; i < stopCount; i++) {
        final x =
            stopInset + (size.width - 2 * stopInset) * (i / (stopCount - 1));
        // Dots the thumb already passed sit on the fill and turn white.
        final passed = i <= position.round();
        canvas.drawCircle(
          Offset(x, cy),
          _dotRadius,
          passed ? passedPaint : upcomingPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_SliderPainter old) =>
      old.position != position ||
      old.stopCount != stopCount ||
      old.thumbX != thumbX ||
      old.primary != primary ||
      old.trackColor != trackColor;
}

/// Text that crossfades between values while its width tweens smoothly.
///
/// A bare [AnimatedSwitcher] stacks old and new children during the
/// transition and snaps its size at the transition boundary, so any layout
/// depending on the text width (e.g. a centered icon+label row) jumps in a
/// single frame. Measuring the text and tweening a tight-width box removes
/// that jump; the switcher inside only handles the glyph transition.
class _AnimatedWidthText extends StatelessWidget {
  const _AnimatedWidthText({
    required this.text,
    required this.style,
    required this.switchKey,
  });

  final String text;
  final TextStyle style;
  final Key switchKey;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    // Measure with the same style the Text below renders with: ambient
    // DefaultTextStyle (fontFamily, letterSpacing, …) merged under the local
    // style. Otherwise the measured width is slightly narrower than the
    // rendered text and ClipRect cuts off the right edge.
    final effectiveStyle = DefaultTextStyle.of(context).style.merge(style);
    final painter = TextPainter(
      text: TextSpan(text: text, style: effectiveStyle),
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: scaler,
    )..layout();
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: painter.width),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      builder: (context, width, _) => SizedBox(
        width: width,
        child: ClipRect(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => ClipRect(
              child: SlideTransition(
                position: animation.drive(
                  Tween(begin: const Offset(0, 0.5), end: Offset.zero),
                ),
                child: FadeTransition(opacity: animation, child: child),
              ),
            ),
            child: Text(
              text,
              key: switchKey,
              style: style,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.clip,
            ),
          ),
        ),
      ),
    );
  }
}
