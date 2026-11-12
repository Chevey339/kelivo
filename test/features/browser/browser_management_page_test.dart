import 'package:Kelivo/features/browser/pages/browser_management_page.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/features/browser/widgets/browser_progressive_edge.dart';
import 'package:Kelivo/features/browser/widgets/browser_surface_controls.dart';
import 'package:Kelivo/features/browser/widgets/browser_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

void main() {
  Future<void> mount(
    WidgetTester tester,
    Widget home, {
    double width = 390,
    double textScale = 1,
    TextDirection direction = TextDirection.ltr,
    ColorScheme? colorScheme,
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 54, bottom: 34);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          platform: TargetPlatform.iOS,
          colorScheme: colorScheme,
        ),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: Directionality(textDirection: direction, child: child!),
        ),
        home: home,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'management header centers its title and leading Back pops once',
    (tester) async {
      await mount(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const BrowserManagementPage(
                    title: 'Browser settings',
                    child: Center(child: Text('Settings content')),
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final page = tester.getRect(find.byType(BrowserManagementPage));
      final title = tester.getRect(
        find.byKey(const ValueKey('browserManagementTitle')),
      );
      final back = tester.getRect(
        find.byKey(const ValueKey('browserManagementBack')),
      );
      expect(title.center.dx, closeTo(page.center.dx, .01));
      expect(back.size, const Size(48, 48));
      expect(back.left, closeTo(page.left + 16, .01));
      expect(back.top, greaterThanOrEqualTo(54));
      expect(title.left, greaterThan(back.right));
      expect(find.byIcon(LucideIcons.chevronLeft), findsOneWidget);
      expect(find.byIcon(LucideIcons.check), findsNothing);
      expect(
        tester.getRect(
          find.byKey(const ValueKey('browserManagementViewportClip')),
        ),
        page,
      );
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(BrowserManagementPage), findsNothing);
      expect(find.text('Open'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final direction in TextDirection.values) {
    testWidgets('long large title keeps Back reachable in $direction', (
      tester,
    ) async {
      var returned = 0;
      await mount(
        tester,
        BrowserManagementPage(
          title: 'A long browser management page title',
          onDone: () => returned++,
          child: const SizedBox.expand(),
        ),
        width: 320,
        textScale: 3,
        direction: direction,
      );
      final title = tester.getRect(
        find.byKey(const ValueKey('browserManagementTitle')),
      );
      final back = tester.getRect(
        find.byKey(const ValueKey('browserManagementBack')),
      );
      expect(title.center.dx, closeTo(160, .01));
      expect(back.size, const Size(48, 48));
      expect(title.overlaps(back), isFalse);
      expect(
        find.byIcon(
          direction == TextDirection.ltr
              ? LucideIcons.chevronLeft
              : LucideIcons.chevronRight,
        ),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(returned, 1);
      expect(tester.takeException(), isNull);
    });
  }

  for (final scale in [1.0, 3.0]) {
    for (final direction in TextDirection.values) {
      testWidgets(
        'header actions leave a centered readable title at $scale in $direction',
        (tester) async {
          var searched = 0;
          var cleared = 0;
          await mount(
            tester,
            BrowserManagementPage(
              title: 'History',
              trailingWidth: 96,
              trailing: BrowserSurfaceIconGroup(
                children: [
                  BrowserSurfaceIconButton(
                    useParentFeedback: true,
                    label: 'Search',
                    icon: LucideIcons.search,
                    size: 48,
                    onPressed: () => searched++,
                  ),
                  BrowserSurfaceIconButton(
                    useParentFeedback: true,
                    label: 'Clear history',
                    icon: LucideIcons.trash2,
                    size: 48,
                    onPressed: () => cleared++,
                  ),
                ],
              ),
              child: const SizedBox.expand(),
            ),
            width: 320,
            textScale: scale,
            direction: direction,
          );
          final title = tester.getRect(
            find.byKey(const ValueKey('browserManagementTitle')),
          );
          final back = tester.getRect(
            find.byKey(const ValueKey('browserManagementBack')),
          );
          final search = tester.getRect(find.byTooltip('Search'));
          final clear = tester.getRect(find.byTooltip('Clear history'));
          expect(title.center.dx, closeTo(160, .01));
          for (final rect in [back, search, clear]) {
            expect(rect.size, const Size(48, 48));
            expect(rect.overlaps(title), isFalse);
            expect(rect.left, greaterThanOrEqualTo(16));
            expect(rect.right, lessThanOrEqualTo(304));
          }
          expect(search.overlaps(clear), isFalse);
          final group = find.byType(BrowserSurfaceIconGroup);
          expect(tester.getSize(group), const Size(96, 48));
          expect(
            find.descendant(of: group, matching: find.byType(BrowserGlass)),
            findsOneWidget,
          );
          expect(
            find.descendant(of: group, matching: find.byType(BrowserPress)),
            findsOneWidget,
          );
          if (scale > 1) expect(title.top, greaterThan(back.bottom));
          final finger = await tester.startGesture(search.center);
          await tester.pump(const Duration(milliseconds: 120));
          // Shared press feedback must preserve the two adjacent 48pt targets;
          // a particular optical scale is not part of this header contract.
          expect(tester.getSize(group), const Size(96, 48));
          expect(tester.getSize(find.byTooltip('Search')), const Size(48, 48));
          expect(
            tester.getSize(find.byTooltip('Clear history')),
            const Size(48, 48),
          );
          await finger.cancel();
          await tester.pumpAndSettle();
          expect(searched, 0);
          expect(cleared, 0);
          await tester.tap(find.byTooltip('Search'));
          await tester.tap(find.byTooltip('Clear history'));
          expect(searched, 1);
          expect(cleared, 1);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('management scrolls under both safe-area edge masks', (
    tester,
  ) async {
    const colors = ColorScheme.light(surface: Color(0xffe8eff0));
    final controller = ScrollController();
    addTearDown(controller.dispose);
    var taps = 0;
    await mount(
      tester,
      BrowserManagementPage(
        title: 'History',
        child: Builder(
          builder: (context) => ListView.builder(
            controller: controller,
            padding:
                BrowserManagementPage.contentInsetsOf(context) +
                const EdgeInsets.only(bottom: 16),
            itemCount: 30,
            itemExtent: 52,
            itemBuilder: (_, index) =>
                TextButton(onPressed: () => taps++, child: Text('Item $index')),
          ),
        ),
      ),
      colorScheme: colors,
    );
    final list = find.byType(ListView);
    expect(tester.getRect(list), const Rect.fromLTWH(0, 0, 390, 844));
    final header = tester.getRect(
      find.byKey(const ValueKey('browserManagementBack')),
    );
    expect(tester.getRect(find.text('Item 0')).top, greaterThan(header.bottom));
    final edges = find.byType(BrowserProgressiveEdge);
    expect(edges, findsNWidgets(2));
    expect(tester.getRect(edges.first).top, 0);
    expect(tester.getRect(edges.last).bottom, 844);
    expect(tester.getRect(edges.last).top, lessThan(844 - 34));
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      colors.surface,
    );

    controller.jumpTo(90);
    await tester.pump();
    expect(tester.getRect(find.text('Item 0')).top, lessThan(header.top));
    expect(tester.getRect(list), const Rect.fromLTWH(0, 0, 390, 844));
    // The gradient occupies this touch location, but does not block scrolling.
    final before = controller.offset;
    await tester.dragFrom(const Offset(195, 800), const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(before));

    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    final lastButton = find.widgetWithText(TextButton, 'Item 29');
    expect(tester.getRect(lastButton).bottom, lessThanOrEqualTo(844 - 34));
    expect(
      tester.getRect(lastButton).center.dy,
      greaterThan(tester.getRect(edges.last).top),
    );
    await tester.tap(lastButton);
    await tester.pump();
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('headerless management keeps its own toolbar and route clip', (
    tester,
  ) async {
    await mount(
      tester,
      const BrowserManagementPage(
        title: 'Tabs',
        showHeader: false,
        child: ColoredBox(color: Colors.blue),
      ),
    );
    expect(find.byKey(const ValueKey('browserManagementBack')), findsNothing);
    expect(find.byKey(const ValueKey('browserManagementTitle')), findsNothing);
    expect(
      tester.getRect(
        find.byKey(const ValueKey('browserManagementViewportClip')),
      ),
      const Rect.fromLTWH(0, 0, 390, 844),
    );
    expect(tester.takeException(), isNull);
  });
}
