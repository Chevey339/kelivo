import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:Kelivo/features/browser/models/browser_models.dart';
import 'package:Kelivo/features/browser/widgets/browser_glass.dart';
import 'package:Kelivo/features/browser/widgets/native_browser_glass.dart';

// Explicit runtime probe, outside the default *_test.dart glob. No app storage,
// network, Navigator flows, or BrowserService are involved. Run the same target
// before/after a native tint change and label it with GLASS_VARIANT.
// flutter drive -d <iOS 26 simulator> --keep-app-running --no-dds \
//   --dart-define=GLASS_VARIANT=baseline \
//   --driver=test_driver/integration_test.dart \
//   --target=integration_test/browser_glass_renderer_probe.dart
// Capture the actual display during GLASS_RENDERER_VISUAL; toImage cannot
// include UIKit overlay slices. WK stages are visual-only, not equivalent A/B.
const _variant = String.fromEnvironment(
  'GLASS_VARIANT',
  defaultValue: 'baseline',
);
// For tint inspection only: native WK glass, light then dark, no measurements.
const _visualOnly = bool.fromEnvironment('GLASS_VISUAL_ONLY');
const _warmup = Duration(seconds: 2);
const _measurement = Duration(seconds: 4);
const _visualHold = Duration(seconds: 60);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('compare native and Flutter browser glass renderers', (
    tester,
  ) async {
    expect(Platform.isIOS, isTrue, reason: 'This probe requires actual iOS.');
    expect(NativeBrowserGlass.isSupported, isTrue);
    if (!_visualOnly) {
      expect(ui.ImageFilter.isShaderFilterSupported, isTrue);
      await BrowserGlass.prewarm(nativeBackdrop: false);
    }

    final motion = AnimationController(
      vsync: tester,
      duration: const Duration(seconds: 2),
    );
    final timings = <ui.FrameTiming>[];
    final samples = <Map<String, Object?>>[];
    final visualStages = <Map<String, Object?>>[];
    void recordTimings(List<ui.FrameTiming> batch) => timings.addAll(batch);
    binding.addTimingsCallback(recordTimings);
    var sceneId = 0;

    Future<Map<String, Object?>?> mount({
      required bool native,
      bool web = false,
      Brightness brightness = Brightness.light,
      VoidCallback? onNext,
    }) async {
      motion.stop();
      motion.value = 0;
      final materials = <int>{};
      InAppWebViewController? webController;
      final loadStops = <String>[];
      Map<String, Object?>? document;
      await tester.pumpWidget(
        _ProbeScene(
          key: ValueKey(++sceneId),
          native: native,
          web: web,
          brightness: brightness,
          motion: motion,
          onMaterialReady: materials.add,
          onWebCreated: (controller) => webController = controller,
          onWebLoadStop: (url) => loadStops.add(url.toString()),
          onNext: onNext,
        ),
      );
      final clock = Stopwatch()..start();
      while (materials.length != 3 || (web && !_fixtureReady(document))) {
        if (webController != null && loadStops.isNotEmpty) {
          final result = await webController!.evaluateJavascript(
            source: _documentProbe,
          );
          if (result is String) {
            document = (jsonDecode(result) as Map).cast<String, Object?>();
          }
        }
        if (clock.elapsed > const Duration(seconds: 15)) {
          fail(
            'Scene not ready: native=$native, web=$web, '
            'materials=${materials.length}, loadStops=$loadStops, '
            'document=${jsonEncode(document)}',
          );
        }
        await Future<void>.delayed(Duration(milliseconds: web ? 100 : 20));
      }
      // onReady confirms parameter preparation and a Flutter frame, not native
      // presentation. Each measured sample still gets a full 2s warmup.
      expect(tester.takeException(), isNull);
      if (web) {
        expect(_fixtureReady(document), isTrue);
        debugPrintSynchronously(
          'GLASS_RENDERER_DOCUMENT ${jsonEncode({'native': native, 'variant': _variant, 'loadStops': loadStops, 'document': document})}',
        );
      }
      return document;
    }

    Map<String, Object?> marker(bool native, int sample) => {
      'renderer': native ? 'native' : 'flutter',
      'native': native,
      'sample': sample,
      'variant': _variant,
      'pid': pid,
      'utc': DateTime.now().toUtc().toIso8601String(),
    };

    Future<void> measure(bool native, int round) async {
      await mount(native: native);
      motion.repeat();
      await Future<void>.delayed(_warmup);
      final firstExclusive =
          ui.PlatformDispatcher.instance.frameData.frameNumber;
      final start = marker(native, round);
      debugPrintSynchronously('GLASS_RENDERER_BEGIN ${jsonEncode(start)}');
      final clock = Stopwatch()..start();
      // Real vsync drives an actual moving backdrop. Never tester.pump, request
      // synthetic frames, or perform screenshot readbacks in this interval.
      await Future<void>.delayed(_measurement);
      clock.stop();
      final lastInclusive =
          ui.PlatformDispatcher.instance.frameData.frameNumber;
      final end = marker(native, round);
      debugPrintSynchronously('GLASS_RENDERER_END ${jsonEncode(end)}');
      motion.stop();
      // Release FrameTiming can arrive one second later in a batch. Match
      // engine frame IDs rather than build timestamps vs presentation targets.
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      final frames = timings
          .where(
            (frame) =>
                frame.frameNumber > firstExclusive &&
                frame.frameNumber <= lastInclusive,
          )
          .toList();
      expect(frames, isNotEmpty);
      samples.add({
        ...start,
        'endUtc': end['utc'],
        'windowMs': clock.elapsedMicroseconds / 1000,
        'engineFramesProduced': lastInclusive - firstExclusive,
        'timingsReceived': frames.length,
        'firstFrameExclusive': firstExclusive,
        'lastFrameInclusive': lastInclusive,
        'ui': _stats(frames.map((frame) => frame.buildDuration)),
        'raster': _stats(frames.map((frame) => frame.rasterDuration)),
        'eitherOver16_7ms': frames
            .where(
              (frame) =>
                  frame.buildDuration.inMicroseconds > 16700 ||
                  frame.rasterDuration.inMicroseconds > 16700,
            )
            .length,
        'raw': [
          for (final frame in frames)
            {
              'frameNumber': frame.frameNumber,
              'uiUs': frame.buildDuration.inMicroseconds,
              'rasterUs': frame.rasterDuration.inMicroseconds,
              'totalUs': frame.totalSpan.inMicroseconds,
            },
        ],
      });
      expect(tester.takeException(), isNull);
    }

    try {
      // Reverse the order in the middle round to expose order/thermal drift.
      if (!_visualOnly) {
        for (var round = 1; round <= 3; round++) {
          for (final native in round.isOdd ? [true, false] : [false, true]) {
            await measure(native, round);
          }
        }
      }
      final visualConfigurations = _visualOnly
          ? [(true, true, Brightness.light), (true, true, Brightness.dark)]
          : [
              for (final web in [false, true])
                for (final native in [true, false])
                  (web, native, Brightness.light),
            ];
      for (final (web, native, brightness) in visualConfigurations) {
        final next = Completer<void>();
        final document = await mount(
          native: native,
          web: web,
          brightness: brightness,
          onNext: () {
            if (!next.isCompleted) next.complete();
          },
        );
        await Future<void>.delayed(_warmup);
        final stage = {
          ...marker(native, 0),
          'scene': web ? 'wk-local-html' : 'flutter-static',
          'brightness': brightness.name,
          'equivalentBackdrop': !web,
          'maximumHoldSeconds': _visualHold.inSeconds,
          if (document != null) 'document': document,
        };
        visualStages.add(stage);
        debugPrintSynchronously('GLASS_RENDERER_VISUAL ${jsonEncode(stage)}');
        await next.future.timeout(_visualHold, onTimeout: () {});
        expect(tester.takeException(), isNull);
      }
      final view = ui.PlatformDispatcher.instance.views.first;
      binding.reportData = {
        'probe': 'browser-glass-renderer',
        'variant': _variant,
        'visualOnly': _visualOnly,
        'pid': pid,
        'operatingSystemVersion': Platform.operatingSystemVersion,
        'buildMode': kReleaseMode
            ? 'release'
            : kProfileMode
            ? 'profile'
            : 'debug',
        'devicePixelRatio': view.devicePixelRatio,
        'physicalSize': [view.physicalSize.width, view.physicalSize.height],
        'protocol': {
          'rounds': _visualOnly ? 0 : 3,
          'warmupMs': _warmup.inMilliseconds,
          'measurementMs': _measurement.inMilliseconds,
          'workload':
              'Identical opaque animated Flutter backdrop; three fixed '
              'BrowserGlass controls, native host versus Flutter shader. '
              'Background paints each real vsync; no synthetic frame pumping.',
          'timingScope':
              'Flutter UI/raster timings and produced engine frames only. '
              'These exclude total UIKit/RenderServer compositor GPU cost. '
              'External app CPU/RSS sampling uses BEGIN/END UTC markers and pid.',
          'visualScope':
              'Actual display capture required. WK is visual-only: the Flutter '
              'shader cannot sample the native WebView and is not equivalent.',
          'deviceScope':
              'Simulator protocol; not physical-device FPS, power, or thermal '
              'evidence for iPhone 14 Pro Max running iOS 18.2.1.',
        },
        'samples': samples,
        'visualStages': visualStages,
      };
    } finally {
      motion.stop();
      binding.removeTimingsCallback(recordTimings);
      await tester.pumpWidget(const SizedBox.shrink());
      motion.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 8)));
}

