import '../text/ui_number_display.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/responsive/screen_type_helper.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import '../catalog/ui_catalog.dart';
import '../runtime/ui_chart_data.dart';
import '../runtime/ui_resolved_node.dart';
import '../runtime/ui_surface_controller.dart';
import 'genui_chart_canvas.dart';
import 'genui_chart_paint.dart';
import 'genui_control_region.dart';
import 'genui_interactions.dart';
import 'genui_theme.dart';
import 'genui_table.dart';
import 'genui_view_tabs.dart';

String genUiChartKindLabel(
  AppLocalizations l10n,
  UiChartKind kind, {
  bool donut = false,
}) => switch (kind) {
  UiChartKind.line => l10n.genuiChartLine,
  UiChartKind.area => l10n.genuiChartArea,
  UiChartKind.bar => l10n.genuiChartBar,
  UiChartKind.scatter => l10n.genuiChartScatter,
  UiChartKind.pie => donut ? l10n.genuiChartDonut : l10n.genuiChartPie,
};

class GenUiChart extends StatefulWidget {
  const GenUiChart({
    super.key,
    required this.id,
    required this.node,
    required this.token,
  });
  final String id;
  final UiResolvedNode node;
  final UiRuntimeToken token;
  @override
  State<GenUiChart> createState() => _GenUiChartState();
}

