import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:Kelivo/core/services/browser/browser_favicon_loader.dart';
import 'package:Kelivo/core/services/browser/browser_service.dart';
import 'package:Kelivo/core/services/browser/browser_native_engine.dart';
import 'package:Kelivo/features/browser/models/browser_models.dart';
import 'package:Kelivo/core/services/browser/browser_store.dart';
import 'package:Kelivo/core/services/browser/browser_engine.dart';
import 'package:Kelivo/core/services/browser/browser_scroll_observer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
// Exercise the Windows implementation resolved by flutter_inappwebview itself.
// ignore: depend_on_referenced_packages
import 'package:flutter_inappwebview_windows/flutter_inappwebview_windows.dart';

const _androidDataUrl = 'data:text/html;charset=utf-8;base64,';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _BrowserPlatform platform;
  late BrowserService service;
  late _MemoryStore store;
  InAppWebViewPlatform? previousPlatform;

  setUp(() {
    _CookieManager.cookies = [];
    previousPlatform = InAppWebViewPlatform.instance;
    platform = _BrowserPlatform();
    InAppWebViewPlatform.instance = platform;
    store = _MemoryStore();
    service = BrowserService(store: store, supported: true);
  });

  tearDown(() async {
    service.dispose();
    await Future<void>.delayed(Duration.zero);
    if (previousPlatform != null) {
      InAppWebViewPlatform.instance = previousPlatform;
    }
  });

  Future<void> evict(String tabId) async {
    for (var index = 0; index < BrowserService.maxLiveViews; index++) {
      final other = await service.createTab(url: 'https://other$index.example');
      await service.evaluateJavascript('1', tabId: other.id);
    }
    await service.selectTab(tabId);
  }

  const faviconPng =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==';

  test(
    'Windows opens a page without the unsupported native find factory',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      platform.useWindowsFindFactory = true;
      final engine = await NativeBrowserEngine.create(
        tab: const BrowserTab(id: 'windows', url: 'https://example.com'),
        settings: const BrowserSettings(),
        onChanged: (_) {},
        onDownload: (_, __) {},
        onNewWindow: (_, __) async => false,
        isAgentActive: () => false,
      );
      try {
        final native = platform.views.single;
        expect(native.params.findInteractionController, isNull);
        await native.start('https://example.com');
        await native.stop('https://example.com');
        await engine.waitForLoad(const Duration(seconds: 1));
        const query = 'a"b\\c\n';
        await engine.find(query);
        expect(
          native.document.evaluations.last,
          'window.find(${jsonEncode(query)}, false, false, true)',
        );
        await engine.findNext(false);
        expect(
          native.document.evaluations.last,
          'window.find(${jsonEncode(query)}, false, true, true)',
        );
        await engine.clearFind();
        final afterClear = native.document.evaluations.length;
        await engine.findNext(true);
        expect(native.document.evaluations.length, afterClear);
      } finally {
        await engine.dispose();
      }
    },
  );

  for (final doubleSequence in [false, true]) {
    for (final sameUrl in [true, false]) {
      test(
        'same-document back/forward settles loading (same URL: $sameUrl, Float64: $doubleSequence)',
        () async {
          const url = 'https://history.example/spa';
          final tab = await service.createTab(url: url);
          await service.evaluateJavascript('1', tabId: tab.id);
          final native = platform.views.single;
          native.document.doubleHistoryNumbers = doubleSequence;
          await native.start(url);
          native.document.historyIndex = 1;
          native.document.historyLength = 2;
          await native.stop(url);
          for (final forward in [false, true]) {
            var loaded = false;
            await (forward
                ? service.forward(tabId: tab.id)
                : service.back(tabId: tab.id));
            final wait = service
                .waitForLoad(tabId: tab.id, timeout: const Duration(seconds: 1))
                .then((_) => loaded = true);
            native.document.historyIndex = forward ? 1 : 0;
            // KVO/list movement can precede the actual document's popstate event.
            await native.history(sameUrl ? url : '$url#${forward ? 1 : 0}');
            expect(loaded, isFalse);
            native.document.historyTraversal++;
            await native.document.handlers[browserHistoryHandlerName]!([]);
            await wait;
            expect(loaded, isTrue);
            expect(service.requireTab(tab.id).isLoading, isFalse);
          }
        },
      );
    }
  }
  test(
    'a different document history event still waits for native load-stop',
    () async {
      const url = 'https://history.example/previous';
      final tab = await service.createTab(url: url);
      await service.evaluateJavascript('1', tabId: tab.id);
      final native = platform.views.single;
      await native.start(url);
      native.document.historyIndex = 1;
      native.document.historyLength = 2;
      await native.stop(url);
      await service.back(tabId: tab.id);
      var loaded = false;
      final wait = service
          .waitForLoad(tabId: tab.id)
          .then((_) => loaded = true);
      native.document.historyIndex = 0;
      native.document.documentId = 'different-document';
      native.document.historyTraversal++;
      await native.start('https://history.example/new');
      await native.document.handlers[browserHistoryHandlerName]!([]);
      expect(loaded, isFalse);
      await native.stop('https://history.example/new');
      await wait;
      expect(loaded, isTrue);
    },
  );

  test(
    'page commit refreshes forward availability before load completes',
    () async {
      const url = 'https://history.example/previous';
      final tab = await service.createTab(url: url);
      await service.evaluateJavascript('1', tabId: tab.id);
      final native = platform.views.single;
      await native.start(url);
      // WebKit can deliver URL KVO before the back/forward list has changed.
      await native.history(url);
      expect(service.requireTab(tab.id).canGoForward, isFalse);
      native.document.canGoForward = true;
      await native.commit(url);
      expect(service.requireTab(tab.id).canGoForward, isTrue);
      expect(service.requireTab(tab.id).isLoading, isTrue);
    },
  );

  test(
    'back and forward refresh history without a full document load',
    () async {
      const url = 'https://history.example/page';
      final tab = await service.createTab(url: url);
      await service.evaluateJavascript('1', tabId: tab.id);
      final native = platform.views.single;
      await native.start(url);
      native.document.canGoBack = true;
      await native.stop(url);
      native.document.onBack = () {
        native.document.canGoBack = false;
        native.document.canGoForward = true;
      };
      native.document.onForward = () {
        native.document.canGoBack = true;
        native.document.canGoForward = false;
      };
      await service.back(tabId: tab.id);
      expect(service.requireTab(tab.id).canGoBack, isFalse);
      expect(service.requireTab(tab.id).canGoForward, isTrue);
      await service.forward(tabId: tab.id);
      expect(native.document.forwardCalls, 1);
      expect(service.requireTab(tab.id).canGoBack, isTrue);
      expect(service.requireTab(tab.id).canGoForward, isFalse);
    },
  );

  for (final callback in ['history', 'load-stop']) {
    test(
      'older $callback cannot overwrite a newer same-document history state',
      () async {
        const url = 'https://history.example/page';
        final tab = await service.createTab(url: url);
        await service.evaluateJavascript('1', tabId: tab.id);
        final native = platform.views.single;
        await native.start(url);
        await native.stop(url);
        final oldForward = Completer<bool>();
        native.document.forwardRead = oldForward;
        if (callback == 'history') {
          await native.history('$url#old');
        } else {
          await native.stop(url);
        }
        native.document.forwardRead = null;
        native.document.canGoForward = true;
        await native.history('$url#current');
        expect(service.requireTab(tab.id).canGoForward, isTrue);
        oldForward.complete(false);
        await Future<void>.delayed(Duration.zero);
        expect(service.requireTab(tab.id).canGoForward, isTrue);
        expect(service.requireTab(tab.id).url, '$url#current');
      },
    );
  }

  test(
    'same-document agent back does not time out or pause the session',
    () async {
      const url = 'https://history.example/spa';
      final tab = await service.createTab(url: url, ownerSessionId: 'chat');
      await service.updateSettings(
        service.settings.copyWith(agentEnabled: true),
      );
      await service.evaluateJavascript('1', tabId: tab.id);
      final native = platform.views.single;
      await native.start(url);
      native.document.historyIndex = 1;
      native.document.historyLength = 2;
      await native.stop(url);
      final issued = Completer<void>();
      final action = service.runAgentAction(
        sessionId: 'chat',
        tabId: tab.id,
        label: 'back',
        action: () async {
          await service.back(tabId: tab.id);
          issued.complete();
          await service.waitForLoad(
            tabId: tab.id,
            timeout: const Duration(seconds: 1),
          );
        },
      );
      await issued.future;
      native.document.historyIndex = 0;
      native.document.historyTraversal++;
      await native.document.handlers[browserHistoryHandlerName]!([]);
      await action;
      expect(service.agentPaused, isFalse);
    },
  );

  test(
    'late same-document acknowledgement cannot finish a newer navigation',
    () async {
      const url = 'https://history.example/spa';
      final tab = await service.createTab(url: url);
      await service.evaluateJavascript('1', tabId: tab.id);
      final native = platform.views.single;
      await native.start(url);
      native.document.historyIndex = 1;
      native.document.historyLength = 2;
      await native.stop(url);
      await service.back(tabId: tab.id);
      native.document.historyIndex = 0;
      final read = native.document.historyDocumentRead = Completer<Object?>();
      final callback = native.document.handlers[browserHistoryHandlerName]!([]);
      await Future<void>.delayed(Duration.zero);
      await service.navigate('https://next.example', tabId: tab.id);
      var loaded = false;
      final waiting = service
          .waitForLoad(tabId: tab.id)
          .then((_) => loaded = true);
      read.complete({'id': native.document.documentId, 'traversal': 1});
      await callback;
      expect(loaded, isFalse);
      native.document.historyDocumentRead = null;
      await native.start('https://next.example');
      await native.stop('https://next.example');
      await waiting;
    },
  );

  test(
    'rejected stale load-stop does not suppress a valid history response',
    () async {
      const url = 'https://history.example/current';
      final tab = await service.createTab(url: url);
      await service.evaluateJavascript('1', tabId: tab.id);
      final native = platform.views.single;
      await native.start(url);
      final forward = Completer<bool>();
      native.document.forwardRead = forward;
      await native.history(url);
      native.params.onLoadStop!(
        native.callbackController,
        WebUri('https://history.example/old'),
      );
      await Future<void>.delayed(Duration.zero);
      forward.complete(true);
      await Future<void>.delayed(Duration.zero);
      expect(service.requireTab(tab.id).url, url);
      expect(service.requireTab(tab.id).canGoForward, isTrue);
    },
  );

  test(
    'older history read cannot hide Forward while a newer read is pending',
    () async {
      const url = 'https://history.example/current';
      final tab = await service.createTab(url: url);
      await service.evaluateJavascript('1', tabId: tab.id);
      final native = platform.views.single;
      native.document.canGoForward = true;
      await native.history(url);
      expect(service.requireTab(tab.id).canGoForward, isTrue);
      final old = Completer<bool>();
      native.document.forwardRead = old;
      await native.history('$url#old');
      final latest = Completer<bool>();
      native.document.forwardRead = latest;
      await native.history('$url#latest');
      old.complete(false);
      await Future<void>.delayed(Duration.zero);
      expect(service.requireTab(tab.id).canGoForward, isTrue);
      latest.complete(true);
      await Future<void>.delayed(Duration.zero);
      expect(service.requireTab(tab.id).canGoForward, isTrue);
    },
  );

  test(
    'rapid Back Forward Back waits for each native history acknowledgement',
    () async {
      const base = 'https://history.example/';
      final tab = await service.createTab(url: '${base}2');
      await service.evaluateJavascript('1', tabId: tab.id);
      final native = platform.views.single;
      native.document.historyLength = 3;
      native.document.historyIndex = 2;
      await native.start('${base}2');
      await native.stop('${base}2');
      final first = service.back(tabId: tab.id);
      await Future<void>.delayed(Duration.zero);
      final second = service.forward(tabId: tab.id);
      final third = service.back(tabId: tab.id);
      await Future<void>.delayed(Duration.zero);
      expect(native.document.historyCommands, ['back']);
      // Native goBack has acknowledged the command but still reports item 2.
      // A second command must not validate Forward against that old item.
      native.document.historyIndex = 1;
      await native.history('${base}1');
      await Future<void>.delayed(Duration.zero);
      expect(native.document.historyCommands, ['back', 'forward']);
      expect(service.requireTab(tab.id).canGoForward, isTrue);
      native.document.historyIndex = 2;
      await native.history('${base}2');
      await Future<void>.delayed(Duration.zero);
      expect(native.document.historyCommands, ['back', 'forward', 'back']);
      native.document.historyIndex = 1;
      await native.history('${base}1');
      await Future.wait([first, second, third]);
      expect(service.requireTab(tab.id).canGoBack, isTrue);
      expect(service.requireTab(tab.id).canGoForward, isTrue);
      expect(service.requireTab(tab.id).url, '${base}1');
      expect(native.document.independentHistoryReads, 0);
    },
  );

  test(
    'same-document completion refreshes a list updated after the URL event',
    () async {
      const url = 'https://history.example/spa';
      final tab = await service.createTab(url: url);
      await service.evaluateJavascript('1', tabId: tab.id);
      final native = platform.views.single;
      final script = native.params.initialUserScripts!.singleWhere(
        (script) => script.groupName == 'kelivo-browser-history',
      );
      expect(script.source, browserHistoryObserverScript);
      expect(script.injectionTime, UserScriptInjectionTime.AT_DOCUMENT_START);
      expect(script.forMainFrameOnly, isTrue);
      final notify = native.document.handlers[browserHistoryHandlerName]!;
      native.document.historyLength = 3;
      native.document.historyIndex = 2;
      await native.start('$url?step=2');
      await native.stop('$url?step=2');
      final back = service.back(tabId: tab.id);
      final forward = service.forward(tabId: tab.id);
      await Future<void>.delayed(Duration.zero);
      // This is the actual WK sequence: URL KVO fires before currentIndex moves.
      await native.history('$url?step=1');
      expect(native.document.historyCommands, ['back']);
      expect(service.requireTab(tab.id).canGoForward, isFalse);
      native.document.historyIndex = 1;
      await notify([]);
      await Future<void>.delayed(Duration.zero);
      expect(native.document.historyCommands, ['back', 'forward']);
      await native.history('$url?step=2');
      native.document.historyIndex = 2;
      await notify([]);
      await Future.wait([back, forward]);
      expect(service.requireTab(tab.id).canGoForward, isFalse);
      expect(service.requireTab(tab.id).url, '$url?step=2');
    },
  );

  test(
    'same-URL push and pop update availability without a URL callback',
    () async {
      const url = 'https://history.example/spa';
      final tab = await service.createTab(url: url);
      await service.evaluateJavascript('1', tabId: tab.id);
      final native = platform.views.single;
      final notify = native.document.handlers[browserHistoryHandlerName]!;
      native.document.historyLength = 1;
      native.document.historyIndex = 0;
      await native.start(url);
      await native.stop(url);
      expect(service.requireTab(tab.id).canGoBack, isFalse);
      native.document.historyLength = 2;
      native.document.historyIndex = 1;
      await notify([]);
      expect(service.requireTab(tab.id).canGoBack, isTrue);
      final back = service.back(tabId: tab.id);
      await Future<void>.delayed(Duration.zero);
      native.document.historyIndex = 0;
      await notify([]);
      await back;
      expect(service.requireTab(tab.id).canGoBack, isFalse);
      expect(service.requireTab(tab.id).canGoForward, isTrue);
      // A new pushState from this index truncates the forward branch.
      native.document.historyIndex = 1;
      await notify([]);
      expect(service.requireTab(tab.id).canGoBack, isTrue);
      expect(service.requireTab(tab.id).canGoForward, isFalse);
      expect(service.requireTab(tab.id).url, url);
    },
  );

  test(
    'post-back availability refresh preserves the visited URL callback',
    () async {
      const url = 'https://history.example/current';
      const previous = 'https://history.example/previous';
      final tab = await service.createTab(url: url);
      await service.evaluateJavascript('1', tabId: tab.id);
      final native = platform.views.single;
      await native.start(url);
      native.document.canGoBack = true;
      await native.stop(url);
      final delayed = Completer<bool>();
      native.document.onBack = () {
        native.document.canGoBack = false;
        native.document.canGoForward = true;
        native.document.url = WebUri(previous);
        native.document.forwardRead = delayed;
        native.params.onUpdateVisitedHistory!(
          native.callbackController,
          native.document.url,
          false,
        );
        native.document.forwardRead = null;
      };
      await service.back(tabId: tab.id);
      expect(service.requireTab(tab.id).url, previous);
      expect(service.requireTab(tab.id).canGoForward, isTrue);
      delayed.complete(false);
      await Future<void>.delayed(Duration.zero);
      expect(service.requireTab(tab.id).url, previous);
      expect(service.requireTab(tab.id).canGoForward, isTrue);
    },
  );

  test(
    'Stop cancels queued history commands while native current item is pending',
    () async {
      const url = 'https://history.example/current';
      final tab = await service.createTab(url: url);
      await service.evaluateJavascript('1', tabId: tab.id);
      final native = platform.views.single;
      native.document.historyLength = 3;
      native.document.historyIndex = 2;
      await native.start(url);
      await native.stop(url);
      final back = service.back(tabId: tab.id);
      await Future<void>.delayed(Duration.zero);
      final forward = service.forward(tabId: tab.id);
      await Future<void>.delayed(Duration.zero);
      expect(native.document.historyCommands, ['back']);
      await service.stop(tabId: tab.id);
      await Future.wait([back, forward]);
      expect(native.document.historyCommands, ['back']);
      expect(service.requireTab(tab.id).canGoForward, isFalse);
    },
  );

  test(
    'favicon uses the loaded document session and survives a hash update',
    () async {
      const url = 'https://icons.example/page';
      final tab = await service.createTab(url: url);
      await service.evaluateJavascript('1', tabId: tab.id);
      final native = platform.views.single;
      final pending = Completer<CallAsyncJavaScriptResult?>();
      native.document.faviconResult = pending;
      await native.start(url);
      await native.stop(url);
      expect(native.document.faviconReads, 1);
      expect(native.document.faviconSource, contains(browserFaviconScript));
      expect(service.requireTab(tab.id).isLoading, isFalse);
      expect(service.faviconForUrl(url), isNull);
      await native.history('$url#section');
      expect(native.document.faviconReads, 1);
      pending.complete(
        CallAsyncJavaScriptResult(value: {'pageUrl': url, 'png': faviconPng}),
      );
      await Future<void>.delayed(Duration.zero);
      expect(service.faviconForUrl(url), base64Decode(faviconPng));
      // A SPA path change gets a new document-bound read; a hash does not.
      native.document.faviconResult = Completer<CallAsyncJavaScriptResult?>()
        ..complete(
          CallAsyncJavaScriptResult(
            value: {'pageUrl': 'https://icons.example/next', 'png': faviconPng},
          ),
        );
      await native.history('https://icons.example/next');
      expect(native.document.faviconReads, 2);
      expect(
        service.faviconForUrl('https://icons.example/bookmark'),
        isNotNull,
      );
    },
  );

  test(
    'an old favicon cannot overwrite a new navigation to the same URL',
    () async {
      const url = 'https://icons.example/page';
      final tab = await service.createTab(url: url);
      await service.evaluateJavascript('1', tabId: tab.id);
      final native = platform.views.single;
      final old = Completer<CallAsyncJavaScriptResult?>();
      native.document.faviconResult = old;
      await native.start(url);
      await native.stop(url);
      await service.reload(tabId: tab.id);
      final current = Completer<CallAsyncJavaScriptResult?>();
      native.document.faviconResult = current;
      await native.start(url);
      await native.stop(url);
      old.complete(
        CallAsyncJavaScriptResult(value: {'pageUrl': url, 'png': faviconPng}),
      );
      await Future<void>.delayed(Duration.zero);
      expect(service.faviconForUrl(url), isNull);
      current.complete(
        CallAsyncJavaScriptResult(value: {'pageUrl': url, 'png': faviconPng}),
      );
      await Future<void>.delayed(Duration.zero);
      expect(service.faviconForUrl(url), isNotNull);
    },
  );

  test(
    'favicon CORS failure and disposal never change page load success',
    () async {
      const url = 'https://icons.example';
      final tab = await service.createTab(url: url);
      await service.evaluateJavascript('1', tabId: tab.id);
      final native = platform.views.single;
      native.document.faviconResult = Completer<CallAsyncJavaScriptResult?>()
        ..complete(
          CallAsyncJavaScriptResult(error: 'SecurityError: tainted canvas'),
        );
      await native.start(url);
      await native.stop(url);
      expect(service.faviconForUrl(url), isNull);
      expect(service.requireTab(tab.id).error, isNull);
      final pending = Completer<CallAsyncJavaScriptResult?>();
      native.document.faviconResult = pending;
      await service.reload(tabId: tab.id);
      await native.start(url);
      await native.stop(url);
      await service.closeTab(tab.id);
      pending.complete(
        CallAsyncJavaScriptResult(value: {'pageUrl': url, 'png': faviconPng}),
      );
      await Future<void>.delayed(Duration.zero);
      expect(service.faviconForUrl(url), isNull);
    },
  );

  test('Apple native -999 maps to cancellation rather than a load failure', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      final error = WebResourceError.fromMap({
        'type': -999,
        'description': 'The operation could not be completed.',
      })!;
      expect(error.type, WebResourceErrorType.CANCELLED);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  for (final action in ['back', 'navigate']) {
    test(
      '$action cancellation cannot fail the replacement navigation',
      () async {
        const oldUrl = 'https://cn.bing.com/search?q=kelivo';
        const destination = 'https://cn.bing.com/';
        final tab = await service.createTab(url: oldUrl);
        await service.evaluateJavascript('1', tabId: tab.id);
        final native = platform.views.single;
        await native.start(oldUrl);
        await native.stop(oldUrl);
        native.document.canGoBack = true;
        if (action == 'back') {
          await service.back(tabId: tab.id);
          expect(native.document.backCalls, 1);
        } else {
          await service.navigate(destination, tabId: tab.id);
        }
        var finished = false;
        final waiting = service.waitForLoad(tabId: tab.id).then((_) {
          finished = true;
        });
        await native.start(destination);
        native.error(oldUrl, WebResourceErrorType.CANCELLED);
        await Future<void>.delayed(Duration.zero);
        expect(service.requireTab(tab.id).error, isNull);
        expect(service.requireTab(tab.id).isLoading, isTrue);
        expect(finished, isFalse);
        await native.stop(destination);
        await waiting;
        expect(service.requireTab(tab.id).url, destination);
        expect(service.requireTab(tab.id).error, isNull);
        expect(service.requireTab(tab.id).isLoading, isFalse);
        // A late cancellation from the previous load must also leave a completed
        // destination visible rather than replacing it with the retry page.
        native.error(oldUrl, WebResourceErrorType.CANCELLED);
        expect(service.requireTab(tab.id).error, isNull);
        expect(service.requireTab(tab.id).isLoading, isFalse);
      },
    );
  }

  test(
    'a real main-frame network failure still fails its load waiter',
    () async {
      const url = 'https://offline.example';
      final tab = await service.createTab(url: url);
      await service.evaluateJavascript('1', tabId: tab.id);
      final native = platform.views.single;
      await native.start(url);
      final failed = expectLater(
        service.waitForLoad(tabId: tab.id),
        throwsA(
          isA<StateError>().having((e) => e.message, 'message', 'offline'),
        ),
      );
      native.error(url, WebResourceErrorType.CANNOT_CONNECT_TO_HOST, 'offline');
      await failed;
      expect(service.requireTab(tab.id).error, 'offline');
      expect(service.requireTab(tab.id).isLoading, isFalse);
      native.error(url, WebResourceErrorType.CANCELLED);
      expect(service.requireTab(tab.id).error, 'offline');
    },
  );

  test('subframe resource and HTTP failures do not replace the page', () async {
    const url = 'https://page.example';
    final tab = await service.createTab(url: url);
    await service.evaluateJavascript('1', tabId: tab.id);
    final native = platform.views.single;
    await native.start(url);
    native.error(
      'https://frame.example',
      WebResourceErrorType.HOST_LOOKUP,
      'frame failed',
      false,
    );
    native.httpError('https://frame.example', 503, mainFrame: false);
    expect(service.requireTab(tab.id).error, isNull);
    expect(service.requireTab(tab.id).isLoading, isTrue);
    await native.stop(url);
    await service.waitForLoad(tabId: tab.id);
    native.httpError(url, 503);
    expect(service.requireTab(tab.id).error, 'HTTP 503');
  });

  test(
    'explicit stop settles loading without showing its cancellation',
    () async {
      const url = 'https://pending.example';
      final tab = await service.createTab(url: url);
      await service.evaluateJavascript('1', tabId: tab.id);
      final native = platform.views.single;
      await native.start(url);
      final stopped = expectLater(
        service.waitForLoad(tabId: tab.id),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'browser_navigation_stopped',
          ),
        ),
      );
      await service.stop(tabId: tab.id);
      native.error(url, WebResourceErrorType.CANCELLED);
      await stopped;
      expect(service.requireTab(tab.id).error, isNull);
      expect(service.requireTab(tab.id).isLoading, isFalse);
      await service.navigate('https://next.example', tabId: tab.id);
      await native.start('https://next.example');
      await native.stop('https://next.example');
      await service.waitForLoad(tabId: tab.id);
      expect(service.requireTab(tab.id).error, isNull);
    },
  );

  test('changing UA also invalidates the cached download header', () async {
    final engine = await NativeBrowserEngine.create(
      tab: const BrowserTab(id: 'ua-download'),
      settings: const BrowserSettings(),
      onChanged: (_) {},
      onDownload: (_, __) {},
      onNewWindow: (_, __) async => false,
      isAgentActive: () => false,
    );
    try {
      final document = platform.views.single.document;
      document.userAgent = 'Mobile/1';
      expect(
        (await engine.downloadHeaders('https://example.com'))['User-Agent'],
        'Mobile/1',
      );
      await engine.updateSettings(
        const BrowserSettings(customUserAgent: 'Custom/2'),
      );
      document.userAgent = 'Custom/2';
      expect(
        (await engine.downloadHeaders('https://example.com'))['User-Agent'],
        'Custom/2',
      );
    } finally {
      await engine.dispose();
    }
  });

  test(
    'download headers exclude cross-host, insecure and wrong-path credentials',
    () async {
      final engine = await NativeBrowserEngine.create(
        tab: const BrowserTab(id: 'cookies'),
        settings: const BrowserSettings(),
        onChanged: (_) {},
        onDownload: (_, __) {},
        onNewWindow: (_, __) async => false,
        isAgentActive: () => false,
      );
      try {
        _CookieManager.cookies = [
          Cookie(
            name: 'session',
            value: 'fake-token',
            domain: 'example.com',
            path: '/account',
            isSecure: true,
          ),
        ];
        expect(
          (await engine.downloadHeaders(
            'https://example.com/account/file',
          ))['Cookie'],
          'session=fake-token',
        );
        for (final destination in [
          'https://evilexample.com/account/file',
          'http://example.com/account/file',
          'https://example.com/file',
        ]) {
          expect((await engine.downloadHeaders(destination))['Cookie'], isNull);
        }
      } finally {
        await engine.dispose();
      }
    },
  );

  test(
    'tab thumbnails are small JPEGs while agent screenshots retain their PNG contract',
    () async {
      final engine = await NativeBrowserEngine.create(
        tab: const BrowserTab(id: 'preview-test'),
        settings: const BrowserSettings(),
        onChanged: (_) {},
        onDownload: (_, __) {},
        onNewWindow: (_, __) async => false,
        isAgentActive: () => false,
      );
      try {
        await engine.thumbnail();
        await engine.screenshot();
        final configurations = platform.views.single.document.screenshots;
        final dpr = WidgetsBinding
            .instance
            .platformDispatcher
            .views
            .first
            .devicePixelRatio;
        // Native screenshot dimensions use logical pixels on these platforms.
        expect(
          configurations[0]!.snapshotWidth! *
              (Platform.isAndroid || Platform.isIOS || Platform.isMacOS
                  ? dpr
                  : 1),
          440,
        );
        expect(configurations[0]!.compressFormat, CompressFormat.JPEG);
        expect(configurations[0]!.quality, 70);
        expect(configurations[0]!.afterScreenUpdates, isFalse);
        expect(configurations[1]!.snapshotWidth, 1280);
        expect(configurations[1]!.compressFormat, CompressFormat.PNG);
      } finally {
        await engine.dispose();
      }
    },
  );

  test(
    'covered tabs clear native focus and a rapid return supersedes pause',
    () async {
      final engine = await NativeBrowserEngine.create(
        tab: const BrowserTab(id: 'focus-test'),
        settings: const BrowserSettings(),
        onChanged: (_) {},
        onDownload: (_, __) {},
        onNewWindow: (_, __) async => false,
        isAgentActive: () => false,
      );
      try {
        final document = platform.views.single.document;
        await engine.setVisible(false);
        expect(document.focusClears, 1);
        expect(document.mediaPauses, 1);
        await engine.setVisible(true);
        final gate = document.clearFocusGate = Completer<void>();
        final hiding = engine.setVisible(false);
        await Future<void>.delayed(Duration.zero);
        expect(document.focusClears, 2);
        final showing = engine.setVisible(true);
        gate.complete();
        await Future.wait([hiding, showing]);
        expect(document.mediaPauses, 1);
      } finally {
        await engine.dispose();
      }
    },
    skip: !Platform.isMacOS,
  );

  test(
    'surface changes update native composition without reloading documents',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final tab = await service.createTab(url: 'https://history.example/page');
      await service.evaluateJavascript('1', tabId: tab.id);
      final native = platform.views.single;
      var applied = native.document.appliedSettings.length;
      for (final style in [
        BrowserSurfaceStyle.frosted,
        BrowserSurfaceStyle.solid,
      ]) {
        await service.updateSettings(
          service.settings.copyWith(surfaceStyle: style),
        );
        expect(native.document.appliedSettings.length, ++applied);
        expect(
          native.document.appliedSettings.last.useHybridComposition,
          style == BrowserSurfaceStyle.solid,
        );
        expect(native.document.reloads, 0);
        expect(platform.views, hasLength(1));
      }
    },
  );

  for (final target in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('material changes reattach the same document on $target', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = target;
      const tab = BrowserTab(id: 'composition-test');
      final engine = await NativeBrowserEngine.create(
        tab: tab,
        settings: const BrowserSettings(
          surfaceStyle: BrowserSurfaceStyle.solid,
        ),
        onChanged: (_) {},
        onDownload: (_, _) {},
        onNewWindow: (_, _) async => false,
        isAgentActive: () => false,
      );
      try {
        final native = platform.views.single;
        native.document.historyIndex = 1;
        native.document.historyLength = 3;
        native.document.documentId = 'retained-form-document';
        final host = engine.buildView();
        await tester.pumpWidget(host);
        await engine.viewReady;
        final token = platform.widgets.single.params.keepAlive;
        expect(
          platform.widgets.single.params.initialSettings!.useHybridComposition,
          target == TargetPlatform.android,
        );
        for (final style in [
          BrowserSurfaceStyle.frosted,
          BrowserSurfaceStyle.solid,
        ]) {
          await engine.updateSettings(BrowserSettings(surfaceStyle: style));
          await tester.pump();
          await engine.viewReady;
          expect(
            platform.widgets.last.params.initialSettings!.useHybridComposition,
            target == TargetPlatform.android &&
                style == BrowserSurfaceStyle.solid,
          );
          expect(platform.widgets.last.params.keepAlive, same(token));
          expect(platform.views, hasLength(1));
          expect(native.document.reloads, 0);
          expect(native.document.historyIndex, 1);
          expect(native.document.historyLength, 3);
          expect(native.document.documentId, 'retained-form-document');
        }
        // Unsupported shader filters already render liquid as a solid surface.
        // Match that effective material instead of allocating a texture host.
        await engine.updateSettings(
          const BrowserSettings(surfaceStyle: BrowserSurfaceStyle.liquid),
        );
        await tester.pump();
        await engine.viewReady;
        final hosts = target == TargetPlatform.android ? 3 : 1;
        expect(platform.widgets, hasLength(hosts));
        // Changes coalescing back to the mounted composition must not strand
        // the first-frame readiness future or replace its native document.
        await engine.updateSettings(
          const BrowserSettings(surfaceStyle: BrowserSurfaceStyle.frosted),
        );
        await engine.updateSettings(
          const BrowserSettings(surfaceStyle: BrowserSurfaceStyle.solid),
        );
        await tester.pump();
        await engine.viewReady;
        await engine.updateSettings(
          const BrowserSettings(
            surfaceStyle: BrowserSurfaceStyle.solid,
            customUserAgent: 'Test/1.0',
          ),
        );
        await tester.pump();
        expect(platform.widgets, hasLength(hosts));
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await engine.dispose();
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  test('custom UA reaches new and live engines and can be cleared', () async {
    await service.initialize();
    await service.updateSettings(
      service.settings.copyWith(customUserAgent: 'Browser-Test/1.0'),
    );
    final tab = await service.createTab(url: 'https://ua.example');
    await service.evaluateJavascript('1', tabId: tab.id);
    final view = platform.views.single;
    expect(view.params.initialSettings!.userAgent, 'Browser-Test/1.0');
    await service.updateSettings(
      service.settings.copyWith(customUserAgent: 'Browser-Test/2.0'),
    );
    expect(view.document.appliedSettings.last.userAgent, 'Browser-Test/2.0');
    expect(view.document.reloads, 1);
    await service.updateSettings(
      service.settings.copyWith(customUserAgent: '', desktopMode: true),
    );
    expect(view.document.appliedSettings.last.userAgent, isEmpty);
    expect(
      view.document.appliedSettings.last.preferredContentMode,
      UserPreferredContentMode.DESKTOP,
    );
    expect(view.document.reloads, 2);
    await service.updateSettings(service.settings.copyWith(saveHistory: false));
    expect(
      view.document.reloads,
      2,
      reason: 'unrelated preferences do not reload',
    );
  });

  for (final desktopMode in [true, false]) {
    test(
      'native content preference explicitly requests ${desktopMode ? 'desktop' : 'mobile'}',
      () async {
        await service.initialize();
        await service.updateSettings(
          service.settings.copyWith(desktopMode: desktopMode),
        );
        final tab = await service.createTab();
        await service.evaluateJavascript('1', tabId: tab.id);
        expect(
          platform.views.single.params.initialSettings!.preferredContentMode,
          desktopMode
              ? UserPreferredContentMode.DESKTOP
              : UserPreferredContentMode.MOBILE,
        );
      },
    );
  }

  test(
    'a newly created blank engine is ready without waiting for a native navigation',
    () async {
      final tab = await service.createTab();
      await service.evaluateJavascript('1', tabId: tab.id);
      await service.waitForLoad(
        tabId: tab.id,
        timeout: const Duration(milliseconds: 50),
      );
      expect(platform.views.single.params.initialUrlRequest, isNull);
      expect(service.requireTab(tab.id).isLoading, isFalse);
      expect(service.requireTab(tab.id).hasContent, isFalse);
    },
  );

  test(
    'initial blank navigation cannot complete loadHtml or discard its content',
    () async {
      final tab = await service.createTab();
      await service.loadHtml('<p>First rendered document</p>', tabId: tab.id);
      final native = platform.views.single;
      // A requested initial about:blank may finish after loadData was issued
      // but before its start callback. It must not masquerade as HTML's stop.
      if (native.params.initialUrlRequest != null) {
        await native.stop('about:blank');
      }
      await native.start('about:blank');
      await native.stop('about:blank');
      await service.waitForLoad(tabId: tab.id);
      expect(service.requireTab(tab.id).hasContent, isTrue);
      expect(native.params.initialUrlRequest, isNull);
      await evict(tab.id);
      await service.evaluateJavascript('1', tabId: tab.id);
      expect(platform.views.last.document.htmlLoads, [
        '<p>First rendered document</p>',
      ]);
    },
  );

  test(
    'Android synthetic callbacks retain HTML identity through persistence and eviction',
    () async {
      final tab = await service.createTab();
      const html = '<h1>Rendered document</h1>';
      await service.loadHtml(html, tabId: tab.id);
      final native = platform.views.single;
      await native.start(_androidDataUrl);
      expect(service.requireTab(tab.id).url, 'about:blank');
      expect(service.requireTab(tab.id).hasContent, isTrue);
      await native.history(_androidDataUrl);
      expect(service.requireTab(tab.id).url, 'about:blank');
      await native.stop(_androidDataUrl);
      await service.waitForLoad(tabId: tab.id);
      expect(service.requireTab(tab.id).url, 'about:blank');
      expect(service.requireTab(tab.id).hasContent, isTrue);

      await service.flush();
      final restored = BrowserService(store: store, supported: true);
      await restored.initialize();
      expect(restored.tabs.single.id, tab.id);
      expect(restored.tabs.single.url, 'about:blank');
      restored.dispose();

      await evict(tab.id);
      expect(native.disposed, isTrue);
      await service.evaluateJavascript('1', tabId: tab.id);
      expect(platform.views.last.document.htmlLoads, [html]);
    },
  );

  test(
    'render base URL survives subframe navigation but real HTTP navigation replaces it',
    () async {
      const base = 'https://render.example/document';
      const destination = 'https://destination.example/article';
      final tab = await service.createTab();
      await service.loadHtml(
        '<a href="$destination">Continue</a>',
        tabId: tab.id,
        baseUrl: base,
      );
      final native = platform.views.single;
      await native.start(_androidDataUrl);
      await native.history(_androidDataUrl);
      await native.stop(_androidDataUrl);
      expect(service.requireTab(tab.id).url, base);
      expect(service.requireTab(tab.id).hasContent, isTrue);
      expect(
        await native.policy('https://frame.example', mainFrame: false),
        NavigationActionPolicy.ALLOW,
      );
      await native.history(_androidDataUrl);
      expect(service.requireTab(tab.id).url, base);

      expect(await native.policy(destination), NavigationActionPolicy.ALLOW);
      await native.start(destination);
      await native.stop(destination);
      expect(service.requireTab(tab.id).url, destination);
      expect(service.requireTab(tab.id).hasContent, isFalse);
      await evict(tab.id);
      await service.evaluateJavascript('1', tabId: tab.id);
      expect(platform.views.last.document.htmlLoads, isEmpty);
      expect(
        platform.views.last.params.initialUrlRequest?.url.toString(),
        destination,
      );
    },
  );

  test(
    'late Android synthetic starts retain the completed render and restorable tab',
    () async {
      final tab = await service.createTab();
      const html = '<h1>Retained after native transfer</h1>';
      await service.loadHtml(html, tabId: tab.id);
      final native = platform.views.single;
      // Android may finish the about:blank representation before delivering
      // the data: start/history callbacks for that same synthetic document.
      await native.stop('about:blank');
      await native.start(_androidDataUrl);
      await native.history(_androidDataUrl);
      await native.stop(_androidDataUrl);
      // Reattaching an already loaded native view can repeat this sequence.
      await native.start(_androidDataUrl);
      await native.stop(_androidDataUrl);
      expect(service.requireTab(tab.id).url, 'about:blank');
      expect(service.requireTab(tab.id).hasContent, isTrue);

      await service.flush();
      final restored = BrowserService(store: store, supported: true);
      await restored.initialize();
      expect(restored.tabs.single.id, tab.id);
      expect(restored.tabs.single.url, 'about:blank');
      restored.dispose();
      await evict(tab.id);
      await service.evaluateJavascript('1', tabId: tab.id);
      expect(platform.views.last.document.htmlLoads, [html]);
    },
  );

  test(
    'late synthetic start does not consume a pending same-URL replacement',
    () async {
      const base = 'https://render.example/form';
      final tab = await service.createTab();
      await service.loadHtml('<p>Synthetic</p>', tabId: tab.id, baseUrl: base);
      final native = platform.views.single;
      await native.start(_androidDataUrl);
      await native.stop(_androidDataUrl);
      expect(await native.policy(base), NavigationActionPolicy.ALLOW);
      await native.start(_androidDataUrl);
      expect(service.requireTab(tab.id).hasContent, isTrue);
      await native.start(base);
      await native.stop(base);
      expect(service.requireTab(tab.id).hasContent, isFalse);
      await evict(tab.id);
      await service.evaluateJavascript('1', tabId: tab.id);
      expect(platform.views.last.document.htmlLoads, isEmpty);
    },
  );

  test(
    'initial HTTP base callbacks preserve HTML but a subsequent same-URL document replaces it',
    () async {
      const base = 'https://render.example/document';
      final tab = await service.createTab();
      await service.loadHtml(
        '<p>Synthetic document</p>',
        tabId: tab.id,
        baseUrl: base,
      );
      final native = platform.views.single;
      expect(await native.policy(base), NavigationActionPolicy.ALLOW);
      await native.start(base);
      await native.stop(base);
      expect(service.requireTab(tab.id).hasContent, isTrue);

      expect(await native.policy(base), NavigationActionPolicy.ALLOW);
      // A policy decision alone must not throw away the currently visible page.
      expect(service.requireTab(tab.id).hasContent, isTrue);
      await native.start(base);
      await native.stop(base);
      expect(service.requireTab(tab.id).url, base);
      expect(service.requireTab(tab.id).hasContent, isFalse);
      await evict(tab.id);
      await service.evaluateJavascript('1', tabId: tab.id);
      expect(platform.views.last.document.htmlLoads, isEmpty);
      expect(
        platform.views.last.params.initialUrlRequest?.url.toString(),
        base,
      );
    },
  );

  test(
    'same-URL POST replaces rendered HTML without a navigation-policy callback',
    () async {
      const base = 'https://render.example/form';
      final tab = await service.createTab();
      await service.loadHtml(
        '<form method="post"></form>',
        tabId: tab.id,
        baseUrl: base,
      );
      final native = platform.views.single;
      await native.start(base);
      await native.stop(base);
      // Android does not call shouldOverrideUrlLoading for form POSTs.
      await native.start(base);
      await native.stop(base);
      expect(service.requireTab(tab.id).hasContent, isFalse);
      await evict(tab.id);
      await service.evaluateJavascript('1', tabId: tab.id);
      expect(platform.views.last.document.htmlLoads, isEmpty);
    },
  );

  test('explicit reload preserves the rendered document', () async {
    final tab = await service.createTab();
    const html = '<p>Keep this rendered page</p>';
    await service.loadHtml(html, tabId: tab.id);
    final native = platform.views.single;
    await native.start(_androidDataUrl);
    await native.stop(_androidDataUrl);
    await service.reload(tabId: tab.id);
    await native.start(_androidDataUrl);
    await native.stop(_androidDataUrl);
    expect(service.requireTab(tab.id).hasContent, isTrue);
    await evict(tab.id);
    await service.evaluateJavascript('1', tabId: tab.id);
    expect(platform.views.last.document.htmlLoads, [html]);
  });

  test(
    'headless load-stop accepts synthetic URL aliases only after DOM is complete',
    () async {
      final tab = await service.createTab();
      await service.loadHtml('<p>Headless</p>', tabId: tab.id);
      final native = platform.views.single;
      await native.start(_androidDataUrl);
      var completed = false;
      final waiting = service
          .waitForLoad(tabId: tab.id)
          .then((_) => completed = true);
      native.document.readiness = 'loading';
      native.params.onLoadStop!(
        native.callbackController,
        WebUri('about:blank'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);
      native.document.readiness = 'complete';
      native.params.onLoadStop!(
        native.callbackController,
        WebUri('about:blank'),
      );
      await waiting;
      expect(completed, isTrue);
      expect(service.requireTab(tab.id).url, 'about:blank');
      expect(service.requireTab(tab.id).hasContent, isTrue);
    },
  );

  test(
    'data URLs remain rejected and no normalization leaks beyond explicit render',
    () async {
      final tab = await service.createTab();
      await service.loadHtml('<p>Local render</p>', tabId: tab.id);
      final native = platform.views.single;
      expect(
        await native.policy(_androidDataUrl),
        NavigationActionPolicy.CANCEL,
      );
      await service.navigate('https://example.com', tabId: tab.id);
      await native.start('https://example.com');
      await native.stop('https://example.com');
      await native.history(_androidDataUrl);
      // Unexpected native data URLs must not masquerade as the old render.
      expect(service.requireTab(tab.id).url, _androidDataUrl);
    },
  );

  test('old load-stop cannot complete a newer rendered document', () async {
    final tab = await service.createTab();
    await service.loadHtml('<p>Current</p>', tabId: tab.id);
    final native = platform.views.single;
    var completed = false;
    final waiting = service.waitForLoad(tabId: tab.id).then((_) {
      completed = true;
    });
    native.document.url = WebUri(_androidDataUrl);
    native.params.onLoadStop!(
      native.callbackController,
      WebUri('https://old.example'),
    );
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);
    expect(service.requireTab(tab.id).url, 'about:blank');
    await native.start(_androidDataUrl);
    await native.stop(_androidDataUrl);
    await waiting;
    expect(service.requireTab(tab.id).url, 'about:blank');
  });

  test(
    'scroll bridge verifies once then pushes ordered phases without per-frame evaluation',
    () async {
      final tab = await service.createTab();
      await service.evaluateJavascript('1', tabId: tab.id);
      final native = platform.views.single;
      expect(
        native.params.initialUserScripts!
            .singleWhere(
              (script) => script.groupName == 'kelivo-browser-scroll',
            )
            .source,
        browserScrollObserverScript,
      );
      final marker = native.params.initialUserScripts!.singleWhere(
        (script) => script.groupName == 'kelivo-browser-identity',
      );
      expect(marker.source, browserTabUserScriptMarker(tab.id));
      expect(marker.injectionTime, UserScriptInjectionTime.AT_DOCUMENT_START);
      expect(marker.forMainFrameOnly, isTrue);
      final handler = native.document.handlers[browserScrollHandlerName]!;
      Map<String, Object> event(int sequence, String phase, double offset) => {
        'documentId': native.document.documentId,
        'sequence': sequence,
        'phase': phase,
        'offset': offset,
        'viewportExtent': 800,
        'contentExtent': 3000,
        'supportsScrollEnd': true,
        'isUserInteracting': false,
        'gestureDelta': 0,
      };
      expect(await handler([event(1, 'reset', 0)]), isTrue);
      final queries = native.document.evaluations.length;
      var globalChanges = 0;
      service.addListener(() => globalChanges++);
      expect(await handler([event(2, 'update', 25)]), isTrue);
      expect(await handler([event(3, 'end', 30)]), isTrue);
      expect(service.scrollStateForTab(tab.id)!.phase, BrowserScrollPhase.end);
      expect(service.scrollStateForTab(tab.id)!.offset, 30);
      expect(native.document.evaluations.length, queries);
      expect(globalChanges, 0);
      expect(await handler([event(2, 'update', 2)]), isFalse);
      expect(service.scrollStateForTab(tab.id)!.offset, 30);
    },
  );

  test(
    'same-document back and forward reconnect scroll without load-stop',
    () async {
      const url = 'https://history.example/page';
      final tab = await service.createTab(url: url);
      await service.evaluateJavascript('1', tabId: tab.id);
      final native = platform.views.single;
      await native.start(url);
      native.document.historyIndex = 1;
      native.document.historyLength = 2;
      await native.stop(url);
      final handler = native.document.handlers[browserScrollHandlerName]!;
      var sequence = 0;
      Map<String, Object> event(String phase, double offset) => {
        'documentId': native.document.documentId,
        'sequence': ++sequence,
        'phase': phase,
        'offset': offset,
        'viewportExtent': 800,
        'contentExtent': 3000,
        'supportsScrollEnd': true,
        'isUserInteracting': phase == 'update',
        'gestureDelta': phase == 'update' ? 20 : 0,
      };
      expect(await handler([event('reset', 0)]), isTrue);
      native.document.onBack = () => native.document.historyIndex = 0;
      native.document.onForward = () => native.document.historyIndex = 1;
      for (var round = 0; round < 3; round++) {
        for (final forward in [false, true]) {
          final before = native.document.evaluations
              .where((script) => script.contains('?.reconnect()'))
              .length;
          await (forward
              ? service.forward(tabId: tab.id)
              : service.back(tabId: tab.id));
          await Future<void>.delayed(Duration.zero);
          expect(
            native.document.evaluations
                .where((script) => script.contains('?.reconnect()'))
                .length,
            greaterThan(before),
          );
          // The same document ID remains valid; no native load-stop occurs.
          expect(await handler([event('reset', 100)]), isTrue);
          expect(await handler([event('update', 120)]), isTrue);
          expect(service.scrollStateForTab(tab.id)!.offset, 120);
          expect(service.requireTab(tab.id).canGoForward, !forward);
        }
      }
    },
  );

  test('navigation and disposal reject stale document scroll events', () async {
    final tab = await service.createTab();
    await service.evaluateJavascript('1', tabId: tab.id);
    final native = platform.views.single;
    final handler = native.document.handlers[browserScrollHandlerName]!;
    Map<String, Object> event(String id, int sequence, String phase) => {
      'documentId': id,
      'sequence': sequence,
      'phase': phase,
      'offset': 80,
      'viewportExtent': 800,
      'contentExtent': 3000,
      'supportsScrollEnd': true,
      'isUserInteracting': false,
      'gestureDelta': 0,
    };
    expect(await handler([event('document-a', 1, 'reset')]), isTrue);
    await native.start('https://new.example');
    expect(service.scrollStateForTab(tab.id)!.phase, BrowserScrollPhase.reset);
    expect(await handler([event('document-a', 2, 'end')]), isFalse);
    native.document.documentId = 'document-b';
    expect(await handler([event('document-a', 3, 'reset')]), isFalse);
    expect(await handler([event('document-b', 1, 'reset')]), isTrue);
    expect(await handler([event('document-a', 4, 'end')]), isFalse);
    await service.closeTab(tab.id);
    expect(await handler([event('document-b', 2, 'end')]), isFalse);
    expect(service.scrollStateForTab(tab.id), isNull);
  });

  test(
    'stopping navigation allows the retained document to reattach its observer',
    () async {
      final tab = await service.createTab();
      await service.evaluateJavascript('1', tabId: tab.id);
      final native = platform.views.single;
      final handler = native.document.handlers[browserScrollHandlerName]!;
      Map<String, Object> reset(int sequence) => {
        'documentId': 'document-a',
        'sequence': sequence,
        'phase': 'reset',
        'offset': 0,
        'viewportExtent': 800,
        'contentExtent': 3000,
        'supportsScrollEnd': true,
        'isUserInteracting': false,
        'gestureDelta': 0,
      };
      expect(await handler([reset(1)]), isTrue);
      await service.navigate('https://pending.example', tabId: tab.id);
      expect(await handler([reset(2)]), isFalse);
      await service.stop(tabId: tab.id);
      expect(await handler([reset(3)]), isTrue);
    },
  );
}

class _MemoryStore extends BrowserStore {
  Map<String, Object?> state = {};
  @override
  Future<Map<String, dynamic>> read() async => Map<String, dynamic>.from(state);
  @override
  Future<void> write(Map<String, Object?> state) async => this.state = state;
}

class _BrowserPlatform extends InAppWebViewPlatform {
  bool useWindowsFindFactory = false;
  final List<_HeadlessView> views = [];
  final Map<Object, _Document> documents = {};
  final List<_WidgetView> widgets = [];
  final Map<InAppWebViewKeepAlive, String> retained = {};

  @override
  PlatformInAppWebViewWidget createPlatformInAppWebViewWidget(
    PlatformInAppWebViewWidgetCreationParams params,
  ) {
    final id = retained.putIfAbsent(
      params.keepAlive!,
      () => params.headlessWebView!.id,
    );
    final view = _WidgetView(params, id, documents[id]!);
    widgets.add(view);
    return view;
  }

  @override
  PlatformInAppWebViewController createPlatformInAppWebViewControllerStatic() =>
      _Controller(
        const PlatformInAppWebViewControllerCreationParams(id: 'static'),
        _Document(),
      );

  @override
  PlatformCookieManager createPlatformCookieManager(
    PlatformCookieManagerCreationParams params,
  ) => _CookieManager(params);

  @override
  PlatformFindInteractionController createPlatformFindInteractionController(
    PlatformFindInteractionControllerCreationParams params,
  ) => useWindowsFindFactory
      ? WindowsInAppWebViewPlatform().createPlatformFindInteractionController(
          params,
        )
      : _FindController(params);

  @override
  PlatformInAppWebViewController createPlatformInAppWebViewController(
    PlatformInAppWebViewControllerCreationParams params,
  ) => _Controller(params, documents[params.id] ?? _Document());

  @override
  PlatformHeadlessInAppWebView createPlatformHeadlessInAppWebView(
    PlatformHeadlessInAppWebViewCreationParams params,
  ) {
    final id = 'test-view-${views.length}';
    final document = _Document();
    documents[id] = document;
    final view = _HeadlessView(params, id, document);
    views.add(view);
    return view;
  }
}

class _WidgetView extends PlatformInAppWebViewWidget {
  _WidgetView(super.params, this.id, this.document) : super.implementation();
  final String id;
  final _Document document;
  bool created = false;
  bool disposed = false;

  @override
  T controllerFromPlatform<T>(PlatformInAppWebViewController controller) =>
      params.controllerFromPlatform!(controller) as T;

  @override
  Widget build(BuildContext context) {
    if (!created) {
      created = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (disposed) return;
        final controller = _Controller(
          PlatformInAppWebViewControllerCreationParams(
            id: id,
            webviewParams: params,
          ),
          document,
        );
        params.onWebViewCreated!(
          controllerFromPlatform<InAppWebViewController>(controller),
        );
      });
    }
    return const SizedBox.expand();
  }

  @override
  void dispose() => disposed = true;
}

