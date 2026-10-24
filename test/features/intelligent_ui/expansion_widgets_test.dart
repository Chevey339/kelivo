import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_interaction_controller.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_state.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_expansion.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_surface.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/theme/theme_factory.dart';

const _source = r'''ui 1 catalog "kelivo.native/1"
$name: string = "initial"
$n: number = 1
root = Column(children=[nameField,numberField])
nameField = TextField(label="Name",bind=$name)
numberField = NumberField(label="Number",bind=$n)
''';

void main() {
  late UiSurfaceController controller;
  late UiInteractionController interactions;
  late ValueNotifier<(bool, double)> appearance;
  late ValueNotifier<bool> visible;
  setUp(() {
    controller =
        UiSurfaceController(
          owner: const UiSurfaceOwner(
            revisionId: 'revision',
            surfaceKey: '0:0',
          ),
        )..updateSource(
          _source,
          closed: true,
          generation: UiGenerationStatus.complete,
        );
    interactions = UiInteractionController(controller);
    appearance = ValueNotifier((false, 1));
    visible = ValueNotifier(true);
  });
  tearDown(() {
    interactions.dispose();
    controller.dispose();
    appearance.dispose();
    visible.dispose();
  });
  Widget app({bool reduceMotion = true}) => ValueListenableBuilder(
    valueListenable: appearance,
    builder: (context, value, _) => MaterialApp(
      theme: value.$1 ? buildDarkTheme(null) : buildLightTheme(null),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: reduceMotion,
          textScaler: TextScaler.linear(value.$2),
        ),
        child: child!,
      ),
      home: Scaffold(
        body: ValueListenableBuilder(
          valueListenable: visible,
          builder: (context, shown, _) => shown
              ? SingleChildScrollView(
                  child: GenUiExpansion(
                    surfaceBuilder: (expand, focus, expanded) => GenUiSurface(
                      controller: controller,
                      interactions: interactions,
                      onExpand: expand,
                      expandFocusNode: focus,
                      expanded: expanded,
                    ),
                  ),
                )
              : const SizedBox(),
        ),
      ),
    ),
  );
  Finder expandButton() => find.byWidgetPredicate(
    (w) => w is IosIconButton && w.tooltip == 'Expand',
  );

  for (final width in [390.0, 1200.0]) {
    testWidgets('one active tree, shared values and focus return at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(app(reduceMotion: false));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).at(1), '-');
      await tester.tap(expandButton());
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        expect(
          find.byType(EditableText, skipOffstage: false).evaluate().length,
          lessThanOrEqualTo(2),
        );
        expect(
          find.byType(GenUiSurface, skipOffstage: false).evaluate().length,
          lessThanOrEqualTo(1),
        );
      }
      expect(
        find.text('Being edited in expanded view', skipOffstage: false),
        findsOneWidget,
      );
      expect(find.text('Shares the same state as the message'), findsOneWidget);
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText).at(1))
            .controller
            .text,
        '-',
      );
      expect(controller.captureRead().inputs['n'], 1);
      await tester.enterText(find.byType(EditableText).first, 'expanded');
      await tester.pump();
      expect(controller.captureRead().inputs['name'], 'expanded');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        expect(
          find.byType(EditableText, skipOffstage: false).evaluate().length,
          lessThanOrEqualTo(2),
        );
        expect(
          find.byType(GenUiSurface, skipOffstage: false).evaluate().length,
          lessThanOrEqualTo(1),
        );
      }
      await tester.pumpAndSettle();
      expect(find.text('Being edited in expanded view'), findsNothing);
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText).first)
            .controller
            .text,
        'expanded',
      );
      expect(
        tester.widget<IosIconButton>(expandButton()).focusNode!.hasFocus,
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
  testWidgets('expanded appearance updates preserve native composition', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(expandButton());
    await tester.pumpAndSettle();
    final field = find.byType(EditableText).first;
    await tester.tap(field);
    await tester.pump();
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'ni',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: 2),
      ),
    );
    await tester.pump();
    final native = tester.widget<EditableText>(field).controller;
    appearance.value = (true, 1.3);
    await tester.pumpAndSettle();
    expect(tester.widget<EditableText>(field).controller, same(native));
    expect(native.value.composing, const TextRange(start: 0, end: 2));
    expect(Theme.of(tester.element(field)).brightness, Brightness.dark);
    expect(MediaQuery.textScalerOf(tester.element(field)).scale(1), 1.3);
    expect(controller.captureRead().inputs['name'], 'initial');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  for (final change in ['source', 'owner', 'host']) {
    testWidgets('$change removal closes expanded controls', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(expandButton());
      await tester.pumpAndSettle();
      switch (change) {
        case 'source':
          controller.updateSource(
            _source.replaceFirst('initial', 'changed'),
            closed: true,
            generation: UiGenerationStatus.complete,
          );
        case 'owner':
          controller.dispose();
          visible.value = false;
        case 'host':
          visible.value = false;
      }
      await tester.pumpAndSettle();
      expect(find.text('Shares the same state as the message'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
  testWidgets('new source can reopen without an obsolete epoch closing input', (
    tester,
  ) async {
    const rootInput = r'''ui 1 catalog "kelivo.native/1"
$n: number = 1
root = NumberField(label="Root amount",bind=$n)
''';
    controller.updateSource(
      rootInput,
      closed: true,
      generation: UiGenerationStatus.complete,
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(expandButton());
    await tester.pumpAndSettle();
    controller.updateSource(
      rootInput.replaceFirst('= 1', '= 2'),
      closed: true,
      generation: UiGenerationStatus.complete,
    );
    await tester.pumpAndSettle();
    expect(find.text('Shares the same state as the message'), findsNothing);
    await tester.tap(expandButton());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), '3');
    await tester.pumpAndSettle();
    expect(controller.captureRead().inputs['n'], 3);
    expect(find.text('Shares the same state as the message'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'inline height is bounded and overflow removal clears its action',
    (tester) async {
      final height = ValueNotifier(600.0);
      addTearDown(height.dispose);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: ValueListenableBuilder(
                valueListenable: height,
                builder: (_, value, _) => GenUiInlineViewport(
                  maxHeight: 300,
                  onExpand: () async {},
                  child: SizedBox(height: value, width: 390),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(GenUiInlineViewport)).height,
        lessThanOrEqualTo(300),
      );
      expect(find.text('Expand'), findsOneWidget);
      height.value = 280;
      await tester.pumpAndSettle();
      expect(find.text('Expand'), findsNothing);
      expect(tester.getSize(find.byType(GenUiInlineViewport)).height, 280);
    },
  );
  testWidgets(
    'horizontal table metrics never create a vertical overflow mask',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 390,
                child: GenUiInlineViewport(
                  maxHeight: 300,
                  onExpand: () async {},
                  child: const SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(width: 1800, height: 200),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ShaderMask), findsNothing);
      expect(find.text('Expand'), findsNothing);
      expect(tester.getSize(find.byType(GenUiInlineViewport)).height, 200);
    },
  );
  testWidgets('chart clears selection then lets Escape close its expanded view', (
    tester,
  ) async {
    controller.updateSource(
      'ui 1 catalog "kelivo.native/1"\nroot = Chart(kind="line",x="x",y=["y"],data=[{"x":0,"y":1},{"x":1,"y":2}])\n',
      closed: true,
      generation: UiGenerationStatus.complete,
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(expandButton());
    await tester.pumpAndSettle();
    final chartFocus = find.byWidgetPredicate(
      (w) => w is Focus && w.focusNode?.debugLabel == 'GenUI chart',
    );
    tester.widget<Focus>(chartFocus).focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('genui-chart-tooltip-root')),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('genui-chart-tooltip-root')),
      findsNothing,
    );
    expect(find.text('Shares the same state as the message'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Shares the same state as the message'), findsNothing);
  });
  testWidgets('failed table filter draft survives expansion and return', (
    tester,
  ) async {
    controller.updateSource(
      r'''ui 1 catalog "kelivo.native/1"
$note: string = ""
root = DataTable(data=[{"id":"1","name":"Example"}],rowKey="id",columns=[{"key":"name","label":"Name"}])
''',
      closed: true,
      generation: UiGenerationStatus.complete,
    );
    controller.setInputs({'note': 'x' * 32000}, token: controller.token);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final query = '界' * 256;
    await tester.enterText(find.byType(EditableText), query);
    await tester.pumpAndSettle();
    const error =
        'This view change exceeds the saved state limit. Shorten a field or reset the UI and try again.';
    expect(controller.state.view['root']?['filter'], isNull);
    expect(find.text(error), findsOneWidget);
    await tester.tap(expandButton());
    await tester.pumpAndSettle();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      query,
    );
    expect(find.text(error), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      query,
    );
    expect(find.text(error), findsOneWidget);
    controller.reset(token: controller.token);
    await tester.pumpAndSettle();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      '',
    );
    expect(find.text(error), findsNothing);
  });
}
