import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/features/intelligent_ui/catalog/ui_catalog.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_state.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_interaction_controller.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_surface.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/theme/theme_factory.dart';

UiSurfaceController _controller(String body) {
  final c = UiSurfaceController(
    owner: const UiSurfaceOwner(revisionId: 'input-widget', surfaceKey: '0:0'),
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
  bool dark = false,
  double scale = 1,
  double width = 390,
  Future<void> Function(UiAskIntent)? onAsk,
}) => MaterialApp(
  theme: dark ? buildDarkTheme(null) : buildLightTheme(null),
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: true),
    child: child!,
  ),
  home: Scaffold(
    body: SingleChildScrollView(
      child: SizedBox(
        width: width,
        child: GenUiSurface(controller: c, onAsk: onAsk),
      ),
    ),
  ),
);
void main() {
  testWidgets(
    'Row reflow preserves the focused editor and IME composition across size and text scale',
    (tester) async {
      final c = _controller(r'''$name: string = "Before"
root = Row(children=[field,display])
field = TextField(label="Name",bind=$name)
display = Text(text="Another cell")''');
      await tester.pumpWidget(_app(c, width: 600));
      await tester.tap(find.byType(TextField));
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '中',
          selection: TextSelection.collapsed(offset: 1),
          composing: TextRange(start: 0, end: 1),
        ),
      );
      await tester.pump();
      final editor = tester
          .widget<TextField>(find.byType(TextField))
          .controller;
      final focus = tester.widget<TextField>(find.byType(TextField)).focusNode;
      for (final (width, scale) in [(600.0, 1.3), (300.0, 1.0), (600.0, 1.0)]) {
        await tester.pumpWidget(
          _app(c, dark: true, width: width, scale: scale),
        );
        await tester.pumpAndSettle();
        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.controller, same(editor));
        expect(field.focusNode, same(focus));
        expect(focus!.hasFocus, isTrue);
        expect(editor!.value.composing, const TextRange(start: 0, end: 1));
        expect(c.captureRead().inputs['name'], 'Before');
      }
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '中',
          selection: TextSelection.collapsed(offset: 1),
        ),
      );
      await tester.pump();
      expect(c.captureRead().inputs['name'], '中');
    },
  );
  testWidgets('same node id can change input kind without stale listener casts', (
    tester,
  ) async {
    final c = _controller(r'''$value: number = 2
root = NumberField(label="Value",bind=$value)''');
    await tester.pumpWidget(_app(c));
    c.updateSource(
      '${UiCatalog.header}\n\$text: string = "New"\nroot = TextField(label="Text",bind=\$text)',
      closed: true,
      generation: UiGenerationStatus.complete,
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'New',
    );
    c.updateSource(
      '${UiCatalog.header}\n\$value: number = 3\nroot = NumberField(label="Value",bind=\$value)',
      closed: true,
      generation: UiGenerationStatus.complete,
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '3',
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'stepper processes consecutive activations before the next frame',
    (tester) async {
      final c = _controller(r'''$n: number = 2
root = NumberField(label="Amount",bind=$n,min=0,max=10)''');
      await tester.pumpWidget(_app(c));
      final plus = find.byWidgetPredicate(
        (w) => w is IosIconButton && w.tooltip == 'Increase Amount',
      );
      await tester.tap(plus);
      await tester.tap(plus);
      await tester.pumpAndSettle();
      expect(c.captureRead().inputs['n'], 4);
    },
  );
  for (final condition in ['enabled', 'visible']) {
    testWidgets(
      'ending composition while $condition changes preserves the eventual submitted draft',
      (tester) async {
        final c = _controller(
          r'''$name: string = "Before"
$active: boolean = true
root = Form(children=[field,ask])
field = TextField(label="Name",bind=$name,enabled=$active)
ask = Button(label="Explain",form=root,action=Ask(text="Explain",context={"name":$name}))'''
              .replaceFirst(r'enabled=$active', '$condition=\$active'),
        );
        UiAskIntent? intent;
        await tester.pumpWidget(
          _app(
            c,
            onAsk: (value) async {
              intent = value;
            },
          ),
        );
        await tester.tap(find.byType(TextField));
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: '中',
            selection: TextSelection.collapsed(offset: 1),
            composing: TextRange(start: 0, end: 1),
          ),
        );
        await tester.pump();
        c.setInputs({'active': false}, token: c.token);
        await tester.pumpAndSettle();
        expect(c.captureRead().inputs['name'], 'Before');
        c.setInputs({'active': true}, token: c.token);
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '中',
        );
        await tester.tap(find.text('Explain'));
        await tester.pumpAndSettle();
        expect(intent?.context['name'], '中');
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'same-text IME commit updates the state only after composition ends',
    (tester) async {
      final c = _controller(r'''$name: string = "Before"
root = Column(children=[field,display])
field = TextField(label="Name",bind=$name)
display = Text(text=$name)''');
      await tester.pumpWidget(_app(c));
      await tester.tap(find.byType(TextField));
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '中',
          selection: TextSelection.collapsed(offset: 1),
          composing: TextRange(start: 0, end: 1),
        ),
      );
      await tester.pump();
      expect(c.captureRead().inputs['name'], 'Before');
      await tester.pumpWidget(_app(c, dark: true, scale: 1.3));
      await tester.pumpAndSettle();
      final editor = tester
          .widget<TextField>(find.byType(TextField))
          .controller!;
      expect(editor.text, '中');
      expect(editor.value.composing, const TextRange(start: 0, end: 1));
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '中',
          selection: TextSelection.collapsed(offset: 1),
        ),
      );
      await tester.pump();
      expect(c.captureRead().inputs['name'], '中');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'number draft survives appearance changes and no-op Reset clears it',
    (tester) async {
      final c = _controller(r'''$n: number = 2
root = NumberField(label="Amount",bind=$n,min=0,max=10,unit="km")''');
      await tester.pumpWidget(_app(c));
      await tester.enterText(find.byType(TextField), '-');
      await tester.pump();
      expect(c.captureRead().inputs['n'], 2);
      await tester.pumpWidget(_app(c, dark: true, scale: 1.3));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '-',
      );
      c.reset(token: c.token);
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '2',
      );
      expect(c.state.isDefault, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('number stepper recovers drafts and enforces bounds', (
    tester,
  ) async {
    final c = _controller(r'''$n: number = 2
root = NumberField(label="Amount",bind=$n,min=0,max=3)''');
    await tester.pumpWidget(_app(c));
    await tester.enterText(find.byType(TextField), '-');
    await tester.pump();
    final plus = find.byWidgetPredicate(
      (w) => w is IosIconButton && w.tooltip == 'Increase Amount',
    );
    await tester.tap(plus);
    await tester.pumpAndSettle();
    expect(c.captureRead().inputs['n'], 3);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '3',
    );
    expect(tester.widget<IosIconButton>(plus).enabled, isFalse);
    await tester.enterText(find.byType(TextField), '12');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(c.captureRead().inputs['n'], 3);
    expect(find.text('Range 0–3'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
  testWidgets('streaming keeps normal fields read-only until host completion', (
    tester,
  ) async {
    final c = _controller(r'''$n: number = 2
root = NumberField(label="Amount",bind=$n)''');
    c.updateSource(
      c.parsed.source,
      closed: true,
      generation: UiGenerationStatus.generating,
    );
    await tester.pumpWidget(_app(c));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
    c.updateSource(
      c.parsed.source,
      closed: true,
      generation: UiGenerationStatus.complete,
    );
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isFalse);
    await tester.enterText(find.byType(TextField), '4');
    await tester.pump();
    expect(c.captureRead().inputs['n'], 4);
  });
}
