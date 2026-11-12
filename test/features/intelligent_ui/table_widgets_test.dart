import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/features/intelligent_ui/catalog/ui_catalog.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_state.dart';
import 'package:Kelivo/features/intelligent_ui/text/ui_text_projection.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_surface.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_table.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_view_tabs.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_theme.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_text_button.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/theme/theme_factory.dart';
import '../../support/genui_projection_fixture.dart';

String _source({int rows = 35, bool note = false, bool chart = false}) {
  final data = jsonEncode([
    for (var i = 0; i < rows; i++)
      {
        'id': 'k$i',
        'name': 'Item ${i.toString().padLeft(2, '0')}',
        'price': i == 2 ? null : i + 0.234,
      },
  ]);
  return '${note ? '\$note: string = ""\n' : ''}root = ${chart ? 'Chart(kind="line",x="name",y=["price"],data=$data)' : 'DataTable(data=$data,rowKey="id",columns=[{"key":"name","label":"Name"},{"key":"price","label":"Price","digits":2}])'}';
}

UiSurfaceController _controller(String source) {
  final c = UiSurfaceController(
    owner: const UiSurfaceOwner(revisionId: 'table-widget', surfaceKey: '0:0'),
  );
  c.updateSource(
    '${UiCatalog.header}\n${source.trimRight()}\n',
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
}) => MaterialApp(
  theme: dark ? buildDarkTheme(null) : buildLightTheme(null),
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
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
      child: GenUiSurface(controller: c, exporting: exporting),
    ),
  ),
);
List<String> _items(WidgetTester tester) => tester
    .widgetList<Text>(
      find.descendant(of: find.byType(Table), matching: find.byType(Text)),
    )
    .map((w) => w.data ?? w.textSpan?.toPlainText() ?? '')
    .where((s) => s.startsWith('Item '))
    .toList();
Finder get _filter => find.descendant(
  of: find.byKey(const ValueKey('genui-table-filter-root')),
  matching: find.byType(TextField),
);
Finder get _sort => find.byKey(const ValueKey('genui-table-sort-root-price'));
Finder get _next => find.byKey(const ValueKey('genui-table-next-root'));
Finder get _pageSize =>
    find.byKey(const ValueKey('genui-table-page-size-root'));
Future<void> _chooseSize(WidgetTester tester, int size) async {
  await tester.ensureVisible(_pageSize);
  await tester.tap(_pageSize);
  await tester.pumpAndSettle();
  await tester.tap(find.text('$size/page').last);
  await tester.pumpAndSettle();
}

const _viewFailure =
    'This view change exceeds the saved state limit. Shorten a field or reset the UI and try again.';
