import 'dart:io';

import 'package:Kelivo/core/database/chat_database_repository.dart';
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
import 'package:Kelivo/core/providers/world_book_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/home/pages/home_desktop_layout.dart';
import 'package:Kelivo/features/home/pages/home_page.dart';
import 'package:Kelivo/features/home/widgets/chat_input_bar.dart';
import 'package:Kelivo/features/home/widgets/chat_selection_app_bar.dart';
import 'package:Kelivo/features/home/widgets/message_list_view.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/interactive_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';

import '../../../support/business_test_harness.dart';

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
  expect(done, isTrue, reason: 'draft I/O did not finish');
  if (error != null) throw error!;
}

void main() {
  for (final share in [true, false]) {
    testWidgets(
      'Android back cancels ${share ? 'sharing' : 'deleting'} after an open drawer changes to wide layout',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final platformCalls = <MethodCall>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async => platformCalls.add(call),
        );
        addTearDown(() {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          );
        });

        late BusinessTestHarness harness;
        late Directory root;
        late SettingsProvider settings;
        late AssistantProvider assistants;
        late ChatService chat;
        final oldPaths = PathProviderPlatform.instance;
        await tester.runAsync(() async {
          root = await Directory.systemTemp.createTemp('home-selection-back-');
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
            title: 'Selection test',
            assistantId: assistants.currentAssistantId,
          );
          await chat.addMessage(
            conversationId: conversation.id,
            role: 'user',
            content: 'Select this message',
          );
        });
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          // Composer disposal starts work in the fake-clock zone. Advance it
          // alongside real file/DB I/O until ChatService has flushed the draft.
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
                create: (_) => InstructionInjectionProvider(
                  preferences: harness.preferences,
                ),
              ),
              ChangeNotifierProvider(
                create: (_) =>
                    WorldBookProvider(preferences: harness.preferences),
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: HomePage(),
            ),
          ),
        );
        for (var i = 0; i < 50; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 50));
          final list = tester.widget<MessageListView>(
            find.byType(MessageListView),
          );
          if (list.messages.isNotEmpty && !list.isLoadingWindow) break;
        }
        await tester.pumpAndSettle();
        final list = tester.widget<MessageListView>(
          find.byType(MessageListView),
        );
        expect(list.messages, hasLength(1));
        if (share) {
          list.onShareMessage!(0, list.messages);
        } else {
          list.onSelectMessages!(0, list.messages);
        }
        await tester.pumpAndSettle();
        expect(find.byType(ChatSelectionAppBar), findsOneWidget);

        final drawer = tester
            .widget<InteractiveDrawer>(find.byType(InteractiveDrawer))
            .controller!;
        await drawer.open();
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(drawer.isClosed, isTrue);
        expect(find.byType(ChatSelectionAppBar), findsOneWidget);

        await drawer.open();
        await tester.pumpAndSettle();
        tester.view.physicalSize = const Size(1100, 800);
        await tester.pumpAndSettle();
        expect(find.byType(HomeDesktopScaffold), findsOneWidget);
        expect(find.byType(InteractiveDrawer), findsNothing);
        expect(drawer.isOpen, isTrue);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(ChatSelectionAppBar), findsNothing);
        expect(find.byType(ChatInputBar), findsOneWidget);
        expect(
          tester
              .widget<MessageListView>(find.byType(MessageListView))
              .selecting,
          isFalse,
        );
        expect(
          platformCalls.where((c) => c.method == 'SystemNavigator.pop'),
          isEmpty,
        );
        await tester.binding.handlePopRoute();
        expect(
          platformCalls.where((c) => c.method == 'SystemNavigator.pop'),
          hasLength(1),
        );
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }
}
