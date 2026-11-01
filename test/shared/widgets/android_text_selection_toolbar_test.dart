import 'package:Kelivo/shared/widgets/android_text_selection_toolbar.dart';
import 'package:Kelivo/shared/widgets/app_text_selection_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/android_selection_menu_mock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final android = TargetPlatformVariant.only(TargetPlatform.android);
  late AndroidSelectionMenuMock native;
  setUp(() => native = AndroidSelectionMenuMock());
  tearDown(() => native.dispose());

  Widget harness(Widget child) => MaterialApp(home: Scaffold(body: child));
  Widget toolbar({
    Key? key,
    String label = 'Copy',
    VoidCallback? action,
    VoidCallback? dismissed,
    Offset primary = const Offset(120, 160),
    Offset? secondary,
  }) => Builder(
    builder: (context) => AppTextSelectionToolbar(
      key: key,
      anchors: TextSelectionToolbarAnchors(
        primaryAnchor: primary,
        secondaryAnchor: secondary,
      ),
      buttonItems: [ContextMenuButtonItem(label: label, onPressed: action)],
      selectionContext: context,
      onDismiss: dismissed ?? () {},
    ),
  );

  testWidgets('system menu owns a long list and external actions overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    tester.view.viewInsets = const FakeViewPadding(bottom: 990);
    tester.view.viewPadding = const FakeViewPadding(top: 90);
    addTearDown(tester.view.reset);
    var invoked = -1;
    final primary = [
      for (final label in [
        'Copy',
        'Quote',
        'Translate',
        'Markdown',
        'Rich text',
      ])
        ContextMenuButtonItem(label: label, onPressed: () {}),
    ];
    final external = List.generate(
      24,
      (i) => ContextMenuButtonItem(
        label: 'External $i',
        onPressed: () => invoked = i,
      ),
    );
    await tester.pumpWidget(
      harness(
        Builder(
          builder: (context) => AndroidTextSelectionToolbar(
            anchors: const TextSelectionToolbarAnchors(
              primaryAnchor: Offset(195, 480),
            ),
            buttonItems: [...primary, ...external],
            overflowItems: external.toSet(),
            selectionContext: context,
            onDismiss: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(native.menu['rect'], [585.0, 1440.0, 586.0, 1441.0]);
    expect(native.items, hasLength(29));
    expect(
      native.items.take(5).every((item) => item['overflow'] == false),
      isTrue,
    );
    expect(
      native.items.skip(5).every((item) => item['overflow'] == true),
      isTrue,
    );
    expect(find.byType(SingleChildScrollView), findsNothing);
    await native.press('External 23');
    expect(invoked, 23);
    await native.press('External 23');
    expect(invoked, 23);
    expect(native.calls.last.method, 'hide');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  }, variant: android);

  testWidgets('unchanged menu keeps its native page and uses latest callback', (
    tester,
  ) async {
    var selected = -1;
    for (var i = 0; i < 5; i++) {
      final value = i;
      await tester.pumpWidget(harness(toolbar(action: () => selected = value)));
      await tester.pumpAndSettle();
    }
    expect(native.calls.where((call) => call.method == 'show'), hasLength(1));
    await native.press('Copy');
    expect(selected, 4);
    await tester.pumpWidget(const SizedBox());
  }, variant: android);

  testWidgets('stale revisions, sessions and disabled actions are ignored', (
    tester,
  ) async {
    var actions = 0;
    var dismissed = 0;
    await tester.pumpWidget(
      harness(toolbar(action: () => actions++, dismissed: () => dismissed++)),
    );
    await tester.pumpAndSettle();
    final old = native.menu;
    await tester.pumpWidget(
      harness(toolbar(label: 'Quote', dismissed: () => dismissed++)),
    );
    await tester.pumpAndSettle();
    await native.event('action', old, index: 0);
    await native.press('Quote');
    expect(actions, 0);
    expect(dismissed, 0);
    await tester.pumpWidget(
      harness(toolbar(key: const ValueKey('next'), action: () => actions++)),
    );
    await tester.pumpAndSettle();
    await native.event('dismissed', old);
    await native.event('action', old, index: 0);
    await native.press('Copy');
    expect(actions, 1);
    await tester.pumpWidget(const SizedBox());
  }, variant: android);

  testWidgets('outside taps dismiss the menu and reach the underlying view', (
    tester,
  ) async {
    var taps = 0;
    var dismissed = 0;
    await tester.pumpWidget(
      harness(
        Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => taps++,
            ),
            toolbar(dismissed: () => dismissed++),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(40, 300));
    await tester.pumpAndSettle();
    expect(dismissed, 1);
    expect(taps, 1);
    expect(native.calls.last.method, 'hide');
    await tester.pumpWidget(const SizedBox());
  }, variant: android);

  testWidgets('scrolling retires the native menu and rejects late actions', (
    tester,
  ) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    var actions = 0;
    var dismissed = 0;
    await tester.pumpWidget(
      harness(
        SingleChildScrollView(
          controller: scroll,
          child: SizedBox(
            height: 1200,
            child: toolbar(
              action: () => actions++,
              dismissed: () => dismissed++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    scroll.jumpTo(20);
    await tester.pumpAndSettle();
    await native.press('Copy');
    expect(dismissed, 1);
    expect(actions, 0);
    await tester.pumpWidget(const SizedBox());
  }, variant: android);

  testWidgets('only changed window metrics dismiss the menu', (tester) async {
    var dismissed = 0;
    await tester.pumpWidget(harness(toolbar(dismissed: () => dismissed++)));
    await tester.pumpAndSettle();
    tester.binding.handleMetricsChanged();
    await tester.pumpAndSettle();
    expect(dismissed, 0);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);
    await tester.pumpAndSettle();
    expect(dismissed, 1);
    await tester.pumpWidget(const SizedBox());
  }, variant: android);

  testWidgets('offscreen editor sentinel uses the visible secondary anchor', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      harness(
        toolbar(
          primary: const Offset(-10000, -10000),
          secondary: const Offset(120, 160),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(native.menu['rect'], [120.0, 160.0, 121.0, 161.0]);
    await tester.pumpWidget(const SizedBox());
  }, variant: android);

  testWidgets('host rejection dismisses the Flutter toolbar owner', (
    tester,
  ) async {
    native.shown = false;
    var dismissed = 0;
    await tester.pumpWidget(harness(toolbar(dismissed: () => dismissed++)));
    await tester.pumpAndSettle();
    expect(dismissed, 1);
    expect(native.calls.map((call) => call.method), ['show', 'hide']);
    await tester.pumpWidget(const SizedBox());
  }, variant: android);
}