void _fillState(UiSurfaceController c) {
  final overhead = utf8
      .encode(
        jsonEncode({
          'inputs': {'note': ''},
          'view': {},
        }),
      )
      .length;
  expect(
    c.setInputs({'note': 'x' * (32768 - overhead)}, token: c.token),
    UiMutationResult.accepted,
  );
  expect(utf8.encode(c.state.json).length, 32768);
}

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .single;
    view.physicalSize = const Size(390, 1600);
    view.devicePixelRatio = 1;
    addTearDown(view.reset);
  });
  testWidgets('page size dialog closes when its source node disappears', (
    tester,
  ) async {
    final c = _controller(_source());
    await tester.pumpWidget(_app(c));
    await tester.pumpAndSettle();
    await tester.tap(_pageSize);
    await tester.pumpAndSettle();
    expect(find.text('20/page'), findsOneWidget);
    c.updateSource(
      '${UiCatalog.header}\nroot = Text(text="Replacement")\n',
      closed: true,
      generation: UiGenerationStatus.complete,
    );
    await tester.pumpAndSettle();
    expect(find.text('20/page'), findsNothing);
    expect(find.text('Replacement'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('two narrow tables wrap their page controls', (tester) async {
    const data = '[{"name":"A","price":1}]';
    final c = _controller(
      'root = Row(children=[a,b])\na = DataTable(data=$data,rowKey="name",columns=[{"key":"name","label":"Name"},{"key":"price","label":"Price"}])\nb = DataTable(data=$data,rowKey="name",columns=[{"key":"name","label":"Name"},{"key":"price","label":"Price"}])',
    );
    await tester.pumpWidget(_app(c));
    await tester.pumpAndSettle();
    expect(find.byType(GenUiDataTable), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'local paging renders only the selected page and handles same-frame clicks',
    (tester) async {
      final c = _controller(_source());
      await tester.pumpWidget(_app(c));
      await tester.pumpAndSettle();
      expect(_items(tester), [for (var i = 0; i < 10; i++) 'Item 0$i']);
      await tester.tap(_next);
      await tester.tap(_next);
      await tester.pumpAndSettle();
      expect(c.state.view['root']?['page'], 2);
      expect(_items(tester).first, 'Item 20');
      expect(find.text('21–30 / 35'), findsOneWidget);
      await _chooseSize(tester, 20);
      await tester.pumpAndSettle();
      expect(c.state.view['root']?['pageSize'], 20);
      expect(_items(tester), hasLength(20));
      expect(c.state.view['root']?['page'], isNull);
    },
  );
  testWidgets(
    'header clicks sort, keep null last and cycle with no intervening frame',
    (tester) async {
      final c = _controller(_source(rows: 8));
      await tester.pumpWidget(_app(c));
      await tester.pumpAndSettle();
      final before = tester
          .widget<Table>(find.byType(Table))
          .children
          .skip(1)
          .map((r) => r.key)
          .toSet();
      await tester.tap(_sort);
      await tester.pumpAndSettle();
      expect(_items(tester).last, 'Item 02');
      expect(
        tester.getBottomRight(find.text('—')).dx,
        closeTo(tester.getBottomRight(find.text('0.23')).dx, 0.1),
      );
      await tester.tap(_sort);
      await tester.pumpAndSettle();
      expect(_items(tester).first, 'Item 07');
      expect(_items(tester).last, 'Item 02');
      final after = tester
          .widget<Table>(find.byType(Table))
          .children
          .skip(1)
          .map((r) => r.key)
          .toSet();
      expect(after, before);
      await tester.tap(_sort);
      await tester.pumpAndSettle();
      await tester.tap(_sort);
      await tester.tap(_sort);
      await tester.tap(_sort);
      await tester.pumpAndSettle();
      expect(c.state.view['root']?['sortKey'], isNull);
      expect(_items(tester).first, 'Item 00');
    },
  );
  testWidgets(
    'filter searches displayed rounding and highlights matching text',
    (tester) async {
      final c = _controller(_source());
      await tester.pumpWidget(_app(c));
      await tester.pumpAndSettle();
      await tester.enterText(_filter, '1.23');
      await tester.pumpAndSettle();
      expect(_items(tester), ['Item 01', 'Item 11', 'Item 21', 'Item 31']);
      final cell = tester.widget<Text>(
        find.descendant(of: find.byType(Table), matching: find.text('1.23')),
      );
      final span = cell.textSpan! as TextSpan;
      expect(
        span.children!.whereType<TextSpan>().any(
          (s) => s.text == '1.23' && s.style?.backgroundColor != null,
        ),
        isTrue,
      );
      await tester.enterText(_filter, '1.234');
      await tester.pumpAndSettle();
      expect(_items(tester), isEmpty);
      expect(find.text('No matching rows'), findsOneWidget);
      expect(c.state.view['root']?['filter'], '1.234');
    },
  );
  for (final chart in [false, true]) {
    testWidgets(
      '${chart ? 'Chart data view' : 'DataTable'} projects the displayed filter rows with exact values',
      (tester) async {
        const data =
            '[{"name":"Item noisy","price":0.1+0.2},'
            '{"name":"Item distinct","price":0.30000000001}]';
        final c = _controller(
          chart
              ? 'root = Chart(kind="line",x="name",y=["price"],xLabel="Name",yLabel="Value",data=$data)'
              : 'root = DataTable(data=$data,rowKey="name",columns=[{"key":"name","label":"Name"},{"key":"price","label":"Value"}])',
        );
        if (chart) c.setView('root', {'dataView': true}, token: c.token);
        await tester.pumpWidget(_app(c));
        await tester.pumpAndSettle();
        expect(find.text('0.3'), findsOneWidget);
        expect(find.text('0.30000000000000004'), findsNothing);
        for (final (query, names) in [
          ('000', ['Item distinct']),
          ('00000000000000004', <String>[]),
          ('0.3', ['Item noisy', 'Item distinct']),
        ]) {
          await tester.enterText(_filter, query);
          await tester.pumpAndSettle();
          expect(_items(tester), names);
          final read = c.captureRead();
          for (final body in [
            for (final mode in UiTextMode.values)
              testUiProjection.text(read, mode: mode),
            testUiProjection.context(read).body,
          ]) {
            expect(
              body,
              contains(
                names.isEmpty
                    ? 'Rows 0–0 of 0'
                    : 'Rows 1–${names.length} of ${names.length}',
              ),
            );
            for (final name in ['Item noisy', 'Item distinct']) {
              expect(
                body.contains('Name: $name | Value:'),
                names.contains(name),
              );
            }
            if (names.contains('Item noisy')) {
              expect(body, contains('Value: 0.30000000000000004'));
            }
          }
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'IME draft blocks late restore, survives appearance changes, then commits',
    (tester) async {
      final c = _controller(_source());
      final snapshot = c.captureSnapshot();
      await tester.pumpWidget(_app(c));
      await tester.pumpAndSettle();
      final token = c.restoreToken;
      await tester.showKeyboard(_filter);
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'Item 0',
          selection: TextSelection.collapsed(offset: 3),
          composing: TextRange(start: 0, end: 6),
        ),
      );
      await tester.pump();
      expect(c.state.view, isEmpty);
      expect(c.restore(snapshot, token: token), isFalse);
      final editing = tester.widget<TextField>(_filter).controller!;
      await tester.pumpWidget(_app(c, dark: true, rtl: true, scale: 1.3));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(_filter).controller, same(editing));
      expect(editing.value.composing, const TextRange(start: 0, end: 6));
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'Item 0',
          selection: TextSelection.collapsed(offset: 3),
          composing: TextRange.empty,
        ),
      );
      await tester.pumpAndSettle();
      expect(c.state.view['root']?['filter'], 'Item 0');
      expect(editing.selection.baseOffset, 3);
      expect(_items(tester), hasLength(10));
    },
  );
  testWidgets('emoji length is bounded in the same units as saved filters', (
    tester,
  ) async {
    final c = _controller(_source());
    await tester.pumpWidget(_app(c));
    await tester.pumpAndSettle();
    await tester.enterText(_filter, List.filled(129, '😀').join());
    await tester.pumpAndSettle();
    final shown = tester.widget<TextField>(_filter).controller!.text;
    expect(shown, List.filled(128, '😀').join());
    expect(c.state.view['root']?['filter'], shown);
  });
  for (final (character, count, expectedCount) in [
    ('😀', 129, 128),
    ('x', 300, 256),
  ]) {
    testWidgets(
      'IME blur bounds $count characters without a formatter callback',
      (tester) async {
        final c = _controller(_source());
        await tester.pumpWidget(_app(c));
        await tester.pumpAndSettle();
        await tester.showKeyboard(_filter);
        final text = character * count;
        tester.testTextInput.updateEditingValue(
          TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
            composing: TextRange(start: 0, end: text.length),
          ),
        );
        await tester.pump();
        expect(c.state.view['root']?['filter'], isNull);
        tester.widget<TextField>(_filter).focusNode!.unfocus();
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(_filter).controller!.text,
          character * expectedCount,
        );
        expect(c.state.view['root']?['filter'], character * expectedCount);
        expect(find.text(_viewFailure), findsNothing);
      },
    );
  }
  testWidgets('all table view budget failures are visible and reset recovers', (
    tester,
  ) async {
    final c = _controller(_source(note: true));
    _fillState(c);
    await tester.pumpWidget(_app(c));
    await tester.pumpAndSettle();
    for (final (index, action) in [_sort, _next, _pageSize].indexed) {
      if (index == 2) {
        await _chooseSize(tester, 20);
      } else {
        await tester.tap(action);
      }
      await tester.pumpAndSettle();
      expect(c.state.view, isEmpty);
      expect(find.text(_viewFailure), findsOneWidget);
    }
    c.reset(token: c.token);
    await tester.pumpAndSettle();
    expect(find.text(_viewFailure), findsNothing);
    await tester.tap(_sort);
    await tester.pumpAndSettle();
    expect(c.state.view['root']?['sortKey'], isNotNull);
  });
  testWidgets('Chart data and legend budget failures are visible', (
    tester,
  ) async {
    final c = _controller(_source(note: true, chart: true));
    _fillState(c);
    await tester.pumpWidget(_app(c));
    await tester.pumpAndSettle();
    for (final action in [
      find.text('Data'),
      find.byKey(const ValueKey('genui-chart-legend-root-0')),
    ]) {
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(c.state.view, isEmpty);
      expect(find.text(_viewFailure), findsOneWidget);
    }
    c.reset(token: c.token);
    await tester.pumpAndSettle();
    expect(find.text(_viewFailure), findsNothing);
    await tester.tap(find.text('Data'));
    await tester.pumpAndSettle();
    expect(find.byType(GenUiDataTable), findsOneWidget);
  });
  testWidgets('non-sortable unfiltered table has a visible keyboard focus', (
    tester,
  ) async {
    final source = _source().replaceFirst(
      'DataTable(',
      'DataTable(sortable=false,filterable=false,',
    );
    final c = _controller(source);
    await tester.pumpWidget(_app(c));
    await tester.pumpAndSettle();
    final viewport = find.byKey(const ValueKey('genui-table-viewport-root'));
    final theme = GenUiTheme.of(tester.element(viewport));
    Color border() =>
        ((tester.widget<Container>(viewport).foregroundDecoration!
                        as BoxDecoration)
                    .border!
                as Border)
            .top
            .color;
    expect(border(), theme.hairline);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    Focus.of(tester.element(viewport)).requestFocus();
    await tester.pumpAndSettle();
    expect(border(), theme.primary);
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pumpAndSettle();
    expect(c.state.view['root']?['page'], 1);
  });
  testWidgets(
    'compact page selector retains its 44dp target and focus return',
    (tester) async {
      final c = _controller(_source());
      await tester.pumpWidget(_app(c));
      await tester.pumpAndSettle();
      final center = tester.getCenter(_pageSize);
      await tester.tapAt(center.translate(0, 21));
      await tester.pumpAndSettle();
      await tester.tap(find.text('20/page'));
      await tester.pumpAndSettle();
      expect(c.state.view['root']?['pageSize'], 20);
      expect(
        tester.widget<IosIconButton>(_pageSize).focusNode!.hasFocus,
        isTrue,
      );
      await _chooseSize(tester, 10);
      expect(c.state.view['root']?['pageSize'], isNull);
    },
  );
  testWidgets(
    'state-budget failure keeps draft with an explicit error and can recover',
    (tester) async {
      final c = _controller(_source(note: true));
      expect(
        c.setInputs({'note': List.filled(32000, 'x').join()}, token: c.token),
        UiMutationResult.accepted,
      );
      await tester.pumpWidget(_app(c));
      await tester.pumpAndSettle();
      final query = List.filled(256, '界').join();
      await tester.enterText(_filter, query);
      await tester.pumpAndSettle();
      expect(c.state.view['root']?['filter'], isNull);
      expect(tester.widget<TextField>(_filter).controller!.text, query);
      // Another view change can fit even though the filter draft did not.
      // It must not hide the explanation for the still-unapplied query.
      await tester.tap(_next);
      await tester.pumpAndSettle();
      expect(c.state.view['root']?['page'], 1);
      expect(
        find.text(
          'This view change exceeds the saved state limit. Shorten a field or reset the UI and try again.',
        ),
        findsOneWidget,
      );
      await tester.enterText(_filter, 'Item');
      await tester.pumpAndSettle();
      expect(c.state.view['root']?['filter'], 'Item');
      expect(
        find.text(
          'This view change exceeds the saved state limit. Shorten a field or reset the UI and try again.',
        ),
        findsNothing,
      );
    },
  );
  testWidgets(
    'view restore does not issue a write and reset clears filter and page size',
    (tester) async {
      final source = _source();
      final c = _controller(source);
      await tester.pumpWidget(_app(c));
      await tester.pumpAndSettle();
      await tester.enterText(_filter, 'Item');
      await tester.pumpAndSettle();
      await _chooseSize(tester, 20);
      await tester.pumpAndSettle();
      await tester.tap(_next);
      await tester.pumpAndSettle();
      final snapshot = c.captureSnapshot(), reopened = _controller(source);
      expect(reopened.restore(snapshot, token: reopened.restoreToken), isTrue);
      final sequence = reopened.sequence;
      await tester.pumpWidget(_app(reopened));
      await tester.pumpAndSettle();
      expect(reopened.sequence, sequence);
      expect(tester.widget<TextField>(_filter).controller!.text, 'Item');
      expect(_items(tester).first, 'Item 20');
      reopened.reset(token: reopened.token);
      await tester.pumpAndSettle();
      expect(reopened.state.isDefault, isTrue);
      expect(tester.widget<TextField>(_filter).controller!.text, '');
      expect(_items(tester), hasLength(10));
    },
  );
  testWidgets(
    'headers expose sorting semantics and keyboard paging reads current view',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final c = _controller(_source());
        await tester.pumpWidget(_app(c));
        await tester.pumpAndSettle();
        await tester.tap(_sort);
        await tester.pumpAndSettle();
        final node = tester.getSemantics(
          find.bySemanticsLabel('Price, Sorted ascending'),
        );
        expect(node.getSemanticsData().role, ui.SemanticsRole.columnHeader);
        expect(
          node.getSemanticsData().hasAction(ui.SemanticsAction.tap),
          isTrue,
        );
        // Tab to a table header, which is inside the horizontal-scroll focus scope.
        Focus.of(tester.element(_sort)).requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
        await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
        await tester.pumpAndSettle();
        expect(c.state.view['root']?['page'], 2);
      } finally {
        semantics.dispose();
      }
    },
  );
  testWidgets(
    'RTL and large text keep numbers LTR while columns and scroll mirror',
    (tester) async {
      final c = _controller(
        _source(
          rows: 3,
        ).replaceAll('"name":"Item', '"name":"A very long product name Item'),
      );
      await tester.pumpWidget(_app(c, rtl: true, scale: 1.3));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('Name')).dx,
        greaterThan(tester.getTopLeft(find.text('Price')).dx),
      );
      final numeric = tester.widget<Text>(find.text('0.23'));
      expect(numeric.textDirection, TextDirection.ltr);
      final scroll = tester.state<ScrollableState>(
        find.ancestor(
          of: find.byType(Table),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Scrollable &&
                (w.axisDirection == AxisDirection.left ||
                    w.axisDirection == AxisDirection.right),
          ),
        ),
      );
      expect(scroll.position.maxScrollExtent, greaterThan(0));
      Focus.of(tester.element(_sort)).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(scroll.position.pixels, greaterThan(0));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'streaming tables disable edits and exports retain filter without actions',
    (tester) async {
      final c = _controller(_source());
      c.updateSource(
        c.parsed.source,
        closed: true,
        generation: UiGenerationStatus.generating,
      );
      await tester.pumpWidget(_app(c));
      await tester.pumpAndSettle();
      await tester.tap(_sort);
      await tester.pump();
      expect(c.state.view, isEmpty);
      c.updateSource(
        c.parsed.source,
        closed: true,
        generation: UiGenerationStatus.complete,
      );
      await tester.pumpAndSettle();
      await tester.enterText(_filter, 'Item 0');
      await tester.pumpAndSettle();
      await tester.pumpWidget(_app(c, exporting: true));
      await tester.pumpAndSettle();
      expect(find.byType(IosTextButton), findsNothing);
      expect(find.byType(IosIconButton), findsNothing);
      expect(find.byType(GenUiViewTabs), findsNothing);
      expect(find.text('Filter visible text: Item 0'), findsOneWidget);
      expect(_items(tester), hasLength(10));
    },
  );
  testWidgets('digits formatting never forces mixed text cells to LTR', (
    tester,
  ) async {
    final c = _controller(
      _source(rows: 3).replaceFirst('"price":0.234', '"price":"مرحبا!"'),
    );
    await tester.pumpWidget(_app(c, rtl: true));
    await tester.pumpAndSettle();
    final text = find.text('مرحبا!');
    expect(tester.widget<Text>(text).textDirection, isNull);
    expect(Directionality.of(tester.element(text)), TextDirection.rtl);
    expect(
      tester.widget<Text>(find.text('1.23')).textDirection,
      TextDirection.ltr,
    );
  });
  testWidgets(
    'Chart data view is keyboard reachable, preserves filter across toggles and resets',
    (tester) async {
      final c = _controller(_source(chart: true));
      await tester.pumpWidget(_app(c));
      await tester.pumpAndSettle();
      for (
        var i = 0;
        i < 12 &&
            FocusManager.instance.primaryFocus?.debugLabel != 'GenUI view tabs';
        i++
      ) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'GenUI view tabs');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.byType(GenUiDataTable), findsOneWidget);
      await tester.enterText(_filter, 'Item 03');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chart'));
      await tester.pumpAndSettle();
      expect(find.byType(GenUiDataTable), findsNothing);
      await tester.tap(find.text('Data'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(_filter).controller!.text, 'Item 03');
      expect(_items(tester), ['Item 03']);
      c.reset(token: c.token);
      await tester.pumpAndSettle();
      expect(find.byType(GenUiDataTable), findsNothing);
    },
  );
  testWidgets(
    'Chart data view reaches the last page of a valid 2000-row chart',
    (tester) async {
      final c = _controller(_source(rows: 2000, chart: true));
      c.setView('root', {'dataView': true, 'page': 199}, token: c.token);
      await tester.pumpWidget(_app(c));
      await tester.pumpAndSettle();
      expect(_items(tester).last, 'Item 1999');
      expect(find.text('1991–2000 / 2000'), findsOneWidget);
    },
  );
}
