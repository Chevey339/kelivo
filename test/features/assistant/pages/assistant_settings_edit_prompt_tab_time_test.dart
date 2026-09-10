import 'dart:io';
import "../../../support/business_test_harness.dart";
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/memory_provider.dart';
import 'package:Kelivo/core/providers/memory_provider_v2.dart';
import 'package:Kelivo/core/providers/quick_phrase_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/memory/memory_pipeline.dart';
import 'package:Kelivo/core/services/memory/memory_repository.dart';
import 'package:Kelivo/core/services/tts/tts_playback_models.dart';
import 'package:Kelivo/features/assistant/pages/assistant_settings_edit_page.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_switch.dart';

class _FakeTtsProvider extends ChangeNotifier implements TtsProvider {
  @override
  TtsPlaybackState get playbackState => const TtsPlaybackState();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;

  @override
  Future<String?> getApplicationSupportPath() async => path;

  @override
  Future<String?> getApplicationCachePath() async => '$path/cache';

  @override
  Future<String?> getTemporaryPath() async => '$path/tmp';
}

const _assistantId = 'assistant-prompt-time-test';

Future<
  ({
    AssistantProvider assistantProvider,
    ChatService chatService,
    MemoryProviderV2 memoryV2,
    MemoryPipelineService pipeline,
  })
