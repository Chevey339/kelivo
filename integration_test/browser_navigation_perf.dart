import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/database/business_repository.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/browser/browser_service.dart';
import 'package:Kelivo/core/services/browser/browser_store.dart';
import 'package:Kelivo/features/browser/pages/browser_management_page.dart';
import 'package:Kelivo/features/browser/pages/browser_page.dart';
import 'package:Kelivo/features/browser/widgets/browser_controls.dart';
import 'package:Kelivo/features/browser/widgets/browser_tabs.dart';
import 'package:Kelivo/features/browser/widgets/native_browser_glass.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

// Explicit runtime probe, intentionally outside the default *_test.dart glob.
// Uses a temporary browser directory and an in-memory settings database only.
// Never omit --keep-app-running: flutter drive otherwise uninstalls the app.
// flutter drive -d <device> --keep-app-running --no-dds \
//   --driver=test_driver/integration_test.dart \
//   --target=integration_test/browser_navigation_perf.dart
// The standard driver writes build/integration_response_data.json.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  // Match main.dart; the SDK default cache can conceal thumbnail churn.
  PaintingBinding.instance.imageCache
    ..maximumSize = 200
    ..maximumSizeBytes = 48 << 20;

  testWidgets('native browser navigation frame timing probe', (tester) async {
    final directory = await Directory.systemTemp.createTemp(
      'browser-nav-perf-',
    );
    final database = AppDatabase(NativeDatabase.memory());
    final preferences = BusinessPreferences(BusinessRepository(database));
    await preferences.load();
    final settings = SettingsProvider(preferences);
    await settings.loaded;
    final service = BrowserService(store: BrowserStore(directory: directory));
    await service.initialize();
    final first = await service.createTab(ownerSessionId: 'navigation-perf');
    final frames = <ui.FrameTiming>[];
    final phases = <Map<String, Object?>>[];
    void recordTimings(List<ui.FrameTiming> batch) => frames.addAll(batch);
    binding.addTimingsCallback(recordTimings);

    final viewport = find.byKey(const ValueKey('browserMobileViewportSlot'));
    final management = find.byType(BrowserManagementPage);
    final overview = find.byType(BrowserTabOverview);
    final more = find.byWidgetPredicate(
      (widget) => widget is BrowserActionButton && widget.label == 'More',
    );
    final menu = find.byKey(const ValueKey('browserMenuSurface'));

    Future<void> waitUntil(String label, bool Function() ready) async {
      final clock = Stopwatch()..start();
      while (!ready()) {
        if (clock.elapsed > const Duration(seconds: 12)) {
          fail(
            '$label timed out; active=${service.activeTabId}; '
            'scheduled=${binding.hasScheduledFrame}; '
            'transients=${binding.transientCallbackCount}',
          );
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }

    Future<void> idle() async {
      DateTime? quietSince;
      await waitUntil('200ms of frame quiescence', () {
        if (binding.hasScheduledFrame || binding.transientCallbackCount != 0) {
          quietSince = null;
          return false;
        }
        quietSince ??= DateTime.now();
        return DateTime.now().difference(quietSince!) >=
            const Duration(milliseconds: 200);
      });
    }

    Future<void> phase(String name, Future<void> Function() action) async {
      await idle();
      final firstFrameExclusive =
          ui.PlatformDispatcher.instance.frameData.frameNumber;
      final clock = Stopwatch()..start();
      await action();
      final readyMilliseconds = clock.elapsedMicroseconds / 1000;
      await idle();
      final quiescentMilliseconds = clock.elapsedMicroseconds / 1000;
      final lastFrameInclusive =
          ui.PlatformDispatcher.instance.frameData.frameNumber;
      // FrameTiming arrives in batches (up to one second in release). Drain
      // without pumping a synthetic frame. Match the engine's frame IDs rather
      // than comparing build-start times to Scheduler's presentation target;
      // a late UI frame can start after that target and would be dropped.
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      final sample = frames.where((frame) {
        return frame.frameNumber > firstFrameExclusive &&
            frame.frameNumber <= lastFrameInclusive;
      }).toList();
      expect(
        sample,
        isNotEmpty,
        reason: '$name produced no engine FrameTiming',
      );
      phases.add({
        'name': name,
        'actionToReadyMs': readyMilliseconds,
        'actionToQuiescentMs': quiescentMilliseconds,
        'frameCount': sample.length,
        'firstFrameExclusive': firstFrameExclusive,
        'lastFrameInclusive': lastFrameInclusive,
        'ui': _durations(sample.map((frame) => frame.buildDuration)),
        'raster': _durations(sample.map((frame) => frame.rasterDuration)),
        'eitherOver16_7ms': sample
            .where(
              (frame) =>
                  frame.buildDuration.inMicroseconds > 16700 ||
                  frame.rasterDuration.inMicroseconds > 16700,
            )
            .length,
        'raw': [
          for (final frame in sample)
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

    Future<void> openMenu() async {
      await tester.tap(more);
      await waitUntil('Menu mounted', () => menu.evaluate().isNotEmpty);
      await idle();
    }

    try {
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: settings,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      CupertinoPageRoute<void>(
                        builder: (_) => BrowserPage(
                          service: service,
                          conversationId: 'navigation-perf',
                        ),
                      ),
                    ),
                    child: const Text('Open browser'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await idle();
      final media = MediaQuery.of(tester.element(find.text('Open browser')));
      expect(media.disableAnimations, isFalse);
      expect(media.highContrast, isFalse);
      binding.reportData = {
        'protocol': {
          'platform': Platform.operatingSystem,
          'osVersion': Platform.operatingSystemVersion,
          'buildMode': kDebugMode
              ? 'debug'
              : (kProfileMode ? 'profile' : 'release'),
          'framePolicy': binding.framePolicy.name,
          'viewport': {'width': media.size.width, 'height': media.size.height},
          'devicePixelRatio': media.devicePixelRatio,
          'imageCacheBytes':
              PaintingBinding.instance.imageCache.maximumSizeBytes,
          'nativeGlass': NativeBrowserGlass.isSupported,
          'shaderFilters': ui.ImageFilter.isShaderFilterSupported,
          'rounds': ['cold', 'warm1', 'warm2'],
          'quietWindowMs': 200,
          'frameTimingDrainMs': 1200,
          'phaseBoundary': 'engine frameNumber; start exclusive, end inclusive',
          'budgetMs': 16.7,
          'fixture': 'two static loadHtml documents; no external network',
          'coldDefinition':
              'first browser/settings/tabs presentation in this process',
          'scope':
              'Real engine UI/raster FrameTiming. Debug simulator results do '
              'not establish physical-device FPS, WebKit compositor timing, '
              'temperature, or improvement without a comparable baseline. '
              'Cold browser open is a blank start page; warm opens retain '
              'loaded native tabs. Menu setup and fixture loading are excluded.',
        },
        'phases': phases,
      };

      String? secondId;
      for (final round in ['cold', 'warm1', 'warm2']) {
        await phase('$round.browser_open', () async {
          await tester.tap(find.text('Open browser'));
          await waitUntil(
            'Browser mounted',
            () => viewport.evaluate().isNotEmpty,
          );
        });
        expect(viewport, findsOneWidget, reason: 'Run on a mobile viewport.');
        if (secondId == null) {
          await service.loadHtml(
            _fixture('First document', '#90c9c1'),
            tabId: first.id,
          );
          await service.waitForLoad(
            tabId: first.id,
            timeout: const Duration(seconds: 10),
          );
          final second = await service.createTab(
            ownerSessionId: 'navigation-perf',
          );
          secondId = second.id;
          await service.loadHtml(
            _fixture('Second document', '#e5b49d'),
            tabId: second.id,
          );
          await service.waitForLoad(
            tabId: second.id,
            timeout: const Duration(seconds: 10),
          );
          await service.selectTab(first.id);
          await waitUntil(
            'Visible native scroll metrics',
            () =>
                (service.scrollStateForTab(first.id)?.viewportExtent ?? 0) > 0,
          );
          await idle();
        }
        await openMenu();
        await phase('$round.settings_open', () async {
          await tester.tap(find.text('Browser settings'));
          await waitUntil(
            'Settings mounted',
            () => management.evaluate().isNotEmpty,
          );
        });
        await phase('$round.settings_close', () async {
          await tester.tap(find.byTooltip('Back'));
          await waitUntil(
            'Settings dismissed',
            () => management.evaluate().isEmpty,
          );
        });
        await openMenu();
        await phase('$round.tabs_open', () async {
          await tester.tap(find.text('Tabs (2)'));
          await waitUntil(
            'Tab overview mounted',
            () => overview.evaluate().isNotEmpty,
          );
        });
        final target = service.activeTabId == first.id ? secondId : first.id;
        await phase('$round.tab_select', () async {
          await tester.tap(find.byKey(ValueKey('browserTabCard-$target')));
          await waitUntil(
            'Selected tab resumed',
            () => overview.evaluate().isEmpty && service.activeTabId == target,
          );
        });
        expect(service.tabs, hasLength(2));
        await openMenu();
        await phase('$round.browser_close', () async {
          await tester.tap(find.text('Close browser'));
          await waitUntil(
            'Browser dismissed',
            () => viewport.evaluate().isEmpty,
          );
        });
      }
    } finally {
      binding.removeTimingsCallback(recordTimings);
      await tester.pumpWidget(const SizedBox.shrink());
      await idle();
      await service.flush();
      service.dispose();
      settings.dispose();
      await database.close();
      await directory.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 4)));
}

Map<String, Object> _durations(Iterable<Duration> values) {
  final milliseconds =
      values.map((value) => value.inMicroseconds / 1000).toList()..sort();
  return {
    'p95Ms': milliseconds[math.max(0, (milliseconds.length * .95).ceil() - 1)],
    'maxMs': milliseconds.last,
    'over16_7ms': milliseconds.where((value) => value > 16.7).length,
  };
}

String _fixture(String title, String color) =>
    '''<!doctype html>
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>$title</title>
<style>html,body{margin:0;font:22px system-ui;color:#172942}
body{min-height:1500px;background:linear-gradient(150deg,$color,#fff4dc)}
main{padding:72px 28px}h1{font-size:36px}p{line-height:1.6}</style>
<main><h1>$title</h1><p>Local native browser fixture.</p>
<p>Settings and tabs animate over a real WebView.</p>
<p>No network, video, timers, or programmatic scrolling.</p></main>''';
