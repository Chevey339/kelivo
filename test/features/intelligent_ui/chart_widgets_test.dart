import 'dart:ui' as ui;
import 'package:fl_chart/fl_chart.dart';
// The exact renderer box makes these real native hit/scroll tests independent
// of assumptions about axis-title layout in the pinned fl_chart version.
// ignore: implementation_imports
import 'package:fl_chart/src/chart/line_chart/line_chart_renderer.dart';
// ignore: implementation_imports
import 'package:fl_chart/src/chart/scatter_chart/scatter_chart_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/features/intelligent_ui/catalog/ui_catalog.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_chart_data.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_state.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/gallery/chart_gallery.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_chart.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_chart_paint.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_surface.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/theme/theme_factory.dart';

UiSurfaceController _controller(String source, {bool readOnly = false}) {
  final c = UiSurfaceController(
    readOnly: readOnly,
    owner: const UiSurfaceOwner(revisionId: 'chart-widget', surfaceKey: '0:0'),
  );
  c.updateSource(
    '${UiCatalog.header}\n$source\n',
    closed: true,
    generation: UiGenerationStatus.complete,
  );
  addTearDown(c.dispose);
  return c;
}

Widget _app(
  UiSurfaceController c, {
  bool dark = false,
  bool rtl = false,
  double scale = 1,
  bool exporting = false,
  ScrollController? scroll,
}) => MaterialApp(
  theme: dark ? buildDarkTheme(null) : buildLightTheme(null),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(disableAnimations: true, textScaler: TextScaler.linear(scale)),
    child: Directionality(
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      child: child!,
    ),
  ),
  home: Scaffold(
    body: SingleChildScrollView(
      controller: scroll,
      child: SizedBox(
        width: 390,
        child: Column(
          children: [
            GenUiSurface(controller: c, exporting: exporting),
            if (scroll != null) const SizedBox(height: 1400),
          ],
        ),
      ),
    ),
  ),
);
Offset _linePoint(WidgetTester tester, int row, int series) {
  final chart = tester.widget<LineChart>(find.byType(LineChart));
  final rect = tester.getRect(find.byType(LineChartLeaf));
  final d = chart.data, spot = d.lineBarsData[series].spots[row];
  return rect.topLeft +
      Offset(
        (spot.x - d.minX) / (d.maxX - d.minX) * rect.width,
        (d.maxY - spot.y) / (d.maxY - d.minY) * rect.height,
      );
}

Offset _scatterPoint(WidgetTester tester, int point) {
  final d = tester.widget<ScatterChart>(find.byType(ScatterChart)).data;
  final rect = tester.getRect(find.byType(ScatterChartLeaf));
  final spot = d.scatterSpots[point];
  return rect.topLeft +
      Offset(
        (spot.x - d.minX) / (d.maxX - d.minX) * rect.width,
        (d.maxY - spot.y) / (d.maxY - d.minY) * rect.height,
      );
}

