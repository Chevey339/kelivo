import 'package:Kelivo/features/browser/widgets/browser_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:Kelivo/features/browser/models/browser_models.dart';
import 'package:Kelivo/features/browser/widgets/browser_find_bar.dart';
import 'package:Kelivo/features/browser/widgets/browser_glass.dart';
import 'package:Kelivo/features/browser/widgets/browser_surface_controls.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

void main() {
  Future<({TextEditingController controller, List<String> calls})> mount(
    WidgetTester tester, {
    double width = 358,
    double scale = 1,
    bool compact = false,
    double keyboard = 0,
    TextDirection direction = TextDirection.ltr,
  }) async {
    tester.view.physicalSize = Size(width + 32, 700);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
    addTearDown(tester.view.reset);
    final controller = TextEditingController();
    final focus = FocusNode();
    final calls = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          platform: compact ? TargetPlatform.macOS : TargetPlatform.iOS,
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: Directionality(textDirection: direction, child: child!),
        ),
        home: BrowserGlassBackdrop(
          native: false,
          child: BrowserGlassScope(
            style: BrowserSurfaceStyle.solid,
            child: Scaffold(
              resizeToAvoidBottomInset: false,
              body: Builder(
                builder: (context) => Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      MediaQuery.viewInsetsOf(context).bottom + 16,
                    ),
                    child: BrowserFindBar(
                      key: const ValueKey('findDock'),
                      controller: controller,
                      focusNode: focus,
                      compact: compact,
                      onChanged: (value) => calls.add('change:$value'),
                      onSubmitted: (value) => calls.add('submit:$value'),
                      onPrevious: () => calls.add('previous'),
                      onNext: () => calls.add('next'),
                      onDone: () => calls.add('done'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      focus.dispose();
    });
    return (controller: controller, calls: calls);
  }

  Finder keyed(String value) => find.byKey(ValueKey(value));

  testWidgets('mobile has three separate aligned capsules and a blue check', (
    tester,
  ) async {
    await mount(tester);
    final done = tester.getRect(keyed('browserFindDone'));
    final search = tester.getRect(keyed('browserFindSearch'));
    final arrows = tester.getRect(keyed('browserFindArrows'));
    expect(tester.getSize(keyed('findDock')).height, 48);
    expect(done.size, const Size(48, 48));
    expect(arrows.size, const Size(96, 48));
    expect(search.height, 48);
    expect(search.left - done.right, 8);
    expect(arrows.left - search.right, 8);
    expect(done.center.dy, search.center.dy);
    expect(arrows.center.dy, search.center.dy);
    final action = tester.widget<BrowserSurfaceIconButton>(
      keyed('browserFindDone'),
    );
    expect(action.icon, LucideIcons.check);
    expect(action.backgroundColor, const Color(0xff007aff));
    expect(action.foregroundColor, Colors.white);
    expect(find.byType(BrowserSurfaceIconGroup), findsOneWidget);
    expect(find.byType(BrowserGlass), findsNWidgets(2));
    expect(find.byIcon(LucideIcons.search), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'input, submit, previous, next and Done keep independent callbacks',
    (tester) async {
      final result = await mount(tester);
      BrowserSurfaceIconButton action(String key) => tester.widget(keyed(key));
      expect(action('browserFindPrevious').onPressed, isNull);
      expect(action('browserFindNext').onPressed, isNull);
      final field = keyed('browserFindField');
      await tester.enterText(field, 'needle');
      await tester.pump();
      expect(result.calls, ['change:needle']);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      expect(result.calls.last, 'submit:needle');
      await tester.tap(keyed('browserFindPrevious'));
      await tester.tap(keyed('browserFindNext'));
      await tester.tap(keyed('browserFindDone'));
      expect(result.calls.skip(2), ['previous', 'next', 'done']);
      result.controller.text = '   ';
      await tester.pump();
      expect(action('browserFindPrevious').onPressed, isNull);
      expect(action('browserFindNext').onPressed, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  for (final (width, scale) in [
    (288.0, 1.0),
    (240.0, 1.0),
    (288.0, 2.0),
    (288.0, 3.0),
    (358.0, 3.0),
  ]) {
    testWidgets('find dock fits width $width at text scale $scale', (
      tester,
    ) async {
      await mount(tester, width: width, scale: scale);
      final dock = tester.getRect(keyed('findDock'));
      final done = tester.getRect(keyed('browserFindDone'));
      final search = tester.getRect(keyed('browserFindSearch'));
      final arrows = tester.getRect(keyed('browserFindArrows'));
      expect(dock.width, width);
      for (final child in [done, search, arrows]) {
        expect(child.left, greaterThanOrEqualTo(dock.left));
        expect(child.right, lessThanOrEqualTo(dock.right));
        expect(child.top, greaterThanOrEqualTo(dock.top));
        expect(child.bottom, lessThanOrEqualTo(dock.bottom));
      }
      if (width == 240 || scale > 1) {
        expect(arrows.top, greaterThanOrEqualTo(search.bottom + 8));
        expect(search.width, width - 56);
      } else {
        expect(dock.height, 48);
      }
      final editable = tester.getRect(find.byType(EditableText));
      expect(editable.width, greaterThan(70));
      await tester.enterText(
        keyed('browserFindField'),
        'A long search phrase which scrolls horizontally',
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('keyboard inset is applied only by its parent', (tester) async {
    await mount(tester, keyboard: 310);
    final dock = tester.getRect(keyed('findDock'));
    expect(dock.bottom, 700 - 310 - 16);
    expect(dock.height, 48);
    expect(tester.takeException(), isNull);
  });

  testWidgets('leading Done and trailing arrows follow RTL direction', (
    tester,
  ) async {
    await mount(tester, direction: TextDirection.rtl);
    final done = tester.getRect(keyed('browserFindDone'));
    final search = tester.getRect(keyed('browserFindSearch'));
    final arrows = tester.getRect(keyed('browserFindArrows'));
    expect(done.left - search.right, 8);
    expect(search.left - arrows.right, 8);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop stays compact without nesting another glass panel', (
    tester,
  ) async {
    await mount(tester, compact: true, width: 360);
    expect(tester.getSize(keyed('findDock')).height, 34);
    expect(find.byType(BrowserGlass), findsNothing);
    expect(find.byType(BrowserSurfaceIconGroup), findsNothing);
    expect(tester.getSize(keyed('browserFindArrows')), const Size(68, 34));
    final field = tester.widget<BrowserTextField>(keyed('browserFindField'));
    expect(field.style!.fontSize, 13);
    expect(tester.takeException(), isNull);
  });
}
