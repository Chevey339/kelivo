// Native browser verification, with an isolated store and no model credentials.
// flutter run -d macos --profile -t tool/browser_smoke.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show timeDilation;
import 'package:drift/native.dart';
import 'package:provider/provider.dart';
import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/database/business_repository.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/browser/browser_service.dart';
import 'package:Kelivo/core/services/browser/browser_store.dart';
import 'package:Kelivo/core/services/browser/browser_tools_service.dart';
import 'package:Kelivo/features/browser/pages/browser_page.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final root = await getApplicationSupportDirectory();
  final directory = Directory(
    '${root.path}/browser-smoke-${DateTime.now().millisecondsSinceEpoch}',
  );
  final service = BrowserService(store: BrowserStore(directory: directory));
  await service.initialize();
  final preferences = BusinessPreferences(
    BusinessRepository(AppDatabase(NativeDatabase.memory())),
  );
  await preferences.load();
  final settings = SettingsProvider(preferences);
  await settings.loaded;
  runApp(
    ChangeNotifierProvider<SettingsProvider>.value(
      value: settings,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff79624c)),
          useMaterial3: true,
        ),
        home: BrowserPage(service: service, conversationId: 'smoke-chat'),
      ),
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(
      _verify(service, directory).whenComplete(() {
        // Optional native-UI inspection mode: the functional smoke stays at
        // normal speed; only subsequent manual Flutter transitions slow down.
        if (const bool.fromEnvironment('BROWSER_SLOW_MOTION')) timeDilation = 4;
      }),
    );
  });
}

