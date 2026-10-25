import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:Kelivo/features/browser/models/browser_models.dart';
import 'package:Kelivo/features/browser/widgets/browser_glass.dart';
import 'package:Kelivo/features/browser/widgets/browser_scroll_configuration.dart';

// Explicit Android Impeller regression probe, outside the default test glob.
// No app settings, browser storage, WebViews, network or user data are accessed.
// flutter drive -d <android-device> --keep-app-running --no-dds \
//   --driver=test_driver/integration_test.dart \
//   --target=integration_test/browser_overscroll_glass_probe.dart
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.onlyPumps;
  testWidgets('held Android overscroll preserves the external glass backdrop', (
    tester,
  ) async {
    expect(
      Platform.isAndroid,
      isTrue,
      reason: 'Run this on the Android renderer.',
    );
    expect(defaultTargetPlatform, TargetPlatform.android);
    expect(
      ui.ImageFilter.isShaderFilterSupported,
      isTrue,
      reason: 'Real Impeller shader filters are required.',
    );
    await BrowserGlass.prewarm(nativeBackdrop: false);
    final directory = await Directory.systemTemp.createTemp(
      'browser-overscroll-',
    );
    final results = <Map<String, Object?>>[];
    final images = <String, String>{};
    final pixelRatio = tester.view.devicePixelRatio;
    final logicalSize = tester.view.physicalSize / pixelRatio;
    final width = math.min(360.0, logicalSize.width - 32);
    final height = math.min(420.0, logicalSize.height - 120);
    expect(width, greaterThanOrEqualTo(240));
    expect(height, greaterThanOrEqualTo(300));
    ScrollController? activeController;
    TestGesture? heldGesture;
    try {
      for (final fixed in [false, true]) {
        final captureKey = GlobalKey();
        final topKey = GlobalKey();
        final bottomKey = GlobalKey();
        final controller = ScrollController();
        activeController = controller;
        var overscrollEvents = 0;
        Widget scroller = NotificationListener<OverscrollNotification>(
          onNotification: (_) {
            overscrollEvents++;
            return false;
          },
          child: SingleChildScrollView(
            key: const ValueKey('overscrollProbeViewport'),
            controller: controller,
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            child: Column(
              children: [
                const SizedBox(height: 48),
                _tile(topKey),
                SizedBox(height: height * 2),
                _tile(bottomKey),
                const SizedBox(height: 48),
              ],
            ),
          ),
        );
        if (fixed) scroller = BrowserScrollConfiguration(child: scroller);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              useMaterial3: true,
              platform: TargetPlatform.android,
            ),
            scrollBehavior: const MaterialScrollBehavior(),
            home: Scaffold(
              backgroundColor: const Color(0xfff2f2f7),
              body: Align(
                // The shader's scene coordinates and capture coordinates must
                // share their origin; a centered offscreen capture is a different
                // render target from the live scene's backdrop sampling space.
                alignment: Alignment.topLeft,
                child: BrowserGlassBackdrop(
                  native: false,
                  child: BrowserGlassScope(
                    style: BrowserSurfaceStyle.liquid,
                    child: SizedBox(
                      width: width,
                      height: height,
                      child: RepaintBoundary(
                        key: captureKey,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Deliberately outside the scroll subtree. The old
                            // StretchEffect isolates this backdrop from glass.
                            const ColoredBox(color: Color(0xfff2f2f7)),
                            scroller,
                          ],
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
        expect(
          find.byType(StretchingOverscrollIndicator),
          fixed ? findsNothing : findsOneWidget,
        );
        final boundary =
            captureKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        expect(tester.getTopLeft(find.byKey(captureKey)), Offset.zero);
        final viewport = find.byKey(const ValueKey('overscrollProbeViewport'));

        Future<_Pixels> capture(String name) async {
          final image = await boundary.toImage(pixelRatio: pixelRatio);
          try {
            final rgba = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            final png = (await image.toByteData(
              format: ui.ImageByteFormat.png,
            ))!;
            final bytes = png.buffer.asUint8List(
              png.offsetInBytes,
              png.lengthInBytes,
            );
            await File('${directory.path}/$name.png').writeAsBytes(bytes);
            images[name] = base64Encode(bytes);
            return _Pixels(rgba, image.width, image.height);
          } finally {
            image.dispose();
          }
        }

        for (final edge in ['top', 'bottom']) {
          final target = edge == 'top'
              ? 0.0
              : controller.position.maxScrollExtent;
          controller.jumpTo(target);
          await tester.pumpAndSettle();
          final tile = edge == 'top' ? topKey : bottomKey;
          final bounds = tester
              .getRect(find.byKey(tile))
              .shift(-tester.getTopLeft(find.byKey(captureKey)));
          // Interior only: excludes the refracting rounded edge and its shadow.
          // A uniform settings background has no pattern a vertical stretch can
          // shift into the sample, so darkening measures a material change.
          final region = bounds.deflate(32);
          final name = '${fixed ? 'fixed' : 'baseline'}-$edge';
          final rest = await capture('$name-rest');
          final beforeEvents = overscrollEvents;
          heldGesture = await tester.startGesture(tester.getCenter(viewport));
          final direction = edge == 'top' ? 1.0 : -1.0;
          await heldGesture.moveBy(Offset(0, 36 * direction));
          await tester.pump(const Duration(milliseconds: 16));
          await heldGesture.moveBy(Offset(0, 104 * direction));
          await tester.pump(const Duration(milliseconds: 16));
          // Capture before up/cancel. Do not settle the held gesture away.
          expect(overscrollEvents, greaterThan(beforeEvents));
          expect(controller.offset, closeTo(target, .001));
          final stretches = tester
              .widgetList<StretchEffect>(find.byType(StretchEffect))
              .toList();
          if (fixed) {
            expect(stretches, isEmpty);
          } else {
            expect(stretches.single.stretchStrength.abs(), greaterThan(.001));
          }
          final held = await capture('$name-held');
          final heldDiff = _difference(held, rest, region, pixelRatio);
          final backdropDiff = _difference(
            held,
            rest,
            Rect.fromLTWH(4, region.top, 8, region.height),
            pixelRatio,
          );
          await heldGesture.up();
          heldGesture = null;
          await tester.pumpAndSettle();
          final released = await capture('$name-released');
          final releasedDiff = _difference(released, rest, region, pixelRatio);
          final row = <String, Object?>{
            'fixed': fixed,
            'edge': edge,
            'overscrollEvents': overscrollEvents - beforeEvents,
            'heldPointer': true,
            'heldStretch': stretches.isEmpty
                ? 0
                : stretches.single.stretchStrength,
            'held': heldDiff,
            'outsideGlass': backdropDiff,
            'released': releasedDiff,
          };
          results.add(row);
          debugPrint('OVERSCROLL_GLASS ${jsonEncode(row)}');
          if (fixed) {
            expect(heldDiff['meanRgbError'], lessThanOrEqualTo(.5));
            expect(heldDiff['severePixelFraction'], lessThanOrEqualTo(.005));
          } else {
            expect(
              heldDiff['meanRgbError'],
              greaterThan(5),
              reason: 'Baseline must reproduce the backdrop defect.',
            );
            expect(
              heldDiff['lumaDrop'],
              greaterThan(5),
              reason:
                  'On the actual pale settings background, isolated glass '
                  'must darken while the pointer is held.',
            );
          }
          expect(
            backdropDiff['meanRgbError'],
            lessThanOrEqualTo(.5),
            reason: 'The external backdrop must not darken with the glass.',
          );
          expect(releasedDiff['meanRgbError'], lessThanOrEqualTo(.5));
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
        activeController = null;
      }
    } finally {
      await heldGesture?.cancel();
      binding.reportData = {
        'overscrollGlass': results,
        'overscrollGlassPng': images,
        'artifactDirectory': directory.path,
        'protocol': {
          'platform': Platform.operatingSystem,
          'osVersion': Platform.operatingSystemVersion,
          'buildMode': kDebugMode
              ? 'debug'
              : (kProfileMode ? 'profile' : 'release'),
          'devicePixelRatio': pixelRatio,
          'viewport': {'width': width, 'height': height},
          'captureOrigin': {'x': 0, 'y': 0},
          'backdrop': '#f2f2f7, matching BrowserManagementPage light settings',
          'capture':
              'real-DPR RepaintBoundary; finger held after two updates, before release',
          'scope':
              'Android Impeller glass backdrop pixels, not device FPS or thermal measurements.',
        },
      };
      debugPrint('OVERSCROLL_GLASS_ARTIFACTS ${directory.path}');
      await tester.pumpWidget(const SizedBox.shrink());
      activeController?.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}

Widget _tile(Key key) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 24),
  child: SizedBox(
    key: key,
    height: 120,
    width: double.infinity,
    child: const BrowserGlass(radius: 28, child: SizedBox.expand()),
  ),
);

class _Pixels {
  const _Pixels(this.bytes, this.width, this.height);
  final ByteData bytes;
  final int width, height;
}

Map<String, double> _difference(
  _Pixels actual,
  _Pixels reference,
  Rect logicalRegion,
  double scale,
) {
  expect(actual.width, reference.width);
  expect(actual.height, reference.height);
  final left = (logicalRegion.left * scale).ceil().clamp(0, actual.width);
  final right = (logicalRegion.right * scale).floor().clamp(0, actual.width);
  final top = (logicalRegion.top * scale).ceil().clamp(0, actual.height);
  final bottom = (logicalRegion.bottom * scale).floor().clamp(0, actual.height);
  var sum = 0.0, actualChroma = 0.0, referenceChroma = 0.0;
  var actualLuma = 0.0, referenceLuma = 0.0;
  var count = 0, severe = 0;
  for (var y = top; y < bottom; y++) {
    for (var x = left; x < right; x++) {
      final offset = (y * actual.width + x) * 4;
      final a = [
        for (var channel = 0; channel < 3; channel++)
          actual.bytes.getUint8(offset + channel),
      ];
      final b = [
        for (var channel = 0; channel < 3; channel++)
          reference.bytes.getUint8(offset + channel),
      ];
      final error = [
        for (var channel = 0; channel < 3; channel++)
          (a[channel] - b[channel]).abs(),
      ];
      sum += error.reduce((a, b) => a + b);
      actualChroma += a.reduce(math.max) - a.reduce(math.min);
      referenceChroma += b.reduce(math.max) - b.reduce(math.min);
      // Weighted display-channel luma, in 8-bit code values. The near-neutral
      // fixture makes this a direct measure of the reported gray darkening.
      actualLuma += .2126 * a[0] + .7152 * a[1] + .0722 * a[2];
      referenceLuma += .2126 * b[0] + .7152 * b[1] + .0722 * b[2];
      if (error.reduce(math.max) > 16) severe++;
      count++;
    }
  }
  expect(count, greaterThan(0));
  return {
    'meanRgbError': sum / (count * 3),
    'severePixelFraction': severe / count,
    'actualChroma': actualChroma / count,
    'referenceChroma': referenceChroma / count,
    'actualLuma': actualLuma / count,
    'referenceLuma': referenceLuma / count,
    'lumaDrop': (referenceLuma - actualLuma) / count,
  };
}
