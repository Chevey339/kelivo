import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:Kelivo/core/services/browser/browser_service.dart';
import 'package:Kelivo/core/services/browser/browser_store.dart';
import 'package:Kelivo/core/services/browser/browser_tools_service.dart';
import 'package:Kelivo/core/services/browser/browser_workspace_resources.dart';
import 'package:Kelivo/core/services/api/tool_result_content.dart';

// Native WebView fixture, with deterministic local responses and a temporary
// workspace. Run with an isolated app/profile, never the installed app's data.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized().framePolicy =
      LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('navigation phases, failed-tab reuse and workspace-only capture', (
    tester,
  ) async {
    final root = await Directory.systemTemp.createTemp(
      'browser-navigation-runtime-',
    );
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final imageGate = Completer<void>(), scriptGate = Completer<void>();
    final scriptRequested = Completer<void>();
    final image = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLttAAAAABJRU5ErkJggg==',
    );
    var recoveredCookie = false;
    server.listen((request) async {
      try {
        final response = request.response;
        switch (request.uri.path) {
          case '/image.png':
            await imageGate.future;
            response.headers.contentType = ContentType('image', 'png');
            response.add(image);
          case '/blocked.js':
            if (!scriptRequested.isCompleted) scriptRequested.complete();
            await scriptGate.future;
            response.headers.contentType = ContentType(
              'application',
              'javascript',
            );
            response.write('window.scriptReady=true;');
          case '/abort':
            (await response.detachSocket()).destroy();
            return;
          default:
            response.headers.contentType = ContentType.html;
            if (request.uri.path == '/slow-image') {
              response.cookies.add(Cookie('fixture', 'retained')..path = '/');
            }
            if (request.uri.path == '/recovered') {
              recoveredCookie = request.cookies.any(
                (c) => c.name == 'fixture' && c.value == 'retained',
              );
            }
            response.write(
              '<!doctype html><title>Native fixture</title><h1 id="ready">Ready</h1>',
            );
            if (request.uri.path == '/slow-dom') {
              response.write('<script src="/blocked.js"></script>');
            } else if (request.uri.path == '/slow-image') {
              response.write('<img src="/image.png">');
            }
            response.write(
              '<input id="far" style="margin-top:1800px"><button id="click" onclick="this.dataset.clicked=1">Click</button>',
            );
        }
        await response.close();
      } catch (_) {
        // Superseding a document intentionally aborts its outstanding requests.
      }
    });
    final origin = 'http://127.0.0.1:${server.port}';
    final browser = BrowserService(
      store: BrowserStore(directory: Directory('${root.path}/state')),
    );
    final tools = BrowserToolsService(
      browser: browser,
      workspaces: BrowserWorkspaceResources()
        ..rootForSession = (id) async => id == 'fixture' ? root : null,
    );
    Future<Map<String, dynamic>> run(
      String action, [
      Map<String, dynamic> args = const {},
      bool ok = true,
    ]) async {
      final raw = await tools.handle('fixture', {
        'action': action,
        ...args,
      }, capturePreview: false);
      final result =
          jsonDecode(raw.content.split('\n![](').first) as Map<String, dynamic>;
      expect(result['ok'], ok, reason: '$action: $result');
      return result;
    }

    try {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Text('Isolated navigation checks')),
        ),
      );
      await browser.initialize();
      await browser.updateSettings(
        browser.settings.copyWith(agentEnabled: true),
      );
      final first = await run('open', {
        'url': '$origin/slow-image',
        'wait_until': 'domcontentloaded',
        'timeout': 5000,
      });
      final tabId = first['page']['tab_id'];
      expect(
        imageGate.isCompleted,
        false,
        reason: 'DOM stage must not wait for images',
      );
      final timeout = await run('wait', {
        'wait_until': 'load',
        'timeout': 200,
      }, false);
      expect(timeout['error_code'], 'browser_load_timeout');
      expect(timeout['outcome_unknown'], false);
      expect(browser.agentPaused, false);
      imageGate.complete();
      await run('wait', {'wait_until': 'load', 'timeout': 5000});

      // Commit is earlier than DOMContentLoaded. A new navigation cancels the
      // old resource request; its late abort must not poison the replacement.
      await run('open', {
        'url': '$origin/slow-dom',
        'wait_until': 'commit',
        'timeout': 5000,
      });
      await scriptRequested.future.timeout(const Duration(seconds: 5));
      final pendingDom = await run('wait', {
        'wait_until': 'domcontentloaded',
        'timeout': 200,
      }, false);
      expect(pendingDom['error_code'], 'browser_load_timeout');
      await run('open', {
        'url': '$origin/healthy',
        'wait_until': 'load',
        'timeout': 5000,
      });
      scriptGate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(browser.requireTab(tabId).error, isNull);
      expect(browser.tabs, hasLength(1));

      final failure = await run('open', {
        'url': '$origin/abort',
        'wait_until': 'load',
        'timeout': 5000,
      }, false);
      expect(failure['error_code'], startsWith('browser_'));
      expect(failure['error'], isNot(contains('Bad state:')));
      expect(browser.agentPaused, false);
      expect(browser.requireTab(tabId).url, isNot(startsWith('chrome-error:')));
      await run('open', {
        'url': '$origin/recovered',
        'wait_until': 'domcontentloaded',
        'timeout': 5000,
      });
      expect(browser.tabs, hasLength(1));
      expect(browser.requireTab(tabId).error, isNull);
      expect(
        recoveredCookie,
        true,
        reason:
            'The existing HttpOnly session cookie survives navigation failure',
      );
      await run('type', {'selector': '#far', 'text': 'after recovery'});
      await run('click', {'selector': '#click'});
      final state = await run('evaluate', {
        'script':
            '({text:document.querySelector("#far").value,clicked:document.querySelector("#click").dataset.clicked,scrolled:scrollY>0})',
      });
      expect(state['page']['value'], {
        'text': 'after recovery',
        'clicked': '1',
        'scrolled': true,
      });
      final shot = await tools.handle('fixture', {
        'action': 'screenshot',
        'save_to': 'shots/native.png',
      }, capturePreview: false);
      final shotResult = jsonDecode(shot.content) as Map;
      expect(shotResult['ok'], true, reason: '$shotResult');
      expect(
        shotResult['page']['screenshot_file']['path'],
        'kelivo://workspace/shots/native.png',
      );
      expect(
        await File('${root.path}/shots/native.png').length(),
        greaterThan(100),
      );
      expect(
        (await ToolResultContent.read(
          'browser',
          shot.content,
          metadata: shot.metadata,
        )).imageUrls,
        isEmpty,
      );
    } finally {
      if (!imageGate.isCompleted) imageGate.complete();
      if (!scriptGate.isCompleted) scriptGate.complete();
      await server.close(force: true);
      browser.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await root.delete(recursive: true);
    }
  });
}
