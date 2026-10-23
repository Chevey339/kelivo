import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';
// ignore: depend_on_referenced_packages
import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import '../../../support/fake_audioplayers_platform.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/core/services/browser/browser_service.dart';
import 'package:Kelivo/features/browser/browser_panel_controller.dart';
import 'package:Kelivo/features/chat/widgets/chat_message_widget.dart';
import 'package:Kelivo/features/home/services/ask_user_interaction_service.dart';
import 'package:Kelivo/features/home/services/local_tools_service.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import '../../../support/business_test_harness.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
}

void main() {
  setUpAll(() {
    AudioplayersPlatformInterface.instance = FakeAudioplayersPlatform();
    GlobalAudioplayersPlatformInterface.instance =
        FakeGlobalAudioplayersPlatform();
  });
  testWidgets(
    'detail opens its tab after the source timeline group is unmounted',
    (tester) async {
      final oldPaths = PathProviderPlatform.instance;
      final browser = BrowserService.instance;
      final panel = BrowserPanelController.instance;
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('browser-step-detail-'),
      ))!;
      PathProviderPlatform.instance = _Paths(directory.path);
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      panel.attachHost();
      SettingsProvider? settings;
      try {
        await tester.runAsync(() async {
          settings = SettingsProvider(createBusinessTestPreferences());
          await settings!.loaded;
          await browser.initialize();
        });
        final tab = (await tester.runAsync(
          () => browser.createTab(ownerSessionId: 'chat'),
        ))!;
        await tester.runAsync(browser.flush);
        var showMessage = true;
        late StateSetter setHostState;
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: settings!),
              ChangeNotifierProvider(create: (_) => ToolApprovalService()),
              ChangeNotifierProvider(
                create: (_) => AskUserInteractionService(),
              ),
              ChangeNotifierProvider(
                create: (_) =>
                    TtsProvider(preferences: createBusinessTestPreferences()),
              ),
            ],
            child: MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    setHostState = setState;
                    return showMessage
                        ? ChatMessageWidget(
                            message: ChatMessage(
                              id: 'message',
                              conversationId: 'chat',
                              role: 'assistant',
                            ),
                            showModelIcon: false,
                            showTokenStats: false,
                            toolParts: [
                              ToolUIPart(
                                id: 'open',
                                toolName: LocalToolNames.browser,
                                arguments: const {'action': 'open'},
                                content: jsonEncode({
                                  'ok': true,
                                  'page': {
                                    'url': 'about:blank',
                                    'title': 'Live tab',
                                  },
                                }),
                                metadata: {
                                  'browser': {'tabId': tab.id},
                                },
                              ),
                            ],
                          )
                        : const Text('The source message was recycled');
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Browsing'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open page'));
        await tester.pumpAndSettle();
        setHostState(() => showMessage = false);
        await tester.pumpAndSettle();
        expect(find.byType(ChatMessageWidget), findsNothing);
        final open = find.byKey(const ValueKey('browser-step-detail-open'));
        expect(tester.widget<TextButton>(open).onPressed, isNotNull);
        await tester.tap(open);
        await tester.pump();
        await tester.runAsync(browser.flush);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('tool_detail_desktop_dialog')),
          findsNothing,
        );
        expect(panel.isOpen, isTrue);
        expect(panel.conversationId, 'chat');
        expect(panel.initialTabId, tab.id);
        expect(browser.activeTabId, tab.id);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        panel.detachHost();
        browser.dispose();
        settings?.dispose();
        PathProviderPlatform.instance = oldPaths;
        debugDefaultTargetPlatformOverride = null;
        await tester.runAsync(() => directory.delete(recursive: true));
      }
    },
  );
}
