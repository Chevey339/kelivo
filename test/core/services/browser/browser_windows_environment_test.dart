import 'dart:async';
import 'dart:io';

import 'package:Kelivo/core/services/browser/browser_windows_environment.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
// Verify the actual Windows method-channel implementation on every test host.
// ignore: depend_on_referenced_packages
import 'package:flutter_inappwebview_windows/flutter_inappwebview_windows.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(
    'com.pichillilorenzo/flutter_webview_environment',
  );
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory root;
  late BrowserWindowsEnvironment owner;
  InAppWebViewPlatform? previous;
  final calls = <MethodCall>[];
  final failure = PlatformException(
    code: '0x80070005',
    message:
        'CreateCoreWebView2EnvironmentWithOptions failed (0x80070005): Access is denied.',
    details: {
      'stage': 'CreateCoreWebView2EnvironmentWithOptions',
      'hresult': -2147024891,
    },
  );

  setUp(() async {
    previous = InAppWebViewPlatform.instance;
    InAppWebViewPlatform.instance = WindowsInAppWebViewPlatform();
    root = await Directory.systemTemp.createTemp('browser-profile-');
    owner = BrowserWindowsEnvironment(dataDirectory: () async => root);
    calls.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(channel, null);
    if (previous != null) InAppWebViewPlatform.instance = previous;
    await root.delete(recursive: true);
  });

  test(
    'concurrent tabs share a profile under the selected data root',
    () async {
      final gate = Completer<void>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        final settings = call.arguments['settings'] as Map;
        expect(
          settings['userDataFolder'],
          p.join(root.path, 'browser', 'webview2'),
        );
        expect(
          await Directory(settings['userDataFolder'] as String).exists(),
          isTrue,
        );
        await gate.future;
        return true;
      });
      final first = owner.get();
      final second = owner.get();
      expect(identical(first, second), isTrue);
      gate.complete();
      final environments = await Future.wait([first, second]);
      expect(environments[0], same(environments[1]));
      expect(await owner.get(), same(environments[0]));
      expect(calls, hasLength(1));
    },
  );

  test(
    'native creation errors retain HRESULT and allow a later retry',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (calls.length == 1) throw failure;
        return true;
      });
      await expectLater(
        owner.get(),
        throwsA(
          isA<PlatformException>()
              .having((e) => e.code, 'HRESULT', failure.code)
              .having(
                (e) => e.message,
                'stage and native message',
                failure.message,
              )
              .having((e) => e.details, 'details', failure.details),
        ),
      );
      expect(await owner.get(), isA<WebViewEnvironment>());
      expect(calls, hasLength(2));
    },
  );

  test(
    'directory creation failure never falls back to the executable directory',
    () async {
      final obstruction = File(p.join(root.path, 'browser'));
      await obstruction.writeAsString('not a directory');
      await expectLater(owner.get(), throwsA(isA<FileSystemException>()));
      expect(calls, isEmpty);
      await obstruction.delete();
      await owner.get();
      expect(calls, hasLength(1));
    },
  );

  test(
    'cookie queries and environment disposal address the created environment',
    () async {
      final environment = await owner.get();
      final id = calls.single.arguments['id'];
      expect(environment.id, id);
      final disposal = MethodChannel(
        'com.pichillilorenzo/flutter_webview_environment_$id',
      );
      const cookies = MethodChannel(
        'com.pichillilorenzo/flutter_inappwebview_cookiemanager',
      );
      var disposed = false;
      messenger.setMockMethodCallHandler(disposal, (call) async {
        expect(call.method, 'dispose');
        disposed = true;
        return true;
      });
      messenger.setMockMethodCallHandler(cookies, (call) async {
        expect(call.method, 'getCookies');
        expect(call.arguments['webViewEnvironmentId'], id);
        return <Object?>[];
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(disposal, null);
        messenger.setMockMethodCallHandler(cookies, null);
      });
      expect(
        await CookieManager.instance(
          webViewEnvironment: environment,
        ).getCookies(url: WebUri('https://example.com')),
        isEmpty,
      );
      await environment.dispose();
      expect(disposed, isTrue);
    },
  );

  test('headless initialization returns the native error unchanged', () async {
    const headless = MethodChannel(
      'com.pichillilorenzo/flutter_headless_inappwebview',
    );
    messenger.setMockMethodCallHandler(headless, (_) async => throw failure);
    addTearDown(() => messenger.setMockMethodCallHandler(headless, null));
    final view = HeadlessInAppWebView(webViewEnvironment: await owner.get());
    await expectLater(
      view.run(),
      throwsA(
        isA<PlatformException>()
            .having((e) => e.code, 'HRESULT', failure.code)
            .having((e) => e.message, 'native message', failure.message)
            .having((e) => e.details, 'details', failure.details),
      ),
    );
    expect(view.isRunning(), isFalse);
    await view.dispose();
  });
}
