import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
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
import 'package:Kelivo/features/browser/models/browser_models.dart';
import 'package:Kelivo/features/browser/pages/browser_mobile_layout.dart';
import 'package:Kelivo/features/browser/pages/browser_page.dart';
import 'package:Kelivo/features/browser/widgets/native_browser_glass.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

// Visual/functional probe of the production BrowserPage, not a performance
// benchmark or a reproduction using separate glass controls. Uses temporary
// browser storage and an in-memory settings database, with local HTML only.
// flutter drive -d <iOS simulator> --keep-app-running --no-dds \
//   --driver=test_driver/integration_test.dart \
//   --target=integration_test/browser_dark_chrome_probe.dart
// Capture the actual display at DARK_CHROME_VISUAL, then tap Next. The final
// With --dart-define=DARK_CHROME_MANUAL_SCROLL=true, DARK_CHROME_ACTION asks
// for one real native swipe; synthetic DOM scrolling intentionally cannot
// collapse the production toolbar. Leave it off for non-touch automation.
void main() {
  const manualScroll = bool.fromEnvironment('DARK_CHROME_MANUAL_SCROLL');
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive
    ..shouldPropagateDevicePointerEvents = true;

  testWidgets('inspect complete dark browser chrome on real webpages', (
    tester,
  ) async {
    expect(Platform.isIOS, isTrue);
    expect(NativeBrowserGlass.isSupported, isTrue);
    final directory = await Directory.systemTemp.createTemp('dark-chrome-');
    final database = AppDatabase(NativeDatabase.memory());
    final preferences = BusinessPreferences(BusinessRepository(database));
    await preferences.load();
    final settings = SettingsProvider(preferences);
    await settings.loaded;
    final service = BrowserService(store: BrowserStore(directory: directory));
    await service.initialize();
    await service.updateSettings(
      service.settings.copyWith(surfaceStyle: BrowserSurfaceStyle.liquid),
    );
    final tab = await service.createTab(ownerSessionId: 'dark-chrome-probe');
    final banner = ValueNotifier((label: 'Preparing', next: false));
    Completer<void>? nextGate;
    final stages = <Map<String, Object?>>[];
    final viewport = find.byKey(const ValueKey('browserMobileViewportSlot'));
    final chrome = find.byType(BrowserChromeTransition);

    Future<void> waitUntil(
      String label,
      FutureOr<bool> Function() ready, {
      Duration timeout = const Duration(seconds: 15),
      Object? Function()? diagnostics,
    }) async {
      final clock = Stopwatch()..start();
      while (!await ready()) {
        if (clock.elapsed > timeout) {
          fail('$label timed out; ${jsonEncode(diagnostics?.call())}');
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }

    Future<void> idle() => waitUntil(
      'Chrome animation completion',
      () => !binding.hasScheduledFrame && binding.transientCallbackCount == 0,
    );

    try {
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: settings,
          child: MaterialApp(
            theme: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(
                primary: Color(0xff0a84ff),
                surface: Color(0xff1c1c1e),
                onSurface: Colors.white,
              ),
            ),
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Stack(
                fit: StackFit.expand,
                children: [
                  BrowserPage(
                    service: service,
                    conversationId: 'dark-chrome-probe',
                  ),
                  Positioned(
                    top: MediaQuery.viewPaddingOf(context).top + 6,
                    left: 12,
                    right: 12,
                    child: ValueListenableBuilder(
                      valueListenable: banner,
                      builder: (context, value, _) => Material(
                        color: const Color(0xe61c1c1e),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 12, right: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  value.label,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: value.next
                                    ? () {
                                        if (nextGate?.isCompleted == false) {
                                          nextGate!.complete();
                                        }
                                      }
                                    : null,
                                child: const Text('Next'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(viewport, findsOneWidget);
      expect(chrome, findsOneWidget);

      for (final name in [
        'white-expanded',
        'color-expanded',
        'black-expanded',
        if (manualScroll) 'white-collapsed',
      ]) {
        banner.value = (label: 'Loading $name', next: false);
        nextGate = null;
        await service.loadHtml(_document(name), tabId: tab.id);
        await service.waitForLoad(
          tabId: tab.id,
          timeout: const Duration(seconds: 15),
        );
        Map<String, Object?>? document;
        Map<String, Object?> readiness = {};
        var lastReadinessLog = DateTime.fromMillisecondsSinceEpoch(0);
        await waitUntil('Actual $name DOM and visible WK viewport', () async {
          final result = await service.evaluateJavascript(
            '''JSON.stringify({marker:document.body?.dataset.scene,
              ready:document.readyState,width:innerWidth,height:innerHeight,
              background:getComputedStyle(document.body).background,
              title:document.querySelector('h1')?.textContent})''',
            tabId: tab.id,
          );
          if (result is String) {
            document = (jsonDecode(result) as Map).cast<String, Object?>();
          }
          final scroll = service.scrollStateForTab(tab.id);
          final viewportSize = tester.getSize(viewport);
          final layout = tester.widget<BrowserMobileLayout>(
            find.byType(BrowserMobileLayout),
          );
          final width = (document?['width'] as num?)?.toDouble() ?? 0;
          final height = (document?['height'] as num?)?.toDouble() ?? 0;
          final checks = {
            'correctDocument': document?['marker'] == name,
            'documentComplete': document?['ready'] == 'complete',
            'positiveDomViewport': width > 0 && height > 0,
            'positiveNativeViewport': (scroll?.viewportExtent ?? 0) > 0,
            // iOS now reports UIScrollView.bounds.height (native points).
            // WK's obscured inset can change DOM innerHeight independently;
            // compare the native bounds to the actual Flutter host instead.
            'nativeViewportMatchesHost':
                scroll != null &&
                (scroll.viewportExtent - viewportSize.height).abs() < 1,
            'domWidthMatchesHost': (width - viewportSize.width).abs() < 1,
            'underlapStatusBar': layout.underlapStatusBar,
            'fadeBehindToolbar': layout.fadeBehindToolbar,
            'tabPresented': service.isTabPresented(tab.id),
          };
          readiness = {
            'scene': name,
            'checks': checks,
            'resultType': result.runtimeType.toString(),
            'document': document,
            'flutterViewport': [viewportSize.width, viewportSize.height],
            'viewPaddingTop': layout.viewPadding.top,
            'nativeScroll': scroll == null
                ? null
                : {
                    'offset': scroll.offset,
                    'viewportExtent': scroll.viewportExtent,
                    'contentExtent': scroll.contentExtent,
                    'phase': scroll.phase.name,
                    'isUserInteracting': scroll.isUserInteracting,
                  },
          };
          final ready = checks.values.every((value) => value);
          final now = DateTime.now();
          if (!ready &&
              now.difference(lastReadinessLog) >= const Duration(seconds: 1)) {
            lastReadinessLog = now;
            debugPrintSynchronously(
              'DARK_CHROME_WAIT ${jsonEncode(readiness)}',
            );
          }
          return ready;
        }, diagnostics: () => readiness);
        expect(service.activeTab?.hasContent, isTrue);
        await waitUntil(
          'Expanded toolbar after navigation',
          () => tester.widget<BrowserChromeTransition>(chrome).progress == 0,
        );
        await idle();
        final collapsed = name.endsWith('collapsed');
        if (collapsed) {
          banner.value = (
            label: 'Swipe UP on the webpage to collapse the real toolbar',
            next: false,
          );
          debugPrintSynchronously(
            'DARK_CHROME_ACTION ${jsonEncode({'scene': name, 'action': 'swipe-up-on-native-webpage', 'maximumWaitSeconds': 60, 'utc': DateTime.now().toUtc().toIso8601String()})}',
          );
          await waitUntil(
            'Actual native gesture collapses toolbar',
            () =>
                tester.widget<BrowserChromeTransition>(chrome).progress == 1 &&
                (service.scrollStateForTab(tab.id)?.offset ?? 0) > 16 &&
                service.scrollStateForTab(tab.id)?.isUserInteracting == false,
            timeout: const Duration(seconds: 60),
          );
          await idle();
        }
        nextGate = Completer<void>();
        banner.value = (label: name, next: true);
        await Future<void>.delayed(const Duration(milliseconds: 800));
        expect(tester.takeException(), isNull);
        final state = service.scrollStateForTab(tab.id)!;
        final stage = <String, Object?>{
          'scene': name,
          'theme': 'dark',
          'surface': service.settings.surfaceStyle.name,
          'nativeGlass': NativeBrowserGlass.isSupported,
          'underlap': tester
              .widget<BrowserMobileLayout>(find.byType(BrowserMobileLayout))
              .underlapStatusBar,
          'fadeBehindToolbar': tester
              .widget<BrowserMobileLayout>(find.byType(BrowserMobileLayout))
              .fadeBehindToolbar,
          'chromeTarget': tester
              .widget<BrowserChromeTransition>(chrome)
              .progress,
          'scrollOffset': state.offset,
          'viewportExtent': state.viewportExtent,
          'document': document,
          'maximumHoldSeconds': 60,
          'utc': DateTime.now().toUtc().toIso8601String(),
        };
        stages.add(stage);
        debugPrintSynchronously('DARK_CHROME_VISUAL ${jsonEncode(stage)}');
        await nextGate.future.timeout(
          const Duration(seconds: 60),
          onTimeout: () {},
        );
      }
      binding.reportData = {
        'probe': 'browser-dark-production-chrome',
        'manualScroll': manualScroll,
        'operatingSystemVersion': Platform.operatingSystemVersion,
        'scope':
            'Actual BrowserPage, native WebView, production toolbar and bottom '
            'gradient. Visual/functional checks only; no performance metrics. '
            'Optional collapsed scene requires a real native gesture, not '
            'injected state. No collapsed gesture coverage when manualScroll '
            'is false.',
        'stages': stages,
      };
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await service.flush();
      service.dispose();
      settings.dispose();
      banner.dispose();
      await database.close();
      await directory.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 7)));
}

String _document(String name) {
  final black = name.startsWith('black');
  final color = name.startsWith('color');
  final background = black
      ? '#08090c'
      : color
      ? 'linear-gradient(90deg,#fb6542 0 33.33%,#19bdc5 33.33% 66.66%,#7369ed 66.66%)'
      : '#ffffff';
  final foreground = black ? '#f6f6fa' : '#162030';
  final lines = black ? 'rgba(255,255,255,.3)' : 'rgba(12,20,30,.3)';
  return '''<!doctype html><html><head>
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>$name</title><style>
html,body{margin:0;font:22px -apple-system;color:$foreground}
body{min-height:4200px;background:$background}
section{height:350px;box-sizing:border-box;padding:88px 24px 12px;
background:repeating-linear-gradient(0deg,transparent 0 42px,$lines 42px 43px)}
h1{font-size:42px;line-height:1.1;margin:12px 0;font-weight:750}
p{font-size:20px;line-height:1.4;margin:12px 0}
</style></head><body data-scene="$name">
${List.generate(12, (index) => '<section><h1>${name.split('-').first.toUpperCase()} ${index + 1}</h1><p>Real browser toolbar<br>Dark glass · Thin lines<br>Bottom gradient · 12345</p></section>').join()}
</body></html>''';
}
