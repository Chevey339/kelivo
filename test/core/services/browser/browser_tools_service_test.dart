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
import 'package:Kelivo/core/services/browser/browser_workspace_resources.dart';
import 'package:Kelivo/core/services/mcp/mcp_image_snapshot.dart';
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
        {'action': 'select_option', 'selector': 'select'},
        {
          'action': 'select_option',
          'selector': 'select',
          'option_value': 'a',
          'option_label': 'One',
        },
        {'action': 'extract', 'offset': -1},
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
  TimeoutException? loadError;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('browser_tools_test_');
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = FakePathProviderPlatform(directory.path);
    SandboxPathResolver.debugSetDirs(docsDir: directory.path);
    engines = {};
    loadError = null;
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
            return engines[tab.id] = _Engine(
              onChanged,
              loadError: loadError,
              onNewWindow: onNewWindow,
            );
          },
    );
    await browser.initialize();
    tools = BrowserToolsService(
      browser: browser,
      workspaces: BrowserWorkspaceResources()
        ..rootForSession = (id) async => id == 'chat-a' ? directory : null,
    );
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
    'step previews persist independently and never enter model image input',
    () async {
      await enable();
      await tools.handle('chat-a', {
        'action': 'open',
        'url': 'https://example.com',
      }, capturePreview: false);
      final engine = engines.values.single;
      engine.onChanged(const BrowserPageState(isLoading: false));
      engine.previewBytes = img.encodePng(
        img.Image(width: 2, height: 2)..setPixelRgba(0, 0, 255, 0, 0, 255),
      );
      final first = await tools.handle('chat-a', {
        'action': 'scroll',
        'direction': 'down',
      });
      final firstUri =
          (first.metadata!['browser'] as Map)['previewImage'] as String;
      final firstFile = (await McpImageSnapshot.localFile(firstUri))!;
      final firstBytes = await firstFile.readAsBytes();
      expect(engine.thumbnailCalls, 1);
      expect(
        (await ToolResultContent.read(
          'browser',
          first.content,
          metadata: first.metadata,
        )).imageUrls,
        isEmpty,
      );
      expect(first.content, isNot(contains(firstUri)));

      engine.previewBytes = img.encodePng(
        img.Image(width: 2, height: 2)..setPixelRgba(0, 0, 0, 0, 255, 255),
      );
      final second = await tools.handle('chat-a', {
        'action': 'scroll',
        'direction': 'down',
      });
      final secondUri =
          (second.metadata!['browser'] as Map)['previewImage'] as String;
      expect(secondUri, isNot(firstUri));
      expect(await firstFile.readAsBytes(), firstBytes);
      expect(
        await (await McpImageSnapshot.localFile(secondUri))!.readAsBytes(),
        isNot(firstBytes),
      );
      expect(engine.thumbnailCalls, 2);

      final read = await tools.handle('chat-a', {'action': 'extract'});
      expect((read.metadata!['browser'] as Map)['previewImage'], secondUri);
      expect(
        engine.thumbnailCalls,
        3,
        reason: 'Each step samples current pixels, even at the same URL',
      );
      expect(
        await firstFile.parent.list().length,
        2,
        reason: 'Reused preview pixels do not create duplicate files',
      );
      engine.previewBytes = Uint8List.fromList(engine.previewBytes!);
      final unchanged = await tools.handle('chat-a', {
        'action': 'click',
        'selector': '#same-page',
      });
      expect(
        (unchanged.metadata!['browser'] as Map)['previewImage'],
        secondUri,
      );
      expect(await firstFile.parent.list().length, 2);
      final persisted = jsonDecode(jsonEncode(first.metadata)) as Map;
      expect(
        await McpImageSnapshot.localFile(
          persisted['browser']['previewImage'] as String,
        ),
        isNotNull,
      );
      await (await McpImageSnapshot.localFile(secondUri))!.delete();
      final restored = await tools.handle('chat-a', {'action': 'snapshot'});
      final restoredUri =
          (restored.metadata!['browser'] as Map)['previewImage'] as String;
      expect(restoredUri, secondUri);
      expect(await McpImageSnapshot.localFile(restoredUri), isNotNull);
    },
  );

  test(
    'hidden cards skip preview capture and explicit screenshots are reused',
    () async {
      await enable();
      await tools.handle('chat-a', {
        'action': 'open',
        'url': 'https://example.com',
      }, capturePreview: false);
      final engine = engines.values.single;
      engine.onChanged(const BrowserPageState(isLoading: false));
      final hidden = await tools.handle('chat-a', {
        'action': 'scroll',
      }, capturePreview: false);
      expect(hidden.metadata!['browser'], isNot(contains('previewImage')));
      expect(engine.thumbnailCalls, 0);
      final explicit = await tools.handle('chat-a', {
        'action': 'snapshot',
        'include_screenshot': true,
      }, capturePreview: false);
      final images = mcpResultImageUris(
        readMcpResultMetadata(explicit.metadata),
      );
      expect(images, hasLength(1));
      expect(
        (explicit.metadata!['browser'] as Map)['previewImage'],
        images.single,
      );
      expect(engine.thumbnailCalls, 0);
      expect(
        await (await McpImageSnapshot.localFile(
          images.single,
        ))!.parent.list().length,
        1,
      );
    },
  );

  test(
    'temporary chats skip extra previews and own explicit screenshot files',
    () async {
      await enable();
      final opened = await tools.handle('chat-a', {
        'action': 'open',
        'url': 'https://example.com',
      }, temporary: true);
      expect(opened.metadata!['browser'], isNot(contains('previewImage')));
      final engine = engines.values.single;
      expect(engine.thumbnailCalls, 0);
      final uris = <String>{};
      for (final temporary in [false, true, true]) {
        final result = await tools.handle('chat-a', {
          'action': 'snapshot',
          'include_screenshot': true,
        }, temporary: temporary);
        final uri =
            (result.metadata!['browser'] as Map)['previewImage'] as String;
        expect(
          uris.add(uri),
          isTrue,
          reason: 'Temporary screenshots must not share persistent assets',
        );
      }
      expect(engine.thumbnailCalls, 0);
    },
  );

  test('wait and reads capture asynchronous changes at the same URL', () async {
    await enable();
    await tools.handle('chat-a', {
      'action': 'open',
      'url': 'https://example.com',
    }, capturePreview: false);
    final engine = engines.values.single;
    engine.waitReady = true;
    engine.onChanged(const BrowserPageState(isLoading: false));
    final uris = <String>{};
    for (final action in ['click', 'wait', 'snapshot', 'extract']) {
      engine.previewBytes = img.encodePng(
        img.Image(width: 2, height: 2)
          ..setPixelRgba(0, 0, uris.length * 60, 0, 0, 255),
      );
      final result = await tools.handle('chat-a', {
        'action': action,
        if (action == 'click') 'selector': '#load-results',
        if (action == 'wait') 'wait_for': '#results',
      });
      final uri =
          (result.metadata!['browser'] as Map)['previewImage'] as String;
      expect(uris.add(uri), isTrue, reason: '$action must sample current DOM');
    }
    expect(engine.thumbnailCalls, 4);
  });

  for (final action in [
    'open',
    'new_tab',
    'render',
    'back',
    'forward',
    'reload',
  ]) {
    test(
      '$action load timeout leaves AI free to inspect and continue',
      () async {
        await enable();
        await tools.handle('chat-a', {
          'action': 'open',
          'url': 'https://example.com',
        });
        loadError = TimeoutException(
          'Future not completed',
          const Duration(seconds: 15),
        );
        for (final engine in engines.values) {
          engine.loadError = loadError;
        }
        final epoch = browser.controlEpoch;
        final result = payload(
          await tools.handle('chat-a', {
            'action': action,
            if (action == 'open' || action == 'new_tab')
              'url': 'https://slow.example.com',
            if (action == 'render') 'html': '<h1>Page</h1>',
          }),
        );
        expect(result['ok'], isFalse);
        expect(result['error_code'], 'browser_load_timeout');
        expect(
          result['page']['tab_id'],
          browser.selectedTabForSession('chat-a')!.id,
        );
        expect(result['page']['url'], isNotNull);
        expect(result['page']['navigation_state'], isNotNull);
        expect(result['error'], isNot(contains('browser_human_control')));
        expect(browser.agentPaused, isFalse);
        expect(browser.agentPauseReason, isNull);
        expect(browser.controlEpoch, epoch);
        expect(engines.values.every((engine) => engine.stopCalls == 0), isTrue);
        expect(
          payload(await tools.handle('chat-a', {'action': 'snapshot'}))['ok'],
          isTrue,
        );
        expect(
          payload(await tools.handle('chat-b', {'action': 'list_tabs'}))['ok'],
          isTrue,
        );

        loadError = null;
        for (final engine in engines.values) {
          engine.loadError = null;
        }
        expect(
          payload(
            await tools.handle('chat-a', {
              'action': 'open',
              'url': 'https://example.com/next',
            }),
          )['ok'],
          isTrue,
        );
      },
    );
  }

  test(
    'select, continuation and URL waits preserve the tool contract',
    () async {
      await enable();
      await tools.handle('chat-a', {
        'action': 'open',
        'url': 'https://example.com',
      });
      final engine = engines.values.single;
      final selected = payload(
        await tools.handle('chat-a', {
          'action': 'select_option',
          'selector': 'select',
          'option_value': 'b',
        }),
      );
      expect(selected['ok'], true);
      expect(engine.lastAwaitPromise, true);
      expect(engine.scripts.last, contains('"option_value":"b"'));
      final continued = payload(
        await tools.handle('chat-a', {'action': 'extract', 'offset': 1000}),
      );
      expect(continued['ok'], true);
      engine.waitReady = true;
      engine.documentUrl = 'https://example.com/next';
      final ready = payload(
        await tools.handle('chat-a', {
          'action': 'wait',
          'wait_for_url': '/next',
          'timeout': 100,
        }),
      );
      expect(ready['ok'], true);
      final timedOut = payload(
        await tools.handle('chat-a', {
          'action': 'wait',
          'wait_for_url': '/missing',
          'timeout': 100,
        }),
      );
      expect(timedOut['ok'], false);
      expect(browser.agentPaused, false);
    },
  );

  test(
    'rejected input reports current page and never claims success',
    () async {
      await enable();
      await tools.handle('chat-a', {
        'action': 'open',
        'url': 'https://example.com',
      });
      engines.values.single.domError = 'input_value_rejected';
      final result = await tools.handle('chat-a', {
        'action': 'type',
        'selector': 'input',
        'text': 'x',
      });
      expect(payload(result)['ok'], false);
      expect(payload(result)['page']['tab_id'], browser.tabs.single.id);
      expect(result.metadata!['browser']['tabId'], browser.tabs.single.id);
      expect(browser.agentPaused, false);
    },
  );

  test(
    'action results report popup ownership and bounded dialog events',
    () async {
      await enable();
      await tools.handle('chat-a', {
        'action': 'open',
        'url': 'https://example.com',
      }, capturePreview: false);
      final parent = engines.values.single;
      final parentId = browser.tabs.single.id;
      parent.onEvaluation = () async {
        parent.onEvaluation = null;
        parent.onChanged(
          const BrowserPageState(
            agentEvent: {
              'type': 'dialog',
              'dialog': 'confirm',
              'response': 'dismissed',
            },
          ),
        );
        unawaited(parent.onNewWindow!('https://example.com/child', 101));
      };
      final result = payload(
        await tools.handle('chat-a', {
          'action': 'click',
          'selector': 'a',
        }, capturePreview: false),
      );
      expect(result['ok'], true);
      expect(result['page']['tab_id'], parentId);
      expect(result['page']['events'], [
        {'type': 'dialog', 'dialog': 'confirm', 'response': 'dismissed'},
      ]);
      expect(result['page']['opened_tabs'], hasLength(1));
      expect(
        result['page']['opened_tabs'][0]['url'],
        'https://example.com/child',
      );
      expect(browser.tabs.last.ownerSessionId, 'chat-a');
      final next = payload(
        await tools.handle('chat-a', {
          'action': 'snapshot',
          'tab_id': parentId,
        }, capturePreview: false),
      );
      expect(next['page'].containsKey('events'), false);
      expect(next['page'].containsKey('opened_tabs'), false);
    },
  );

  test('selector wait timeout does not pause later browser actions', () async {
    await enable();
    await tools.handle('chat-a', {
      'action': 'open',
      'url': 'https://example.com',
    });
    final result = payload(
      await tools.handle('chat-a', {
        'action': 'wait',
        'wait_for': '#not-yet-present',
        'timeout': 100,
      }),
    );
    expect(result['error_code'], 'browser_wait_timeout');
    expect(browser.agentPaused, isFalse);
    expect(
      payload(await tools.handle('chat-a', {'action': 'snapshot'}))['ok'],
      isTrue,
    );
  });

  test(
    'unfinished native operation pauses with a timeout reason, not takeover',
    () async {
      await enable();
      await tools.handle('chat-a', {
        'action': 'open',
        'url': 'https://example.com',
      });
      final engine = engines.values.single;
      engine.evaluationError = TimeoutException(
        'Native operation did not finish',
      );
      final result = payload(
        await tools.handle('chat-a', {
          'action': 'click',
          'selector': '#submit',
        }),
      );
      expect(
        result['error_code'],
        contains('browser_action_timeout_outcome_unknown'),
      );
      expect(browser.agentPauseReason, BrowserAgentPauseReason.timeout);
      expect(browser.agentPaused, isTrue);
      expect(browser.pausedAgentSessionId, 'chat-a');
      expect(engine.stopCalls, 1);
      final blocked = payload(
        await tools.handle('chat-a', {'action': 'snapshot'}),
      );
      expect(
        blocked['error_code'],
        contains('browser_action_timeout_outcome_unknown'),
      );
      expect(blocked['error'], isNot(contains('browser_human_control')));

      engine.evaluationError = null;
      browser.allowAgentControl(sessionId: 'chat-a');
      expect(
        payload(await tools.handle('chat-a', {'action': 'snapshot'}))['ok'],
        isTrue,
      );
      expect(browser.agentPaused, isFalse);
    },
  );

  test(
    'human takeover stays paused until the user allows continuation',
    () async {
      await enable();
      browser.takeOver(sessionId: 'chat-a');
      for (var attempt = 0; attempt < 2; attempt++) {
        final result = payload(
          await tools.handle('chat-a', {'action': 'list_tabs'}),
        );
        expect(result['error_code'], contains('browser_human_control'));
        expect(browser.agentPauseReason, BrowserAgentPauseReason.user);
        expect(browser.agentPaused, isTrue);
      }
      browser.allowAgentControl(sessionId: 'chat-a');
      expect(
        payload(await tools.handle('chat-a', {'action': 'list_tabs'}))['ok'],
        isTrue,
      );
    },
  );

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
      expect(denied['error_code'], contains('browser_session_tab_limit'));
      expect(denied['next_action'], contains('list_tabs'));
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
    'navigation stage is explicit, defaults to DOM, and none tolerates slow load',
    () async {
      await enable();
      await tools.handle('chat-a', {
        'action': 'open',
        'url': 'https://example.com',
      });
      final engine = engines.values.single;
      expect(engine.loadStages.last, BrowserLoadStage.domcontentloaded);
      for (final stage in BrowserLoadStage.values) {
        final result = payload(
          await tools.handle('chat-a', {
            'action': 'reload',
            'wait_until': stage.name,
          }, capturePreview: false),
        );
        expect(result['ok'], true);
        expect(engine.loadStages.last, stage);
      }
      engine.loadError = TimeoutException('raw failure');
      expect(
        payload(
          await tools.handle('chat-a', {
            'action': 'open',
            'url': 'https://slow.example',
            'wait_until': 'none',
          }, capturePreview: false),
        )['ok'],
        true,
      );
    },
  );

  test(
    'workspace-only screenshot saves PNG without model images or extra previews',
    () async {
      await enable();
      await tools.handle('chat-a', {
        'action': 'open',
        'url': 'https://example.com',
      }, capturePreview: false);
      final engine = engines.values.single;
      final before = engine.thumbnailCalls;
      final result = await tools.handle('chat-a', {
        'action': 'screenshot',
        'save_to': 'shots/页面.png',
      });
      final data = payload(result);
      expect(data['ok'], true);
      expect(
        data['page']['screenshot_file']['path'],
        'kelivo://workspace/shots/%E9%A1%B5%E9%9D%A2.png',
      );
      final file = File('${directory.path}/shots/页面.png');
      expect(img.decodePng(await file.readAsBytes()), isNotNull);
      expect(result.content, isNot(contains('![](')));
      expect(
        mcpResultImageUris(readMcpResultMetadata(result.metadata)),
        isEmpty,
      );
      final replay = await ToolResultContent.read(
        'browser',
        result.content,
        metadata: result.metadata,
      );
      expect(replay.imageUrls, isEmpty);
      expect(engine.thumbnailCalls, before);
      expect(
        engine.scripts.any((s) => s.contains('const action = "screenshot"')),
        false,
      );
      final again = payload(
        await tools.handle('chat-a', {
          'action': 'screenshot',
          'save_to': 'shots/页面.png',
        }),
      );
      expect(again['ok'], false);
      expect(again['error_code'], 'browser_workspace_file_exists');
      final dual = await tools.handle('chat-a', {
        'action': 'screenshot',
        'save_to': 'dual.png',
        'return_image': true,
      });
      expect(payload(dual)['ok'], true);
      expect(
        mcpResultImageUris(readMcpResultMetadata(dual.metadata)),
        hasLength(1),
      );
    },
  );

  test(
    'invalid screenshot paths and combinations cannot write files',
    () async {
      for (final args in <Map<String, dynamic>>[
        {'save_to': '../escape.png'},
        {'save_to': '/absolute.png'},
        {'save_to': 'kelivo://workspace/%2e%2e/escape.png'},
        {'save_to': 'file:///a.png'},
        {'save_to': 'page.html'},
        {'return_image': false},
      ]) {
        final result = payload(
          await tools.handle('chat-a', {'action': 'screenshot', ...args}),
        );
        expect(
          result['error_code'],
          'browser_invalid_arguments',
          reason: '$args',
        );
      }
      expect(browser.tabs, isEmpty);
    },
  );

  test('structured errors do not expose raw exception details', () async {
    await enable();
    await tools.handle('chat-a', {
      'action': 'open',
      'url': 'https://example.com',
    }, capturePreview: false);
    engines.values.single.domError =
        'some raw site exception /private/path/secret';
    final result = payload(
      await tools.handle('chat-a', {'action': 'snapshot'}),
    );
    expect(result['error_code'], 'browser_action_failed');
    expect(result['error'], isNot(contains('secret')));
    expect(result['next_action'], isNotEmpty);
    expect(result['outcome_unknown'], false);
    expect(result['recoverable'], true);
  });

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
  _Engine(this.onChanged, {this.loadError, this.onNewWindow});
  final Future<bool> Function(String?, int)? onNewWindow;
  Future<void> Function()? onEvaluation;
  final void Function(BrowserPageState) onChanged;
  final scripts = <String>[];
  String? domError;
  Uint8List? screenshotBytes;
  Uint8List? previewBytes;
  int thumbnailCalls = 0;
  TimeoutException? loadError;
  final loadStages = <BrowserLoadStage>[];
  TimeoutException? evaluationError;
  bool waitReady = false;
  bool lastAwaitPromise = false;
  String documentUrl = 'https://example.com';
  int stopCalls = 0;
  @override
  Widget buildView() => const SizedBox.shrink();
  @override
  Future<void> navigate(String url) async =>
      onChanged(BrowserPageState(url: url, title: 'Page', isLoading: false));
  @override
  Future<void> waitForLoad(
    Duration timeout, {
    BrowserLoadStage stage = BrowserLoadStage.load,
  }) async {
    loadStages.add(stage);
    if (stage != BrowserLoadStage.none && loadError != null) throw loadError!;
  }

  @override
  Future<Object?> evaluate(String source, {bool awaitPromise = false}) async {
    scripts.add(source);
    lastAwaitPromise = awaitPromise;
    if (onEvaluation != null) await onEvaluation!();
    if (evaluationError case final error?) throw error;
    if (source == 'document.readyState') return 'complete';
    if (source.startsWith('JSON.stringify({width:innerWidth')) {
      return '{"width":390,"height":780,"device_pixel_ratio":3}';
    }
    if (domError != null) return jsonEncode({'ok': false, 'error': domError});
    if (source.contains('const action = "wait"')) {
      return jsonEncode({'ok': true, 'ready': waitReady, 'url': documentUrl});
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
  Future<Uint8List?> thumbnail() async {
    thumbnailCalls++;
    return previewBytes ?? img.encodePng(img.Image(width: 1, height: 1));
  }

  @override
  Future<void> loadHtml(String html, {String? baseUrl}) async {}
  @override
  Future<void> back() async {}
  @override
  Future<void> forward() async {}
  @override
  Future<void> reload() async {}
  @override
  Future<void> stop() async => stopCalls++;
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
