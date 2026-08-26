import 'dart:async';
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
import 'package:Kelivo/core/models/chat_input_data.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/mcp_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/mcp/mcp_tool_service.dart';
import 'package:Kelivo/features/chat/widgets/chat_message_widget.dart'
    show ToolUIPart;
import 'package:Kelivo/features/home/controllers/home_page_controller.dart';
import 'package:Kelivo/features/home/controllers/scroll_controller.dart';
import 'package:Kelivo/features/home/services/ask_user_interaction_service.dart';
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
  late ChatService service;
  late HttpServer server;
  late SettingsProvider settings;
  late AssistantProvider assistantProvider;
  var streamRequestCount = 0;
  Completer<void>? streamHold;

  Future<void> handleApiRequest(HttpRequest request) async {
    final body =
        jsonDecode(await utf8.decoder.bind(request).join())
            as Map<String, dynamic>;
    if (body['stream'] == true) {
      streamRequestCount++;
      final hold = streamHold;
      if (hold != null) await hold.future;
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType(
        'text',
        'event-stream',
        charset: 'utf-8',
      );
      request.response.write(
        'data: ${jsonEncode({
          'id': 'cmpl-race',
          'object': 'chat.completion.chunk',
          'created': 0,
          'model': 'test-model',
          'choices': [
            {
              'index': 0,
              'delta': {'role': 'assistant', 'content': 'ok'},
              'finish_reason': 'stop',
            },
          ],
        })}\n\n',
      );
      request.response.write('data: [DONE]\n\n');
      await request.response.close();
      return;
    }
    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode({
        'choices': [
          {
            'message': {'content': '- suggestion one\n- suggestion two'},
          },
        ],
      }),
    );
    await request.response.close();
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('kelivo_send_race_');
    previousPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProviderPlatform(directory.path);
    // The widget-test binding replaces HttpClient with a 400-only mock; the
    // loopback API server below needs real networking.
    HttpOverrides.global = null;
    repository = ChatDatabaseRepository.open(
      file: File('${directory.path}/kelivo.db'),
    );
    await repository.ensureReady();
    service = ChatService(existingRepository: repository);
    await service.init();
    streamRequestCount = 0;
    streamHold = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen(handleApiRequest);
  });

  tearDown(() async {
    PathProviderPlatform.instance = previousPathProvider;
    try {
      await server.close(force: true);
    } catch (_) {}
    try {
      await service.close().timeout(const Duration(seconds: 10));
    } catch (_) {}
    try {
      await repository.close().timeout(const Duration(seconds: 10));
    } catch (_) {}
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  Future<HomePageController> pumpHarness(
    WidgetTester tester, {
    bool withSuggestions = false,
  }) async {
    HomePageController? controller;
    final baseUrl = 'http://${server.address.address}:${server.port}/v1';
    // Futures only complete for awaits on the zone that created them, and the
    // send path runs inside runAsync: build and fully configure every provider
    // there so its loaded/write futures belong to the real-async zone.
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
          apiKey: 'race-test-key',
          baseUrl: baseUrl,
          providerType: ProviderKind.openai,
        ),
      );
      await settings.setCurrentModel('SiliconFlow', 'test-model');
      if (withSuggestions) {
        await settings.setSuggestionModel('SiliconFlow', 'test-model');
      }

      final assistantPrefs = createBusinessTestPreferences();
      await assistantPrefs.load();
      assistantProvider = AssistantProvider(preferences: assistantPrefs);
      await assistantProvider.loaded;
      final assistantId = await assistantProvider.addAssistant(
        name: 'Test Assistant',
      );
      await assistantProvider.setCurrentAssistant(assistantId);
    });
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<ChatService>.value(value: service),
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

  Future<Conversation> openConversation(HomePageController controller) async {
    final convo = await service.createConversation(title: 'Race test');
    await controller.chatController.setCurrentConversationAndLoad(convo);
    return convo;
  }

  Future<void> waitFor(bool Function() condition, String description) async {
    for (var i = 0; i < 200; i++) {
      if (condition()) return;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    fail('timed out waiting for $description');
  }

  testWidgets('concurrent sends persist a single user/assistant pair', (
    tester,
  ) async {
    final controller = await pumpHarness(tester);
    await tester.runAsync(() async {
      final convo = await openConversation(controller);
      final first = controller.sendMessage(ChatInputData(text: 'hello')).then((
        r,
      ) {
        return r;
      });
      final second = controller.sendMessage(ChatInputData(text: 'hello')).then((
        r,
      ) {
        return r;
      });
      await Future.wait([first, second]);
      // sendMessage resolves once the pair is persisted; the streamed reply
      // keeps running in the background, so wait for it to finish.
      await waitFor(() => streamRequestCount == 1, 'stream request to fire');
      await waitFor(
        () => !controller.chatController.isConversationLoading(convo.id),
        'streaming to finish',
      );

      final messages = await service.loadMessages(convo.id);
      expect(messages.where((m) => m.role == 'user'), hasLength(1));
      expect(messages.where((m) => m.role == 'assistant'), hasLength(1));
      expect(
        messages.where((m) => m.role == 'assistant').single.isStreaming,
        isFalse,
      );
      expect(streamRequestCount, 1);
      expect(
        controller.chatController.isConversationLoading(convo.id),
        isFalse,
      );
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('single-flight cancel hides loading before slow teardown', (
    tester,
  ) async {
    final controller = await pumpHarness(tester);
    await tester.runAsync(() async {
      final convo = await openConversation(controller);
      controller.chatController.setConversationLoading(convo.id, true);
      final releaseCancel = Completer<void>();
      var cancelCalls = 0;
      final source = StreamController<void>(
        onCancel: () async {
          cancelCalls++;
          await releaseCancel.future;
          throw StateError('cancel failed');
        },
      );
      controller.chatController.setStreamSubscription(
        convo.id,
        source.stream.listen((_) {}),
      );

      final firstCancel = controller.cancelStreaming();
      await Future<void>.delayed(Duration.zero);

      expect(controller.isCurrentConversationLoading, isFalse);
      expect(controller.chatController.isConversationLoading(convo.id), isTrue);
      expect(controller.loadingConversationIds, isNot(contains(convo.id)));

      final recoveredMessage = ChatMessage(
        id: 'stopping-assistant',
        role: 'assistant',
        content: '',
        conversationId: convo.id,
      );
      const recoveredPart = ToolUIPart(
        id: 'ask-user',
        toolName: AskUserToolNames.askUser,
        arguments: <String, dynamic>{},
        loading: true,
      );
      await controller.submitRecoveredAskUserAnswer(
        recoveredMessage,
        recoveredPart,
        const AskUserResult.answer(<String, AskUserAnswerValue>{}),
      );
      expect(service.getToolEvents(recoveredMessage.id), isEmpty);
      expect(controller.toolParts[recoveredMessage.id], isNull);

      var secondCompleted = false;
      final secondCancel = controller.cancelStreaming().whenComplete(
        () => secondCompleted = true,
      );
      await Future<void>.delayed(Duration.zero);
      expect(cancelCalls, 1);
      expect(secondCompleted, isFalse);

      releaseCancel.complete();
      await Future.wait([firstCancel, secondCancel]);

      expect(
        controller.chatController.isConversationLoading(convo.id),
        isFalse,
      );
      await source.close();
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('double suggestion tap persists a single user/assistant pair', (
    tester,
  ) async {
    final controller = await pumpHarness(tester);
    await tester.runAsync(() async {
      final convo = await openConversation(controller);
      final first = controller.sendSuggestion('hello');
      final second = controller.sendSuggestion('hello');
      await Future.wait([first, second]);
      await waitFor(() => streamRequestCount == 1, 'stream request to fire');
      await waitFor(
        () => !controller.chatController.isConversationLoading(convo.id),
        'streaming to finish',
      );

      final messages = await service.loadMessages(convo.id);
      expect(messages.where((m) => m.role == 'user'), hasLength(1));
      expect(messages.where((m) => m.role == 'assistant'), hasLength(1));
      expect(streamRequestCount, 1);
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('double regenerate tap creates a single new version', (
    tester,
  ) async {
    final controller = await pumpHarness(tester);
    await tester.runAsync(() async {
      final convo = await openConversation(controller);
      await controller.sendMessage(ChatInputData(text: 'hello'));
      await waitFor(() => streamRequestCount == 1, 'stream request to fire');
      await waitFor(
        () => !controller.chatController.isConversationLoading(convo.id),
        'initial streaming to finish',
      );
      final before = await service.loadMessages(convo.id);
      expect(before, hasLength(2));
      final assistantMessage = before.firstWhere((m) => m.role == 'assistant');

      final first = controller.regenerateAtMessage(assistantMessage);
      final second = controller.regenerateAtMessage(assistantMessage);
      await Future.wait([first, second]);
      await waitFor(() => streamRequestCount == 2, 'second stream to fire');
      await waitFor(
        () => !controller.chatController.isConversationLoading(convo.id),
        'regeneration streaming to finish',
      );

      final messages = await service.loadMessages(convo.id);
      // user + original assistant revision + exactly one regenerated revision
      expect(messages, hasLength(3));
      expect(
        messages.where((m) => m.role == 'assistant' && m.version == 1),
        hasLength(1),
      );
      expect(streamRequestCount, 2);
      expect(
        controller.chatController.isConversationLoading(convo.id),
        isFalse,
      );
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('assistant edit save and send creates a new reply slot', (
    tester,
  ) async {
    final controller = await pumpHarness(tester);
    await tester.runAsync(() async {
      final convo = await openConversation(controller);
      await controller.sendMessage(ChatInputData(text: 'hello'));
      await waitFor(
        () => !controller.chatController.isConversationLoading(convo.id),
        'initial streaming to finish',
      );
      final before = await service.loadMessages(convo.id);
      final original = before.firstWhere((m) => m.role == 'assistant');
      final edited = await service.appendMessageVersion(
        messageId: original.id,
        content: 'edited answer',
      );
      expect(edited, isNotNull);

      await controller.regenerateAtMessage(edited!, assistantAsNewReply: true);

      await waitFor(() => streamRequestCount == 2, 'second stream to fire');
      await waitFor(
        () => !controller.chatController.isConversationLoading(convo.id),
        'new reply streaming to finish',
      );
      final messages = await service.loadMessages(convo.id);
      final editedGroupId = original.groupId ?? original.id;
      final newReplies = messages.where(
        (message) =>
            message.role == 'assistant' &&
            (message.groupId ?? message.id) != editedGroupId,
      );
      expect(
        messages.where((message) => message.role == 'assistant'),
        hasLength(3),
      );
      expect(newReplies, hasLength(1));
      expect(
        newReplies.single.groupId ?? newReplies.single.id,
        newReplies.single.id,
      );
      expect(newReplies.single.version, 0);
      expect(newReplies.single.isStreaming, isFalse);
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('temporary user edit saves and sends the in-memory version', (
    tester,
  ) async {
    final controller = await pumpHarness(tester);
    await tester.runAsync(() async {
      final convo = await service.createDraftConversation(
        title: 'Temporary Chat',
        temporary: true,
      );
      controller.chatController.setDraftConversation(convo);
      await controller.sendMessage(ChatInputData(text: 'original question'));
      await waitFor(
        () => !controller.chatController.isConversationLoading(convo.id),
        'initial temporary streaming to finish',
      );
      final original = service
          .getMessages(convo.id)
          .firstWhere((message) => message.role == 'user');

      await controller.startUserMessageEdit(original);
      final result = await controller.sendMessage(
        ChatInputData(text: 'edited question'),
      );

      expect(result, ChatInputSubmissionResult.sent);
      await waitFor(() => streamRequestCount == 2, 'edited stream to fire');
      await waitFor(
        () => !controller.chatController.isConversationLoading(convo.id),
        'edited temporary streaming to finish',
      );
      final edited = service
          .getMessages(convo.id)
          .firstWhere(
            (message) =>
                message.role == 'user' &&
                (message.groupId ?? message.id) ==
                    (original.groupId ?? original.id) &&
                message.version == 1,
          );
      expect(edited.content, 'edited question');
      expect(
        service.getVersionSelections(convo.id),
        containsPair(original.groupId ?? original.id, 1),
      );
      expect(service.isTemporaryConversation(convo.id), isTrue);
      expect(service.getAllConversations(), isEmpty);
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('multi-version conversation still saves generated suggestions', (
    tester,
  ) async {
    final controller = await pumpHarness(tester, withSuggestions: true);
    await tester.runAsync(() async {
      final convo = await openConversation(controller);
      await controller.sendMessage(ChatInputData(text: 'hello'));
      await waitFor(
        () => !controller.chatController.isConversationLoading(convo.id),
        'initial streaming to finish',
      );
      final before = await service.loadMessages(convo.id);
      final assistantMessage = before.firstWhere((m) => m.role == 'assistant');

      // Make the conversation multi-version, then wait for the automatic
      // suggestion generation that follows the regenerated reply.
      await controller.regenerateAtMessage(assistantMessage);
      await waitFor(
        () => !controller.chatController.isConversationLoading(convo.id),
        'regeneration streaming to finish',
      );
      expect(await service.loadMessages(convo.id), hasLength(3));

      await waitFor(
        () =>
            service.getConversation(convo.id)?.chatSuggestions.isNotEmpty ??
            false,
        'suggestions to be saved',
      );
      expect(
        service.getConversation(convo.id)!.chatSuggestions,
        contains('suggestion one'),
      );
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a second conversation can send while the first is still streaming',
    (tester) async {
      final controller = await pumpHarness(tester);
      await tester.runAsync(() async {
        streamHold = Completer<void>();
        final first = await openConversation(controller);
        await controller.sendMessage(ChatInputData(text: 'from a'));
        await waitFor(
          () => controller.chatController.isConversationLoading(first.id),
          'first conversation to start streaming',
        );

        final second = await service.createConversation(title: 'Second');
        await controller.chatController.setCurrentConversationAndLoad(second);
        final result = await controller.sendMessage(
          ChatInputData(text: 'from b'),
        );

        expect(result, ChatInputSubmissionResult.sent);
        expect(
          controller.chatController.isConversationLoading(first.id),
          isTrue,
        );
        expect(
          controller.chatController.isConversationLoading(second.id),
          isTrue,
        );

        streamHold!.complete();
        await waitFor(
          () =>
              !controller.chatController.isConversationLoading(first.id) &&
              !controller.chatController.isConversationLoading(second.id),
          'both streams to finish',
        );

        final firstMessages = await service.loadMessages(first.id);
        final secondMessages = await service.loadMessages(second.id);
        expect(
          firstMessages.where((m) => m.role == 'user').single.content,
          'from a',
        );
        expect(
          secondMessages.where((m) => m.role == 'user').single.content,
          'from b',
        );
      });
      expect(tester.takeException(), isNull);
    },
  );
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
