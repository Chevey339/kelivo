import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/features/browser/models/browser_models.dart';
import 'package:Kelivo/features/browser/pages/browser_mobile_layout.dart';
import 'package:Kelivo/features/browser/widgets/browser_glass.dart';
import 'package:Kelivo/features/browser/widgets/browser_progressive_edge.dart';

void main() {
  testWidgets(
    'Android keyboard moves the dock without rebuilding its viewport',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Future<void> mount(double inset, {bool reduceMotion = false}) =>
            tester.pumpWidget(
              MaterialApp(
                home: MediaQuery(
                  data: MediaQueryData(disableAnimations: reduceMotion),
                  child: BrowserMobileLayout(
                    keyboardInset: inset,
                    viewportResizesForKeyboard: false,
                    viewPadding: const EdgeInsets.only(top: 24, bottom: 24),
                    content: const ColoredBox(
                      key: ValueKey('keyboardViewport'),
                      color: Colors.white,
                    ),
                    toolbar: const SizedBox(
                      key: ValueKey('keyboardDock'),
                      height: 54,
                    ),
                  ),
                ),
              ),
            );
        final dock = find.byKey(const ValueKey('keyboardDock'));
        final viewport = find.byKey(const ValueKey('keyboardViewport'));
        await mount(0);
        final original = tester.getTopLeft(dock).dy;
        final viewportRect = tester.getRect(viewport);
        final viewportElement = tester.element(viewport);
        await mount(300);
        expect(tester.getTopLeft(dock).dy, original);
        await tester.pump(const Duration(milliseconds: 120));
        expect(
          tester.getTopLeft(dock).dy,
          inExclusiveRange(original - 276, original),
        );
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(dock).dy, closeTo(original - 276, .01));
        await mount(0);
        await tester.pump(const Duration(milliseconds: 120));
        expect(
          tester.getTopLeft(dock).dy,
          inExclusiveRange(original - 276, original),
        );
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(dock).dy, original);
        expect(tester.getRect(viewport), viewportRect);
        expect(identical(tester.element(viewport), viewportElement), isTrue);
        await mount(300, reduceMotion: true);
        await tester.pump();
        expect(tester.getTopLeft(dock).dy, closeTo(original - 276, .01));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'native dark toolbar fade preserves home indicator protection and tap access',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var taps = 0;
      Future<void> mount(bool fade) => tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: const ColorScheme.dark(surface: Colors.black),
          ),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              viewPadding: EdgeInsets.only(top: 59, bottom: 34),
            ),
            child: BrowserGlassScope(
              style: BrowserSurfaceStyle.liquid,
              child: RepaintBoundary(
                key: const ValueKey('darkEdgePixels'),
                child: BrowserMobileLayout(
                  viewPadding: const EdgeInsets.only(top: 59, bottom: 34),
                  underlapStatusBar: true,
                  fadeBehindToolbar: fade,
                  content: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => taps++,
                    child: const ColoredBox(color: Colors.white),
                  ),
                  toolbar: const SizedBox(height: 54),
                ),
              ),
            ),
          ),
        ),
      );
      Future<List<int>?> readPixels() => tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('darkEdgePixels')),
        );
        final image = await boundary.toImage();
        try {
          final pixels = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          // Expanded controls, collapsed capsule, then the home-indicator edge.
          return [
            773,
            797,
            843,
          ].map((y) => pixels.getUint8((y * 390 + 5) * 4)).toList();
        } finally {
          image.dispose();
        }
      });

      await mount(false);
      final original = (await readPixels())!;
      await mount(true);
      final faded = (await readPixels())!;
      expect(faded[0], greaterThan(original[0] + 16));
      expect(faded[1], greaterThan(original[1] + 32));
      expect(faded[2], closeTo(original[2], 2));
      expect(faded[2], lessThan(110));
      expect(find.byType(BackdropFilter), findsNothing);
      await tester.tapAt(const Offset(5, 797));
      await tester.tapAt(const Offset(5, 830));
      expect(taps, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('native webpage edges fade inward without blocking its taps', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
          ).copyWith(surface: Colors.white),
        ),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            viewPadding: EdgeInsets.only(top: 59, bottom: 34),
          ),
          child: RepaintBoundary(
            key: const ValueKey('edgePixels'),
            child: BrowserMobileLayout(
              viewPadding: const EdgeInsets.only(top: 59, bottom: 34),
              underlapStatusBar: true,
              content: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => taps++,
                child: const ColoredBox(color: Colors.blue),
              ),
              toolbar: const SizedBox(height: 54),
            ),
          ),
        ),
      ),
    );
    final top = tester.getRect(
      find.byKey(const ValueKey('browserMobileTopEdge')),
    );
    final bottom = tester.getRect(
      find.byKey(const ValueKey('browserMobileBottomEdge')),
    );
    expect(top, const Rect.fromLTWH(0, 0, 390, 83));
    expect(bottom, const Rect.fromLTWH(0, 736, 390, 108));
    expect(find.byType(BrowserProgressiveEdge), findsNWidgets(2));
    expect(find.byType(BackdropFilter), findsNothing);
    await tester.tapAt(const Offset(5, 20));
    await tester.tapAt(const Offset(5, 830));
    expect(taps, 2);
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('edgePixels')),
    );
    final red = await tester.runAsync(() async {
      final image = await boundary.toImage();
      try {
        final pixels = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        return [
          1,
          40,
          100,
          842,
          780,
          700,
        ].map((y) => pixels.getUint8((y * 390 + 5) * 4)).toList();
      } finally {
        image.dispose();
      }
    });
    expect(red![0], greaterThan(red[1]));
    expect(red[1], greaterThan(red[2]));
    expect(red[3], greaterThan(red[4]));
    expect(red[4], greaterThan(red[5]));
    expect(tester.takeException(), isNull);
  });

  testWidgets('address keyboard removes bottom fade without resizing webpage', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Future<void> mount(double inset) => tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            viewPadding: EdgeInsets.only(top: 59, bottom: 34),
          ),
          child: BrowserMobileLayout(
            viewPadding: const EdgeInsets.only(top: 59, bottom: 34),
            underlapStatusBar: true,
            keyboardInset: inset,
            viewportResizesForKeyboard: false,
            content: const ColoredBox(
              key: ValueKey('nativeSlot'),
              color: Colors.blue,
            ),
            toolbar: const SizedBox(height: 54),
          ),
        ),
      ),
    );
    await mount(0);
    final slot = tester.getRect(find.byKey(const ValueKey('nativeSlot')));
    final element = tester.element(find.byKey(const ValueKey('nativeSlot')));
    expect(
      find.byKey(const ValueKey('browserMobileBottomEdge')),
      findsOneWidget,
    );
    await mount(300);
    expect(find.byKey(const ValueKey('browserMobileBottomEdge')), findsNothing);
    expect(tester.getRect(find.byKey(const ValueKey('nativeSlot'))), slot);
    expect(
      identical(
        tester.element(find.byKey(const ValueKey('nativeSlot'))),
        element,
      ),
      isTrue,
    );
    expect(find.byKey(const ValueKey('browserMobileTopEdge')), findsOneWidget);
  });
}
