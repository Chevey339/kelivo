import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../support/business_test_harness.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/chat/title_generation_service.dart';

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
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory directory;
  late PathProviderPlatform previousPathProvider;
  late ChatDatabaseRepository repository;
  late ChatService chatService;
  late HttpServer server;
  late SettingsProvider settings;
  late AssistantProvider assistantProvider;
  late TitleGenerationService service;
  var generateTextRequestCount = 0;
  String? generateTextModel;
  var replyContent = 'Dark mode chat';

  Future<void> handleApiRequest(HttpRequest request) async {
    final body =
        jsonDecode(await utf8.decoder.bind(request).join())
            as Map<String, dynamic>;
    if (body['stream'] != true) {
      generateTextRequestCount++;
      generateTextModel = body['model'] as String?;
    }
    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode({
        'choices': [
          {
            'message': {'content': replyContent},
          },
        ],
      }),
    );
    await request.response.close();
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('kelivo_title_');
    previousPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProviderPlatform(directory.path);
    HttpOverrides.global = null;
    repository = ChatDatabaseRepository.open(
      file: File('${directory.path}/kelivo.db'),
    );
    await repository.ensureReady();
    chatService = ChatService(existingRepository: repository);
    await chatService.init();
    generateTextRequestCount = 0;
    generateTextModel = null;
    replyContent = 'Dark mode chat';
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen(handleApiRequest);

    final baseUrl = 'http://${server.address.address}:${server.port}/v1';
    final settingsPrefs = createBusinessTestPreferences();
    await settingsPrefs.load();
    settings = SettingsProvider(settingsPrefs);
    await settings.loaded;
    await settings.setProviderConfig(
      'SiliconFlow',
      ProviderConfig(
        id: 'SiliconFlow',
        enabled: true,
        name: 'SiliconFlow',
        apiKey: 'title-test-key',
        baseUrl: baseUrl,
        providerType: ProviderKind.openai,
      ),
    );
    await settings.setCurrentModel('SiliconFlow', 'test-model');

    final assistantPrefs = createBusinessTestPreferences();
    await assistantPrefs.load();
    assistantProvider = AssistantProvider(preferences: assistantPrefs);
    await assistantProvider.loaded;
    final assistantId = await assistantProvider.addAssistant(
      name: 'Title Assistant',
    );
    await assistantProvider.setCurrentAssistant(assistantId);

    service = TitleGenerationService(
      chatService: chatService,
      settings: settings,
      assistants: assistantProvider,
    );
  });

  tearDown(() async {
    PathProviderPlatform.instance = previousPathProvider;
    try {
      await server.close(force: true);
    } catch (_) {}
    try {
      await chatService.close().timeout(const Duration(seconds: 10));
    } catch (_) {}
    try {
      await repository.close().timeout(const Duration(seconds: 10));
    } catch (_) {}
    try {
      if (await directory.exists()) await directory.delete(recursive: true);
    } catch (_) {}
  });

  Future<void> seedTwoTurnConversation(String conversationId) async {
    await chatService.addMessage(
      conversationId: conversationId,
      role: 'user',
      content: 'Remember that I prefer dark mode.',
    );
    await chatService.addMessage(
      conversationId: conversationId,
      role: 'assistant',
      content: 'Got it.',
    );
  }

  test('skips generation and makes no model call when disabled', () async {
    await settings.disableTitleGeneration();
    final convo = await chatService.createConversation(
      title: 'New Chat',
      assistantId: assistantProvider.currentAssistantId,
    );
    await seedTwoTurnConversation(convo.id);

    final title = await service.generate(
      convo.id,
      locale: 'en',
      defaultTitle: 'New Chat',
    );

    expect(title, isNull);
    expect(generateTextRequestCount, 0);
    expect(chatService.getConversation(convo.id)!.title, 'New Chat');
  });

  test('skips an already titled conversation unless forced', () async {
    final convo = await chatService.createConversation(
      title: 'Custom Title',
      assistantId: assistantProvider.currentAssistantId,
    );
    await seedTwoTurnConversation(convo.id);

    final skipped = await service.generate(
      convo.id,
      locale: 'en',
      defaultTitle: 'New Chat',
    );
    expect(skipped, isNull);
    expect(generateTextRequestCount, 0);

    final regenerated = await service.generate(
      convo.id,
      locale: 'en',
      force: true,
    );
    expect(regenerated, 'Dark mode chat');
    expect(generateTextRequestCount, 1);
    expect(chatService.getConversation(convo.id)!.title, 'Dark mode chat');
  });

  test('generates a title when a title model is configured', () async {
    await settings.setTitleModel('SiliconFlow', 'test-model');
    final convo = await chatService.createConversation(
      title: 'New Chat',
      assistantId: assistantProvider.currentAssistantId,
    );
    await seedTwoTurnConversation(convo.id);

    final title = await service.generate(
      convo.id,
      locale: 'en',
      defaultTitle: 'New Chat',
    );

    expect(title, 'Dark mode chat');
    expect(generateTextRequestCount, 1);
    expect(generateTextModel, 'test-model');
    expect(chatService.getConversation(convo.id)!.title, 'Dark mode chat');
  });

  test('follow-current title generation uses the conversation model', () async {
    await settings.setPerChatModelEnabled(true);
    final convo = await chatService.createConversation(
      title: 'New Chat',
      assistantId: assistantProvider.currentAssistantId,
    );
    await chatService.setConversationModel(
      convo.id,
      providerKey: 'SiliconFlow',
      modelId: 'conversation-model',
    );
    await seedTwoTurnConversation(convo.id);

    final title = await service.generate(
      convo.id,
      locale: 'en',
      defaultTitle: 'New Chat',
    );

    expect(title, 'Dark mode chat');
    expect(generateTextRequestCount, 1);
    expect(generateTextModel, 'conversation-model');
  });

  test('returns null for an unknown conversation', () async {
    final title = await service.generate(
      'missing-conversation',
      locale: 'en',
      defaultTitle: 'New Chat',
    );
    expect(title, isNull);
    expect(generateTextRequestCount, 0);
  });

  test('throws empty_response when the model returns nothing', () async {
    replyContent = '';
    final convo = await chatService.createConversation(
      title: 'New Chat',
      assistantId: assistantProvider.currentAssistantId,
    );
    await seedTwoTurnConversation(convo.id);

    await expectLater(
      service.generate(convo.id, locale: 'en', defaultTitle: 'New Chat'),
      throwsA(
        isA<TitleGenerationException>().having(
          (e) => e.toString(),
          'toString',
          'empty_response',
        ),
      ),
    );
    expect(chatService.getConversation(convo.id)!.title, 'New Chat');
  });

  test('strips thinking tags from the generated title', () async {
    replyContent = '<think>chain of thought</think>Dark mode chat';
    final convo = await chatService.createConversation(
      title: 'New Chat',
      assistantId: assistantProvider.currentAssistantId,
    );
    await seedTwoTurnConversation(convo.id);

    final title = await service.generate(
      convo.id,
      locale: 'en',
      defaultTitle: 'New Chat',
    );

    expect(title, 'Dark mode chat');
    expect(chatService.getConversation(convo.id)!.title, 'Dark mode chat');
  });

  test('discards a truncated think block instead of a raw CoT title', () async {
    replyContent = '<think>truncated reasoning';
    final convo = await chatService.createConversation(
      title: 'New Chat',
      assistantId: assistantProvider.currentAssistantId,
    );
    await seedTwoTurnConversation(convo.id);

    await expectLater(
      service.generate(convo.id, locale: 'en', defaultTitle: 'New Chat'),
      throwsA(isA<TitleGenerationException>()),
    );
    expect(chatService.getConversation(convo.id)!.title, 'New Chat');
  });
}
