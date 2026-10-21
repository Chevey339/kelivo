import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/services/browser/browser_service.dart';
import 'package:Kelivo/core/services/browser/browser_store.dart';
import 'package:Kelivo/features/browser/models/browser_models.dart';
import 'package:Kelivo/features/browser/pages/browser_management_page.dart';
import 'package:Kelivo/features/browser/widgets/browser_surface_controls.dart';
import 'package:Kelivo/features/browser/widgets/browser_glass.dart';
import 'package:Kelivo/features/browser/widgets/browser_progressive_edge.dart';
import 'package:Kelivo/features/browser/widgets/browser_tabs.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

void main() {
  Future<void> mount(
    WidgetTester tester,
    Widget body, {
    Size size = const Size(390, 844),
    bool desktop = false,
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        theme: ThemeData(
          platform: desktop ? TargetPlatform.macOS : TargetPlatform.android,
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(body: body),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'desktop tabs stay compact and expose close on active or hovered tabs',
    (tester) async {
      final selections = <String>[];
      final closed = <String>[];
      await mount(
        tester,
        Column(
          children: [
            BrowserTabStrip(
              tabs: const [
                BrowserTab(id: 'a', title: 'First'),
                BrowserTab(id: 'b', title: 'Second'),
              ],
              activeId: 'a',
              onSelect: selections.add,
              onClose: closed.add,
            ),
          ],
        ),
        size: const Size(1200, 700),
        desktop: true,
      );
      final first = find.byKey(const ValueKey('browserDesktopTab-a'));
      final second = find.byKey(const ValueKey('browserDesktopTab-b'));
      expect(tester.getSize(first).width, lessThanOrEqualTo(220));
      expect(tester.getSize(second).width, lessThanOrEqualTo(220));
      expect(tester.getSize(find.byType(BrowserTabStrip)).height, 44);
      expect(find.byTooltip('Close tab'), findsOneWidget);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(1000, 300));
      await mouse.moveTo(tester.getCenter(second));
      await tester.pump();
      expect(find.byTooltip('Close tab'), findsNWidgets(2));
      final close = find.descendant(
        of: second,
        matching: find.byType(BrowserSurfaceIconButton),
      );
      expect(tester.widget<BrowserSurfaceIconButton>(close).iconSize, 14);
      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(closed, ['b']);
      expect(selections, isEmpty);
      await mouse.moveTo(const Offset(1000, 300));
      await tester.pump();
      expect(find.byTooltip('Close tab'), findsOneWidget);
      await tester.tap(find.text('Second'));
      expect(selections, ['b']);
      await mouse.removePointer();
      expect(tester.takeException(), isNull);
    },
  );

  for (final (desktop, size, scale) in [
    (false, const Size(390, 844), 1.0),
    (true, const Size(1200, 800), 1.0),
    (false, const Size(320, 800), 3.0),
  ]) {
    testWidgets(
      'tab overview uses page cards at $size with text scale $scale',
      (tester) async {
        final service = _PreviewService();
        await service.initialize();
        final selected = <String>[];
        final closed = <String>[];
        var created = 0;
        var done = 0;
        try {
          await mount(
            tester,
            BrowserTabOverview(
              service: service,
              onSelect: selected.add,
              onClose: closed.add,
              onNew: () => created++,
              onDone: () => done++,
            ),
            size: size,
            desktop: desktop,
            scale: scale,
          );
          expect(service.captures, ['a']);
          final card = find.byKey(const ValueKey('browserTabCard-a'));
          final image = find.descendant(of: card, matching: find.byType(Image));
          expect(image, findsOneWidget);
          final imageBounds = tester.getRect(image);
          final title = find.descendant(
            of: card,
            matching: find.text('First page'),
          );
          expect(
            tester.getRect(title).top,
            greaterThanOrEqualTo(imageBounds.bottom),
          );
          if (desktop) {
            expect(imageBounds.width, greaterThan(imageBounds.height));
          } else {
            expect(imageBounds.height, greaterThan(imageBounds.width));
            expect(find.byType(EditableText), findsNothing);
            expect(
              tester.getSize(find.byTooltip('Search tabs')),
              const Size(44, 44),
            );
            final pill = find.byKey(const ValueKey('browserTabCountPill'));
            final add = find.byTooltip('New tab');
            final doneButton = find.byTooltip('Done');
            expect(tester.getCenter(pill).dx, closeTo(size.width / 2, .01));
            expect(
              tester.getCenter(add).dx + tester.getCenter(doneButton).dx,
              closeTo(size.width, .01),
            );
            expect(tester.getSize(add), const Size(52, 52));
            expect(tester.getSize(doneButton), const Size(52, 52));
            final check = tester.widget<Icon>(
              find.descendant(of: doneButton, matching: find.byType(Icon)),
            );
            expect(check.color, Colors.white);
            expect(
              find.descendant(of: add, matching: find.byType(BrowserPress)),
              findsOneWidget,
            );
          }
          expect(find.byType(GridView), findsOneWidget);
          final close = find.descendant(
            of: card,
            matching: find.byType(BrowserSurfaceIconButton),
          );
          expect(
            tester.widget<BrowserSurfaceIconButton>(close).size,
            desktop ? 26 : 30,
          );
          expect(
            tester.widget<BrowserSurfaceIconButton>(close).iconSize,
            desktop ? 14 : 18,
          );
          await tester.tap(
            find.descendant(of: card, matching: find.byTooltip('Close tab')),
          );
          await tester.pump();
          expect(closed, ['a']);
          expect(selected, isEmpty);
          await tester.tap(find.byTooltip('New tab'));
          expect(created, 1);
          if (desktop) {
            final newCard = find.byKey(const ValueKey('browserNewTabCard'));
            expect(newCard, findsOneWidget);
            expect(tester.getSize(newCard), tester.getSize(card));
            expect(find.byTooltip('Done'), findsNothing);
            expect(find.text('2 tabs'), findsNothing);
            expect(done, 0);
          } else {
            expect(
              find.byKey(const ValueKey('browserNewTabCard')),
              findsNothing,
            );
            await tester.tap(find.byTooltip('Done'));
            expect(done, 1);
          }
          service.refresh();
          await tester.pumpAndSettle();
          expect(service.captures, ['a']);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          service.dispose();
          await tester.pumpAndSettle();
        }
      },
    );
  }

  testWidgets(
    'desktop new-tab card follows the grid and remains available with no search matches',
    (tester) async {
      final service = _PreviewService();
      await service.initialize();
      var created = 0;
      try {
        await mount(
          tester,
          BrowserTabOverview(
            service: service,
            onSelect: (_) {},
            onClose: (_) {},
            onNew: () => created++,
          ),
          size: const Size(1200, 800),
          desktop: true,
        );
        final newCard = find.byKey(const ValueKey('browserNewTabCard'));
        final lastTab = find.byKey(const ValueKey('browserTabCard-b'));
        expect(
          tester.getRect(newCard).left,
          greaterThan(tester.getRect(lastTab).right),
        );
        expect(tester.getRect(newCard).top, tester.getRect(lastTab).top);
        final field = find.byType(EditableText);
        expect(tester.getRect(field).left, greaterThan(800));
        await tester.enterText(field, 'second.example');
        await tester.pumpAndSettle();
        expect(lastTab, findsOneWidget);
        expect(newCard, findsNothing);
        await tester.enterText(field, 'not-a-matching-tab');
        await tester.pumpAndSettle();
        expect(lastTab, findsNothing);
        expect(newCard, findsOneWidget);
        await tester.tap(newCard);
        expect(created, 1);
        await tester.enterText(field, '');
        await tester.pumpAndSettle();
        expect(lastTab, findsOneWidget);
        expect(newCard, findsOneWidget);
        expect(service.captures, ['a']);
        expect(find.byTooltip('Done'), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        service.dispose();
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets(
    'overview searches title or URL without recapturing its native page',
    (tester) async {
      final service = _PreviewService();
      await service.initialize();
      try {
        await mount(
          tester,
          BrowserTabOverview(
            service: service,
            onSelect: (_) {},
            onClose: (_) {},
            onNew: () {},
            onDone: () {},
          ),
        );
        final field = find.byType(EditableText);
        expect(field, findsNothing);
        await tester.tap(find.byTooltip('Search tabs'));
        await tester.pumpAndSettle();
        expect(field, findsOneWidget);
        expect(tester.widget<EditableText>(field).focusNode.hasFocus, isTrue);
        await tester.enterText(field, 'second.example');
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('browserTabCard-a')), findsNothing);
        expect(find.byKey(const ValueKey('browserTabCard-b')), findsOneWidget);
        expect(service.captures, ['a']);
        await tester.tap(find.byTooltip('Cancel'));
        await tester.pumpAndSettle();
        expect(field, findsNothing);
        expect(find.byTooltip('Search tabs'), findsOneWidget);
        expect(find.byKey(const ValueKey('browserTabCard-a')), findsOneWidget);
        expect(find.byKey(const ValueKey('browserTabCard-b')), findsOneWidget);
        expect(service.captures, ['a']);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        service.dispose();
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets('page notifications retain the existing overview grid', (
    tester,
  ) async {
    final service = _PreviewService();
    await service.initialize();
    try {
      await mount(
        tester,
        BrowserTabOverview(
          service: service,
          onSelect: (_) {},
          onClose: (_) {},
          onNew: () {},
        ),
      );
      final grid = find.byKey(const ValueKey('browserTabGrid'));
      final initial = tester.widget<GridView>(grid);
      for (var frame = 0; frame < 20; frame++) {
        service.refresh();
        await tester.pump(const Duration(milliseconds: 16));
        expect(identical(tester.widget<GridView>(grid), initial), isTrue);
      }
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      service.dispose();
      await tester.pumpAndSettle();
    }
  });

  testWidgets(
    'mobile tab grid scrolls beneath both safe-area edges while controls stay fixed',
    (tester) async {
      tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
      tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      final service = _PreviewService(tabCount: 8);
      await service.initialize();
      try {
        await mount(
          tester,
          BrowserManagementPage(
            title: 'Tabs',
            showHeader: false,
            child: BrowserTabOverview(
              service: service,
              onSelect: (_) {},
              onClose: (_) {},
              onNew: () {},
              onDone: () {},
            ),
          ),
        );
        final grid = find.byKey(const ValueKey('browserTabGrid'));
        expect(tester.getRect(grid), const Rect.fromLTWH(0, 0, 390, 844));
        final top = find.byKey(const ValueKey('browserTabsTopEdge'));
        final bottom = find.byKey(const ValueKey('browserTabsBottomEdge'));
        expect(find.byType(BrowserProgressiveEdge), findsNWidgets(2));
        expect(tester.getRect(top).top, 0);
        expect(tester.getRect(bottom).bottom, 844);
        expect(tester.getRect(top).bottom, lessThan(200));
        expect(tester.getRect(bottom).height, lessThan(200));
        for (final edge in [top, bottom]) {
          final ignore = find.descendant(
            of: edge,
            matching: find.byType(IgnorePointer),
          );
          expect(tester.widget<IgnorePointer>(ignore).ignoring, isTrue);
        }
        final actions = find.byKey(const ValueKey('browserTabActions'));
        final search = find.byTooltip('Search tabs');
        final actionRect = tester.getRect(actions);
        final searchRect = tester.getRect(search);
        expect(actionRect.bottom, 844 - 34 - 12);
        expect(searchRect.top, 59 + 12);
        final firstCard = find.byKey(const ValueKey('browserTabCard-a'));
        final initialTop = tester.getRect(firstCard).top;
        await tester.drag(grid, const Offset(0, -100));
        await tester.pumpAndSettle();
        expect(tester.getRect(firstCard).top, lessThan(59));
        expect(tester.getRect(firstCard).top, lessThan(initialTop - 70));
        expect(tester.getRect(actions), actionRect);
        expect(tester.getRect(search), searchRect);
        expect(service.captures, ['a']);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        service.dispose();
        await tester.pumpAndSettle();
      }
    },
  );

  for (final (desktop, size, scale) in [
    (false, const Size(390, 844), 1.0),
    (true, const Size(1200, 800), 1.0),
    (false, const Size(320, 844), 3.0),
  ]) {
    testWidgets('scope selector keeps chat tabs separate at $size / $scale', (
      tester,
    ) async {
      final service = _PreviewService(owners: {'a': 'chat-a', 'b': 'chat-b'});
      await service.initialize();
      try {
        await mount(
          tester,
          BrowserTabOverview(
            service: service,
            conversationId: 'chat-a',
            conversationTitle: (id) => id == 'chat-b' ? 'Research' : 'Writing',
            onSelect: (_) {},
            onClose: (_) {},
            onNew: () {},
          ),
          desktop: desktop,
          size: size,
          scale: scale,
        );
        expect(find.byKey(const ValueKey('browserTabCard-a')), findsOneWidget);
        expect(find.byKey(const ValueKey('browserTabCard-b')), findsNothing);
        await tester.tap(find.text('All tabs'));
        await tester.pumpAndSettle();
        expect(find.text('This chat · 1'), findsOneWidget);
        expect(find.byKey(const ValueKey('browserTabCard-b')), findsOneWidget);
        expect(find.text('Research · 1'), findsOneWidget);
        expect(service.liveViewCount, 0);
        await tester.tap(find.text('This chat'));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('browserTabCard-b')), findsNothing);
        expect(service.captures, ['a']);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        service.dispose();
        await tester.pumpAndSettle();
      }
    });
  }

  testWidgets(
    'management shell is a full route and Back returns to its caller',
    (tester) async {
      await mount(
        tester,
        Builder(
          builder: (context) => BrowserTextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const BrowserManagementPage(
                  title: 'Bookmarks',
                  child: Center(child: Text('Saved page')),
                ),
              ),
            ),
            child: const Text('Open library'),
          ),
        ),
      );
      await tester.tap(find.text('Open library'));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byType(BrowserManagementPage)),
        const Rect.fromLTWH(0, 0, 390, 844),
      );
      expect(find.text('Saved page'), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(BrowserManagementPage), findsNothing);
      expect(find.text('Open library'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _PreviewService extends BrowserService {
  _PreviewService({int tabCount = 2, Map<String, String> owners = const {}})
    : super(
        store: _MemoryStore(tabCount: tabCount, owners: owners),
        supported: true,
      );
  final captures = <String>[];
  final _bytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1UAAAAASUVORK5CYII=',
  );
  @override
  Future<void> refreshActivePreview({bool fresh = false}) async {
    captures.add(activeTabId!);
    notifyListeners();
  }

  @override
  Uint8List? previewForTab(String id) => id != 'a' ? null : _bytes;

  void refresh() => notifyListeners();
}

class _MemoryStore extends BrowserStore {
  _MemoryStore({this.tabCount = 2, this.owners = const {}});
  final int tabCount;
  final Map<String, String> owners;
  @override
  Future<Map<String, dynamic>> read() async => {
    'activeTabId': 'a',
    'tabs': [
      {
        'id': 'a',
        'url': 'https://first.example',
        'title': 'First page',
        'ownerSessionId': owners['a'],
      },
      {
        'id': 'b',
        'url': 'https://second.example',
        'title': 'Second page',
        'ownerSessionId': owners['b'],
      },
      for (var index = 2; index < tabCount; index++)
        {
          'id': String.fromCharCode(97 + index),
          'url': 'https://page$index.example',
          'title': 'Page $index',
        },
    ],
  };
  @override
  Future<void> write(Map<String, Object?> state) async {}
}
