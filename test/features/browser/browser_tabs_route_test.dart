import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/services/browser/browser_service.dart';
import 'package:Kelivo/core/services/browser/browser_store.dart';
import 'package:Kelivo/features/browser/browser_tabs_route.dart';
import 'package:Kelivo/features/browser/models/browser_models.dart';
import 'package:Kelivo/features/browser/pages/browser_management_page.dart';
import 'package:Kelivo/features/browser/widgets/browser_glass.dart';
import 'package:Kelivo/features/browser/widgets/browser_tabs.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

void main() {
  Future<({BrowserTabsRoute route, _PreviewService service})> mount(
    WidgetTester tester, {
    bool reduceMotion = false,
    bool openingPreviewReady = true,
    String activeTab = 'a',
    int tabCount = 2,
    bool blankTabs = false,
    ui.Image? startPageSnapshot,
    Uint8List? previewBytes,
    Rect initialContentRect = const Rect.fromLTWH(0, 0, 390, 844),
    Rect Function(BrowserTab?)? contentRectForTab,
    VoidCallback? onFallbackBuild,
    VoidCallback? onReturnStarted,
    String? conversationId,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
    addTearDown(tester.view.reset);
    final service = _PreviewService(
      activeTab,
      tabCount,
      blankTabs: blankTabs,
      previewBytes: previewBytes,
    );
    await service.initialize();
    late BrowserTabsRoute route;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => RepaintBoundary(
          key: const ValueKey('browserTabRoutePixels'),
          child: child,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () {
                  final motion = BrowserTabTransitionController(
                    service: service,
                    initialTabId: service.activeTabId,
                    initialContentRect: initialContentRect,
                    contentRectForTab:
                        contentRectForTab ?? (_) => initialContentRect,
                    openingPreviewReady: openingPreviewReady,
                    startPageSnapshot: startPageSnapshot,
                    fallbackBuilder: (_, tab) {
                      onFallbackBuild?.call();
                      return ColoredBox(
                        color: Colors.purple,
                        child: Center(
                          child: Text('Preview ${tab?.id ?? "new"}'),
                        ),
                      );
                    },
                  );
                  route = BrowserTabsRoute(
                    transition: motion,
                    reduceMotion: reduceMotion,
                    onReturnStarted: onReturnStarted,
                    builder: (pageContext) => BrowserGlassScope(
                      style: BrowserSurfaceStyle.solid,
                      child: BrowserManagementPage(
                        title: 'Tabs',
                        showHeader: false,
                        child: BrowserTabOverview(
                          service: service,
                          conversationId: conversationId,
                          transition: motion,
                          onDone: () => Navigator.of(pageContext).pop(),
                          onSelect: (id) {
                            motion.prepareReturn(id);
                            Navigator.of(pageContext).pop();
                          },
                          onClose: (id) => service.closeTab(id),
                          onNew: () {
                            motion.prepareReturn(null);
                            Navigator.of(pageContext).pop();
                          },
                        ),
                      ),
                    ),
                  );
                  Navigator.of(context).push(route);
                },
                child: const Text('Open tabs'),
              ),
            ),
          ),
        ),
      ),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      service.dispose();
      await tester.pumpAndSettle();
    });
    if (previewBytes != null) {
      await tester.runAsync(
        () => precacheImage(
          MemoryImage(previewBytes),
          tester.element(find.text('Open tabs')),
        ),
      );
    }
    await tester.tap(find.text('Open tabs'));
    await tester.pump();
    return (route: route, service: service);
  }

  testWidgets('closing the scope menu does not freeze the tab return target', (
    tester,
  ) async {
    var returns = 0;
    final state = await mount(
      tester,
      conversationId: 'chat-a',
      onReturnStarted: () => returns++,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('browserTabScope')));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(state.route.isCurrent, isTrue);
    expect(returns, 0);
    final current = find.byKey(const ValueKey('browserTabCard-a'));
    await tester.tap(
      find.descendant(of: current, matching: find.byTooltip('Close tab')),
    );
    await tester.pumpAndSettle();
    expect(state.service.activeTabId, 'b');
    await tester.tap(find.byTooltip('Done'));
    await tester.pump();
    expect(state.route.transition.tabId, 'b');
    expect(returns, 1);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  const landmarks = <(Offset, Color)>[
    (Offset(35, 140), Color(0xffff0000)),
    (Offset(325, 140), Color(0xff00ff00)),
    (Offset(195, 280), Color(0xff0000ff)),
  ];

  Future<ui.Image> contentImage(WidgetTester tester, double nativeTop) async {
    // The native underlapping view contains a 59pt status strip; the inset
    // view already begins below it. Both capture contracts normalize to the
    // same page-content pixels before the route receives the image.
    final cropTop = 59 - nativeTop;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawColor(const Color(0xffffffff), ui.BlendMode.src);
    for (final (point, color) in landmarks) {
      canvas.drawRect(
        Rect.fromCenter(
          center: point + Offset(0, cropTop),
          width: 16,
          height: 16,
        ),
        Paint()..color = color,
      );
    }
    final nativePicture = recorder.endRecording();
    final native = await tester.runAsync(
      () => nativePicture.toImage(390, (844 - nativeTop).toInt()),
    );
    nativePicture.dispose();
    final croppedRecorder = ui.PictureRecorder();
    ui.Canvas(croppedRecorder).drawImageRect(
      native!,
      Rect.fromLTWH(0, cropTop, 390, 785),
      const Rect.fromLTWH(0, 0, 390, 785),
      Paint(),
    );
    final picture = croppedRecorder.endRecording();
    final cropped = await tester.runAsync(() => picture.toImage(390, 785));
    picture.dispose();
    native.dispose();
    return cropped!;
  }

  Future<void> expectLandmarks(WidgetTester tester, Rect frame) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('browserTabRoutePixels')),
    );
    final pixels = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return data!;
    });
    for (final (point, color) in landmarks) {
      // Width is the sole scale factor. Frame height only clips the bottom;
      // it must never enlarge/crop the image horizontally to fill the frame.
      final screen = frame.topLeft + point * (frame.width / 390);
      final offset = (screen.dy.floor() * 390 + screen.dx.floor()) * 4;
      final actual = Color.fromARGB(
        pixels!.getUint8(offset + 3),
        pixels.getUint8(offset),
        pixels.getUint8(offset + 1),
        pixels.getUint8(offset + 2),
      );
      expect(actual, color, reason: 'source $point in $frame at $screen');
    }
  }

  for (final (label, nativeTop, blank) in [
    ('web inset', 59.0, false),
    ('web underlap cropped', 0.0, false),
    ('blank page cropped', 0.0, true),
  ]) {
    testWidgets('$label keeps content landmarks through both zoom handoffs', (
      tester,
    ) async {
      final raster = await contentImage(tester, nativeTop);
      addTearDown(raster.dispose);
      final encoded = await tester.runAsync(
        () => raster.toByteData(format: ui.ImageByteFormat.png),
      );
      const contentRect = Rect.fromLTWH(0, 59, 390, 785);
      final result = await mount(
        tester,
        tabCount: 1,
        blankTabs: blank,
        startPageSnapshot: blank ? raster : null,
        previewBytes: blank ? null : encoded!.buffer.asUint8List(),
        initialContentRect: contentRect,
      );
      await tester.pump();
      final flight = find.byKey(const ValueKey('browserTabSnapshotFlight'));
      expect(tester.getRect(flight), contentRect);
      await expectLandmarks(tester, contentRect);
      await tester.pump(const Duration(milliseconds: 180));
      await expectLandmarks(tester, tester.getRect(flight));
      await tester.pumpAndSettle();
      final card = find.byKey(result.route.transition.previewKeyFor('a'));
      final cardRect = tester.getRect(card);
      await expectLandmarks(tester, cardRect);
      await tester.tap(card);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));
      await expectLandmarks(tester, tester.getRect(flight));
      await tester.pump(const Duration(milliseconds: 144));
      final end = tester.getRect(flight);
      // This is the last sampled moving frame, not the disposed endpoint.
      // Assert its exact trajectory at the actual controller value rather
      // than assuming 304ms is already close enough to a 320ms animation.
      final remaining = Curves.easeInOutCubic.transform(
        result.route.animation!.value,
      );
      final expected = Rect.lerp(contentRect, cardRect, remaining)!;
      expect(end.left, closeTo(expected.left, .00001));
      expect(end.top, closeTo(expected.top, .00001));
      expect(end.width, closeTo(expected.width, .00001));
      expect(end.height, closeTo(expected.height, .00001));
      await expectLandmarks(tester, end);
      expect(result.route.transition.contentRect, contentRect);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('selected destination resolves its own content bounds once', (
    tester,
  ) async {
    var resolutions = 0;
    final result = await mount(
      tester,
      initialContentRect: const Rect.fromLTWH(0, 59, 390, 785),
      contentRectForTab: (tab) {
        resolutions++;
        return tab?.id == 'b'
            ? const Rect.fromLTWH(0, 0, 390, 844)
            : const Rect.fromLTWH(0, 59, 390, 785);
      },
    );
    await tester.pumpAndSettle();
    expect(resolutions, 0);
    await tester.tap(find.byKey(result.route.transition.previewKeyFor('b')));
    await tester.pump();
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(resolutions, 1);
    expect(
      result.route.transition.contentRect,
      const Rect.fromLTWH(0, 0, 390, 844),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'page shrinks into its real card without moving overview controls',
    (tester) async {
      final result = await mount(tester);
      // Navigator first lays a pushed route out offstage with its animation
      // proxy forced to 1. A second zero-time frame clears that measuring pass
      // and paints the actual first transition frame at progress 0.
      await tester.pump();
      expect(result.route.offstage, isFalse);
      expect(result.route.animation!.value, 0);
      final flight = find.byKey(const ValueKey('browserTabSnapshotFlight'));
      expect(flight, findsOneWidget);
      expect(tester.getRect(flight), const Rect.fromLTWH(0, 0, 390, 844));
      await tester.pump(const Duration(milliseconds: 16));
      final actions = find.byKey(const ValueKey('browserTabActions'));
      final start = tester.getRect(flight);
      final actionsRect = tester.getRect(actions);
      expect(start.width, greaterThan(360));
      await tester.pump(const Duration(milliseconds: 120));
      final middle = tester.getRect(flight);
      expect(middle.width, lessThan(start.width));
      expect(middle.top, greaterThan(start.top));
      expect(tester.getRect(actions), actionsRect);
      await tester.pumpAndSettle();
      expect(flight, findsNothing);
      expect(tester.getRect(actions), actionsRect);
      expect(result.service.captures, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'tapped tab expands from that card rather than the previous tab',
    (tester) async {
      final result = await mount(tester);
      await tester.pumpAndSettle();
      final second = find.byKey(result.route.transition.previewKeyFor('b'));
      final sourceRect = tester.getRect(second);
      await tester.tap(second);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      final flight = find.byKey(const ValueKey('browserTabSnapshotFlight'));
      final rect = tester.getRect(flight);
      expect(result.route.transition.tabId, 'b');
      expect((rect.left - sourceRect.left).abs(), lessThan(2));
      expect((rect.width - sourceRect.width).abs(), lessThan(2));
      expect(find.text('Preview b'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byType(BrowserTabOverview), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('edge swipe can cancel without shifting or clipping Done', (
    tester,
  ) async {
    final result = await mount(tester);
    await tester.pumpAndSettle();
    final done = find.byTooltip('Done');
    final before = tester.getRect(done);
    final gesture = await tester.startGesture(const Offset(2, 400));
    await gesture.moveTo(const Offset(40, 400));
    await tester.pump();
    await gesture.moveTo(const Offset(110, 400));
    await tester.pump(const Duration(milliseconds: 80));
    expect(result.route.popGestureInProgress, isTrue);
    expect(tester.getRect(done), before);
    expect(
      find.byKey(const ValueKey('browserTabSnapshotFlight')),
      findsOneWidget,
    );
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(result.route.isCurrent, isTrue);
    expect(result.route.popGestureInProgress, isFalse);
    expect(tester.getRect(done), before);
    expect(tester.takeException(), isNull);
  });

  testWidgets('edge swipe can finish dismissal', (tester) async {
    await mount(tester);
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(const Offset(2, 400));
    await gesture.moveTo(const Offset(35, 400));
    await tester.pump();
    await gesture.moveTo(const Offset(320, 400));
    await tester.pump(const Duration(milliseconds: 80));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byType(BrowserTabOverview), findsNothing);
    expect(find.text('Open tabs'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'programmatic back during an edge gesture cannot restore a popped route',
    (tester) async {
      final result = await mount(tester);
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(const Offset(2, 400));
      await gesture.moveTo(const Offset(40, 400));
      await tester.pump();
      await gesture.moveTo(const Offset(110, 400));
      await tester.pump(const Duration(milliseconds: 80));
      result.route.navigator!.pop();
      await tester.pump();
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(find.byType(BrowserTabOverview), findsNothing);
      expect(find.text('Open tabs'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('new tab returns with fade and no unrelated card flight', (
    tester,
  ) async {
    await mount(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('New tab'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(
      find.byKey(const ValueKey('browserTabSnapshotFlight')),
      findsNothing,
    );
    await tester.pumpAndSettle();
    expect(find.byType(BrowserTabOverview), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'stale opening preview fades in but selected card can still expand',
    (tester) async {
      final result = await mount(tester, openingPreviewReady: false);
      final flight = find.byKey(const ValueKey('browserTabSnapshotFlight'));
      expect(flight, findsNothing);
      await tester.pump(const Duration(milliseconds: 100));
      expect(flight, findsNothing);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(result.route.transition.previewKeyFor('b')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(flight, findsOneWidget);
      expect(result.route.transition.canFly, isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(BrowserTabOverview), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('opening a later active tab scrolls its actual card into view', (
    tester,
  ) async {
    final result = await mount(tester, activeTab: 'h', tabCount: 10);
    await tester.pump(const Duration(milliseconds: 16));
    expect(
      find.byKey(const ValueKey('browserTabSnapshotFlight')),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
    final card = tester.getRect(
      find.byKey(result.route.transition.previewKeyFor('h')),
    );
    expect(card.top, greaterThanOrEqualTo(59));
    expect(card.bottom, lessThan(844 - 86));
    expect(tester.takeException(), isNull);
  });

  for (final (id, count) in [
    ('b', 2),
    ('c', 3),
    ('c', 4),
    ('d', 4),
    ('f', 6),
    ('h', 8),
  ]) {
    testWidgets(
      'opening $id of $count lands on that card without a grid rebound',
      (tester) async {
        final result = await mount(tester, activeTab: id, tabCount: count);
        await tester.pump();
        final grid = find.byKey(const ValueKey('browserTabGrid'));
        final position = tester
            .state<ScrollableState>(
              find.descendant(of: grid, matching: find.byType(Scrollable)),
            )
            .position;
        final initialOffset = position.pixels;
        expect(initialOffset, inInclusiveRange(0, position.maxScrollExtent));
        if (count <= 4) expect(initialOffset, 0);
        await tester.pump(const Duration(milliseconds: 150));
        final flight = tester.getRect(
          find.byKey(const ValueKey('browserTabSnapshotFlight')),
        );
        final progress = Curves.easeInOutCubic.transform(
          result.route.animation!.value,
        );
        const full = Rect.fromLTWH(0, 0, 390, 844);
        final destination = Rect.fromLTRB(
          (flight.left - full.left * (1 - progress)) / progress,
          (flight.top - full.top * (1 - progress)) / progress,
          (flight.right - full.right * (1 - progress)) / progress,
          (flight.bottom - full.bottom * (1 - progress)) / progress,
        );
        final selected = tester.getRect(
          find.byKey(result.route.transition.previewKeyFor(id)),
        );
        expect(destination.left, closeTo(selected.left, .01));
        expect(destination.top, closeTo(selected.top, .01));
        expect(destination.right, closeTo(selected.right, .01));
        expect(destination.bottom, closeTo(selected.bottom, .01));
        if (id != 'c') {
          // b, d, f and h are in the right column, never the first card.
          expect(destination.left, greaterThan(195));
        }
        await tester.pumpAndSettle();
        expect(position.pixels, closeTo(initialOffset, .01));
        expect(
          tester.getRect(find.byKey(result.route.transition.previewKeyFor(id))),
          selected,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('reduced motion does not animate a snapshot', (tester) async {
    final result = await mount(tester, reduceMotion: true);
    await tester.pumpAndSettle();
    expect(result.route.transitionDuration, Duration.zero);
    expect(
      find.byKey(const ValueKey('browserTabSnapshotFlight')),
      findsNothing,
    );
    await tester.tap(find.byTooltip('Done'));
    await tester.pumpAndSettle();
    expect(find.byType(BrowserTabOverview), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'real preview and optical grid remain opaque until committed handoff',
    (tester) async {
      var returns = 0;
      await mount(tester, onReturnStarted: () => returns++);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 340));
      Opacity opacity(String key) =>
          tester.widget<Opacity>(find.byKey(ValueKey(key)));
      expect(opacity('browserTabFlightOpacity').opacity, 1);
      expect(opacity('browserTabOverviewOpacity').opacity, 1);
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(const Offset(2, 400));
      await gesture.moveTo(const Offset(40, 400));
      await tester.pump();
      await gesture.moveTo(const Offset(110, 400));
      await tester.pump();
      expect(returns, 0);
      expect(opacity('browserTabFlightOpacity').opacity, 1);
      expect(opacity('browserTabOverviewOpacity').opacity, 1);
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(returns, 0);
      await tester.tap(find.byTooltip('Done'));
      expect(returns, 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(opacity('browserTabFlightOpacity').opacity, 1);
      expect(opacity('browserTabOverviewOpacity').opacity, 1);
      await tester.pumpAndSettle();
      expect(returns, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'fallback flight has app typography and builds once across animation frames',
    (tester) async {
      var builds = 0;
      final result = await mount(
        tester,
        activeTab: 'b',
        onFallbackBuild: () => builds++,
      );
      await tester.pump();
      final text = find.text('Preview b');
      expect(text, findsOneWidget);
      final style = DefaultTextStyle.of(tester.element(text)).style;
      expect(style.decoration, TextDecoration.none);
      expect(style.color, Theme.of(tester.element(text)).colorScheme.onSurface);
      for (var frame = 0; frame < 15; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(builds, 1);
      expect(result.service.captures, 0);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('grid and flight reuse one thumbnail image stream', (
    tester,
  ) async {
    final cache = PaintingBinding.instance.imageCache;
    cache.clear();
    cache.clearLiveImages();
    final result = await mount(tester, tabCount: 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    final images = tester.widgetList<Image>(find.byType(Image)).toList();
    expect(images, hasLength(2));
    expect(images.first.image, images.last.image);
    final key = await images.first.image.obtainKey(ImageConfiguration.empty);
    // The route and card both subscribe to the same image stream; native
    // thumbnails are already 440px and need no second 640px ResizeImage key.
    expect(key, isA<MemoryImage>());
    final flightStream = images.first.image.resolve(ImageConfiguration.empty);
    final cardStream = images.last.image.resolve(ImageConfiguration.empty);
    expect(identical(flightStream.completer, cardStream.completer), isTrue);
    await tester.pumpAndSettle();
    expect(cache.statusForKey(key).live, isTrue);
    expect(cache.liveImageCount, 1);
    expect(result.service.captures, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'route keeps warmed preview identities when native capture finishes late',
    (tester) async {
      final result = await mount(tester);
      await tester.pumpAndSettle();
      final warmed = result.route.transition.previewForTab('a')!;
      final replacement = Uint8List.fromList(warmed);
      result.service.replacePreview('a', replacement);
      result.service.replacePreview('b', replacement);
      await tester.pumpAndSettle();
      expect(result.service.previewForTab('a'), same(replacement));
      expect(result.route.transition.previewForTab('a'), same(warmed));
      expect(result.route.transition.previewForTab('b'), isNull);
      final card = find.byKey(result.route.transition.previewKeyFor('a'));
      final image = tester.widget<Image>(
        find.descendant(of: card, matching: find.byType(Image)),
      );
      expect((image.image as MemoryImage).bytes, same(warmed));
      expect(
        find.descendant(
          of: find.byKey(result.route.transition.previewKeyFor('b')),
          matching: find.byType(Image),
        ),
        findsNothing,
      );
      await tester.tap(card);
      await tester.pump();
      expect(result.route.transition.previewBytes, same(warmed));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'blank tabs reuse one painted raster without rebuilding the start page',
    (tester) async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawColor(const Color(0xff234567), ui.BlendMode.src);
      final picture = recorder.endRecording();
      final raster = await tester.runAsync(() => picture.toImage(39, 84));
      picture.dispose();
      addTearDown(raster!.dispose);
      var builds = 0;
      final result = await mount(
        tester,
        blankTabs: true,
        startPageSnapshot: raster,
        onFallbackBuild: () => builds++,
      );
      await tester.pump();
      final flight = find.byKey(const ValueKey('browserTabSnapshotFlight'));
      final source = tester
          .widget<RawImage>(
            find.descendant(of: flight, matching: find.byType(RawImage)),
          )
          .image!;
      final cardRasters = tester.widgetList<RawImage>(
        find.descendant(
          of: find.byType(BrowserTabOverview),
          matching: find.byType(RawImage),
        ),
      );
      expect(cardRasters, hasLength(2));
      expect(
        cardRasters.every((image) => identical(image.image, source)),
        isTrue,
      );
      for (var frame = 0; frame < 15; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(builds, 0);
      expect(result.service.captures, 0);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Done'));
      await tester.pumpAndSettle();
      expect(source.debugDisposed, isTrue);
      expect(raster.debugDisposed, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}

class _PreviewService extends BrowserService {
  _PreviewService(
    String activeTab,
    int count, {
    bool blankTabs = false,
    Uint8List? previewBytes,
  }) : _bytes =
           previewBytes ??
           base64Decode(
             'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1UAAAAASUVORK5CYII=',
           ),
       super(store: _MemoryStore(activeTab, count, blankTabs), supported: true);
  int captures = 0;
  final Uint8List _bytes;
  final Map<String, Uint8List?> _replacements = {};

  void replacePreview(String id, Uint8List? bytes) {
    _replacements[id] = bytes;
    notifyListeners();
  }

  @override
  Future<void> refreshActivePreview({bool fresh = false}) async => captures++;

  @override
  Uint8List? previewForTab(String id) => _replacements.containsKey(id)
      ? _replacements[id]
      : id == 'b'
      ? null
      : _bytes;
}

class _MemoryStore extends BrowserStore {
  _MemoryStore(this.activeTab, this.count, this.blankTabs);
  final String activeTab;
  final int count;
  final bool blankTabs;
  @override
  Future<Map<String, dynamic>> read() async => {
    'activeTabId': activeTab,
    'tabs': [
      for (var i = 0; i < count; i++)
        {
          'id': String.fromCharCode(97 + i),
          'url': blankTabs ? 'about:blank' : 'https://page$i.example',
          'title': 'Page ${String.fromCharCode(97 + i)}',
        },
    ],
  };
  @override
  Future<void> write(Map<String, Object?> state) async {}
}