Map<String, Object> _stats(Iterable<Duration> values) {
  final sorted = values.map((value) => value.inMicroseconds / 1000).toList()
    ..sort();
  double percentile(double fraction) =>
      sorted[math.max(0, (sorted.length * fraction).ceil() - 1)];
  return {
    'p50Ms': percentile(0.50),
    'p95Ms': percentile(0.95),
    'maxMs': sorted.last,
    'meanMs': sorted.reduce((a, b) => a + b) / sorted.length,
    'over16_7ms': sorted.where((value) => value > 16.7).length,
  };
}

class _ProbeScene extends StatelessWidget {
  const _ProbeScene({
    super.key,
    required this.native,
    required this.web,
    required this.brightness,
    required this.motion,
    required this.onMaterialReady,
    required this.onWebCreated,
    required this.onWebLoadStop,
    this.onNext,
  });

  final bool native;
  final bool web;
  final Brightness brightness;
  final Animation<double> motion;
  final ValueChanged<int> onMaterialReady;
  final ValueChanged<InAppWebViewController> onWebCreated;
  final ValueChanged<WebUri?> onWebLoadStop;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: brightness == Brightness.dark
        ? ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xff0a84ff),
              surface: Color(0xff1c1c1e),
              onSurface: Colors.white,
            ),
          )
        : ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xff007aff),
              surface: Color(0xfff2f2f7),
              onSurface: Color(0xff161618),
            ),
          ),
    home: BrowserGlassBackdrop(
      native: native,
      child: BrowserGlassScope(
        style: BrowserSurfaceStyle.liquid,
        child: Builder(
          builder: (context) => Scaffold(
            body: Stack(
              fit: StackFit.expand,
              children: [
                if (web)
                  InAppWebView(
                    initialSettings: InAppWebViewSettings(
                      transparentBackground: false,
                      disableVerticalScroll: true,
                      disableHorizontalScroll: true,
                    ),
                    initialData: InAppWebViewInitialData(data: _html),
                    onWebViewCreated: onWebCreated,
                    onLoadStop: (_, url) => onWebLoadStop(url),
                  )
                else
                  RepaintBoundary(
                    child: CustomPaint(painter: _Backdrop(motion)),
                  ),
                Positioned(
                  top: MediaQuery.viewPaddingOf(context).top + 12,
                  left: 16,
                  right: 16,
                  child: ColoredBox(
                    color: brightness == Brightness.dark
                        ? const Color(0xe61c1c1e)
                        : const Color(0xe6ffffff),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${native ? 'NATIVE' : 'FLUTTER'} · $_variant\n'
                              '${web ? 'WK visual only / not equivalent' : 'Flutter backdrop / same workload'}'
                              '${_visualOnly ? ' · ${brightness.name}' : ''}',
                              style: TextStyle(
                                fontSize: 13,
                                color: brightness == Brightness.dark
                                    ? Colors.white
                                    : const Color(0xff161618),
                              ),
                            ),
                          ),
                          if (onNext != null)
                            TextButton(
                              onPressed: onNext,
                              child: const Text('Next'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.viewPaddingOf(context).bottom + 10,
                  child: Row(
                    children: [
                      _glass(
                        0,
                        const SizedBox.square(
                          dimension: 48,
                          child: Icon(LucideIcons.chevronLeft, size: 22),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _glass(
                          1,
                          const SizedBox(
                            height: 48,
                            child: Row(
                              children: [
                                SizedBox(width: 18),
                                Expanded(
                                  child: Text(
                                    'example.com',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Icon(LucideIcons.rotateCw, size: 19),
                                SizedBox(width: 16),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _glass(
                        2,
                        const SizedBox.square(
                          dimension: 48,
                          child: Icon(LucideIcons.ellipsis, size: 22),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _glass(int index, Widget child) => BrowserGlass(
    radius: 1000,
    onReady: () => onMaterialReady(index),
    child: child,
  );
}

class _Backdrop extends CustomPainter {
  _Backdrop(this.motion) : super(repaint: motion);

  final Animation<double> motion;
  static const _colors = [
    Color(0xfffafafa),
    Color(0xff141820),
    Color(0xff16b9c5),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final bandWidth = size.width / 3;
    final offset = motion.value * size.width;
    final paint = Paint();
    for (var band = -3; band < 6; band++) {
      final x = band * bandWidth + offset;
      paint.color = _colors[band % 3];
      canvas.drawRect(Rect.fromLTWH(x, 0, bandWidth + 1, size.height), paint);
      paint.color = band % 3 == 0
          ? const Color(0xff646878)
          : const Color(0xffe5edf2);
      for (var y = 145.0; y < size.height; y += 44) {
        canvas.drawRect(Rect.fromLTWH(x + 12, y, bandWidth - 24, 3), paint);
        canvas.drawRect(
          Rect.fromLTWH(x + 12, y + 9, (bandWidth - 24) * 0.7, 3),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_Backdrop oldDelegate) => oldDelegate.motion != motion;
}

bool _fixtureReady(Map<String, Object?>? document) {
  if (document == null ||
      document['marker'] != 'renderer-fixture-r9' ||
      document['readyState'] != 'complete' ||
      document['middleHit'] != 'black' ||
      document['rightHit'] != 'color') {
    return false;
  }
  final width = (document['width'] as num?)?.toDouble() ?? 0;
  final height = (document['height'] as num?)?.toDouble() ?? 0;
  final columns = document['columns'];
  if (width <= 0 || height <= 0 || columns is! List || columns.length != 3) {
    return false;
  }
  const colors = ['rgb(250, 250, 250)', 'rgb(20, 24, 32)', 'rgb(22, 185, 197)'];
  for (var index = 0; index < columns.length; index++) {
    final column = columns[index] as Map;
    if (column['background'] != colors[index] ||
        ((column['width'] as num) - width / 3).abs() > 1 ||
        ((column['x'] as num) - width * index / 3).abs() > 1 ||
        ((column['height'] as num) - height).abs() > 1) {
      return false;
    }
  }
  return true;
}

const _documentProbe = '''JSON.stringify({
  marker: document.body?.id,
  readyState: document.readyState,
  url: location.href,
  width: innerWidth,
  height: innerHeight,
  middleHit: document.elementFromPoint(innerWidth * .5, innerHeight * .5)?.className,
  rightHit: document.elementFromPoint(innerWidth * .9, innerHeight * .5)?.className,
  columns: Array.from(document.querySelectorAll('section')).map(element => {
    const rect = element.getBoundingClientRect();
    return {x: rect.x, y: rect.y, width: rect.width, height: rect.height,
      background: getComputedStyle(element).backgroundColor};
  })
})''';

const _html = '''<!doctype html><html><head>
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Kelivo renderer fixture R9</title>
<style>
html,body{margin:0;width:100%;height:100%;overflow:hidden;font:15px -apple-system}
main{position:fixed;inset:0;display:grid;grid-template-columns:repeat(3,minmax(0,1fr))}
section{min-width:0;padding:140px 12px 0;
box-sizing:border-box;overflow:hidden;line-height:44px;white-space:nowrap}
.white{background:#fafafa;color:#646878}.black{background:#141820;color:#e5edf2}
.color{background:#16b9c5;color:#e5edf2}
</style></head><body id="renderer-fixture-r9"><main>
<section class="white">White background<br>Page text 123<br>Browser glass<br>Local HTML only<br>Optical contrast<br>Window sampling<br>Page text 123<br>Browser glass<br>Local HTML only<br>Optical contrast<br>Window sampling<br>Page text 123<br>Browser glass<br>Local HTML only<br>Optical contrast<br>Window sampling<br>Page text 123<br>Browser glass<br>Local HTML only<br>Optical contrast<br>Window sampling</section>
<section class="black">Black background<br>Page text 123<br>Browser glass<br>Local HTML only<br>Optical contrast<br>Window sampling<br>Page text 123<br>Browser glass<br>Local HTML only<br>Optical contrast<br>Window sampling<br>Page text 123<br>Browser glass<br>Local HTML only<br>Optical contrast<br>Window sampling<br>Page text 123<br>Browser glass<br>Local HTML only<br>Optical contrast<br>Window sampling</section>
<section class="color">Color background<br>Page text 123<br>Browser glass<br>Local HTML only<br>Optical contrast<br>Window sampling<br>Page text 123<br>Browser glass<br>Local HTML only<br>Optical contrast<br>Window sampling<br>Page text 123<br>Browser glass<br>Local HTML only<br>Optical contrast<br>Window sampling<br>Page text 123<br>Browser glass<br>Local HTML only<br>Optical contrast<br>Window sampling</section>
</main></body></html>''';
