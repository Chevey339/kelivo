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
import 'package:Kelivo/desktop/tools_popover.dart';
import 'package:Kelivo/features/home/services/local_tools_service.dart';
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

  setUp(() async {
    preferences = createBusinessTestPreferences();
    await preferences.setStringList('display_chat_tools_expanded_groups_v1', [
      'mcp',
    ]);
  });

  /// Loads the provider outside the fake clock: it reads through drift, and a
  /// widget test's timers never advance on their own.
  Future<AssistantProvider> loadAssistantWithMcp(
    WidgetTester tester, {
    List<String> localToolIds = const [],
  }) async {
    late AssistantProvider provider;
    await tester.runAsync(() async {
      await preferences.setString(
        'assistants_v1',
        jsonEncode([
          {
            'id': 'assistant-1',
            'name': 'Assistant',
            'mcpServerIds': ['server-1'],
            'localToolIds': localToolIds,
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
    String? providerKey = 'SomeProvider',
    String? modelId = 'no-tools-model',
    bool supportsTools = false,
    bool desktopTools = false,
    double composerWidth = 800,
    VoidCallback? openBrowser,
  }) async {
    final settings = settingsOverride ?? SettingsProvider(preferences);
    final inputBarKey = GlobalKey();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<BusinessPreferences>.value(value: preferences),
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: assistants),
          ChangeNotifierProvider(create: (_) => AsrProvider()),
          ChangeNotifierProvider(
            create: (_) => WorldBookProvider(preferences: preferences),
          ),
          ChangeNotifierProvider(
            create: (_) =>
                InstructionInjectionProvider(preferences: preferences),
          ),
          ChangeNotifierProvider(
            create: (_) => McpProvider(preferences: preferences),
          ),
          ChangeNotifierProvider(
            create: (_) => QuickPhraseProvider(preferences: preferences),
          ),
        ],
        child: MaterialApp(
          theme: desktopTools
              ? ThemeData(platform: TargetPlatform.macOS)
              : null,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final section = ChatInputSection(
                  inputBarKey: inputBarKey,
                  chatModelProviderKey: providerKey,
                  chatModelId: modelId,
                  chatModelIsConversationOverride: isConversationOverride,
                  inputFocus: FocusNode(),
                  inputController: TextEditingController(),
                  mediaController: ChatInputBarController(),
                  isTablet: desktopTools,
                  isLoading: false,
                  isToolModel: (_, _) => supportsTools,
                  isReasoningModel: (_, _) => supportsReasoning,
                  isReasoningEnabled: (request) =>
                      request.level != ReasoningLevel.off,
                  onOpenBrowser: desktopTools ? openBrowser ?? () {} : null,
                  onOpenTools: desktopTools
                      ? () => showDesktopToolsPopover(
                          context,
                          anchorKey: inputBarKey,
                          assistantId: assistants.currentAssistant!.id,
                          supportsModelTools:
                              providerKey != null &&
                              modelId != null &&
                              supportsTools,
                        )
                      : null,
                );
                return desktopTools
                    ? Align(
                        alignment: Alignment.bottomCenter,
                        child: SizedBox(width: composerWidth, child: section),
                      )
                    : section;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  for (final scenario in [
    (name: 'no model', providerKey: null, modelId: null, supportsTools: false),
    (
      name: 'a model without tools',
      providerKey: 'SomeProvider',
      modelId: 'no-tools-model',
      supportsTools: false,
    ),
    (
      name: 'a tool-capable model',
      providerKey: 'SomeProvider',
      modelId: 'tool-model',
      supportsTools: true,
    ),
  ]) {
    testWidgets('desktop browser entry stays available with ${scenario.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final assistants = await loadAssistantWithMcp(
        tester,
        localToolIds: const [LocalToolNames.browser],
      );
      await pumpComposer(
        tester,
        assistants: assistants,
        isConversationOverride: true,
        providerKey: scenario.providerKey,
        modelId: scenario.modelId,
        supportsTools: scenario.supportsTools,
        desktopTools: true,
      );
      final bar = tester.widget<ChatInputBar>(find.byType(ChatInputBar));
      expect(bar.showToolsButton, scenario.supportsTools);
      expect(bar.toolsActive, scenario.supportsTools);
      expect(bar.onOpenBrowser, isNotNull);
      expect(find.byTooltip('Open browser'), findsOneWidget);
      if (scenario.supportsTools) {
        await tester.tap(find.byTooltip('Tools'));
        await tester.pumpAndSettle();
        expect(find.text('Open browser'), findsNothing);
        expect(find.text('Local Tools'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Browser control'),
          200,
          scrollable: find
              .descendant(
                of: find.byType(ListView).last,
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(find.text('Browser control'), findsOneWidget);
      } else {
        expect(find.byTooltip('Tools'), findsNothing);
      }
      expect(assistants.currentAssistant!.localToolIds, [
        LocalToolNames.browser,
      ]);
      expect(assistants.currentAssistant!.mcpServerIds, ['server-1']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'narrow desktop moves browser action into More without model tools',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var opened = false;
      final assistants = await loadAssistantWithMcp(tester);
      await pumpComposer(
        tester,
        assistants: assistants,
        isConversationOverride: true,
        desktopTools: true,
        composerWidth: 220,
        openBrowser: () => opened = true,
      );
      expect(find.byTooltip('Tools'), findsNothing);
      await tester.tap(find.byTooltip('Add'));
      await tester.pumpAndSettle();
      expect(find.text('Open browser'), findsOneWidget);
      await tester.tap(find.text('Open browser'));
      await tester.pumpAndSettle();
      expect(opened, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

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
