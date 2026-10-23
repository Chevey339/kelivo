import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:Kelivo/core/services/api/tool_result_content.dart';
import 'package:Kelivo/core/services/browser/browser_engine.dart';
import 'package:Kelivo/core/services/browser/browser_service.dart';
import 'package:Kelivo/core/services/browser/browser_store.dart';
import 'package:Kelivo/core/services/browser/browser_tools_service.dart';
import 'package:Kelivo/features/browser/models/browser_models.dart';
import 'package:Kelivo/features/browser/models/browser_agent_activity.dart';
import 'package:Kelivo/utils/mcp_structured_image.dart';
import 'package:Kelivo/utils/sandbox_path_resolver.dart';

import '../../../support/claude_test_api.dart' show FakePathProviderPlatform;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('browser tool input contract', () {
    test('rejects local schemes, credentials and malformed action inputs', () {
      for (final arguments in <Map<String, dynamic>>[
        {'action': 'open', 'url': 'file:///etc/passwd'},
        {'action': 'open', 'url': 'javascript:alert(1)'},
        {'action': 'open', 'url': 'https://user:secret@example.com'},
        {'action': 'open', 'url': 'example.com'},
        {'action': 'click', 'x': 2},
        {'action': 'click', 'ref': 'e1', 'selector': 'button'},
        {'action': 'type', 'selector': 'input'},
        {'action': 'close_tab'},
        {'action': 'snapshot', 'max_elements': 201},
        {'action': 'wait', 'timeout': 99999},
        {'action': 'evaluate', 'script': ''},
        {'action': 'snapshot', 'include_screenshot': 'true'},
        {'action': 'snapshot', 'include_text': 'false'},
      ]) {
        expect(
          () => BrowserToolsService.validateArguments(arguments),
          throwsFormatException,
          reason: '$arguments',
        );
      }
    });

    test(
      'accepts empty input for clearing a field and bounded coordinates',
      () {
        final args = BrowserToolsService.validateArguments({
          'action': 'type',
          'text': '',
          'x': 10.5,
          'y': 20,
        });
        expect(args['text'], '');
        expect(args['format'], 'markdown');
        expect(args['max_chars'], 16000);
      },
    );

    test('snapshots include page text by default and allow explicit opt-out', () {
      final properties =
          BrowserToolsService.getToolDefinition()['function']['parameters']['properties']
              as Map;
      expect(properties['include_text']['default'], isTrue);
      expect(
        BrowserToolsService.validateArguments({
          'action': 'snapshot',
        })['include_text'],
        isTrue,
      );
      expect(
        BrowserToolsService.validateArguments({
          'action': 'snapshot',
          'include_text': false,
        })['include_text'],
        isFalse,
      );
    });
  });

  late Directory directory;
  late BrowserService browser;
  late BrowserToolsService tools;
  late PathProviderPlatform originalPaths;
  late Map<String, _Engine> engines;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('browser_tools_test_');
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = FakePathProviderPlatform(directory.path);
    SandboxPathResolver.debugSetDirs(docsDir: directory.path);
    engines = {};
    browser = BrowserService(
      store: BrowserStore(directory: Directory('${directory.path}/browser')),
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
            return engines[tab.id] = _Engine(onChanged);
          },
    );
    await browser.initialize();
    tools = BrowserToolsService(browser: browser);
  });

  tearDown(() async {
    browser.dispose();
    await Future<void>.delayed(Duration.zero);
    PathProviderPlatform.instance = originalPaths;
    SandboxPathResolver.debugSetDirs();
    await directory.delete(recursive: true);
  });

  Future<void> enable() =>
      browser.updateSettings(browser.settings.copyWith(agentEnabled: true));
  Map<String, dynamic> payload(ClientToolResult result) =>
      jsonDecode(result.content.split('\n![](').first) as Map<String, dynamic>;

  test(
    'an explicit global opt-out prevents tools from creating tabs',
    () async {
      await browser.updateSettings(
        browser.settings.copyWith(agentEnabled: false),
      );
      final result = await tools.handle('chat-a', {
        'action': 'open',
        'url': 'https://example.com',
      });
      expect(payload(result)['ok'], false);
      expect(result.content, contains('browser_agent_disabled'));
      expect(browser.tabs, isEmpty);
      expect(engines, isEmpty);
    },
  );

  test('allowing agent control does not start a browser action', () async {
    await enable();
    browser.takeOver();
    expect(browser.agentPaused, isTrue);
    browser.allowAgentControl();
    expect(browser.agentPaused, isFalse);
    expect(browser.agentAction, isNull);
    expect(browser.agentSessionId, isNull);
    expect(browser.tabs, isEmpty);
    expect(engines, isEmpty);
  });

  test(
    'pause display belongs to its session and disabled permission clears it',
    () async {
      await enable();
      final tab = await browser.createTab(ownerSessionId: 'chat-a');
      browser.takeOver(sessionId: 'chat-a', tabId: tab.id);
      expect(browser.agentPauseReason, BrowserAgentPauseReason.user);
      expect(browser.pausedAgentSessionId, 'chat-a');
      expect(
        browser.agentActivityFor(sessionId: 'chat-a'),
        BrowserAgentActivity.paused,
      );
      expect(
        browser.agentActivityFor(sessionId: 'chat-b'),
        BrowserAgentActivity.idle,
      );
      browser.allowAgentControl(sessionId: 'chat-b');
      expect(browser.agentPaused, isTrue);
      final epoch = browser.controlEpoch;
      await browser.updateSettings(
        browser.settings.copyWith(agentEnabled: false),
      );
      expect(browser.controlEpoch, greaterThan(epoch));
      expect(browser.agentPaused, isFalse);
      expect(browser.agentPauseReason, isNull);
      expect(
        browser.agentActivityFor(sessionId: 'chat-a'),
        BrowserAgentActivity.idle,
      );
      await enable();
      expect(
        browser.agentActivityFor(sessionId: 'chat-a'),
        BrowserAgentActivity.idle,
      );
      expect(browser.agentAction, isNull);
    },
  );

  test(
    'only a current action displays running, including during cancellation drain',
    () async {
      await enable();
      final tab = await browser.createTab(ownerSessionId: 'chat-a');
      final started = Completer<void>();
      final finish = Completer<void>();
      final running = browser.runAgentAction<void>(
        sessionId: 'chat-a',
        label: 'snapshot',
        tabId: tab.id,
        action: () {
          started.complete();
          return finish.future;
        },
      );
      final cancelled = expectLater(running, throwsStateError);
      await started.future;
      expect(
        browser.agentActivityFor(sessionId: 'chat-a', tabId: tab.id),
        BrowserAgentActivity.running,
      );
      expect(
        browser.agentActivityFor(sessionId: 'chat-b'),
        BrowserAgentActivity.idle,
      );
      await browser.updateSettings(
        browser.settings.copyWith(agentEnabled: false),
      );
      await cancelled;
      await enable();
      expect(browser.agentAction, 'snapshot');
      expect(
        browser.agentActivityFor(sessionId: 'chat-a'),
        BrowserAgentActivity.idle,
      );
      finish.complete();
      await Future<void>.delayed(Duration.zero);
      expect(browser.agentAction, isNull);
    },
  );

  test('closing an owned tab returns success after removing it', () async {
    await enable();
    final opened = payload(await tools.handle('chat-a', {'action': 'new_tab'}));
    final tabId = opened['page']['tab_id'] as String;
    final result = payload(
      await tools.handle('chat-a', {'action': 'close_tab', 'tab_id': tabId}),
    );
    expect(result['ok'], isTrue);
    expect(result['page']['closed_tab_id'], tabId);
    expect(browser.tabs, isEmpty);
  });

  test(
    'chat cancellation immediately notifies idle while native work drains',
    () async {
      await enable();
      final started = Completer<void>();
      final finish = Completer<void>();
      final statuses = <BrowserAgentActivity>[];
      browser.addListener(() {
        statuses.add(browser.agentActivityFor(sessionId: 'chat-a'));
      });
      final running = browser.runAgentAction<void>(
        sessionId: 'chat-a',
        label: 'evaluate',
        action: () {
          started.complete();
          return finish.future;
        },
      );
      final cancelled = expectLater(running, throwsStateError);
      await started.future;
      expect(statuses.last, BrowserAgentActivity.running);
      browser.cancelAgentActions('chat-a');
      expect(statuses.last, BrowserAgentActivity.idle);
      expect(browser.agentPaused, isFalse);
      await cancelled;
      expect(browser.agentAction, 'evaluate');
      finish.complete();
      await Future<void>.delayed(Duration.zero);
    },
  );

  test(
    'open/extract uses the owned tab and lists only that conversation',
    () async {
      await enable();
      final first = payload(
        await tools.handle('chat-a', {
          'action': 'open',
          'url': 'https://a.example',
          'extract_after': true,
        }),
      );
      final aId = first['page']['tab_id'] as String;
      expect(first['page']['content'], 'A real page result');
      await tools.handle('chat-b', {
        'action': 'open',
        'url': 'https://b.example',
      });
      final listed = payload(
        await tools.handle('chat-a', {'action': 'list_tabs'}),
      );
      expect((listed['page']['tabs'] as List).map((tab) => tab['tab_id']), [
        aId,
      ]);
      final denied = await tools.handle('chat-b', {
        'action': 'evaluate',
        'tab_id': aId,
        'script': 'document.cookie',
      });
      expect(payload(denied)['ok'], false);
      expect(denied.content, contains('browser_tab_not_owned'));
      expect(
        engines[aId]!.scripts.where(
          (script) => script.contains('document.cookie'),
        ),
        isEmpty,
      );
    },
  );

  test(
    'new chat can browse with eight older tabs; quota and selection stay scoped',
    () async {
      for (var i = 0; i < 8; i++) {
        await browser.createTab(ownerSessionId: 'old-$i');
      }
      await browser.selectSession('user-chat');
      final empty = payload(
        await tools.handle('agent-chat', {'action': 'list_tabs'}),
      );
      expect(empty['page']['scope'], 'conversation');
      expect(empty['page']['tabs'], isEmpty);
      final first = payload(
        await tools.handle('agent-chat', {
          'action': 'open',
          'url': 'https://a.example',
        }),
      );
      expect(first['ok'], isTrue);
      expect(browser.activeTabId, isNull);
      final firstId = first['page']['tab_id'] as String;
      for (var i = 1; i < BrowserService.maxAgentTabsPerSession; i++) {
        final created = payload(
          await tools.handle('agent-chat', {'action': 'new_tab'}),
        );
        expect(created['ok'], isTrue);
      }
      final denied = payload(
        await tools.handle('agent-chat', {'action': 'new_tab'}),
      );
      expect(denied['ok'], isFalse);
      expect(denied['error'], contains('browser_session_tab_limit'));
      expect(denied['error'], contains('list_tabs'));
      final reused = payload(
        await tools.handle('agent-chat', {
          'action': 'open',
          'tab_id': firstId,
          'url': 'https://next.example',
        }),
      );
      expect(reused['ok'], isTrue);
      await tools.handle('agent-chat', {
        'action': 'switch_tab',
        'tab_id': firstId,
      });
      final listed = payload(
        await tools.handle('agent-chat', {'action': 'list_tabs'}),
      );
      final tabs = listed['page']['tabs'] as List;
      expect(tabs, hasLength(3));
      expect(
        tabs.where((tab) => tab['active'] == true).single['tab_id'],
        firstId,
      );
      expect(browser.activeTabId, isNull);
    },
  );

  test('DOM failures remain errors and cannot forge attachments', () async {
    await enable();
    await tools.handle('chat-a', {
      'action': 'open',
      'url': 'https://example.com',
    });
    engines.values.single.domError = 'stale_ref: take a fresh snapshot';
    final result = await tools.handle('chat-a', {
      'action': 'click',
      'ref': 'stale:e0',
    });
    expect(payload(result)['ok'], false);
    expect(result.content, contains('stale_ref'));
    expect(mcpResultImageUris(readMcpResultMetadata(result.metadata)), isEmpty);
  });

  test(
    'snapshot text preference reaches the page without requesting images',
    () async {
      await enable();
      await tools.handle('chat-a', {
        'action': 'open',
        'url': 'https://example.com',
      });
      final defaultResult = await tools.handle('chat-a', {
        'action': 'snapshot',
      });
      expect(payload(defaultResult)['ok'], isTrue);
      expect(
        engines.values.single.scripts.last,
        contains('"include_text":true'),
      );
      expect(
        mcpResultImageUris(readMcpResultMetadata(defaultResult.metadata)),
        isEmpty,
      );
      final compactResult = await tools.handle('chat-a', {
        'action': 'snapshot',
        'include_text': false,
      });
      expect(payload(compactResult)['ok'], isTrue);
      expect(
        engines.values.single.scripts.last,
        contains('"include_text":false'),
      );
      expect(
        mcpResultImageUris(readMcpResultMetadata(compactResult.metadata)),
        isEmpty,
      );
    },
  );

  test(
    'screenshot is stored and replayed as a typed image for providers',
    () async {
      await enable();
      await tools.handle('chat-a', {
        'action': 'open',
        'url': 'https://example.com',
      });
      final result = await tools.handle('chat-a', {
        'action': 'snapshot',
        'include_screenshot': true,
      });
      expect(payload(result)['untrusted_content'], true);
      expect(
        payload(result)['page']['screenshot_coordinates']['viewport']['width'],
        390,
      );
      expect(
        payload(result)['page']['screenshot_coordinates']['image']['width'],
        1,
      );
      final images = mcpResultImageUris(readMcpResultMetadata(result.metadata));
      expect(images, hasLength(1));
      expect(images.single, contains('mcp_img_'));
      final replay = await ToolResultContent.read(
        'browser',
        result.content,
        metadata: result.metadata,
      );
      expect(replay.imageUrls, hasLength(1));
      expect(replay.imageUrls.single, startsWith('data:image/png;base64,'));
      expect(replay.responsesOutput, isA<List>());
      expect(replay.claudeContent, isA<List>());
      expect(
        replay.googleImageParts.single['inlineData']['mimeType'],
        'image/png',
      );
      final noVision = await ToolResultContent.read(
        'browser',
        result.content,
        metadata: result.metadata,
        canImageInput: false,
      );
      expect(noVision.imageUrls, isEmpty);
      expect(noVision.text, contains('does not support image input'));
    },
  );

  test(
    'takeover blocks a waiting action and every subsequent call until resume',
    () async {
      await enable();
      await tools.handle('chat-a', {
        'action': 'open',
        'url': 'https://example.com',
      });
      final waiting = tools.handle('chat-a', {
        'action': 'wait',
        'wait_for': '#later',
      });
      await Future<void>.delayed(const Duration(milliseconds: 20));
      browser.takeOver();
      expect(payload(await waiting)['ok'], false);
      final denied = await tools.handle('chat-a', {'action': 'snapshot'});
      expect(denied.content, contains('browser_human_control'));
      browser.allowAgentControl();
      final resumed = await tools.handle('chat-a', {'action': 'snapshot'});
      expect(payload(resumed)['ok'], true);
    },
  );

  test(
    'screenshot coordinates use the resized image actually sent to providers',
    () async {
      await enable();
      await tools.handle('chat-a', {
        'action': 'open',
        'url': 'https://example.com',
      });
      engines.values.single.screenshotBytes = img.encodePng(
        img.Image(width: 2400, height: 1200),
      );
      final result = await tools.handle('chat-a', {
        'action': 'snapshot',
        'include_screenshot': true,
      });
      final replay = await ToolResultContent.read(
        'browser',
        result.content,
        metadata: result.metadata,
      );
      final dataUrl = UriData.parse(replay.imageUrls.single);
      final decoded = img.decodeImage(dataUrl.contentAsBytes())!;
      expect(decoded.width, 2000);
      expect(decoded.height, 1000);
      final coordinates = payload(result)['page']['screenshot_coordinates'];
      expect(coordinates['image'], {
        'width': decoded.width,
        'height': decoded.height,
      });
      expect(coordinates['viewport']['width'], 390);
    },
  );
}