class _Document {
  int historyTraversal = 0;
  bool doubleHistoryNumbers = false;
  Completer<Object?>? historyDocumentRead;
  String userAgent = 'Default/1';
  final List<InAppWebViewSettings> appliedSettings = [];
  int reloads = 0;
  int focusClears = 0;
  int mediaPauses = 0;
  Completer<void>? clearFocusGate;
  Completer<CallAsyncJavaScriptResult?>? faviconResult;
  int faviconReads = 0;
  String? faviconSource;
  final List<ScreenshotConfiguration?> screenshots = [];
  bool canGoBack = false;
  bool canGoForward = false;
  int? historyIndex, historyLength;
  int independentHistoryReads = 0;
  final historyCommands = <String>[];
  Completer<bool>? forwardRead;
  int backCalls = 0;
  int forwardCalls = 0;
  void Function()? onBack;
  void Function()? onForward;
  WebUri? url;
  String readiness = 'complete';
  final List<String> htmlLoads = [];
  String documentId = 'document-a';
  final Map<String, JavaScriptHandlerCallback> handlers = {};
  final List<String> evaluations = [];
}

class _HeadlessView extends PlatformHeadlessInAppWebView {
  _HeadlessView(super.params, this.id, this.document) : super.implementation();
  @override
  final String id;
  final _Document document;
  bool disposed = false;
  late final _Controller controller = _Controller(
    PlatformInAppWebViewControllerCreationParams(id: id, webviewParams: params),
    document,
  );

