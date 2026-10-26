import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/desktop/widgets/desktop_select_dropdown.dart';
import 'package:Kelivo/features/intelligent_ui/catalog/ui_catalog.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_state.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_boolean_input.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_choice_input.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_field_frame.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_slider.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_surface.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_theme.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/form_sheet.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_segments.dart';
import 'package:Kelivo/theme/theme_factory.dart';

UiSurfaceController _controller(String source) {
  final c = UiSurfaceController(
    owner: const UiSurfaceOwner(
      revisionId: 'selection-widget',
      surfaceKey: '0:0',
    ),
  );
  c.updateSource(
    '${UiCatalog.header}\n$source',
    closed: true,
    generation: UiGenerationStatus.complete,
  );
  addTearDown(c.dispose);
  return c;
}

Widget _app(
  UiSurfaceController c, {
  bool rtl = false,
  double scale = 1,
  bool dark = false,
  double width = 390,
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
      child: SizedBox(
        width: width,
        child: GenUiSurface(controller: c),
      ),
    ),
  ),
);

Finder _track() => find.descendant(
  of: find.byType(GenUiSlider),
  matching: find.byType(CustomPaint),
);
Finder _radio() => find.byWidgetPredicate(
  (w) => w is GenUiChoiceInput && w.node.declaration.component == 'RadioGroup',
);
void main() {
  testWidgets(
    'desktop Select fills its field and opens an equally wide menu from the trailing edge',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = _controller(
        r'''$complexity: number = 1.3
root = Select(label="复杂度系数",bind=$complexity,options=[{"value":1,"label":"基础 ×1.0"},{"value":1.3,"label":"标准 ×1.3"},{"value":1.8,"label":"复杂 ×1.8"}])''',
      );
      for (final width in [360.0, 900.0]) {
        for (final rtl in [false, true]) {
          await tester.pumpWidget(_app(c, width: width, rtl: rtl, scale: 1.3));
          await tester.pumpAndSettle();
          final field = tester.getRect(find.byType(GenUiFieldSurface));
          final trigger = find
              .descendant(
                of: find.byType(DesktopSelectDropdown<Object?>),
                matching: find.byType(AnimatedContainer),
              )
              .first;
          expect(tester.getRect(trigger).width, field.width);
          final arrow = tester.getRect(
            find.descendant(of: trigger, matching: find.byType(Icon)),
          );
          expect(
            rtl ? arrow.left - field.left : field.right - arrow.right,
            lessThan(20),
          );
          await tester.tapAt(
            Offset(rtl ? field.left + 40 : field.right - 40, field.center.dy),
          );
          await tester.pumpAndSettle();
          final theme = GenUiTheme.of(
            tester.element(find.byType(GenUiChoiceInput)),
          );
          final menu = find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).color == theme.popover,
          );
          expect(tester.getSize(menu).width, field.width);
          for (final label in ['基础 ×1.0', '标准 ×1.3', '复杂 ×1.8']) {
            final text = find.descendant(of: menu, matching: find.text(label));
            final paragraph = tester.renderObject<RenderParagraph>(
              find.descendant(of: text, matching: find.byType(RichText)),
            );
            expect(paragraph.didExceedMaxLines, isFalse, reason: label);
          }
          await tester.tap(
            find.descendant(of: menu, matching: find.text('复杂 ×1.8')),
          );
          await tester.pumpAndSettle();
          expect(c.captureRead().inputs['complexity'], 1.8);
          expect(find.text('复杂 ×1.8'), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );
  testWidgets('unselected radio arrows choose endpoints in both directions', (
    tester,
  ) async {
    final c = _controller(
      r'''$mode: string = ""
root = RadioGroup(label="Mode",bind=$mode,options=[{"value":"a","label":"A"},{"value":"b","label":"B"},{"value":"c","label":"C"}])''',
    );
    for (final rtl in [false, true]) {
      await tester.pumpWidget(_app(c, rtl: rtl));
      final focus = tester.widget<Focus>(
        find.descendant(
          of: _radio(),
          matching: find.byWidgetPredicate(
            (w) => w is Focus && w.onKeyEvent != null,
          ),
        ),
      );
      focus.focusNode!.requestFocus();
      await tester.pump();
      c.setInputs({'mode': ''}, token: c.token);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      expect(c.captureRead().inputs['mode'], 'c');
      c.setInputs({'mode': ''}, token: c.token);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      expect(c.captureRead().inputs['mode'], rtl ? 'a' : 'c');
      c.setInputs({'mode': ''}, token: c.token);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      expect(c.captureRead().inputs['mode'], 'a');
      await tester.pump();
    }
  });
  testWidgets('open desktop popover refreshes its surface when theme changes', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final c = _controller(
      r'''$mode: string = "a"
root = Select(label="Mode",bind=$mode,options=[{"value":"a","label":"One"},{"value":"b","label":"Two"}])''',
    );
    await tester.pumpWidget(_app(c));
    await tester.tap(find.byType(DesktopSelectDropdown<Object?>));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_app(c, dark: true));
    await tester.pumpAndSettle();
    expect(find.text('Two'), findsOneWidget);
    final theme = GenUiTheme.of(tester.element(find.byType(GenUiChoiceInput)));
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color == theme.popover,
      ),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(c.captureRead().inputs['mode'], 'a');
    debugDefaultTargetPlatformOverride = null;
  });
  testWidgets(
    'mobile sheet shows keyboard focus and closes when its source is replaced',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final c = _controller(
        r'''$mode: string = "a"
root = Select(label="Mode",bind=$mode,options=[{"value":"a","label":"One"},{"value":"b","label":"Two"}])''',
      );
      await tester.pumpWidget(_app(c));
      await tester.tap(find.text('One'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      final theme = GenUiTheme.of(
        tester.element(find.byType(GenUiChoiceInput)),
      );
      final rings = find.descendant(
        of: find.byType(FormSheet),
        matching: find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).shape == BoxShape.rectangle &&
              (w.decoration as BoxDecoration).border ==
                  Border.all(color: theme.primary, width: 2),
        ),
      );
      expect(rings, findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(c.captureRead().inputs['mode'], 'b');
      await tester.tap(find.text('Two'));
      await tester.pumpAndSettle();
      c.updateSource(
        '${UiCatalog.header}\nroot = Text(text="Changed")',
        closed: true,
        generation: UiGenerationStatus.complete,
      );
      await tester.pumpAndSettle();
      expect(find.byType(FormSheet), findsNothing);
      expect(find.text('Changed'), findsOneWidget);
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    },
  );
  testWidgets(
    'slider narrow finite interval is monotonic and large integers remain exact in semantics',
    (tester) async {
      final c = _controller(
        r'''$n: number = 2.5
root = Slider(label="Narrow",bind=$n,min=2.5,max=2.5000000000000004,step=1e-16)''',
      );
      await tester.pumpWidget(_app(c));
      final rect = tester.getRect(_track());
      double? previous;
      for (final fraction in [.06, .063, .064, .2, .5, .75, 1.0]) {
        await tester.tapAt(
          Offset(rect.left + 11 + (rect.width - 22) * fraction, rect.center.dy),
        );
        await tester.pump();
        final value = (c.captureRead().inputs['n'] as num).toDouble();
        if (previous != null) expect(value, greaterThanOrEqualTo(previous));
        previous = value;
      }
      final integer = _controller(
        r'''$n: number = 1000000000001
root = Slider(label="Exact",bind=$n,min=1000000000000,max=1000000000010,step=1)''',
      );
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_app(integer));
      expect(
        tester.getSemantics(find.bySemanticsLabel('Exact')).value,
        '1000000000001',
      );
      expect(find.text('1000000000001'), findsOneWidget);
      semantics.dispose();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'clicking a boolean control transfers focus from an editor and Space toggles its latest value',
    (tester) async {
      final c = _controller(r'''$name: string = ""
$on: boolean = false
root = Column(children=[field,toggle])
field = TextField(label="Name",bind=$name)
toggle = Switch(label="Enable",bind=$on)''');
      await tester.pumpWidget(_app(c));
      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
        isTrue,
      );
      await tester.tap(find.text('Enable'));
      // Focus changes are asynchronous, but the switch value is already current.
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
        isFalse,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(c.captureRead().inputs['on'], isTrue);
      expect(c.captureRead().inputs['name'], '');
    },
  );
  testWidgets(
    'slider coalesces a drag and flushes on release or keyboard commit',
    (tester) async {
      final c = _controller(r'''$n: number = 5
root = Slider(label="Amount",bind=$n,min=0,max=10)''');
      var flushes = 0;
      c.bindFlush(() async {
        flushes++;
      });
      await tester.pumpWidget(_app(c));
      final drag = await tester.startGesture(tester.getCenter(_track()));
      await drag.moveBy(const Offset(30, 0));
      await tester.pump();
      await drag.moveBy(const Offset(25, 0));
      await tester.pump();
      expect(c.captureRead().inputs['n'], greaterThan(5));
      expect(flushes, 0);
      await drag.up();
      await tester.pump();
      expect(flushes, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(flushes, 2);
    },
  );
  testWidgets(
    'slider keyboard and semantics change bounded state without a Material slider',
    (tester) async {
      final c = _controller(r'''$n: number = 5
root = Slider(label="Amount",bind=$n,min=0,max=10)''');
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_app(c));
      expect(find.byType(Slider), findsNothing);
      await tester.tap(_track());
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(c.captureRead().inputs['n'], 6);
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
      await tester.pump();
      expect(c.captureRead().inputs['n'], 1);
      final node = tester.getSemantics(find.bySemanticsLabel('Amount'));
      expect(node.getSemanticsData().flagsCollection.isSlider, isTrue);
      expect(node.value, '1');
      tester.binding.performSemanticsAction(
        ui.SemanticsActionEvent(
          type: ui.SemanticsAction.increase,
          nodeId: node.id,
          viewId: tester.view.viewId,
        ),
      );
      await tester.pump();
      expect(c.captureRead().inputs['n'], 2);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(c.captureRead().inputs['n'], 10);
      semantics.dispose();
    },
  );
  testWidgets(
    'slider mirrors pointer and arrow direction in RTL, numeric text stays LTR',
    (tester) async {
      final c = _controller(r'''$n: number = 5
root = Slider(label="Amount",bind=$n,min=0,max=10)''');
      await tester.pumpWidget(_app(c, rtl: true, scale: 1.3));
      await tester.tap(_track());
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(c.captureRead().inputs['n'], 6);
      final rect = tester.getRect(_track());
      await tester.tapAt(Offset(rect.left + 11, rect.center.dy));
      await tester.pump();
      expect(c.captureRead().inputs['n'], 10);
      final values = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(GenUiSlider),
              matching: find.byType(Text),
            ),
          )
          .where((w) => w.data == '10');
      expect(values.every((w) => w.textDirection == TextDirection.ltr), isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'slider fixed and very large finite ranges never divide or paint non-finite coordinates',
    (tester) async {
      final fixed = _controller(r'''$n: number = 2
root = Slider(label="Fixed",bind=$n,min=2,max=2)''');
      await tester.pumpWidget(_app(fixed));
      await tester.tap(_track());
      await tester.pump();
      expect(fixed.captureRead().inputs['n'], 2);
      expect(tester.takeException(), isNull);
      final huge = _controller(r'''$n: number = 0
root = Slider(label="Huge",bind=$n,min=-1e308,max=1e308,step=1e307)''');
      await tester.pumpWidget(_app(huge));
      await tester.tap(_track());
      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
      await tester.pump();
      expect(huge.captureRead().inputs['n'], closeTo(2e307, 1e292));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'a vertical scroll gesture over a slider does not edit its value',
    (tester) async {
      final c = _controller(r'''$n: number = 2
root = Slider(label="Amount",bind=$n,min=0,max=10)''');
      await tester.pumpWidget(_app(c));
      await tester.drag(_track(), const Offset(0, -100));
      await tester.pumpAndSettle();
      expect(c.captureRead().inputs['n'], 2);
    },
  );
  testWidgets(
    'switch and checkbox expose distinct semantics and keyboard actions; streaming locks both',
    (tester) async {
      final c = _controller(r'''$on: boolean = false
$ok: boolean = false
root = Column(children=[toggle,check])
toggle = Switch(label="Enable",bind=$on)
check = Checkbox(label="Agree",bind=$ok,required=true)''');
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_app(c));
      await tester.tap(find.text('Enable'));
      await tester.pump();
      expect(c.captureRead().inputs['on'], isTrue);
      final toggle = tester.getSemantics(find.bySemanticsLabel('Enable'));
      expect(
        toggle.getSemanticsData().flagsCollection.isToggled,
        ui.Tristate.isTrue,
      );
      final check = tester.getSemantics(find.bySemanticsLabel('Agree'));
      expect(
        check.getSemanticsData().flagsCollection.isChecked,
        ui.CheckedState.isFalse,
      );
      tester.binding.performSemanticsAction(
        ui.SemanticsActionEvent(
          type: ui.SemanticsAction.tap,
          nodeId: check.id,
          viewId: tester.view.viewId,
        ),
      );
      await tester.pump();
      expect(c.captureRead().inputs['ok'], isTrue);
      final detector = find.descendant(
        of: find.byType(GenUiBooleanInput).last,
        matching: find.byType(FocusableActionDetector),
      );
      tester
          .widget<FocusableActionDetector>(detector)
          .focusNode!
          .requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(c.captureRead().inputs['ok'], isFalse);
      c.updateSource(
        c.parsed.source,
        closed: true,
        generation: UiGenerationStatus.generating,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enable'), warnIfMissed: false);
      await tester.pump();
      expect(c.captureRead().inputs['on'], isTrue);
      semantics.dispose();
    },
  );
  testWidgets(
    'radio segments become wrapping rows for large text and retain state through appearance changes',
    (tester) async {
      final c = _controller(
        r'''$mode: string = "a"
root = RadioGroup(label="Mode",bind=$mode,options=[{"value":"a","label":"One"},{"value":"b","label":"Two"}])''',
      );
      await tester.pumpWidget(_app(c));
      expect(find.byType(GenUiSegments), findsOneWidget);
      await tester.tap(find.text('Two'));
      await tester.pump();
      expect(c.captureRead().inputs['mode'], 'b');
      await tester.pumpWidget(_app(c, rtl: true, scale: 1.3, dark: true));
      await tester.pumpAndSettle();
      expect(find.byType(GenUiSegments), findsNothing);
      expect(c.captureRead().inputs['mode'], 'b');
      await tester.tap(find.text('One'));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(c.captureRead().inputs['mode'], 'b');
      expect(_radio(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'desktop select uses a bounded popover, keyboard selection and Esc restore focus',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final c = _controller(
        r'''$mode: string = "a"
root = Select(label="Mode",bind=$mode,options=[{"value":"a","label":"One"},{"value":"b","label":"Two"},{"value":"c","label":"Three"}])''',
      );
      await tester.pumpWidget(_app(c));
      final trigger = find.byType(DesktopSelectDropdown<Object?>);
      await tester.tap(trigger);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(c.captureRead().inputs['mode'], 'b');
      expect(
        tester
            .widget<DesktopSelectDropdown<Object?>>(trigger)
            .focusNode!
            .hasFocus,
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DesktopSelectDropdown<Object?>>(trigger)
            .focusNode!
            .hasFocus,
        isTrue,
      );
      expect(find.text('Three'), findsNothing);
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    },
  );
  testWidgets(
    'mobile select distinguishes choosing null from cancelling and returns focus',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final c = _controller(
        r'''$mode: string? = "a"
root = Select(label="Mode",bind=$mode,options=[{"value":null,"label":"None"},{"value":"a","label":"One"}])''',
      );
      await tester.pumpWidget(_app(c));
      await tester.tap(find.text('One'));
      await tester.pumpAndSettle();
      expect(find.byType(FormSheet), findsOneWidget);
      await tester.tap(find.text('None'));
      await tester.pumpAndSettle();
      expect(c.captureRead().inputs['mode'], isNull);
      expect(find.byType(FormSheet), findsNothing);
      await tester.tap(find.text('None'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(c.captureRead().inputs['mode'], isNull);
      expect(find.byType(FormSheet), findsNothing);
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
