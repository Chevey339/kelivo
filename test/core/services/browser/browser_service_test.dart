import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/services/browser/browser_engine.dart';
import 'package:Kelivo/core/services/browser/browser_service.dart';
import 'package:Kelivo/core/services/browser/browser_store.dart';
import 'package:Kelivo/core/services/api/tool_call_cancellation.dart';
import 'package:Kelivo/features/browser/models/browser_models.dart';

class FakeBrowserEngine extends BrowserEngine {
  FakeBrowserEngine(this.tab, this.onChanged, {this.onDisposed});
  final void Function()? onDisposed;
  final BrowserTab tab;
  final void Function(BrowserPageState) onChanged;
  bool disposed = false;
  int viewBuilds = 0;
  int paints = 0;
  final List<bool> visibility = [];
  final List<String> navigations = [];
  final List<String> scripts = [];
  final List<String> htmlLoads = [];
  Completer<Object?>? evaluation;
  @override
  Widget buildView() {
    viewBuilds++;
    return CustomPaint(
      painter: _EnginePaintProbe(() => paints++),
      child: const SizedBox(key: ValueKey('fake-browser-engine')),
    );
  }

  @override
  Future<void> navigate(String url) async {
    navigations.add(url);
  }

  @override
  Future<void> loadHtml(String html, {String? baseUrl}) async {
    htmlLoads.add(html);
  }

  @override
  Future<void> back() async {}
  @override
  Future<void> forward() async {}
  @override
  Future<void> reload() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> waitForLoad(Duration timeout) async {}
  @override
  Future<Object?> evaluate(String source, {bool awaitPromise = false}) async {
    scripts.add(source);
    return evaluation == null ? 'complete' : evaluation!.future;
  }

  @override
  Future<Uint8List?> screenshot() async => Uint8List.fromList([1, 2, 3]);
  @override
  Future<void> updateSettings(BrowserSettings settings) async {}
  @override
  Future<void> find(String text) async {}
  @override
  Future<void> findNext(bool forward) async {}
  @override
  Future<void> clearFind() async {}
  @override
  Future<Map<String, String>> downloadHeaders(String url) async => {};
  @override
  Future<void> setVisible(bool visible) async => visibility.add(visible);
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> dispose() async {
    if (disposed) return;
    disposed = true;
    onDisposed?.call();
  }
}

class _EnginePaintProbe extends CustomPainter {
  _EnginePaintProbe(this.onPaint);
  final VoidCallback onPaint;
  @override
  void paint(Canvas canvas, Size size) {
    onPaint();
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xff123456),
    );
  }

  @override
  bool shouldRepaint(_EnginePaintProbe oldDelegate) => false;
}

class _RetryStore extends BrowserStore {
  bool failRead = true;
  int reads = 0;
  @override
  Future<Map<String, dynamic>> read() async {
    reads++;
    if (failRead) throw const FileSystemException('temporarily unavailable');
    return {};
  }

  @override
  Future<void> write(Map<String, Object?> state) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late BrowserService service;
  late Map<String, FakeBrowserEngine> engines;
  late List<String> disposedIds;
  late Map<String, Future<bool> Function(String?, int)> popupCallbacks;
  Completer<void>? popupCreating;
  Completer<void>? popupReady;

