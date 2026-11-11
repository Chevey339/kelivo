import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:Kelivo/core/services/browser/browser_service.dart';
import 'package:Kelivo/core/services/browser/browser_store.dart';
import 'package:Kelivo/core/services/browser/browser_workspace_resources.dart';
import 'package:Kelivo/core/services/browser/browser_workspace_app.dart';
import 'package:Kelivo/core/services/workspace/workspace_app_storage.dart';
import 'package:Kelivo/core/services/workspace/workspace_file_access.dart';
import 'package:Kelivo/core/services/workspace/workspace_paths.dart';
import 'package:Kelivo/core/services/conversation_tool_permissions.dart';
import 'package:Kelivo/core/models/tool_permission_mode.dart';

Future<void> _measureStorage(Future<Object?> Function(String) evaluate) async {
  final clock = Stopwatch()..start();
  var last = clock.elapsedMicroseconds;
  var samples = <int>[];
  final timer = Timer.periodic(const Duration(milliseconds: 4), (_) {
    final now = clock.elapsedMicroseconds;
    samples.add((now - last - 4000).clamp(0, 10000000));
    last = now;
  });
  Map<String, num> delays(List<int> values) {
    values.sort();
    return {
      'p95_ms':
          values[(values.length * .95).floor().clamp(0, values.length - 1)] /
          1000,
      'max_ms': values.last / 1000,
    };
  }

  try {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final baseline = delays(samples);
    samples = [];
    final result = await evaluate('''(async () => {
      const results=[];
      for (const size of [10240,102400,2097152]) {
        const path='perf-'+size+'.txt'; let version=(await kelivo.readFile(path)).version;
        const writes=[], reads=[];
        for(let i=0;i<12;i++) {
          const text=String.fromCharCode(65+i).repeat(size);
          let start=performance.now();
          version=(await kelivo.writeFile(path,text,version)).version;
          if(i>=2) writes.push(performance.now()-start);
          start=performance.now(); await kelivo.readFile(path);
          if(i>=2) reads.push(performance.now()-start);
        }
        writes.sort((a,b)=>a-b); reads.sort((a,b)=>a-b);
        results.push({bytes:size,write_p50_ms:writes[5],write_max_ms:writes[9],read_p50_ms:reads[5],read_max_ms:reads[9]});
      }
      return JSON.stringify(results);
    })()''');
    // ignore: avoid_print
    print(
      'STORAGE_PERF ${jsonEncode({'platform': Platform.operatingSystem, 'build': 'debug integration runner', 'permissions': 'WorkspaceFileAccess with in-memory fixture state', 'samples_per_size': 10, 'results': jsonDecode(result as String), 'idle_timer_delay': baseline, 'active_timer_delay': delays(samples)})}',
    );
  } finally {
    timer.cancel();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized().framePolicy =
      LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('native storage bridge and offline application isolation', (
    tester,
  ) async {
    final root = await Directory.systemTemp.createTemp(
      'kelivo-storage-runtime-',
    );
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var requests = 0;
    server.listen((request) {
      requests++;
      request.response.headers.contentType = ContentType.html;
      request.response.write('<title>external</title>');
      request.response.close();
    });
    final address = 'http://127.0.0.1:${server.port}';
    await File('${root.path}/notes.app.html').writeAsString(
      '''<!doctype html><meta charset="utf-8">
<title>Storage isolation fixture</title><p>Isolation test</p>
<script>
window.checks = {bridge:false, fetchBlocked:false};
window.appInitialized = kelivo.ready.then(async value => {
  await Promise.all(Array.from({length:8},(_,i)=>kelivo.readFile('missing-'+i+'.json')));
  checks.bridge=value.version===1;
}).catch(e => checks.error=String(e));
fetch('$address/fetch').catch(() => checks.fetchBlocked=true);
new Image().src='$address/image';
const frame=document.createElement('iframe');frame.src='$address/frame';document.body.append(frame);
</script>''',
    );
    final resources = BrowserWorkspaceResources.instance;
    final oldRoot = resources.rootForSession;
    final oldAccess = resources.authorizeData;
    var writesAllowed = true;
    var writeChecks = 0;
    Completer<void>? writeGate;
    final canonicalRoot = await root.resolveSymbolicLinks();
    final paths = WorkspacePaths.sandboxed(
      workspaceHostRoot: canonicalRoot,
      sessionHostDir: '$canonicalRoot/session',
      skillsHostDir: '$canonicalRoot/skills',
    );
    resources.authorizeData = (id, path, write) async {
      if (id != 'storage-fixture') throw StateError('tool_disabled');
      if (write) {
        writeChecks++;
        await writeGate?.future;
      }
      await WorkspaceFileAccess(
        paths: paths,
        arguments: const {},
        permission: ToolCallPermission(
          toolName: write ? 'write_file' : 'read_file',
          toolCallId: '',
          workspaceId: 'fixture',
          isEnabled: () => !write || writesAllowed,
          readState: () => const ToolPermissionState(workspaceId: 'fixture'),
        ),
      ).resolve(path, paths.modelRoot, write: write);
    };
    resources.rootForSession = (id) async =>
        id == 'storage-fixture' ? root : null;
    final browser = BrowserService(
      store: BrowserStore(directory: Directory('${root.path}/profile')),
    );
    try {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Text('Storage isolation checks')),
        ),
      );
      await browser.initialize();
      final tab = await browser.createTab(
        ownerSessionId: 'storage-fixture',
        url: 'kelivo://workspace/notes.app.html',
      );
      if (Platform.isAndroid &&
          (!BrowserWorkspaceApp.supportsConnectionAllowlist(
                (await InAppWebViewController.getCurrentWebViewPackage())
                    ?.versionName,
              ) ||
              !await WebViewFeature.isFeatureSupported(
                WebViewFeature.WEB_MESSAGE_LISTENER,
              ) ||
              !await WebViewFeature.isFeatureSupported(
                WebViewFeature.DOCUMENT_START_SCRIPT,
              ))) {
        await expectLater(
          browser.evaluateJavascript('1', tabId: tab.id),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'code',
              'browser_storage_bridge_unsupported',
            ),
          ),
        );
        expect(requests, 0);
        // ignore: avoid_print
        print('Validated fail-closed behavior on unsupported Android WebView.');
        return;
      }
      Object? state;
      final deadline = DateTime.now().add(const Duration(seconds: 20));
      do {
        state = await browser.evaluateJavascript(
          'JSON.stringify(window.checks)',
          tabId: tab.id,
        );
        if (state is String && state.contains('"bridge":true')) break;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      } while (DateTime.now().isBefore(deadline));
      final checks = jsonDecode(state as String) as Map;
      expect(checks['bridge'], true, reason: '$checks');
      expect(checks['fetchBlocked'], true);
      await WorkspaceAppStorage(
        root: await root.resolveSymbolicLinks(),
        directory: 'notes.app.html.data',
        authorize: (_, __) async {},
      ).write('backend.txt', 'native filesystem check', null);
      Future<Object?> evaluate(String script) =>
          browser.evaluateJavascript(script, tabId: tab.id, awaitPromise: true);
      await expectLater(
        evaluate('Promise.reject(new Error("storage-probe-failure"))'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message.toString(),
            'JavaScript error description',
            contains('storage-probe-failure'),
          ),
        ),
      );
      if (Platform.isAndroid) {
        final ordinary = await resources.scope('storage-fixture');
        try {
          await evaluate('''(() => {
            document.cookie = 'kelivoHostProbe=1; path=/';
            document.cookie = 'kelivoDomainProbe=1; Domain=kelivo.invalid; path=/';
            document.cookie = 'kelivoSuffixProbe=1; Domain=invalid; path=/';
            return true;
          })()''');
          expect(
            await evaluate("document.cookie.includes('kelivoHostProbe=1')"),
            true,
          );
          final cookies = await CookieManager.instance().getCookies(
            url: WebUri(
              ordinary
                  .internalUrl(
                    'kelivo://workspace/ordinary.html',
                    android: true,
                  )
                  .toString(),
            ),
          );
          expect(
            cookies.where(
              (c) => c.name.startsWith('kelivo') && c.name.endsWith('Probe'),
            ),
            isEmpty,
          );
        } finally {
          ordinary.close();
          await evaluate('''(() => {
            document.cookie = 'kelivoHostProbe=; Max-Age=0; path=/';
            document.cookie = 'kelivoDomainProbe=; Max-Age=0; Domain=kelivo.invalid; path=/';
            document.cookie = 'kelivoSuffixProbe=; Max-Age=0; Domain=invalid; path=/';
            return true;
          })()''');
        }
      }
      expect(
        await evaluate('''(() => {
          const original = location.href;
          history.replaceState(null, '', '/changed-path');
          const frame = document.createElement('iframe'); document.body.append(frame);
          const nested = frame.contentDocument.createElement('iframe');
          frame.contentDocument.body.append(nested);
          const result = [frame.contentWindow, nested.contentWindow].every(w => {
            if (typeof w.kelivo !== 'undefined') return false;
            const RTC = w.RTCPeerConnection || w.webkitRTCPeerConnection;
            if (!RTC) return true;
            // Chromium's initial empty document may not run injected scripts;
            // its inherited Connection-Allowlist must block the native peer.
            // The policy strips ICE servers synchronously; do not start ICE
            // or depend on a later connectionstatechange event for this probe.
            const peer = new RTC({iceServers:[{urls:'stun:127.0.0.1:9'}]});
            const blocked = peer.getConfiguration().iceServers.length === 0;
            peer.close(); return blocked;
          });
          frame.remove(); history.replaceState(null, '', original); return result;
        })()'''),
        true,
        reason:
            'Initial empty frames must not restore peer networking or the file SDK',
      );
      expect(
        await evaluate('''(async () => {
          const svg = '<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"><rect width="1" height="1"/></svg>';
          const blob = URL.createObjectURL(new Blob([svg], {type:'image/svg+xml'}));
          try {
            for (const src of ['data:image/svg+xml,' + encodeURIComponent(svg), blob]) {
              const image = new Image(); image.src = src; await image.decode();
              if (image.naturalWidth !== 1) return false;
            }
            return true;
          } finally { URL.revokeObjectURL(blob); }
        })()'''),
        true,
        reason: 'Offline applications retain embedded data/blob images',
      );
      await evaluate('''(() => {
        const target=${jsonEncode(address)};
        const icon=document.createElement('link'); icon.rel='icon'; icon.href=target+'/favicon'; document.head.append(icon);
        const download=document.createElement('a'); download.href=target+'/download'; download.download='probe.txt'; download.click();
        const form=document.createElement('form'); form.action=target+'/form'; form.method='POST'; document.body.append(form); form.submit();
        window.open(target+'/popup');
        try { navigator.sendBeacon(target+'/beacon','probe'); } catch (_) {}
        return true;
      })()''');
      expect(await evaluate('location.protocol'), isNot('chrome-error:'));
      final saved = await evaluate('''(async () => {
        const initial = await kelivo.readJson('state.json', {count:0});
        await kelivo.saveJson('state.json', {count:initial.count+1});
        return JSON.stringify(await kelivo.readJson('state.json'));
      })()''');
      expect(saved, '{"count":1}');
      expect(
        await File(
          '${root.path}/notes.app.html.data/state.json',
        ).readAsString(),
        '{"count":1}',
      );
      // A valid 2 MiB text file may expand beyond 3 MiB in bridge JSON.
      expect(
        await evaluate(
          "(async()=>{const text='\\n'.repeat(2097152);await kelivo.writeFile('large.txt',text,null);return (await kelivo.readFile('large.txt')).content.length;})()",
        ),
        2097152,
      );
      final beforeBurst = writeChecks;
      // Exercise the real headless -> visible -> retained transfer; message
      // listeners must survive the widget controller's disposal/handoff.
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: browser.buildView(tab.id))),
      );
      final presentationDeadline = DateTime.now().add(
        const Duration(seconds: 10),
      );
      while (!browser.isTabPresented(tab.id) &&
          DateTime.now().isBefore(presentationDeadline)) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(browser.isTabPresented(tab.id), true);
      await evaluate('''(async () => {
        const saves=[];for(let i=0;i<100;i++) saves.push(kelivo.saveJson('state.json',{count:i}));
        await Promise.all(saves);
      })()''');
      expect(
        writeChecks - beforeBurst,
        2,
        reason: 'One staged write, authorized twice',
      );
      expect(
        await File(
          '${root.path}/notes.app.html.data/state.json',
        ).readAsString(),
        '{"count":99}',
      );
      // A slow filesystem must retain only the latest waiting snapshot, even
      // when more inputs arrive across several separate debounce windows.
      final beforeSlow = writeChecks;
      writeGate = Completer<void>();
      await evaluate('''(() => {
        window.slowSaves = [kelivo.saveJson('state.json', {count:300})];
        return true;
      })()''');
      final slowDeadline = DateTime.now().add(const Duration(seconds: 10));
      while (writeChecks == beforeSlow &&
          DateTime.now().isBefore(slowDeadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(writeChecks, beforeSlow + 1);
      for (var i = 301; i <= 305; i++) {
        await evaluate('''(() => {
          slowSaves.push(kelivo.saveJson('state.json', {count:$i}));
          return true;
        })()''');
        await Future<void>.delayed(const Duration(milliseconds: 350));
      }
      expect(writeChecks, beforeSlow + 1);
      writeGate.complete();
      await evaluate('Promise.all(slowSaves).then(() => true)');
      writeGate = null;
      expect(
        writeChecks - beforeSlow,
        4,
        reason: 'First and latest snapshots only',
      );
      expect(
        await evaluate("kelivo.readJson('state.json').then(JSON.stringify)"),
        '{"count":305}',
      );
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Retained browser check'))),
      );
      expect(
        await evaluate("kelivo.readJson('state.json').then(JSON.stringify)"),
        '{"count":305}',
      );
      writesAllowed = false;
      expect(
        await evaluate(
          "kelivo.saveJson('state.json',{count:100}).then(()=>'',e=>e.message)",
        ),
        'tool_disabled',
      );
      writesAllowed = true;
      await File(
        '${root.path}/notes.app.html.data/state.json',
      ).writeAsString('{"count":200}');
      // Failed save requires an explicit reread; the wrapper never adopts a
      // fresh version to overwrite data it has not actually loaded.
      expect(
        await evaluate(
          "kelivo.saveJson('state.json',{}).then(()=>'',e=>e.message)",
        ),
        'storage_read_required',
      );
      expect(
        await evaluate(
          "kelivo.readFile('../secret.json').then(()=>'',e=>e.message)",
        ),
        'storage_invalid_path',
      );
      await browser.reload(tabId: tab.id);
      await browser.waitForLoad(tabId: tab.id);
      await evaluate('window.appInitialized');
      expect(await evaluate('window.checks.bridge'), true);
      expect(
        await evaluate("kelivo.readJson('state.json').then(JSON.stringify)"),
        '{"count":200}',
      );
      expect(
        await browser.evaluateJavascript(
          'typeof RTCPeerConnection',
          tabId: tab.id,
        ),
        'undefined',
      );
      await browser.evaluateJavascript(
        'location.href=${jsonEncode('$address/navigation')}',
        tabId: tab.id,
      );
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(requests, 0);
      expect(await evaluate('typeof kelivo'), 'object');
      expect(browser.tabs.single.url, 'kelivo://workspace/notes.app.html');
      if (const bool.fromEnvironment('KELIVO_STORAGE_PERF')) {
        await _measureStorage(evaluate);
      }
      final previousDocument =
          await evaluate('window.__kelivoStorageDocument') as String;
      // Explicit human navigation leaves the restricted document. It must not
      // inherit its SDK or permissions, even though the native view is reused.
      await browser.navigate(address, tabId: tab.id);
      await browser.waitForLoad(tabId: tab.id);
      expect(
        await browser.evaluateJavascript('typeof kelivo', tabId: tab.id),
        'undefined',
      );
      expect(await evaluate('typeof RTCPeerConnection'), 'function');
      // Simulate an old native reply arriving after navigation. An external
      // page's forged handler must never receive its data, regardless of
      // whether that handler checks the document token itself.
      await evaluate('''(() => { window.receivedStorageReply = false;
        window.__kelivoStorageReply = () => window.receivedStorageReply = true;
        window.__kelivoStorageDocument = 'different-document'; })()''');
      await evaluate(
        '(() => { ${browserStorageReplyScript(previousDocument, jsonEncode({'document': previousDocument, 'result': 'private'}))} })()',
      );
      expect(await evaluate('window.receivedStorageReply'), false);
      await browser.back(tabId: tab.id);
      await browser.waitForLoad(tabId: tab.id);
      await evaluate('window.appInitialized');
      expect(await evaluate('window.checks.bridge'), true);
      expect(
        await evaluate("kelivo.readJson('state.json').then(JSON.stringify)"),
        '{"count":200}',
      );
    } finally {
      browser.dispose();
      if (writeGate != null && !writeGate.isCompleted) writeGate.complete();
      resources.rootForSession = oldRoot;
      resources.authorizeData = oldAccess;
      await tester.pumpWidget(const SizedBox.shrink());
      await server.close(force: true);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await root.delete(recursive: true);
    }
  });
}
