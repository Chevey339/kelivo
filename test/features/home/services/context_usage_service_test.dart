import 'dart:async';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/conversation_prompt_settings.dart';
import 'package:Kelivo/core/models/instruction_injection.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/models/token_usage.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/instruction_injection_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/world_book_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/utils/token_estimator.dart';
import 'package:Kelivo/features/home/services/context_assembly.dart';
import 'package:Kelivo/features/home/services/context_usage_service.dart';
import 'package:Kelivo/utils/sandbox_path_resolver.dart';

import '../../../support/business_test_harness.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  final services = <ChatService>[];
  final disposers = <void Function()>[];

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'kelivo_context_usage_test_',
    );
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    SandboxPathResolver.debugSetDirs(
      docsDir: tempDir.path,
      supportDir: tempDir.path,
    );
  });

  tearDown(() async {
    for (final dispose in disposers.reversed) {
      dispose();
    }
    disposers.clear();
    for (final service in services) {
      await service.close();
    }
    services.clear();
    await Hive.close();
    SandboxPathResolver.debugSetDirs(docsDir: null, supportDir: null);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<ChatService> createChat() async {
    final chat = ChatService();
    services.add(chat);
    await chat.init();
    return chat;
  }

  Future<({SettingsProvider settings, AssistantProvider assistants})>
  createProviders({String modelId = 'window-model'}) async {
    final harness = await createBusinessTestHarness();
    final settings = SettingsProvider(harness.preferences);
    final assistants = AssistantProvider(preferences: harness.preferences);
    await settings.loaded;
    await assistants.loaded;
    await settings.setProviderConfig(
      'TestProvider',
      ProviderConfig(
        id: 'TestProvider',
        enabled: true,
        name: 'Test',
        apiKey: 'k',
        baseUrl: 'https://example.test',
        models: const ['window-model', 'plain-model'],
        modelOverrides: const {
          'window-model': {
            'contextWindow': 1000,
            'reasoning': {'replay': 'all'},
          },
          'plain-model': {
            'reasoning': {'replay': 'none'},
          },
        },
      ),
    );
    await settings.setCurrentModel('TestProvider', modelId);
    disposers.add(settings.dispose);
    disposers.add(assistants.dispose);
    return (settings: settings, assistants: assistants);
  }

  ContextUsageService createUsage({
    required ChatService chat,
    required SettingsProvider settings,
    required AssistantProvider assistants,
    InstructionInjectionProvider? instructions,
    WorldBookProvider? worldBooks,
    ContextAssemblyPreviewFn? assemble,
  }) {
    final resolvedInstructions =
        instructions ??
        InstructionInjectionProvider(
          preferences: createBusinessTestPreferences(),
        );
    if (instructions == null) disposers.add(resolvedInstructions.dispose);
    final resolvedWorldBooks =
        worldBooks ??
        WorldBookProvider(preferences: createBusinessTestPreferences());
    if (worldBooks == null) disposers.add(resolvedWorldBooks.dispose);
    final service = ContextUsageService(
      chatService: chat,
      settings: settings,
      assistants: assistants,
      instructions: resolvedInstructions,
      worldBooks: resolvedWorldBooks,
      assemble:
          assemble ??
          ({
            required conversationId,
            required providerKey,
            required modelId,
            required assistantId,
          }) async => const ContextAssemblyPreview(
            systemText: 'sys',
            injectionsText: 'inj',
            historyText: 'hist',
            tools: [
              {
                'type': 'function',
                'function': {'name': 'date'},
              },
            ],
            images: [ContextImageRef()],
          ),
      runEstimate: <T>(T Function() computation) async => computation(),
    );
    disposers.add(service.dispose);
    return service;
  }

  void flushUntil(FakeAsync async, bool Function() ready) {
    for (var i = 0; i < 30; i++) {
      async.flushMicrotasks();
      if (ready()) return;
    }
  }

  Future<void> waitUntil(bool Function() ready, {Object? debug}) async {
    for (var i = 0; i < 40; i++) {
      if (ready()) return;
      await Future<void>.delayed(Duration.zero);
    }
    fail('condition not met: $debug');
  }

  Object requestConfiguration(
    ({SettingsProvider settings, AssistantProvider assistants}) providers, {
    String modelId = 'window-model',
    InstructionInjectionProvider? instructions,
    WorldBookProvider? worldBooks,
    Conversation? conversation,
  }) => contextUsageConfiguration(
    settings: providers.settings,
    config: providers.settings.getProviderConfig('TestProvider'),
    providerKey: 'TestProvider',
    modelId: modelId,
    assistant: providers.assistants.currentAssistant,
    instructions: instructions,
    worldBooks: worldBooks,
    conversation: conversation,
  );

  String tokenWords(int count) => List.filled(count, 'aa').join(' ');

  test(
    'late usage rejects a changed history revision, not streaming writes',
    () async {
      final chat = await createChat();
      final providers = await createProviders();
      final conversation = await chat.createDraftConversation(title: 'History');
      final first = await chat.addMessage(
        conversationId: conversation.id,
        role: 'user',
        content: 'short',
      );
      final second = (await chat.appendMessageVersion(
        messageId: first.id,
        content: tokenWords(100),
      ))!;
      final groupId = first.groupId ?? first.id;
      await chat.setSelectedVersion(conversation.id, groupId, first.version);
      final reply = await chat.addMessage(
        conversationId: conversation.id,
        role: 'assistant',
        content: '',
        isStreaming: true,
      );
      final usage = createUsage(
        chat: chat,
        settings: providers.settings,
        assistants: providers.assistants,
        assemble:
            ({
              required conversationId,
              required providerKey,
              required modelId,
              required assistantId,
            }) async {
              final selected = chat.getVersionSelections(
                conversationId,
              )[groupId];
              final history = (await chat.loadMessages(conversationId))
                  .singleWhere(
                    (message) =>
                        (message.groupId ?? message.id) == groupId &&
                        message.version == selected,
                  );
              return ContextAssemblyPreview(
                systemText: '',
                injectionsText: '',
                historyText: history.content,
                tools: [],
                images: [],
              );
            },
      );
      usage.setActiveConversation(conversation.id);
      final sentRevision = chat.contextRevision(conversation.id);
      final sentConfiguration = requestConfiguration(providers);
      Future<void> respond() => usage.recordUsage(
        conversationId: conversation.id,
        providerKey: 'TestProvider',
        modelId: 'window-model',
        assistantId: null,
        requestRevision: sentRevision,
        requestConfiguration: sentConfiguration,
        usage: const TokenUsage(promptTokens: 9, completionTokens: 1),
        assistantMessage: reply.copyWith(content: 'reply'),
      );
      await chat.updateStreamingCheckpointSilent(
        reply.copyWith(content: 'reply'),
        const [],
      );
      expect(chat.contextRevision(conversation.id), sentRevision);
      await respond();
      await usage.refresh(conversation.id, force: true);
      expect(usage.current!.state, ContextUsageState.exact);
      expect(usage.current!.usedTokens, 10);

      await chat.setSelectedVersion(conversation.id, groupId, second.version);
      expect(chat.contextRevision(conversation.id), sentRevision + 1);
      await respond();
      await usage.refresh(conversation.id, force: true);
      expect(usage.current!.state, ContextUsageState.estimated);
      expect(usage.current!.usedTokens, 100);
    },
  );

  for (final force in [false, true]) {
    test('instruction changes invalidate exact usage, force=$force', () async {
      final chat = await createChat();
      final providers = await createProviders();
      final instructions = InstructionInjectionProvider(
        preferences: createBusinessTestPreferences(),
      );
      disposers.add(instructions.dispose);
      await instructions.initialize();
      final assistantId = await providers.assistants.addAssistant(name: 'A');
      await providers.assistants.setCurrentAssistant(assistantId);
      final conversation = await chat.createDraftConversation(
        title: 'Instructions',
        assistantId: assistantId,
      );
      final instruction = InstructionInjection(
        id: 'long',
        title: 'Long',
        prompt: tokenWords(100),
      );
      await instructions.add(instruction);
      final usage = createUsage(
        chat: chat,
        settings: providers.settings,
        assistants: providers.assistants,
        instructions: instructions,
        assemble:
            ({
              required conversationId,
              required providerKey,
              required modelId,
              required assistantId,
            }) async => ContextAssemblyPreview(
              systemText: '',
              injectionsText: instructions.promptFor(assistantId),
              historyText: '',
              tools: [],
              images: [],
            ),
      );
      // Also exercise forced refresh for a background conversation, where the
      // provider listener does not proactively mark its snapshot stale.
      if (!force) usage.setActiveConversation(conversation.id);
      final sentConfiguration = requestConfiguration(
        providers,
        instructions: instructions,
        conversation: conversation,
      );
      final sentRevision = chat.contextRevision(conversation.id);
      Future<void> respond() => usage.recordUsage(
        conversationId: conversation.id,
        providerKey: 'TestProvider',
        modelId: 'window-model',
        assistantId: assistantId,
        requestRevision: sentRevision,
        requestConfiguration: sentConfiguration,
        usage: const TokenUsage(promptTokens: 9, completionTokens: 1),
        assistantMessage: ChatMessage(
          role: 'assistant',
          content: 'x',
          conversationId: conversation.id,
        ),
      );
      await respond();
      await usage.refresh(conversation.id, force: true);
      expect(usage.snapshot(conversation.id)!.state, ContextUsageState.exact);
      expect(usage.snapshot(conversation.id)!.usedTokens, 10);

      await instructions.setActiveIds(['long'], assistantId: assistantId);
      if (!force) {
        expect(usage.current!.state, ContextUsageState.stale);
      }
      await usage.refresh(conversation.id, force: force);
      expect(
        usage.snapshot(conversation.id)!.state,
        ContextUsageState.estimated,
      );
      expect(usage.snapshot(conversation.id)!.usedTokens, 100);
      await respond();
      await usage.refresh(conversation.id, force: true);
      expect(
        usage.snapshot(conversation.id)!.state,
        ContextUsageState.estimated,
      );
      expect(usage.snapshot(conversation.id)!.usedTokens, 100);

      await instructions.update(instruction.copyWith(prompt: tokenWords(200)));
      await usage.refresh(conversation.id, force: force);
      expect(usage.snapshot(conversation.id)!.usedTokens, 200);
      await instructions.setActiveIds([], assistantId: assistantId);
      await usage.refresh(conversation.id, force: force);
      expect(usage.snapshot(conversation.id)!.usedTokens, 0);
    });
  }

  test(
    'conversation instruction bindings track only their effective prompts',
    () async {
      final chat = await createChat();
      final providers = await createProviders();
      final instructions = InstructionInjectionProvider(
        preferences: createBusinessTestPreferences(),
      );
      disposers.add(instructions.dispose);
      await instructions.initialize();
      final assistantId = await providers.assistants.addAssistant(name: 'A');
      await providers.assistants.setCurrentAssistant(assistantId);
      await providers.assistants.updateAssistant(
        providers.assistants
            .getById(assistantId)!
            .copyWith(allowConversationPromptInjection: true),
      );
      var conversation = await chat.createDraftConversation(
        title: 'Bound',
        assistantId: assistantId,
      );
      await chat.updateConversationExtras(
        conversation.id,
        (extras) => {
          ...extras,
          ConversationPromptSettings.instructionIdsKey: ['bound'],
        },
      );
      conversation = chat.getConversation(conversation.id)!;
      const bound = InstructionInjection(
        id: 'bound',
        title: 'Bound',
        prompt: 'short',
      );
      await instructions.add(bound);
      await instructions.add(
        InstructionInjection(
          id: 'other',
          title: 'Other',
          prompt: tokenWords(50),
        ),
      );
      final usage = createUsage(
        chat: chat,
        settings: providers.settings,
        assistants: providers.assistants,
        instructions: instructions,
        assemble:
            ({
              required conversationId,
              required providerKey,
              required modelId,
              required assistantId,
            }) async => ContextAssemblyPreview(
              systemText: '',
              injectionsText: instructions.promptFor(
                assistantId,
                instructionIds: ['bound'],
              ),
              historyText: '',
              tools: [],
              images: [],
            ),
      );
      usage.setActiveConversation(conversation.id);
      await usage.recordUsage(
        conversationId: conversation.id,
        providerKey: 'TestProvider',
        modelId: 'window-model',
        assistantId: assistantId,
        requestRevision: chat.contextRevision(conversation.id),
        requestConfiguration: requestConfiguration(
          providers,
          instructions: instructions,
          conversation: conversation,
        ),
        usage: const TokenUsage(promptTokens: 9, completionTokens: 1),
        assistantMessage: ChatMessage(
          role: 'assistant',
          content: 'x',
          conversationId: conversation.id,
        ),
      );
      await usage.refresh(conversation.id, force: true);
      await instructions.setActiveIds(['other'], assistantId: assistantId);
      await instructions.update(
        bound.copyWith(title: 'Renamed', prompt: ' short '),
      );
      await usage.refresh(conversation.id);
      expect(usage.current!.state, ContextUsageState.exact);
      expect(usage.current!.usedTokens, 10);

      await instructions.update(bound.copyWith(prompt: tokenWords(100)));
      await usage.refresh(conversation.id);
      expect(usage.current!.state, ContextUsageState.estimated);
      expect(usage.current!.usedTokens, 100);
      await instructions.delete('bound');
      await usage.refresh(conversation.id, force: true);
      expect(usage.current!.usedTokens, 0);
    },
  );

  test(
    'late responses cannot anchor a changed assistant configuration',
    () async {
      final chat = await createChat();
      final providers = await createProviders();
      final assistantId = await providers.assistants.addAssistant(name: 'A');
      await providers.assistants.updateAssistant(
        providers.assistants
            .getById(assistantId)!
            .copyWith(systemPrompt: 'short'),
      );
      final usage = createUsage(
        chat: chat,
        settings: providers.settings,
        assistants: providers.assistants,
        assemble:
            ({
              required conversationId,
              required providerKey,
              required modelId,
              required assistantId,
            }) async => ContextAssemblyPreview(
              systemText: providers.assistants
                  .getById(assistantId!)!
                  .systemPrompt,
              injectionsText: '',
              historyText: '',
              tools: [],
              images: [],
            ),
      );
      final conversation = await chat.createDraftConversation(
        title: 'A',
        assistantId: assistantId,
      );
      usage.setActiveConversation(conversation.id);
      final sentConfiguration = requestConfiguration(providers);
      final reply = ChatMessage(
        role: 'assistant',
        content: 'x',
        conversationId: conversation.id,
      );
      Future<void> respond() => usage.recordUsage(
        requestRevision: chat.contextRevision(conversation.id),
        conversationId: conversation.id,
        providerKey: 'TestProvider',
        modelId: 'window-model',
        assistantId: assistantId,
        requestConfiguration: sentConfiguration,
        usage: const TokenUsage(promptTokens: 9, completionTokens: 1),
        assistantMessage: reply,
      );
      await respond();
      await waitUntil(() => usage.current?.calibrated == true);
      expect(usage.current!.state, ContextUsageState.exact);
      expect(usage.current!.usedTokens, 10);

      await providers.assistants.updateAssistant(
        providers.assistants
            .getById(assistantId)!
            .copyWith(systemPrompt: tokenWords(100)),
      );
      await respond();
      await waitUntil(
        () => usage.current?.state == ContextUsageState.estimated,
      );
      expect(usage.current!.usedTokens, 100);
    },
  );

  test(
    'memory templates invalidate cache and reject usage from the old template',
    () async {
      final chat = await createChat();
      final providers = await createProviders();
      final assistantId = await providers.assistants.addAssistant(
        name: 'Memory',
      );
      await providers.assistants.updateAssistant(
        providers.assistants.getById(assistantId)!.copyWith(enableMemory: true),
      );
      final settings = providers.settings;
      await settings.setMemoryPromptLang('en');
      await settings.setMemoryRulesPromptEn('short');
      final usage = createUsage(
        chat: chat,
        settings: settings,
        assistants: providers.assistants,
        assemble:
            ({
              required conversationId,
              required providerKey,
              required modelId,
              required assistantId,
            }) async => ContextAssemblyPreview(
              systemText: '',
              injectionsText: settings.memoryRulesPromptEn,
              historyText: '',
              tools: [],
              images: [],
            ),
      );
      final conversation = await chat.createDraftConversation(
        title: 'A',
        assistantId: assistantId,
      );
      usage.setActiveConversation(conversation.id);
      await usage.refresh(conversation.id);
      expect(usage.current!.usedTokens, 1);
      final sentConfiguration = requestConfiguration(providers);
      await settings.setMemoryRulesPromptEn(tokenWords(100));
      await usage.refresh(conversation.id);
      expect(usage.current!.usedTokens, 100);
      await usage.recordUsage(
        requestRevision: chat.contextRevision(conversation.id),
        conversationId: conversation.id,
        providerKey: 'TestProvider',
        modelId: 'window-model',
        assistantId: assistantId,
        requestConfiguration: sentConfiguration,
        usage: const TokenUsage(promptTokens: 9, completionTokens: 1),
        assistantMessage: ChatMessage(
          role: 'assistant',
          content: 'x',
          conversationId: conversation.id,
        ),
      );
      await waitUntil(
        () => usage.current?.state == ContextUsageState.estimated,
      );
      expect(usage.current!.usedTokens, 100);
    },
  );

  test('usage without request provenance remains an estimate', () async {
    final chat = await createChat();
    final providers = await createProviders();
    final usage = createUsage(
      chat: chat,
      settings: providers.settings,
      assistants: providers.assistants,
    );
    final conversation = await chat.createDraftConversation(title: 'A');
    await usage.recordUsage(
      requestRevision: chat.contextRevision(conversation.id),
      conversationId: conversation.id,
      providerKey: 'TestProvider',
      modelId: 'window-model',
      assistantId: null,
      usage: const TokenUsage(promptTokens: 9, completionTokens: 1),
      assistantMessage: ChatMessage(
        role: 'assistant',
        content: 'x',
        conversationId: conversation.id,
      ),
    );
    await waitUntil(
      () =>
          usage.snapshot(conversation.id)?.state == ContextUsageState.estimated,
    );
  });

  test('same model window edits and removal invalidate cached usage', () async {
    final chat = await createChat();
    final providers = await createProviders();
    final usage = createUsage(
      chat: chat,
      settings: providers.settings,
      assistants: providers.assistants,
    );
    final conversation = await chat.createDraftConversation(title: 'A');
    usage.setActiveConversation(conversation.id);
    await usage.refresh(conversation.id);
    expect(usage.current!.contextWindow, 1000);
    for (final window in [2000, null]) {
      final cfg = providers.settings.getProviderConfig('TestProvider');
      await providers.settings.setProviderConfig(
        'TestProvider',
        cfg.copyWith(
          modelOverrides: {
            'window-model': {'contextWindow': window},
          },
        ),
      );
      expect(usage.current!.state, ContextUsageState.stale);
      await usage.refresh(conversation.id);
      expect(usage.current!.contextWindow, window);
      expect(usage.current!.state, ContextUsageState.estimated);
    }
  });

  test(
    'editing the same assistant drops exact anchors and rebuilds its prompt',
    () async {
      final chat = await createChat();
      final providers = await createProviders();
      final id = await providers.assistants.addAssistant(name: 'A');
      await providers.assistants.updateAssistant(
        providers.assistants.getById(id)!.copyWith(systemPrompt: 'short'),
      );
      final usage = createUsage(
        chat: chat,
        settings: providers.settings,
        assistants: providers.assistants,
        assemble:
            ({
              required conversationId,
              required providerKey,
              required modelId,
              required assistantId,
            }) async => ContextAssemblyPreview(
              systemText: providers.assistants
                  .getById(assistantId!)!
                  .systemPrompt,
              injectionsText: '',
              historyText: '',
              tools: [],
              images: [],
            ),
      );
      final conversation = await chat.createDraftConversation(
        title: 'A',
        assistantId: id,
      );
      usage.setActiveConversation(conversation.id);
      await usage.recordUsage(
        requestRevision: chat.contextRevision(conversation.id),
        requestConfiguration: requestConfiguration(
          providers,
          modelId: 'window-model',
        ),
        conversationId: conversation.id,
        providerKey: 'TestProvider',
        modelId: 'window-model',
        assistantId: id,
        usage: const TokenUsage(promptTokens: 90, completionTokens: 10),
        assistantMessage: ChatMessage(
          role: 'assistant',
          content: 'reply',
          conversationId: conversation.id,
        ),
      );
      await waitUntil(() => usage.current?.calibrated == true);
      final prompt = tokenWords(40);
      await providers.assistants.updateAssistant(
        providers.assistants
            .getById(id)!
            .copyWith(
              systemPrompt: prompt,
              contextMessageSize: 2,
              limitContextMessages: true,
            ),
      );
      expect(usage.current!.state, ContextUsageState.stale);
      await usage.refresh(conversation.id);
      expect(usage.current!.state, ContextUsageState.estimated);
      expect(usage.current!.usedTokens, estimateTokens(prompt));
    },
  );

  test(
    'a settings edit rejects an in-flight estimate with the same model id',
    () async {
      final chat = await createChat();
      final providers = await createProviders();
      final pending = Completer<ContextAssemblyPreview>();
      final assembling = Completer<void>();
      var calls = 0;
      final usage = createUsage(
        chat: chat,
        settings: providers.settings,
        assistants: providers.assistants,
        assemble:
            ({
              required conversationId,
              required providerKey,
              required modelId,
              required assistantId,
            }) async {
              calls++;
              if (calls == 1) {
                assembling.complete();
                return pending.future;
              }
              return const ContextAssemblyPreview(
                systemText: 'new',
                injectionsText: '',
                historyText: '',
                tools: [],
                images: [],
              );
            },
      );
      final conversation = await chat.createDraftConversation(title: 'A');
      usage.setActiveConversation(conversation.id);
      final first = usage.refresh(conversation.id);
      await assembling.future;
      final cfg = providers.settings.getProviderConfig('TestProvider');
      await providers.settings.setProviderConfig(
        'TestProvider',
        cfg.copyWith(
          modelOverrides: const {
            'window-model': {'contextWindow': 2000},
          },
        ),
      );
      pending.complete(
        const ContextAssemblyPreview(
          systemText: 'old',
          injectionsText: '',
          historyText: '',
          tools: [],
          images: [],
        ),
      );
      await first;
      expect(usage.current!.state, ContextUsageState.stale);
      await usage.refresh(conversation.id);
      expect(usage.current!.contextWindow, 2000);
      expect(usage.current!.usedTokens, estimateTokens('new'));
    },
  );

  test('calibrateContextUsageBuckets scales and pushes residual', () {
    const estimated = ContextUsageBuckets(
      system: 10,
      injections: 10,
      history: 10,
      tools: 10,
      attachments: 11,
      draft: 5,
    );
    final calibrated = calibrateContextUsageBuckets(
      estimated: estimated,
      anchorTotal: 100,
    )!;
    expect(calibrated.nonDraftTotal, 100);
    expect(calibrated.draft, 5);
    expect(calibrated.system, 20);
    expect(calibrated.injections, 20);
    expect(calibrated.history, 20);
    expect(calibrated.tools, 20);
    expect(calibrated.attachments, 20);
    expect(
      calibrateContextUsageBuckets(
        estimated: const ContextUsageBuckets(draft: 3),
        anchorTotal: 50,
      ),
      isNull,
    );
  });

  test('recordUsage anchors prompt plus replayed assistant turn', () async {
    final chat = await createChat();
    final providers = await createProviders();
    final usage = createUsage(
      chat: chat,
      settings: providers.settings,
      assistants: providers.assistants,
    );
    final conversation = await chat.createConversation(title: 'A');
    const content = 'visible reply';
    const reasoning = 'hidden thoughts';
    final message = ChatMessage(
      role: 'assistant',
      content: content,
      conversationId: conversation.id,
      reasoningText: reasoning,
    );

    await usage.recordUsage(
      requestRevision: chat.contextRevision(conversation.id),
      requestConfiguration: requestConfiguration(
        providers,
        modelId: 'window-model',
      ),
      conversationId: conversation.id,
      providerKey: 'TestProvider',
      modelId: 'window-model',
      assistantId: null,
      usage: const TokenUsage(promptTokens: 100),
      assistantMessage: message,
    );

    final snap = usage.snapshot(conversation.id)!;
    final expected = 100 + estimateTokens(content) + estimateTokens(reasoning);
    expect(snap.state, ContextUsageState.exact);
    expect(snap.usedTokens, expected);
    expect(snap.contextWindow, 1000);
    expect(snap.ratio, expected / 1000);
    expect(snap.revision, 0);
  });

  test('recordUsage skips reasoning when replay is none', () async {
    final chat = await createChat();
    final providers = await createProviders(modelId: 'plain-model');
    final usage = createUsage(
      chat: chat,
      settings: providers.settings,
      assistants: providers.assistants,
    );
    final conversation = await chat.createConversation(title: 'A');
    const content = 'visible reply';
    final message = ChatMessage(
      role: 'assistant',
      content: content,
      conversationId: conversation.id,
      reasoningText: 'hidden thoughts',
    );

    await usage.recordUsage(
      requestRevision: chat.contextRevision(conversation.id),
      requestConfiguration: requestConfiguration(
        providers,
        modelId: 'plain-model',
      ),
      conversationId: conversation.id,
      providerKey: 'TestProvider',
      modelId: 'plain-model',
      assistantId: null,
      usage: const TokenUsage(promptTokens: 40),
      assistantMessage: message,
    );

    expect(
      usage.snapshot(conversation.id)!.usedTokens,
      40 + estimateTokens(content),
    );
  });

  test(
    'recordUsage includes reasoning on toolTurns only when tools ran',
    () async {
      final chat = await createChat();
      final harness = await createBusinessTestHarness();
      final settings = SettingsProvider(harness.preferences);
      final assistants = AssistantProvider(preferences: harness.preferences);
      await settings.loaded;
      await assistants.loaded;
      await settings.setProviderConfig(
        'TestProvider',
        ProviderConfig(
          id: 'TestProvider',
          enabled: true,
          name: 'Test',
          apiKey: 'k',
          baseUrl: 'https://example.test',
          models: const ['tool-model'],
          modelOverrides: const {
            'tool-model': {
              'contextWindow': 2000,
              'reasoning': {'replay': 'toolTurns'},
            },
          },
        ),
      );
      await settings.setCurrentModel('TestProvider', 'tool-model');
      disposers.add(settings.dispose);
      disposers.add(assistants.dispose);
      final usage = createUsage(
        chat: chat,
        settings: settings,
        assistants: assistants,
      );
      final conversation = await chat.createConversation(title: 'A');
      const content = 'done';
      const reasoning = 'plan';
      const toolJson = '{"name":"search"}';

      await usage.recordUsage(
        requestRevision: chat.contextRevision(conversation.id),
        requestConfiguration: requestConfiguration((
          settings: settings,
          assistants: assistants,
        ), modelId: 'tool-model'),
        conversationId: conversation.id,
        providerKey: 'TestProvider',
        modelId: 'tool-model',
        assistantId: null,
        usage: const TokenUsage(promptTokens: 10),
        assistantMessage: ChatMessage(
          role: 'assistant',
          content: content,
          conversationId: conversation.id,
          reasoningText: reasoning,
        ),
      );
      expect(
        usage.snapshot(conversation.id)!.usedTokens,
        10 + estimateTokens(content),
      );

      await usage.recordUsage(
        requestRevision: chat.contextRevision(conversation.id),
        requestConfiguration: requestConfiguration((
          settings: settings,
          assistants: assistants,
        ), modelId: 'tool-model'),
        conversationId: conversation.id,
        providerKey: 'TestProvider',
        modelId: 'tool-model',
        assistantId: null,
        usage: const TokenUsage(promptTokens: 10),
        assistantMessage: ChatMessage(
          role: 'assistant',
          conversationId: conversation.id,
          reasoningText: reasoning,
          parts: [const TextPart(content), ToolCallPart(toolJson)],
        ),
      );
      expect(
        usage.snapshot(conversation.id)!.usedTokens,
        10 + estimateTokens(content) + estimateTokens(reasoning),
      );
    },
  );

  test(
    'recordUsage uses prompt plus completion and ignores tool payloads',
    () async {
      final chat = await createChat();
      final providers = await createProviders();
      final usage = createUsage(
        chat: chat,
        settings: providers.settings,
        assistants: providers.assistants,
      );
      final conversation = await chat.createConversation(title: 'A');
      const hugeTool = '{"name":"search","result":"xxxxxxxxxxxxxxxxxxxxxxxx"}';

      await usage.recordUsage(
        requestRevision: chat.contextRevision(conversation.id),
        requestConfiguration: requestConfiguration(
          providers,
          modelId: 'window-model',
        ),
        conversationId: conversation.id,
        providerKey: 'TestProvider',
        modelId: 'window-model',
        assistantId: null,
        usage: const TokenUsage(promptTokens: 40991, completionTokens: 655),
        assistantMessage: ChatMessage(
          role: 'assistant',
          conversationId: conversation.id,
          reasoningText: 'thoughts that must not be estimated on top',
          parts: const [TextPart('ok'), ToolCallPart(hugeTool)],
        ),
      );

      final snap = usage.snapshot(conversation.id)!;
      expect(snap.state, ContextUsageState.exact);
      expect(snap.usedTokens, 41646);
      expect(snap.calibrated, isFalse);

      await waitUntil(
        () => usage.snapshot(conversation.id)?.calibrated == true,
        debug: usage.snapshot(conversation.id),
      );
      final calibrated = usage.snapshot(conversation.id)!;
      expect(calibrated.state, ContextUsageState.exact);
      expect(calibrated.usedTokens, 41646);
      expect(calibrated.buckets.nonDraftTotal, 41646);
      expect(calibrated.buckets.draft, 0);

      await usage.refresh(conversation.id, draftText: 'typed later');
      final folded = usage.snapshot(conversation.id)!;
      expect(folded.state, ContextUsageState.exact);
      expect(folded.calibrated, isTrue);
      expect(folded.buckets.draft, estimateTokens('typed later'));
      expect(folded.usedTokens, 41646 + folded.buckets.draft);
    },
  );

  test('recordUsage subtracts reasoning when replay is none', () async {
    final chat = await createChat();
    final providers = await createProviders(modelId: 'plain-model');
    final usage = createUsage(
      chat: chat,
      settings: providers.settings,
      assistants: providers.assistants,
    );
    final conversation = await chat.createConversation(title: 'A');

    await usage.recordUsage(
      requestRevision: chat.contextRevision(conversation.id),
      requestConfiguration: requestConfiguration(
        providers,
        modelId: 'plain-model',
      ),
      conversationId: conversation.id,
      providerKey: 'TestProvider',
      modelId: 'plain-model',
      assistantId: null,
      usage: const TokenUsage(
        promptTokens: 100,
        completionTokens: 50,
        reasoningTokens: 20,
      ),
      assistantMessage: ChatMessage(
        role: 'assistant',
        content: 'visible reply',
        conversationId: conversation.id,
        reasoningText: 'hidden thoughts',
      ),
    );

    expect(usage.snapshot(conversation.id)!.usedTokens, 130);
  });

  test(
    'recordUsage keeps reasoning on toolTurns only when tools ran',
    () async {
      final chat = await createChat();
      final harness = await createBusinessTestHarness();
      final settings = SettingsProvider(harness.preferences);
      final assistants = AssistantProvider(preferences: harness.preferences);
      await settings.loaded;
      await assistants.loaded;
      await settings.setProviderConfig(
        'TestProvider',
        ProviderConfig(
          id: 'TestProvider',
          enabled: true,
          name: 'Test',
          apiKey: 'k',
          baseUrl: 'https://example.test',
          models: const ['tool-model'],
          modelOverrides: const {
            'tool-model': {
              'contextWindow': 2000,
              'reasoning': {'replay': 'toolTurns'},
            },
          },
        ),
      );
      await settings.setCurrentModel('TestProvider', 'tool-model');
      disposers.add(settings.dispose);
      disposers.add(assistants.dispose);
      final usage = createUsage(
        chat: chat,
        settings: settings,
        assistants: assistants,
      );
      final conversation = await chat.createConversation(title: 'A');

      await usage.recordUsage(
        requestRevision: chat.contextRevision(conversation.id),
        requestConfiguration: requestConfiguration((
          settings: settings,
          assistants: assistants,
        ), modelId: 'tool-model'),
        conversationId: conversation.id,
        providerKey: 'TestProvider',
        modelId: 'tool-model',
        assistantId: null,
        usage: const TokenUsage(
          promptTokens: 80,
          completionTokens: 40,
          reasoningTokens: 15,
        ),
        assistantMessage: ChatMessage(
          role: 'assistant',
          content: 'done',
          conversationId: conversation.id,
          reasoningText: 'plan',
        ),
      );
      expect(usage.snapshot(conversation.id)!.usedTokens, 105);

      await usage.recordUsage(
        requestRevision: chat.contextRevision(conversation.id),
        requestConfiguration: requestConfiguration((
          settings: settings,
          assistants: assistants,
        ), modelId: 'tool-model'),
        conversationId: conversation.id,
        providerKey: 'TestProvider',
        modelId: 'tool-model',
        assistantId: null,
        usage: const TokenUsage(
          promptTokens: 80,
          completionTokens: 40,
          reasoningTokens: 15,
        ),
        assistantMessage: ChatMessage(
          role: 'assistant',
          conversationId: conversation.id,
          reasoningText: 'plan',
          parts: const [TextPart('done'), ToolCallPart('{"name":"search"}')],
        ),
      );
      expect(usage.snapshot(conversation.id)!.usedTokens, 120);
    },
  );

  test('recordUsage calibrates buckets to the exact anchor', () async {
    final chat = await createChat();
    final providers = await createProviders();
    final systemText = tokenWords(10);
    final injectionsText = tokenWords(20);
    final historyText = tokenWords(70);
    final usage = createUsage(
      chat: chat,
      settings: providers.settings,
      assistants: providers.assistants,
      assemble:
          ({
            required conversationId,
            required providerKey,
            required modelId,
            required assistantId,
          }) async => ContextAssemblyPreview(
            systemText: systemText,
            injectionsText: injectionsText,
            historyText: historyText,
            tools: const [],
            images: const [],
          ),
    );
    final conversation = await chat.createConversation(title: 'A');
    const anchor = 41646;

    await usage.recordUsage(
      requestRevision: chat.contextRevision(conversation.id),
      requestConfiguration: requestConfiguration(
        providers,
        modelId: 'window-model',
      ),
      conversationId: conversation.id,
      providerKey: 'TestProvider',
      modelId: 'window-model',
      assistantId: null,
      usage: const TokenUsage(promptTokens: 40991, completionTokens: 655),
      assistantMessage: ChatMessage(
        role: 'assistant',
        content: 'ok',
        conversationId: conversation.id,
      ),
    );

    await waitUntil(
      () => usage.snapshot(conversation.id)?.calibrated == true,
      debug: usage.snapshot(conversation.id),
    );
    final snap = usage.snapshot(conversation.id)!;
    expect(snap.state, ContextUsageState.exact);
    expect(snap.calibrated, isTrue);
    expect(snap.buckets.nonDraftTotal, anchor);
    expect(snap.usedTokens, anchor);
    expect(snap.buckets.system, 4165);
    expect(snap.buckets.injections, 8329);
    expect(snap.buckets.history, 29152);
    expect(snap.buckets.tools, 0);
    expect(snap.buckets.attachments, 0);
    expect(snap.buckets.system / anchor, closeTo(0.1, 1e-4));
    expect(snap.buckets.injections / anchor, closeTo(0.2, 1e-4));
    expect(snap.buckets.history / anchor, closeTo(0.7, 1e-4));
  });

  test('recordUsage stays exact until estimate lands', () async {
    final chat = await createChat();
    final providers = await createProviders();
    final preview = Completer<ContextAssemblyPreview>();
    final usage = createUsage(
      chat: chat,
      settings: providers.settings,
      assistants: providers.assistants,
      assemble:
          ({
            required conversationId,
            required providerKey,
            required modelId,
            required assistantId,
          }) => preview.future,
    );
    final conversation = await chat.createConversation(title: 'A');

    await usage.recordUsage(
      requestRevision: chat.contextRevision(conversation.id),
      requestConfiguration: requestConfiguration(
        providers,
        modelId: 'window-model',
      ),
      conversationId: conversation.id,
      providerKey: 'TestProvider',
      modelId: 'window-model',
      assistantId: null,
      usage: const TokenUsage(promptTokens: 40991, completionTokens: 655),
      assistantMessage: ChatMessage(
        role: 'assistant',
        content: 'ok',
        conversationId: conversation.id,
      ),
    );

    final pending = usage.snapshot(conversation.id)!;
    expect(pending.state, ContextUsageState.exact);
    expect(pending.calibrated, isFalse);
    expect(pending.usedTokens, 41646);

    preview.complete(
      ContextAssemblyPreview(
        systemText: tokenWords(10),
        injectionsText: tokenWords(20),
        historyText: tokenWords(70),
        tools: const [],
        images: const [],
      ),
    );
    await waitUntil(
      () => usage.snapshot(conversation.id)?.calibrated == true,
      debug: usage.snapshot(conversation.id),
    );
    expect(usage.snapshot(conversation.id)!.state, ContextUsageState.exact);
    expect(usage.snapshot(conversation.id)!.usedTokens, 41646);
  });

  test('revision bump after recordUsage drops back to estimated', () async {
    final chat = await createChat();
    final providers = await createProviders();
    var assembleCalls = 0;
    final usage = createUsage(
      chat: chat,
      settings: providers.settings,
      assistants: providers.assistants,
      assemble:
          ({
            required conversationId,
            required providerKey,
            required modelId,
            required assistantId,
          }) async {
            assembleCalls++;
            return ContextAssemblyPreview(
              systemText: tokenWords(10),
              injectionsText: tokenWords(20),
              historyText: tokenWords(70),
              tools: const [],
              images: const [],
            );
          },
    );
    final conversation = await chat.createDraftConversation(title: 'A');
    usage.setActiveConversation(conversation.id);
    await usage.recordUsage(
      requestRevision: chat.contextRevision(conversation.id),
      requestConfiguration: requestConfiguration(
        providers,
        modelId: 'window-model',
      ),
      conversationId: conversation.id,
      providerKey: 'TestProvider',
      modelId: 'window-model',
      assistantId: null,
      usage: const TokenUsage(promptTokens: 40991, completionTokens: 655),
      assistantMessage: ChatMessage(
        role: 'assistant',
        content: 'ok',
        conversationId: conversation.id,
      ),
    );
    await waitUntil(
      () => usage.snapshot(conversation.id)?.calibrated == true,
      debug: usage.snapshot(conversation.id),
    );
    expect(usage.snapshot(conversation.id)!.state, ContextUsageState.exact);
    expect(assembleCalls, 1);

    fakeAsync((async) {
      chat.updateConversationExtras(conversation.id, (extras) {
        extras['k'] = 1;
        return extras;
      });
      async.flushMicrotasks();
      expect(usage.snapshot(conversation.id)!.state, ContextUsageState.stale);
      async.elapse(const Duration(milliseconds: 800));
      flushUntil(
        async,
        () =>
            usage.snapshot(conversation.id)?.state ==
            ContextUsageState.estimated,
      );
      final snap = usage.snapshot(conversation.id)!;
      expect(snap.state, ContextUsageState.estimated);
      expect(snap.calibrated, isFalse);
      expect(snap.usedTokens, snap.buckets.total);
      expect(snap.buckets.nonDraftTotal, isNot(41646));
      expect(assembleCalls, 2);
    });
  });

  test('recordUsage does not anchor when promptTokens is 0', () async {
    final chat = await createChat();
    final providers = await createProviders();
    final usage = createUsage(
      chat: chat,
      settings: providers.settings,
      assistants: providers.assistants,
    );
    final conversation = await chat.createConversation(title: 'A');

    await usage.recordUsage(
      requestRevision: chat.contextRevision(conversation.id),
      requestConfiguration: requestConfiguration(
        providers,
        modelId: 'window-model',
      ),
      conversationId: conversation.id,
      providerKey: 'TestProvider',
      modelId: 'window-model',
      assistantId: null,
      usage: const TokenUsage(completionTokens: 4),
      assistantMessage: ChatMessage(
        role: 'assistant',
        content: 'x',
        conversationId: conversation.id,
      ),
    );

    expect(usage.snapshot(conversation.id), isNull);
  });

  test('refresh estimates buckets and short-circuits when fresh', () async {
    final chat = await createChat();
    final providers = await createProviders();
    var assembleCalls = 0;
    final usage = createUsage(
      chat: chat,
      settings: providers.settings,
      assistants: providers.assistants,
      assemble:
          ({
            required conversationId,
            required providerKey,
            required modelId,
            required assistantId,
          }) async {
            assembleCalls++;
            return const ContextAssemblyPreview(
              systemText: 'sys',
              injectionsText: 'inj',
              historyText: 'hist',
              tools: [
                {
                  'type': 'function',
                  'function': {'name': 'date'},
                },
              ],
              images: [ContextImageRef()],
            );
          },
    );
    final conversation = await chat.createConversation(title: 'A');
    usage.setActiveConversation(conversation.id);
    await usage.refresh(conversation.id);

    final snap = usage.snapshot(conversation.id)!;
    expect(snap.state, ContextUsageState.estimated);
    expect(snap.buckets.system, estimateTokens('sys'));
    expect(snap.buckets.injections, estimateTokens('inj'));
    expect(snap.buckets.history, estimateTokens('hist'));
    expect(
      snap.buckets.tools,
      estimateToolsTokens([
        {
          'type': 'function',
          'function': {'name': 'date'},
        },
      ]),
    );
    expect(snap.buckets.attachments, 1000);
    expect(snap.buckets.draft, 0);
    expect(snap.usedTokens, snap.buckets.total);
    expect(snap.contextWindow, 1000);
    expect(assembleCalls, 1);

    await usage.refresh(conversation.id, draftText: 'typed later');
    final folded = usage.snapshot(conversation.id)!;
    expect(assembleCalls, 1);
    expect(folded.state, ContextUsageState.estimated);
    expect(folded.buckets.draft, estimateTokens('typed later'));
    expect(
      folded.usedTokens,
      snap.buckets.total - snap.buckets.draft + folded.buckets.draft,
    );
  });

  test('revision change marks stale then debounced estimated', () async {
    final chat = await createChat();
    final providers = await createProviders();
    var assembleCalls = 0;
    final usage = createUsage(
      chat: chat,
      settings: providers.settings,
      assistants: providers.assistants,
      assemble:
          ({
            required conversationId,
            required providerKey,
            required modelId,
            required assistantId,
          }) async {
            assembleCalls++;
            return const ContextAssemblyPreview(
              systemText: 'sys',
              injectionsText: '',
              historyText: 'hist',
              tools: [],
              images: [],
            );
          },
    );
    final conversation = await chat.createDraftConversation(title: 'A');
    usage.setActiveConversation(conversation.id);
    await usage.refresh(conversation.id);
    expect(usage.snapshot(conversation.id)!.state, ContextUsageState.estimated);
    expect(assembleCalls, 1);

    fakeAsync((async) {
      chat.updateConversationExtras(conversation.id, (extras) {
        extras['k'] = 1;
        return extras;
      });
      async.flushMicrotasks();
      expect(usage.snapshot(conversation.id)!.state, ContextUsageState.stale);
      async.elapse(const Duration(milliseconds: 800));
      flushUntil(
        async,
        () =>
            usage.snapshot(conversation.id)?.state ==
            ContextUsageState.estimated,
      );
      expect(
        usage.snapshot(conversation.id)!.state,
        ContextUsageState.estimated,
      );
      expect(usage.snapshot(conversation.id)!.revision, 1);
      expect(assembleCalls, 2);
    });
  });

  test('background conversation never auto-refreshes', () async {
    final chat = await createChat();
    final providers = await createProviders();
    final assembleCalls = <String, int>{};
    final usage = createUsage(
      chat: chat,
      settings: providers.settings,
      assistants: providers.assistants,
      assemble:
          ({
            required conversationId,
            required providerKey,
            required modelId,
            required assistantId,
          }) async {
            assembleCalls[conversationId] =
                (assembleCalls[conversationId] ?? 0) + 1;
            return const ContextAssemblyPreview(
              systemText: 'sys',
              injectionsText: '',
              historyText: 'hist',
              tools: [],
              images: [],
            );
          },
    );
    final active = await chat.createDraftConversation(title: 'Active');
    final background = await chat.createDraftConversation(title: 'Bg');
    usage.setActiveConversation(background.id);
    await usage.refresh(background.id);
    usage.setActiveConversation(active.id);
    await usage.refresh(active.id);
    expect(assembleCalls[background.id], 1);
    expect(assembleCalls[active.id], 1);
    final bgRevision = chat.contextRevision(background.id);

    fakeAsync((async) {
      chat.updateConversationExtras(background.id, (extras) {
        extras['k'] = 1;
        return extras;
      });
      async.flushMicrotasks();
      expect(chat.contextRevision(background.id), bgRevision + 1);
      expect(usage.snapshot(background.id)!.state, ContextUsageState.estimated);
      async.elapse(const Duration(milliseconds: 800));
      async.flushMicrotasks();
      expect(assembleCalls[background.id], 1);
      expect(usage.snapshot(background.id)!.revision, bgRevision);
    });
  });

  test('model switch marks the active snapshot stale', () async {
    final chat = await createChat();
    final providers = await createProviders();
    final usage = createUsage(
      chat: chat,
      settings: providers.settings,
      assistants: providers.assistants,
    );
    final conversation = await chat.createConversation(title: 'A');
    usage.setActiveConversation(conversation.id);
    await usage.refresh(conversation.id);
    expect(usage.snapshot(conversation.id)!.state, ContextUsageState.estimated);

    await providers.settings.setCurrentModel('TestProvider', 'plain-model');
    expect(usage.snapshot(conversation.id)!.state, ContextUsageState.stale);
  });

  test('ratio is null when the spec has no context window', () async {
    final chat = await createChat();
    final providers = await createProviders(modelId: 'plain-model');
    final usage = createUsage(
      chat: chat,
      settings: providers.settings,
      assistants: providers.assistants,
    );
    final conversation = await chat.createConversation(title: 'A');
    usage.setActiveConversation(conversation.id);
    await usage.refresh(conversation.id);

    final snap = usage.snapshot(conversation.id)!;
    expect(snap.state, ContextUsageState.estimated);
    expect(snap.contextWindow, isNull);
    expect(snap.ratio, isNull);
  });
}
