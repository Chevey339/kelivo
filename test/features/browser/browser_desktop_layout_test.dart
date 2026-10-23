import 'package:Kelivo/features/browser/widgets/browser_agent_status_chip.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/features/browser/pages/browser_desktop_layout.dart';
import 'package:Kelivo/features/browser/widgets/browser_desktop_toolbar.dart';
import 'package:Kelivo/features/browser/widgets/browser_tabs.dart';
import 'package:Kelivo/features/browser/widgets/browser_glass.dart';
import 'package:Kelivo/features/browser/models/browser_models.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

void main() {
  Future<void> mount(
    WidgetTester tester,
    Widget body, {
    Size size = const Size(1200, 800),
  }) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: body),
      ),
    );
    await tester.pumpAndSettle();
  }

  void desktopTest(String name, WidgetTesterCallback body) {
    testWidgets(name, (tester) async {
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  const toolbar = BrowserDesktopToolbar(
    navigation: SizedBox(key: ValueKey('navigation'), width: 122, height: 36),
    addressBar: SizedBox(key: ValueKey('address'), height: 32),
    actions: SizedBox(key: ValueKey('actions'), width: 126, height: 36),
    compactNavigation: SizedBox(
      key: ValueKey('navigation'),
      width: 64,
      height: 32,
    ),
    compactActions: SizedBox(key: ValueKey('actions'), width: 32, height: 32),
  );

  desktopTest('agent pill centers within the pane and find stays below it', (
    tester,
  ) async {
    await mount(
      tester,
      Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          key: const ValueKey('pane'),
          width: 480,
          child: BrowserDesktopLayout(
            embedded: true,
            tabBar: const SizedBox(),
            toolbar: toolbar,
            content: const SizedBox.expand(),
            agentStatus: BrowserAgentStatusChip(
              activity: BrowserAgentActivity.running,
              onPause: () {},
              onResume: () {},
            ),
            findBar: const SizedBox(height: 36),
          ),
        ),
      ),
    );
    final pane = tester.getRect(find.byKey(const ValueKey('pane')));
    final pill = tester.getRect(
      find.byKey(const ValueKey('browserAgentStatusChip')),
    );
    final findBar = tester.getRect(
      find.byKey(const ValueKey('browserDesktopFindSurface')),
    );
    expect(pill.center.dx, closeTo(pane.center.dx, .01));
    expect(findBar.top, greaterThanOrEqualTo(pill.bottom + 8));
    expect(findBar.right, lessThanOrEqualTo(pane.right));
    expect(tester.takeException(), isNull);
  });

  desktopTest(
    'blank title row moves window while tabs and toolbar stay interactive',
    (tester) async {
      const windowChannel = MethodChannel('window_manager');
      final calls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        windowChannel,
        (call) async {
          calls.add(call.method);
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          windowChannel,
          null,
        );
      });
      var selected = 0;
      var closed = 0;
      await mount(
        tester,
        BrowserDesktopLayout(
          toolbar: toolbar,
          tabBar: BrowserTabStrip(
            tabs: const [BrowserTab(id: 'one', title: 'One')],
            activeId: 'one',
            onSelect: (_) => selected++,
            onClose: (_) => closed++,
          ),
          content: const ColoredBox(color: Colors.white),
        ),
      );
      // This is inside the expanded tab-strip viewport but beyond its tab.
      await tester.dragFrom(const Offset(700, 20), const Offset(80, 0));
      await tester.pump();
      expect(calls.where((call) => call == 'startDragging'), hasLength(1));
      await tester.tap(find.text('One'));
      await tester.tap(find.byTooltip('Close tab'));
      await tester.dragFrom(const Offset(700, 64), const Offset(80, 0));
      await tester.pump(const Duration(milliseconds: 300));
      expect(selected, 1);
      expect(closed, 1);
      expect(calls.where((call) => call == 'startDragging'), hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  desktopTest(
    'address row uses available width below the native window controls',
    (tester) async {
      await mount(tester, const Column(children: [toolbar]));
      final navigation = tester.getRect(
        find.byKey(const ValueKey('navigation')),
      );
      final address = tester.getRect(find.byKey(const ValueKey('address')));
      final actions = tester.getRect(find.byKey(const ValueKey('actions')));
      expect(navigation.left, 10);
      expect(address.left, 278);
      expect(address.width, 640);
      expect(address.center.dy, 20);
      expect(navigation.right, lessThan(address.left));
      expect(address.right, lessThan(actions.left));
      expect(actions.right, 1190);
      expect(tester.takeException(), isNull);
    },
  );

  desktopTest(
    'very wide windows cap the address instead of stretching across the toolbar',
    (tester) async {
      await mount(
        tester,
        const Column(children: [toolbar]),
        size: const Size(1800, 900),
      );
      final address = tester.getRect(find.byKey(const ValueKey('address')));
      expect(address.width, 640);
      expect(address.center.dx, 898);
      expect(tester.takeException(), isNull);
    },
  );

  desktopTest(
    'tabs precede the toolbar and find floats without resizing or remounting the page',
    (tester) async {
      var showFind = false;
      late StateSetter update;
      final lifecycle = _Lifecycle();
      await mount(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return BrowserDesktopLayout(
              toolbar: toolbar,
              tabBar: const SizedBox(key: ValueKey('tabs'), height: 44),
              content: _Viewport(lifecycle: lifecycle),
              findBar: showFind
                  ? const SizedBox(key: ValueKey('findControls'), height: 48)
                  : null,
            );
          },
        ),
      );
      final viewport = find.byKey(const ValueKey('viewport'));
      final before = tester.getRect(viewport);
      expect(tester.getRect(find.byKey(const ValueKey('tabs'))).top, 0);
      expect(tester.getRect(find.byKey(const ValueKey('tabs'))).left, 96);
      expect(
        tester.getRect(find.byKey(const ValueKey('browserDesktopToolbar'))).top,
        44,
      );
      expect(before.top, 84);
      expect(lifecycle.mounts, 1);
      update(() => showFind = true);
      await tester.pumpAndSettle();
      final panel = tester.getRect(
        find.byKey(const ValueKey('browserDesktopFindSurface')),
      );
      expect(panel.width, 360);
      expect(panel.right, 1186);
      expect(panel.top, before.top + 12);
      expect(tester.getRect(viewport), before);
      expect(lifecycle.mounts, 1);
      expect(lifecycle.disposals, 0);
      update(() => showFind = false);
      await tester.pumpAndSettle();
      expect(tester.getRect(viewport), before);
      expect(lifecycle.mounts, 1);
      expect(lifecycle.disposals, 0);
      expect(tester.takeException(), isNull);
    },
  );

  desktopTest(
    'desktop tabs cap their width and keep independent close actions',
    (tester) async {
      final selections = <String>[];
      final closed = <String>[];
      await mount(
        tester,
        Column(
          children: [
            BrowserTabStrip(
              tabs: const [
                BrowserTab(id: 'a', title: 'One'),
                BrowserTab(id: 'b', title: 'Two'),
              ],
              activeId: 'a',
              onSelect: selections.add,
              onClose: closed.add,
            ),
          ],
        ),
      );
      Rect tabRect(String id) =>
          tester.getRect(find.byKey(ValueKey('browserDesktopTab-$id')));
      final first = tabRect('a');
      final second = tabRect('b');
      expect(first.width, second.width);
      expect(first.width, 216);
      expect(first.top, 6);
      expect(first.height, 32);
      expect(find.byTooltip('New tab'), findsNothing);
      expect(find.byTooltip('Close browser'), findsNothing);
      await tester.tap(find.byTooltip('Close tab').first);
      await tester.pumpAndSettle();
      expect(closed, ['a']);
      expect(selections, isEmpty);
      await tester.tap(find.text('Two'));
      await tester.pumpAndSettle();
      expect(selections, ['b']);
      expect(tester.takeException(), isNull);
    },
  );

  desktopTest(
    'many tabs keep a readable minimum width and scroll to the final tab',
    (tester) async {
      String? selected;
      await mount(
        tester,
        Column(
          children: [
            BrowserTabStrip(
              tabs: [
                for (var index = 0; index < 8; index++)
                  BrowserTab(id: '$index', title: 'Tab $index'),
              ],
              activeId: '0',
              onSelect: (id) => selected = id,
              onClose: (_) {},
            ),
          ],
        ),
        size: const Size(390, 700),
      );
      final first = tester.getRect(
        find.byKey(const ValueKey('browserDesktopTab-0')),
      );
      expect(first.width, 116);
      await tester.ensureVisible(find.text('Tab 7'));
      await tester.tap(find.text('Tab 7'));
      await tester.pumpAndSettle();
      expect(selected, '7');
      expect(tester.takeException(), isNull);
    },
  );

  desktopTest(
    'narrow windows keep address and command groups reachable without overlap',
    (tester) async {
      await mount(
        tester,
        const Column(children: [toolbar]),
        size: const Size(390, 700),
      );
      final address = tester.getRect(find.byKey(const ValueKey('address')));
      final navigation = tester.getRect(
        find.byKey(const ValueKey('navigation')),
      );
      final actions = tester.getRect(find.byKey(const ValueKey('actions')));
      expect(address.center.dy, navigation.center.dy);
      expect(address.center.dy, actions.center.dy);
      expect(address.width, 258);
      expect(navigation.right, lessThan(actions.left));
      expect(address.left, 82);
      expect(address.right, 340);
      expect(tester.takeException(), isNull);
    },
  );

  desktopTest(
    'native-inset layout lets the page extend behind its glass header',
    (tester) async {
      await mount(
        tester,
        const BrowserDesktopLayout(
          underlapHeader: true,
          toolbar: toolbar,
          tabBar: SizedBox(key: ValueKey('tabs'), height: 44),
          content: ColoredBox(key: ValueKey('page'), color: Colors.blue),
        ),
      );
      expect(tester.getRect(find.byKey(const ValueKey('page'))).top, 0);
      expect(tester.getSize(find.byKey(const ValueKey('page'))).height, 800);
      expect(tester.getRect(find.byKey(const ValueKey('tabs'))).left, 96);
      final header = tester.widget<BrowserGlass>(
        find.byKey(const ValueKey('browserDesktopHeader')),
      );
      expect(header.clear, isTrue);
      expect(header.radius, 0);
    },
  );

  desktopTest('embedded browser has no native-window-control offset', (
    tester,
  ) async {
    await mount(
      tester,
      const BrowserDesktopLayout(
        embedded: true,
        toolbar: toolbar,
        tabBar: SizedBox(key: ValueKey('tabs'), height: 44),
        content: SizedBox(key: ValueKey('page')),
      ),
      size: const Size(520, 700),
    );
    expect(tester.getRect(find.byKey(const ValueKey('tabs'))).left, 0);
    expect(tester.getRect(find.byKey(const ValueKey('page'))).top, 84);
    expect(
      tester.getRect(find.byKey(const ValueKey('browserDesktopToolbar'))).top,
      44,
    );
    expect(tester.takeException(), isNull);
  });
}

class _Lifecycle {
  int mounts = 0;
  int disposals = 0;
}

class _Viewport extends StatefulWidget {
  const _Viewport({required this.lifecycle});
  final _Lifecycle lifecycle;
  @override
  State<_Viewport> createState() => _ViewportState();
}

class _ViewportState extends State<_Viewport> {
  @override
  void initState() {
    super.initState();
    widget.lifecycle.mounts++;
  }

  @override
  void dispose() {
    widget.lifecycle.disposals++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      const ColoredBox(key: ValueKey('viewport'), color: Colors.white);
}
