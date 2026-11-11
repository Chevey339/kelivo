import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markstream/markstream.dart' as ms;
import 'package:Kelivo/features/intelligent_ui/catalog/ui_catalog.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_state.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_content.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_layout.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_node.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_surface.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_theme.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/theme/theme_factory.dart';

UiSurfaceController _controller(String source) {
  final controller = UiSurfaceController(
    owner: const UiSurfaceOwner(revisionId: 'widgets', surfaceKey: '0:0'),
  );
  controller.updateSource(
    '${UiCatalog.header}\n$source',
    closed: true,
    generation: UiGenerationStatus.complete,
  );
  addTearDown(controller.dispose);
  return controller;
}

Widget _app(
  Widget child, {
  double width = 700,
  double scale = 1,
  bool dark = false,
  bool rtl = false,
}) => MaterialApp(
  theme: dark ? buildDarkTheme(null) : buildLightTheme(null),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: true),
      child: Directionality(
        textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: SingleChildScrollView(
                child: SelectionArea(child: GenUiThemeScope(child: child)),
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('all ten layout/content types render from a resolved controller', (
    tester,
  ) async {
    final c = _controller(
      r'''root = Column(children=[heading,row,section,rule,markdown,formula,badge,callout])
$a: number = 2
let value = $a * 2
heading = Text(text="Example title", variant="title")
row = Row(children=[metric,other])
metric = Metric(label="Result", value=value, digits=2, unit="u")
other = Text(text="Independent")
section = Section(title="Section", subtitle="Grouped content", tone="primary", children=[caption])
caption = Text(text="Caption", variant="caption")
rule = Divider(label="Details")
markdown = Markdown(text="**Local** results")
formula = Formula(tex="x^2 + 1")
badge = Badge(text="Ready", tone="success")
callout = Callout(title="Example", text="Synthetic values", tone="info")''',
    );
    await tester.pumpWidget(_app(GenUiNode(controller: c, id: 'root')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final type in [
      GenUiColumn,
      GenUiRow,
      GenUiSection,
      GenUiDivider,
      GenUiText,
      GenUiMarkdown,
      GenUiFormula,
      GenUiMetric,
      GenUiBadge,
      GenUiCallout,
    ]) {
      expect(find.byType(type), findsWidgets);
    }
    expect(find.text('4.00'), findsOneWidget);
    c.setInputs({'a': 4}, token: c.token);
    await tester.pump();
    expect(find.text('8.00'), findsOneWidget);
    await tester.pumpWidget(
      _app(
        GenUiNode(controller: c, id: 'root'),
        scale: 1.3,
        dark: true,
        rtl: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('8.00'), findsOneWidget);
    expect(c.captureRead().inputs['a'], 4);
  });

  testWidgets(
    'rows wrap for narrow containers and large text without shrinking',
    (tester) async {
      Widget row() => const GenUiRow(
        children: [
          GenUiMetric(label: 'A', value: 1),
          GenUiMetric(label: 'B', value: 2),
        ],
      );
      await tester.pumpWidget(_app(row(), width: 700));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('A')).dy,
        tester.getTopLeft(find.text('B')).dy,
      );
      for (final (width, scale) in [(320.0, 1.0), (700.0, 1.3)]) {
        await tester.pumpWidget(_app(row(), width: width, scale: scale));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          tester.getTopLeft(find.text('A')).dy,
          lessThan(tester.getTopLeft(find.text('B')).dy),
        );
        expect(tester.widget<Text>(find.text('1')).style!.fontSize, 26);
      }
    },
  );

  testWidgets(
    'RTL mirrors row order while numeric text retains LTR direction',
    (tester) async {
      await tester.pumpWidget(
        _app(
          const GenUiRow(
            children: [
              GenUiMetric(label: 'A', value: -12),
              GenUiMetric(label: 'B', value: 3),
            ],
          ),
          rtl: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('A')).dx,
        greaterThan(tester.getTopLeft(find.text('B')).dx),
      );
      expect(
        tester.widget<Text>(find.text('-12')).textDirection,
        TextDirection.ltr,
      );
    },
  );

  testWidgets(
    'Metric exposes the latest display immediately and throttles announcements',
    (tester) async {
      final handle = tester.ensureSemantics();
      final c = _controller(r'''$a: number = 1
root = Metric(label="Result", value=$a, unit="u")''');
      await tester.pumpWidget(_app(GenUiNode(controller: c, id: 'root')));
      await tester.pumpAndSettle();
      String label() => tester
          .getSemantics(find.byType(GenUiMetric))
          .getSemanticsData()
          .label;
      expect(label(), 'Result 1 u');
      c.setInputs({'a': 2}, token: c.token);
      await tester.pump();
      expect(find.text('2'), findsOneWidget);
      expect(label(), 'Result 1 u');
      c.setInputs({'a': 3}, token: c.token);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(label(), 'Result 3 u');
      handle.dispose();
    },
  );

  testWidgets('nested UI fences stay ordinary code inside Markdown', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const GenUiMarkdown(
          text:
              '```kelivo-ui\nui 1 catalog "kelivo.native/1"\nroot = Metric(label="Nested", value=3)\n```',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ms.MarkstreamCodeBlock), findsOneWidget);
    expect(find.byType(GenUiMetric), findsNothing);
    expect(find.byType(GenUiNode), findsNothing);
  });

  testWidgets(
    'surface export includes every Markdown row and removes formula source actions',
    (tester) async {
      final markdown = [
        '| Row | Value |',
        '| --- | --- |',
        for (var i = 1; i <= 100; i++) '| Row $i | $i |',
      ].join('\n');
      final c = _controller(
        'root = Column(children=[markdown,invalid,styled])\n'
        'markdown = Markdown(text=${jsonEncode(markdown)})\n'
        'invalid = Formula(tex=${jsonEncode(r'\frac{')})\n'
        'styled = Formula(tex=${jsonEncode(r'\textcolor{red}{x}')})',
      );
      for (final exporting in [true, false, true]) {
        await tester.pumpWidget(
          _app(GenUiSurface(controller: c, exporting: exporting)),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final table = tester.widget<Table>(find.byType(Table));
        expect(
          table.children.length,
          exporting ? 101 : ms.PerformanceLimits.initialTableRows,
        );
        expect(
          find.text('Row 100', findRichText: true),
          exporting ? findsOneWidget : findsNothing,
        );
        expect(find.byType(GenUiSource), findsNWidgets(2));
        for (final source in tester.widgetList<GenUiSource>(
          find.byType(GenUiSource),
        )) {
          expect(source.exporting, exporting);
        }
        for (final view in tester.widgetList<ms.MarkstreamView>(
          find.byType(ms.MarkstreamView),
        )) {
          expect(view.exporting, exporting);
          expect(view.cullToViewport, !exporting);
        }
        expect(
          find.byType(ms.MarkstreamActionButton),
          exporting ? findsNothing : findsWidgets,
        );
      }
    },
  );

  testWidgets(
    'standalone content retains ordinary Markdown and source actions',
    (tester) async {
      final markdown = [
        '| Row |',
        '| --- |',
        for (var i = 1; i <= 100; i++) '| Row $i |',
      ].join('\n');
      for (final child in [
        GenUiMarkdown(text: markdown),
        const GenUiFormula(tex: r'\frac{'),
      ]) {
        await tester.pumpWidget(_app(child));
        await tester.pumpAndSettle();
        final view = tester.widget<ms.MarkstreamView>(
          find.byType(ms.MarkstreamView),
        );
        expect(view.exporting, isFalse);
        expect(view.cullToViewport, isTrue);
        expect(find.byType(ms.MarkstreamActionButton), findsWidgets);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'invalid and presentation-changing formulas expose their source',
    (tester) async {
      for (final tex in [
        r'\frac{',
        r'\textcolor{red}{x}',
        r'\fontsize{99px}{1em}x',
        r'\raisebox{100000pt}{x}',
        r'\hskip{100000pt}',
        r'\mkern{100000mu}',
        r'\footnotesize x',
        r'\genfrac{(}{)}{99pt}{0}{a}{b}',
        r'\begin{matrix}a\\[100000pt]b\end{matrix}',
        r'\newcommand{\f}{x}\f',
      ]) {
        await tester.pumpWidget(_app(GenUiFormula(tex: tex)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text("This formula can't be displayed"), findsOneWidget);
        expect(find.byType(GenUiSource), findsOneWidget);
      }
      await tester.pumpWidget(_app(const GenUiFormula(tex: r'x^2 + 1')));
      await tester.pumpAndSettle();
      expect(find.byType(Math), findsOneWidget);
      expect(find.byType(GenUiSource), findsNothing);
    },
  );

  testWidgets('formula description and TeX participate in selection', (
    tester,
  ) async {
    String selected = '';
    await tester.pumpWidget(
      _app(
        SelectionArea(
          onSelectionChanged: (content) => selected = content?.plainText ?? '',
          child: const GenUiFormula(tex: r'x^2 + 1', label: 'Example formula'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Example formula'), findsOneWidget);
    tester
        .state<SelectableRegionState>(find.byType(SelectableRegion).last)
        .selectAll(SelectionChangedCause.keyboard);
    await tester.pump();
    expect(selected, contains('x^2 + 1'));
  });

  testWidgets('conditional children disappear without leaving a layout gap', (
    tester,
  ) async {
    final c = _controller(r'''root = Column(children=[a,b,c])
$show: boolean = true
a = Text(text="First")
b = Text(text="Conditional", visible=$show)
c = Text(text="Last")''');
    await tester.pumpWidget(_app(GenUiNode(controller: c, id: 'root')));
    await tester.pumpAndSettle();
    final before =
        tester.getTopLeft(find.text('Last')).dy -
        tester.getTopLeft(find.text('First')).dy;
    c.setInputs({'show': false}, token: c.token);
    await tester.pump();
    expect(find.text('Conditional'), findsNothing);
    final after =
        tester.getTopLeft(find.text('Last')).dy -
        tester.getTopLeft(find.text('First')).dy;
    expect(after, lessThan(before - 12));
  });
}
