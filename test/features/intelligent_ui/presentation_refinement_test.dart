import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_chart_data.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_state.dart';
import 'package:Kelivo/features/intelligent_ui/text/ui_number_display.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_expansion.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_surface.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_web_card.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/gallery/review_gallery.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/theme/theme_factory.dart';
import '../../support/business_test_harness.dart';

UiSurfaceController controller(String body) {
  final c =
      UiSurfaceController(
        owner: const UiSurfaceOwner(
          revisionId: 'refinement',
          surfaceKey: '0:0',
        ),
      )..updateSource(
        '${body.startsWith('ui ') ? '' : 'ui 1 catalog "kelivo.native/1"\n'}$body\n',
        closed: true,
        generation: UiGenerationStatus.complete,
      );
  addTearDown(c.dispose);
  return c;
}

Widget app(Widget child, {double scale = 1}) => MaterialApp(
  theme: buildLightTheme(null),
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(
    body: SingleChildScrollView(child: SizedBox(width: 390, child: child)),
  ),
);

void main() {
  for (final scale in [1.0, 1.3]) {
    testWidgets('donut constrains long units without overflowing at $scale', (
      tester,
    ) async {
      final c = controller(
        'root = Chart(kind="pie",donut=true,unit="千克二氧化碳当量/人/年",data=[{"x":"A","y":3500},{"x":"B","y":1500}],x="x",y=["y"])',
      );
      await tester.pumpWidget(app(GenUiSurface(controller: c), scale: scale));
      await tester.pumpAndSettle();
      final focus = find.byWidgetPredicate(
        (w) => w is Focus && w.focusNode?.debugLabel == 'GenUI chart',
      );
      tester.widget<Focus>(focus).focusNode!.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pumpAndSettle();
      expect(find.text('3500'), findsOneWidget);
      expect(tester.getSize(find.text('3500')).width, greaterThan(20));
      expect(tester.takeException(), isNull);
    });
  }
  test(
    'presentation removes arithmetic noise but preserves distinct integers and meaningful decimals',
    () {
      expect(genUiDisplayNumber(5499.999999999999), '5500');
      expect(genUiDisplayNumber(1234567890123.0), '1234567890123');
      expect(genUiDisplayNumber(1234567890124.0), '1234567890124');
      expect(genUiDisplayNumber(1.123456789012345), '1.123456789012345');
      expect(genUiDisplayNumber(1e-20), '1e-20');
      expect(
        genUiDisplayTotal([
          5500 * .35,
          5500 * .25,
          5500 * .12,
          5500 * .1,
          5500 * .18,
        ]),
        '5500',
      );
      expect(genUiDisplayNumber(1.2345, digits: 2), '1.23');
    },
  );
  test(
    'nice ticks retain subnormal, large adjacent and opposing finite domains',
    () {
      for (final values in [
        [0.0, 5e-324],
        [1e300, 1.0000000000000002e300],
        [-double.maxFinite, double.maxFinite],
        [12.4, 30.3],
      ]) {
        final d = UiChartData.read({
          'kind': 'line',
          'x': 'x',
          'y': ['y'],
          'data': [
            for (var i = 0; i < values.length; i++) {'x': i, 'y': values[i]},
          ],
        });
        expect(d.yAxis.maximum, greaterThan(d.yAxis.minimum));
        expect(d.yAxis.minimum.isFinite && d.yAxis.maximum.isFinite, true);
        for (final value in values) {
          expect(d.yAxis.fraction(value).isFinite, true);
        }
      }
    },
  );
  test('header setting persists and keeps the default enabled', () async {
    final preferences = createBusinessTestPreferences();
    final settings = SettingsProvider(preferences);
    await settings.loaded;
    expect(settings.showGenUiHeader, true);
    await settings.setShowGenUiHeader(false);
    final reopened = SettingsProvider(preferences);
    await reopened.loaded;
    expect(reopened.showGenUiHeader, false);
    settings.dispose();
    reopened.dispose();
  });
  testWidgets(
    'immersive chrome preserves input state and source/expand actions',
    (tester) async {
      final c = controller(
        r'$n: number = 1'
        '\nroot = NumberField(label="Value",bind=\$n)',
      );
      final header = ValueNotifier(true);
      addTearDown(header.dispose);
      await tester.pumpWidget(
        app(
          ValueListenableBuilder(
            valueListenable: header,
            builder: (_, shown, _) => GenUiExpansion(
              surfaceBuilder: (expand, focus, expanded) => GenUiSurface(
                controller: c,
                showHeader: shown,
                onExpand: expand,
                expandFocusNode: focus,
                expanded: expanded,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), '7');
      header.value = false;
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('genui-surface-header')), findsNothing);
      expect(c.captureRead().inputs['n'], 7);
      final more = find.byKey(const ValueKey('genui-immersive-more'));
      await tester.tap(more);
      await tester.pumpAndSettle();
      await tester.tap(find.text('View source'));
      await tester.pumpAndSettle();
      expect(find.text('View source'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.tap(more);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Expand'));
      await tester.pumpAndSettle();
      expect(find.text('Shares the same state as the message'), findsOneWidget);
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        '7',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(more, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('short table omits pagination; long table pager stays in one row', (
    tester,
  ) async {
    final c = controller(
      'root = DataTable(data=[${List.generate(12, (i) => '{"id":$i,"name":"Row $i"}').join(',')}],rowKey="id",filterable=true,columns=[{"key":"name","label":"Name"}])',
    );
    await tester.pumpWidget(app(GenUiSurface(controller: c)));
    await tester.pumpAndSettle();
    final size = find.byKey(const ValueKey('genui-table-page-size-root'));
    final next = find.byKey(const ValueKey('genui-table-next-root'));
    expect(tester.getCenter(size).dy, tester.getCenter(next).dy);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(find.text('Row 11'), findsOneWidget);
    await tester.tap(size);
    await tester.pumpAndSettle();
    await tester.tap(find.text('20/page'));
    await tester.pumpAndSettle();
    expect(size, findsOneWidget);
    expect(next, findsNothing);
    await tester.enterText(find.byType(EditableText), 'Row 11');
    await tester.pumpAndSettle();
    expect(find.text('Row 11'), findsWidgets);
    expect(size, findsNothing);
    expect(next, findsNothing);
    c.updateSource(
      'ui 1 catalog "kelivo.native/1"\nroot = DataTable(data=[{"id":1}],rowKey="id",columns=[{"key":"id","label":"ID"}])\n',
      closed: true,
      generation: UiGenerationStatus.complete,
    );
    await tester.pumpAndSettle();
    expect(size, findsNothing);
    expect(next, findsNothing);
  });
  testWidgets(
    'donut center selects values and retains unit and missing-value keyboard access',
    (tester) async {
      final c = controller(
        r'$second: number? = 250'
        '\nroot = Chart(kind="pie",title="Costs",data=[{"x":"A","y":100},{"x":"B","y":\$second}],x="x",y=["y"],unit="USD",donut=true)',
      );
      await tester.pumpWidget(app(GenUiSurface(controller: c)));
      await tester.pumpAndSettle();
      final focus = find.byWidgetPredicate(
        (w) => w is Focus && w.focusNode?.debugLabel == 'GenUI chart',
      );
      tester.widget<Focus>(focus).focusNode!.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      expect(find.text('B'), findsOneWidget);
      expect(find.text('250'), findsOneWidget);
      expect(find.text('USD'), findsOneWidget);
      expect(find.text('71.43%'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('genui-chart-tooltip-root')),
        findsNothing,
      );
      c.setInputs({'second': null}, token: c.token);
      await tester.pumpAndSettle();
      expect(find.text('—'), findsOneWidget);
      expect(find.text('USD'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Web action retains the outer edge of its 44dp touch target', (
    tester,
  ) async {
    var clicks = 0;
    await tester.pumpWidget(
      app(
        GenUiWebOpenButton(label: 'Open', enabled: true, onTap: () => clicks++),
      ),
    );
    final button = find.byType(GenUiWebOpenButton);
    expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
    await tester.tapAt(tester.getCenter(button).translate(0, 21));
    expect(clicks, 1);
  });
  test(
    'native visual budget fixture is valid and has the user-reported total',
    () {
      final c = controller(genUiReviewBudget);
      expect(c.phase, SurfacePhase.complete);
      expect(
        genUiDisplayTotal(
          c.nodes['chart']!.chartData!.rows.map((r) => r.y.single!),
        ),
        '5500',
      );
    },
  );
}