  InAppWebViewController get callbackController =>
      params.controllerFromPlatform!(controller) as InAppWebViewController;

  @override
  Future<void> run() async => params.onWebViewCreated!(callbackController);
  @override
  Future<void> dispose() async => disposed = true;
  @override
  bool isRunning() => !disposed;
  @override
  PlatformInAppWebViewController get webViewController => controller;

  Future<void> start(String url) async {
    document.url = WebUri(url);
    params.onLoadStart!(callbackController, document.url);
  }

  Future<void> stop(String url) async {
    document.url = WebUri(url);
    params.onLoadStop!(callbackController, document.url);
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> history(String url) async {
    document.url = WebUri(url);
    params.onUpdateVisitedHistory!(callbackController, document.url, false);
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> commit(String url) async {
    document.url = WebUri(url);
    params.onPageCommitVisible!(callbackController, document.url);
    await Future<void>.delayed(Duration.zero);
  }

  void error(
    String url,
    WebResourceErrorType type, [
    String description = 'cancelled',
    bool mainFrame = true,
  ]) => params.onReceivedError!(
    callbackController,
    WebResourceRequest(url: WebUri(url), isForMainFrame: mainFrame),
    WebResourceError(type: type, description: description),
  );

  void httpError(String url, int status, {bool mainFrame = true}) =>
      params.onReceivedHttpError!(
        callbackController,
        WebResourceRequest(url: WebUri(url), isForMainFrame: mainFrame),
        WebResourceResponse(statusCode: status),
      );

  Future<NavigationActionPolicy?> policy(String url, {bool mainFrame = true}) =>
      params.shouldOverrideUrlLoading!(
        callbackController,
        NavigationAction(
          request: URLRequest(url: WebUri(url)),
          isForMainFrame: mainFrame,
        ),
      );
}

class _Controller extends PlatformInAppWebViewController {
  _Controller(super.params, this.document) : super.implementation();
  final _Document document;
  @override
  Future<CallAsyncJavaScriptResult?> callAsyncJavaScript({
    required String functionBody,
    Map<String, dynamic> arguments = const {},
    ContentWorld? contentWorld,
  }) async {
    if (functionBody.contains(browserFaviconScript)) {
      document.faviconReads++;
      document.faviconSource = functionBody;
      return document.faviconResult?.future;
    }
    return null;
  }

  @override
  Future<Uint8List?> takeScreenshot({
    ScreenshotConfiguration? screenshotConfiguration,
  }) async {
    document.screenshots.add(screenshotConfiguration);
    return Uint8List.fromList([1]);
  }

  @override
  Future<WebUri?> getUrl() async => document.url;
  @override
  Future<String?> getTitle() async => 'Rendered document';
  @override
  Future<bool> canGoBack() async {
    document.independentHistoryReads++;
    return document.canGoBack;
  }

  @override
  Future<WebHistory?> getCopyBackForwardList() async {
    final index = document.historyIndex;
    final length = document.historyLength;
    if (index != null && length != null) {
      return WebHistory(
        currentIndex: index,
        list: List.generate(length, (_) => WebHistoryItem(url: document.url)),
      );
    }
    final back = document.canGoBack;
    final forward =
        await (document.forwardRead?.future ??
            Future.value(document.canGoForward));
    return WebHistory(
      currentIndex: back ? 1 : 0,
      list: List.generate(
        1 + (back ? 1 : 0) + (forward ? 1 : 0),
        (_) => WebHistoryItem(url: document.url),
      ),
    );
  }

  @override
  Future<void> goBack() async {
    document.backCalls++;
    document.historyCommands.add('back');
    document.onBack?.call();
  }

  @override
  Future<bool> canGoForward() async {
    document.independentHistoryReads++;
    return document.forwardRead?.future ?? document.canGoForward;
  }

  @override
  Future<void> goForward() async {
    document.forwardCalls++;
    document.historyCommands.add('forward');
    document.onForward?.call();
  }

  @override
  Future<void> clearFocus() async {
    document.focusClears++;
    await document.clearFocusGate?.future;
  }

  @override
  Future<void> pauseAllMediaPlayback() async => document.mediaPauses++;
  @override
  Future<void> reload() async {
    document.reloads++;
  }

  @override
  Future<void> setSettings({required InAppWebViewSettings settings}) async {
    document.appliedSettings.add(settings);
  }

  @override
  Future<void> stopLoading() async {}
  @override
  void dispose({bool isKeepAlive = false}) {}
  @override
  Future<void> disposeKeepAlive(InAppWebViewKeepAlive keepAlive) async {}
  @override
  void addJavaScriptHandler({
    required String handlerName,
    required JavaScriptHandlerCallback callback,
  }) {
    document.handlers[handlerName] = callback;
  }

  @override
  Future<dynamic> evaluateJavascript({
    required String source,
    ContentWorld? contentWorld,
  }) async {
    document.evaluations.add(source);
    if (source == 'navigator.userAgent') return document.userAgent;
    if (source == browserScrollIdentityScript) return document.documentId;
    if (source == browserHistoryDocumentScript) {
      if (document.historyDocumentRead != null) {
        return document.historyDocumentRead!.future;
      }
      return {
        'id': document.documentId,
        'traversal': document.doubleHistoryNumbers
            ? document.historyTraversal.toDouble()
            : document.historyTraversal,
      };
    }
    return source == 'document.readyState' ? document.readiness : 1;
  }

  @override
  Future<void> loadData({
    required String data,
    String mimeType = 'text/html',
    String encoding = 'utf8',
    WebUri? baseUrl,
    Uri? androidHistoryUrl,
    WebUri? historyUrl,
    Uri? iosAllowingReadAccessTo,
    WebUri? allowingReadAccessTo,
  }) async {
    document.htmlLoads.add(data);
  }

  @override
  Future<void> loadUrl({
    required URLRequest urlRequest,
    Uri? iosAllowingReadAccessTo,
    WebUri? allowingReadAccessTo,
  }) async {
    document.url = urlRequest.url;
  }
}

class _CookieManager extends PlatformCookieManager {
  static List<Cookie> cookies = [];
  _CookieManager(super.params) : super.implementation();
  @override
  Future<List<Cookie>> getCookies({
    required WebUri url,
    PlatformInAppWebViewController? iosBelow11WebViewController,
    PlatformInAppWebViewController? webViewController,
  }) async => cookies;
}

class _FindController extends PlatformFindInteractionController {
  _FindController(super.params) : super.implementation();
}
