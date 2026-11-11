import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:Kelivo/features/intelligent_ui/host/ui_web_controller.dart';
import 'package:Kelivo/features/intelligent_ui/host/ui_web_document.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'support/genui_data_font.dart';
import 'support/genui_web_navigation_audit.dart';

/// Real engine acceptance, separate from G. Only synthetic local endpoints and
/// storage are used. The observer exists solely in this integration executable;
/// production markup contains no observer, message handler or application bridge.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Flutter 3.47.6 TestPlatformDispatcher does not forward onHitTest. Without
  // the production GestureBinding algorithm below, UIKit sees no native view
  // even though Dart receives pointer events. Keep this in the test executable;
  // never bypass the actual render tree or alter production gesture policy.
  final dispatcher = ui.PlatformDispatcher.instance;
  final originalHitTest = dispatcher.onHitTest;
  dispatcher.onHitTest = (request) {
    final result = HitTestResult();
    binding.hitTestInView(result, request.offset, request.view.viewId);
    return ui.HitTestResponse(
      hasPlatformView: result.path.any((e) => e.target is NativeHitTestTarget),
    );
  };
  tearDownAll(() => dispatcher.onHitTest = originalHitTest);
  binding.shouldPropagateDevicePointerEvents = true;
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  // Native accessibility automation may enable semantics midway through a
  // test. Establish that binding-owned handle before leak baselines are taken.
  if (Platform.isMacOS) {
    binding.platformDispatcher.semanticsEnabledTestValue = true;
    tearDownAll(binding.platformDispatcher.clearSemanticsEnabledTestValue);
  }
  testWidgets('native generated-document sandbox and teardown', (tester) async {
    // ignore: avoid_print
    print(
      'GENUI_WEB_PROCESS ${jsonEncode({'pid': pid, 'platform': Platform.operatingSystem})}',
    );
    // The Android cached engine can start before its Activity is visible.
    final visibleDeadline = DateTime.now().add(const Duration(seconds: 30));
    while (tester.view.physicalSize.isEmpty &&
        DateTime.now().isBefore(visibleDeadline)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.view.physicalSize.isEmpty, isFalse);
    final navigations = <Map<String, Object?>>[];
    WebViewPlatform.instance = Platform.isAndroid
        ? GenUiAuditedAndroid(navigations)
        : GenUiAuditedWebKit(navigations);
    final requests = <String>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final sockets = <Socket>[];
    final tls = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final tlsSubscription = tls.listen((socket) {
      sockets.add(socket);
      socket.destroy();
    });
    final origin = 'http://127.0.0.1:${server.port}';
    final secure = 'https://127.0.0.1:${tls.port}';
    final nonce = DateTime.now().microsecondsSinceEpoch.toString();
    final storageKey = 'genui_test_$nonce';
    final temporary = await Directory.systemTemp.createTemp('genui-web-');
    final localFile = File('${temporary.path}/probe.html');
    final authorityFile = localFile.uri.replace(host: 'localhost');
    await localFile.writeAsString(
      '''<!doctype html><title>Unexecuted canary</title><script>
      document.title='SYNTHETIC_FILE_$nonce';
      parent.postMessage({nonce:'$nonce',results:{fileCanary:true}},'*');
      </script>''',
    );
    server.listen((request) async {
      requests.add(request.uri.path);
      request.response.headers.set('Access-Control-Allow-Origin', '*');
      if (request.uri.path.endsWith('/redirect')) {
        request.response.statusCode = HttpStatus.found;
        request.response.headers.set('Location', '$origin/probe/redirect-end');
      } else {
        request.response.headers.contentType = ContentType.html;
        request.response.write(
          '<!doctype html><title>ordinary-control-${request.uri.query}</title>',
        );
      }
      await request.response.close();
    });
    addTearDown(() async {
      await server.close(force: true);
      await tlsSubscription.cancel();
      await tls.close();
      await temporary.delete(recursive: true);
    });

    Future<void> until(
      Future<bool> Function() condition,
      String reason, {
      int seconds = 12,
    }) async {
      final deadline = DateTime.now().add(Duration(seconds: seconds));
      while (DateTime.now().isBefore(deadline)) {
        if (await condition()) return;
        await tester.pump(const Duration(milliseconds: 100));
      }
      fail(reason);
    }

    Future<void> mount(Widget child) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SafeArea(child: child)),
      ),
    );
    final ordinary = WebViewController();
    await ordinary.setJavaScriptMode(JavaScriptMode.unrestricted);
    await mount(WebViewWidget(controller: ordinary));
    await ordinary.loadFile(localFile.path);
    await until(
      () async => await ordinary.getTitle() == 'SYNTHETIC_FILE_$nonce',
      'File canary must execute in its ordinary positive control',
    );
    await ordinary.runJavaScript(
      'document.title="Before file authority control"',
    );
    await ordinary.loadRequest(authorityFile);
    await until(
      () async => await ordinary.getTitle() == 'SYNTHETIC_FILE_$nonce',
      'The localhost file-authority target must execute the same canary',
    );
    await ordinary.loadRequest(Uri.parse('$origin/control?first'));
    await until(
      () async => await ordinary.getTitle() == 'ordinary-control-first',
      'Ordinary HTTP control must reach the same endpoint',
    );
    expect(requests, contains('/control'));
    await ordinary.runJavaScript('''
      localStorage.setItem('$storageKey','ordinary-secret');
      sessionStorage.setItem('$storageKey','ordinary-session');
      document.cookie='$storageKey=ordinary-cookie; path=/';
    ''');
    await ordinary.loadRequest(Uri.parse('$secure/control'));
    await until(() async => sockets.isNotEmpty, 'TLS control must connect');
    await ordinary.loadRequest(Uri.parse('$origin/control?recovered'));
    await until(
      () async => await ordinary.getTitle() == 'ordinary-control-recovered',
      'Ordinary control did not recover',
    );
    final tlsBaseline = sockets.length;
    final reports = <Map<String, Object?>>[];

    Future<Map<String, dynamic>> run(
      String name,
      String code, {
      String markup = '',
      Duration settle = const Duration(milliseconds: 650),
      bool trustedGesture = false,
    }) async {
      final controller = UiWebController();
      final html =
          '''<!doctype html><html><head>
        <meta http-equiv="Content-Security-Policy" content="default-src * data: blob: 'unsafe-inline' 'unsafe-eval'">
        <style>body{background:rgb(12,34,56)}</style></head><body>$markup
        <script>
        const results={};
        const nonce='$nonce';
        const report=()=>parent.postMessage({nonce:'$nonce',results},'*');
        const base=${jsonEncode('$origin/probe')};
        const secure=${jsonEncode('$secure/probe')};
        const localFile=${jsonEncode(localFile.uri.toString())};
        const authorityFile=${jsonEncode(authorityFile.toString())};
        const testScheme=${jsonEncode(Platform.isIOS ? 'kelivo-genui-test' : 'kelivo')};
        const fontUrl=${jsonEncode('data:font/woff2;base64,$genUiDataFont')};
        const attempt=(key,fn)=>{try{results[key]=fn()}catch(e){results[key]=e.name}};
        const execute=async(e)=>{try{
          if($trustedGesture){results.trusted=e.isTrusted;results.active=navigator.userActivation.isActive;results.finished=true;report()}
          $code; results.finished=true; report();
        }catch(e){
          results.failure=String(e); results.finished=true; report();
        }};
        if($trustedGesture){
          document.body.style.cssText='margin:0;background:white';
          const button=document.createElement('button');button.textContent=${jsonEncode('Run $name')};
          button.style.cssText='width:100%;height:90vh;font:24px system-ui';
          button.onclick=execute;document.body.append(button);results.ready=true;report();
          button.addEventListener('pointerdown',e=>{results.pointerDown=e.isTrusted;report()});
          button.addEventListener('pointerup',e=>{results.pointerUp=e.isTrusted;report()});
        }else execute(null);
        setInterval(()=>{results.tick=(results.tick||0)+1;report()},80);
        </script></body></html>''';
      final observer =
          '''<script>
        const observed={};
        addEventListener('securitypolicyviolation',e=>{
          const blocks=observed.cspBlocks||(observed.cspBlocks=[]);
          if(blocks.length<40) blocks.push({uri:e.blockedURI,directive:e.effectiveDirective,disposition:e.disposition});
          document.title='GENUI:'+JSON.stringify(observed);
        });
        addEventListener('message',e=>{
          if(e.data && e.data.nonce==='$nonce') {
            Object.assign(observed,e.data.results);
            document.title='GENUI:'+JSON.stringify(observed);
          }
        });
        </script>''';
      final trusted = UiWebSandbox.wrap(
        html,
      ).replaceFirst('</head>', '$observer</head>');
      final before = requests.length;
      final navigationStart = navigations.length;
      await mount(
        ListenableBuilder(
          listenable: controller,
          builder: (_, _) => controller.buildView(),
        ),
      );
      await controller.loadTrustedDocument(trusted);
      Map<String, dynamic> result = {};
      Future<bool> updateResult() async {
        final title = await controller.nativeTitle();
        if (title != null && title.startsWith('GENUI:')) {
          result = jsonDecode(title.substring(6)) as Map<String, dynamic>;
        }
        return result['finished'] == true;
      }

      try {
        if (trustedGesture) {
          await until(() async {
            await updateResult();
            return result['ready'] == true;
          }, '$name: gesture control did not appear');
          await tester.pump();
          if (Platform.isAndroid) {
            await tester.tapAt(tester.getCenter(find.byType(WebViewWidget)));
            await tester.pump(const Duration(milliseconds: 250));
          }
          if (!await updateResult()) {
            // Desktop AppKit and iOS platform views may require native input.
            // A CUA/XCTest operator taps this synthetic button; no JS click is
            // accepted as evidence. The event's trusted/activation bits prove it.
            // ignore: avoid_print
            print(
              'GENUI_WEB_NATIVE_TAP ${jsonEncode({'case': name, 'label': 'Run $name'})}',
            );
          }
        }
        await until(
          updateResult,
          '$name: child inline script or parent CSP/srcdoc did not run',
          seconds: trustedGesture ? 90 : 12,
        );
        await tester.pump(settle);
        final lastTitle = await controller.nativeTitle();
        if (lastTitle != null && lastTitle.startsWith('GENUI:')) {
          result = jsonDecode(lastTitle.substring(6)) as Map<String, dynamic>;
        }
        if (trustedGesture) {
          expect(result['trusted'], isTrue);
          expect(result['active'], isTrue);
        }
        final native = controller.nativeController!;
        await controller.close();
        if (controller.closeError != null) {
          // Synthetic diagnostics distinguish failed teardown from a missed
          // completion callback. Never inspect a user's browsing controller.
          // ignore: avoid_print
          print(
            'GENUI_WEB_CLOSE ${jsonEncode({'case': name, 'error': controller.closeError.toString(), 'title': await native.getTitle()})}',
          );
        }
        expect(controller.closeError, isNull, reason: '$name: teardown');
        expect(await native.getTitle(), UiWebSandbox.closedTitle);
        await tester.pump(const Duration(milliseconds: 250));
        expect(await native.getTitle(), UiWebSandbox.closedTitle);
      } catch (failure) {
        // ignore: avoid_print
        print(
          'GENUI_WEB_FAILURE ${jsonEncode({'case': name, 'result': result})}',
        );
        rethrow;
      } finally {
        await controller.close();
        await mount(const SizedBox());
        controller.dispose();
      }
      final outbound = requests.skip(before).toList();
      final record = <String, Object?>{
        'name': name,
        'result': result,
        'requests': outbound,
        'navigation': navigations.skip(navigationStart).toList(),
      };
      reports.add(record);
      // ignore: avoid_print
      print('GENUI_WEB_CASE ${jsonEncode(record)}');
      return result;
    }

    final normal = await run('inline-data', r'''
      results.style=getComputedStyle(document.body).backgroundColor;
      const img=new Image();
      const ready=new Promise(resolve=>{img.onload=()=>resolve(true);img.onerror=()=>resolve(false)});
      img.src='data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7';
      document.body.append(img);results.image=await ready;
      const font=new FontFace('LocalProbe','url('+fontUrl+')');
      await font.load();document.fonts.add(font);results.font=font.status;
      results.inline=2+3;
      attempt('parent',()=>parent.document.body.innerHTML);
      attempt('cookie',()=>{document.cookie='preview_cookie=probe';return document.cookie});
      attempt('localStorage',()=>localStorage.getItem('example'));
      attempt('sessionStorage',()=>sessionStorage.getItem('example'));
      attempt('indexedDB',()=>{indexedDB.open('example');return 'opened'});
      try {await caches.open('example');results.cache='opened'} catch(e){results.cache=e.name}
    ''');
    expect(normal['inline'], 5);
    expect(normal['style'], 'rgb(12, 34, 56)');
    expect(normal['image'], isTrue);
    expect(normal['font'], 'loaded');
    for (final key in [
      'parent',
      'localStorage',
      'sessionStorage',
      'indexedDB',
    ]) {
      expect(normal[key], 'SecurityError', reason: key);
    }
    expect(normal['cookie'], anyOf('', 'SecurityError'));
    expect(normal['cache'], anyOf('SecurityError', 'ReferenceError'));

    await run('external-resources', r'''
      for(const scheme of [base,secure]){
        const img=new Image();img.src=scheme+'/image';document.body.append(img);
        const script=document.createElement('script');script.src=scheme+'/script';document.body.append(script);
        const css=document.createElement('link');css.rel='stylesheet';css.href=scheme+'/style';document.head.append(css);
        fetch(scheme+'/fetch').catch(()=>{});
        attempt('xhr',()=>{const x=new XMLHttpRequest();x.open('GET',scheme+'/xhr');x.send();return 'attempted'});
        attempt('worker',()=>{new Worker(scheme+'/worker');return 'created'});
        attempt('socket',()=>{new WebSocket(scheme.replace(/^http/,'ws')+'/socket');return 'created'});
        const frame=document.createElement('iframe');frame.src=scheme+'/frame';document.body.append(frame);
        const font=new FontFace('remote','url('+scheme+'/font)');font.load().catch(()=>{});
        const obj=document.createElement('object');obj.data=scheme+'/object';document.body.append(obj);
      }
    ''');
    final nested = await run('nested-srcdoc', r'''
      const nested=document.createElement('iframe');
      nested.sandbox='allow-scripts allow-same-origin';
      nested.srcdoc=`<meta http-equiv="Content-Security-Policy" content="default-src * 'unsafe-inline'"><script>const r={nestedStarted:true};try{r.nestedStorage=localStorage.length}catch(e){r.nestedStorage=e.name}parent.parent.postMessage({nonce:${JSON.stringify(nonce)},results:r},"*");fetch(${JSON.stringify(base+'/nested-fetch')}).catch(()=>{});const i=new Image();i.src=${JSON.stringify(base+'/nested-image')};<\/script>`;
      document.body.append(nested);
    ''');
    expect(nested['nestedStarted'], isTrue);
    expect(nested['nestedStorage'], 'SecurityError');
    await run('remove-child-policy', r'''
      document.querySelectorAll('meta[http-equiv="Content-Security-Policy"]').forEach(m=>m.remove());
      fetch(base+'/removed-csp-fetch').catch(()=>{});
      const i=new Image();i.src=base+'/removed-csp-image';document.body.append(i);
    ''');
    void expectProtocolRejected(Map<String, dynamic> result) {
      final scheme = Platform.isIOS ? 'kelivo-genui-test' : 'kelivo';
      final nativeDenied = (reports.last['navigation'] as List)
          .cast<Map<String, Object?>>()
          .any(
            (event) =>
                (event['url'] as String).startsWith('$scheme:') &&
                event['decision'] == 'prevent',
          );
      final blocks = (result['cspBlocks'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .toList();
      // Engines redact non-fetch targets differently: WebKit reports "null",
      // Chromium reports an empty URI. This fresh context attempts exactly one
      // navigation; require exactly one enforcing frame-src event for it.
      final redacted = Platform.isAndroid ? '' : 'null';
      final cspDenied =
          blocks.length == 1 &&
          blocks.single['directive'] == 'frame-src' &&
          blocks.single['disposition'] == 'enforce' &&
          ((blocks.single['uri'] as String).startsWith('$scheme:') ||
              blocks.single['uri'] == redacted);
      expect(
        nativeDenied || cspDenied,
        isTrue,
        reason:
            'The isolated protocol probe needs a specific enforcing rejection',
      );
    }

    for (final entry in <String, String>{
      'location': 'location.href=base+"/location";',
      'link':
          'const a=document.createElement("a");a.href=base+"/link";document.body.append(a);a.click();',
      'meta':
          'const m=document.createElement("meta");m.httpEquiv="refresh";m.content="0;url="+base+"/meta";document.head.append(m);',
      'redirect': 'location.href=base+"/redirect";',
      'top-navigation':
          'attempt("top",()=>{top.location.href=base+"/top";return "allowed"});',
      'form':
          'const f=document.createElement("form");f.action=base+"/form";document.body.append(f);f.submit();',
      'popup': 'results.popup=window.open(base+"/popup")==null;',
      'download':
          'const a=document.createElement("a");a.href=base+"/download";a.download="probe.txt";document.body.append(a);a.click();',
      'nested-location':
          r'''const f=document.createElement('iframe');f.srcdoc='<script>parent.parent.postMessage('+JSON.stringify({nonce,results:{nestedNavigationStarted:true}})+',"*");location.href='+JSON.stringify(base+'/nested-location')+';<\/script>';document.body.append(f);''',
      'file-navigation': 'location.href=localFile;',
      'file-authority-navigation': 'location.href=authorityFile;',
      'external-scheme': 'location.href=testScheme+"://genui-sandbox-probe";',
    }.entries) {
      final result = await run(
        entry.key,
        'results.attempted=true; results.finished=true; report(); ${entry.value}',
      );
      if (entry.key == 'nested-location') {
        expect(result['nestedNavigationStarted'], isTrue);
      }
      if (entry.key == 'file-navigation' ||
          entry.key == 'file-authority-navigation') {
        expect(
          result['fileCanary'],
          isNull,
          reason: 'A file navigation loaded the executable canary',
        );
      }
      if (entry.key == 'external-scheme') expectProtocolRejected(result);
    }
    for (final gesture in <String, String>{
      'gesture-link': 'location.href=base+"/gesture-link";',
      'gesture-popup':
          'results.popup=window.open(base+"/gesture-popup")==null;',
      'gesture-download':
          'const a=document.createElement("a");a.href=base+"/gesture-download";a.download="probe.txt";document.body.append(a);a.click();',
      'gesture-file': 'location.href=localFile;',
      'gesture-protocol': 'location.href=testScheme+"://genui-sandbox-probe";',
    }.entries) {
      final result = await run(
        gesture.key,
        gesture.value,
        trustedGesture: true,
      );
      expect(result['fileCanary'], isNull);
      if (gesture.key == 'gesture-popup') expect(result['popup'], isTrue);
      if (gesture.key == 'gesture-protocol') expectProtocolRejected(result);
    }
    final capabilities = await run('files-and-permissions', r'''
      try{results.file=await (await fetch(localFile)).text()}catch(e){results.file=e.name}
      if(navigator.mediaDevices){
        try{const s=await navigator.mediaDevices.getUserMedia({audio:true,video:true});s.getTracks().forEach(t=>t.stop());results.media='granted'}catch(e){results.media=e.name}
      }else results.media='unavailable';
      if(navigator.geolocation){
        results.location=await new Promise(resolve=>navigator.geolocation.getCurrentPosition(()=>resolve('granted'),e=>resolve('denied:'+e.code),{timeout:1500}));
      }else results.location='unavailable';
    ''');
    expect(capabilities['file'], anyOf('TypeError', 'SecurityError'));
    expect(
      capabilities['media'],
      anyOf('unavailable', 'NotAllowedError', 'SecurityError'),
    );
    expect(capabilities['location'], anyOf('unavailable', 'denied:1'));
    final second = await run('new-preview-storage', '''
      attempt('cookie',()=>document.cookie);
      attempt('localStorage',()=>localStorage.getItem('$storageKey'));
      attempt('sessionStorage',()=>sessionStorage.getItem('$storageKey'));
    ''');
    expect(second['cookie'], anyOf('', 'SecurityError'));
    expect(second['localStorage'], 'SecurityError');
    expect(second['sessionStorage'], 'SecurityError');

    for (var i = 0; i < 3; i++) {
      final loading = UiWebController();
      final starting = loading.loadTrustedDocument(
        UiWebSandbox.wrap('<p>Closed during initialization</p>'),
      );
      final closing = loading.close();
      await starting;
      await closing;
      expect(loading.closeError, isNull);
      expect(loading.phase, UiWebNativePhase.closed);
      loading.dispose();
    }

    await mount(WebViewWidget(controller: ordinary));
    await ordinary.loadRequest(Uri.parse('$origin/control?final'));
    await until(
      () async => await ordinary.getTitle() == 'ordinary-control-final',
      'Ordinary page must still load after previews',
    );
    expect(
      await ordinary.runJavaScriptReturningResult(
        'localStorage.getItem("$storageKey")',
      ),
      contains('ordinary-secret'),
    );
    // Remove only this run's synthetic key, never clear a shared profile.
    await ordinary.runJavaScript('''
      localStorage.removeItem('$storageKey');sessionStorage.removeItem('$storageKey');
      document.cookie='$storageKey=; Max-Age=0; path=/';
    ''');
    await ordinary.loadHtmlString(UiWebSandbox.emptyDocument);
    await mount(const SizedBox());
    final outbound = requests
        .where((path) => path.startsWith('/probe/'))
        .toList();
    binding.reportData = {
      'platform': Platform.operatingSystem,
      'cases': reports,
      'httpOutbound': outbound,
      'tlsOutbound': sockets.length - tlsBaseline,
    };
    // ignore: avoid_print
    print('GENUI_WEB_RESULT ${jsonEncode(binding.reportData)}');
    expect(outbound, isEmpty, reason: 'Controlled endpoint observed an escape');
    expect(
      sockets.length,
      tlsBaseline,
      reason: 'TLS endpoint observed an escape',
    );
  }, timeout: const Timeout(Duration(minutes: 8)));
}
