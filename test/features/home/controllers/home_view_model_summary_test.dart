import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';

import '../../../support/business_test_harness.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/mcp_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/mcp/mcp_tool_service.dart';
import 'package:Kelivo/features/home/controllers/home_page_controller.dart';
import 'package:Kelivo/features/home/controllers/scroll_controller.dart';
import 'package:Kelivo/features/home/widgets/chat_input_bar.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

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
  var generateTextRequestCount = 0;

  Future<void> handleApiRequest(HttpRequest request) async {
    final body =
        jsonDecode(await utf8.decoder.bind(request).join())
            as Map<String, dynamic>;
    if (body['stream'] != true) {
      generateTextRequestCount++;
    }
    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode({
        'choices': [
          {
            'message': {'content': 'User prefers dark mode.'},
          },
        ],
      }),
    );
    await request.response.close();
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('kelivo_summary_');
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
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen(handleApiRequest);
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
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  Future<HomePageController> pumpHarness(WidgetTester tester) async {
    HomePageController? controller;
    final baseUrl = 'http://${server.address.address}:${server.port}/v1';
    await tester.runAsync(() async {
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
          apiKey: 'summary-test-key',
          baseUrl: baseUrl,
          providerType: ProviderKind.openai,
        ),
      );
      await settings.setCurrentModel('SiliconFlow', 'test-model');
      await settings.setSummaryModel('SiliconFlow', 'test-model');

      final assistantPrefs = createBusinessTestPreferences();
      await assistantPrefs.load();
      assistantProvider = AssistantProvider(preferences: assistantPrefs);
      await assistantProvider.loaded;
      final assistantId = await assistantProvider.addAssistant(
        name: 'Summary Assistant',
      );
      await assistantProvider.setCurrentAssistant(assistantId);
      final assistant = assistantProvider.currentAssistant!;
      await assistantProvider.updateAssistant(
        assistant.copyWith(
          allowPastConversationRecall: true,
          generateConversationSummary: true,
          recentChatsSummaryMessageCount: 1,
        ),
      );
    });
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<ChatService>.value(value: chatService),
          ChangeNotifierProvider<AssistantProvider>.value(
            value: assistantProvider,
          ),
          ChangeNotifierProvider<McpProvider>(
            create: (_) =>
                McpProvider(preferences: createBusinessTestPreferences()),
          ),
          ChangeNotifierProvider<McpToolService>(
            create: (_) => McpToolService(),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _ControllerHarness(onCreated: (value) => controller = value),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    return controller!;
  }

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
    expect(
      chatService.getMessageCount(conversationId),
      greaterThanOrEqualTo(1),
    );
  }

  testWidgets(
    'temporary conversation skips summary generation and makes no model call',
    (tester) async {
      final controller = await pumpHarness(tester);
      await tester.runAsync(() async {
        final temp = await chatService.createDraftConversation(
          title: 'Temporary Chat',
          assistantId: assistantProvider.currentAssistantId,
          temporary: true,
        );
        expect(chatService.isTemporaryConversation(temp.id), isTrue);
        await seedTwoTurnConversation(temp.id);

        await controller.debugViewModel.debugMaybeGenerateSummaryFor(temp.id);

        expect(
          generateTextRequestCount,
          0,
          reason: 'temporary chats must not spend an LLM call on a summary',
        );
        final after = chatService.getConversation(temp.id)!;
        expect(after.summary, anyOf(isNull, isEmpty));
        expect(after.lastSummarizedMessageCount, 0);
      });
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('ordinary conversation still generates a summary via the model', (
    tester,
  ) async {
    final controller = await pumpHarness(tester);
    await tester.runAsync(() async {
      final convo = await chatService.createConversation(
        title: 'Ordinary Chat',
        assistantId: assistantProvider.currentAssistantId,
      );
      await seedTwoTurnConversation(convo.id);

      await controller.debugViewModel.debugMaybeGenerateSummaryFor(convo.id);

      expect(generateTextRequestCount, 1);
      final after = chatService.getConversation(convo.id)!;
      expect(after.summary, 'User prefers dark mode.');
      expect(after.lastSummarizedMessageCount, greaterThan(0));
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'legacy mode generates summary when only allowPastConversationRecall is on',
    (tester) async {
      final controller = await pumpHarness(tester);
      await tester.runAsync(() async {
        await settings.setLegacyMemoryMode(true);
        await assistantProvider.updateAssistant(
          assistantProvider.currentAssistant!.copyWith(
            allowPastConversationRecall: true,
            generateConversationSummary: false,
            recentChatsSummaryMessageCount: 1,
          ),
        );
        final convo = await chatService.createConversation(
          title: 'Ordinary Chat',
          assistantId: assistantProvider.currentAssistantId,
        );
        await seedTwoTurnConversation(convo.id);

        await controller.debugViewModel.debugMaybeGenerateSummaryFor(convo.id);

        expect(generateTextRequestCount, 1);
        final after = chatService.getConversation(convo.id)!;
        expect(after.summary, 'User prefers dark mode.');
        expect(after.lastSummarizedMessageCount, greaterThan(0));
      });
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('clear-context label counts logical messages, not revisions', (
    tester,
  ) async {
    final controller = await pumpHarness(tester);
    await tester.runAsync(() async {
      await assistantProvider.updateAssistant(
        assistantProvider.currentAssistant!.copyWith(
          limitContextMessages: true,
          contextMessageSize: 10,
        ),
      );
      final conversation = await chatService.createConversation(
        title: 'Versioned Chat',
        assistantId: assistantProvider.currentAssistantId,
      );
      await chatService.addMessage(
        conversationId: conversation.id,
        role: 'user',
        content: 'Question',
      );
      final answer = await chatService.addMessage(
        conversationId: conversation.id,
        role: 'assistant',
        content: 'Answer v1',
      );
      await chatService.appendMessageVersion(
        messageId: answer.id,
        content: 'Answer v2',
      );
      await chatService.appendMessageVersion(
        messageId: answer.id,
        content: 'Answer v3',
      );
      await controller.chatController.setCurrentConversationAndLoad(
        chatService.getConversation(conversation.id)!,
      );

      expect(controller.debugViewModel.getContextMessageCount(), (
        actual: 2,
        configured: 10,
      ));

      await controller.debugViewModel.clearContext();

      expect(controller.debugViewModel.getContextMessageCount(), (
        actual: 0,
        configured: 10,
      ));
    });
    expect(tester.takeException(), isNull);
  });
}

class _ControllerHarness extends StatefulWidget {
  const _ControllerHarness({required this.onCreated});

  final ValueChanged<HomePageController> onCreated;

  @override
  State<_ControllerHarness> createState() => _ControllerHarnessState();
}

class _ControllerHarnessState extends State<_ControllerHarness>
    with TickerProviderStateMixin {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _inputBarKey = GlobalKey();
  final _inputFocus = FocusNode();
  final _inputController = TextEditingController();
  final _mediaController = ChatInputBarController();
  final _scrollController = ChatAutoFollowScrollController();
  late final HomePageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = HomePageController(
      context: context,
      vsync: this,
      scaffoldKey: _scaffoldKey,
      inputBarKey: _inputBarKey,
      inputFocus: _inputFocus,
      inputController: _inputController,
      mediaController: _mediaController,
      scrollController: _scrollController,
    );
    widget.onCreated(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    _inputFocus.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(key: _scaffoldKey);
}
