import 'package:Kelivo/features/intelligent_ui/widgets/genui_node.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/features/intelligent_ui/catalog/ui_catalog.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_state.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_surface.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_content.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/theme/theme_factory.dart';

const _body = r'''$x: number = 0
root = Column(children=[a,b,c])
a = Metric(label="A", value=1/$x)
b = Metric(label="B", value=2/$x)
c = Metric(label="C", value=1/($x-1))''';
UiSurfaceController _controller([String body = _body]) {
  final c = UiSurfaceController(
    owner: const UiSurfaceOwner(revisionId: 'shell', surfaceKey: '0:0'),
  );
  c.updateSource(
    '${UiCatalog.header}\n$body',
    closed: true,
    generation: UiGenerationStatus.complete,
  );
  addTearDown(c.dispose);
  return c;
}

Widget _app(Widget child, {bool reduceMotion = true}) => MaterialApp(
  theme: buildLightTheme(null),
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
    child: child!,
  ),
  home: Scaffold(
    body: SingleChildScrollView(
      child: SizedBox(width: 390, child: SelectionArea(child: child)),
    ),
  ),
);
Finder _icon(String tooltip) =>
    find.byWidgetPredicate((w) => w is IosIconButton && w.tooltip == tooltip);

void main() {
  testWidgets('surface title is announced once in a read-only snapshot', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final c = _controller('root = Metric(label="Result", value=7)');
    await tester.pumpWidget(
      _app(GenUiSurface(controller: c, title: 'Unique title', exporting: true)),
    );
    await tester.pumpAndSettle();
    final labels = <String>[];
    bool collect(SemanticsNode node) {
      labels.add(node.getSemanticsData().label);
      node.visitChildren(collect);
      return true;
    }

    collect(tester.getSemantics(find.byType(GenUiSurface)));
    expect(RegExp('Unique title').allMatches(labels.join(' ')).length, 1);
    handle.dispose();
  });

  testWidgets('restore updates error count without scheduling another save', (
    tester,
  ) async {
    final source = _controller();
    source.setInputs({'x': 1}, token: source.token);
    final target = _controller();
    var saves = 0;
    target.listenState(() => saves++);
    await tester.pumpWidget(_app(GenUiSurface(controller: target)));
    await tester.pumpAndSettle();
    expect(find.text("2 nodes can't be displayed"), findsOneWidget);
    expect(
      target.restore(source.captureSnapshot(), token: target.restoreToken),
      isTrue,
    );
    await tester.pumpAndSettle();
    expect(find.text("1 node can't be displayed"), findsOneWidget);
    expect(saves, 0);
  });
  testWidgets(
    'source uses the full touch target and Escape restores trigger focus',
    (tester) async {
      final c = _controller('root = Text(text="Selectable content")');
      await tester.pumpWidget(_app(GenUiSurface(controller: c)));
      await tester.pumpAndSettle();
      final trigger = _icon('View source');
      expect(tester.getSize(trigger).width, greaterThanOrEqualTo(44));
      await tester.tapAt(tester.getTopLeft(trigger) + const Offset(2, 2));
      await tester.pumpAndSettle();
      expect(find.byType(GenUiSource), findsOneWidget);
      expect(
        tester.widget<GenUiSource>(find.byType(GenUiSource)).source,
        c.parsed.source,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(GenUiSource), findsNothing);
      expect(tester.widget<IosIconButton>(trigger).focusNode!.hasFocus, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'More resets local inputs and returns focus without a model action',
    (tester) async {
      final c = _controller(r'''$x: number = 2
root = Metric(label="Value", value=$x)''');
      c.setInputs({'x': 9}, token: c.token);
      await tester.pumpWidget(_app(GenUiSurface(controller: c)));
      await tester.pumpAndSettle();
      await tester.tap(_icon('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset to defaults'));
      await tester.pumpAndSettle();
      expect(c.captureRead().inputs['x'], 2);
      expect(
        tester.widget<IosIconButton>(_icon('More')).focusNode!.hasFocus,
        isTrue,
      );
    },
  );
  testWidgets(
    'streaming badge stops on completion and respects reduced motion',
    (tester) async {
      final c = _controller('root = Metric(label="Result", value=7)');
      c.updateSource(
        c.parsed.source,
        closed: true,
        generation: UiGenerationStatus.generating,
      );
      await tester.pumpWidget(
        _app(GenUiSurface(controller: c), reduceMotion: false),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Generating'), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isTrue);
      c.updateSource(
        c.parsed.source,
        closed: true,
        generation: UiGenerationStatus.complete,
      );
      await tester.pumpAndSettle();
      expect(find.text('Generating'), findsNothing);
      expect(tester.binding.hasScheduledFrame, isFalse);
      c.updateSource(
        c.parsed.source,
        closed: true,
        generation: UiGenerationStatus.generating,
      );
      await tester.pumpWidget(_app(GenUiSurface(controller: c)));
      await tester.pumpAndSettle();
      expect(find.text('Generating'), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
    },
  );
  testWidgets(
    'read-only exports contain no shell actions and save retry is explicit',
    (tester) async {
      final c = _controller('root = Metric(label="Result", value=7)');
      c.setSaveFailed(true, token: c.token, sequence: c.sequence);
      var retries = 0;
      await tester.pumpWidget(
        _app(GenUiSurface(controller: c, onRetrySave: () => retries++)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Not saved'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      await tester.tap(find.text('Not saved'));
      expect(retries, 1);
      await tester.pumpWidget(
        _app(GenUiSurface(controller: c, exporting: true)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(IosIconButton), findsNothing);
      expect(find.text('Not saved'), findsNothing);
      expect(find.text('Read-only snapshot'), findsOneWidget);
    },
  );
  testWidgets(
    'node reveal exists only during animation and preserves editor focus and composing',
    (tester) async {
      final c = _controller();
      const prefix = '${UiCatalog.header}\nroot = Column(children=[field])\n';
      c.updateSource(
        prefix,
        closed: false,
        generation: UiGenerationStatus.generating,
      );
      await tester.pumpWidget(
        _app(GenUiSurface(controller: c), reduceMotion: false),
      );
      final nodeFinder = find.byType(GenUiNode);
      Finder fades() => find.descendant(
        of: nodeFinder,
        matching: find.byType(FadeTransition),
      );
      expect(fades(), findsNothing);
      c.updateSource(
        '$prefix\$value: string = "initial"\nfield = TextField(label="Name",bind=\$value)\n',
        closed: true,
        generation: UiGenerationStatus.complete,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(fades(), findsOneWidget);
      final field = find.byType(EditableText);
      await tester.tap(field);
      await tester.pump();
      final state = tester.state<EditableTextState>(field);
      final editing = tester.widget<EditableText>(field);
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '组字',
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange(start: 0, end: 2),
        ),
      );
      await tester.pump();
      expect(editing.focusNode.hasFocus, isTrue);
      await tester.pump(const Duration(milliseconds: 180));
      await tester.pump();
      expect(fades(), findsNothing);
      expect(identical(state, tester.state<EditableTextState>(field)), isTrue);
      expect(editing.focusNode.hasFocus, isTrue);
      expect(
        editing.controller.value.composing,
        const TextRange(start: 0, end: 2),
      );
      expect(c.captureRead().inputs['value'], 'initial');
      await tester.pumpWidget(const SizedBox());
    },
  );
}
