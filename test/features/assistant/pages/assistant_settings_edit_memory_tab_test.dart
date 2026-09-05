import 'dart:io';

import 'package:flutter/foundation.dart';
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
import 'package:Kelivo/features/settings/pages/memory_settings_page.dart';
import 'package:Kelivo/features/settings/widgets/memory_ui.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

import '../../../support/business_test_harness.dart';

class _FakeTtsProvider extends ChangeNotifier implements TtsProvider {
  @override
  TtsPlaybackState get playbackState => const TtsPlaybackState();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _assistantId = 'assistant-memory-tab-test';

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

Future<
  (AssistantProvider, ChatService, MemoryProviderV2, MemoryPipelineService)
>
_createProviders(WidgetTester tester) async {
  // Real filesystem IO must leave the fake-async zone used by testWidgets.
  final tempDir = await tester.runAsync(
    () => Directory.systemTemp.createTemp('kelivo_mem_tab_'),
  );
  final previous = PathProviderPlatform.instance;
  PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir!.path);
  addTearDown(() async {
    PathProviderPlatform.instance = previous;
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  final harness = await createBusinessTestHarness(
    initial: {
      'assistants_v1': Assistant.encodeList([
        Assistant(id: _assistantId, name: 'Memory Assistant', temperature: 0.6),
      ]),
    },
  );
  final chatRepository = ChatDatabaseRepository(harness.database);
  await chatRepository.ensureReady();
  // Skip ChatService.init() — AppDirectories + asset maintenance are out of
  // scope for switch UI tests.
  final chatService = ChatService(existingRepository: chatRepository);

  final assistantProvider = AssistantProvider(
    preferences: harness.preferences,
    chatService: chatService,
  );
  for (var i = 0; i < 25; i++) {
    if (assistantProvider.getById(_assistantId) != null) break;
    await tester.pump(const Duration(milliseconds: 10));
  }

  final memoryV2 = MemoryProviderV2(
    repository: MemoryRepository(harness.preferences),
    chatRepository: chatRepository,
  );
  final pipeline = MemoryPipelineService(
    chatService: chatService,
    repository: memoryV2.repository,
    chatRepository: chatRepository,
    settings: () => SettingsProvider(harness.preferences),
    assistants: () => assistantProvider,
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
  return (assistantProvider, chatService, memoryV2, pipeline);
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

Future<void> _openMemoryTab(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  final tab = find.text('Memory');
  await tester.ensureVisible(tab);
  await tester.tap(tab.hitTestable());
  // Wait for TabController.animateTo + TabBarView slide.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  expect(find.text('Use long-term memory').hitTestable(), findsOneWidget);
}

Future<void> _tapSwitchNearLabel(WidgetTester tester, String label) async {
  final target = find.text(label).hitTestable();
  await tester.ensureVisible(target);
  await tester.tap(target);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('memory tab switches persist and reveal nested rows', (
    tester,
  ) async {
    final (ap, chat, memoryV2, pipeline) = await _createProviders(tester);
    _setLargeSurface(tester);

    await tester.pumpWidget(
      _buildHarness(
        assistantProvider: ap,
        chatService: chat,
        memoryV2: memoryV2,
        pipeline: pipeline,
        child: const AssistantSettingsEditPage(assistantId: _assistantId),
      ),
    );
    await _openMemoryTab(tester);

    expect(find.text('Use long-term memory'), findsOneWidget);
    expect(find.text('Auto-organize memory'), findsNothing);
    expect(find.text('Memory write scope'), findsNothing);

    await _tapSwitchNearLabel(tester, 'Use long-term memory');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    var a = ap.getById(_assistantId)!;
    expect(a.enableMemory, isTrue);
    expect(find.text('Auto-organize memory'), findsOneWidget);
    expect(find.text('Memory write scope'), findsOneWidget);
    expect(find.text('Organize every N turns'), findsNothing);

    await _tapSwitchNearLabel(tester, 'Auto-organize memory');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    a = ap.getById(_assistantId)!;
    expect(a.autoOrganizeMemory, isTrue);
    expect(find.text('Organize every N turns'), findsOneWidget);
    expect(find.text('Dedupe mode'), findsOneWidget);
    expect(
      find.textContaining('Select a memory processing model'),
      findsOneWidget,
    );

    expect(find.text('Generate conversation summaries'), findsNothing);
    await _tapSwitchNearLabel(tester, 'Allow recalling past chats');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    a = ap.getById(_assistantId)!;
    expect(a.allowPastConversationRecall, isTrue);
    expect(find.text('Generate conversation summaries'), findsOneWidget);

    await _tapSwitchNearLabel(tester, 'Generate conversation summaries');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    a = ap.getById(_assistantId)!;
    expect(a.generateConversationSummary, isTrue);

    await _tapSwitchNearLabel(tester, 'Use long-term memory');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    a = ap.getById(_assistantId)!;
    expect(a.enableMemory, isFalse);
    expect(find.text('Auto-organize memory'), findsNothing);
    expect(find.text('Memory write scope'), findsNothing);
    expect(
      find.text('Long-term memory is off for this assistant'),
      findsOneWidget,
    );
  });

  testWidgets('memory tab has no about row or inline option subtitles', (
    tester,
  ) async {
    final (ap, chat, memoryV2, pipeline) = await _createProviders(tester);
    _setLargeSurface(tester);
    await ap.updateAssistant(
      ap
          .getById(_assistantId)!
          .copyWith(
            enableMemory: true,
            autoOrganizeMemory: true,
            allowPastConversationRecall: true,
            generateConversationSummary: true,
          ),
    );

    await tester.pumpWidget(
      _buildHarness(
        assistantProvider: ap,
        chatService: chat,
        memoryV2: memoryV2,
        pipeline: pipeline,
        child: const AssistantSettingsEditPage(assistantId: _assistantId),
      ),
    );
    await _openMemoryTab(tester);

    expect(find.text('About memory'), findsNothing);
    expect(find.text('How memory works and when it runs'), findsNothing);
    expect(
      find.text(
        'Inject saved memories into chats and let this assistant write new ones',
      ),
      findsNothing,
    );
    expect(find.text('Run the memory pipeline after chats'), findsNothing);
    expect(
      find.text('Run auto-organize after this many assistant replies'),
      findsNothing,
    );
    expect(
      find.text('How candidates are judged against existing memories'),
      findsNothing,
    );
    expect(find.text('Where new memories are stored by default'), findsNothing);
    expect(
      find.text('Enable chat search across past conversations'),
      findsNothing,
    );
    expect(find.text('Summaries are only used by chat search'), findsNothing);
    expect(find.text('Use long-term memory'), findsOneWidget);
    expect(find.text('Auto-organize memory'), findsOneWidget);
    expect(find.byType(MemoryTipIcon), findsWidgets);
  });

  testWidgets(
    'add memory from tab uses assistant scope when write scope is assistant',
    (tester) async {
      final (ap, chat, memoryV2, pipeline) = await _createProviders(tester);
      _setLargeSurface(tester);
      await ap.updateAssistant(
        ap
            .getById(_assistantId)!
            .copyWith(
              enableMemory: true,
              memoryWriteScope: MemoryWriteScope.alwaysAssistant,
            ),
      );

      await tester.pumpWidget(
        _buildHarness(
          assistantProvider: ap,
          chatService: chat,
          memoryV2: memoryV2,
          pipeline: pipeline,
          child: const AssistantSettingsEditPage(assistantId: _assistantId),
        ),
      );
      await _openMemoryTab(tester);

      final addButton = find.text('Add memory').hitTestable();
      await tester.ensureVisible(addButton);
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      final chips = tester.widgetList<MemorySelectChip>(
        find.byType(MemorySelectChip),
      );
      expect(
        chips.any((c) => c.label == 'This assistant' && c.selected),
        isTrue,
      );
      expect(chips.any((c) => c.label == 'Global' && c.selected), isFalse);
    },
  );

  testWidgets('add memory sheet opens and cancels without throwing', (
    tester,
  ) async {
    final (ap, chat, memoryV2, pipeline) = await _createProviders(tester);
    _setLargeSurface(tester);
    await ap.updateAssistant(
      ap.getById(_assistantId)!.copyWith(enableMemory: true),
    );

    await tester.pumpWidget(
      _buildHarness(
        assistantProvider: ap,
        chatService: chat,
        memoryV2: memoryV2,
        pipeline: pipeline,
        child: const AssistantSettingsEditPage(assistantId: _assistantId),
      ),
    );
    await _openMemoryTab(tester);

    final addButton = find.text('Add memory').hitTestable();
    await tester.ensureVisible(addButton);
    await tester.tap(addButton);
    await tester.pumpAndSettle();
    expect(find.byType(MemoryEntryEditForm), findsOneWidget);

    // Cancelling used to throw "TextEditingController was used after being
    // disposed" while the sheet was still animating out.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(MemoryEntryEditForm), findsNothing);
    expect(tester.takeException(), isNull);
    expect(memoryV2.entries, isEmpty);
  });

  testWidgets('memory tab exposes only the global memory settings link', (
    tester,
  ) async {
    final (ap, chat, memoryV2, pipeline) = await _createProviders(tester);
    _setLargeSurface(tester);

    await tester.pumpWidget(
      _buildHarness(
        assistantProvider: ap,
        chatService: chat,
        memoryV2: memoryV2,
        pipeline: pipeline,
        child: const AssistantSettingsEditPage(assistantId: _assistantId),
      ),
    );
    await _openMemoryTab(tester);

    expect(find.text('Legacy memories (read-only)'), findsNothing);
    expect(find.text('Memory mode, model, and prompts'), findsOneWidget);
  });

  testWidgets('write scope and dedupe sheet choices persist', (tester) async {
    final (ap, chat, memoryV2, pipeline) = await _createProviders(tester);
    _setLargeSurface(tester);
    await ap.updateAssistant(
      ap
          .getById(_assistantId)!
          .copyWith(enableMemory: true, autoOrganizeMemory: true),
    );

    await tester.pumpWidget(
      _buildHarness(
        assistantProvider: ap,
        chatService: chat,
        memoryV2: memoryV2,
        pipeline: pipeline,
        child: const AssistantSettingsEditPage(assistantId: _assistantId),
      ),
    );
    await _openMemoryTab(tester);

    final writeScopeRow = find.text('Memory write scope').hitTestable();
    await tester.ensureVisible(writeScopeRow);
    await tester.tap(writeScopeRow);
    await tester.pumpAndSettle();
    final alwaysAssistant = find.text('Always this assistant').hitTestable();
    await tester.tap(alwaysAssistant);
    await tester.pumpAndSettle();
    expect(
      ap.getById(_assistantId)!.memoryWriteScope,
      MemoryWriteScope.alwaysAssistant,
    );

    final dedupeRow = find.text('Dedupe mode').hitTestable();
    await tester.ensureVisible(dedupeRow);
    await tester.tap(dedupeRow);
    await tester.pumpAndSettle();
    final perItem = find.text('Per item').hitTestable();
    await tester.tap(perItem);
    await tester.pumpAndSettle();
    expect(
      ap.getById(_assistantId)!.memorySmartAddMode,
      MemorySmartAddMode.perItem,
    );
  });

  testWidgets('desktop write-scope and dedupe menus show per-option help', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      final (ap, chat, memoryV2, pipeline) = await _createProviders(tester);
      _setLargeSurface(tester);
      await ap.updateAssistant(
        ap
            .getById(_assistantId)!
            .copyWith(enableMemory: true, autoOrganizeMemory: true),
      );

      await tester.pumpWidget(
        _buildHarness(
          assistantProvider: ap,
          chatService: chat,
          memoryV2: memoryV2,
          pipeline: pipeline,
          child: const AssistantSettingsEditPage(assistantId: _assistantId),
        ),
      );
      await _openMemoryTab(tester);

      final writeScope = find.text('Always global').hitTestable();
      await tester.ensureVisible(writeScope);
      await tester.tap(writeScope);
      await tester.pumpAndSettle();
      expect(
        find.text('New memories are shared with every assistant'),
        findsOneWidget,
      );
      expect(
        find.text('New memories stay private to this assistant'),
        findsOneWidget,
      );

      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();

      final dedupe = find.text('Batched').hitTestable();
      await tester.ensureVisible(dedupe);
      await tester.tap(dedupe);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Judge all new candidates in one request'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Judge each candidate in its own request'),
        findsOneWidget,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('memory tab links to memory settings page', (tester) async {
    final (ap, chat, memoryV2, pipeline) = await _createProviders(tester);
    _setLargeSurface(tester);

    await tester.pumpWidget(
      _buildHarness(
        assistantProvider: ap,
        chatService: chat,
        memoryV2: memoryV2,
        pipeline: pipeline,
        child: const AssistantSettingsEditPage(assistantId: _assistantId),
      ),
    );
    await _openMemoryTab(tester);

    // Title "Memory" also appears on the tab; use the row subtitle.
    final settingsRow = find
        .text('Memory mode, model, and prompts')
        .hitTestable();
    await tester.ensureVisible(settingsRow);
    await tester.tap(settingsRow);
    await tester.pumpAndSettle();
    expect(find.byType(MemorySettingsPage), findsOneWidget);
  });

  testWidgets('legacy memory mode hides new-only rows', (tester) async {
    final (ap, chat, memoryV2, pipeline) = await _createProviders(tester);
    _setLargeSurface(tester);

    await tester.pumpWidget(
      _buildHarness(
        assistantProvider: ap,
        chatService: chat,
        memoryV2: memoryV2,
        pipeline: pipeline,
        child: const AssistantSettingsEditPage(assistantId: _assistantId),
      ),
    );
    await _openMemoryTab(tester);

    final settings = tester
        .element(find.byType(AssistantSettingsEditPage))
        .read<SettingsProvider>();
    await settings.setLegacyMemoryMode(true);
    await tester.pumpAndSettle();

    expect(find.text('Use legacy memory'), findsNothing);
    expect(find.text('Recent Chats Reference'), findsOneWidget);
    expect(find.text('Auto-organize memory'), findsNothing);
    expect(find.text('Memory write scope'), findsNothing);
    expect(find.text('Legacy memories (read-only)'), findsNothing);
    expect(find.text('Use long-term memory'), findsOneWidget);
    expect(find.text('Memory mode, model, and prompts'), findsOneWidget);
  });
}
