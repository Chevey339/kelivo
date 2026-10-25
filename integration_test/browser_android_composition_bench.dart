import 'dart:io';
import 'dart:developer' as developer;
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:Kelivo/l10n/app_localizations.dart';

// Explicit profile-mode probe; not part of the default unit-test glob. Uses
// temporary browser storage and an in-memory settings database. Always run
// drive with --keep-app-running to prevent uninstalling the user's package.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('Android browser composition costs', (tester) async {
    final directory = await Directory.systemTemp.createTemp('browser-compose-');
    final database = AppDatabase(NativeDatabase.memory());
    final prefs = BusinessPreferences(BusinessRepository(database));
    await prefs.load();
    final settings = SettingsProvider(prefs);
    await settings.loaded;
    final service = BrowserService(store: BrowserStore(directory: directory));
    await service.initialize();
    final frames = <ui.FrameTiming>[];
    final reports = <Map<String, Object?>>[];
    void record(List<ui.FrameTiming> batch) => frames.addAll(batch);
    binding.addTimingsCallback(record);
    final menu = find.byKey(const ValueKey('browserMenuSurface'));
    final more = find.byWidgetPredicate(
      (w) => w is BrowserActionButton && w.label == 'More',
    );
    final viewport = find.byKey(const ValueKey('browserMobileViewportSlot'));
    Future<void> waitFor(String label, bool Function() ready) async {
      final clock = Stopwatch()..start();
      while (!ready()) {
        if (clock.elapsed > const Duration(seconds: 12)) {
          fail('Timeout: $label');
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }

    Future<void> idle() async {
      await waitFor(
        'Flutter motion',
        () => binding.transientCallbackCount == 0,
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }

    Duration pointerTime() => Duration(microseconds: developer.Timeline.now);

    // WidgetTester defaults down/up timestamps to zero. Android's native
    // gesture/IME recognizers need real monotonic times, including the hold.
    Future<void> nativePress(Offset position, {bool long = false}) async {
      final gesture = await tester.createGesture();
      await gesture.down(position, timeStamp: pointerTime());
      await Future<void>.delayed(Duration(milliseconds: long ? 650 : 60));
      await gesture.up(timeStamp: pointerTime());
    }

    Future<void> nativeFling(Offset offset) async {
      final start = tester.getCenter(viewport);
      final gesture = await tester.createGesture();
      await gesture.down(start, timeStamp: pointerTime());
      for (var step = 1; step <= 20; step++) {
        await Future<void>.delayed(const Duration(milliseconds: 16));
        await gesture.moveTo(
          start + offset * (step / 20),
          timeStamp: pointerTime(),
        );
      }
      await gesture.up(timeStamp: pointerTime());
    }

    Future<void> phase(String name, Future<void> Function() action) async {
      await idle();
      final first = ui.PlatformDispatcher.instance.frameData.frameNumber;
      await action();
      await idle();
      final last = ui.PlatformDispatcher.instance.frameData.frameNumber;
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      final sample = frames
          .where((f) => f.frameNumber > first && f.frameNumber <= last)
          .toList();
      final row = <String, Object?>{
        'name': name,
        'frames': sample.length,
        'scrollOffset': service.scrollStateForTab(service.activeTabId)?.offset,
        'ui': _stats(sample.map((f) => f.buildDuration)),
        'raster': _stats(sample.map((f) => f.rasterDuration)),
        'total': _stats(sample.map((f) => f.totalSpan)),
      };
      reports.add(row);
      // ignore: avoid_print
      print('BROWSER_COMPOSITION $row');
      expect(tester.takeException(), isNull);
    }

    try {
      final tab = await service.createTab(ownerSessionId: 'composition-probe');
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: settings,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: BrowserPage(
              service: service,
              conversationId: 'composition-probe',
            ),
          ),
        ),
      );
      const benchmarkUrl = String.fromEnvironment('BROWSER_BENCH_URL');
      if (benchmarkUrl.isEmpty) {
        await service.loadHtml(_page, tabId: tab.id);
      } else {
        await service.navigate(benchmarkUrl, tabId: tab.id);
      }
      await service.waitForLoad(tabId: tab.id);
      await waitFor(
        'web metrics',
        () => service.scrollStateForTab(tab.id) != null,
      );
      for (final style
          in const bool.fromEnvironment('BROWSER_HOST_ONLY')
              ? <BrowserSurfaceStyle>[]
              : BrowserSurfaceStyle.values.reversed) {
        await service.updateSettings(
          service.settings.copyWith(surfaceStyle: style),
        );
        await idle();
        for (var round = 0; round < 2; round++) {
          await phase('${style.name}.$round.menu.open', () async {
            await tester.tap(more);
            await waitFor('menu open', () => menu.evaluate().isNotEmpty);
          });
          await phase('${style.name}.$round.menu.close', () async {
            await tester.tapAt(
              tester.getRect(viewport).topLeft + const Offset(12, 12),
            );
            await waitFor('menu close', () => menu.evaluate().isEmpty);
          });
          await phase('${style.name}.$round.address.open', () async {
            await tester.tap(find.byType(BrowserAddressBar));
            await waitFor('keyboard', () => tester.view.viewInsets.bottom > 0);
          });
          await phase('${style.name}.$round.address.close', () async {
            FocusManager.instance.primaryFocus?.unfocus();
            await waitFor(
              'keyboard closed',
              () => tester.view.viewInsets.bottom == 0,
            );
          });
          await phase('${style.name}.$round.collapse', () async {
            await nativeFling(const Offset(0, -400));
            await Future<void>.delayed(const Duration(milliseconds: 700));
          });
          await phase('${style.name}.$round.expand', () async {
            await nativeFling(const Offset(0, 400));
            await Future<void>.delayed(const Duration(milliseconds: 700));
          });
        }
      }
      if (const bool.fromEnvironment('BROWSER_HOST_CHECK')) {
        await service.loadHtml(_page, tabId: tab.id);
        await service.waitForLoad(tabId: tab.id);
        await idle();
        final inputRect =
            await service.evaluateJavascript(
                  "(() => { const r = document.querySelector('input').getBoundingClientRect(); return [r.left + r.width / 2, r.top + r.height / 2, innerWidth]; })()",
                  tabId: tab.id,
                )
                as List;
        final bounds = tester.getRect(viewport);
        final scale = bounds.width / (inputRect[2] as num);
        await nativePress(
          bounds.topLeft +
              Offset(
                (inputRect[0] as num) * scale,
                (inputRect[1] as num) * scale,
              ),
        );
        await waitFor(
          'native input keyboard',
          () => tester.view.viewInsets.bottom > 0,
        );
        await idle();
        expect(tester.view.viewInsets.bottom, greaterThan(0));
        expect(
          await service.evaluateJavascript(
            "document.activeElement === document.querySelector('input')",
            tabId: tab.id,
          ),
          isTrue,
        );
        await service.evaluateJavascript(
          "document.querySelector('input').value = 'retained input'; document.querySelector('input').blur(); window.scrollTo(0, 220);",
          tabId: tab.id,
        );
        await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
        await waitFor(
          'native input dismissal',
          () => tester.view.viewInsets.bottom == 0,
        );
        await idle();
        for (var iteration = 0; iteration < 6; iteration++) {
          final other = await service.createTab(
            ownerSessionId: 'composition-probe',
          );
          await service.loadHtml('<h1>Other tab</h1>', tabId: other.id);
          await service.waitForLoad(tabId: other.id);
          await idle();
          await service.selectTab(tab.id);
          await idle();
          expect(
            await service.evaluateJavascript(
              "document.querySelector('input').value",
              tabId: tab.id,
            ),
            'retained input',
          );
          expect(
            await service.evaluateJavascript('window.scrollY', tabId: tab.id),
            greaterThan(100),
          );
          await service.closeTab(other.id);
        }
      }
      if (const bool.fromEnvironment('BROWSER_SELECTION_CHECK')) {
        await service.evaluateJavascript(
          'window.scrollTo(0, 0)',
          tabId: tab.id,
        );
        await idle();
        final textRect =
            await service.evaluateJavascript(
                  "(() => { const range = document.createRange(); const n = document.querySelector('h1').firstChild; range.setStart(n, 0); range.setEnd(n, 4); const r = range.getBoundingClientRect(); return [r.left+r.width/2, r.top+r.height/2, innerWidth]; })()",
                  tabId: tab.id,
                )
                as List;
        final bounds = tester.getRect(viewport);
        final scale = bounds.width / (textRect[2] as num);
        await nativePress(
          bounds.topLeft +
              Offset(
                (textRect[0] as num) * scale,
                (textRect[1] as num) * scale,
              ),
          long: true,
        );
        await Future<void>.delayed(const Duration(milliseconds: 800));
        expect(
          await service.evaluateJavascript(
            'getSelection().toString().length',
            tabId: tab.id,
          ),
          greaterThan(0),
        );
        // ignore: avoid_print
        print('BROWSER_SELECTION_READY');
        expect(
          tester.view.viewInsets.bottom,
          0,
          reason: 'Selecting webpage text must not open the keyboard',
        );
        await Future<void>.delayed(const Duration(seconds: 6));
      }
      if (const bool.fromEnvironment('BROWSER_HOST_CHECK')) {
        // Closing a tab while its IME is resizing the native buffer must not
        // release that buffer ahead of Flutter's delayed resize reply.
        await service.evaluateJavascript(
          "getSelection().removeAllRanges(); window.scrollTo(0, 0)",
          tabId: tab.id,
        );
        await idle();
        final r =
            await service.evaluateJavascript(
                  "(() => { const r = document.querySelector('input').getBoundingClientRect(); return [r.left+r.width/2, r.top+r.height/2, innerWidth]; })()",
                  tabId: tab.id,
                )
                as List;
        final bounds = tester.getRect(viewport);
        final scale = bounds.width / (r[2] as num);
        await nativePress(
          bounds.topLeft + Offset((r[0] as num) * scale, (r[1] as num) * scale),
        );
        await waitFor(
          'keyboard before closing tab',
          () => tester.view.viewInsets.bottom > 0,
        );
        await service.closeTab(tab.id);
        await waitFor(
          'keyboard after closing tab',
          () => tester.view.viewInsets.bottom == 0,
        );
        await idle();
        await Future<void>.delayed(const Duration(seconds: 1));
        expect(tester.view.viewInsets.bottom, 0);
      }
      binding.reportData = {
        'phases': reports,
        'shaderFilters': ui.ImageFilter.isShaderFilterSupported,
        'scope':
            'Profile build; ${benchmarkUrl.isEmpty ? 'local fixture' : benchmarkUrl}; Flutter engine FrameTiming, not Android presentation FPS',
      };
    } finally {
      binding.removeTimingsCallback(record);
      await tester.pumpWidget(const SizedBox.shrink());
      service.dispose();
      settings.dispose();
      await database.close();
      await directory.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 4)));
}

Map<String, Object> _stats(Iterable<Duration> values) {
  final ms = values.map((v) => v.inMicroseconds / 1000).toList()..sort();
  if (ms.isEmpty) return {};
  return {
    'p50': ms[(ms.length - 1) ~/ 2],
    'p95': ms[((ms.length - 1) * .95).floor()],
    'max': ms.last,
    'over8ms': ms.where((v) => v > 8.333).length,
    'over16ms': ms.where((v) => v > 16.667).length,
  };
}

const _page =
    '''<!doctype html><meta name="viewport" content="width=device-width,initial-scale=1">
<style>body{margin:0;color:#172942;font:24px system-ui;min-height:5000px;background:repeating-linear-gradient(135deg,#ef8a78 0px,#f3d675 180px,#70b8ad 360px,#7b9bc9 540px,#ef8a78 720px)}section{height:500px;padding:30px}</style>
<section><h1>Composition timing</h1><p>Native webpage and Flutter controls.</p><input placeholder="Web input"></section>
<section>Frame timing</section><section>Scroll area</section><section>Same content in every mode</section>''';
