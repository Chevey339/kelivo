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
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_switch.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';

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

const _warningEn =
    'Using time variables in the system prompt makes the beginning of every request different';

const _formatExample = '<current_time>Mon 2026-08-08 14:30:05</current_time>';

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

  testWidgets('time-variable warning appears for each cur_* token', (
    tester,
  ) async {
    for (final token in ['{cur_date}', '{cur_time}', '{cur_datetime}']) {
      final bundle = await _createAssistantProvider(
        tester,
        systemPrompt: 'Hello $token',
      );
      final assistantProvider = bundle.assistantProvider;
      _setLargeSurface(tester);
      await tester.pumpWidget(
        _buildHarness(
          assistantProvider: assistantProvider,
          chatService: bundle.chatService,
          memoryV2: bundle.memoryV2,
          pipeline: bundle.pipeline,
          child: const AssistantSettingsEditPage(assistantId: _assistantId),
        ),
      );
      await _openPromptsTab(tester);

      expect(find.textContaining(_warningEn), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });

  testWidgets('time-variable warning does not appear for timezone or none', (
    tester,
  ) async {
    for (final prompt in ['timezone is {timezone}', 'plain system prompt']) {
      final bundle = await _createAssistantProvider(
        tester,
        systemPrompt: prompt,
      );
      final assistantProvider = bundle.assistantProvider;
      _setLargeSurface(tester);
      await tester.pumpWidget(
        _buildHarness(
          assistantProvider: assistantProvider,
          chatService: bundle.chatService,
          memoryV2: bundle.memoryV2,
          pipeline: bundle.pipeline,
          child: const AssistantSettingsEditPage(assistantId: _assistantId),
        ),
      );
      await _openPromptsTab(tester);

      expect(find.textContaining(_warningEn), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });

  testWidgets(
    'time-variable warning updates live while editing system prompt',
    (tester) async {
      final bundle = await _createAssistantProvider(tester);
      final assistantProvider = bundle.assistantProvider;
      _setLargeSurface(tester);
      await tester.pumpWidget(
        _buildHarness(
          assistantProvider: assistantProvider,
          chatService: bundle.chatService,
          memoryV2: bundle.memoryV2,
          pipeline: bundle.pipeline,
          child: const AssistantSettingsEditPage(assistantId: _assistantId),
        ),
      );
      await _openPromptsTab(tester);

      expect(find.textContaining(_warningEn), findsNothing);

      await tester.enterText(_systemPromptField(), 'now is {cur_time}');
      await tester.pump();
      expect(find.textContaining(_warningEn), findsOneWidget);

      await tester.enterText(_systemPromptField(), 'stable {timezone}');
      await tester.pump();
      expect(find.textContaining(_warningEn), findsNothing);
    },
  );

  testWidgets('append current time switch persists on assistant', (
    tester,
  ) async {
    final bundle = await _createAssistantProvider(tester);
    final assistantProvider = bundle.assistantProvider;
    _setLargeSurface(tester);
    await tester.pumpWidget(
      _buildHarness(
        assistantProvider: assistantProvider,
        chatService: bundle.chatService,
        memoryV2: bundle.memoryV2,
        pipeline: bundle.pipeline,
        child: const AssistantSettingsEditPage(assistantId: _assistantId),
      ),
    );
    await _openPromptsTab(tester);

    expect(
      assistantProvider.getById(_assistantId)!.appendCurrentTimeToUserMessage,
      isFalse,
    );

    expect(find.text('Append current time'), findsOneWidget);
    final appendRow = find.ancestor(
      of: find.text('Append current time'),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Padding &&
            widget.padding ==
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
    final sw = tester.widget<IosSwitch>(
      find.descendant(of: appendRow, matching: find.byType(IosSwitch)),
    );
    expect(sw.value, isFalse);
    sw.onChanged!(true);
    await tester.pump();
    for (var i = 0; i < 40; i++) {
      if (assistantProvider
          .getById(_assistantId)!
          .appendCurrentTimeToUserMessage) {
        break;
      }
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(
      assistantProvider.getById(_assistantId)!.appendCurrentTimeToUserMessage,
      isTrue,
    );
  });

  testWidgets('append current time info dialog shows format example', (
    tester,
  ) async {
    final bundle = await _createAssistantProvider(tester);
    final assistantProvider = bundle.assistantProvider;
    _setLargeSurface(tester);
    await tester.pumpWidget(
      _buildHarness(
        assistantProvider: assistantProvider,
        chatService: bundle.chatService,
        memoryV2: bundle.memoryV2,
        pipeline: bundle.pipeline,
        child: const AssistantSettingsEditPage(assistantId: _assistantId),
      ),
    );
    await _openPromptsTab(tester);

    final infoButton = tester.widget<IosIconButton>(
      find.byWidgetPredicate(
        (widget) =>
            widget is IosIconButton &&
            widget.icon == Lucide.BadgeInfo &&
            widget.semanticLabel == 'Appended time format',
      ),
    );
    infoButton.onTap!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Appended time format'), findsWidgets);
    expect(find.textContaining(_formatExample), findsOneWidget);
  });
}
