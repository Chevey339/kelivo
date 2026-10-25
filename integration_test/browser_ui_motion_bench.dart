import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
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
import 'package:Kelivo/features/browser/models/browser_models.dart';
import 'package:Kelivo/features/browser/pages/browser_page.dart';
import 'package:Kelivo/features/browser/widgets/browser_controls.dart';
import 'package:Kelivo/features/browser/widgets/browser_tabs.dart';
import 'package:Kelivo/features/browser/browser_tabs_route.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

// Profile in the independent browser-probe package, with --keep-app-running.
// Control callbacks exercise app animations over a real WebView. This does not certify
// Android's physical touch/IME dispatch. No account or persisted browser data.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('solid chrome motion and current tab pixels', (tester) async {
    final directory = await Directory.systemTemp.createTemp('browser-ui-');
    final database = AppDatabase(NativeDatabase.memory());
    final prefs = BusinessPreferences(BusinessRepository(database));
    await prefs.load();
    final settings = SettingsProvider(prefs);
    await settings.loaded;
    final service = BrowserService(store: BrowserStore(directory: directory));
    await service.initialize();
    await service.updateSettings(
      service.settings.copyWith(surfaceStyle: BrowserSurfaceStyle.solid),
    );
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.headers.contentType = ContentType.html;
      request.response.write(
        '''<!doctype html><meta name="viewport" content="width=device-width,initial-scale=1">
<style>body{margin:0;background:#214bd4;color:white;font:20px sans-serif}section{height:1200px;padding:24px;box-sizing:border-box}section:nth-child(2){background:#23a14d}</style>
<section><h1>Browser motion fixture</h1>First screen</section><section>Second screen</section>''',
      );
      await request.response.close();
    });
    final reports = <Map<String, Object?>>[];
    final frames = <ui.FrameTiming>[];
    void record(List<ui.FrameTiming> batch) => frames.addAll(batch);
    binding.addTimingsCallback(record);
    Future<void> waitFor(String label, bool Function() ready) async {
      final deadline = Stopwatch()..start();
      while (!ready()) {
        if (deadline.elapsed > const Duration(seconds: 12)) fail(label);
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }

    Future<void> settle() async {
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await waitFor(
        'motion did not settle',
        () => binding.transientCallbackCount == 0,
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    Finder action(String label) => find.byWidgetPredicate(
      (widget) => widget is BrowserActionButton && widget.label == label,
    );
    final menu = find.byKey(const ValueKey('browserMenuSurface'));
    Future<void> phase(String name, Future<void> Function() run) async {
      await settle();
      final first = ui.PlatformDispatcher.instance.frameData.frameNumber;
      final elapsed = Stopwatch()..start();
      await run();
      await settle();
      final last = ui.PlatformDispatcher.instance.frameData.frameNumber;
      final duration = elapsed.elapsedMilliseconds;
      await Future<void>.delayed(const Duration(milliseconds: 1000));
      final sample = frames
          .where(
            (frame) => frame.frameNumber > first && frame.frameNumber <= last,
          )
          .toList();
      final report = <String, Object?>{
        'name': name,
        'frames': sample.length,
        'wallMs': duration,
        'ui': stats(sample.map((frame) => frame.buildDuration)),
        'raster': stats(sample.map((frame) => frame.rasterDuration)),
        'total': stats(sample.map((frame) => frame.totalSpan)),
      };
      reports.add(report);
      // ignore: avoid_print
      print('BROWSER_UI ${jsonEncode(report)}');
      expect(tester.takeException(), isNull);
    }

    try {
      final tab = await service.createTab(ownerSessionId: 'ui-motion');
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: settings,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: BrowserPage(service: service, conversationId: 'ui-motion'),
          ),
        ),
      );
      await service.navigate('http://127.0.0.1:${server.port}/', tabId: tab.id);
      await service.waitForLoad(tabId: tab.id);
      await waitFor('viewport not ready', () => service.isTabPresented(tab.id));
      await settle();
      await service.navigate(
        'http://127.0.0.1:${server.port}/next',
        tabId: tab.id,
      );
      await service.waitForLoad(tabId: tab.id);
      await waitFor(
        'history not populated',
        () => service.activeTab!.canGoBack,
      );
      for (var round = 0; round < 5; round++) {
        await phase('$round.back', () async {
          tester.widget<BrowserActionButton>(action('Back')).onPressed!();
          await waitFor(
            'Forward not available',
            () => service.activeTab!.canGoForward,
          );
        });
        await phase('$round.forward', () async {
          tester.widget<BrowserActionButton>(action('Forward')).onPressed!();
          await waitFor(
            'Forward not consumed',
            () => !service.activeTab!.canGoForward,
          );
        });
        await phase('$round.menu.open', () async {
          tester.widget<BrowserActionButton>(action('More')).onPressed!();
          await waitFor('menu not opened', () => menu.evaluate().isNotEmpty);
        });
        await phase('$round.menu.close', () async {
          await tester.tapAt(const Offset(12, 180));
          await waitFor('menu not closed', () => menu.evaluate().isEmpty);
        });
      }
      if (const bool.fromEnvironment('BROWSER_VERIFY_CURRENT_PREVIEW')) {
        // Scroll and open immediately: the one-second idle cache cannot satisfy
        // this request. Both image content and flight source must be current.
        await service.evaluateJavascript('scrollTo(0,1200)', tabId: tab.id);
        await Future<void>.delayed(const Duration(milliseconds: 100));
        tester.widget<BrowserActionButton>(action('More')).onPressed!();
        await settle();
        final tabs = find.text('Tabs (1)');
        await tester.tap(tabs);
        await waitFor(
          'overview not opened',
          () => find.byType(BrowserTabOverview).evaluate().isNotEmpty,
        );
        await settle();
        final route =
            ModalRoute.of(tester.element(find.byType(BrowserTabOverview)))!
                as BrowserTabsRoute;
        final bytes = route.transition.previewForTab(tab.id);
        expect(bytes, isNotNull);
        final codec = await ui.instantiateImageCodec(bytes!);
        final frame = await codec.getNextFrame();
        final pixels = (await frame.image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        final sample =
            ((frame.image.height ~/ 2) * frame.image.width +
                frame.image.width ~/ 2) *
            4;
        expect(
          pixels.getUint8(sample + 1),
          greaterThan(pixels.getUint8(sample + 2)),
          reason:
              'Thumbnail must show the green current viewport, not blue cached pixels',
        );
        expect(frame.image.width, lessThanOrEqualTo(441));
        frame.image.dispose();
        codec.dispose();
      }
      binding.reportData = {'phases': reports};
    } finally {
      binding.removeTimingsCallback(record);
      await tester.pumpWidget(const SizedBox.shrink());
      service.dispose();
      settings.dispose();
      await database.close();
      await server.close(force: true);
      await directory.delete(recursive: true);
    }
  });
}

Map<String, Object> stats(Iterable<Duration> durations) {
  final values =
      durations.map((duration) => duration.inMicroseconds / 1000).toList()
        ..sort();
  if (values.isEmpty) return {'p50': 0, 'p95': 0, 'max': 0};
  return {
    'p50': values[(values.length * .5).floor()],
    'p95': values[(values.length * .95).floor().clamp(0, values.length - 1)],
    'max': values.last,
    'over16': values.where((value) => value > 16.667).length,
  };
}
