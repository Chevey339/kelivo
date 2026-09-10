import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/chat/prepared_context_store.dart';
import 'package:Kelivo/core/services/logging/context_logger.dart';
import 'package:Kelivo/features/chat/widgets/chat_context_inspector.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_switch.dart';
import '../../../support/business_test_harness.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
}

class _Chat extends ChatService {
  final conversation = Conversation(id: 'c1', title: 'Test');
  @override
  Conversation? getConversation(String id) => id == 'c1' ? conversation : null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BusinessTestHarness harness;
  late SettingsProvider settings;
  late AssistantProvider assistants;
  late _Chat chat;
  late Directory directory;
  late PathProviderPlatform previousPaths;

  setUp(() async {
    directory = Directory.systemTemp.createTempSync('kelivo_context_ui_');
    previousPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(directory.path);
    harness = await BusinessTestHarness.create(
      initial: {
        'assistants_v1': Assistant.encodeList([
          const Assistant(
            id: 'a',
            name: 'A',
            chatModelProvider: 'fixture',
            chatModelId: 'alias',
            localToolIds: ['get_time_info'],
            mcpServerIds: ['disconnected'],
          ),
        ]),
      },
    );
    chat = _Chat();
    settings = SettingsProvider(harness.preferences);
    await settings.loaded;
    await ContextLogger.setEnabled(false);
    assistants = AssistantProvider(
      preferences: harness.preferences,
      chatService: chat,
    );
    await assistants.loaded;
  });
  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    assistants.dispose();
    settings.dispose();
    chat.dispose();
    await harness.close();
    PathProviderPlatform.instance = previousPaths;
    await directory.delete(recursive: true);
  });

  Widget app() => MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: assistants),
      ChangeNotifierProvider.value(value: settings),
      ChangeNotifierProvider<ChatService>.value(value: chat),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: const TextScaler.linear(1.3)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showChatContextInspector(
              context,
              assistantId: 'a',
              conversationId: 'c1',
              isToolModel: (_, _) => false,
            ),
            child: const Text('Open context'),
          ),
        ),
      ),
    ),
  );

  for (final platform in [TargetPlatform.android, TargetPlatform.linux]) {
    testWidgets(
      '$platform opens the right surface, without sending or enabling logs',
      (tester) async {
        tester.view.physicalSize = Size(
          platform == TargetPlatform.android ? 390 : 780,
          1000,
        );
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(app());
        await tester.tap(find.text('Open context'));
        await tester.pumpAndSettle();
        expect(
          find.byType(Dialog),
          platform == TargetPlatform.linux ? findsOneWidget : findsNothing,
        );
        expect(
          find.byType(BottomSheet),
          platform == TargetPlatform.android ? findsOneWidget : findsNothing,
        );
        expect(find.text('Current configuration'), findsOneWidget);
        expect(chat.preparedContexts.forConversation('c1'), isNull);
        expect(ContextLogger.enabled, isFalse);
        await tester.runAsync(() async {
          tester
              .widget<IosSwitch>(
                find.byKey(const ValueKey('runtime-context-time')),
              )
              .onChanged!(true);
          await harness.database.customSelect('SELECT 1').getSingle();
        });
        await tester.pumpAndSettle();
        expect(assistants.getById('a')!.appendCurrentTimeToUserMessage, isTrue);
        expect(assistants.getById('a')!.mcpServerIds, ['disconnected']);
        expect(chat.preparedContexts.forConversation('c1'), isNull);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({platform}),
    );
  }

  testWidgets(
    'details show actual snapshot, not current settings, and clear on removal',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      chat.recordPreparedContext(
        PreparedContextSnapshot(
          generationId: 'g1',
          context: ContextLogger.buildSnapshot(
            apiMessages: [
              {'role': 'system', 'content': 'request-only-marker'},
              {'role': 'user', 'content': 'sent text'},
            ],
            conversationId: 'c1',
            assistantName: 'A',
            provider: 'Fixture',
            model: 'previous-model',
          ),
          tools: [
            {
              'type': 'function',
              'function': {'name': 'previous_tool'},
            },
          ],
        ),
      );
      await tester.pumpWidget(app());
      await tester.tap(find.text('Open context'));
      await tester.pumpAndSettle();
      expect(find.textContaining('previous-model'), findsOneWidget);
      expect(find.text('request-only-marker'), findsNothing);
      final details = find.byKey(const ValueKey('context-inspector-details'));
      await tester.ensureVisible(details);
      await tester.tap(details);
      await tester.pumpAndSettle();
      expect(find.text('request-only-marker'), findsOneWidget);
      expect(find.textContaining('previous_tool'), findsOneWidget);
      chat.preparedContexts.remove('c1');
      await tester.pumpAndSettle();
      expect(find.text('request-only-marker'), findsNothing);
      expect(find.textContaining('No request snapshot'), findsOneWidget);
      expect(ContextLogger.enabled, isFalse);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({TargetPlatform.linux}),
  );
}
