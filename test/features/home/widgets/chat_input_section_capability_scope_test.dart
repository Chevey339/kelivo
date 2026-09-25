import 'dart:convert';

import 'package:Kelivo/core/providers/asr_provider.dart';
import 'package:Kelivo/core/models/reasoning_request.dart';
import 'package:Kelivo/core/models/model_spec.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/instruction_injection_provider.dart';
import 'package:Kelivo/core/providers/mcp_provider.dart';
import 'package:Kelivo/core/providers/quick_phrase_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/world_book_provider.dart';
import 'package:Kelivo/features/home/widgets/chat_input_bar.dart';
import 'package:Kelivo/features/home/widgets/chat_input_section.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../support/business_test_harness.dart';

/// The composer force-disables capabilities the current model lacks by writing
/// to the ASSISTANT. Once a conversation can pin its own model, that write
/// would reach every other conversation sharing the assistant, so it has to be
/// scoped to the case where the assistant really is the source of the model.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BusinessPreferences preferences;

  setUp(() {
    preferences = createBusinessTestPreferences();
  });

  /// Loads the provider outside the fake clock: it reads through drift, and a
  /// widget test's timers never advance on their own.
  Future<AssistantProvider> loadAssistantWithMcp(WidgetTester tester) async {
    late AssistantProvider provider;
    await tester.runAsync(() async {
      await preferences.setString(
        'assistants_v1',
        jsonEncode([
          {
            'id': 'assistant-1',
            'name': 'Assistant',
            'mcpServerIds': ['server-1'],
          },
        ]),
      );
      await preferences.setString('current_assistant_id_v1', 'assistant-1');
      provider = AssistantProvider(preferences: preferences);
      for (var i = 0; i < 100; i++) {
        if (provider.currentAssistant != null) break;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    return provider;
  }

  Future<void> pumpComposer(
    WidgetTester tester, {
    required AssistantProvider assistants,
    required bool isConversationOverride,
    SettingsProvider? settingsOverride,
    bool supportsReasoning = false,
  }) async {
    final settings = settingsOverride ?? SettingsProvider(preferences);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: assistants),
          ChangeNotifierProvider(create: (_) => AsrProvider()),
          ChangeNotifierProvider(
            create: (_) => McpProvider(preferences: preferences),
          ),
          ChangeNotifierProvider(
            create: (_) => QuickPhraseProvider(preferences: preferences),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ChatInputSection(
              inputBarKey: GlobalKey(),
              chatModelProviderKey: 'SomeProvider',
              chatModelId: 'no-tools-model',
              chatModelIsConversationOverride: isConversationOverride,
              inputFocus: FocusNode(),
              inputController: TextEditingController(),
              mediaController: ChatInputBarController(),
              isTablet: false,
              isLoading: false,
              // The model in play supports neither tools nor reasoning, which
              // is what triggers the enforcement under test.
              isToolModel: (_, _) => false,
              isReasoningModel: (_, _) => supportsReasoning,
              isReasoningEnabled: (request) =>
                  request.level != ReasoningLevel.off,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('a conversation-pinned model leaves the assistant alone', (
    tester,
  ) async {
    final assistants = await loadAssistantWithMcp(tester);

    await pumpComposer(
      tester,
      assistants: assistants,
      isConversationOverride: true,
    );

    expect(
      assistants.currentAssistant?.mcpServerIds,
      const ['server-1'],
      reason:
          'one conversation must not rewrite settings shared by all of them',
    );
  });

  testWidgets('composer badge and active state reflect the effective level', (
    tester,
  ) async {
    late AssistantProvider assistants;
    late SettingsProvider settings;
    addTearDown(() => settings.dispose());
    addTearDown(() => assistants.dispose());
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    ProviderConfig config(bool canDisable) => ProviderConfig(
      id: 'SomeProvider',
      enabled: true,
      name: 'Test',
      apiKey: '',
      baseUrl: '',
      modelOverrides: {
        'no-tools-model': {
          'abilities': ['reasoning'],
          'reasoning': {
            'dialect': 'openaiReasoningEffort',
            'levels': ['low', 'high'],
            'canDisable': canDisable,
          },
        },
      },
    );
    await tester.runAsync(() async {
      final harness = await createBusinessTestHarness();
      preferences = harness.preferences;
      settings = SettingsProvider(preferences);
      assistants = AssistantProvider(preferences: preferences);
      await settings.loaded;
      await assistants.loaded;
      final id = await assistants.addAssistant(name: 'A');
      await assistants.setCurrentAssistant(id);
      await settings.setProviderConfig('SomeProvider', config(false));
      await settings.setShowReasoningLevelBadge(true);
      await assistants.updateAssistant(
        assistants.currentAssistant!.copyWith(
          reasoning: const ReasoningRequest(ReasoningLevel.max),
        ),
      );
    });
    // Background providers use the widget clock. Keep their store separate
    // from the real-clock settings writes exercised with runAsync below.
    preferences = createBusinessTestPreferences();
    await pumpComposer(
      tester,
      assistants: assistants,
      isConversationOverride: true,
      settingsOverride: settings,
      supportsReasoning: true,
    );
    ChatInputBar bar() =>
        tester.widget<ChatInputBar>(find.byType(ChatInputBar));
    expect(bar().reasoning!.level, ReasoningLevel.high);
    expect(find.text('high'), findsOneWidget);
    expect(find.text('max'), findsNothing);

    await tester.runAsync(
      () => assistants.updateAssistant(
        assistants.currentAssistant!.copyWith(reasoning: ReasoningRequest.off),
      ),
    );
    await tester.pumpAndSettle();
    expect(bar().reasoning!.level, ReasoningLevel.low);
    expect(bar().reasoningActive, isTrue);
    expect(find.text('low'), findsOneWidget);

    await tester.runAsync(
      () => settings.setProviderConfig('SomeProvider', config(true)),
    );
    await tester.pumpAndSettle();
    expect(bar().reasoning!.level, ReasoningLevel.off);
    expect(bar().reasoningActive, isFalse);
  });

  testWidgets('the assistant\'s own model still disables what it cannot do', (
    tester,
  ) async {
    final assistants = await loadAssistantWithMcp(tester);

    await pumpComposer(
      tester,
      assistants: assistants,
      isConversationOverride: false,
    );

    expect(assistants.currentAssistant?.mcpServerIds, isEmpty);
  });

  Future<void> pumpTabletComposer(
    WidgetTester tester, {
    required AssistantProvider assistants,
    required String modelId,
  }) async {
    final settings = SettingsProvider(preferences);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: assistants),
          ChangeNotifierProvider(create: (_) => AsrProvider()),
          ChangeNotifierProvider(
            create: (_) => McpProvider(preferences: preferences),
          ),
          ChangeNotifierProvider(
            create: (_) => QuickPhraseProvider(preferences: preferences),
          ),
          ChangeNotifierProvider(
            create: (_) => WorldBookProvider(preferences: preferences),
          ),
          ChangeNotifierProvider(
            create: (_) =>
                InstructionInjectionProvider(preferences: preferences),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ChatInputSection(
              inputBarKey: GlobalKey(),
              chatModelProviderKey: 'SomeProvider',
              chatModelId: modelId,
              inputFocus: FocusNode(),
              inputController: TextEditingController(),
              mediaController: ChatInputBarController(),
              isTablet: true,
              isLoading: false,
              isToolModel: (_, _) => false,
              isReasoningModel: (_, _) => false,
              isReasoningEnabled: (_) => false,
              onPickCamera: () {},
              onPickPhotos: () {},
              onUploadFiles: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('tablet camera and photos stay available for a text-only model', (
    tester,
  ) async {
    final assistants = await loadAssistantWithMcp(tester);
    await pumpTabletComposer(
      tester,
      assistants: assistants,
      modelId: 'mimo-v2.5-pro',
    );
    final bar = tester.widget<ChatInputBar>(find.byType(ChatInputBar));
    expect(bar.onPickCamera, isNotNull);
    expect(bar.onPickPhotos, isNotNull);
    expect(bar.onUploadFiles, isNotNull);
  });

  testWidgets('tablet camera and photos show when the spec accepts image', (
    tester,
  ) async {
    final assistants = await loadAssistantWithMcp(tester);
    await pumpTabletComposer(tester, assistants: assistants, modelId: 'gpt-4o');
    final bar = tester.widget<ChatInputBar>(find.byType(ChatInputBar));
    expect(bar.onPickCamera, isNotNull);
    expect(bar.onPickPhotos, isNotNull);
    expect(bar.onUploadFiles, isNotNull);
  });
}