class _GenUiChartState extends State<GenUiChart> {
  final _focus = FocusNode(debugLabel: 'GenUI chart');
  GenUiInteractions? _scope;
  VoidCallback? _unsubscribe, _reset;
  GenUiChartPoint? _hover, _selected;
  bool _focused = false, _showFocus = false;
  bool _viewFailed = false;
  UiChartData get _data => widget.node.chartData!;
  Map<String, Object?> get _props => widget.node.properties;
  UiSurfaceController get _surface => _scope!.controller.surface;
  Set<int> get _hidden =>
      ((_surface.state.view[widget.id]?['hiddenSeries'] as List?)
                  ?.cast<int>() ??
              const <int>[])
          .toSet();
  bool get _pie => _data.kind == UiChartKind.pie;
  bool get _interactive =>
      !_scope!.readOnly &&
      _surface.accepts(widget.token) &&
      _scope!.controller.tree.enabled[widget.id] == true;
  int get _seriesCount => _pie ? _data.rows.length : _data.yKeys.length;
  GenUiChartPoint? _visible(GenUiChartPoint? point) =>
      point == null ||
          point.row < 0 ||
          point.row >= _data.rows.length ||
          point.series < 0 ||
          point.series >= _seriesCount ||
          _hidden.contains(point.series)
      ? null
      : point;
  GenUiChartPoint? get _active => _visible(_hover) ?? _visible(_selected);
  List<UiChartRow> get _pieRows =>
      _data.rows.where((r) => !_hidden.contains(r.index)).toList();
  double get _pieTotal =>
      _pieRows.fold(0.0, (sum, r) => sum + (r.y.single ?? 0));
  bool get _visibleValues => _pie
      ? _pieTotal > 0
      : _data.rows.any(
          (r) => [
            for (var s = 0; s < _data.yKeys.length; s++)
              if (!_hidden.contains(s)) r.y[s],
          ].any((v) => v != null),
        );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = GenUiInteractions.of(context);
    if (scope.controller != _scope?.controller) {
      _viewFailed = false;
      _unsubscribe?.call();
      _reset?.call();
      _unsubscribe = scope.controller.listen(widget.id, () {
        if (mounted) setState(() {});
      });
      _reset = scope.controller.surface.listenReset(() {
        if (mounted) {
          setState(() {
            _hover = null;
            _selected = null;
            _viewFailed = false;
          });
        }
      });
    }
    _scope = scope;
  }

  @override
  void didUpdateWidget(GenUiChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.node.chartData!;
    if (old.kind != _data.kind ||
        old.xKey != _data.xKey ||
        !listEquals(old.yKeys, _data.yKeys)) {
      _hover = null;
      _selected = null;
    }
  }

  @override
  void dispose() {
    _unsubscribe?.call();
    _reset?.call();
    _focus.dispose();
    super.dispose();
  }

  void _toggle(int series) {
    if (!_interactive) return;
    final next = _hidden;
    if (!next.remove(series)) next.add(series);
    _changeView({'hiddenSeries': next.toList()});
  }

  void _changeView(Map<String, Object?> changes) {
    if (!_interactive) return;
    final result = _surface.setView(widget.id, {
      ...?_surface.state.view[widget.id],
      ...changes,
    }, token: widget.token);
    setState(() => _viewFailed = result == UiMutationResult.invalid);
    _surface.flushQuietly();
  }

  void _touch(FlTouchEvent event, GenUiChartPoint? point) {
    if (!_interactive) return;
    if (event is FlTapUpEvent) {
      _focus.requestFocus();
      setState(() {
        _selected = _selected == point ? null : point;
        _hover = null;
      });
    } else {
      final next = event.isInterestedForInteractions ? point : null;
      if (_hover != next) setState(() => _hover = next);
    }
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (!_interactive || event is KeyUpEvent || _data.rows.isEmpty) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      if (_selected == null && _hover == null) return KeyEventResult.ignored;
      setState(() {
        _selected = null;
        _hover = null;
      });
      return KeyEventResult.handled;
    }
    final series = [
      for (var i = 0; i < _seriesCount; i++)
        if (!_hidden.contains(i)) i,
    ];
    if (series.isEmpty) return KeyEventResult.ignored;
    final current =
        _visible(_selected) ??
        (row: _pie ? series.first : 0, series: series.first);
    var row = current.row, s = series.indexOf(current.series);
    if (key == LogicalKeyboardKey.home) {
      row = 0;
      s = 0;
    } else if (key == LogicalKeyboardKey.end) {
      row = _data.rows.length - 1;
      s = series.length - 1;
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      if (_pie) {
        s--;
      } else {
        row--;
      }
    } else if (key == LogicalKeyboardKey.arrowRight) {
      if (_pie) {
        s++;
      } else {
        row++;
      }
    } else if (key == LogicalKeyboardKey.arrowUp) {
      s--;
    } else if (key == LogicalKeyboardKey.arrowDown) {
      s++;
    } else if (key != LogicalKeyboardKey.enter &&
        key != LogicalKeyboardKey.space) {
      return KeyEventResult.ignored;
    }
    s = s.clamp(0, series.length - 1);
    row = _pie ? series[s] : row.clamp(0, _data.rows.length - 1);
    setState(() {
      _selected = (row: row, series: series[s]);
      _hover = null;
    });
    return KeyEventResult.handled;
  }

  String _value(num? value) =>
      '${genUiDisplayNumber(value)}${_props['unit'] == null || value == null ? '' : ' ${_props['unit']}'}';
  String _xValue(UiChartRow row) =>
      row.x is num ? genUiDisplayNumber(row.x as num) : row.x as String;
  String _tooltip(GenUiChartPoint point, AppLocalizations l10n) {
    final row = _data.rows[point.row];
    if (_pie) {
      return '${_xValue(row)}: ${_value(row.y.single)}${row.y.single == null || _pieTotal == 0 ? '' : ' (${genUiChartTick(row.y.single! / _pieTotal * 100)}%)'}';
    }
    return [
      '${_props['xLabel'] ?? _data.xKey}: ${_xValue(row)}',
      for (var s = 0; s < _data.yKeys.length; s++)
        '${_data.yKeys[s]}: ${_value(row.y[s])}',
      if (_data.domainRows.contains(row.index)) l10n.genuiChartDomainGap,
    ].join('\n');
  }

  String get _axisCaption {
    final title = (_props['title'] as String? ?? '').trim();
    final label = _props['yLabel'] as String? ?? '';
    final unit = _props['unit'] as String? ?? '';
    final parts = <String>[
      if (label.isNotEmpty &&
          title != label &&
          !(_data.yKeys.length == 1 && _data.yKeys.single == label))
        label,
      if (unit.isNotEmpty &&
          title != unit &&
          !title.contains('($unit)') &&
          !title.contains('（$unit）') &&
          !title.contains('[$unit]'))
        unit,
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = GenUiTheme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final kind = genUiChartKindLabel(
      l10n,
      _data.kind,
      donut: _props['donut'] == true,
    );
    final summary = _pie
        ? l10n.genuiChartPieSummary(
            kind,
            _pieRows.length,
            '${genUiDisplayTotal(_pieRows.map((r) => r.y.single ?? 0))}${_props['unit'] == null ? '' : ' ${_props['unit']}'}',
          )
        : l10n.genuiChartSummary(
            kind,
            _data.yKeys.length,
            _data.rows.length,
            _data.missingCount,
          );
    final active = _scope!.exporting ? null : _active;
    final height = ResponsiveHelper.isMobile(context) ? 200.0 : 260.0;
    final dataView = _surface.state.view[widget.id]?['dataView'] == true;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: summary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: switch (_props['title']) {
                  final String title => Text(title, style: theme.sectionTitle),
                  _ => const SizedBox(),
                },
              ),
              if (!_scope!.exporting) ...[
                SizedBox(width: theme.xs),
                GenUiViewTabs(
                  key: ValueKey('genui-chart-view-${widget.id}'),
                  labels: [l10n.genuiViewChart, l10n.genuiViewData],
                  index: dataView ? 1 : 0,
                  enabled: _interactive,
                  onChanged: (index) => _changeView({'dataView': index == 1}),
                ),
              ],
            ],
          ),
          if (_viewFailed && !_scope!.exporting)
            Semantics(
              liveRegion: true,
              child: Text(
                l10n.genuiViewStateFailed,
                style: theme.caption.copyWith(color: theme.error),
              ),
            ),
          if (dataView)
            GenUiDataTable(
              id: widget.id,
              node: widget.node,
              token: widget.token,
            )
          else ...[
            LayoutBuilder(
              builder: (context, constraints) => Wrap(
                spacing: theme.xs,
                runSpacing: 0,
                children: [
                  for (var s = 0; s < _seriesCount; s++)
                    _legend(s, constraints.maxWidth, theme, l10n),
                ],
              ),
            ),
            if (!_pie && _axisCaption.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(bottom: theme.xs),
                child: Text(_axisCaption, style: theme.label),
              ),
            GenUiControlRegion(
              child: Focus(
                canRequestFocus: false,
                onKeyEvent: _key,
                child: FocusableActionDetector(
                  focusNode: _focus,
                  onFocusChange: (value) => setState(() => _focused = value),
                  enabled: _interactive,
                  onShowFocusHighlight: (value) =>
                      setState(() => _showFocus = value),
                  child: Semantics(
                    focusable: _interactive,
                    focused: _focused,
                    hint: l10n.genuiChartKeyboardHint,
                    child: Container(
                      key: ValueKey('genui-chart-canvas-${widget.id}'),
                      height: height,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _showFocus ? theme.primary : theme.transparent,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(
                          theme.controlRadius,
                        ),
                      ),
                      child: !_visibleValues
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    LucideIcons.chartNoAxesCombined,
                                    color: theme.captionInk,
                                  ),
                                  SizedBox(height: theme.xs),
                                  Text(
                                    _data.isEmpty
                                        ? l10n.genuiChartEmpty
                                        : _hidden.length >= _seriesCount
                                        ? l10n.genuiChartAllHidden
                                        : l10n.genuiChartNoVisibleValues,
                                    textAlign: TextAlign.center,
                                    style: theme.caption,
                                  ),
                                ],
                              ),
                            )
                          : ExcludeSemantics(
                              child: GenUiChartCanvas(
                                data: _data,
                                properties: _props,
                                hidden: _hidden,
                                active: active,
                                highlightedSeries: _scope!.exporting
                                    ? null
                                    : _visible(_selected)?.series,
                                interactive: _interactive,
                                onTouch: _touch,
                                gapLabel: l10n.genuiChartDomainGap,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
            if (_props['xLabel'] case final String label)
              Text(label, textAlign: TextAlign.center, style: theme.label),
            if (active != null &&
                !_scope!.exporting &&
                !(_pie && _props['donut'] == true))
              Semantics(
                liveRegion: true,
                child: Container(
                  key: ValueKey('genui-chart-tooltip-${widget.id}'),
                  margin: EdgeInsets.only(top: theme.xs),
                  // A normal text subtree keeps the exact values reachable to assistive
                  // technology and large text, unlike a clipped canvas tooltip.
                  child: Stack(
                    children: [
                      Positioned.fill(
                        top: theme.xxs,
                        bottom: theme.xxs,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: theme.cardFill,
                            borderRadius: BorderRadius.circular(
                              theme.controlRadius,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsetsDirectional.only(start: theme.sm),
                        child: Row(
                          children: [
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: theme.xs,
                                ),
                                child: Text(
                                  _tooltip(
                                    active,
                                    l10n,
                                  ).replaceAll('\n', ' · '),
                                  style: theme.caption.copyWith(
                                    color: theme.secondaryInk,
                                  ),
                                ),
                              ),
                            ),
                            IosIconButton(
                              icon: LucideIcons.x,
                              size: 14,
                              minSize: 44,
                              visualSize: 28,
                              tooltip: l10n.genuiClearSelection,
                              onTap: () => setState(() {
                                _selected = null;
                                _hover = null;
                              }),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],

          if (_pie && active != null && _props['donut'] == true)
            Semantics(
              liveRegion: true,
              label: _tooltip(active, l10n),
              child: const SizedBox.shrink(),
            ),
          if (_data.domainRows.isNotEmpty)
            Text(
              l10n.genuiChartDomainSummary(_data.domainRows.length),
              style: theme.caption,
            ),
          if (_data.missingCount > 0 && _data.domainRows.isEmpty)
            Text(
              l10n.genuiChartMissingValues(_data.missingCount),
              style: theme.caption,
            ),
        ],
      ),
    );
  }

  Widget _legend(
    int series,
    double width,
    GenUiTheme theme,
    AppLocalizations l10n,
  ) {
    final hidden = _hidden.contains(series);
    final name = _pie ? _xValue(_data.rows[series]) : _data.yKeys[series];
    final color = _pie ? theme.pieColor(series) : theme.chartColors[series];
    final value = _pie ? _data.rows[series].y.single : null;
    final label = _pie
        ? '$name  ${value == null || _pieTotal == 0 ? '—' : '${genUiChartTick(value / _pieTotal * 100)}%'}'
        : name;
    final action = hidden
        ? l10n.genuiChartShowSeries(name)
        : l10n.genuiChartHideSeries(name);
    Widget item(Color ink) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: CustomPaint(
            size: Size(_pie ? 10 : 24, 12),
            painter: GenUiChartLegendPainter(
              series: series,
              color: hidden ? theme.disabledInk : color,
              fill: theme.card,
              pie: _pie,
            ),
          ),
        ),
        SizedBox(width: theme.xxs),
        Flexible(
          child: Text(
            label,
            textHeightBehavior: const TextHeightBehavior(
              applyHeightToFirstAscent: false,
              applyHeightToLastDescent: false,
            ),
            style: theme.label.copyWith(
              color: ink,
              decoration: hidden ? TextDecoration.lineThrough : null,
              decorationColor: theme.captionInk,
            ),
          ),
        ),
      ],
    );
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: width),
      child: _scope!.exporting
          ? item(theme.secondaryInk)
          : GenUiControlRegion(
              child: Semantics(
                button: true,
                toggled: !hidden,
                label: action,
                value: _pie ? _value(_data.rows[series].y.single) : null,
                enabled: _interactive,
                onTap: _interactive ? () => _toggle(series) : null,
                child: ExcludeSemantics(
                  child: IosIconButton(
                    key: ValueKey('genui-chart-legend-${widget.id}-$series'),
                    // Legends form a compact list; using a full field height
                    // on every wrapped row leaves a blank line between labels.
                    minSize: 32,
                    padding: EdgeInsets.symmetric(horizontal: theme.xxs),
                    color: hidden ? theme.captionInk : theme.secondaryInk,
                    tooltip: action,
                    enabled: _interactive,
                    onTap: () => _toggle(series),
                    builder: item,
                  ),
                ),
              ),
            ),
    );
  }
}
