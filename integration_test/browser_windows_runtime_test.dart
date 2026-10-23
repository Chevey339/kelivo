import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart'
    show InAppWebView;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/database/business_repository.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/browser/browser_engine.dart';
import 'package:Kelivo/core/services/browser/browser_native_engine.dart';
import 'package:Kelivo/core/services/browser/browser_service.dart';
import 'package:Kelivo/core/services/browser/browser_store.dart';
import 'package:Kelivo/features/browser/models/browser_models.dart';
import 'package:Kelivo/features/browser/pages/browser_page.dart';
import 'package:Kelivo/features/browser/widgets/browser_controls.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

// Run in an independently named Windows runner, with a process-local
// WEBVIEW2_USER_DATA_FOLDER. No normal Kelivo database or profile is opened.
// flutter drive -d windows --driver=test_driver/integration_test.dart \
//   --target=integration_test/browser_windows_runtime_test.dart
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('Windows native browser runtime', (tester) async {
    final directory = await Directory.systemTemp.createTemp('browser-win-');
    final database = AppDatabase(NativeDatabase.memory());
    final preferences = BusinessPreferences(BusinessRepository(database));
    await preferences.load();
    final settings = SettingsProvider(preferences);
    await settings.loaded;
    final engines = <String, BrowserEngine>{};
    final browser = BrowserService(
      store: BrowserStore(directory: directory),
      engineFactory:
          ({
            required tab,
            required settings,
            required onChanged,
            required onDownload,
            required onNewWindow,
            required isAgentActive,
          }) async {
            return engines[tab.id] = await NativeBrowserEngine.create(
              tab: tab,
              settings: settings,
              onChanged: onChanged,
              onDownload: onDownload,
              onNewWindow: onNewWindow,
              isAgentActive: isAgentActive,
            );
          },
    );
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final origin = 'http://127.0.0.1:${server.port}';
    final checks = <Map<String, Object?>>[];
    final failures = <String>[];
    var uiFrames = 0;
    var rasterFrames = 0;
    var framesResponsive = true;
    binding.addPersistentFrameCallback((_) => uiFrames++);
    void frameTimings(List<ui.FrameTiming> timings) {
      rasterFrames += timings.length;
    }

    binding.addTimingsCallback(frameTimings);
    server.listen((request) async {
      if (request.uri.path == '/download') {
        final cookies = {for (final c in request.cookies) c.name: c.value};
        final authenticated =
            cookies['probe_session'] == 'test-session' &&
            cookies['probe_persistent'] == 'test-persistent';
        request.response.statusCode = authenticated ? 200 : 401;
        request.response.write(
          authenticated ? 'isolated download passed' : 'missing cookies',
        );
      } else {
        request.response.headers.contentType = ContentType.html;
        request.response.headers.set(
          HttpHeaders.cacheControlHeader,
          'no-store',
        );
        request.response.cookies.add(
          Cookie('probe_session', 'test-session')
            ..path = '/'
            ..httpOnly = true,
        );
        request.response.cookies.add(
          Cookie('probe_persistent', 'test-persistent')
            ..path = '/'
            ..maxAge = 600
            ..httpOnly = true,
        );
        request.response.write(
          '''<!doctype html><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Browser Probe ${request.uri.path}</title>
<body style="margin:0;min-height:2200px;background:#e8c04a;font:24px sans-serif">
<header style="height:120px;background:#123456;color:white">Browser Probe ${request.uri.path}</header>
<p id="first">Browser probe needle</p><p id="second">Browser probe needle</p>
<a href="/b">Next page</a><input id="input" placeholder="Probe input">
<button id="routes" onclick="history.pushState({}, '', '#one'); history.pushState({}, '', '#two')">Route states</button>
</body>''',
        );
      }
      await request.response.close();
    });
    Future<void> waitUntil(bool Function() condition) async {
      final elapsed = Stopwatch()..start();
      while (!condition()) {
        if (elapsed.elapsed > const Duration(seconds: 3)) {
          fail('UI did not reach the expected state within 3 seconds');
        }
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }
    }

    Future<void> nextFrame() async {
      final beforeUi = uiFrames;
      final beforeRaster = rasterFrames;
      binding.scheduleFrame();
      try {
        await waitUntil(
          () => uiFrames > beforeUi && rasterFrames > beforeRaster,
        );
      } catch (_) {
        framesResponsive = false;
        rethrow;
      }
    }

    Future<void> mount(Widget widget) async {
      // Fully-live integration frames must have a bounded wait: a timed-out
      // tester.pumpWidget leaves an uncancellable guarded pump behind.
      binding.attachRootWidget(binding.wrapWithDefaultView(widget));
      await nextFrame();
    }

    Future<void> check(String name, Future<void> Function() action) async {
      final clock = Stopwatch()..start();
      try {
        await action().timeout(const Duration(seconds: 25));
        checks.add({
          'name': name,
          'passed': true,
          'ms': clock.elapsedMilliseconds,
        });
        debugPrint('WINDOWS_BROWSER_PASS $name');
      } catch (error, stack) {
        failures.add('$name: $error');
        checks.add({
          'name': name,
          'passed': false,
          'error': '$error',
          'stack': '$stack',
          'ms': clock.elapsedMilliseconds,
        });
        debugPrint('WINDOWS_BROWSER_FAIL $name: $error');
      }
    }

    try {
      await windowManager.ensureInitialized();
      await windowManager.setTitle('Kelivo Browser Probe');
      await windowManager.show();
      await windowManager.focus();
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Windows browser probe'))),
      );
      await browser.initialize();
      await browser.updateSettings(
        browser.settings.copyWith(agentEnabled: true),
      );
      final tab = await browser.createTab(ownerSessionId: 'windows-probe');
      Future<Object?> js(String source) =>
          browser.evaluateJavascript(source, tabId: tab.id);
      Future<void> mouseClick(Offset point) async {
        final mouse = await tester.createGesture(
          kind: ui.PointerDeviceKind.mouse,
        );
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(point);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await mouse.down(point);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await mouse.up();
        await mouse.removePointer();
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }

      Widget browserPage() => ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BrowserPage(service: browser, conversationId: 'windows-probe'),
        ),
      );

      Future<void> verifyThumbnail(String phase) async {
        final bytes = await engines[tab.id]!.thumbnail();
        expect(bytes, isNotNull);
        final codec = await ui.instantiateImageCodec(bytes!);
        final frame = await codec.getNextFrame();
        try {
          checks.add({
            'name': '$phase thumbnail dimensions',
            'width': frame.image.width,
            'height': frame.image.height,
            'bytes': bytes.length,
          });
          expect(frame.image.width, inInclusiveRange(430, 440));
          expect(frame.image.height, greaterThan(40));
          final pixels = (await frame.image.toByteData())!;
          expect(
            pixels.getUint32(0),
            isNot(pixels.getUint32(pixels.lengthInBytes - 4)),
          );
        } finally {
          frame.image.dispose();
          codec.dispose();
        }
        final report = Platform.environment['KELIVO_BROWSER_PROBE_REPORT'];
        if (report != null) {
          await File(
            '${File(report).parent.path}/$phase-thumbnail.jpg',
          ).writeAsBytes(bytes);
        }
      }

      Future<void> recordState(String phase) async {
        final state = <String, Object?>{
          'name': phase,
          'tabUrl': browser.requireTab(tab.id).url,
          'back': browser.requireTab(tab.id).canGoBack,
          'forward': browser.requireTab(tab.id).canGoForward,
          'document': await js('''({url: location.href, title: document.title,
            ready: document.readyState, hidden: document.hidden, focus: document.hasFocus(), historyLength: history.length,
            index: window.navigation?.currentEntry?.index,
            observer: window.__kelivoBrowserHistoryDocument,
            selection: window.getSelection().toString(),
            width: innerWidth, height: innerHeight})'''),
        };
        checks.add(state);
        debugPrint('WINDOWS_BROWSER_STATE ${jsonEncode(state)}');
      }

      Future<void> navigate(String path) async {
        await browser.navigate('$origin$path', tabId: tab.id);
        await browser.waitForLoad(
          tabId: tab.id,
          timeout: const Duration(seconds: 12),
        );
      }

      await check('headless WebView2 opens HTTP page', () async {
        await navigate('/a');
        expect(await js('document.title'), 'Browser Probe /a');
        expect(browser.requireTab(tab.id).isLoading, isFalse);
      });
      await check('page title metadata', () async {
        expect(browser.requireTab(tab.id).title, 'Browser Probe /a');
      });
      await check(
        'headless thumbnail is bounded',
        () => verifyThumbnail('headless'),
      );
      await js(
        'window.__probeIdentity = "retained"; document.getElementById("input").value = "unsent input"; scrollTo(0, 400)',
      );
      await tester.pumpWidget(browserPage());
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 3),
      );
      await engines[tab.id]!.viewReady.timeout(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 300));
      await recordState('after presentation');
      await check('presentation preserves the loaded document', () async {
        expect(await js('document.title'), 'Browser Probe /a');
        expect(await js('location.pathname'), '/a');
        expect(await js('window.__probeIdentity'), 'retained');
        expect(
          await js('document.getElementById("input").value'),
          'unsent input',
        );
        expect(await js('scrollY'), 400);
      });
      await js('scrollTo(0, 0)');
      await check(
        'visible thumbnail is bounded',
        () => verifyThumbnail('visible'),
      );
      await check('detach and reattach preserve the same document', () async {
        await mount(
          const MaterialApp(home: Scaffold(body: Text('Back in chat'))),
        );
        expect(await js('window.__probeIdentity'), 'retained');
        await verifyThumbnail('detached');
        await mount(browserPage());
        await engines[tab.id]!.viewReady.timeout(const Duration(seconds: 5));
        expect(await js('window.__probeIdentity'), 'retained');
        expect(
          await js('document.getElementById("input").value'),
          'unsent input',
        );
      });
      // Independently exercise the visible host even if presentation lost the
      // headless document, so later failures are not consequences of that loss.
      await navigate('/a');
      await check('visible page and find next/previous', () async {
        await browser.findInPage('Browser probe needle', tabId: tab.id);
        await recordState('after find');
        expect(
          await js('window.getSelection().toString()'),
          'Browser probe needle',
        );
        final first = await js(
          'window.getSelection().anchorNode.parentElement.id',
        );
        await browser.findNext(tabId: tab.id);
        expect(
          await js('window.getSelection().anchorNode.parentElement.id'),
          isNot(first),
        );
        await browser.findNext(tabId: tab.id, forward: false);
        expect(
          await js('window.getSelection().anchorNode.parentElement.id'),
          first,
        );
        await browser.clearFind(tabId: tab.id);
        expect(await js('window.getSelection().toString()'), isEmpty);
      });
      await check('full-document back and forward', () async {
        await navigate('/b');
        await recordState('before back');
        await browser.back(tabId: tab.id);
        await browser.waitForLoad(
          tabId: tab.id,
          timeout: const Duration(seconds: 8),
        );
        await recordState('after back');
        expect(await js('location.pathname'), '/a');
        await browser.forward(tabId: tab.id);
        await browser.waitForLoad(
          tabId: tab.id,
          timeout: const Duration(seconds: 8),
        );
        expect(await js('location.pathname'), '/b');
      });
      await navigate('/b');
      await check('same-document agent back/forward completes', () async {
        // Chromium's native Back intentionally skips script-created entries
        // without user activation. Create SPA entries through the WebView's
        // actual pointer path, as a person clicking a page would.
        final button =
            (await js('''(() => {
          const r = document.getElementById('routes').getBoundingClientRect();
          return {x:r.x+r.width/2, y:r.y+r.height/2};
        })()'''))
                as Map;
        final origin = tester.getTopLeft(find.byType(InAppWebView));
        await mouseClick(
          origin +
              Offset(
                (button['x'] as num).toDouble(),
                (button['y'] as num).toDouble(),
              ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 300));
        expect(await js('location.hash'), '#two');
        expect(await js('navigator.userActivation.hasBeenActive'), isTrue);
        for (final forward in [false, true]) {
          await browser.runAgentAction(
            sessionId: 'windows-probe',
            label: forward ? 'forward' : 'back',
            tabId: tab.id,
            action: () async {
              if (forward) {
                await browser.forward(tabId: tab.id);
              } else {
                await browser.back(tabId: tab.id);
              }
              try {
                await browser.waitForLoad(
                  tabId: tab.id,
                  timeout: const Duration(seconds: 5),
                );
              } finally {
                await recordState(
                  'same-document ${forward ? 'forward' : 'back'}',
                );
              }
            },
          );
          expect(await js('location.hash'), forward ? '#two' : '#one');
          expect(browser.agentPaused, isFalse);
        }
      });
      await check(
        'authenticated download retains session and persistent cookies',
        () async {
          await browser.download(
            '$origin/download',
            tabId: tab.id,
            fileName: 'probe.txt',
          );
          final download = browser.downloads.first;
          expect(download.status, BrowserDownloadStatus.completed);
          expect(
            await File(download.path!).readAsString(),
            'isolated download passed',
          );
        },
      );
      await check('thumbnail contains bounded real pixels', () async {
        final bytes = await engines[tab.id]!.thumbnail();
        expect(bytes, isNotNull);
        final report = Platform.environment['KELIVO_BROWSER_PROBE_REPORT'];
        if (report != null) {
          await File(
            '${File(report).parent.path}/native-thumbnail.jpg',
          ).writeAsBytes(bytes!);
          final screenshot = await engines[tab.id]!.screenshot();
          if (screenshot != null) {
            await File(
              '${File(report).parent.path}/native-page.png',
            ).writeAsBytes(screenshot);
          }
        }
        final codec = await ui.instantiateImageCodec(bytes!);
        final frame = await codec.getNextFrame();
        checks.add({
          'name': 'thumbnail dimensions',
          'width': frame.image.width,
          'height': frame.image.height,
          'bytes': bytes.length,
        });
        try {
          expect(frame.image.width, inInclusiveRange(430, 440));
        } finally {
          frame.image.dispose();
          codec.dispose();
        }
      });
      await check('concurrent captures preserve viewport and scroll', () async {
        await js('scrollTo(0, 400)');
        const viewportScript =
            'JSON.stringify({width:innerWidth,height:innerHeight,x:scrollX,y:scrollY})';
        final before = await js(viewportScript);
        for (var round = 0; round < 3; round++) {
          final captures = await Future.wait([
            engines[tab.id]!.thumbnail(),
            engines[tab.id]!.screenshot(),
          ]);
          for (var index = 0; index < captures.length; index++) {
            final bytes = captures[index];
            expect(bytes, isNotNull);
            final codec = await ui.instantiateImageCodec(bytes!);
            final frame = await codec.getNextFrame();
            try {
              final bound = index == 0 ? 440 : 1280;
              expect(frame.image.width, inInclusiveRange(bound - 1, bound));
              final pixels = (await frame.image.toByteData())!;
              final offset = (10 * frame.image.width + 10) * 4;
              // After scrolling, the viewport starts with yellow body, not
              // the dark blue document header. Capture must not jump to top.
              expect(pixels.getUint8(offset), greaterThan(180));
              expect(pixels.getUint8(offset + 1), greaterThan(140));
              expect(pixels.getUint8(offset + 2), lessThan(120));
            } finally {
              frame.image.dispose();
              codec.dispose();
            }
          }
          expect(await js(viewportScript), before);
        }
      });
      await check('browser menu in all surface modes', () async {
        await navigate('/a');
        checks.add({
          'name': 'shader support',
          'supported': ui.ImageFilter.isShaderFilterSupported,
        });
        for (final style in [
          BrowserSurfaceStyle.solid,
          BrowserSurfaceStyle.frosted,
          BrowserSurfaceStyle.liquid,
        ]) {
          debugPrint('WINDOWS_BROWSER_MENU ${style.name} settings');
          final beforeRaster = rasterFrames;
          await browser.updateSettings(
            browser.settings.copyWith(surfaceStyle: style),
          );
          await nextFrame();
          await Future<void>.delayed(const Duration(milliseconds: 400));
          if (style == BrowserSurfaceStyle.liquid) {
            final effects = find.byWidgetPredicate(
              (w) => w.runtimeType.toString() == '_LightweightGlassEffect',
            );
            expect(effects, findsWidgets);
            for (final element in effects.evaluate()) {
              final dynamic renderer = element.findRenderObject()!;
              expect(
                renderer.shader,
                isNotNull,
                reason: 'Liquid must paint its shader, not only a tint',
              );
            }
            checks.add({'name': 'liquid shader ready', 'passed': true});
          }
          debugPrint('WINDOWS_BROWSER_MENU ${style.name} tap');
          final more = find.byWidgetPredicate(
            (w) => w is BrowserActionButton && w.label == 'More',
          );
          expect(more.hitTestable(), findsOneWidget);
          await mouseClick(tester.getCenter(more.hitTestable()));
          await waitUntil(() => find.text('New tab').evaluate().isNotEmpty);
          expect(find.text('New tab'), findsWidgets);
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await nextFrame();
          await waitUntil(() => find.text('New tab').evaluate().isEmpty);
          await waitUntil(() => rasterFrames > beforeRaster + 3);
          checks.add({
            'name': '${style.name} menu frames',
            'rasterFrames': rasterFrames - beforeRaster,
          });
          debugPrint('WINDOWS_BROWSER_MENU ${style.name} passed');
          expect(
            await js('document.body.innerText'),
            contains('Browser probe needle'),
          );
        }
      });
    } finally {
      if (framesResponsive) {
        await check('renderer remains responsive during cleanup', () async {
          // Confirm a raster frame, not only a UI callback, before unmounting.
          await nextFrame();
          await mount(const SizedBox.shrink());
        });
      }
      binding.reportData = {
        'platform': Platform.operatingSystem,
        'os': Platform.operatingSystemVersion,
        'checks': checks,
        'failures': failures,
        'uiFrames': uiFrames,
        'rasterFrames': rasterFrames,
        'framesResponsive': framesResponsive,
      };
      final report = Platform.environment['KELIVO_BROWSER_PROBE_REPORT'];
      if (report != null) {
        await File(report).writeAsString(
          const JsonEncoder.withIndent('  ').convert(binding.reportData),
        );
      }
      binding.removeTimingsCallback(frameTimings);
      browser.dispose();
      settings.dispose();
      await database.close();
      await server.close(force: true);
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  }, skip: !Platform.isWindows);
}
