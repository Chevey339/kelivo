import 'dart:async';

import 'package:Kelivo/core/services/browser/browser_engine.dart';
import 'package:Kelivo/core/services/browser/browser_service.dart';
import 'package:Kelivo/core/services/browser/browser_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late BrowserService service;
  late Map<String, _Engine> engines;
  Future<void>? nextViewReady;

  void previewTest(String name, WidgetTesterCallback body) {
    testWidgets(name, (tester) async {
      engines = {};
      nextViewReady = null;
      service = BrowserService(
        store: _Store(),
        supported: true,
        engineFactory:
            ({
              required tab,
              required settings,
              required onChanged,
              required onDownload,
              required onNewWindow,
              required isAgentActive,
            }) async => engines[tab.id] = _Engine(onChanged, nextViewReady),
      );
      await service.initialize();
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        service.dispose();
        debugDefaultTargetPlatformOverride = null;
        await tester.pump();
      }
    });
  }

  Widget host() => Directionality(
    textDirection: TextDirection.ltr,
    child: ListenableBuilder(
      listenable: service,
      builder: (_, __) => service.activeTabId == null
          ? const SizedBox.shrink()
          : service.buildView(service.activeTabId!),
    ),
  );

  Future<String> backgroundPage() async {
    final tab = await service.createTab(
      url: 'https://agent.example',
      ownerSessionId: 'chat',
    );
    await service.runAgentAction<void>(
      sessionId: 'chat',
      label: 'open',
      action: () async {
        await service.navigate('https://agent.example', tabId: tab.id);
        engines[tab.id]!.complete();
      },
    );
    return tab.id;
  }

  previewTest(
    'chat preview captures an existing headless page without presenting or resuming it',
    (tester) async {
      final id = await backgroundPage();
      final engine = engines[id]!;
      final resumes = engine.resumes;
      expect(engine.captures, 0);
      final unwatch = service.watchTabPreview(id);
      await tester.pump(const Duration(milliseconds: 160));
      expect(service.previewForTab(id), [1]);
      expect(engine.captures, 1);
      expect(engine.viewBuilds, 0);
      expect(engine.resumes, resumes);
      unwatch();
      final saved = await service.createTab(url: 'https://saved.example');
      final release = service.watchTabPreview(saved.id);
      await tester.pump(const Duration(seconds: 2));
      expect(engines.containsKey(saved.id), isFalse);
      release();
    },
  );

  previewTest(
    'tool previews sample each completed step without resuming its renderer',
    (tester) async {
      final id = await backgroundPage();
      final engine = engines[id]!;
      final resumes = engine.resumes;
      final first = await service.captureToolPreview(id);
      expect(first, [1]);
      expect(engine.captures, 1);
      engine.bytes = Uint8List.fromList([2]);
      expect(await service.captureToolPreview(id), [2]);
      expect(engine.captures, 2);
      final second = await service.captureToolPreview(id);
      expect(second, [2]);
      expect(first, [1]);
      expect(engine.captures, 3);
      expect(engine.resumes, resumes);
      expect(engine.viewBuilds, 0);
      final saved = await service.createTab(
        url: 'https://never-created.example',
      );
      expect(await service.captureToolPreview(saved.id), isNull);
      expect(engines.containsKey(saved.id), isFalse);
    },
  );

  previewTest(
    'slow historical capture never blocks tools or starts concurrent encoders',
    (tester) async {
      final id = await backgroundPage();
      final engine = engines[id]!;
      engine.pending = Completer<Uint8List?>();
      final preview = service.captureToolPreview(id);
      await tester.pump(const Duration(milliseconds: 501));
      expect(await preview, isNull);
      expect(service.agentPaused, isFalse);
      final again = service.captureToolPreview(id);
      await tester.pump(const Duration(milliseconds: 501));
      expect(await again, isNull);
      expect(engine.captures, 1);
      await service.navigate('https://next.example', tabId: id);
      engine.pending!.complete(Uint8List.fromList([3]));
      await tester.pump();
      expect(service.previewForTab(id), isNull);
    },
  );

  for (final failure in ['null', 'empty', 'oversized', 'error']) {
    previewTest('failed $failure capture never freezes earlier pixels', (
      tester,
    ) async {
      final id = await backgroundPage();
      final engine = engines[id]!;
      final first = await service.captureToolPreview(id);
      final pending = Completer<Uint8List?>();
      engine.pending = pending;
      final next = service.captureToolPreview(id);
      switch (failure) {
        case 'null':
          pending.complete(null);
        case 'empty':
          pending.complete(Uint8List(0));
        case 'oversized':
          pending.complete(Uint8List(2 * 1024 * 1024 + 1));
        case 'error':
          pending.completeError(StateError('renderer unavailable'));
      }
      expect(await next, isNull);
      expect(service.previewForTab(id), same(first));
      engine.pending = null;
      engine.bytes = Uint8List.fromList([2]);
      expect(await service.captureToolPreview(id), [2]);
    });
  }

  previewTest(
    'fast actions coalesce and the final snapshot updates at most once per second',
    (tester) async {
      final id = await backgroundPage();
      final engine = engines[id]!;
      final release = service.watchTabPreview(id);
      await tester.pump(const Duration(milliseconds: 160));
      for (var i = 0; i < 8; i++) {
        await service.runAgentAction<void>(
          sessionId: 'chat',
          label: 'scroll',
          tabId: id,
          action: () async {},
        );
      }
      engine.bytes = Uint8List.fromList([9]);
      await tester.pump(const Duration(milliseconds: 500));
      expect(engine.captures, 1);
      await tester.pump(const Duration(milliseconds: 510));
      expect(engine.captures, 2);
      expect(service.previewForTab(id), [9]);
      await tester.pump(const Duration(seconds: 4));
      expect(engine.captures, 2, reason: 'No permanent polling timer');
      release();
    },
  );

  previewTest('hidden cards and background app cancel queued preview work', (
    tester,
  ) async {
    final id = await backgroundPage();
    var release = service.watchTabPreview(id);
    release();
    await tester.pump(const Duration(seconds: 2));
    expect(engines[id]!.captures, 0);
    release = service.watchTabPreview(id);
    service.didChangeAppLifecycleState(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 2));
    expect(engines[id]!.captures, 0);
    service.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 160));
    expect(engines[id]!.captures, 1);
    release();
  });

  previewTest(
    'timed out encoder stays single flight and closed headless tabs discard late images',
    (tester) async {
      final id = await backgroundPage();
      final engine = engines[id]!;
      final pending = Completer<Uint8List?>();
      engine.pending = pending;
      final release = service.watchTabPreview(id);
      await tester.pump(const Duration(milliseconds: 160));
      await tester.pump(const Duration(seconds: 3));
      await service.runAgentAction<void>(
        sessionId: 'chat',
        label: 'click',
        tabId: id,
        action: () async {},
      );
      await tester.pump(const Duration(milliseconds: 160));
      expect(
        engine.captures,
        1,
        reason: 'Dart timeout must not start another native encoder',
      );
      await service.closeTab(id);
      pending.complete(Uint8List.fromList([8]));
      await tester.pump();
      expect(service.previewForTab(id), isNull);
      release();
    },
  );

  for (final hideApp in [true, false]) {
    previewTest(
      'waiting encoder does not start new work after ${hideApp ? "backgrounding" : "card removal"}',
      (tester) async {
        final id = await backgroundPage();
        final engine = engines[id]!;
        final pending = Completer<Uint8List?>();
        engine.pending = pending;
        final release = service.watchTabPreview(id);
        await tester.pump(const Duration(milliseconds: 160));
        await tester.pump(const Duration(seconds: 3));
        await service.runAgentAction<void>(
          sessionId: 'chat',
          label: 'scroll',
          tabId: id,
          action: () async {},
        );
        await tester.pump(const Duration(milliseconds: 1010));
        if (hideApp) {
          service.didChangeAppLifecycleState(AppLifecycleState.paused);
        } else {
          release();
        }
        engine.pending = null;
        pending.complete(Uint8List.fromList([8]));
        await tester.pump();
        expect(engine.captures, 1);
        release();
      },
    );
  }

  for (final navigate in [true, false]) {
    previewTest(
      'a timed-out native image is discarded before ${navigate ? "a new document" : "a fresh viewport"}',
      (tester) async {
        final tab = await service.createTab(url: 'https://one.example');
        await tester.pumpWidget(host());
        await tester.pumpAndSettle();
        final engine = engines[tab.id]!;
        final pending = Completer<Uint8List?>();
        engine.pending = pending;
        final old = service.refreshActivePreview();
        await tester.pump(const Duration(seconds: 3));
        await old;
        if (navigate) {
          await service.navigate('https://two.example', tabId: tab.id);
          engine.complete();
        }
        final fresh = service.refreshActivePreview(fresh: true);
        final captures = engine.captures;
        engine.pending = null;
        engine.bytes = Uint8List.fromList([9]);
        pending.complete(Uint8List.fromList([77]));
        await fresh;
        await tester.pumpAndSettle();
        expect(engine.captures, greaterThan(captures));
        expect(service.previewForTab(tab.id), [9]);
      },
    );
  }

  previewTest('many saved tabs keep thumbnails and native instances bounded', (
    tester,
  ) async {
    final ids = <String>[];
    for (var index = 0; index < 12; index++) {
      final tab = await service.createTab(
        url: 'https://page$index.example',
        ownerSessionId: 'chat-$index',
      );
      ids.add(tab.id);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      await service.refreshActivePreview(fresh: true);
      expect(service.liveViewCount, lessThanOrEqualTo(service.liveViewLimit));
    }
    expect(service.tabs, hasLength(12));
    expect(
      ids.where((id) => service.previewForTab(id) != null),
      hasLength(BrowserService.maxCachedPreviews),
    );
    expect(service.previewForTab(ids.first), isNull);
    expect(service.previewForTab(ids.last), isNotNull);
    await service.selectTab(ids.first);
    await tester.pumpAndSettle();
    await service.refreshActivePreview(fresh: true);
    expect(service.previewForTab(ids.first), isNotNull);
    expect(service.requireTab(ids.first).url, 'https://page0.example');
  });

  previewTest('Android thumbnails wait for a presented native view', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final ready = Completer<void>();
    nextViewReady = ready.future;
    final tab = await service.createTab(url: 'https://one.example');
    await tester.pumpWidget(host());
    await tester.pump();
    await tester.pump();
    final engine = engines[tab.id]!;
    await service.refreshActivePreview();
    expect(engine.captures, 0);
    expect(service.isTabPresented(tab.id), isFalse);
    ready.complete();
    await tester.pumpAndSettle();
    expect(service.isTabPresented(tab.id), isTrue);
    expect(engine.captures, 1);
    expect(service.previewForTab(tab.id), [1]);
  });

  previewTest('fresh overview capture waits past an older in-flight image', (
    tester,
  ) async {
    final tab = await service.createTab(url: 'https://one.example');
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    final engine = engines[tab.id]!;
    final pending = Completer<Uint8List?>();
    engine.pending = pending;
    final oldCapture = service.refreshActivePreview();
    final freshCapture = service.refreshActivePreview(fresh: true);
    final count = engine.captures;
    engine.pending = null;
    engine.bytes = Uint8List.fromList([3]);
    pending.complete(Uint8List.fromList([2]));
    await oldCapture;
    await freshCapture;
    expect(engine.captures, count + 1);
    expect(service.previewForTab(tab.id), [3]);
  });

  previewTest(
    'explicit overview captures visible pixels while resources still load',
    (tester) async {
      final tab = await service.createTab(url: 'https://one.example');
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      final engine = engines[tab.id]!;
      engine.emit(const BrowserPageState(isLoading: true));
      engine.bytes = Uint8List.fromList([4]);
      await service.refreshActivePreview();
      expect(service.previewForTab(tab.id), isNull);
      await service.refreshActivePreview(fresh: true);
      expect(service.previewForTab(tab.id), [4]);
    },
  );

  previewTest('load completion replaces an in-flight partial preview', (
    tester,
  ) async {
    final tab = await service.createTab(url: 'https://one.example');
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    final engine = engines[tab.id]!;
    engine.emit(const BrowserPageState(isLoading: true));
    final pending = Completer<Uint8List?>();
    engine.pending = pending;
    final partial = service.refreshActivePreview(fresh: true);
    final count = engine.captures;
    engine.complete();
    engine.pending = null;
    engine.bytes = Uint8List.fromList([5]);
    pending.complete(Uint8List.fromList([4]));
    await partial;
    await tester.pumpAndSettle();
    expect(engine.captures, count + 1);
    expect(service.previewForTab(tab.id), [5]);
  });

  previewTest('mobile native creation waits until route entry settles', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final tab = await service.createTab(url: 'https://one.example');
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              CupertinoPageRoute<void>(
                builder: (_) => service.buildView(tab.id),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      engines,
      isEmpty,
      reason: 'Do not create WKWebView in the entry animation.',
    );
    await tester.pumpAndSettle();
    expect(engines.length, 1);
  });

  previewTest(
    'covered tab selection defers new engine until motion is released',
    (tester) async {
      final tab = await service.createTab(url: 'https://one.example');
      Widget scene(bool defer) => Directionality(
        textDirection: TextDirection.ltr,
        child: service.buildViewport(deferNewViews: defer),
      );
      await tester.pumpWidget(scene(true));
      await tester.pumpAndSettle();
      expect(engines, isEmpty);
      await tester.pumpWidget(scene(false));
      await tester.pumpAndSettle();
      expect(engines.keys, [tab.id]);
    },
  );

  previewTest(
    'preview never creates a background engine and captures a loaded visit once',
    (tester) async {
      final tab = await service.createTab(url: 'https://one.example');
      await service.refreshActivePreview();
      expect(engines, isEmpty);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      final engine = engines[tab.id]!;
      expect(engine.captures, 1);
      expect(service.previewForTab(tab.id), [1]);
      engine.complete();
      engine.complete();
      for (var index = 0; index < 8; index++) {
        engine.emit(BrowserPageState(progress: index / 10));
      }
      await tester.pumpAndSettle();
      expect(engine.captures, 1);
      engine.emit(const BrowserPageState(isLoading: true));
      expect(service.previewForTab(tab.id), isNull);
      engine.complete();
      await tester.pumpAndSettle();
      expect(engine.captures, 2);
      await tester.pumpWidget(const SizedBox.shrink());
      await service.refreshActivePreview();
      expect(engine.captures, 2);
      expect(service.previewForTab(tab.id), [1]);
    },
  );

  previewTest(
    'new-tab and agent switches refresh the departing view without waiting',
    (tester) async {
      await service.updateSettings(
        service.settings.copyWith(agentEnabled: true),
      );
      final a = await service.createTab(
        url: 'https://one.example',
        ownerSessionId: 'chat',
      );
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      final first = engines[a.id]!;
      final b = await service.createTab(
        url: 'https://two.example',
        ownerSessionId: 'chat',
      );
      expect(first.captures, 2);
      await tester.pumpAndSettle();
      expect(service.previewForTab(a.id), [1]);
      final second = engines[b.id]!;
      final pending = Completer<Uint8List?>();
      second.pending = pending;
      await service.runAgentAction<void>(
        sessionId: 'chat',
        label: 'switch_tab',
        tabId: a.id,
        action: () => service.selectTab(a.id),
      );
      expect(service.activeTabId, a.id);
      expect(pending.isCompleted, isFalse);
      expect(second.captures, 2);
      second.pending = null;
      pending.complete(Uint8List.fromList([2]));
      await tester.pumpAndSettle();
      expect(service.previewForTab(a.id), [1]);
      expect(service.previewForTab(b.id), [2]);
      expect(engines.length, 2);
    },
  );

  for (final change in ['navigate', 'reload', 'POST', 'loadHtml']) {
    previewTest(
      '$change rejects a late old-document image and queues a fresh one',
      (tester) async {
        final tab = await service.createTab(url: 'https://one.example');
        await tester.pumpWidget(host());
        await tester.pumpAndSettle();
        final engine = engines[tab.id]!;
        final pending = Completer<Uint8List?>();
        engine.pending = pending;
        final oldCapture = service.refreshActivePreview();
        final duplicate = service.refreshActivePreview();
        expect(identical(oldCapture, duplicate), isTrue);
        expect(engine.captures, 2);
        switch (change) {
          case 'navigate':
            await service.navigate('https://two.example');
          case 'reload':
            await service.reload();
          case 'loadHtml':
            await service.loadHtml('<p>New document</p>', tabId: tab.id);
          case 'POST':
            engine.emit(const BrowserPageState(isLoading: true));
        }
        expect(service.previewForTab(tab.id), isNull);
        engine.complete();
        engine.bytes = Uint8List.fromList([9]);
        engine.pending = null;
        pending.complete(Uint8List.fromList([77]));
        await oldCapture;
        await tester.pumpAndSettle();
        expect(service.previewForTab(tab.id), [9]);
        expect(engine.captures, 3);
      },
    );
  }

  previewTest('closed tabs cannot be resurrected by a pending snapshot', (
    tester,
  ) async {
    final tab = await service.createTab(url: 'https://one.example');
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    final pending = Completer<Uint8List?>();
    engines[tab.id]!.pending = pending;
    final capture = service.refreshActivePreview();
    final closing = service.closeTab(tab.id);
    await tester.pump();
    await tester.pump();
    await closing;
    pending.complete(Uint8List.fromList([7]));
    await capture;
    expect(service.previewForTab(tab.id), isNull);
    expect(service.tabs, isEmpty);
  });

  previewTest('last-view thumbnail survives ordinary renderer eviction', (
    tester,
  ) async {
    final first = await service.createTab(url: 'https://one.example');
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    final firstEngine = engines[first.id]!;
    for (var index = 0; index < service.liveViewLimit; index++) {
      await service.createTab(url: 'https://$index.example');
      await tester.pumpAndSettle();
    }
    expect(firstEngine.disposed, isTrue);
    expect(service.previewForTab(first.id), [1]);
    expect(service.liveViewCount, service.liveViewLimit);
  });

  previewTest(
    'a hidden desktop pane does not capture background load completion',
    (tester) async {
      final tab = await service.createTab(url: 'https://one.example');
      var index = 0;
      late StateSetter update;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: StatefulBuilder(
            builder: (_, setState) {
              update = setState;
              return IndexedStack(
                index: index,
                children: [host(), const SizedBox.expand()],
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final engine = engines[tab.id]!;
      expect(engine.captures, 1);
      update(() => index = 1);
      await tester.pump();
      engine.emit(const BrowserPageState(isLoading: true));
      engine.complete();
      await service.refreshActivePreview();
      await tester.pump();
      expect(engine.captures, 1);
      update(() => index = 0);
      await tester.pumpAndSettle();
      expect(engine.captures, 2);
      expect(engines.length, 1);
    },
  );
  previewTest(
    'opaque management routes pause the retained viewport and skip background snapshots',
    (tester) async {
      final tab = await service.createTab(url: 'https://one.example');
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xff000000),
          navigatorKey: navigator,
          pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
            settings: settings,
            pageBuilder: (context, _, __) => builder(context),
          ),
          home: service.buildViewport(),
        ),
      );
      await tester.pumpAndSettle();
      final engine = engines[tab.id]!;
      expect(engine.visibility.last, isTrue);
      expect(engine.captures, 1);
      unawaited(
        navigator.currentState!.push<void>(
          PageRouteBuilder<void>(
            opaque: false,
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
            pageBuilder: (_, __, ___) => const SizedBox.expand(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // A transparent menu still samples the live page behind it.
      expect(engine.visibility.last, isTrue);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      unawaited(
        navigator.currentState!.push<void>(
          PageRouteBuilder<void>(
            transitionDuration: const Duration(milliseconds: 200),
            reverseTransitionDuration: Duration.zero,
            pageBuilder: (_, __, ___) => const SizedBox.expand(),
          ),
        ),
      );
      await tester.pump();
      expect(engine.visibility.last, isTrue);
      await tester.pumpAndSettle();
      expect(engine.visibility.last, isFalse);
      engine.emit(const BrowserPageState(isLoading: true));
      engine.complete();
      await service.refreshActivePreview();
      await tester.pump();
      expect(engine.captures, 1);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(engine.visibility.last, isTrue);
      expect(engine.captures, 2);
      expect(engine.viewBuilds, 1);
      expect(engines.length, 1);
      expect(tester.takeException(), isNull);
    },
  );
}

class _Store extends BrowserStore {
  @override
  Future<Map<String, dynamic>> read() async => {};
  @override
  Future<void> write(Map<String, Object?> state) async {}
}

class _Engine extends BrowserEngine {
  _Engine(this.emit, this.ready);
  final Future<void>? ready;
  @override
  Future<void> get viewReady => ready ?? Future<void>.value();
  final void Function(BrowserPageState) emit;
  int captures = 0;
  int resumes = 0;
  int viewBuilds = 0;
  final List<bool> visibility = [];
  bool disposed = false;
  Uint8List bytes = Uint8List.fromList([1]);
  Completer<Uint8List?>? pending;
  void complete() =>
      emit(const BrowserPageState(isLoading: false, completedNavigation: true));
  @override
  Widget buildView() {
    viewBuilds++;
    return const SizedBox.expand();
  }

  @override
  Future<void> setVisible(bool visible) async => visibility.add(visible);
  @override
  Future<Uint8List?> thumbnail() {
    captures++;
    return pending?.future ?? Future.value(bytes);
  }

  @override
  Future<Uint8List?> screenshot() async =>
      throw StateError('tool screenshot must not be used for previews');
  @override
  Future<void> navigate(String url) async {}
  @override
  Future<void> loadHtml(String html, {String? baseUrl}) async {}
  @override
  Future<void> reload() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {
    resumes++;
  }

  @override
  Future<void> updateSettings(dynamic settings) async {}
  @override
  Future<void> dispose() async {
    disposed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
