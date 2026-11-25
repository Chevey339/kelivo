import 'dart:io';

import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/database/extension_entity_store.dart';
import 'package:Kelivo/core/providers/asr_provider.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/backup_reminder_provider.dart';
import 'package:Kelivo/core/providers/instruction_injection_provider.dart';
import 'package:Kelivo/core/providers/mcp_provider.dart';
import 'package:Kelivo/core/providers/quick_phrase_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/tag_provider.dart';
import 'package:Kelivo/core/providers/update_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/core/providers/workspace_provider.dart';
import 'package:Kelivo/core/providers/world_book_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:Kelivo/desktop/desktop_home_page.dart';
import 'package:Kelivo/desktop/desktop_settings_page.dart';
import 'package:Kelivo/desktop/hotkeys/hotkey_event_bus.dart';
import 'package:Kelivo/features/home/pages/home_page.dart';
import 'package:Kelivo/features/home/widgets/message_list_view.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';

import '../support/business_test_harness.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.root);
  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;
  @override
  Future<String?> getApplicationSupportPath() async => root;
  @override
  Future<String?> getApplicationCachePath() async => '$root/cache';
  @override
  Future<String?> getTemporaryPath() async => '$root/tmp';
}

Future<void> _finishIo(WidgetTester tester, Future<void> operation) async {
  var done = false;
  Object? error;
  operation.then<void>(
    (_) => done = true,
    onError: (Object value) {
      error = value;
      done = true;
    },
  );
  for (var i = 0; i < 500 && !done; i++) {
    await tester.pump(const Duration(milliseconds: 10));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
  }
  expect(done, isTrue, reason: 'background I/O did not finish');
  if (error != null) throw error!;
}

void main() {
  const desktopPlatforms = TargetPlatformVariant({
    TargetPlatform.windows,
    TargetPlatform.macOS,
    TargetPlatform.linux,
  });

  testWidgets('desktop disables all tab tickers when hidden or paused', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() {
      switch (tester.binding.lifecycleState) {
        case null:
        case AppLifecycleState.resumed:
          return;
        case AppLifecycleState.paused:
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.hidden,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
        case AppLifecycleState.hidden:
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
        case AppLifecycleState.inactive:
        case AppLifecycleState.detached:
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
      }
    });

    const windowChannel = MethodChannel('window_manager');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      windowChannel,
      (call) async {
        if (call.method == 'isMaximized') return false;
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        windowChannel,
        null,
      ),
    );

    late BusinessTestHarness harness;
    late Directory root;
    late SettingsProvider settings;
    late AssistantProvider assistants;
    late ChatService chat;
    final oldPaths = PathProviderPlatform.instance;
    await tester.runAsync(() async {
      root = await Directory.systemTemp.createTemp('desktop-ticker-mode-');
      PathProviderPlatform.instance = _Paths(root.path);
      harness = await BusinessTestHarness.create();
      settings = SettingsProvider(harness.preferences);
      assistants = AssistantProvider(preferences: harness.preferences);
      await Future.wait([settings.loaded, assistants.loaded]);
      await settings.setNewChatOnLaunch(false);
      chat = ChatService(
        existingRepository: ChatDatabaseRepository(harness.database),
      );
      final conversation = await chat.createConversation(
        title: 'Ticker test',
        assistantId: assistants.currentAssistantId,
      );
      await chat.addMessage(
        conversationId: conversation.id,
        role: 'user',
        content: 'Ticker test message',
      );
    });
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await _finishIo(tester, chat.close());
      settings.dispose();
      assistants.dispose();
      await tester.runAsync(() async {
        await harness.close();
        await root.delete(recursive: true);
      });
      PathProviderPlatform.instance = oldPaths;
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: assistants),
          ChangeNotifierProvider.value(value: chat),
          ChangeNotifierProvider(create: (_) => WorkspaceRuntimeProvider()),
          ChangeNotifierProvider(
            create: (_) => WorkspaceProvider(
              store: ExtensionEntityStore(harness.database),
            ),
          ),
          ChangeNotifierProvider(create: (_) => AsrProvider()),
          ChangeNotifierProvider(
            create: (_) => UserProvider(preferences: harness.preferences),
          ),
          ChangeNotifierProvider(
            create: (_) => BackupReminderProvider(
              preferences: harness.preferences,
              autoLoad: false,
            ),
          ),
          ChangeNotifierProvider(
            create: (_) => TagProvider(preferences: harness.preferences),
          ),
          ChangeNotifierProvider(create: (_) => UpdateProvider()),
          ChangeNotifierProvider(
            create: (_) => McpProvider(preferences: harness.preferences),
          ),
          ChangeNotifierProvider(
            create: (_) =>
                QuickPhraseProvider(preferences: harness.preferences),
          ),
          ChangeNotifierProvider(
            create: (_) =>
                InstructionInjectionProvider(preferences: harness.preferences),
          ),
          ChangeNotifierProvider(
            create: (_) => WorldBookProvider(preferences: harness.preferences),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DesktopHomePage(),
        ),
      ),
    );
    for (var i = 0; i < 50; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 50));
      final list = tester.widget<MessageListView>(find.byType(MessageListView));
      if (list.messages.isNotEmpty && !list.isLoadingWindow) break;
    }
    await tester.pumpAndSettle();

    bool tabTickerEnabled(Type pageType) {
      final element = tester.element(
        find.byType(pageType, skipOffstage: false),
      );
      return TickerMode.valuesOf(element).enabled;
    }

    expect(tabTickerEnabled(HomePage), isTrue);

    // Losing window focus keeps visible animations alive for secondary displays.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(tabTickerEnabled(HomePage), isTrue);

    for (final state in [AppLifecycleState.hidden, AppLifecycleState.paused]) {
      tester.binding.handleAppLifecycleStateChanged(state);
      expect(tester.binding.framesEnabled, isFalse, reason: state.name);
      tester.binding.scheduleWarmUpFrame();
      expect(tabTickerEnabled(HomePage), isFalse, reason: state.name);
    }

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(tabTickerEnabled(HomePage), isTrue);

    HotkeyEventBus.instance.fire(HotkeyAction.openSettings);
    await tester.pumpAndSettle();
    expect(tabTickerEnabled(HomePage), isFalse);
    expect(tabTickerEnabled(DesktopSettingsPage), isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.scheduleWarmUpFrame();
    expect(tabTickerEnabled(HomePage), isFalse);
    expect(tabTickerEnabled(DesktopSettingsPage), isFalse);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 350));
    expect(tabTickerEnabled(DesktopSettingsPage), isTrue);
    expect(tabTickerEnabled(HomePage), isFalse);
  }, variant: desktopPlatforms);
}
