import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/features/intelligent_ui/catalog/ui_catalog.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_interaction_controller.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_state.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_button.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_surface.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_text_input.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/theme/theme_factory.dart';

const _source = r'''$name: string = ""
$n: number? = null
root = Form(title="Parameters",children=[nameField,amount,ask])
nameField = TextField(label="Name",bind=$name,required=true)
amount = NumberField(label="Amount",bind=$n,required=true,min=0,max=10)
ask = Button(label="Explain",form=root,variant="primary",action=Ask(text="Explain",context={"name":$name,"n":$n}))''';
UiSurfaceController _controller([String body = _source]) {
  final c = UiSurfaceController(
    owner: const UiSurfaceOwner(revisionId: 'form-widget', surfaceKey: '0:0'),
  );
  c.updateSource(
    '${UiCatalog.header}\n$body',
    closed: true,
    generation: UiGenerationStatus.complete,
  );
  addTearDown(c.dispose);
  return c;
}

Widget _app(
  UiSurfaceController c, {
  Future<void> Function(UiAskIntent)? onAsk,
}) => MaterialApp(
  theme: buildLightTheme(null),
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child!,
  ),
  home: Scaffold(
    body: SingleChildScrollView(
      child: SizedBox(
        width: 390,
        child: GenUiSurface(controller: c, onAsk: onAsk),
      ),
    ),
  ),
);
Finder _field(String id) => find.descendant(
  of: find.byWidgetPredicate((w) => w is GenUiTextInput && w.id == id),
  matching: find.byType(TextField),
);
void main() {
  testWidgets(
    'a required field revealed during submit is mounted before focus moves to it',
    (tester) async {
      final c = _controller(
        r'''$n: number? = 2
$name: string = ""
root = Form(children=[amount,nameField,ask])
amount = NumberField(label="Amount",bind=$n)
nameField = TextField(label="Name",bind=$name,visible=$n == null,required=true)
ask = Button(label="Explain",form=root,action=Ask(text="Explain",context={"n":$n,"name":$name}))''',
      );
      var asks = 0;
      await tester.pumpWidget(
        _app(
          c,
          onAsk: (_) async {
            asks++;
          },
        ),
      );
      expect(_field('nameField'), findsNothing);
      await tester.enterText(_field('amount'), '');
      await tester.tap(find.text('Explain'));
      await tester.pumpAndSettle();
      expect(asks, 0);
      expect(_field('nameField'), findsOneWidget);
      expect(
        tester.widget<TextField>(_field('nameField')).focusNode!.hasFocus,
        isTrue,
      );
    },
  );
  testWidgets(
    'invalid Form focuses first field, then publishes one frozen intent',
    (tester) async {
      final c = _controller();
      final captured = <UiAskIntent>[];
      await tester.pumpWidget(
        _app(
          c,
          onAsk: (intent) async {
            captured.add(intent);
          },
        ),
      );
      await tester.tap(find.text('Explain'));
      await tester.pumpAndSettle();
      expect(captured, isEmpty);
      expect(find.text('2 fields need attention'), findsOneWidget);
      expect(
        tester.widget<TextField>(_field('nameField')).focusNode!.hasFocus,
        isTrue,
      );
      await tester.enterText(_field('nameField'), 'Ada');
      await tester.enterText(_field('amount'), '4');
      await tester.pump();
      await tester.tap(find.text('Explain'));
      await tester.pumpAndSettle();
      expect(captured, hasLength(1));
      expect(captured.single.context, {'name': 'Ada', 'n': 4.0});
      expect(find.text('2 fields need attention'), findsNothing);
      await tester.enterText(_field('nameField'), 'Changed');
      await tester.pump();
      expect(captured.single.context['name'], 'Ada');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'single-line submit uses the same action and failures stay visible',
    (tester) async {
      final c = _controller();
      await tester.pumpWidget(
        _app(
          c,
          onAsk: (_) async {
            throw StateError('Test host failure');
          },
        ),
      );
      await tester.enterText(_field('nameField'), 'Ada');
      await tester.enterText(_field('amount'), '3');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(
        find.text("This action isn't available in this view"),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('unconnected Ask is disabled with a reason and no fake success', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final c = _controller();
    await tester.pumpWidget(_app(c));
    await tester.pumpAndSettle();
    final semantics = find.byWidgetPredicate(
      (w) =>
          w is Semantics &&
          w.properties.label == 'Explain' &&
          w.properties.button == true,
    );
    final data = tester.getSemantics(semantics).getSemanticsData();
    expect(data.flagsCollection.isEnabled, ui.Tristate.isFalse);
    expect(data.hasAction(ui.SemanticsAction.tap), isFalse);
    expect(data.hint, "This action isn't available in this view");
    expect(find.byType(GenUiButton), findsOneWidget);
    handle.dispose();
  });
  testWidgets('connected Ask exposes a semantic tap action', (tester) async {
    final handle = tester.ensureSemantics();
    final c = _controller();
    await tester.pumpWidget(_app(c, onAsk: (_) async {}));
    await tester.pumpAndSettle();
    final semantics = find.byWidgetPredicate(
      (w) =>
          w is Semantics &&
          w.properties.label == 'Explain' &&
          w.properties.button == true,
    );
    expect(
      tester
          .getSemantics(semantics)
          .getSemanticsData()
          .hasAction(ui.SemanticsAction.tap),
      isTrue,
    );
    handle.dispose();
  });
}
