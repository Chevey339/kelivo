import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/browser/browser_service.dart';
import 'package:Kelivo/core/services/browser/browser_store.dart';
import 'package:Kelivo/core/services/haptics.dart';
import 'package:Kelivo/features/browser/pages/browser_management_page.dart';
import 'package:Kelivo/features/browser/pages/browser_page.dart';
import 'package:Kelivo/features/browser/widgets/browser_scroll_configuration.dart';
import 'package:Kelivo/features/browser/widgets/browser_settings.dart';
import 'package:Kelivo/features/browser/widgets/browser_surface_controls.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

void main() {
  void browserTest(String name, WidgetTesterCallback body) {
    testWidgets(name, (tester) async {
      Haptics.setEnabled(false);
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        debugDefaultTargetPlatformOverride = null;
        Haptics.setEnabled(true);
        await tester.pumpAndSettle();
      }
    });
  }

  Future<void> mount(
    WidgetTester tester,
    Widget child, {
    TargetPlatform platform = TargetPlatform.android,
    ScrollBehavior? behavior,
    Size size = const Size(390, 600),
  }) async {
    debugDefaultTargetPlatformOverride = platform;
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: platform, useMaterial3: true),
        scrollBehavior: behavior,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );
    await tester.pumpAndSettle();
  }

  Widget rows(ScrollController controller, {VoidCallback? onTap}) =>
      ListView.builder(
        controller: controller,
        itemCount: 40,
        itemExtent: 56,
        itemBuilder: (_, index) =>
            TextButton(onPressed: onTap ?? () {}, child: Text('Row $index')),
      );

  Future<void> pullAtBothEnds(
    WidgetTester tester,
    ScrollController controller,
    Finder list, {
    required bool stretch,
  }) async {
    controller.jumpTo(0);
    await tester.pump();
    final top = await tester.startGesture(tester.getCenter(list));
    await top.moveBy(const Offset(0, 30));
    await top.moveBy(const Offset(0, 110));
    await tester.pump(const Duration(milliseconds: 16));
    expect(controller.offset, 0);
    if (stretch) {
      expect(
        find.descendant(
          of: find.byType(StretchingOverscrollIndicator),
          matching: find.byWidgetPredicate(
            (widget) =>
                (widget is Transform && widget.filterQuality != null) ||
                (widget is ImageFiltered && widget.enabled),
          ),
        ),
        findsWidgets,
      );
    }
    expect(
      find.byType(StretchingOverscrollIndicator),
      stretch ? findsOneWidget : findsNothing,
    );
    await top.up();
    await tester.pumpAndSettle();
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    final bottom = await tester.startGesture(tester.getCenter(list));
    await bottom.moveBy(const Offset(0, -30));
    await bottom.moveBy(const Offset(0, -110));
    await tester.pump(const Duration(milliseconds: 16));
    expect(controller.offset, controller.position.maxScrollExtent);
    expect(
      find.byType(StretchingOverscrollIndicator),
      stretch ? findsOneWidget : findsNothing,
    );
    await bottom.up();
    await tester.pumpAndSettle();
  }

  browserTest(
    'ordinary Android Material lists still stretch at both boundaries',
    (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await mount(tester, Scaffold(body: rows(controller)));
      await pullAtBothEnds(
        tester,
        controller,
        find.byType(ListView),
        stretch: true,
      );
      expect(tester.takeException(), isNull);
    },
  );

  browserTest(
    'browser Android lists scroll and accept taps without a stretch layer',
    (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      var taps = 0;
      await mount(
        tester,
        BrowserScrollConfiguration(
          child: Scaffold(body: rows(controller, onTap: () => taps++)),
        ),
      );
      final list = find.byType(ListView);
      await tester.drag(list, const Offset(0, -180));
      await tester.pumpAndSettle();
      expect(controller.offset, greaterThan(0));
      expect(controller.offset, lessThan(controller.position.maxScrollExtent));
      await pullAtBothEnds(tester, controller, list, stretch: false);
      expect(find.byType(GlowingOverscrollIndicator), findsNothing);
      await tester.tap(find.text('Row 39'));
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    },
  );

  browserTest('iOS keeps its original behavior and real bouncing offset', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    late ScrollBehavior original;
    late ScrollBehavior inherited;
    await mount(
      tester,
      Builder(
        builder: (context) {
          original = ScrollConfiguration.of(context);
          return BrowserScrollConfiguration(
            child: Builder(
              builder: (context) {
                inherited = ScrollConfiguration.of(context);
                return Scaffold(body: rows(controller));
              },
            ),
          );
        },
      ),
      platform: TargetPlatform.iOS,
    );
    expect(identical(inherited, original), isTrue);
    expect(find.byType(StretchingOverscrollIndicator), findsNothing);
    expect(find.byType(GlowingOverscrollIndicator), findsNothing);
    final finger = await tester.startGesture(
      tester.getCenter(find.byType(ListView)),
    );
    await finger.moveBy(const Offset(0, 30));
    await finger.moveBy(const Offset(0, 110));
    await tester.pump(const Duration(milliseconds: 16));
    expect(controller.offset, lessThan(0));
    await finger.up();
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(0, .01));
    expect(tester.takeException(), isNull);
  });

  browserTest('browser scope retains custom scrollbars and mouse drag policy', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await mount(
      tester,
      BrowserScrollConfiguration(child: Scaffold(body: rows(controller))),
      behavior: const _ScrollbarBehavior(),
    );
    expect(find.byType(Scrollbar), findsOneWidget);
    final mouse = await tester.startGesture(
      tester.getCenter(find.byType(ListView)),
      kind: PointerDeviceKind.mouse,
    );
    await mouse.moveBy(const Offset(0, -30));
    await mouse.moveBy(const Offset(0, -110));
    await tester.pump();
    expect(controller.offset, greaterThan(0));
    await mouse.up();
    await tester.pumpAndSettle();
    await pullAtBothEnds(
      tester,
      controller,
      find.byType(ListView),
      stretch: false,
    );
    expect(find.byType(Scrollbar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  browserTest(
    'browser start and independently pushed management pages have no stretch decoration',
    (tester) async {
      final service = BrowserService(store: _MemoryStore(), supported: true);
      await service.initialize();
      try {
        await mount(tester, BrowserPage(service: service));
        expect(find.byType(BrowserStartPage), findsOneWidget);
        expect(find.byType(ListView), findsOneWidget);
        expect(find.byType(StretchingOverscrollIndicator), findsNothing);
        await tester.tap(find.byTooltip('More').last);
        await tester.pumpAndSettle();
        // The portal menu inherits the browser's configuration as well.
        expect(find.byType(SingleChildScrollView), findsWidgets);
        expect(find.byType(StretchingOverscrollIndicator), findsNothing);
        await tester.tap(find.text('Browser settings'));
        await tester.pumpAndSettle();
        expect(find.byType(BrowserManagementPage), findsOneWidget);
        expect(find.byType(BrowserSettingsPanel), findsOneWidget);
        expect(find.byType(StretchingOverscrollIndicator), findsNothing);
        await tester.tap(find.text('Search engine'));
        await tester.pumpAndSettle();
        expect(find.byType(BrowserDialogHeader), findsOneWidget);
        expect(find.byType(StretchingOverscrollIndicator), findsNothing);
        await tester.tap(find.text('Google').last);
        await tester.pumpAndSettle();
        expect(find.byType(BrowserDialogHeader), findsNothing);
        expect(find.text('Google'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        service.dispose();
        await tester.pumpAndSettle();
      }
    },
  );

  browserTest(
    'Android embedded settings dialog also keeps scrolling outside stretch filters',
    (tester) async {
      final service = BrowserService(store: _MemoryStore(), supported: true);
      await service.initialize();
      try {
        await mount(
          tester,
          BrowserPage(service: service, embedded: true),
          size: const Size(1100, 700),
        );
        await tester.tap(find.byTooltip('More').last);
        await tester.pumpAndSettle();
        expect(find.byType(StretchingOverscrollIndicator), findsNothing);
        await tester.tap(find.text('Browser settings'));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('browserPanel')), findsOneWidget);
        expect(find.byType(BrowserManagementPage), findsNothing);
        final panel = find.byType(BrowserSettingsPanel);
        final list = find.descendant(
          of: panel,
          matching: find.byType(ListView),
        );
        final scroll = tester.state<ScrollableState>(
          find.descendant(of: panel, matching: find.byType(Scrollable)),
        );
        final originalPhysics = const MaterialScrollBehavior().getScrollPhysics(
          scroll.context,
        );
        final scopedPhysics = ScrollConfiguration.of(
          scroll.context,
        ).getScrollPhysics(scroll.context);
        final physics = scroll.position.physics;
        expect(identical(scopedPhysics, originalPhysics), isTrue);
        expect(scroll.position.maxScrollExtent, greaterThan(0));
        expect(find.byType(StretchingOverscrollIndicator), findsNothing);
        await tester.drag(list, const Offset(0, -100));
        await tester.pumpAndSettle();
        expect(scroll.position.pixels, greaterThan(0));
        scroll.position.jumpTo(scroll.position.maxScrollExtent);
        await tester.pump();
        final pull = await tester.startGesture(tester.getCenter(list));
        await pull.moveBy(const Offset(0, -30));
        await pull.moveBy(const Offset(0, -90));
        await tester.pump(const Duration(milliseconds: 16));
        // A captured dialog theme may use bouncing physics even on Android.
        // Removing its stretch decoration must not clamp that existing bounce.
        expect(identical(scroll.position.physics, physics), isTrue);
        expect(
          scroll.position.pixels,
          greaterThanOrEqualTo(scroll.position.maxScrollExtent),
        );
        expect(find.byType(StretchingOverscrollIndicator), findsNothing);
        await pull.up();
        await tester.pumpAndSettle();
        expect(
          scroll.position.pixels,
          closeTo(scroll.position.maxScrollExtent, .01),
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        service.dispose();
        await tester.pumpAndSettle();
      }
    },
  );

  browserTest(
    'a browser dialog scopes its own root-navigator scrolling content',
    (tester) async {
      await mount(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => unawaited(
                showBrowserDialog<void>(
                  context,
                  child: Column(
                    children: [
                      for (var i = 0; i < 25; i++)
                        SizedBox(
                          height: 56,
                          child: TextButton(
                            onPressed: () => Navigator.of(
                              context,
                              rootNavigator: true,
                            ).pop(),
                            child: Text('Choose $i'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              child: const Text('Dialog'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Dialog'));
      await tester.pumpAndSettle();
      expect(find.byType(StretchingOverscrollIndicator), findsNothing);
      final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
      final finger = await tester.startGesture(
        tester.getCenter(find.byType(SingleChildScrollView)),
      );
      await finger.moveBy(const Offset(0, -30));
      await finger.moveBy(const Offset(0, -130));
      await tester.pump();
      expect(scroll.position.pixels, greaterThan(0));
      await finger.up();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Choose 8'));
      await tester.tap(find.text('Choose 8'));
      await tester.pumpAndSettle();
      expect(find.byType(SingleChildScrollView), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

class _ScrollbarBehavior extends MaterialScrollBehavior {
  const _ScrollbarBehavior();
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
  };
  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => Scrollbar(controller: details.controller, child: child);
}

class _MemoryStore extends BrowserStore {
  @override
  Future<Map<String, dynamic>> read() async => {};
  @override
  Future<void> write(Map<String, Object?> state) async {}
}