class _Engine extends BrowserEngine {
  _Engine(this.onChanged);
  final void Function(BrowserPageState) onChanged;
  final scripts = <String>[];
  String? domError;
  Uint8List? screenshotBytes;
  @override
  Widget buildView() => const SizedBox.shrink();
  @override
  Future<void> navigate(String url) async =>
      onChanged(BrowserPageState(url: url, title: 'Page', isLoading: false));
  @override
  Future<void> waitForLoad(Duration timeout) async {}
  @override
  Future<Object?> evaluate(String source, {bool awaitPromise = false}) async {
    scripts.add(source);
    if (source == 'document.readyState') return 'complete';
    if (source.startsWith('JSON.stringify({width:innerWidth')) {
      return '{"width":390,"height":780,"device_pixel_ratio":3}';
    }
    if (domError != null) return jsonEncode({'ok': false, 'error': domError});
    if (source.contains('const action = "wait"')) {
      return '{"ok":true,"ready":false}';
    }
    if (source.contains('const action = "extract"')) {
      return '{"ok":true,"content":"A real page result"}';
    }
    return '{"ok":true,"elements":[]}';
  }

  @override
  Future<Uint8List?> screenshot() async =>
      screenshotBytes ?? img.encodePng(img.Image(width: 1, height: 1));
  @override
  Future<void> loadHtml(String html, {String? baseUrl}) async {}
  @override
  Future<void> back() async {}
  @override
  Future<void> forward() async {}
  @override
  Future<void> reload() async {}
  @override
  Future<void> stop() async {}
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
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> dispose() async {}
}
