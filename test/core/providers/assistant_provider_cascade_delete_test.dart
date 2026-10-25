import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/search/services/global_session_search_service.dart';

import '../../support/business_preferences_test_harness.dart';

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

Future<AssistantProvider> _createLoadedAssistantProvider({
  required BusinessPreferencesTestSession session,
  required ChatService chatService,
  List<Map<String, Object?>> assistants = const [
    {'id': 'assistant-delete', 'name': 'Delete Me'},
    {'id': 'assistant-keep', 'name': 'Keep Me'},
  ],
  String currentAssistantId = 'assistant-delete',
}) async {
  await session.preferences.setString('assistants_v1', jsonEncode(assistants));
  await session.preferences.setString(
    'current_assistant_id_v1',
    currentAssistantId,
  );

  final provider = AssistantProvider(
    preferences: session.preferences,
    chatService: chatService,
  );
  for (var i = 0; i < 25; i++) {
    if (provider.assistants.length == assistants.length) return provider;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  return provider;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late BusinessPreferencesTestHarness harness;
  late BusinessPreferencesTestSession session;
  final services = <ChatService>[];

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'kelivo_assistant_cascade_test_',
    );
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    harness = await BusinessPreferencesTestHarness.create();
    session = await harness.open();
  });

  tearDown(() async {
    for (final service in services) {
      await service.close();
    }
    services.clear();
    await Hive.close();
    await harness.dispose();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  ChatService createService() {
    final service = ChatService();
    services.add(service);
    return service;
  }

  test(
    'retiring KelivoIN clears assistant and conversation model overrides',
    () async {
      SharedPreferences.setMockInitialValues({'flutter_log_enabled_v1': false});
      final chatService = createService();
      await chatService.init();
      final assistants = await _createLoadedAssistantProvider(
        session: session,
        chatService: chatService,
        assistants: const [
          {
            'id': 'assistant-delete',
            'name': 'Retired model',
            'chatModelProvider': 'KelivoIN',
            'chatModelId': 'mistral',
          },
          {
            'id': 'assistant-keep',
            'name': 'Keep model',
            'chatModelProvider': 'OpenAI',
            'chatModelId': 'gpt-4o',
          },
        ],
      );
      final retiredChat = await chatService.createConversation(
        title: 'Retired',
      );
      await chatService.setConversationModel(
        retiredChat.id,
        providerKey: 'KelivoIN',
        modelId: 'qwen-coder',
      );
      final keptChat = await chatService.createConversation(title: 'Keep');
      await chatService.setConversationModel(
        keptChat.id,
        providerKey: 'OpenAI',
        modelId: 'gpt-4o',
      );
      final retired = ProviderConfig.defaultsFor('KelivoIN').copyWith(
        baseUrl: 'https://text.pollinations.ai/openai',
        apiKey: 'kelivo',
        models: ['mistral', 'qwen-coder'],
      );
      await session.preferences.setString(
        'provider_configs_v1',
        jsonEncode({'KelivoIN': retired.toJson()}),
      );
      final settings = SettingsProvider(
        session.preferences,
        onProviderModelsRetired: assistants.clearModelSelectionsForProvider,
      );
      await settings.loaded;

      expect(assistants.assistants[0].chatModelProvider, isNull);
      expect(assistants.assistants[0].chatModelId, isNull);
      expect(assistants.assistants[1].chatModelId, 'gpt-4o');
      expect(chatService.getConversation(retiredChat.id)!.chatModelId, isNull);
      expect(chatService.getConversation(keptChat.id)!.chatModelId, 'gpt-4o');
      expect(settings.getProviderConfig('KelivoIN').models, contains('auto'));

      final reloadedSession = await harness.open();
      final reloadedAssistants = AssistantProvider(
        preferences: reloadedSession.preferences,
      );
      await reloadedAssistants.loaded;
      expect(reloadedAssistants.assistants[0].chatModelProvider, isNull);
      expect(reloadedAssistants.assistants[0].chatModelId, isNull);
      expect(reloadedAssistants.assistants[1].chatModelId, 'gpt-4o');
      final reloadedChat = createService();
      await reloadedChat.init();
      expect(reloadedChat.getConversation(retiredChat.id)!.chatModelId, isNull);
      expect(reloadedChat.getConversation(keptChat.id)!.chatModelId, 'gpt-4o');
    },
  );

  group('AssistantProvider cascade delete', () {
    test(
      'deletes conversations and messages owned by the deleted assistant',
      () async {
        final chatService = createService();
        await chatService.init();
        final provider = await _createLoadedAssistantProvider(
          session: session,
          chatService: chatService,
        );

        final deletedConversation = await chatService.createConversation(
          title: 'Deleted assistant chat',
          assistantId: 'assistant-delete',
        );
        await chatService.addMessage(
          conversationId: deletedConversation.id,
          role: 'user',
          content: 'unique-test-keyword-123',
        );

        final keptConversation = await chatService.createConversation(
          title: 'Kept assistant chat',
          assistantId: 'assistant-keep',
        );
        await chatService.addMessage(
          conversationId: keptConversation.id,
          role: 'user',
          content: 'keep-assistant-keyword-456',
        );

        expect(
          await GlobalSessionSearchService.search(
            chatService: chatService,
            query: 'unique-test-keyword-123',
          ),
          hasLength(1),
        );

        expect(await provider.deleteAssistant('assistant-delete'), isTrue);

        expect(chatService.getConversation(deletedConversation.id), isNull);
        expect(chatService.getMessages(deletedConversation.id), isEmpty);
        expect(
          await GlobalSessionSearchService.search(
            chatService: chatService,
            query: 'unique-test-keyword-123',
          ),
          isEmpty,
        );
        expect(
          await GlobalSessionSearchService.search(
            chatService: chatService,
            query: 'keep-assistant-keyword-456',
          ),
          hasLength(1),
        );
      },
    );

    test(
      'deletes draft conversations owned by the deleted assistant',
      () async {
        final chatService = createService();
        await chatService.init();
        final provider = await _createLoadedAssistantProvider(
          session: session,
          chatService: chatService,
        );

        final draft = await chatService.createDraftConversation(
          title: 'Draft assistant chat',
          assistantId: 'assistant-delete',
        );
        final keptDraft = await chatService.createDraftConversation(
          title: 'Kept draft chat',
          assistantId: 'assistant-keep',
        );

        expect(chatService.getConversation(draft.id), isNotNull);

        expect(await provider.deleteAssistant('assistant-delete'), isTrue);

        expect(chatService.getConversation(draft.id), isNull);
        expect(chatService.getConversation(keptDraft.id), isNotNull);
      },
    );

    test(
      'notifies once when deleting multiple assistant conversations',
      () async {
        final chatService = createService();
        await chatService.init();

        final first = await chatService.createConversation(
          title: 'First deleted chat',
          assistantId: 'assistant-delete',
        );
        await chatService.addMessage(
          conversationId: first.id,
          role: 'user',
          content: 'first-delete-keyword',
        );
        final second = await chatService.createConversation(
          title: 'Second deleted chat',
          assistantId: 'assistant-delete',
        );
        await chatService.addMessage(
          conversationId: second.id,
          role: 'user',
          content: 'second-delete-keyword',
        );
        final kept = await chatService.createConversation(
          title: 'Kept chat',
          assistantId: 'assistant-keep',
        );

        var notifications = 0;
        chatService.addListener(() {
          notifications++;
        });

        await chatService.deleteConversationsForAssistant('assistant-delete');

        expect(notifications, 1);
        expect(chatService.getConversation(first.id), isNull);
        expect(chatService.getConversation(second.id), isNull);
        expect(chatService.getConversation(kept.id), isNotNull);
      },
    );

    test(
      'keeps conversations when deleting the last assistant is rejected',
      () async {
        final chatService = createService();
        await chatService.init();
        final provider = await _createLoadedAssistantProvider(
          session: session,
          chatService: chatService,
          assistants: const [
            {'id': 'only-assistant', 'name': 'Only Assistant'},
          ],
          currentAssistantId: 'only-assistant',
        );

        final conversation = await chatService.createConversation(
          title: 'Only assistant chat',
          assistantId: 'only-assistant',
        );
        await chatService.addMessage(
          conversationId: conversation.id,
          role: 'user',
          content: 'last-assistant-keyword-789',
        );

        expect(await provider.deleteAssistant('only-assistant'), isFalse);

        expect(chatService.getConversation(conversation.id), isNotNull);
        expect(
          await GlobalSessionSearchService.search(
            chatService: chatService,
            query: 'last-assistant-keyword-789',
          ),
          hasLength(1),
        );
      },
    );
  });
}
