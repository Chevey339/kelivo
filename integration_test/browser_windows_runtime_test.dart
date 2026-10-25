import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart'
    show
        HeadlessInAppWebView,
        InAppWebView,
        InAppWebViewController,
        URLRequest,
        WebUri;
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
    var rejectNextPopup = false;
    final sceneKey = GlobalKey();
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
            if (tab.windowId != null && rejectNextPopup) {
              rejectNextPopup = false;
              throw StateError('Intentional popup creation failure');
            }
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
    Completer<void>? slowPopupResponse;
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
      if (request.uri.path == '/slow-popup') await slowPopupResponse?.future;
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
        final posted = request.method == 'POST'
            ? await utf8.decoder.bind(request).join()
            : '';
        request.response.write(
          '''<!doctype html><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Browser Probe ${request.uri.path}</title>
<body style="margin:0;min-height:2200px;background:#e8c04a;font:24px sans-serif">
<header style="height:120px;background:#123456;color:white">Browser Probe ${request.uri.path}</header>
<p id="first">Browser probe needle</p><p id="second">Browser probe needle</p>
<a href="/b">Next page</a><input id="input" placeholder="Probe input">
<a id="popup-link" href="/popup-link" target="_blank">New window link</a>
<button id="popup-script" onclick="window.open('/popup-script', '_blank')">Open popup</button>
<button id="popup-cross" onclick="window.open(location.href.replace('127.0.0.1', 'localhost').replace('/a', '/popup-cross'), '_blank')">Cross origin popup</button>
<button id="counter" onclick="this.dataset.count = String(Number(this.dataset.count || 0) + 1)">Counter</button>
<form id="popup-form" method="post" action="/popup-post" target="_blank"><input name="token" value="post-kept"></form>
<p id="post-result">$posted</p>
<script>
window.addEventListener('message', e => { if (e.origin === location.origin) window.popupReply = e.data; });
if (window.opener) window.opener.postMessage('child-ready', location.origin);
${request.uri.path == '/bridge' ? "window.flutter_inappwebview.callHandler('probeReady').then(value => window.__probeReady = value);" : ''}
</script>
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
          home: RepaintBoundary(
            key: sceneKey,
            child: BrowserPage(
              service: browser,
              conversationId: 'windows-probe',
            ),
          ),
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
      await check(
        'captures never expose a resized or white live texture',
        () async {
          await navigate('/a');
          await js('scrollTo(0, 600)');
          await Future<void>.delayed(const Duration(milliseconds: 400));
          final webRect = tester.getRect(find.byType(InAppWebView));
          final boundary =
              sceneKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final sceneOrigin = boundary.localToGlobal(Offset.zero);
          Future<void> sample() async {
            await nextFrame();
            final image = await boundary.toImage(pixelRatio: 1);
            try {
              final pixels = (await image.toByteData())!;
              for (final fraction in [0.25, 0.65, 0.9]) {
                final point =
                    Offset(
                      webRect.left + webRect.width * fraction,
                      webRect.top + webRect.height * 0.7,
                    ) -
                    sceneOrigin;
                final offset =
                    (point.dy.floor() * image.width + point.dx.floor()) * 4;
                expect(pixels.getUint8(offset), inInclusiveRange(225, 240));
                expect(pixels.getUint8(offset + 1), inInclusiveRange(185, 200));
                expect(pixels.getUint8(offset + 2), inInclusiveRange(65, 85));
              }
            } finally {
              image.dispose();
            }
          }

          await sample(); // Verify the oracle sees actual WebView texture pixels.
          for (var i = 0; i < 12; i++) {
            var done = false;
            final capture = Future.wait([
              engines[tab.id]!.thumbnail(),
              engines[tab.id]!.screenshot(),
            ]).whenComplete(() => done = true);
            var sampled = 0;
            while (!done || sampled < 3) {
              await sample();
              sampled++;
            }
            final bytes = await capture;
            expect(bytes.every((b) => b != null), isTrue);
            checks.add({'name': 'in-flight texture samples', 'count': sampled});
          }
        },
      );
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
      await navigate('/a');
      for (final popup in ['script', 'cross', 'link', 'post']) {
        await check('$popup popup loads and leaves opener usable', () async {
          await js("document.getElementById('counter').dataset.count = '0'");
          if (popup == 'cross') {
            await js(
              "window.addEventListener('message', e => { if (e.origin === ${jsonEncode(origin.replaceFirst('127.0.0.1', 'localhost'))}) window.crossReply = e.data; })",
            );
          }
          final before = browser.tabs.map((t) => t.id).toSet();
          debugPrint('WINDOWS_BROWSER_POPUP $popup click');
          await js(
            popup == 'post'
                ? "document.getElementById('popup-form').submit(); 'submitted'"
                : "document.getElementById('popup-$popup').click(); 'clicked'",
          );
          debugPrint('WINDOWS_BROWSER_POPUP $popup clicked');
          await waitUntil(
            () => browser.tabs.any((t) => !before.contains(t.id)),
          );
          final child = browser.tabs.firstWhere((t) => !before.contains(t.id));
          try {
            await browser.waitForLoad(
              tabId: child.id,
              timeout: const Duration(seconds: 10),
            );
            debugPrint('WINDOWS_BROWSER_POPUP $popup loaded');
            await nextFrame();
            await engines[child.id]!.viewReady.timeout(
              const Duration(seconds: 5),
            );
            Future<Object?> childJs(String source) =>
                browser.evaluateJavascript(source, tabId: child.id);
            expect(await childJs('location.pathname'), '/popup-$popup');
            expect(
              await childJs('typeof window.flutter_inappwebview.callHandler'),
              'function',
            );
            await childJs(
              "window.__bridgeReply = null; window.flutter_inappwebview.callHandler('kelivoBrowserHistory').then(() => window.__bridgeReply = 'bridge-ok'); true",
            );
            final bridgeDeadline = Stopwatch()..start();
            while (await childJs('window.__bridgeReply') != 'bridge-ok') {
              if (bridgeDeadline.elapsed > const Duration(seconds: 3)) {
                fail('Popup bridge did not complete');
              }
              await Future<void>.delayed(const Duration(milliseconds: 16));
            }
            debugPrint('WINDOWS_BROWSER_POPUP $popup bridge');
            if (popup == 'script') {
              expect(await childJs('!!window.opener'), isTrue);
              expect(await js('window.popupReply'), 'child-ready');
            }
            if (popup == 'cross') {
              expect(await childJs('!!window.opener'), isTrue);
              await childJs(
                "window.opener.postMessage('cross-ready', ${jsonEncode(origin)})",
              );
              await Future<void>.delayed(const Duration(milliseconds: 50));
              expect(await js('window.crossReply'), 'cross-ready');
            }
            if (popup == 'post') {
              expect(
                await childJs(
                  "document.getElementById('post-result').textContent",
                ),
                'token=post-kept',
              );
            }
            debugPrint('WINDOWS_BROWSER_POPUP $popup reload');
            await browser.reload(tabId: child.id);
            await browser.waitForLoad(
              tabId: child.id,
              timeout: const Duration(seconds: 10),
            );
            expect(
              await childJs('document.title'),
              'Browser Probe /popup-$popup',
            );
            debugPrint('WINDOWS_BROWSER_POPUP $popup reloaded');
            if (popup == 'script') {
              slowPopupResponse = Completer<void>();
              try {
                await childJs(
                  "document.querySelector('a').href = '/slow-popup'; document.querySelector('a').click()",
                );
                await waitUntil(() => browser.requireTab(child.id).isLoading);
                var settled = false;
                final loaded = browser
                    .waitForLoad(
                      tabId: child.id,
                      timeout: const Duration(seconds: 10),
                    )
                    .then((_) => settled = true);
                await Future<void>.delayed(const Duration(milliseconds: 200));
                expect(
                  settled,
                  isFalse,
                  reason: 'Popup link must await the new document',
                );
                slowPopupResponse!.complete();
                await loaded;
                expect(await childJs('location.pathname'), '/slow-popup');
                expect(browser.requireTab(child.id).isLoading, isFalse);
              } finally {
                if (!slowPopupResponse!.isCompleted) {
                  slowPopupResponse!.complete();
                }
                slowPopupResponse = null;
              }
            }
          } finally {
            debugPrint('WINDOWS_BROWSER_POPUP $popup close');
            await browser.closeTab(child.id);
            debugPrint('WINDOWS_BROWSER_POPUP $popup closed');
          }
          await browser.selectTab(tab.id);
          await nextFrame();
          await engines[tab.id]!.viewReady.timeout(const Duration(seconds: 5));
          await js('scrollTo(0, 0)');
          final target =
              (await js("""(() => {
            const r = document.getElementById('counter').getBoundingClientRect();
            return {x:r.x+r.width/2,y:r.y+r.height/2};
          })()"""))
                  as Map;
          await mouseClick(
            tester.getTopLeft(find.byType(InAppWebView)) +
                Offset(
                  (target['x'] as num).toDouble(),
                  (target['y'] as num).toDouble(),
                ),
          );
          expect(
            await js("document.getElementById('counter').dataset.count"),
            '1',
          );
          expect(await js('location.pathname'), '/a');
        });
      }
      await check(
        'rejected popup unblocks opener without navigating it',
        () async {
          await js("document.getElementById('counter').dataset.count = '0'");
          rejectNextPopup = true;
          final count = browser.tabs.length;
          await js(
            "document.getElementById('popup-script').click(); 'returned'",
          );
          await waitUntil(() => !rejectNextPopup);
          await waitUntil(() => browser.tabs.length == count);
          expect(await js('location.pathname'), '/a');
          await js("document.getElementById('counter').click()");
          expect(
            await js("document.getElementById('counter').dataset.count"),
            '1',
          );
          await browser.reload(tabId: tab.id);
          await browser.waitForLoad(
            tabId: tab.id,
            timeout: const Duration(seconds: 10),
          );
          expect(await js('document.title'), 'Browser Probe /a');
        },
      );
      await check('bridge isolates frames and retired documents', () async {
        late InAppWebViewController controller;
        var loaded = Completer<void>();
        var delayed = Completer<String>();
        var delayStarted = Completer<void>();
        var echoCalls = 0;
        var disposed = false;
        final view = HeadlessInAppWebView(
          initialUrlRequest: URLRequest(url: WebUri('$origin/bridge')),
          onWebViewCreated: (created) {
            controller = created;
            created.addJavaScriptHandler(
              handlerName: 'probeReady',
              callback: (_) => 'ready',
            );
            created.addJavaScriptHandler(
              handlerName: 'probeEcho',
              callback: (_) => ++echoCalls,
            );
            created.addJavaScriptHandler(
              handlerName: 'probeDelay',
              callback: (_) {
                if (!delayStarted.isCompleted) delayStarted.complete();
                return delayed.future;
              },
            );
          },
          onLoadStop: (_, _) {
            if (!loaded.isCompleted) loaded.complete();
          },
        );
        Future<Object?> evaluate(String source) =>
            controller.evaluateJavascript(source: source);
        Future<void> waitJs(String source, Object expected) async {
          final deadline = Stopwatch()..start();
          while (await evaluate(source) != expected) {
            if (deadline.elapsed > const Duration(seconds: 3)) {
              fail('Bridge did not reach $expected for $source');
            }
            await Future<void>.delayed(const Duration(milliseconds: 20));
          }
        }

        try {
          await view.run();
          await loaded.future.timeout(const Duration(seconds: 5));
          // The first document calls the bridge without waiting for a later
          // navigation or manually opening the visible browser.
          await waitJs('window.__probeReady', 'ready');
          const envelope =
              "JSON.stringify({name:'callHandler',body:{handlerName:'probeEcho',_callHandlerID:901,args:'[]'}})";
          await evaluate('_flutter_inappwebview_postMessage($envelope)');
          await waitUntil(() => echoCalls == 1);
          final iframeScript =
              '_flutter_inappwebview_postMessage($envelope); '
              "parent.postMessage('frame-called', '*');";
          await evaluate('''
window.addEventListener('message', e => { if (e.data === 'frame-called') window.__frameCalled = true; });
const frame = document.createElement('iframe');
frame.sandbox = 'allow-scripts';
frame.srcdoc = ${jsonEncode('<script>$iframeScript</script>')};
document.body.appendChild(frame);
''');
          await waitJs('window.__frameCalled', true);
          await Future<void>.delayed(const Duration(milliseconds: 100));
          expect(
            echoCalls,
            1,
            reason: 'A subframe must not invoke app handlers',
          );
          // Malformed binding messages must not escape a native event callback.
          await evaluate('''
_flutter_inappwebview_postMessage('not-json');
_flutter_inappwebview_postMessage('{"name":"callHandler","body":3}');
window.flutter_inappwebview.callHandler('probeEcho').then(v => window.__echo = v);
''');
          await waitJs('window.__echo', 2);
          final callId = await evaluate('''
window.flutter_inappwebview.callHandler('probeDelay');
Object.keys(window.flutter_inappwebview).filter(k => !isNaN(Number(k))).map(Number).pop();
''');
          expect(callId, isA<num>());
          await delayStarted.future.timeout(const Duration(seconds: 3));
          loaded = Completer<void>();
          await controller.loadUrl(
            urlRequest: URLRequest(url: WebUri('$origin/b')),
          );
          await loaded.future.timeout(const Duration(seconds: 5));
          await evaluate('''
window.__leaked = false;
window.flutter_inappwebview[$callId] = {resolve:()=>window.__leaked=true,reject:()=>window.__leaked=true};
while (setTimeout(()=>{}, 0) <= $callId) {}
''');
          delayed.complete('old document result');
          await evaluate(
            "window.flutter_inappwebview.callHandler('probeEcho').then(v => window.__echo = v)",
          );
          await waitJs('window.__echo', 3);
          expect(await evaluate('window.__leaked'), isFalse);
          delayed = Completer<String>();
          delayStarted = Completer<void>();
          await evaluate(
            "window.flutter_inappwebview.callHandler('probeDelay'); true",
          );
          await delayStarted.future.timeout(const Duration(seconds: 3));
          await view.dispose();
          disposed = true;
          delayed.complete('closed document result');
          await nextFrame();
          expect(await js('document.title'), 'Browser Probe /a');
        } finally {
          if (!delayed.isCompleted) delayed.complete('test cleanup');
          if (!disposed) await view.dispose();
        }
      });
      await check('closing a tab during capture completes safely', () async {
        final closing = await browser.createTab(
          ownerSessionId: 'windows-probe',
        );
        await browser.navigate('$origin/a', tabId: closing.id);
        await browser.waitForLoad(
          tabId: closing.id,
          timeout: const Duration(seconds: 10),
        );
        final capture = engines[closing.id]!.thumbnail();
        await browser.closeTab(closing.id);
        // A capture already copied may finish; a cancelled one returns null.
        // In either case it must settle and leave the surviving tab usable.
        await capture.timeout(const Duration(seconds: 5));
        expect(browser.tabs.any((t) => t.id == closing.id), isFalse);
        expect(await js('document.title'), 'Browser Probe /a');
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