>
_createAssistantProvider(
  WidgetTester tester, {
  String systemPrompt = '',
  bool appendCurrentTimeToUserMessage = false,
}) async {
  final tempDir = await tester.runAsync(
    () => Directory.systemTemp.createTemp('kelivo_asst_edit_'),
  );
  final previousPathProvider = PathProviderPlatform.instance;
  PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir!.path);
  addTearDown(() async {
    PathProviderPlatform.instance = previousPathProvider;
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  final harness = await createBusinessTestHarness(
    initial: {
      'assistants_v1': Assistant.encodeList([
        Assistant(
          id: _assistantId,
          name: 'Test Assistant',
          temperature: 0.6,
          systemPrompt: systemPrompt,
          appendCurrentTimeToUserMessage: appendCurrentTimeToUserMessage,
        ),
      ]),
    },
  );
  final chatRepository = ChatDatabaseRepository(harness.database);
  await chatRepository.ensureReady();
  final chatService = ChatService(existingRepository: chatRepository);

  final provider = AssistantProvider(
    preferences: harness.preferences,
    chatService: chatService,
  );
  for (var i = 0; i < 25; i++) {
    if (provider.getById(_assistantId) != null) break;
    await tester.pump(const Duration(milliseconds: 10));
  }
  final memoryV2 = MemoryProviderV2(
    repository: MemoryRepository(harness.preferences),
    chatRepository: chatRepository,
  );
  final settings = SettingsProvider(harness.preferences);
  final pipeline = MemoryPipelineService(
    chatService: chatService,
    repository: memoryV2.repository,
    chatRepository: chatRepository,
    settings: () => settings,
    assistants: () => provider,
    memoryV2: () => memoryV2,
    generateText:
        ({
          required config,
          required modelId,
          required prompt,
          String? conversationId,
          int? thinkingBudget,
        }) async => '<user_memory>false</user_memory>',
  );
  return (
    assistantProvider: provider,
    chatService: chatService,
    memoryV2: memoryV2,
    pipeline: pipeline,
  );
}

Widget _buildHarness({
  required AssistantProvider assistantProvider,
  required ChatService chatService,
  required MemoryProviderV2 memoryV2,
  required MemoryPipelineService pipeline,
  required Widget child,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => SettingsProvider(assistantProvider.preferences),
      ),
      ChangeNotifierProvider.value(value: assistantProvider),
      ChangeNotifierProvider.value(value: chatService),
      ChangeNotifierProvider(
        create: (_) =>
            MemoryProvider(preferences: assistantProvider.preferences),
      ),
      ChangeNotifierProvider.value(value: memoryV2),
      Provider.value(value: pipeline),
      ChangeNotifierProvider(
        create: (_) =>
            QuickPhraseProvider(preferences: assistantProvider.preferences),
      ),
      ChangeNotifierProvider(
        create: (_) => UserProvider(preferences: assistantProvider.preferences),
      ),
      ChangeNotifierProvider<TtsProvider>(create: (_) => _FakeTtsProvider()),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

void _setLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _openPromptsTab(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.text('Prompts'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Finder _systemPromptField() {
  return find.byWidgetPredicate(
    (widget) =>
        widget is TextField &&
        (widget.decoration?.hintText?.contains('system prompt') ?? false),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AssistantProvider> open(
    WidgetTester tester, {
    String prompt = '',
    bool enabled = false,
  }) async {
    final bundle = await _createAssistantProvider(
      tester,
      systemPrompt: prompt,
      appendCurrentTimeToUserMessage: enabled,
    );
    _setLargeSurface(tester);
    await tester.pumpWidget(
      _buildHarness(
        assistantProvider: bundle.assistantProvider,
        chatService: bundle.chatService,
        memoryV2: bundle.memoryV2,
        pipeline: bundle.pipeline,
        child: const AssistantSettingsEditPage(assistantId: _assistantId),
      ),
    );
    await _openPromptsTab(tester);
    return bundle.assistantProvider;
  }

  testWidgets('context options are visible while templates start folded', (
    tester,
  ) async {
    final provider = await open(tester);
    expect(find.text('Built-in context'), findsOneWidget);
    expect(find.text('Custom instructions'), findsOneWidget);
    expect(find.textContaining('refreshed when sending'), findsOneWidget);
    expect(find.textContaining('get_time_info'), findsOneWidget);
    for (final id in ['time', 'locale', 'model']) {
      final toggle = tester.widget<IosSwitch>(
        find.byKey(ValueKey('runtime-context-$id')),
      );
      expect(toggle.value, isFalse);
      toggle.onChanged!(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }
    final assistant = provider.getById(_assistantId)!;
    expect(assistant.appendCurrentTimeToUserMessage, isTrue);
    expect(assistant.includeAppLocaleInContext, isTrue);
    expect(assistant.includeModelInfoInContext, isTrue);
    expect(find.text('Available variables:'), findsNothing);
    await tester.tap(find.text('Advanced · variables and message templates'));
    await tester.pump();
    expect(find.text('Available variables:'), findsWidgets);
  });

  testWidgets(
    'time conflict is non-blocking and never rewrites custom instructions',
    (tester) async {
      const prompt = 'Current: {cur_datetime}';
      final provider = await open(tester, prompt: prompt);
      expect(
        find.byKey(const ValueKey('runtime-context-time-warning')),
        findsNothing,
      );
      tester
          .widget<IosSwitch>(find.byKey(const ValueKey('runtime-context-time')))
          .onChanged!(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        provider.getById(_assistantId)!.appendCurrentTimeToUserMessage,
        isTrue,
      );
      expect(provider.getById(_assistantId)!.systemPrompt, prompt);
      expect(
        find.byKey(const ValueKey('runtime-context-time-warning')),
        findsOneWidget,
      );
      await tester.enterText(_systemPromptField(), 'Stable instructions');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.byKey(const ValueKey('runtime-context-time-warning')),
        findsNothing,
      );
    },
  );

  testWidgets('existing time choice is retained and new choices remain off', (
    tester,
  ) async {
    await open(tester, enabled: true);
    expect(
      tester
          .widget<IosSwitch>(find.byKey(const ValueKey('runtime-context-time')))
          .value,
      isTrue,
    );
    expect(
      tester
          .widget<IosSwitch>(
            find.byKey(const ValueKey('runtime-context-locale')),
          )
          .value,
      isFalse,
    );
    expect(
      tester
          .widget<IosSwitch>(
            find.byKey(const ValueKey('runtime-context-model')),
          )
          .value,
      isFalse,
    );
  });
}