Future<void> _verify(BrowserService service, Directory directory) async {
  final results = <String, Object?>{};
  final tools = BrowserToolsService(browser: service);
  final timings = <FrameTiming>[];
  HttpServer? server;
  void record(List<FrameTiming> frames) => timings.addAll(frames);
  WidgetsBinding.instance.addTimingsCallback(record);
  Future<Map<String, dynamic>> action(
    String name, [
    Map<String, dynamic> args = const {},
  ]) async {
    debugPrint('BROWSER_SMOKE_ACTION $name start');
    final result = await tools.handle('smoke-chat', {'action': name, ...args});
    final decoded =
        jsonDecode(result.content.split('\n![](').first)
            as Map<String, dynamic>;
    if (decoded['ok'] != true) throw StateError('$name: ${result.content}');
    results[name] = true;
    debugPrint('BROWSER_SMOKE_ACTION $name passed');
    return Map<String, dynamic>.from(decoded['page'] as Map);
  }

  try {
    await Future<void>.delayed(const Duration(seconds: 1));
    await service.updateSettings(service.settings.copyWith(agentEnabled: true));
    service.allowAgentControl();
    final rendered = await action('render', {
      'html': _fixture,
      'title': 'Kelivo browser smoke',
    });
    final tabId = rendered['tab_id'] as String;
    await Future<void>.delayed(const Duration(milliseconds: 700));
    await action('snapshot', {'include_text': true});
    await action('type', {'selector': '#name', 'text': 'Kelivo'});
    await action('click', {'selector': '#apply'});
    final value = await action('evaluate', {
      'script': 'document.querySelector("#result").textContent',
    });
    if (!jsonEncode(value).contains('Hello Kelivo')) {
      throw StateError('Input/click result mismatch: $value');
    }
    final promised = await action('evaluate', {
      'script': 'Promise.resolve({answer: 42})',
    });
    if (!jsonEncode(promised).contains('42')) {
      throw StateError('Promise result missing');
    }
    await action('scroll', {'direction': 'down', 'amount': 240});
    await action('scroll', {'direction': 'up', 'amount': 240});
    await service.findInPage('Kelivo', tabId: tabId);
    await service.clearFind(tabId: tabId);
    final shot = await action('snapshot', {'include_screenshot': true});
    if (shot.containsKey('screenshot_error')) {
      throw StateError('${shot['screenshot_error']}');
    }
    final bytes = await service.captureScreenshot(tabId: tabId);
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Native screenshot empty');
    }
    await File('${directory.path}/webview.png').writeAsBytes(bytes);
    results['screenshot_bytes'] = bytes.length;
    final other = await service.createTab(ownerSessionId: 'other-chat');
    final denied = await tools.handle('smoke-chat', {
      'action': 'snapshot',
      'tab_id': other.id,
    });
    if (jsonDecode(denied.content)['ok'] != false) {
      throw StateError('Cross-chat access allowed');
    }
    results['session_isolation'] = true;
    await Future<void>.delayed(const Duration(milliseconds: 700));
    final background = await action('evaluate', {
      'tab_id': tabId,
      'script': 'document.querySelector("#name").value',
    });
    if (!jsonEncode(background).contains('Kelivo')) {
      throw StateError('Detached visible tab lost its controller or document');
    }
    await action('type', {
      'tab_id': tabId,
      'selector': '#name',
      'text': 'Kelivo background',
    });
    results['detached_agent'] = true;
    await service.selectTab(tabId);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    final retained = await action('evaluate', {
      'script': 'document.querySelector("#name").value',
    });
    if (!jsonEncode(retained).contains('Kelivo background')) {
      throw StateError('View transfer lost form state');
    }
    results['view_transfer'] = true;
    service.takeOver();
    final paused = await tools.handle('smoke-chat', {
      'action': 'click',
      'selector': '#apply',
    });
    if (jsonDecode(paused.content)['ok'] != false) {
      throw StateError('Human takeover did not block automation');
    }
    results['takeover'] = true;
    service.allowAgentControl();
    await action('snapshot');
    final temporaryTab = await action('new_tab');
    await action('close_tab', {'tab_id': temporaryTab['tab_id']});
    await service.selectTab(tabId);
    await service.addBookmark(url: 'https://example.com/', title: 'Example');
    await service.flush();
    final restored = BrowserService(store: BrowserStore(directory: directory));
    await restored.initialize();
    if (restored.bookmarks.single.title != 'Example' ||
        restored.tabs.length != service.tabs.length) {
      throw StateError('Persistence did not round-trip');
    }
    restored.dispose();
    results['persistence'] = true;
    final hidden = BrowserService(
      store: BrowserStore(directory: Directory('${directory.path}/headless')),
    );
    try {
      await hidden.initialize();
      await hidden.updateSettings(hidden.settings.copyWith(agentEnabled: true));
      final hiddenTools = BrowserToolsService(browser: hidden);
      final renderedHidden = await hiddenTools.handle('hidden-chat', {
        'action': 'render',
        'html': _fixture,
      });
      if (jsonDecode(renderedHidden.content)['ok'] != true) {
        throw StateError('Headless render failed: ${renderedHidden.content}');
      }
      final hiddenSnapshot = await hiddenTools.handle('hidden-chat', {
        'action': 'snapshot',
        'include_text': true,
        'include_screenshot': true,
      });
      final hiddenData =
          jsonDecode(hiddenSnapshot.content.split('\n![](').first) as Map;
      if (hiddenData['ok'] != true ||
          (hiddenData['page'] as Map).containsKey('screenshot_error')) {
        throw StateError('Headless screenshot failed: $hiddenData');
      }
      results['headless_agent'] = true;
    } finally {
      hidden.dispose();
    }
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      if (request.uri.path == '/download') {
        request.response.statusCode = HttpStatus.found;
        request.response.headers.set(HttpHeaders.locationHeader, '/file');
      } else if (request.uri.path == '/file') {
        if (!request.cookies.any(
          (cookie) => cookie.name == 'browser_smoke' && cookie.value == 'yes',
        )) {
          request.response.statusCode = HttpStatus.unauthorized;
        } else {
          request.response.headers.set(
            HttpHeaders.contentTypeHeader,
            'application/octet-stream',
          );
          request.response.write('Kelivo download verified');
        }
      } else {
        request.response.headers.contentType = ContentType.html;
        request.response.cookies.add(
          Cookie('browser_smoke', 'yes')..path = '/',
        );
        request.response.write(
          _fixture.replaceAll(
            'A place to explore.',
            request.uri.path == '/second'
                ? 'The second page.'
                : 'A place to explore.',
          ),
        );
      }
      await request.response.close();
    });
    final base = 'http://127.0.0.1:${server.port}';
    await action('open', {'url': '$base/first'});
    await action('open', {'url': '$base/second'});
    await action('back');
    final previous = await action('evaluate', {'script': 'location.pathname'});
    if (!jsonEncode(previous).contains('/first')) {
      throw StateError('Back navigation failed: $previous');
    }
    await action('forward');
    if (!service.history.any((entry) => entry.url.endsWith('/second'))) {
      throw StateError('Navigation missing from history');
    }
    results['navigation_history'] = true;
    await service.download(
      '$base/download',
      fileName: 'smoke.txt',
      tabId: tabId,
    );
    final download = service.downloads.first;
    if (download.path == null ||
        await File(download.path!).readAsString() !=
            'Kelivo download verified') {
      throw StateError(
        'Authenticated redirect download failed: ${download.error}',
      );
    }
    results['authenticated_download'] = true;
    results['ok'] = true;
  } catch (error, stack) {
    results['ok'] = false;
    results['error'] = error.toString();
    results['stack'] = stack.toString();
  } finally {
    WidgetsBinding.instance.removeTimingsCallback(record);
    await server?.close(force: true);
    if (timings.isNotEmpty) {
      final build =
          timings.map((x) => x.buildDuration.inMicroseconds / 1000).toList()
            ..sort();
      final raster =
          timings.map((x) => x.rasterDuration.inMicroseconds / 1000).toList()
            ..sort();
      results['frames'] = timings.length;
      results['build_p90_ms'] =
          build[(build.length * .9).floor().clamp(0, build.length - 1)];
      results['raster_p90_ms'] =
          raster[(raster.length * .9).floor().clamp(0, raster.length - 1)];
    }
    await directory.create(recursive: true);
    await File(
      '${directory.path}/result.json',
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(results));
    debugPrint('BROWSER_SMOKE ${jsonEncode(results)}');
    debugPrint('BROWSER_SMOKE_DIRECTORY ${directory.path}');
  }
}

