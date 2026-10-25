import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_segments.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_numeric_step.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_state.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_expansion.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_slider.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_surface.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_view_tabs.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/theme/theme_factory.dart';

UiSurfaceController _controller(String body) {
  final c =
      UiSurfaceController(
        owner: const UiSurfaceOwner(
          revisionId: 'visual-regression',
          surfaceKey: '0:0',
        ),
      )..updateSource(
        'ui 1 catalog "kelivo.native/1"\n$body\n',
        closed: true,
        generation: UiGenerationStatus.complete,
      );
  addTearDown(c.dispose);
  return c;
}

Widget _app(UiSurfaceController c, {ScrollController? scroll}) => MaterialApp(
  theme: buildLightTheme(null),
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: SingleChildScrollView(
      controller: scroll,
      child: Column(
        children: [
          GenUiExpansion(
            surfaceBuilder: (expand, focus, expanded) => GenUiSurface(
              controller: c,
              onExpand: expand,
              expandFocusNode: focus,
              expanded: expanded,
            ),
          ),
          const SizedBox(
            height: 120,
            child: Center(child: Text('Following message')),
          ),
        ],
      ),
    ),
  ),
);

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .single;
    view.physicalSize = const Size(390, 700);
    view.devicePixelRatio = 1;
    addTearDown(view.reset);
  });

  for (final kind in ['line', 'pie']) {
    testWidgets('long inline $kind card yields vertical drags to the message', (
      tester,
    ) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      final c = _controller(
        '''root = Column(children=[chart,${List.generate(14, (i) => 'm$i').join(',')}])
chart = Chart(kind="$kind",data=[{"x":0,"y":1},{"x":1,"y":2}],x="x",y=["y"])
${List.generate(14, (i) => 'm$i = Metric(label="Result $i",value=$i)').join('\n')}''',
      );
      await tester.pumpWidget(_app(c, scroll: scroll));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(GenUiSurface)).height,
        greaterThan(1200),
      );
      expect(
        find.descendant(
          of: find.byType(GenUiExpansion),
          matching: find.byType(Scrollable),
        ),
        findsNothing,
      );
      await tester.drag(
        find.byKey(const ValueKey('genui-chart-canvas-chart')),
        const Offset(0, -220),
      );
      await tester.pumpAndSettle();
      expect(scroll.offset, greaterThan(100));
      for (var i = 0; i < 5; i++) {
        await tester.dragFrom(const Offset(190, 480), const Offset(0, -450));
        await tester.pumpAndSettle();
      }
      expect(find.text('Following message').hitTestable(), findsOneWidget);
      expect(find.text('Result 13').hitTestable(), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Expand'));
      await tester.tap(find.byTooltip('Expand'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Result 13'));
      await tester.pumpAndSettle();
      expect(find.text('Result 13').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }

  testWidgets(
    'decimal slider steps update a shared editor without binary tails',
    (tester) async {
      final c = _controller(r'''$n: number = -3.2
root = Column(children=[slider,number])
slider = Slider(label="Slope",bind=$n,min=-5,max=5,step=0.1)
number = NumberField(label="Exact slope",bind=$n,step=0.1)''');
      await tester.pumpWidget(_app(c));
      await tester.pumpAndSettle();
      final track = find.descendant(
        of: find.byType(GenUiSlider),
        matching: find.byType(CustomPaint),
      );
      await tester.tap(track);
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      for (var i = 0; i < 19; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      }
      await tester.pumpAndSettle();
      expect(c.captureRead().inputs['n'], -3.1);
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        '-3.1',
      );
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is IosIconButton && w.tooltip == 'Increase Exact slope',
        ),
      );
      await tester.pumpAndSettle();
      expect(c.captureRead().inputs['n'], -3);
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        '-3',
      );
    },
  );

  testWidgets(
    'small chart tabs keep their full touch region and keyboard selection',
    (tester) async {
      final c = _controller(
        'root = Chart(kind="pie",data=[{"x":"Rent","y":5600},{"x":"Food","y":10400}],x="x",y=["y"],donut=true)',
      );
      await tester.pumpWidget(_app(c));
      await tester.pumpAndSettle();
      expect(find.text('16000'), findsOneWidget);
      expect(find.text('1.6e+4'), findsNothing);
      expect(tester.getSize(find.byType(GenUiViewTabs)).width, lessThan(200));
      await tester.tapAt(tester.getCenter(find.text('Data')).translate(0, 21));
      await tester.pumpAndSettle();
      expect(c.state.view['root']?['dataView'], true);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(c.state.view['root']?['dataView'], isNull);
    },
  );

  testWidgets('pie totals and missing legends preserve decimal and null data', (
    tester,
  ) async {
    final c = _controller(
      'root = Chart(kind="pie",data=[{"x":"A","y":0.1},{"x":"B","y":0.2},{"x":"Missing","y":null}],x="x",y=["y"],donut=true)',
    );
    await tester.pumpWidget(_app(c));
    await tester.pumpAndSettle();
    expect(find.text('0.3'), findsOneWidget);
    expect(find.text('Missing  —'), findsOneWidget);
    expect(find.text('Missing  0%'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('decimal total text preserves finite extreme chart geometry', (
    tester,
  ) async {
    final values = [double.maxFinite, ...List.filled(11, 1e291)];
    final rows = [
      for (var i = 0; i < values.length; i++) '{"x":"$i","y":${values[i]}}',
    ].join(',');
    final c = _controller(
      'root = Chart(kind="pie",data=[$rows],x="x",y=["y"],donut=true)',
    );
    await tester.pumpWidget(_app(c));
    await tester.pumpAndSettle();
    final sections = tester
        .widget<PieChart>(find.byType(PieChart))
        .data
        .sections;
    expect(sections, hasLength(12));
    expect(sections.every((s) => s.value.isFinite && s.value > 0), true);
    expect(uiNumericTotalText(values), isNot(contains('Infinity')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('multiline radio options use wrapping rows', (tester) async {
    final c = _controller(
      r'''$mode: string = "a"
root = RadioGroup(label="Mode",bind=$mode,options=[{"value":"a","label":"One\nTwo"},{"value":"b","label":"Three"}])''',
    );
    await tester.pumpWidget(_app(c));
    await tester.pumpAndSettle();
    expect(find.byType(GenUiSegments), findsNothing);
    expect(find.text('One\nTwo'), findsOneWidget);
    await tester.tap(find.text('Three'));
    expect(c.captureRead().inputs['mode'], 'b');
    expect(tester.takeException(), isNull);
  });

  test(
    'decimal steps retain small, large and scientific numeric input ranges',
    () {
      expect(uiNumericStep(-5, .1, 19), -3.1);
      expect(uiNumericStep(.3, .1, -1), .2);
      expect(uiNumericStep(1e-10, 1e-11, 3), 1.3e-10);
      expect(uiNumericStep(1e20, 1e18, 2), 1.02e20);
      expect(uiNumericStep(1e308, 1e308, 1).isFinite, false);
    },
  );
}
