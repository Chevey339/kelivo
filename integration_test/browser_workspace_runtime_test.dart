import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:Kelivo/core/services/browser/browser_service.dart';
import 'package:Kelivo/core/services/browser/browser_store.dart';
import 'package:Kelivo/core/services/browser/browser_tools_service.dart';
import 'package:Kelivo/core/services/browser/browser_workspace_resources.dart';

// Run in an isolated runner/profile. Uses temporary files and no app database,
// provider credentials, external websites or installed-app state.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized().framePolicy =
      LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('workspace browser resources and verified agent interactions', (
    tester,
  ) async {
    final directory = await Directory.systemTemp.createTemp(
      'browser-resources-runtime-',
    );
    final workspace = await Directory('${directory.path}/files').create();
    await File('${workspace.path}/index.html').writeAsString('''<!doctype html>
<meta charset="utf-8"><title>Workspace fixture</title>
<link rel="stylesheet" href="style.css">
<main><h1>工作区预览</h1><input id="name" aria-label="Name">
<input id="reject" oninput="this.value=''">
<select id="choice"><option value="a">One</option><option value="b">Two</option></select>
<button id="dialog" onclick="window.answers=[confirm('confirm-fixture'),prompt('prompt-fixture')];alert('alert-fixture')">Dialog</button>
<p id="data">loading</p><div id="ticker">0</div></main>
<script type="module" src="app.js"></script>''');
    await File(
      '${workspace.path}/style.css',
    ).writeAsString('h1{color:rgb(12,34,56)}');
    await File('${workspace.path}/app.js').writeAsString(
      "const response=await fetch('./data.json');window.fetchStatus=response.status;const data=await response.json();document.querySelector('#data').textContent=data.label;window.assetsReady=response.ok;",
    );
    await File(
      '${workspace.path}/data.json',
    ).writeAsString('{"label":"相对资源正常"}');
    final resources = BrowserWorkspaceResources.instance;
    final previousResolver = resources.rootForSession;
    resources.rootForSession = (id) async => id == 'fixture' ? workspace : null;
    final browser = BrowserService(
      store: BrowserStore(directory: Directory('${directory.path}/browser')),
    );
    final tools = BrowserToolsService(browser: browser);
    Map<String, dynamic> decode(String value) =>
        jsonDecode(value.split('\n![](').first) as Map<String, dynamic>;
    Future<Map<String, dynamic>> run(
      String action, [
      Map<String, dynamic> args = const {},
    ]) async {
      final result = decode(
        (await tools.handle('fixture', {
          'action': action,
          ...args,
        }, capturePreview: false)).content,
      );
      expect(result['ok'], true, reason: '$action: $result');
      return result['page'] as Map<String, dynamic>;
    }

    try {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Text('Isolated browser resource checks')),
        ),
      );
      await browser.initialize();
      await browser.updateSettings(
        browser.settings.copyWith(agentEnabled: true),
      );
      final opened = await run('open', {
        'url': 'kelivo://workspace/index.html',
      });
      expect(opened['url'], 'kelivo://workspace/index.html');
      // Module loading is asynchronous; wait on a concrete resulting element.
      await run('wait', {
        'wait_for': '#data',
        'wait_for_url': 'workspace/index.html',
      });
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      Map<String, dynamic> state;
      do {
        state = await run('evaluate', {
          'script':
              '({ready:window.assetsReady,status:window.fetchStatus,text:document.querySelector("#data").textContent,color:getComputedStyle(document.querySelector("h1")).color})',
        });
        if ((state['value'] as Map)['ready'] == true) break;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      } while (DateTime.now().isBefore(deadline));
      expect(state['value'], {
        'ready': true,
        'status': 200,
        'text': '相对资源正常',
        'color': 'rgb(12, 34, 56)',
      });
      final snap = await run('snapshot');
      final ref = (snap['elements'] as List).cast<Map>().singleWhere(
        (e) => e['name'] == 'Name',
      )['ref'];
      await run('evaluate', {
        'script': 'document.querySelector("#ticker").textContent="unrelated"',
      });
      expect(
        (await run('type', {'ref': ref, 'text': 'Kelivo'}))['verified'],
        true,
      );
      expect(
        (await run('select_option', {
          'selector': '#choice',
          'option_value': 'b',
        }))['value'],
        'b',
      );
      final rejected = decode(
        (await tools.handle('fixture', {
          'action': 'type',
          'selector': '#reject',
          'text': 'rejected',
        }, capturePreview: false)).content,
      );
      expect(rejected['ok'], false);
      expect(rejected['error_code'], 'input_value_rejected');
      final dialog = await run('click', {'selector': '#dialog'});
      expect((dialog['events'] as List).length, 3);
      expect((await run('evaluate', {'script': 'window.answers'}))['value'], [
        false,
        null,
      ]);
      resources.rootForSession = (_) async => null;
      final denied = decode(
        (await tools.handle('fixture', {
          'action': 'open',
          'url': 'kelivo://workspace/index.html',
        }, capturePreview: false)).content,
      );
      expect(denied['ok'], false);
    } finally {
      browser.dispose();
      resources.rootForSession = previousResolver;
      await tester.pumpWidget(const SizedBox.shrink());
      // Native disposal is async; the temporary data is independent of the app.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await directory.delete(recursive: true);
    }
  });
}