const _fixture = '''<!doctype html><html><head>
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Kelivo browser smoke</title><style>
body{font:18px -apple-system,sans-serif;margin:0;color:#303a35;background:#edf0e8}
main{padding:40px 24px;max-width:720px;margin:auto}h1{font-size:42px;letter-spacing:-2px}
input,button{font:inherit;padding:12px;border:1px solid #c6cfc2;border-radius:12px}
button{background:#546c57;color:white}section{height:1600px;padding-top:32px;background:repeating-linear-gradient(135deg,#ed8d7d 0 120px,#e0c276 120px 240px,#75b9af 240px 360px,#799bc8 360px 480px);font-size:52px;font-weight:700;line-height:2.2;color:#253c48}
.scroll-check{position:fixed;right:12px;top:12px;z-index:5;display:flex;gap:4px}.scroll-check button{padding:8px;font-size:12px;background:#fff;color:#222}
</style></head><body><nav class="scroll-check"><button onclick="window.scrollBy({top:480,behavior:'smooth'})">Scroll ↓</button><button onclick="window.scrollBy({top:-480,behavior:'smooth'})">Scroll ↑</button></nav><main><p>KELIVO / BROWSER</p><h1>A place to explore.</h1>
<p>A real native web page, shared with your agent.</p>
<label for="name">Your name</label><p><input id="name" placeholder="Type here"></p>
<button id="apply" onclick="document.querySelector('#result').textContent='Hello '+document.querySelector('#name').value">Apply</button>
<p><button id="popup" onclick="const w=window.open('about:blank'); if(w) w.document.write('<title>Popup test</title><h1>Popup opened</h1><p id=opener>Opener: '+Boolean(w.opener)+'</p>')">Open popup</button></p>
<p id="result" role="status">Ready</p><section>Live page<br>Glass<br>Refraction<br>Scroll to explore<br>Light &amp; color</section></main></body></html>''';