  BrowserService createService({BrowserStore? store}) => BrowserService(
    store: store ?? BrowserStore(directory: directory),
    supported: true,
    engineFactory:
        ({
          required tab,
          required settings,
          required onChanged,
          required onDownload,
          required onNewWindow,
          required isAgentActive,
        }) async {
          final engine = FakeBrowserEngine(
            tab,
            onChanged,
            onDisposed: () => disposedIds.add(tab.id),
          );
          engines[tab.id] = engine;
          popupCallbacks[tab.id] = Zone.current.bindBinaryCallback(onNewWindow);
          if (tab.windowId != null && popupReady != null) {
            popupCreating!.complete();
            await popupReady!.future;
          }
          return engine;
        },
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('kelivo-browser-core-');
    engines = {};
    disposedIds = [];
    popupCallbacks = {};
    popupCreating = null;
    popupReady = null;
    service = createService();
    await service.initialize();
  });
  tearDown(() async {
    await service.flush();
    service.dispose();
    await directory.delete(recursive: true);
  });

  test(
    'appearance settings preserve agent work; a UA reload hands control over',
    () async {
      await service.initialize();
      final tab = await service.createTab(
        url: 'https://example.com',
        ownerSessionId: 'chat-a',
      );
      final pending = Completer<void>();
      final started = Completer<void>();
      final outcome = service
          .runAgentAction<void>(
            sessionId: 'chat-a',
            tabId: tab.id,
            label: 'click',
            action: () {
              started.complete();
              return pending.future;
            },
          )
          .then<Object?>((_) => null, onError: (Object e) => e);
      await started.future;
      await service.updateSettings(
        service.settings.copyWith(surfaceStyle: BrowserSurfaceStyle.frosted),
      );
      expect(service.agentPaused, isFalse);
      await service.updateSettings(
        service.settings.copyWith(customUserAgent: 'Browser test UA'),
      );
      expect(service.agentPaused, isTrue);
      expect(service.pausedAgentSessionId, 'chat-a');
      pending.complete();
      expect(await outcome, isA<StateError>());
    },
  );

  test(
    'initial content mode follows the host OS and retains explicit choice',
    () async {
      expect(
        service.settings.desktopMode,
        Platform.isMacOS || Platform.isWindows || Platform.isLinux,
      );
      await service.updateSettings(
        service.settings.copyWith(desktopMode: false),
      );
      await service.flush();
      service.dispose();
      service = createService();
      await service.initialize();
      expect(service.settings.desktopMode, isFalse);
    },
  );

  test(
    'solid is the default without overriding a saved material choice',
    () async {
      expect(const BrowserSettings().surfaceStyle, BrowserSurfaceStyle.solid);
      expect(
        BrowserSettings.fromJson({}).surfaceStyle,
        BrowserSurfaceStyle.solid,
      );
      expect(
        BrowserSettings.fromJson({'surfaceStyle': 'unknown'}).surfaceStyle,
        BrowserSurfaceStyle.solid,
      );
      for (final style in BrowserSurfaceStyle.values) {
        expect(
          BrowserSettings.fromJson({'surfaceStyle': style.name}).surfaceStyle,
          style,
        );
      }
      await service.updateSettings(
        service.settings.copyWith(surfaceStyle: BrowserSurfaceStyle.frosted),
      );
      service.dispose();
      service = createService();
      await service.initialize();
      expect(service.settings.surfaceStyle, BrowserSurfaceStyle.frosted);
    },
  );

  test('assistant access defaults on but preserves a saved opt-out', () async {
    expect(service.settings.agentEnabled, isTrue);
    expect(const BrowserSettings().agentEnabled, isTrue);
    expect(BrowserSettings.fromJson({}).agentEnabled, isTrue);
    await service.updateSettings(
      service.settings.copyWith(agentEnabled: false),
    );
    service.dispose();
    service = createService();
    await service.initialize();
    expect(service.settings.agentEnabled, isFalse);
  });

  test(
    'custom UA persists, resets to presets and rejects invalid header characters',
    () async {
      await service.updateSettings(
        service.settings.copyWith(customUserAgent: '  Kelivo-Test/1.0  '),
      );
      service.dispose();
      service = createService();
      await service.initialize();
      expect(service.settings.customUserAgent, 'Kelivo-Test/1.0');
      for (final invalid in [
        'Bad\r\nInjected: value',
        'Bad\u0000UA',
        'Kelivo/测试',
        'Kelivo/😀',
        'Kelivo/é',
        'x' * 2049,
      ]) {
        await expectLater(
          service.updateSettings(
            service.settings.copyWith(customUserAgent: invalid),
          ),
          throwsFormatException,
        );
        expect(service.settings.customUserAgent, 'Kelivo-Test/1.0');
        expect(
          BrowserSettings.fromJson({
            'customUserAgent': invalid,
          }).customUserAgent,
          isEmpty,
        );
      }
      await service.updateSettings(
        service.settings.copyWith(customUserAgent: '', desktopMode: false),
      );
      service.dispose();
      service = createService();
      await service.initialize();
      expect(service.settings.customUserAgent, isEmpty);
      expect(service.settings.desktopMode, isFalse);
    },
  );

  test(
    'missing desktop mode uses the caller default without overriding false',
    () {
      expect(
        BrowserSettings.fromJson({}, defaultDesktopMode: true).desktopMode,
        isTrue,
      );
      expect(
        BrowserSettings.fromJson({}, defaultDesktopMode: false).desktopMode,
        isFalse,
      );
      expect(
        BrowserSettings.fromJson({
          'desktopMode': false,
        }, defaultDesktopMode: true).desktopMode,
        isFalse,
      );
      expect(
        BrowserSettings.fromJson({
          'desktopMode': true,
        }, defaultDesktopMode: false).desktopMode,
        isTrue,
      );
    },
  );

  test(
    'initialization can retry after a transient storage read failure',
    () async {
      service.dispose();
      final store = _RetryStore();
      service = BrowserService(store: store, supported: true);
      await expectLater(
        service.initialize(),
        throwsA(isA<FileSystemException>()),
      );
      store.failRead = false;
      await service.initialize();
      expect(service.isInitialized, isTrue);
      expect(store.reads, 2);
    },
  );

  test(
    'address normalization distinguishes URLs, search, and unsafe schemes',
    () {
      expect(
        BrowserService.normalizeAddress('example.com/path?q=two'),
        'https://example.com/path?q=two',
      );
      expect(
        BrowserService.normalizeAddress('localhost:8080/demo'),
        'http://localhost:8080/demo',
      );
      expect(
        BrowserService.normalizeAddress('127.0.0.1:3000'),
        'http://127.0.0.1:3000',
      );
      expect(
        BrowserService.normalizeAddress('example.com:8080/demo'),
        'https://example.com:8080/demo',
      );
      expect(
        BrowserService.normalizeAddress(
          '  中文 search  ',
          searchEngine: BrowserSearchEngine.duckDuckGo,
        ),
        Uri.https('duckduckgo.com', '/', {'q': '中文 search'}).toString(),
      );
      for (final input in [
        'javascript:alert(1)',
        'file:///etc/passwd',
        'data:text/html,hi',
        'https://name:password@example.com',
      ]) {
        expect(
          () => BrowserService.normalizeAddress(input),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'bookmarks, unique history, active stable IDs and preferences survive restoration',
    () async {
      final first = await service.createTab(
        url: 'https://one.example',
        ownerSessionId: 'chat-a',
      );
      final second = await service.createTab(url: 'https://two.example');
      await service.selectTab(first.id);
      await service.navigate('https://one.example', tabId: first.id);
      engines[first.id]!.onChanged(
        const BrowserPageState(
          url: 'https://one.example',
          title: 'One',
          isLoading: false,
          completedNavigation: true,
        ),
      );
      engines[first.id]!.onChanged(
        const BrowserPageState(
          url: 'https://one.example',
          title: 'One updated',
          isLoading: false,
          completedNavigation: true,
        ),
      );
      await service.addBookmark(url: first.url, title: 'Saved');
      await service.updateSettings(
        service.settings.copyWith(
          searchEngine: BrowserSearchEngine.google,
          desktopMode: true,
        ),
      );
      await service.flush();
      service.dispose();
      service = createService();
      await service.initialize();
      expect(service.tabs.map((tab) => tab.id), [first.id, second.id]);
      expect(service.activeTabId, first.id);
      expect(service.tabs.first.ownerSessionId, 'chat-a');
      expect(service.bookmarks.single.title, 'Saved');
      expect(service.history.single.title, 'One updated');
      expect(service.settings.searchEngine, BrowserSearchEngine.google);
      expect(service.settings.desktopMode, isTrue);
      expect(service.liveViewCount, 0);
    },
  );

  test('saved tabs exceed eight without allocating native views', () async {
    for (var index = 0; index < 12; index++) {
      await service.createTab(url: 'https://$index.example');
    }
    final ids = service.tabs.map((tab) => tab.id).toList();
    expect(service.tabs, hasLength(12));
    expect(service.liveViewCount, 0);
    await service.flush();
    service.dispose();
    service = createService();
    await service.initialize();
    expect(service.tabs.map((tab) => tab.id), ids);
    await service.closeTab(ids[3]);
    expect(service.tabs.map((tab) => tab.id), ids.where((id) => id != ids[3]));
    expect(service.activeTabId, ids.last);
  });

  test(
    'conversation selection is lazy and remembers each conversation across restart',
    () async {
      final a = await service.createTab(ownerSessionId: 'a');
      await service.createTab(ownerSessionId: 'a');
      final b = await service.createTab(ownerSessionId: 'b');
      await service.selectTab(a.id);
      await service.selectSession('new-chat');
      expect(service.activeTab, isNull);
      expect(service.tabs, hasLength(3));
      expect(service.liveViewCount, 0);
      await service.selectSession('b');
      expect(service.activeTabId, b.id);
      await service.flush();
      service.dispose();
      service = createService();
      await service.initialize();
      await service.selectSession('a');
      expect(service.activeTabId, a.id);
      expect(service.requireAgentTab('a', null).id, a.id);
      await service.closeTab(a.id);
      expect(service.activeTab!.ownerSessionId, 'a');
      await service.closeTab(service.activeTabId!);
      expect(service.activeTabId, isNull);
      expect(service.tabs.single.id, b.id);
    },
  );

  test('agent quota is per conversation and does not cap user tabs', () async {
    Future<BrowserTab> agentTab(String owner) => service.runAgentAction(
      sessionId: owner,
      label: 'new_tab',
      action: () => service.createTab(ownerSessionId: owner),
    );
    for (var i = 0; i < BrowserService.maxAgentTabsPerSession; i++) {
      await agentTab('a');
    }
    await expectLater(
      agentTab('a'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('browser_session_tab_limit'),
        ),
      ),
    );
    final b = await agentTab('b');
    expect(b.ownerSessionId, 'b');
    await service.createTab(ownerSessionId: 'a');
    expect(service.tabsForSession('a'), hasLength(4));
    expect(service.liveViewCount, 0);
  });

  test('native agent popups share the conversation quota', () async {
    final parent = await service.createTab(
      url: 'https://parent.example',
      ownerSessionId: 'a',
    );
    await service.createTab(ownerSessionId: 'a');
    await service.evaluateJavascript('ready', tabId: parent.id);
    final started = Completer<void>();
    final finish = Completer<void>();
    final running = service.runAgentAction(
      sessionId: 'a',
      label: 'click',
      tabId: parent.id,
      action: () async {
        started.complete();
        await finish.future;
      },
    );
    await started.future;
    try {
      expect(await popupCallbacks[parent.id]!(null, 42), isTrue);
      final child = service.tabs.last;
      expect(service.tabsForSession('a'), hasLength(3));
      expect(await popupCallbacks[parent.id]!(null, 43), isFalse);
      expect(await popupCallbacks[child.id]!(null, 44), isFalse);
      expect(service.tabsForSession('a'), hasLength(3));
      expect(service.liveViewCount, 2);
    } finally {
      finish.complete();
      await running;
      await Future<void>.delayed(Duration.zero);
    }
    // A later user popup is not constrained by an old agent action's guard.
    expect(await popupCallbacks[parent.id]!(null, 45), isTrue);
    expect(service.tabsForSession('a'), hasLength(4));
    expect(service.liveViewCount, 3);
  });

  test(
    'late native popup completion cannot retarget the next agent action',
    () async {
      final parent = await service.createTab(
        url: 'https://parent.example',
        ownerSessionId: 'a',
      );
      final other = await service.createTab(ownerSessionId: 'b');
      await service.evaluateJavascript('ready', tabId: parent.id);
      popupCreating = Completer<void>();
      popupReady = Completer<void>();
      final firstStarted = Completer<void>();
      final firstFinish = Completer<void>();
      final first = service.runAgentAction(
        sessionId: 'a',
        label: 'click',
        tabId: parent.id,
        action: () async {
          firstStarted.complete();
          await firstFinish.future;
        },
      );
      await firstStarted.future;
      final popup = popupCallbacks[parent.id]!(null, 42);
      await popupCreating!.future;
      firstFinish.complete();
      await first;
      final nextStarted = Completer<void>();
      final nextFinish = Completer<void>();
      final next = service.runAgentAction(
        sessionId: 'b',
        label: 'wait',
        tabId: other.id,
        action: () async {
          nextStarted.complete();
          await nextFinish.future;
        },
      );
      await nextStarted.future;
      try {
        popupReady!.complete();
        expect(await popup, isTrue);
        expect(service.agentSessionId, 'b');
        expect(service.agentTabId, other.id);
        expect(service.activeTabId, other.id);
        expect(service.selectedTabForSession('b')!.id, other.id);
        expect(service.tabsForSession('a'), hasLength(2));
      } finally {
        nextFinish.complete();
        await next;
      }
    },
  );

  test(
    'background agent selection does not replace another chat viewport',
    () async {
      final a = await service.createTab(ownerSessionId: 'a');
      final b = await service.createTab(ownerSessionId: 'b');
      final secondA = await service.runAgentAction(
        sessionId: 'a',
        label: 'new_tab',
        action: () => service.createTab(ownerSessionId: 'a'),
      );
      expect(service.activeTabId, b.id);
      expect(service.requireAgentTab('a', null).id, secondA.id);
      await service.runAgentAction(
        sessionId: 'a',
        label: 'switch_tab',
        action: () => service.selectTab(a.id),
      );
      expect(service.activeTabId, b.id);
      await service.selectSession('empty');
      await service.runAgentAction(
        sessionId: 'a',
        label: 'switch_tab',
        action: () => service.selectTab(secondA.id),
      );
      expect(service.activeTab, isNull);
      await service.selectSession('a');
      expect(service.activeTabId, secondA.id);
    },
  );

  test(
    'explicit handoff moves popup family without recreating its pages',
    () async {
      final a = await service.createTab(
        url: 'https://a.example',
        ownerSessionId: 'a',
      );
      await service.evaluateJavascript('ready', tabId: a.id);
      expect(await popupCallbacks[a.id]!(null, 42), isTrue);
      final child = service.activeTab!;
      final rootEngine = engines[a.id];
      await service.moveTabToSession(child.id, 'b');
      expect(service.tabsForSession('a'), isEmpty);
      expect(service.tabsForSession('b'), hasLength(2));
      expect(service.requireAgentTab('b', child.id).id, child.id);
      expect(() => service.requireAgentTab('a', a.id), throwsStateError);
      expect(engines[a.id], same(rootEngine));
      expect(rootEngine!.disposed, isFalse);
      expect(await popupCallbacks[a.id]!(null, 43), isTrue);
      expect(service.tabs.last.ownerSessionId, 'b');
      expect(service.activeTabId, child.id);
      await service.flush();
      service.dispose();
      service = createService();
      await service.initialize();
      expect(service.tabs.every((tab) => tab.ownerSessionId == 'b'), isTrue);
    },
  );

  test('handoff preserves a failed page until it is retried', () async {
    final tab = await service.createTab(
      url: 'https://failed.example',
      ownerSessionId: 'a',
    );
    await service.evaluateJavascript('ready', tabId: tab.id);
    final engine = engines[tab.id]!;
    engine.onChanged(const BrowserPageState(error: 'connection_failed'));
    expect(service.requireTab(tab.id).error, 'connection_failed');
    await service.moveTabToSession(tab.id, 'b');
    expect(service.requireTab(tab.id).ownerSessionId, 'b');
    expect(service.requireTab(tab.id).error, 'connection_failed');
    expect(engines[tab.id], same(engine));
    expect(engine.disposed, isFalse);
    await service.refreshActivePreview();
    expect(service.previewForTab(tab.id), isNull);
  });

  test(
    'busy tab cannot be transferred or reclaimed by another conversation',
    () async {
      final a = await service.createTab(
        url: 'https://a.example',
        ownerSessionId: 'a',
      );
      final started = Completer<void>();
      final finish = Completer<void>();
      final running = service.runAgentAction(
        sessionId: 'a',
        label: 'wait',
        tabId: a.id,
        action: () async {
          await service.evaluateJavascript('ready', tabId: a.id);
          started.complete();
          await finish.future;
        },
      );
      await started.future;
      await expectLater(service.moveTabToSession(a.id, 'b'), throwsStateError);
      for (var i = 0; i < 3; i++) {
        final tab = await service.createTab(
          url: 'https://$i.example',
          ownerSessionId: 'b',
        );
        await service.evaluateJavascript('ready', tabId: tab.id);
      }
      expect(service.liveViewCount, BrowserService.maxLiveViews);
      expect(engines[a.id]!.disposed, isFalse);
      expect(service.requireTab(a.id).ownerSessionId, 'a');
      expect(service.agentSessionId, 'a');
      finish.complete();
      await running;
      await Future<void>.delayed(Duration.zero);
      await service.moveTabToSession(a.id, 'b');
      expect(service.requireTab(a.id).ownerSessionId, 'b');
      await expectLater(
        service.runAgentAction(
          sessionId: 'b',
          label: 'move',
          action: () => service.moveTabToSession(a.id, 'c'),
        ),
        throwsStateError,
      );
    },
  );

  test(
    'takeover keeps a cancelled native action protected until it settles',
    () async {
      final tab = await service.createTab(
        url: 'https://busy.example',
        ownerSessionId: 'a',
      );
      final started = Completer<void>();
      final finish = Completer<void>();
      final running = service.runAgentAction(
        sessionId: 'a',
        label: 'wait',
        tabId: tab.id,
        action: () async {
          await service.evaluateJavascript('ready', tabId: tab.id);
          started.complete();
          await finish.future;
        },
      );
      final cancelled = expectLater(running, throwsStateError);
      await started.future;
      service.takeOver(sessionId: 'a', tabId: tab.id);
      await cancelled;
      for (var i = 0; i < 3; i++) {
        final other = await service.createTab(
          url: 'https://$i.example',
          ownerSessionId: 'b',
        );
        await service.evaluateJavascript('ready', tabId: other.id);
      }
      expect(service.liveViewCount, BrowserService.maxLiveViews);
      expect(engines[tab.id]!.disposed, isFalse);
      await expectLater(
        service.moveTabToSession(tab.id, 'b'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'browser_tab_busy',
          ),
        ),
      );
      finish.complete();
      await Future<void>.delayed(Duration.zero);
      await service.moveTabToSession(tab.id, 'b');
      expect(service.requireTab(tab.id).ownerSessionId, 'b');
    },
  );

  test('a queued action loses access when the user moves its tab', () async {
    final old = await service.createTab(ownerSessionId: 'old-chat');
    final busy = await service.createTab(ownerSessionId: 'busy-chat');
    final started = Completer<void>();
    final finish = Completer<void>();
    final first = service.runAgentAction(
      sessionId: 'busy-chat',
      label: 'wait',
      tabId: busy.id,
      action: () async {
        started.complete();
        await finish.future;
      },
    );
    await started.future;
    var called = false;
    final queued = service.runAgentAction(
      sessionId: 'old-chat',
      label: 'evaluate',
      tabId: old.id,
      action: () async {
        called = true;
      },
    );
    final rejected = expectLater(
      queued,
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'browser_tab_not_owned',
        ),
      ),
    );
    await service.moveTabToSession(old.id, 'new-chat');
    finish.complete();
    await first;
    await rejected;
    expect(called, isFalse);
    expect(service.requireAgentTab('new-chat', old.id).id, old.id);
  });

  test('popup handoff waits for a closed but retained parent action', () async {
    final parent = await service.createTab(
      url: 'https://parent.example',
      ownerSessionId: 'a',
    );
    await service.evaluateJavascript('ready', tabId: parent.id);
    await popupCallbacks[parent.id]!(null, 42);
    final child = service.activeTab!;
    final started = Completer<void>();
    final finish = Completer<void>();
    final running = service.runAgentAction(
      sessionId: 'a',
      label: 'wait',
      tabId: parent.id,
      action: () async {
        started.complete();
        await finish.future;
      },
    );
    await started.future;
    try {
      await service.closeTab(parent.id);
      expect(engines[parent.id]!.disposed, isFalse);
      await expectLater(
        service.moveTabToSession(child.id, 'b'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'browser_tab_busy',
          ),
        ),
      );
      expect(service.requireTab(child.id).ownerSessionId, 'a');
    } finally {
      finish.complete();
      await running;
      await Future<void>.delayed(Duration.zero);
    }
    await service.moveTabToSession(child.id, 'b');
    expect(service.requireTab(child.id).ownerSessionId, 'b');
  });

  test(
    'native views are created lazily and evict the least recently used view',
    () async {
      final tabs = <BrowserTab>[];
      for (var index = 0; index < 4; index++) {
        tabs.add(await service.createTab(url: 'https://$index.example'));
      }
      expect(engines, isEmpty);
      for (final tab in tabs) {
        await service.evaluateJavascript('document.title', tabId: tab.id);
      }
      expect(service.liveViewCount, BrowserService.maxLiveViews);
      expect(engines[tabs.first.id]!.disposed, isTrue);
      expect(service.tabs, hasLength(4));
      expect(service.requireTab(tabs.first.id).url, 'https://0.example');
    },
  );

  test('first navigation does not request the URL twice', () async {
    final tab = await service.createTab();
    await service.navigate('https://first.example', tabId: tab.id);
    expect(engines[tab.id]!.tab.url, 'https://first.example');
    expect(engines[tab.id]!.navigations, isEmpty);
    await service.navigate('https://second.example', tabId: tab.id);
    expect(engines[tab.id]!.navigations, ['https://second.example']);
  });

  test('a second address entered during native creation is not lost', () async {
    service.dispose();
    final creating = Completer<void>();
    final created = Completer<BrowserEngine>();
    FakeBrowserEngine? engine;
    service = BrowserService(
      store: BrowserStore(directory: directory),
      supported: true,
      engineFactory:
          ({
            required tab,
            required settings,
            required onChanged,
            required onDownload,
            required onNewWindow,
            required isAgentActive,
          }) {
            engine = FakeBrowserEngine(tab, onChanged);
            creating.complete();
            return created.future;
          },
    );
    final tab = await service.createTab();
    final first = service.navigate('https://first.example', tabId: tab.id);
    await creating.future;
    final second = service.navigate('https://second.example', tabId: tab.id);
    created.complete(engine!);
    await Future.wait([first, second]);
    expect(engine!.navigations, ['https://second.example']);
    expect(service.requireTab(tab.id).url, 'https://second.example');
  });

  test(
    'takeover during engine creation disposes the late native engine',
    () async {
      service.dispose();
      final creating = Completer<void>();
      final created = Completer<BrowserEngine>();
      FakeBrowserEngine? engine;
      service = BrowserService(
        store: BrowserStore(directory: directory),
        supported: true,
        engineFactory:
            ({
              required tab,
              required settings,
              required onChanged,
              required onDownload,
              required onNewWindow,
              required isAgentActive,
            }) {
              engine = FakeBrowserEngine(tab, onChanged);
              creating.complete();
              return created.future;
            },
      );
      final tab = await service.createTab(ownerSessionId: 'a');
      await service.updateSettings(
        service.settings.copyWith(agentEnabled: true),
      );
      final running = service.runAgentAction(
        sessionId: 'a',
        label: 'create',
        action: () => service.evaluateJavascript('read', tabId: tab.id),
      );
      final cancelled = expectLater(running, throwsStateError);
      await creating.future;
      service.takeOver();
      await cancelled;
      created.complete(engine!);
      await Future<void>.delayed(Duration.zero);
      expect(engine!.disposed, isTrue);
      expect(service.liveViewCount, 0);
      expect(engine!.scripts, isEmpty);
    },
  );

  test('an old completed call cancellation cannot cancel a new call', () async {
    final tab = await service.createTab(ownerSessionId: 'a');
    await service.updateSettings(service.settings.copyWith(agentEnabled: true));
    final cancellation = Completer<void>();
    var cancelled = false;
    final token = ToolCallCancellation(
      isCancelled: () => cancelled,
      cancelled: cancellation.future,
    );
    await token.run(
      () => service.runAgentAction(
        sessionId: 'a',
        label: 'first',
        action: () => service.evaluateJavascript('first', tabId: tab.id),
      ),
    );
    // Wait for queue cleanup, which may finish after delivery of the result.
    await Future<void>.delayed(Duration.zero);
    final epoch = service.controlEpoch;
    cancelled = true;
    cancellation.complete();
    await Future<void>.delayed(Duration.zero);
    expect(
      await service.runAgentAction(
        sessionId: 'a',
        label: 'next',
        action: () => service.evaluateJavascript('next', tabId: tab.id),
      ),
      'complete',
    );
    expect(service.controlEpoch, epoch);
    expect(service.agentPaused, isFalse);
  });

  test(
    'disabling session restore retains bookmarks but no tabs on disk',
    () async {
      await service.createTab(url: 'https://example.com');
      await service.addBookmark(url: 'https://example.com', title: 'Example');
      await service.updateSettings(
        service.settings.copyWith(restoreTabs: false),
      );
      service.dispose();
      service = createService();
      await service.initialize();
      expect(service.tabs, isEmpty);
      expect(service.bookmarks, hasLength(1));
    },
  );

  test(
    'conversation ownership guards native operations inside the action zone',
    () async {
      final a = await service.createTab(ownerSessionId: 'a');
      final b = await service.createTab(ownerSessionId: 'b');
      await service.updateSettings(
        service.settings.copyWith(agentEnabled: true),
      );
      expect(service.requireAgentTab('a', null).id, a.id);
      await expectLater(
        service.runAgentAction(
          sessionId: 'a',
          label: 'read',
          action: () =>
              service.evaluateJavascript('document.cookie', tabId: b.id),
        ),
        throwsStateError,
      );
      expect(engines, isEmpty);
    },
  );

  test(
    'takeover rejects queued calls and keeps serialization until native settlement',
    () async {
      final tab = await service.createTab(ownerSessionId: 'a');
      await service.updateSettings(
        service.settings.copyWith(agentEnabled: true),
      );
      await service.evaluateJavascript('prepare', tabId: tab.id);
      final engine = engines[tab.id]!;
      engine.evaluation = Completer<Object?>();
      final first = service.runAgentAction(
        sessionId: 'a',
        label: 'first',
        action: () => service.evaluateJavascript('first', tabId: tab.id),
      );
      final firstExpectation = expectLater(first, throwsStateError);
      await Future<void>.delayed(Duration.zero);
      final queued = service.runAgentAction(
        sessionId: 'a',
        label: 'queued',
        action: () => service.evaluateJavascript('queued', tabId: tab.id),
      );
      final queuedExpectation = expectLater(queued, throwsStateError);
      service.takeOver();
      await firstExpectation;
      service.allowAgentControl();
      final next = service.runAgentAction(
        sessionId: 'a',
        label: 'next',
        action: () => service.evaluateJavascript('next', tabId: tab.id),
      );
      await Future<void>.delayed(Duration.zero);
      expect(engine.scripts, ['prepare', 'first']);
      final pending = engine.evaluation!;
      engine.evaluation = null;
      pending.complete('settled');
      await queuedExpectation;
      expect(await next, 'complete');
      expect(engine.scripts, ['prepare', 'first', 'next']);
    },
  );

  test(
    'concurrent persistence writes retain the newest complete snapshot',
    () async {
      final store = BrowserStore(directory: directory);
      await Future.wait([
        for (var index = 0; index < 20; index++)
          store.write({
            'index': index,
            'tabs': [index],
          }),
      ]);
      expect(await store.read(), {
        'version': 1,
        'index': 19,
        'tabs': [19],
      });
      expect(File('${directory.path}/state.json.tmp').existsSync(), isFalse);
    },
  );
  test(
    'popup native window ID and conversation ownership are retained',
    () async {
      final parent = await service.createTab(
        url: 'https://parent.example',
        ownerSessionId: 'chat',
      );
      await service.evaluateJavascript('prepare', tabId: parent.id);
      expect(await popupCallbacks[parent.id]!(null, 42), isTrue);
      final child = service.activeTab!;
      expect(child.ownerSessionId, 'chat');
      expect(child.hasContent, isTrue);
      expect(engines[child.id]!.tab.windowId, 42);
      expect(child.windowId, isNull);
      for (var index = 0; index < 8; index++) {
        await service.createTab(ownerSessionId: 'other-$index');
      }
      expect(
        await popupCallbacks[parent.id]!('https://popup.example', 43),
        isTrue,
      );
      final third = service.tabs.last;
      expect(service.activeTab!.ownerSessionId, 'other-7');
      expect(third.ownerSessionId, 'chat');
      expect(service.liveViewCount, BrowserService.maxLiveViews);
      expect(
        await popupCallbacks[parent.id]!('https://overflow.example', 44),
        isFalse,
      );
      expect(service.liveViewCount, BrowserService.maxLiveViews);
      await service.closeTab(third.id);
      await service.selectTab(child.id);
      engines[child.id]!.onChanged(
        const BrowserPageState(closeRequested: true),
      );
      await Future<void>.delayed(Duration.zero);
      expect(service.tabs.any((tab) => tab.id == child.id), isFalse);
      expect(service.activeTabId, parent.id);
    },
  );

  test(
    'renderer termination recreates its engine without changing the tab identity',
    () async {
      final tab = await service.createTab(url: 'https://example.com');
      await service.evaluateJavascript('prepare', tabId: tab.id);
      final old = engines[tab.id]!;
      old.onChanged(
        const BrowserPageState(
          isLoading: false,
          rendererTerminated: true,
          error: 'browser_renderer_terminated',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(old.disposed, isTrue);
      expect(service.requireTab(tab.id).runtimeVersion, 1);
      await service.reload(tabId: tab.id);
      expect(engines[tab.id], isNot(same(old)));
      expect(service.tabs.single.id, tab.id);
      // A late event from the dead engine must not overwrite the replacement.
      old.onChanged(const BrowserPageState(url: 'https://stale.example'));
      expect(service.tabs.single.url, 'https://example.com');
    },
  );

  test(
    'following a link from rendered HTML does not replay the old render after eviction',
    () async {
      final tab = await service.createTab();
      await service.loadHtml(
        '<a href="https://destination.example">Continue</a>',
        tabId: tab.id,
      );
      final original = engines[tab.id]!;
      original.onChanged(
        const BrowserPageState(
          url: 'https://destination.example',
          isLoading: true,
        ),
      );
      expect(service.requireTab(tab.id).hasContent, isFalse);
      for (var index = 0; index < 3; index++) {
        final other = await service.createTab(
          url: 'https://other$index.example',
        );
        await service.evaluateJavascript('prepare', tabId: other.id);
      }
      expect(original.disposed, isTrue);
      await service.selectTab(tab.id);
      await service.evaluateJavascript('prepare', tabId: tab.id);
      expect(engines[tab.id]!.tab.url, 'https://destination.example');
      expect(engines[tab.id]!.htmlLoads, isEmpty);
    },
  );

  test(
    'popup family cleanup waits for surviving renderer task acknowledgements',
    () async {
      final parent = await service.createTab(url: 'https://parent.example');
      await service.evaluateJavascript('prepare', tabId: parent.id);
      await popupCallbacks[parent.id]!('https://child.example', 1);
      final child = service.activeTab!;
      await popupCallbacks[child.id]!('https://grandchild.example', 2);
      final grandchild = service.activeTab!;
      expect(child.popupGroupId, parent.id);
      expect(grandchild.popupGroupId, parent.id);
      final childEngine = engines[child.id]!;
      childEngine.evaluation = Completer<Object?>();
      final closing = service.closeTab(parent.id);
      await Future<void>.delayed(Duration.zero);
      expect(engines[parent.id]!.disposed, isFalse);
      expect(childEngine.scripts.last, contains('setTimeout'));
      expect(engines[grandchild.id]!.scripts.last, contains('setTimeout'));
      childEngine.evaluation!.complete(true);
      childEngine.evaluation = null;
      await closing;
      expect(engines[parent.id]!.disposed, isFalse);
      expect(engines[parent.id]!.navigations.last, 'about:blank');
      expect(service.liveViewCount, 3);
      expect(service.tabs.map((tab) => tab.id), [child.id, grandchild.id]);
      await expectLater(
        service.evaluateJavascript('document.body', tabId: parent.id),
        throwsStateError,
      );
      await expectLater(
        service.navigate('https://closed.example', tabId: parent.id),
        throwsStateError,
      );
      expect(engines[parent.id]!.navigations.last, 'about:blank');
      await service.closeTab(child.id);
      expect(engines[parent.id]!.disposed, isFalse);
      await service.closeTab(grandchild.id);
      expect(engines[parent.id]!.disposed, isTrue);
      expect(disposedIds, [child.id, grandchild.id, parent.id]);
      expect(service.liveViewCount, 0);
    },
  );

  test(
    'LRU releases a popup family together and restores tabs independently',
    () async {
      final parent = await service.createTab(url: 'https://parent.example');
      await service.evaluateJavascript('prepare', tabId: parent.id);
      await popupCallbacks[parent.id]!('https://child.example', 1);
      final child = service.activeTab!;
      await popupCallbacks[child.id]!('https://grandchild.example', 2);
      final grandchild = service.activeTab!;
      expect(
        await popupCallbacks[grandchild.id]!('https://fourth.example', 3),
        isFalse,
      );
      expect(disposedIds, isEmpty);
      final other = await service.createTab(url: 'https://other.example');
      await service.evaluateJavascript('prepare', tabId: other.id);
      expect(service.liveViewCount, 1);
      expect(disposedIds, [child.id, grandchild.id, parent.id]);
      expect(service.requireTab(child.id).popupGroupId, isNull);
      await service.selectTab(child.id);
      await service.evaluateJavascript('prepare', tabId: child.id);
      expect(engines[child.id]!.tab.windowId, isNull);
      expect(engines[child.id]!.tab.url, 'https://child.example');
    },
  );

  test(
    'a crashed popup can reopen after its previous family is evicted',
    () async {
      final parent = await service.createTab(url: 'https://parent.example');
      await service.evaluateJavascript('prepare', tabId: parent.id);
      await popupCallbacks[parent.id]!('https://child.example', 1);
      final child = service.activeTab!;
      final third = await service.createTab(url: 'https://third.example');
      await service.evaluateJavascript('prepare', tabId: third.id);
      engines[child.id]!.onChanged(
        const BrowserPageState(
          rendererTerminated: true,
          isLoading: false,
          error: 'browser_renderer_terminated',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      final fourth = await service.createTab(url: 'https://fourth.example');
      await service.evaluateJavascript('prepare', tabId: fourth.id);
      await service.selectTab(child.id);
      expect(
        await service.evaluateJavascript('document.title', tabId: child.id),
        'complete',
      );
      expect(engines[parent.id]!.disposed, isTrue);
      expect(service.requireTab(child.id).popupGroupId, isNull);
      expect(
        engines[child.id]!.tab.runtimeVersion,
        service.requireTab(child.id).runtimeVersion,
      );
      expect(service.liveViewCount, 3);
    },
  );

  testWidgets(
    'switching away from a full popup family admits the replacement view',
    (tester) async {
      service.dispose();
      service = createService(store: _RetryStore()..failRead = false);
      await service.initialize();
      final parent = await service.createTab(url: 'https://parent.example');
      await service.evaluateJavascript('prepare', tabId: parent.id);
      await popupCallbacks[parent.id]!('https://child.example', 1);
      final child = service.activeTab!;
      await popupCallbacks[child.id]!('https://grandchild.example', 2);
      final grandchild = service.activeTab!;
      Widget host(String id) => Directionality(
        textDirection: TextDirection.ltr,
        child: service.buildView(id),
      );
      await tester.pumpWidget(host(grandchild.id));
      await tester.pump();
      final other = await service.createTab(url: 'https://other.example');
      await tester.pumpWidget(host(other.id));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('fake-browser-engine')), findsOneWidget);
      expect(service.liveViewCount, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      service.dispose();
    },
  );

  testWidgets(
    'macOS tab viewport retains painted hosts and evicts hidden runtimes at the limit',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        service.dispose();
        service = createService(store: _RetryStore()..failRead = false);
        await service.initialize();
        final first = await service.createTab(url: 'https://first.example');
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: service.buildViewport(),
          ),
        );
        await tester.pumpAndSettle();
        final firstHost = tester.element(find.byKey(ValueKey('${first.id}:0')));
        final second = await service.createTab(url: 'https://second.example');
        await tester.pumpAndSettle();
        final secondHost = tester.element(
          find.byKey(ValueKey('${second.id}:0')),
        );
        final firstPaints = engines[first.id]!.paints;
        final secondPaints = engines[second.id]!.paints;
        expect(engines[first.id]!.visibility.last, isFalse);
        await service.selectTab(first.id);
        await tester.pumpAndSettle();
        expect(
          identical(
            tester.element(find.byKey(ValueKey('${first.id}:0'))),
            firstHost,
          ),
          isTrue,
        );
        expect(engines[first.id]!.viewBuilds, 1);
        expect(engines[second.id]!.viewBuilds, 1);
        expect(engines[first.id]!.paints, greaterThan(firstPaints));
        expect(engines[second.id]!.paints, greaterThan(secondPaints));
        expect(engines[first.id]!.visibility.last, isTrue);
        expect(engines[second.id]!.visibility.last, isFalse);
        expect(find.byType(Offstage), findsNothing);
        await service.selectTab(second.id);
        await tester.pumpAndSettle();
        expect(
          identical(
            tester.element(find.byKey(ValueKey('${second.id}:0'))),
            secondHost,
          ),
          isTrue,
        );
        await service.createTab(url: 'https://third.example');
        await tester.pumpAndSettle();
        await service.createTab(url: 'https://fourth.example');
        await tester.pumpAndSettle();
        expect(service.liveViewCount, BrowserService.maxLiveViews);
        expect(engines[first.id]!.disposed, isTrue);
        expect(
          find.byKey(ValueKey('${first.id}:0'), skipOffstage: false),
          findsNothing,
        );
        expect(engines[second.id]!.viewBuilds, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        service.dispose();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets(
      '$platform paints only the selected native tab while retaining its runtime',
      (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        try {
          service.dispose();
          service = createService(store: _RetryStore()..failRead = false);
          await service.initialize();
          final first = await service.createTab(url: 'https://first.example');
          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: service.buildViewport(),
            ),
          );
          await tester.pumpAndSettle();
          final firstHost = tester.element(
            find.byKey(ValueKey('${first.id}:0')),
          );
          final second = await service.createTab(url: 'https://second.example');
          await tester.pumpAndSettle();
          final firstPaints = engines[first.id]!.paints;
          final secondPaints = engines[second.id]!.paints;
          await service.selectTab(first.id);
          await tester.pumpAndSettle();
          expect(engines[first.id]!.paints, greaterThan(firstPaints));
          expect(engines[second.id]!.paints, secondPaints);
          expect(engines[first.id]!.visibility.last, isTrue);
          expect(engines[second.id]!.visibility.last, isFalse);
          expect(engines[first.id]!.viewBuilds, 1);
          expect(engines[second.id]!.viewBuilds, 1);
          expect(
            identical(
              tester.element(find.byKey(ValueKey('${first.id}:0'))),
              firstHost,
            ),
            isTrue,
          );
          expect(service.liveViewCount, 2);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          service.dispose();
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  }

  testWidgets(
    'eviction listeners cannot reacquire the retiring native instance',
    (tester) async {
      service.dispose();
      service = createService(store: _RetryStore()..failRead = false);
      await service.initialize();
      final first = await service.createTab(url: 'https://first.example');
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: service.buildViewport(),
        ),
      );
      await tester.pumpAndSettle();
      final retired = engines[first.id]!;
      await service.createTab(url: 'https://second.example');
      await tester.pumpAndSettle();
      await service.createTab(url: 'https://third.example');
      await tester.pumpAndSettle();
      Future<Object?>? reacquired;
      void reacquireDuringDetach() {
        if (reacquired == null &&
            service.requireTab(first.id).runtimeVersion > 0) {
          // The runtime-version notification happens before native detachment.
          // Requests from listeners must queue behind disposal, not take the
          // retiring renderer from the service's immediate acquisition path.
          reacquired = service.evaluateJavascript(
            'during-eviction',
            tabId: first.id,
          );
        }
      }

      service.addListener(reacquireDuringDetach);
      await service.createTab(url: 'https://fourth.example');
      await tester.pumpAndSettle();
      service.removeListener(reacquireDuringDetach);
      expect(reacquired, isNotNull);
      expect(await reacquired, 'complete');
      expect(retired.disposed, isTrue);
      expect(retired.scripts, isNot(contains('during-eviction')));
      final replacement = engines[first.id]!;
      expect(identical(replacement, retired), isFalse);
      expect(replacement.disposed, isFalse);
      expect(replacement.scripts, contains('during-eviction'));
      expect(
        replacement.tab.runtimeVersion,
        service.requireTab(first.id).runtimeVersion,
      );
      expect(
        service.liveViewCount,
        lessThanOrEqualTo(BrowserService.maxLiveViews),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      service.dispose();
    },
  );

  testWidgets(
    'moving the browser host between responsive layouts restores the native view',
    (tester) async {
      final tab = (await tester.runAsync(() async {
        final tab = await service.createTab(url: 'https://example.com');
        await service.evaluateJavascript('prepare', tabId: tab.id);
        return tab;
      }))!;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Column(children: [Expanded(child: service.buildView(tab.id))]),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('fake-browser-engine')), findsOneWidget);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Column(children: [Expanded(child: service.buildView(tab.id))]),
        ),
      );
      await tester.pump();
      expect(engines[tab.id]!.viewBuilds, 1);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(children: [Expanded(child: service.buildView(tab.id))]),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('fake-browser-engine')), findsOneWidget);
      expect(engines, hasLength(1));
      expect(engines[tab.id]!.visibility.last, isTrue);
      await tester.pumpWidget(const SizedBox());
      service.dispose();
    },
  );
}
