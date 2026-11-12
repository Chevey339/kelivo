import 'genui_interactions.dart';
import 'genui_input_snapshot.dart';
import 'genui_motion.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:markstream/markstream.dart' as ms;
import 'package:Kelivo/features/intelligent_ui/protocol/ui_diagnostic.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'genui_content.dart';
import 'genui_layout.dart';
import 'genui_localizations.dart';
import 'genui_theme.dart';
import 'genui_text_input.dart';
import 'genui_form.dart';
import 'genui_button.dart';
import 'genui_boolean_input.dart';
import 'genui_choice_input.dart';
import 'genui_slider.dart';
import 'genui_chart.dart';
import 'genui_table.dart';

/// One dependency subscription per node. The host owns the controller; widget
/// disposal only removes this observer, so off-screen messages retain state.
class GenUiNode extends StatefulWidget {
  const GenUiNode({
    super.key,
    required this.controller,
    required this.id,
    this.linkHandler,
  });
  final UiSurfaceController controller;
  final String id;
  final ms.LinkHandler? linkHandler;
  @override
  State<GenUiNode> createState() => _GenUiNodeState();
}

class _GenUiNodeState extends State<GenUiNode>
    with SingleTickerProviderStateMixin {
  AnimationController? _reveal;
  final _contentKey = GlobalKey(debugLabel: 'GenUI node content');
  bool _wasPending = false;
  bool _reduceMotion = false;
  bool get _pending {
    final node = widget.controller.nodes[widget.id];
    return node?.pending == true ||
        (node == null &&
            (widget.controller.parsed.program.pendingSymbols.contains(
                  widget.id,
                ) ||
                widget.controller.phase == SurfacePhase.streaming ||
                widget.controller.phase == SurfacePhase.interrupted));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) _reveal?.value = 1;
  }

  late void Function() _unsubscribe;
  void _subscribe() {
    _wasPending = _pending;
    _unsubscribe = widget.controller.listenNode(widget.id, () {
      if (!mounted) return;
      final pending = _pending;
      if (pending) _reveal?.stop();
      if (_wasPending && !pending && !_reduceMotion) {
        _reveal ??=
            AnimationController(
              vsync: this,
              duration: const Duration(milliseconds: 160),
            )..addStatusListener((status) {
              if (mounted && status == AnimationStatus.completed) {
                setState(() {});
              }
            });
        _reveal!.forward(from: 0);
      }
      _wasPending = pending;
      setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(GenUiNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.id != widget.id) {
      _unsubscribe();
      _subscribe();
    }
  }

  @override
  void dispose() {
    _unsubscribe();
    _reveal?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Reparent this same subtree when the short-lived transition disappears;
    // field elements, focus nodes and active composing ranges stay alive.
    final child = KeyedSubtree(key: _contentKey, child: _buildNode(context));
    final returning = GenUiReturnMotion.maybeOf(context);
    final component = widget.controller.nodes[widget.id]?.declaration.component;
    if (!_reduceMotion &&
        returning?.changed.contains(widget.id) == true &&
        const {
          'Text',
          'Markdown',
          'Formula',
          'Metric',
          'Badge',
          'Callout',
          'Chart',
          'DataTable',
        }.contains(component)) {
      return FadeTransition(opacity: returning!.animation, child: child);
    }
    return !_reduceMotion && _reveal?.isAnimating == true
        ? FadeTransition(opacity: _reveal!, child: child)
        : child;
  }

  Widget _buildNode(BuildContext context) {
    final controller = widget.controller;
    final node = controller.nodes[widget.id];
    if (_pending) {
      return GenUiPendingNode(
        id: widget.id,
        component: node?.declaration.component,
      );
    }
    if (node != null &&
        node.declaration.component == 'Button' &&
        node.properties['label'] is String) {
      if (!node.visible) return const SizedBox.shrink();
      return GenUiButton(
        key: ValueKey((controller, widget.id, controller.token.epoch)),
        id: widget.id,
        node: node,
        token: controller.token,
      );
    }
    if (node == null || !node.valid) {
      final diagnostics =
          node?.diagnostics ??
          controller.parsed.program.diagnostics
              .where((d) => d.symbol == widget.id)
              .toList();
      return GenUiNodeError(
        id: widget.id,
        diagnostic:
            diagnostics.firstOrNull ??
            UiDiagnostic(
              UiDiagnosticCode.missingReference,
              line: 1,
              symbol: widget.id,
            ),
      );
    }
    if (!node.visible) return const SizedBox.shrink();
    final exporting =
        context
            .dependOnInheritedWidgetOfExactType<GenUiInteractions>()
            ?.exporting ??
        false;
    if (const {
          'TextField',
          'NumberField',
          'Slider',
          'Switch',
          'Checkbox',
          'Select',
          'RadioGroup',
        }.contains(node.declaration.component) &&
        exporting) {
      return GenUiInputSnapshot(node: node);
    }
    final props = node.properties;
    final key = ValueKey((controller, widget.id, controller.token.epoch));
    Widget children(Widget Function(List<Widget>) builder) => _GenUiChildren(
      key: key,
      controller: controller,
      ids: (props['children'] as List).cast<String>(),
      linkHandler: widget.linkHandler,
      builder: builder,
    );
    return switch (node.declaration.component) {
      'Form' => children(
        (items) => GenUiForm(
          id: widget.id,
          title: props['title'] as String?,
          children: items,
        ),
      ),
      'Column' => children(
        (items) => GenUiColumn(gap: props['gap'] as String, children: items),
      ),
      'Row' => children(
        (items) => GenUiRow(
          gap: props['gap'] as String,
          distribution: props['distribution'] as String,
          children: items,
        ),
      ),
      'Section' => children(
        (items) => GenUiSection(
          title: props['title'] as String,
          subtitle: props['subtitle'] as String?,
          tone: props['tone'] as String,
          children: items,
        ),
      ),
      'Switch' || 'Checkbox' => GenUiBooleanInput(
        key: key,
        id: widget.id,
        node: node,
        token: controller.token,
      ),
      'Slider' => GenUiSlider(
        key: key,
        id: widget.id,
        node: node,
        token: controller.token,
      ),
      'Select' || 'RadioGroup' => GenUiChoiceInput(
        key: key,
        id: widget.id,
        node: node,
        token: controller.token,
      ),
      'TextField' || 'NumberField' => GenUiTextInput(
        key: key,
        id: widget.id,
        node: node,
        token: controller.token,
      ),
      'Chart' => GenUiChart(
        key: key,
        id: widget.id,
        node: node,
        token: controller.token,
      ),
      'DataTable' => GenUiDataTable(
        key: key,
        id: widget.id,
        node: node,
        token: controller.token,
      ),
      'Divider' => GenUiDivider(key: key, label: props['label'] as String?),
      'Text' => GenUiText(
        key: key,
        text: props['text'] as String,
        variant: props['variant'] as String?,
      ),
      'Markdown' => GenUiMarkdown(
        key: key,
        text: props['text'] as String,
        linkHandler: widget.linkHandler,
        exporting: exporting,
      ),
      'Formula' => GenUiFormula(
        key: key,
        tex: props['tex'] as String,
        label: props['label'] as String?,
        exporting: exporting,
      ),
      'Metric' => GenUiMetric(
        key: key,
        label: props['label'] as String,
        value: props['value'] as num?,
        unit: props['unit'] as String?,
        digits: (props['digits'] as num?)?.toInt(),
        trend: props['trend'] as num?,
      ),
      'Badge' => Align(
        alignment: AlignmentDirectional.centerStart,
        child: GenUiBadge(
          key: key,
          text: props['text'] as String,
          tone: props['tone'] as String,
        ),
      ),
      'Callout' => GenUiCallout(
        key: key,
        text: props['text'] as String,
        title: props['title'] as String?,
        tone: props['tone'] as String,
      ),
      _ => GenUiCallout(
        key: key,
        text: AppLocalizations.of(context)!.genuiNodeUnavailable,
        title: node.declaration.component,
        tone: 'error',
      ),
    };
  }
}

/// Layout depends on child visibility, not each child's value. Filtering here
/// removes hidden-field gaps without rebuilding ancestors on slider updates.
class _GenUiChildren extends StatefulWidget {
  const _GenUiChildren({
    super.key,
    required this.controller,
    required this.ids,
    required this.builder,
    this.linkHandler,
  });
  final UiSurfaceController controller;
  final List<String> ids;
  final Widget Function(List<Widget>) builder;
  final ms.LinkHandler? linkHandler;
  @override
  State<_GenUiChildren> createState() => _GenUiChildrenState();
}

class _GenUiChildrenState extends State<_GenUiChildren> {
  final _subscriptions = <void Function()>[];
  final _visibility = <String, bool>{};
  bool _visible(String id) {
    final node = widget.controller.nodes[id];
    return node == null || !node.valid || node.visible;
  }

  void _subscribe() {
    _visibility.clear();
    for (final id in widget.ids) {
      _visibility[id] = _visible(id);
      _subscriptions.add(
        widget.controller.listenNode(id, () {
          final value = _visible(id);
          if (mounted && _visibility[id] != value) {
            setState(() => _visibility[id] = value);
          }
        }),
      );
    }
  }

  void _unsubscribe() {
    for (final stop in _subscriptions) {
      stop();
    }
    _subscriptions.clear();
  }

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(_GenUiChildren oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.ids != widget.ids) {
      _unsubscribe();
      _subscribe();
    }
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder([
    for (final id in widget.ids)
      if (_visibility[id] != false)
        GenUiNode(
          key: ValueKey(id),
          controller: widget.controller,
          id: id,
          linkHandler: widget.linkHandler,
        ),
  ]);
}

String _displayId(String id) =>
    id.length <= 80 ? id : '${id.substring(0, 80)}…';

class GenUiPendingNode extends StatelessWidget {
  const GenUiPendingNode({super.key, required this.id, this.component});
  final String id;
  final String? component;
  @override
  Widget build(BuildContext context) {
    final theme = GenUiTheme.of(context);
    final height = switch (component) {
      'Chart' => 200.0,
      'DataTable' => 160.0,
      'Button' => 36.0,
      'Form' => 56.0,
      _ => 64.0,
    };
    return CustomPaint(
      painter: _PendingPainter(
        GenUiMotion.of(context),
        theme,
        theme.sm +
            MediaQuery.textScalerOf(context).scale(theme.caption.fontSize!) *
                theme.caption.height! +
            theme.xs,
      ),
      child: Container(
        constraints: BoxConstraints(minHeight: height),
        padding: EdgeInsets.all(theme.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ExcludeSemantics(
                  child: RotationTransition(
                    turns: GenUiMotion.of(context),
                    child: Icon(
                      LucideIcons.loaderCircle,
                      size: 14,
                      color: theme.captionInk,
                    ),
                  ),
                ),
                SizedBox(width: theme.xs),
                Expanded(
                  child: Text(
                    '${AppLocalizations.of(context)!.genuiPendingNode(_displayId(id))}${component == null ? "" : " · $component"}',
                    style: theme.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (height > 36)
              const ExcludeSemantics(child: SizedBox(height: 20)),
          ],
        ),
      ),
    );
  }
}

class _PendingPainter extends CustomPainter {
  _PendingPainter(this.animation, this.theme, this.contentTop)
    : super(repaint: animation);
  final double contentTop;
  final Animation<double> animation;
  final GenUiTheme theme;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(theme.controlRadius),
    );
    canvas.drawRRect(rect, Paint()..color = theme.contentBackground);
    final outline = Path()..addRRect(rect.deflate(.5));
    final stroke = Paint()
      ..color = theme.hairlineStrong
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final metric in outline.computeMetrics()) {
      for (var offset = 0.0; offset < metric.length; offset += 7) {
        canvas.drawPath(
          metric.extractPath(offset, (offset + 4).clamp(0, metric.length)),
          stroke,
        );
      }
    }
    if (size.height > contentTop + theme.sm) {
      final block = Rect.fromLTRB(
        theme.sm,
        contentTop,
        size.width - theme.sm,
        size.height - theme.sm,
      );
      // A full-height shimmer, painted from the surface's one shared clock.
      // No layer/Opacity widget and no node-owned animation controller.
      final progress = animation.value * 3 - 1;
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment(progress - 1, 0),
          end: Alignment(progress + 1, 0),
          colors: [theme.fill, theme.cardFill, theme.fill],
          stops: const [0, .5, 1],
        ).createShader(block);
      canvas.drawRRect(
        RRect.fromRectAndRadius(block, Radius.circular(theme.controlRadius)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_PendingPainter oldDelegate) =>
      theme != oldDelegate.theme ||
      animation != oldDelegate.animation ||
      contentTop != oldDelegate.contentTop;
}

class GenUiNodeError extends StatelessWidget {
  const GenUiNodeError({super.key, required this.id, required this.diagnostic});
  final String id;
  final UiDiagnostic diagnostic;
  @override
  Widget build(BuildContext context) {
    final theme = GenUiTheme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: EdgeInsets.all(theme.sm),
      decoration: BoxDecoration(
        color: theme.errorWash,
        borderRadius: BorderRadius.circular(theme.controlRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Icon(LucideIcons.circleAlert, size: 16, color: theme.error),
          ),
          SizedBox(width: theme.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _displayId(id),
                  style: theme.header.copyWith(color: theme.error),
                ),
                SizedBox(height: theme.xxs),
                Text(
                  genUiDiagnosticMessage(l10n, diagnostic),
                  style: theme.body,
                ),
                SizedBox(height: theme.xxs),
                Text(
                  l10n.genuiErrorLine(diagnostic.line),
                  style: theme.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