void main() {
  testWidgets('overlapping source rows do not repeat every decorative marker', (
    tester,
  ) async {
    final c = _controller(
      'root = Chart(kind="line",data=[${List.filled(500, '{"x":1,"y":1}').join(',')}],x="x",y=["y"])',
    );
    await tester.pumpWidget(_app(c));
    await tester.pumpAndSettle();
    final rendered = tester.widget<LineChartLeaf>(find.byType(LineChartLeaf));
    final bar = rendered.data.lineBarsData.single;
    expect(bar.spots, hasLength(500));
    expect(
      bar.spots.where((spot) => bar.dotData.checkToShowDot(spot, bar)),
      hasLength(2),
    );
  });

  testWidgets('dense line markers preserve vertices, gaps and hit targets', (
    tester,
  ) async {
    final rows = List.generate(
      500,
      (i) => '{"x":$i,"y":${i == 10 ? 'null' : i}}',
    ).join(',');
    final c = _controller(
      'root = Chart(kind="line",data=[$rows],x="x",y=["y"])',
    );
    await tester.pumpWidget(_app(c));
    await tester.pumpAndSettle();
    LineChartBarData bar() => tester
        .widget<LineChart>(find.byType(LineChart))
        .data
        .lineBarsData
        .single;
    bool marked(int row) =>
        bar().dotData.checkToShowDot(bar().spots[row], bar());
    expect(bar().spots, hasLength(500));
    expect(bar().spots[10], FlSpot.nullSpot);
    expect([0, 9, 11, 499].every(marked), isTrue);
    expect(
      bar().spots
          .where((s) => s.isNotNull() && bar().dotData.checkToShowDot(s, bar()))
          .length,
      lessThan(50),
    );
    final row = List.generate(450, (i) => i + 20).firstWhere((i) => !marked(i));
    final mouse = await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    final position = _linePoint(tester, row, 0);
    final base = tester.widget<LineChart>(find.byType(LineChart));
    await mouse.moveTo(position);
    await tester.pumpAndSettle();
    expect(find.text('x: $row · y: $row'), findsOneWidget);
    final marker = find.byKey(const ValueKey('genui-chart-active-marker'));
    expect(marker, findsOneWidget);
    final paint =
        tester.widget<CustomPaint>(marker).painter! as GenUiChartMarkerPainter;
    expect(
      (tester.getTopLeft(marker) + paint.point - position).distance,
      lessThan(.01),
    );
    expect(tester.widget<LineChart>(find.byType(LineChart)), same(base));
    expect(bar().spots, hasLength(500));
    await mouse.removePointer();
  });

  test('opposite-direction area segments do not cancel overlapping fills', () {
    final data = UiChartData.read({
      'kind': 'area',
      'x': 'x',
      'y': ['y'],
      'data': [
        {'x': 0, 'y': 1},
        {'x': 2, 'y': 1},
        {'x': 1, 'y': null},
        {'x': 2, 'y': 1},
        {'x': 0, 'y': 1},
      ],
    });
    final painter = GenUiChartAreaPainter(
      data: data,
      colors: const [Color(0xff000000)],
    );
    final paths = painter.pathsForSeries(const Size(300, 200), 0).toList();
    final center = Offset(
      data.xAxis.fraction(1) * 300,
      (1 - data.yAxis.fraction(.5)) * 200,
    );
    expect(paths, hasLength(2));
    expect(paths.every((p) => p.contains(center)), isTrue);
  });
  test(
    'area contours close at zero on both signs and never fill a null gap',
    () {
      final data = UiChartData.read({
        'kind': 'area',
        'x': 'x',
        'y': ['y'],
        'data': [
          {'x': 0, 'y': 2},
          {'x': 1, 'y': -2},
          {'x': 2, 'y': null},
          {'x': 3, 'y': -2},
          {'x': 4, 'y': -2},
        ],
      });
      final painter = GenUiChartAreaPainter(
        data: data,
        colors: const [Color(0xff000000)],
      );
      const size = Size(300, 200);
      Offset pixel(double x, double y) => Offset(
        data.xAxis.fraction(x) * size.width,
        (1 - data.yAxis.fraction(y)) * size.height,
      );
      final paths = painter.pathsForSeries(size, 0).toList();
      bool contains(double x, double y) =>
          paths.any((p) => p.contains(pixel(x, y)));
      expect(contains(.1, .5), isTrue);
      expect(contains(.9, -.5), isTrue);
      expect(contains(3.5, -1), isTrue);
      expect(contains(2, -1), isFalse);
      expect(contains(3.5, 1), isFalse);
    },
  );
  testWidgets('axis units remain visible and accessible in read-only exports', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final c = _controller(
        'root = Chart(kind="line",unit="USD",x="x",y=["y"],data=[{"x":0,"y":2},{"x":1,"y":3}])',
        readOnly: true,
      );
      await tester.pumpWidget(_app(c, exporting: true));
      await tester.pumpAndSettle();
      expect(find.text('USD'), findsOneWidget);
      expect(find.bySemanticsLabel('USD'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });
  testWidgets('title words do not hide axis labels or units in exports', (
    tester,
  ) async {
    final c = _controller(
      'root = Chart(kind="line",title="Commuting distance",yLabel="distance",unit="m",x="x",y=["y"],data=[{"x":0,"y":2},{"x":1,"y":3}])',
      readOnly: true,
    );
    await tester.pumpWidget(_app(c, exporting: true));
    await tester.pumpAndSettle();
    expect(find.text('distance · m'), findsOneWidget);
  });
  testWidgets(
    'changing from Cartesian to pie clears selection before real pie hits',
    (tester) async {
      final c = _controller(r'''$kind: string = "line"
root = Chart(kind=$kind,x="x",y=["y"],data=[{"x":0,"y":2},{"x":1,"y":3}])''');
      await tester.pumpWidget(_app(c));
      await tester.pumpAndSettle();
      await tester.tapAt(_linePoint(tester, 1, 0));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('genui-chart-tooltip-root')),
        findsOneWidget,
      );
      c.setInputs({'kind': 'pie'}, token: c.token);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('genui-chart-tooltip-root')),
        findsNothing,
      );
      final pie = tester.widget<PieChart>(find.byType(PieChart));
      expect(pie.data.sections.every((s) => s.color.a == 1), isTrue);
      await tester.tapAt(
        tester.getCenter(find.byType(PieChart)) + const Offset(60, -20),
      );
      await tester.pumpAndSettle();
      expect(find.text('0: 2 (40%)'), findsOneWidget);
    },
  );
  for (final kind in [
    'line',
    'area',
    'bar',
    'scatter',
    'pie',
    'gaps',
    'empty',
    'invalid',
  ]) {
    testWidgets('$kind gallery renders through the real node/surface', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = _controller(genUiChartGallerySources[kind]!);
      await tester.pumpWidget(_app(c));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(c.parsed.program.diagnostics, isEmpty);
      if (kind != 'invalid') expect(find.byType(GenUiChart), findsOneWidget);
    });
  }
  testWidgets(
    'line native point hit shows exact row values and dims only other series',
    (tester) async {
      final c = _controller(
        'root = Chart(kind="line",x="x",y=["A","B"],unit="u",data=[{"x":0,"A":1,"B":4},{"x":2,"A":3,"B":null},{"x":10,"A":2,"B":5}])',
      );
      await tester.pumpWidget(_app(c));
      await tester.pumpAndSettle();
      await tester.tapAt(_linePoint(tester, 1, 0));
      await tester.pumpAndSettle();
      expect(find.text('x: 2 · A: 3 u · B: —'), findsOneWidget);
      final data = tester.widget<LineChart>(find.byType(LineChart)).data;
      expect(data.lineBarsData[0].color!.a, 1);
      expect(data.lineBarsData[1].color!.a, closeTo(.35, .01));
      expect(data.lineBarsData[1].spots[1], FlSpot.nullSpot);
      await tester.pumpWidget(_app(c, dark: true, rtl: true, scale: 1.3));
      await tester.pumpAndSettle();
      expect(find.text('x: 2 · A: 3 u · B: —'), findsOneWidget);
      expect(
        _linePoint(tester, 0, 0).dx,
        lessThan(_linePoint(tester, 2, 0).dx),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'legend semantic actions toggle persisted visibility and expose pie values',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final c = _controller(genUiChartGallerySources['pie']!);
        await tester.pumpWidget(_app(c));
        await tester.pumpAndSettle();
        final node = tester.getSemantics(find.bySemanticsLabel('Hide Online'));
        expect(
          node.getSemanticsData().hasAction(ui.SemanticsAction.tap),
          isTrue,
        );
        expect(node.getSemanticsData().value, '280 k');
        tester.binding.performSemanticsAction(
          ui.SemanticsActionEvent(
            type: ui.SemanticsAction.tap,
            nodeId: node.id,
            viewId: tester.view.viewId,
          ),
        );
        await tester.pumpAndSettle();
        expect(c.state.view['root']?['hiddenSeries'], [0]);
        expect(
          tester.widget<PieChart>(find.byType(PieChart)).data.sections,
          hasLength(2),
        );
        expect(find.bySemanticsLabel('Show Online'), findsOneWidget);
      } finally {
        semantics.dispose();
      }
    },
  );
  for (final kind in ['line', 'bar', 'scatter', 'pie']) {
    testWidgets(
      '$kind allows the message to scroll when dragged over its canvas',
      (tester) async {
        final scroll = ScrollController();
        addTearDown(scroll.dispose);
        final c = _controller(genUiChartGallerySources[kind]!);
        await tester.pumpWidget(_app(c, scroll: scroll));
        await tester.pumpAndSettle();
        await tester.drag(
          find.byKey(const ValueKey('genui-chart-canvas-root')),
          const Offset(0, -150),
        );
        await tester.pumpAndSettle();
        expect(scroll.offset, greaterThan(50));
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('zero-valued bar is hit at its marker without inventing height', (
    tester,
  ) async {
    final c = _controller(
      'root = Chart(kind="bar",x="x",y=["A"],data=[{"x":0,"A":0},{"x":1,"A":3}])',
    );
    await tester.pumpWidget(_app(c));
    await tester.pumpAndSettle();
    await tester.tapAt(_scatterPoint(tester, 0));
    await tester.pumpAndSettle();
    expect(find.text('x: 0 · A: 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'grouped numeric bars stay in the plot and both signs meet the same zero baseline',
    (tester) async {
      final c = _controller(
        'root = Chart(kind="bar",x="x",y=["A","B","C","D"],data=[{"x":0,"A":3,"B":-2,"C":1,"D":0},{"x":1,"A":2,"B":-1,"C":4,"D":1}])',
      );
      await tester.pumpWidget(_app(c));
      await tester.pumpAndSettle();
      final chart = tester.widget<ScatterChart>(find.byType(ScatterChart));
      final plot = tester.getRect(find.byType(ScatterChartLeaf));
      final axis = c.nodes['root']!.chartData!.yAxis;
      final zero =
          plot.top +
          (chart.data.maxY - axis.coordinate(0)) /
              (chart.data.maxY - chart.data.minY) *
              plot.height;
      for (var i = 0; i < chart.data.scatterSpots.length; i++) {
        final glyph = chart.data.scatterSpots[i].dotPainter as GenUiBarDot;
        final point = _scatterPoint(tester, i);
        expect(
          point.dx - glyph.width / 2,
          greaterThanOrEqualTo(plot.left - .01),
        );
        expect(point.dx + glyph.width / 2, lessThanOrEqualTo(plot.right + .01));
        expect(point.dy + glyph.baselineDelta, closeTo(zero, .01));
      }
      final negative = chart.data.scatterSpots[1].dotPainter as GenUiBarDot;
      await tester.tapAt(
        _scatterPoint(tester, 1) + Offset(0, negative.baselineDelta / 2),
      );
      await tester.pumpAndSettle();
      expect(find.text('x: 0 · A: 3 · B: -2 · C: 1 · D: 0'), findsOneWidget);
      final selected = tester
          .widget<ScatterChart>(find.byType(ScatterChart))
          .data;
      expect(selected.scatterSpots[1].dotPainter.mainColor.a, 1);
      expect(
        selected.scatterSpots[0].dotPainter.mainColor.a,
        closeTo(.35, .01),
      );
    },
  );
  testWidgets(
    'hidden scatter points cannot steal a hit from a visible overlapping series',
    (tester) async {
      final c = _controller(
        'root = Chart(kind="scatter",x="x",y=["A","B"],data=[{"x":0,"A":2,"B":2}])',
      );
      await tester.pumpWidget(_app(c));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('genui-chart-legend-root-1')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ScatterChart>(find.byType(ScatterChart))
            .data
            .scatterSpots,
        hasLength(1),
      );
      await tester.tapAt(_scatterPoint(tester, 0));
      await tester.pumpAndSettle();
      expect(find.text('x: 0 · A: 2 · B: 2'), findsOneWidget);
      final snapshot = c.captureSnapshot();
      final reopened = _controller(
        c.parsed.source.substring(UiCatalog.header.length + 1).trimRight(),
      );
      expect(reopened.restore(snapshot, token: reopened.restoreToken), isTrue);
      await tester.pumpWidget(_app(reopened));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ScatterChart>(find.byType(ScatterChart))
            .data
            .scatterSpots,
        hasLength(1),
      );
      expect(
        find.byKey(const ValueKey('genui-chart-tooltip-root')),
        findsNothing,
      );
      reopened.reset(token: reopened.token);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ScatterChart>(find.byType(ScatterChart))
            .data
            .scatterSpots,
        hasLength(2),
      );
    },
  );
  testWidgets(
    'keyboard reads missing rows and escape/reset clear point selection',
    (tester) async {
      final c = _controller(
        'root = Chart(kind="line",x="x",y=["A"],data=[{"x":0,"A":1},{"x":1,"A":null},{"x":2,"A":3}])',
      );
      await tester.pumpWidget(_app(c, rtl: true));
      await tester.pumpAndSettle();
      await tester.tapAt(_linePoint(tester, 0, 0));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('x: 1 · A: —'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      expect(find.text('x: 2 · A: 3'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('genui-chart-tooltip-root')),
        findsNothing,
      );
      await tester.tapAt(_linePoint(tester, 0, 0));
      await tester.pumpAndSettle();
      c.reset(token: c.token);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('genui-chart-tooltip-root')),
        findsNothing,
      );
    },
  );
  testWidgets(
    'streaming and export have no pointer work or action buttons; completion unlocks',
    (tester) async {
      final c = _controller(genUiChartGallerySources['line']!);
      c.updateSource(
        c.parsed.source,
        closed: true,
        generation: UiGenerationStatus.generating,
      );
      await tester.pumpWidget(_app(c));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<LineChart>(find.byType(LineChart))
            .data
            .lineTouchData
            .touchCallback,
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('genui-chart-legend-root-0')));
      await tester.pump();
      expect(c.state.view, isEmpty);
      c.updateSource(
        c.parsed.source,
        closed: true,
        generation: UiGenerationStatus.complete,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('genui-chart-legend-root-0')));
      await tester.pumpAndSettle();
      expect(c.state.view['root']?['hiddenSeries'], [0]);
      await tester.pumpWidget(_app(c, exporting: true));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('genui-chart-legend-root-1')),
        findsNothing,
      );
      expect(
        tester
            .widget<LineChart>(find.byType(LineChart))
            .data
            .lineTouchData
            .touchCallback,
        isNull,
      );
    },
  );
  testWidgets(
    'dynamic bar and scatter kinds can replace their painter without an animation exception',
    (tester) async {
      final c = _controller(r'''$kind: string = "bar"
root = Chart(kind=$kind,x="x",y=["A"],data=[{"x":0,"A":1},{"x":2,"A":3}])''');
      await tester.pumpWidget(_app(c));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ScatterChart>(find.byType(ScatterChart))
            .data
            .scatterSpots
            .first
            .dotPainter,
        isA<GenUiBarDot>(),
      );
      c.setInputs({'kind': 'scatter'}, token: c.token);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ScatterChart>(find.byType(ScatterChart))
            .data
            .scatterSpots
            .first
            .dotPainter,
        isNot(isA<GenUiBarDot>()),
      );
      await tester.tapAt(_scatterPoint(tester, 1));
      await tester.pumpAndSettle();
      expect(find.text('x: 2 · A: 3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('sampled domain gaps remain null in the real native path', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = _controller(genUiChartGallerySources['gaps']!);
    await tester.pumpWidget(_app(c));
    await tester.pumpAndSettle();
    final d = c.nodes['curve']!.chartData!;
    expect(d.sampled, isTrue);
    expect(d.domainRows, hasLength(19));
    final line = tester.widget<LineChart>(find.byType(LineChart)).data;
    expect(
      line.lineBarsData.single.spots.where((p) => p == FlSpot.nullSpot),
      hasLength(19),
    );
    final bar = line.lineBarsData.single;
    expect(
      bar.spots.where(
        (p) => p.isNotNull() && bar.dotData.checkToShowDot(p, bar),
      ),
      isEmpty,
    );
    await tester.tapAt(_linePoint(tester, 8, 0));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('genui-chart-tooltip-curve')),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is GenUiChartGapPainter,
      ),
      findsOneWidget,
    );
  });
}
