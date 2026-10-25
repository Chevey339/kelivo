import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:Kelivo/core/services/browser/browser_service.dart';
import 'package:Kelivo/core/services/browser/browser_store.dart';
import 'package:Kelivo/features/browser/browser_management_route.dart';
import 'package:Kelivo/features/browser/models/browser_models.dart';
import 'package:Kelivo/features/browser/pages/browser_management_page.dart';
import 'package:Kelivo/features/browser/widgets/browser_glass.dart';
import 'package:Kelivo/features/browser/widgets/browser_progressive_edge.dart';
import 'package:Kelivo/features/browser/widgets/browser_settings.dart';
import 'package:Kelivo/features/browser/widgets/browser_transition_snapshot.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

// Explicit real-Impeller image/performance probe. Uses no app user data or WK
// view; comparison isolates the opaque Flutter management page's filter cost.
// flutter drive -d <simulator> --keep-app-running --no-dds \
//   --driver=test_driver/integration_test.dart \
//   --target=integration_test/browser_management_snapshot_probe.dart
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('management snapshots preserve optics and bound route raster work', (
    tester,
  ) async {
    expect(ui.ImageFilter.isShaderFilterSupported, isTrue);
    final directory = await Directory.systemTemp.createTemp(
      'management-cache-',
    );
    final service = BrowserService(store: BrowserStore(directory: directory));
    await service.initialize();
    await Future.wait([
      BrowserGlass.prewarm(nativeBackdrop: false),
      BrowserProgressiveEdge.prewarm(),
    ]);
    final results = <Map<String, Object>>[];
    final phases = <Map<String, Object>>[];
    final timings = <ui.FrameTiming>[];
    void record(List<ui.FrameTiming> batch) => timings.addAll(batch);
    binding.addTimingsCallback(record);
    AnimationController? activeMotion;
    try {
      for (final style in [
        BrowserSurfaceStyle.liquid,
        BrowserSurfaceStyle.frosted,
      ]) {
        await service.updateSettings(
          service.settings.copyWith(surfaceStyle: style),
        );
        binding.framePolicy =
            LiveTestWidgetsFlutterBindingFramePolicy.onlyPumps;
        final motion = AnimationController(vsync: tester, value: .5);
        activeMotion = motion;
        final capture = GlobalKey();
        await tester.pumpWidget(
          _app(
            home: RepaintBoundary(
              key: capture,
              child: BrowserTransitionSnapshot(
                animation: motion,
                child: _page(service, style),
              ),
            ),
          ),
        );
        final boundary =
            capture.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        // Match SnapshotWidget's cache resolution. Rendering the live shader
        // tree at 1x while its uniforms use the view's 3x DPR is a different
        // render target, not a comparison of what reaches the display.
        final pixelRatio = tester.view.devicePixelRatio;
        for (final phase in ['entry', 'cancel']) {
          if (phase == 'cancel') {
            motion.value = .65;
            await tester.pump();
          }
          final first = await boundary.toImage(pixelRatio: pixelRatio);
          final firstBytes = (await first.toByteData())!;
          motion.value = 1;
          await tester.pumpAndSettle();
          final live = await boundary.toImage(pixelRatio: pixelRatio);
          final liveBytes = (await live.toByteData())!;
          final diff = _difference(firstBytes, liveBytes);
          for (final entry in {'cached': first, 'live': live}.entries) {
            final png = (await entry.value.toByteData(
              format: ui.ImageByteFormat.png,
            ))!;
            await File(
              '${directory.path}/${style.name}-$phase-${entry.key}.png',
            ).writeAsBytes(
              png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
            );
            entry.value.dispose();
          }
          results.add({'style': style.name, 'phase': phase, ...diff});
          expect(diff['meanRgbError'], lessThanOrEqualTo(.5));
          expect(diff['severePixelFraction'], lessThanOrEqualTo(.005));
        }
        await tester.pumpWidget(const SizedBox.shrink());
        motion.dispose();
        activeMotion = null;

        binding.framePolicy =
            LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
        final navigator = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          _app(
            navigatorKey: navigator,
            home: const Scaffold(body: Center(child: Text('Route GPU probe'))),
          ),
        );
        for (final cached in [false, true]) {
          Future<void> cycle() async {
            final PageRoute<void> route = cached
                ? BrowserManagementRoute<void>(
                    builder: (_) => _page(service, style),
                  )
                : _LiveStationaryRoute(builder: (_) => _page(service, style));
            final closed = navigator.currentState!.push<void>(route);
            await Future<void>.delayed(const Duration(milliseconds: 700));
            expect(route.animation!.status, AnimationStatus.completed);
            navigator.currentState!.pop();
            await closed;
            await route.completed;
          }

          await cycle(); // Warm both render paths before comparison.
          await Future<void>.delayed(const Duration(milliseconds: 1200));
          final firstFrame =
              ui.PlatformDispatcher.instance.frameData.frameNumber;
          await cycle();
          await cycle();
          final lastFrame =
              ui.PlatformDispatcher.instance.frameData.frameNumber;
          await Future<void>.delayed(const Duration(milliseconds: 1200));
          final sample = timings
              .where(
                (frame) =>
                    frame.frameNumber > firstFrame &&
                    frame.frameNumber <= lastFrame,
              )
              .toList();
          expect(sample, isNotEmpty);
          final raster =
              sample
                  .map((frame) => frame.rasterDuration.inMicroseconds / 1000)
                  .toList()
                ..sort();
          final build =
              sample
                  .map((frame) => frame.buildDuration.inMicroseconds / 1000)
                  .toList()
                ..sort();
          phases.add({
            'style': style.name,
            'cached': cached,
            'frames': sample.length,
            'rasterMeanMs': raster.reduce((a, b) => a + b) / raster.length,
            'rasterP95Ms': raster[((raster.length - 1) * .95).round()],
            'buildMeanMs': build.reduce((a, b) => a + b) / build.length,
            'rasterOver16_7ms': raster.where((ms) => ms > 16.7).length,
          });
        }
      }
      expect(tester.takeException(), isNull);
    } finally {
      binding.reportData = {
        'managementSnapshotPixels': results,
        'managementSnapshotPhases': phases,
        'managementSnapshotArtifacts': directory.path,
        'scope':
            'Real Impeller Flutter-only page; ${kDebugMode ? 'debug' : 'non-debug'} runtime. '
            'Not physical-device FPS, native WK compositor cost, or temperature evidence.',
      };
      binding.removeTimingsCallback(record);
      await tester.pumpWidget(const SizedBox.shrink());
      activeMotion?.dispose();
      service.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}

Widget _app({required Widget home, GlobalKey<NavigatorState>? navigatorKey}) =>
    MaterialApp(
      navigatorKey: navigatorKey,
      theme: ThemeData.light().copyWith(
        colorScheme: const ColorScheme.light(
          primary: Color(0xff007aff),
          surface: Color(0xfff2f2f7),
          onSurface: Color(0xff161618),
        ),
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

Widget _page(BrowserService service, BrowserSurfaceStyle style) =>
    BrowserGlassBackdrop(
      native: false,
      child: BrowserGlassScope(
        style: style,
        child: BrowserManagementPage(
          title: 'Glass capture comparison',
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(painter: _Pattern()),
              BrowserSettingsPanel(
                service: service,
                onError: (_) {},
                onDataCleared: () {},
              ),
            ],
          ),
        ),
      ),
    );

class _LiveStationaryRoute extends CupertinoPageRoute<void> {
  _LiveStationaryRoute({required super.builder});
  @override
  bool canTransitionFrom(TransitionRoute<dynamic> previousRoute) => false;
}

Map<String, double> _difference(ByteData actual, ByteData expected) {
  var sum = 0;
  var severe = 0;
  final pixels = actual.lengthInBytes ~/ 4;
  for (var index = 0; index < actual.lengthInBytes; index += 4) {
    var maximum = 0;
    for (var channel = 0; channel < 3; channel++) {
      final delta =
          (actual.getUint8(index + channel) -
                  expected.getUint8(index + channel))
              .abs();
      sum += delta;
      if (delta > maximum) maximum = delta;
    }
    if (maximum > 12) severe++;
  }
  return {
    'meanRgbError': sum / (pixels * 3),
    'severePixelFraction': severe / pixels,
  };
}

class _Pattern extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xff9aafbd)
      ..strokeWidth = 2;
    for (var x = -size.height; x < size.width; x += 20) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_Pattern oldDelegate) => false;
}
