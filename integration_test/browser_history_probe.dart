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
import 'package:Kelivo/features/browser/pages/browser_page.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

// Explicit native runtime probe, outside the default *_test.dart glob.
// Uses an ephemeral loopback server, browser directory and settings database.
// --keep-app-running is required: otherwise flutter drive uninstalls the app.
// flutter drive -d <device> --keep-app-running --no-dds \
//   --driver=test_driver/integration_test.dart \
//   --target=integration_test/browser_history_probe.dart
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('native back-forward history ordering', (tester) async {
    final directory = await Directory.systemTemp.createTemp('browser-history-');
    final database = AppDatabase(NativeDatabase.memory());
    final preferences = BusinessPreferences(BusinessRepository(database));
    await preferences.load();
    final settings = SettingsProvider(preferences);
    await settings.loaded;
    final service = BrowserService(store: BrowserStore(directory: directory));
    await service.initialize();
    var tab = await service.createTab(ownerSessionId: 'history-probe');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final origin = 'http://127.0.0.1:${server.port}';
    final requests = <String>[];
    server.listen((request) async {
      requests.add(request.uri.toString());
      if (!const ['/a', '/b', '/c', '/spa'].contains(request.uri.path)) {
        request.response.statusCode = HttpStatus.notFound;
      } else {
        request.response.headers.contentType = ContentType.html;
        request.response.headers.set(
          HttpHeaders.cacheControlHeader,
          'no-store',
        );
        request.response.write(_fixture(request.uri.path));
      }
      await request.response.close();
    });

    final events = <Map<String, Object?>>[];
    final checkpoints = <Map<String, Object?>>[];
    final rapidTraversals = <Map<String, Object?>>[];
    final clock = Stopwatch()..start();
    String? previousState;
    void recordState() {
      final current = service.requireTab(tab.id);
      final key = '${current.url}|${current.canGoBack}|${current.canGoForward}';
      if (key == previousState) return;
      previousState = key;
      events.add({
        'elapsedMs': clock.elapsedMilliseconds,
        'url': current.url,
        'back': current.canGoBack,
        'forward': current.canGoForward,
      });
    }

    service.addListener(recordState);
    Future<void> waitUntil(String label, bool Function() ready) async {
      final waiting = Stopwatch()..start();
      while (!ready()) {
        if (waiting.elapsed > const Duration(seconds: 12)) {
          fail(
            '$label timed out; last events: ${events.skip(events.length > 8 ? events.length - 8 : 0).toList()}',
          );
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }

    Future<Map<String, dynamic>> document() async {
      final result = await service.evaluateJavascript(
        'JSON.stringify({url: location.href, length: history.length, '
        'document: document.body.dataset.page, ready: document.readyState, '
        'state: history.state})',
        tabId: tab.id,
      );
      return jsonDecode(result! as String) as Map<String, dynamic>;
    }

    Future<void> checkpoint(
      String label,
      String path, {
      required bool back,
      required bool forward,
      required int length,
    }) async {
      final url = '$origin$path';
      bool matches() {
        final current = service.requireTab(tab.id);
        return current.url == url &&
            current.canGoBack == back &&
            current.canGoForward == forward;
      }

      await waitUntil('$label native URL and history flags', matches);
      // Allow late native callbacks to arrive; they must not revert Forward.
      await Future<void>.delayed(const Duration(milliseconds: 180));
      expect(matches(), isTrue, reason: '$label reverted after acknowledgment');
      var actual = await document();
      final documentWait = Stopwatch()..start();
      while (actual['url'] != url || actual['ready'] != 'complete') {
        if (documentWait.elapsed > const Duration(seconds: 12)) {
          fail('$label visible document did not settle: $actual');
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
        actual = await document();
      }
      expect(matches(), isTrue, reason: '$label history after document commit');
      expect(actual['url'], url, reason: '$label visible WebKit document');
      expect(actual['document'], Uri.parse(path).path);
      expect(actual['length'], length, reason: '$label WebKit history length');
      checkpoints.add({
        'name': label,
        'url': url,
        'back': back,
        'forward': forward,
        'document': actual,
      });
      debugPrint('HISTORY PROBE checkpoint $label');
      expect(tester.takeException(), isNull);
    }

    Future<void> navigate(String path) async {
      await service.navigate('$origin$path', tabId: tab.id);
      await service.waitForLoad(
        tabId: tab.id,
        timeout: const Duration(seconds: 12),
      );
    }

    Future<void> rapid(
      String label,
      List<int> directions,
      List<String> expectedPaths,
    ) async {
      final start = events.length;
      final started = Stopwatch()..start();
      // Intentionally enqueue in one synchronous turn, with no settling between
      // calls. Waiting for all returned Futures alone is not evidence of order.
      await Future.wait([
        for (final direction in directions)
          direction < 0
              ? service.back(tabId: tab.id)
              : service.forward(tabId: tab.id),
      ]).timeout(const Duration(seconds: 15));
      List<String> urls() {
        final result = <String>[];
        for (final event in events.skip(start)) {
          final url = event['url']! as String;
          if (result.isEmpty || result.last != url) result.add(url);
        }
        // A history availability update can precede the first URL notification.
        final initial = '$origin${expectedPaths.last}';
        if (result.isNotEmpty && result.first == initial) result.removeAt(0);
        return result;
      }

      await waitUntil('$label all native URL transitions', () {
        return urls().length >= expectedPaths.length;
      });
      final actual = urls();
      expect(actual, expectedPaths.map((path) => '$origin$path').toList());
      rapidTraversals.add({
        'name': label,
        'commands': directions,
        'nativeUrls': actual,
        'acknowledgedMs': started.elapsedMilliseconds,
      });
    }

    binding.reportData = {
      'protocol': {
        'platform': Platform.operatingSystem,
        'osVersion': Platform.operatingSystemVersion,
        'buildMode': kDebugMode
            ? 'debug'
            : (kProfileMode ? 'profile' : 'release'),
        'fixture': 'ephemeral loopback HTTP pages; no external assets',
        'scope':
            'Real WebKit URL/document/history acknowledgments and browser '
            'availability. Service commands exercise the same path as UI '
            'buttons. Does not measure physical-device frame rate or heat.',
      },
      'checkpoints': checkpoints,
      'rapidTraversals': rapidTraversals,
      'events': events,
      'requests': requests,
    };
    try {
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: settings,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BrowserPage(
              service: service,
              conversationId: 'history-probe',
            ),
          ),
        ),
      );
      await navigate('/a');
      await waitUntil(
        'Visible native view',
        () => (service.scrollStateForTab(tab.id)?.viewportExtent ?? 0) > 0,
      );
      await checkpoint(
        'initial A',
        '/a',
        back: false,
        forward: false,
        length: 1,
      );
      await navigate('/b');
      await checkpoint(
        'navigate B',
        '/b',
        back: true,
        forward: false,
        length: 2,
      );
      await navigate('/c');
      await checkpoint(
        'navigate C',
        '/c',
        back: true,
        forward: false,
        length: 3,
      );

      for (var round = 1; round <= 5; round++) {
        await service.back(tabId: tab.id);
        await checkpoint(
          'back $round',
          '/b',
          back: true,
          forward: true,
          length: 3,
        );
        await service.forward(tabId: tab.id);
        await checkpoint(
          'forward $round',
          '/c',
          back: true,
          forward: false,
          length: 3,
        );
      }
      for (var round = 1; round <= 3; round++) {
        await rapid(
          'alternating $round',
          [-1, 1, -1, 1],
          ['/b', '/c', '/b', '/c'],
        );
        await checkpoint(
          'rapid $round end',
          '/c',
          back: true,
          forward: false,
          length: 3,
        );
      }

      await navigate('/spa');
      await checkpoint(
        'SPA base',
        '/spa',
        back: true,
        forward: false,
        length: 4,
      );
      for (var step = 1; step <= 2; step++) {
        await service.evaluateJavascript(
          'history.pushState({step:$step}, "", "/spa?step=$step")',
          tabId: tab.id,
        );
        await checkpoint(
          'SPA push $step',
          '/spa?step=$step',
          back: true,
          forward: false,
          length: 4 + step,
        );
      }
      await service.back(tabId: tab.id);
      await checkpoint(
        'SPA back',
        '/spa?step=1',
        back: true,
        forward: true,
        length: 6,
      );
      await service.forward(tabId: tab.id);
      await checkpoint(
        'SPA forward',
        '/spa?step=2',
        back: true,
        forward: false,
        length: 6,
      );
      await rapid(
        'SPA alternating',
        [-1, -1, 1, 1],
        ['/spa?step=1', '/spa', '/spa?step=1', '/spa?step=2'],
      );
      await checkpoint(
        'SPA rapid end',
        '/spa?step=2',
        back: true,
        forward: false,
        length: 6,
      );
      await service.back(tabId: tab.id);
      await checkpoint(
        'SPA before branch',
        '/spa?step=1',
        back: true,
        forward: true,
        length: 6,
      );
      await service.evaluateJavascript(
        'history.pushState({branch:1}, "", "/spa?branch=1")',
        tabId: tab.id,
      );
      await checkpoint(
        'SPA new branch clears Forward',
        '/spa?branch=1',
        back: true,
        forward: false,
        length: 6,
      );
      await service.evaluateJavascript(
        'history.replaceState({branch:2}, "", "/spa?branch=2")',
        tabId: tab.id,
      );
      await checkpoint(
        'SPA replace preserves list',
        '/spa?branch=2',
        back: true,
        forward: false,
        length: 6,
      );

      tab = await service.createTab(ownerSessionId: 'history-probe');
      await navigate('/spa');
      await checkpoint(
        'same URL base',
        '/spa',
        back: false,
        forward: false,
        length: 1,
      );
      await service.evaluateJavascript(
        'history.pushState({same:1}, "")',
        tabId: tab.id,
      );
      await checkpoint(
        'same URL push enables Back',
        '/spa',
        back: true,
        forward: false,
        length: 2,
      );
      await service.back(tabId: tab.id);
      await checkpoint(
        'same URL back enables Forward',
        '/spa',
        back: false,
        forward: true,
        length: 2,
      );
      expect((await document())['state'], isNull);
      await service.forward(tabId: tab.id);
      await checkpoint(
        'same URL forward',
        '/spa',
        back: true,
        forward: false,
        length: 2,
      );
      expect((await document())['state'], {'same': 1});
      await Future.wait([
        service.back(tabId: tab.id),
        service.forward(tabId: tab.id),
        service.back(tabId: tab.id),
        service.forward(tabId: tab.id),
      ]).timeout(const Duration(seconds: 15));
      await checkpoint(
        'same URL rapid end',
        '/spa',
        back: true,
        forward: false,
        length: 2,
      );
      expect((await document())['state'], {'same': 1});
    } catch (_) {
      debugPrint(
        'HISTORY PROBE failure report: ${jsonEncode(binding.reportData)}',
      );
      rethrow;
    } finally {
      service.removeListener(recordState);
      await tester.pumpWidget(const SizedBox.shrink());
      await service.flush();
      service.dispose();
      settings.dispose();
      await database.close();
      await server.close(force: true);
      await directory.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}

String _fixture(String path) =>
    '''<!doctype html>
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>History $path</title>
<link rel="icon" href="data:,">
<style>body{font:24px system-ui;padding:32px;min-height:1200px;background:#e5edf6}</style>
<body data-page="$path"><h1>History $path</h1><p>Local native navigation fixture.</p></body>''';
