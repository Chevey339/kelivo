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
import '../../../support/gated_xfile.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/chat_input_data.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/composer_draft.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/models/preset_message.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/mcp_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/api/providers/openai/responses_history.dart';
import 'package:Kelivo/core/services/api/providers/claude/claude_history.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk_emit.dart';
import 'package:Kelivo/core/services/mcp/mcp_tool_service.dart';
import 'package:Kelivo/features/chat/widgets/chat_message_widget.dart'
    show ToolUIPart;
import 'package:Kelivo/features/home/controllers/home_page_controller.dart';
import 'package:Kelivo/features/home/controllers/chat_actions.dart';
import 'package:Kelivo/features/home/controllers/scroll_controller.dart';
import 'package:Kelivo/features/home/services/ask_user_interaction_service.dart';
import 'package:Kelivo/features/home/widgets/chat_input_bar.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';

class _GatedChatService extends ChatService {
  _GatedChatService({required super.existingRepository});
  Completer<void>? versionSaveHold;
  bool versionSaveEntered = false;
  bool holdAfterVersionSave = false;
  Completer<void>? regenerationHold;
  bool regenerationEntered = false;
  bool failAfterVersionSave = false;
  Completer<void>? presetHold;
  String? presetConversationId;
  Completer<void>? checkpointHold;
  final checkpointEntered = Completer<void>();

  @override
  Future<void> updateStreamingCheckpointSilent(
    ChatMessage message,
    List<Map<String, dynamic>> toolEvents, {
    String? generationRunId,
    int? checkpointSeq,
  }) async {
    if (checkpointHold != null &&
        toolEvents.any(
          (event) =>
              event['arguments'] is Map &&
              (event['arguments'] as Map).isNotEmpty,
        )) {
      if (!checkpointEntered.isCompleted) checkpointEntered.complete();
      await checkpointHold!.future;
    }
    await super.updateStreamingCheckpointSilent(
      message,
      toolEvents,
      generationRunId: generationRunId,
      checkpointSeq: checkpointSeq,
    );
  }

  @override
  Future<ChatMessage> addMessage({
    required String conversationId,
    required String role,
    String content = '',
    List<MessagePart>? parts,
    String? modelId,
    String? providerId,
    int? totalTokens,
    bool isStreaming = false,
    String? reasoningText,
    DateTime? reasoningStartAt,
    DateTime? reasoningFinishedAt,
    String? groupId,
    int? version,
    bool selectVersion = false,
    String? temporaryAfterGroupId,
  }) async {
    if (content == 'preset question' && presetHold != null) {
      presetConversationId = conversationId;
      await presetHold!.future;
    }
    return super.addMessage(
      conversationId: conversationId,
      role: role,
      content: content,
      parts: parts,
      modelId: modelId,
      providerId: providerId,
      totalTokens: totalTokens,
      isStreaming: isStreaming,
      reasoningText: reasoningText,
      reasoningStartAt: reasoningStartAt,
      reasoningFinishedAt: reasoningFinishedAt,
      groupId: groupId,
      version: version,
      selectVersion: selectVersion,
      temporaryAfterGroupId: temporaryAfterGroupId,
    );
  }

  @override
  Future<GenerationBeginResult> beginAssistantGeneration({
    required String conversationId,
    required String modelId,
    required String providerId,
    required String anchorGroupId,
    required bool truncateFuture,
  }) async {
    regenerationEntered = true;
    await regenerationHold?.future;
    return super.beginAssistantGeneration(
      conversationId: conversationId,
      modelId: modelId,
      providerId: providerId,
      anchorGroupId: anchorGroupId,
      truncateFuture: truncateFuture,
    );
  }

  @override
  Future<ChatMessage?> appendMessageVersion({
    required String messageId,
    String content = '',
    List<MessagePart>? parts,
    DraftSubmission? draftSubmission,
  }) async {
    if (!holdAfterVersionSave) {
      versionSaveEntered = true;
      await versionSaveHold?.future;
    }
    final message = await super.appendMessageVersion(
      messageId: messageId,
      content: content,
      parts: parts,
      draftSubmission: draftSubmission,
    );
    if (holdAfterVersionSave) {
      versionSaveEntered = true;
      await versionSaveHold?.future;
    }
    if (failAfterVersionSave) throw StateError('post-commit callback failed');
    return message;
  }
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory directory;
  late PathProviderPlatform previousPathProvider;
  late ChatDatabaseRepository repository;
  late _GatedChatService service;
  late HttpServer server;
  late SettingsProvider settings;
  late AssistantProvider assistantProvider;
  var streamRequestCount = 0;
  final streamRequests = <Map<String, dynamic>>[];
  Completer<void>? streamHold;
  Completer<void>? suggestionHold;
  final suggestionRequests = <Map<String, dynamic>>[];
  var suggestionResponse =
      '{"suggestions":["suggestion one","suggestion two"]}';
  var suggestionResponsesSent = 0;
  late AskUserInteractionService questions;
  Future<void> Function(HttpRequest, Map<String, dynamic>)? apiOverride;

  Future<void> handleApiRequest(HttpRequest request) async {
    final body =
        jsonDecode(await utf8.decoder.bind(request).join())
            as Map<String, dynamic>;
    if (apiOverride != null) return apiOverride!(request, body);
    if (body['model'] == 'gpt-4o' &&
        body['stream'] != true &&
        !(body['messages'] as List).any((m) => m['role'] == 'tool')) {
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'choices': [
            {
              'message': {
                'role': 'assistant',
                'content': null,
                'tool_calls': [
                  {
                    'id': 'scheduled-ask',
                    'type': 'function',
                    'function': {
                      'name': AskUserToolNames.askUser,
                      'arguments': jsonEncode({
                        'questions': [
                          {'id': 'q1', 'question': 'Which option?'},
                        ],
                      }),
                    },
                  },
                ],
              },
              'finish_reason': 'tool_calls',
            },
          ],
        }),
      );
      await request.response.close();
      return;
    }
    if (body['stream'] == true) {
      streamRequestCount++;
      streamRequests.add(body);
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
    final isSuggestion = (body['messages'] as List).any(
      (m) =>
          m['role'] == 'system' &&
          (m['content'] as String).contains('candidate next messages'),
    );
    final response = suggestionResponse;
    if (isSuggestion) {
      suggestionRequests.add(body);
      final hold = suggestionHold;
      if (hold != null) await hold.future;
    }
    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode({
        'choices': [
          {
            'message': {'content': isSuggestion ? response : 'Test title'},
          },
        ],
      }),
    );
    await request.response.close();
    if (isSuggestion) suggestionResponsesSent++;
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
    service = _GatedChatService(existingRepository: repository);
    await service.init();
    streamRequestCount = 0;
    apiOverride = null;
    streamRequests.clear();
    streamHold = null;
    suggestionHold = null;
    suggestionRequests.clear();
    suggestionResponsesSent = 0;
    suggestionResponse = '{"suggestions":["suggestion one","suggestion two"]}';
    questions = AskUserInteractionService();
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
    bool withComposer = false,
  }) async {
    HomePageController? controller;
    late Zone sendZone;
    final baseUrl = 'http://${server.address.address}:${server.port}/v1';
    // Futures only complete for awaits on the zone that created them, and the
    // send path runs inside runAsync: build and fully configure every provider
    // there so its loaded/write futures belong to the real-async zone.
    await tester.runAsync(() async {
      sendZone = Zone.current;
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
        await settings.resetSuggestionModel();
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
          ChangeNotifierProvider<AskUserInteractionService>.value(
            value: questions,
          ),
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
          home: _ControllerHarness(
            onCreated: (value) => controller = value,
            withComposer: withComposer,
            onSend: (input) =>
                sendZone.run(() => controller!.sendMessage(input)),
          ),
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

  Future<void> waitForWidget(
    WidgetTester tester,
    bool Function() condition,
    String description,
  ) async {
    for (var i = 0; i < 300 && !condition(); i++) {
      await tester.pump(const Duration(milliseconds: 10));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }
    expect(condition(), isTrue, reason: 'timed out waiting for $description');
  }

  Future<void> finishWidget(WidgetTester tester, Future<void> future) async {
    var done = false;
    Object? failure;
    future.then<void>(
      (_) {
        done = true;
      },
      onError: (Object error) {
        failure = error;
        done = true;
      },
    );
    await waitForWidget(tester, () => done, 'asynchronous operation');
    if (failure != null) throw failure!;
  }

  Future<ProviderConfig> configureNative({
    required bool claude,
    required bool stream,
  }) async {
    final config = settings
        .getProviderConfig('SiliconFlow')
        .copyWith(
          providerType: claude ? ProviderKind.claude : ProviderKind.openai,
          useResponseApi: !claude,
        );
    await settings.setProviderConfig(config.id, config);
    await settings.setCurrentModel(
      config.id,
      claude ? 'claude-sonnet-4-6' : 'gpt-5.4',
    );
    await settings.disableTitleGeneration();
    await settings.disableSuggestionGeneration();
    await assistantProvider.updateAssistant(
      assistantProvider.currentAssistant!.copyWith(
        streamOutput: stream,
        localToolIds: [AskUserToolNames.askUser],
      ),
    );
    return config;
  }

  for (final claude in [false, true]) {
    testWidgets(
      'nonstream cancel during checkpoint never starts the pending tool: claude=$claude',
      (tester) async {
        final controller = await pumpHarness(tester);
        await tester.runAsync(() async {
          await configureNative(claude: claude, stream: false);
          final hold = Completer<void>();
          service.checkpointHold = hold;
          const arguments = {
            'questions': [
              {'id': 'q1', 'question': 'Continue?'},
            ],
          };
          apiOverride = (request, body) async {
            if (claude) {
              request.response.headers.contentType = ContentType.json;
              request.response.write(
                jsonEncode({
                  'content': [
                    {'type': 'text', 'text': 'Before tool.'},
                    {
                      'type': 'tool_use',
                      'id': 'cancel-probe',
                      'name': AskUserToolNames.askUser,
                      'input': arguments,
                    },
                  ],
                  'stop_reason': 'tool_use',
                }),
              );
              await request.response.close();
            } else {
              await _writeResponses(request, body, [
                _nativeText('Before tool.'),
                {
                  'type': 'function_call',
                  'call_id': 'cancel-probe',
                  'name': AskUserToolNames.askUser,
                  'arguments': jsonEncode(arguments),
                },
              ]);
            }
          };
          final conversation = await openConversation(controller);
          final sending = controller.sendMessage(ChatInputData(text: 'Ask me'));
          try {
            await service.checkpointEntered.future.timeout(
              const Duration(seconds: 10),
            );
            expect(questions.pendingRequests, isEmpty);
            final cancelling = controller.cancelStreaming();
            await waitFor(
              () => !controller.chatController.messages.last.isStreaming,
              'cancellation published before checkpoint release',
            );
            hold.complete();
            await cancelling;
            // Let the tool closure finish too. A regression creates a new
            // prompt after cancellation and leaves this generation waiting.
            var completed = false;
            final completion = sending.then((_) => completed = true);
            await waitFor(
              () => completed || questions.pendingRequests.isNotEmpty,
              'cancelled generation to settle',
            );
            final pendingAfterCancel = List<String>.of(
              questions.pendingRequests.keys,
            );
            questions.cancelForConversation(conversation.id);
            await completion;
            expect(pendingAfterCancel, isEmpty);
          } finally {
            if (!hold.isCompleted) hold.complete();
            questions.cancelForConversation(conversation.id);
            await ChatActions.cancelActiveGenerationFor(conversation.id);
            await sending.timeout(const Duration(seconds: 10));
          }
        });
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'nonstream completed exchange is durable before next tool starts claude=$claude',
      (tester) async {
        final controller = await pumpHarness(tester);
        await tester.runAsync(() async {
          await configureNative(claude: claude, stream: false);
          final requests = <Map<String, dynamic>>[];
          const args = {
            'questions': [
              {'id': 'q1', 'question': 'Continue?'},
            ],
          };
          apiOverride = (request, body) async {
            requests.add(body);
            final first = requests.length <= 2;
            final callId = requests.length == 1 ? 'probe-first' : 'probe-ask';
            request.response.headers.contentType = ContentType.json;
            request.response.write(
              jsonEncode(
                claude
                    ? {
                        'content': [
                          {
                            'type': 'thinking',
                            'thinking': 'Plan',
                            'signature': 'signed-plan',
                          },
                          {
                            'type': 'text',
                            'text': first ? 'Before asking. ' : 'Done',
                          },
                          if (first)
                            {
                              'type': 'tool_use',
                              'id': callId,
                              'name': AskUserToolNames.askUser,
                              'input': args,
                            },
                        ],
                        'stop_reason': first ? 'tool_use' : 'end_turn',
                      }
                    : {
                        'output': [
                          _nativeReasoning('probe-plan'),
                          _nativeText(first ? 'Before asking. ' : 'Done'),
                          if (first)
                            {
                              'type': 'function_call',
                              'call_id': callId,
                              'name': AskUserToolNames.askUser,
                              'arguments': jsonEncode(args),
                            },
                        ],
                      },
              ),
            );
            await request.response.close();
          };
          final conversation = await openConversation(controller);
          final sending = controller.sendMessage(
            ChatInputData(text: 'Ask before continuing'),
          );
          await waitFor(
            () => questions.pendingRequests.containsKey('probe-first'),
            'first probe tool pending',
          );
          questions.answer('probe-first', {
            'q1': const AskUserAnswerValue.single(
              value: 'First completed answer',
              custom: true,
            ),
          });
          await waitFor(
            () => questions.pendingRequests.containsKey('probe-ask'),
            'second probe tool pending',
          );
          final reloadedRepository = ChatDatabaseRepository.open(
            file: File('${directory.path}/kelivo.db'),
          );
          await reloadedRepository.ensureReady();
          final messages = await reloadedRepository.getMessagesRange(
            conversation.id,
            start: 0,
            limit: 20,
          );
          final waiting = messages.last;
          final artifact = await reloadedRepository
              .getProviderArtifactsForMessages([
                waiting.id,
              ], claude ? claudeTurnArtifactKind : responsesTurnArtifactKind);
          await reloadedRepository.close();
          questions.answer('probe-ask', {
            'q1': const AskUserAnswerValue.single(value: 'Yes', custom: true),
          });
          await sending;
          await waitFor(
            () => !controller.chatController.isConversationLoading(
              conversation.id,
            ),
            'probe generation finish',
          );
          expect(
            artifact[waiting.id],
            contains(claude ? 'signed-plan' : 'opaque-probe-plan'),
          );
          final pending = waiting.parts
              .whereType<ToolCallPart>()
              .map((p) => jsonDecode(p.payloadJson) as Map)
              .singleWhere((event) => event['id'] == 'probe-ask');
          expect(pending['content'], isNull);
          final completed = waiting.parts
              .whereType<ToolCallPart>()
              .map((p) => jsonDecode(p.payloadJson) as Map)
              .where((event) => event['id'] == 'probe-first');
          expect(
            completed,
            hasLength(1),
            reason:
                'The previous call and its answered result must survive a new database connection',
          );
          expect(
            completed.single['content'],
            contains('First completed answer'),
          );
          expect(waiting.content, 'Before asking. Before asking. ');
          final finished = (await service.loadMessages(conversation.id)).last;
          expect(finished.content, 'Before asking. Before asking. Done');
          expect(finished.parts.whereType<ToolCallPart>(), hasLength(2));
          expect(finished.firstTokenMs, isNull);
          if (claude) expect(finished.reasoningText, 'PlanPlanPlan');
        });
      },
    );
  }

  for (final claude in [false, true]) {
    testWidgets(
      'nonstream native state is persisted and sent on next question: claude=$claude',
      (tester) async {
        final controller = await pumpHarness(tester);
        await tester.runAsync(() async {
          await configureNative(claude: claude, stream: false);
          final requests = <Map<String, dynamic>>[];
          const thinking = {
            'type': 'thinking',
            'thinking': '',
            'signature': 'opaque-claude',
          };
          apiOverride = (request, body) async {
            requests.add(body);
            expect(body['stream'], isFalse);
            request.response.headers.contentType = ContentType.json;
            request.response.write(
              jsonEncode(
                claude
                    ? {
                        'content': [
                          thinking,
                          {'type': 'text', 'text': 'Answer'},
                        ],
                        'stop_reason': 'end_turn',
                      }
                    : {
                        'output': [
                          _nativeReasoning('first'),
                          _nativeText('Answer'),
                        ],
                      },
              ),
            );
            await request.response.close();
          };
          final convo = await openConversation(controller);
          await controller.sendMessage(ChatInputData(text: 'Question'));
          await waitFor(
            () => !controller.chatController.isConversationLoading(convo.id),
            'nonstream finish',
          );
          final reply = (await service.loadMessages(convo.id)).last;
          final kind = claude
              ? claudeTurnArtifactKind
              : responsesTurnArtifactKind;
          final persisted = await repository.getProviderArtifactsForMessages([
            reply.id,
          ], kind);
          expect(
            persisted[reply.id],
            contains(claude ? 'opaque-claude' : 'opaque-first'),
          );
          expect(
            service.getProviderArtifact(reply.id, kind),
            persisted[reply.id],
          );
          await controller.sendMessage(ChatInputData(text: 'Next'));
          await waitFor(
            () => !controller.chatController.isConversationLoading(convo.id),
            'next finish',
          );
          expect(requests, hasLength(2));
          final history = requests.last[claude ? 'messages' : 'input'] as List;
          if (claude) {
            final assistant = history.singleWhere(
              (m) => m['role'] == 'assistant',
            );
            expect(assistant['content'], [
              thinking,
              {'type': 'text', 'text': 'Answer'},
            ]);
          } else {
            expect(history.where((m) => m['type'] == 'reasoning'), [
              _nativeReasoning('first'),
            ]);
          }
        });
        expect(tester.takeException(), isNull);
      },
    );
  }

  Future<void> evictConversationMessages(String conversationId) async {
    final pressure = await service.createConversation(
      title: 'Cache pressure',
      activate: false,
    );
    for (var i = 0; i < 12; i++) {
      await service.addMessage(
        conversationId: pressure.id,
        role: 'user',
        content: '$i${'x' * (512 * 1024)}',
      );
    }
    expect(service.getMessages(conversationId), isEmpty);
  }

  for (final evicted in [false, true]) {
    testWidgets(
      'Claude recovered native history retains both signed responses: evicted=$evicted',
      (tester) async {
        final controller = await pumpHarness(tester);
        await tester.runAsync(() async {
          final config = await configureNative(claude: true, stream: false);
          final convo = await openConversation(controller);
          const arguments = {
            'questions': [
              {'id': 'q1', 'question': 'Which option?'},
            ],
          };
          const oldBlocks = [
            {'type': 'thinking', 'thinking': '', 'signature': 'opaque-old'},
            {'type': 'text', 'text': 'Before asking. '},
            {
              'type': 'tool_use',
              'id': 'old-ask',
              'name': AskUserToolNames.askUser,
              'input': arguments,
            },
          ];
          const freshBlocks = [
            {'type': 'thinking', 'thinking': '', 'signature': 'opaque-fresh'},
            {'type': 'text', 'text': 'Answer'},
          ];
          await service.addMessage(
            conversationId: convo.id,
            role: 'user',
            content: 'Ask me',
          );
          final reply = await service.addMessage(
            conversationId: convo.id,
            role: 'assistant',
            providerId: config.id,
            modelId: 'claude-sonnet-4-6',
            parts: [
              const TextPart('Before asking. '),
              ToolCallPart(
                jsonEncode({
                  'id': 'old-ask',
                  'name': AskUserToolNames.askUser,
                  'arguments': arguments,
                  'content': null,
                }),
              ),
            ],
          );
          await service.setProviderArtifact(
            reply.id,
            claudeTurnArtifactKind,
            encodeClaudeTurn([oldBlocks]),
          );
          final requests = <Map<String, dynamic>>[];
          apiOverride = (request, body) async {
            requests.add(body);
            request.response.headers.contentType = ContentType.json;
            request.response.write(
              jsonEncode({'content': freshBlocks, 'stop_reason': 'end_turn'}),
            );
            await request.response.close();
          };
          await controller.chatController.setCurrentConversationAndLoad(convo);
          if (evicted) await evictConversationMessages(convo.id);
          await controller.submitRecoveredAskUserAnswer(
            reply,
            const ToolUIPart(
              id: 'old-ask',
              toolName: AskUserToolNames.askUser,
              arguments: arguments,
              loading: true,
            ),
            const AskUserResult.answer({
              'q1': AskUserAnswerValue.single(value: 'approved', custom: true),
            }),
          );
          await waitFor(
            () => !controller.chatController.isConversationLoading(convo.id),
            'Claude recovery finish',
          );
          expect(
            decodeClaudeTurn(
              service.getProviderArtifact(reply.id, claudeTurnArtifactKind),
            ),
            [oldBlocks, freshBlocks],
          );
          await controller.sendMessage(ChatInputData(text: 'Next'));
          await waitFor(
            () => !controller.chatController.isConversationLoading(convo.id),
            'Claude next finish',
          );
          expect(requests, hasLength(2));
          final messages = requests.last['messages'] as List;
          final assistants = messages
              .where((m) => m['role'] == 'assistant')
              .toList();
          expect(assistants.map((m) => m['content']), [oldBlocks, freshBlocks]);
          final results = messages.where(
            (m) => m['role'] == 'user' && m['content'] is List,
          );
          expect(jsonEncode(results.toList()), contains('approved'));
        });
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final stream in [false, true]) {
    for (final temporary in [false, true]) {
      for (final preamble in ['', 'Before asking. ']) {
        for (final evicted in [false, if (!temporary) true]) {
          testWidgets(
            'native Responses recovery keeps all rounds: stream=$stream, temporary=$temporary, evicted=$evicted, preamble="$preamble"',
            (tester) async {
              final controller = await pumpHarness(tester);
              await tester.runAsync(() async {
                final config = await configureNative(
                  claude: false,
                  stream: stream,
                );
                final convo = temporary
                    ? await service.createDraftConversation(
                        title: 'Recovery',
                        temporary: true,
                      )
                    : await service.createConversation(title: 'Recovery');
                const arguments = {
                  'questions': [
                    {'id': 'q1', 'question': 'Which option?'},
                  ],
                };
                Map<String, dynamic> call(String id) => {
                  'type': 'function_call',
                  'id': 'fc-$id',
                  'call_id': id,
                  'name': AskUserToolNames.askUser,
                  'arguments': jsonEncode(arguments),
                };
                final oldOutput = [
                  _nativeReasoning('old'),
                  if (preamble.isNotEmpty) _nativeText(preamble),
                  call('old-ask'),
                ];
                await service.addMessage(
                  conversationId: convo.id,
                  role: 'user',
                  content: 'Ask me',
                );
                final reply = await service.addMessage(
                  conversationId: convo.id,
                  role: 'assistant',
                  providerId: config.id,
                  modelId: 'gpt-5.4',
                  parts: [
                    if (preamble.isNotEmpty) TextPart(preamble),
                    ToolCallPart(
                      jsonEncode({
                        'id': 'old-ask',
                        'name': AskUserToolNames.askUser,
                        'arguments': arguments,
                        'content': null,
                      }),
                    ),
                    const AssistantRoundEndPart(),
                  ],
                );
                await service.setProviderArtifact(
                  reply.id,
                  responsesTurnArtifactKind,
                  ResponsesTurnRecorder(
                    responsesReplayScope(config, 'gpt-5.4'),
                  ).record(oldOutput, [
                    emitToolCall(
                      id: 'old-ask',
                      name: AskUserToolNames.askUser,
                      arguments: arguments,
                    ),
                  ]).payload,
                );
                final requests = <Map<String, dynamic>>[];
                final middle = [
                  _nativeReasoning('middle'),
                  _nativeText('During recovery. '),
                  call('live-ask'),
                ];
                final finalOutput = [
                  _nativeReasoning('final'),
                  _nativeText('Answer'),
                ];
                apiOverride = (request, body) async {
                  requests.add(body);
                  await _writeResponses(
                    request,
                    body,
                    requests.length == 1 ? middle : finalOutput,
                  );
                };
                await controller.chatController.setCurrentConversationAndLoad(
                  convo,
                );
                if (evicted) await evictConversationMessages(convo.id);
                final resumed = controller.submitRecoveredAskUserAnswer(
                  reply,
                  const ToolUIPart(
                    id: 'old-ask',
                    toolName: AskUserToolNames.askUser,
                    arguments: arguments,
                    loading: true,
                  ),
                  const AskUserResult.answer({
                    'q1': AskUserAnswerValue.single(
                      value: 'original answer',
                      custom: true,
                    ),
                  }),
                );
                await waitFor(
                  () => questions.pendingRequests.containsKey('live-ask'),
                  'second ask',
                );
                questions.answer('live-ask', {
                  'q1': const AskUserAnswerValue.single(
                    value: 'follow-up answer',
                    custom: true,
                  ),
                });
                await resumed;
                await waitFor(
                  () => !controller.chatController.isConversationLoading(
                    convo.id,
                  ),
                  'recovery finish',
                );
                expect(requests, hasLength(2));
                final firstInput = requests.first['input'] as List;
                expect(
                  firstInput.where(
                    (m) =>
                        m['type'] != null &&
                        m['type'] != 'function_call_output',
                  ),
                  oldOutput,
                );
                final artifact = service.getProviderArtifact(
                  reply.id,
                  responsesTurnArtifactKind,
                )!;
                final rounds = (jsonDecode(artifact) as Map)['rounds'] as List;
                expect(rounds.map((round) => round['output']), [
                  oldOutput,
                  middle,
                  finalOutput,
                ]);
                if (!temporary) {
                  expect(
                    (await repository.getProviderArtifactsForMessages([
                      reply.id,
                    ], responsesTurnArtifactKind))[reply.id],
                    artifact,
                  );
                }
                await controller.sendMessage(ChatInputData(text: 'Next'));
                await waitFor(
                  () => !controller.chatController.isConversationLoading(
                    convo.id,
                  ),
                  'next finish',
                );
                expect(requests, hasLength(3));
                final next = requests.last['input'] as List;
                expect(
                  next
                      .where((m) => m['type'] == 'reasoning')
                      .map((m) => m['encrypted_content']),
                  ['opaque-old', 'opaque-middle', 'opaque-final'],
                );
                expect(
                  next
                      .where((m) => m['type'] == 'function_call')
                      .map((m) => m['call_id']),
                  ['old-ask', 'live-ask'],
                );
                final answers = next
                    .where((m) => m['type'] == 'function_call_output')
                    .toList();
                expect(answers.map((m) => m['call_id']), [
                  'old-ask',
                  'live-ask',
                ]);
                expect(answers.first['output'], contains('original answer'));
                expect(answers.last['output'], contains('follow-up answer'));
                final latest = (await service.loadMessages(convo.id)).last;
                expect(
                  (jsonDecode(
                        service.getProviderArtifact(
                          latest.id,
                          responsesTurnArtifactKind,
                        )!,
                      )
                      as Map)['rounds'],
                  hasLength(1),
                );
              });
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }
  }

  for (final temporary in [false, true]) {
    testWidgets('recovered ask answer reaches request: temporary=$temporary', (
      tester,
    ) async {
      final controller = await pumpHarness(tester);
      await tester.runAsync(() async {
        final convo = temporary
            ? await service.createDraftConversation(
                title: 'Recovered ask',
                temporary: true,
              )
            : await service.createConversation(title: 'Recovered ask');
        await service.addMessage(
          conversationId: convo.id,
          role: 'user',
          content: 'Ask me what to do',
        );
        final arguments = <String, dynamic>{
          'questions': [
            {'id': 'q1', 'question': 'Which option?'},
          ],
        };
        final reply = await service.addMessage(
          conversationId: convo.id,
          role: 'assistant',
          providerId: 'SiliconFlow',
          modelId: 'test-model',
          parts: [
            const ReasoningPart('Need user choice'),
            ToolCallPart(
              jsonEncode({
                'id': 'recovered-ask',
                'name': AskUserToolNames.askUser,
                'arguments': arguments,
                'content': null,
              }),
            ),
            const AssistantRoundEndPart(),
          ],
        );
        await controller.chatController.setCurrentConversationAndLoad(convo);
        await controller.submitRecoveredAskUserAnswer(
          reply,
          ToolUIPart(
            id: 'recovered-ask',
            toolName: AskUserToolNames.askUser,
            arguments: arguments,
            loading: true,
          ),
          const AskUserResult.answer({
            'q1': AskUserAnswerValue.single(
              value: 'Only review; do not modify files',
              custom: true,
            ),
          }),
        );
        await waitFor(() => streamRequestCount == 1, 'recovered request');
        await waitFor(
          () => !controller.chatController.isConversationLoading(convo.id),
          'recovered streaming to finish',
        );
        final requestMessages = (streamRequests.single['messages'] as List)
            .cast<Map>();
        final result = requestMessages.singleWhere((m) => m['role'] == 'tool');
        expect(result['tool_call_id'], 'recovered-ask');
        final answer = jsonDecode(result['content'] as String) as Map;
        expect(answer['type'], 'ask_user_answer');
        expect(
          answer['answers']['q1']['value'],
          'Only review; do not modify files',
        );
        final assistant = requestMessages.singleWhere(
          (m) => m['role'] == 'assistant',
        );
        expect(assistant['tool_calls'].single['id'], 'recovered-ask');
      });
      expect(tester.takeException(), isNull);
    });
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

  for (final (laterInput, afterCommit) in [
    ('text', false),
    ('attachment', false),
    ('none', false),
    ('text', true),
    ('cleared', false),
  ]) {
    testWidgets(
      'edit submission preserves later $laterInput input${afterCommit ? ' after database commit' : ''}',
      (tester) async {
        final controller = await pumpHarness(tester, withComposer: true);
        final state = tester.state<_ControllerHarnessState>(
          find.byType(_ControllerHarness),
        );
        late Conversation conversation;
        late ChatMessage original;
        await tester.runAsync(() async {
          conversation = await service.createConversation(title: 'Edit draft');
          await controller.debugViewModel.switchConversation(conversation.id);
          await waitFor(
            () => state._mediaController.draftOwnerId == conversation.id,
            'composer binding',
          );
          original = await service.addMessage(
            conversationId: conversation.id,
            role: 'user',
            content: 'original',
          );
          await controller.chatController.setCurrentConversationAndLoad(
            conversation,
          );
          state._inputController.text = 'ordinary draft';
          await controller.startUserMessageEdit(original);
        });
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(EditableText), 'submitted edit');
        service.versionSaveHold = Completer<void>();
        service.holdAfterVersionSave = afterCommit;
        if (laterInput == 'cleared') {
          service.regenerationHold = Completer<void>();
        }
        await tester.tap(find.byIcon(Lucide.ArrowUp));
        await tester.pump();
        await waitForWidget(
          tester,
          () => service.versionSaveEntered,
          'version persistence',
        );
        expect(state._inputController.text, isEmpty);
        if (afterCommit) {
          // A cleared interim edit can autosave after the version commits,
          // while the UI is still waiting for the save callback.
          await tester.enterText(find.byType(EditableText), 'interim input');
          await tester.enterText(find.byType(EditableText), '');
          await finishWidget(tester, service.composerDrafts!.flush());
        }
        if (laterInput == 'text' || laterInput == 'cleared') {
          await tester.enterText(
            find.byType(EditableText),
            'typed after submit',
          );
        } else if (laterInput == 'attachment') {
          state._mediaController.addFiles([
            const DocumentAttachment(
              path: '/later.txt',
              fileName: 'later.txt',
              mime: 'text/plain',
            ),
          ]);
        }
        service.versionSaveHold!.complete();
        if (laterInput == 'cleared') {
          await waitForWidget(
            tester,
            () => service.regenerationEntered,
            'regeneration preparation',
          );
          await tester.enterText(find.byType(EditableText), '');
          service.regenerationHold!.complete();
        }
        await waitForWidget(
          tester,
          () =>
              streamRequestCount == 1 &&
              !service.composerDrafts!.submitting.contains(conversation.id) &&
              !controller.chatController.isConversationLoading(conversation.id),
          'edit submission and regeneration',
        );
        await tester.runAsync(() async {
          await service.composerDrafts!.flush();
          final versions = await service.loadMessages(conversation.id);
          expect(
            versions
                .where((m) => m.role == 'user' && m.version == 1)
                .single
                .content,
            'submitted edit',
          );
        });
        await tester.pumpAndSettle();
        final draft = service.composerDrafts!.peek(conversation.id)!;
        expect(draft.compose.text, 'ordinary draft');
        expect(draft.pending, isNull);
        if (laterInput == 'none' || laterInput == 'cleared') {
          expect(controller.isUserMessageEditActive, isFalse);
          expect(state._inputController.text, 'ordinary draft');
        } else {
          expect(controller.userMessageEditState?.messageId, original.id);
          if (laterInput == 'text') {
            expect(state._inputController.text, 'typed after submit');
            expect(draft.edit!.text, 'typed after submit');
          } else {
            expect(
              state._mediaController
                  .snapshotDraft(state._inputController.text)
                  .documents
                  .single
                  .fileName,
              'later.txt',
            );
            expect(draft.edit!.documents.single.fileName, 'later.txt');
          }
          controller.cancelUserMessageEdit();
          expect(state._inputController.text, 'ordinary draft');
        }
        await tester.pumpWidget(const SizedBox());
        await finishWidget(tester, service.composerDrafts!.flush());
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final saveOnly in [false, true]) {
    testWidgets(
      'ordinary file import survives edit submission (save only: $saveOnly)',
      (tester) async {
        final controller = await pumpHarness(tester, withComposer: true);
        final state = tester.state<_ControllerHarnessState>(
          find.byType(_ControllerHarness),
        );
        late Conversation conversation;
        late ChatMessage original;
        late GatedXFile file;
        await tester.runAsync(() async {
          conversation = await service.createConversation(
            title: 'Ordinary import',
          );
          original = await service.addMessage(
            conversationId: conversation.id,
            role: 'user',
            content: 'original',
          );
          await controller.debugViewModel.switchConversation(conversation.id);
          await waitFor(
            () => state._mediaController.draftOwnerId == conversation.id,
            'composer',
          );
          state._inputController.text = 'ordinary draft';
          final source = await File(
            '${directory.path}/ordinary.txt',
          ).writeAsString('ordinary attachment');
          file = GatedXFile(source.path);
        });
        final importing = controller.onFilesDroppedDesktop([file]);
        await finishWidget(tester, file.started.future);
        await controller.startUserMessageEdit(original);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(EditableText), 'saved edit');
        if (saveOnly) {
          await finishWidget(tester, controller.saveUserMessageEditOnly());
        } else {
          await tester.tap(find.byIcon(Lucide.ArrowUp));
          await waitForWidget(
            tester,
            () =>
                service.versionSaveEntered &&
                !service.composerDrafts!.submitting.contains(conversation.id) &&
                !controller.chatController.isConversationLoading(
                  conversation.id,
                ),
            'edit completion',
          );
        }
        expect(controller.isUserMessageEditActive, isFalse);
        expect(state._inputController.text, 'ordinary draft');
        file.release.complete();
        await finishWidget(tester, importing);
        await finishWidget(tester, service.composerDrafts!.flush());
        final docs = state._mediaController
            .snapshotDraft(state._inputController.text)
            .documents;
        expect(docs, hasLength(1));
        expect(docs.single.fileName, 'ordinary.txt');
        expect(
          service.composerDrafts!
              .peek(conversation.id)!
              .compose
              .documents
              .single
              .fileName,
          'ordinary.txt',
        );
        await tester.runAsync(() async {
          expect(
            await File(docs.single.path).readAsString(),
            'ordinary attachment',
          );
          final edited = (await service.loadMessages(conversation.id))
              .where(
                (message) => message.role == 'user' && message.version == 1,
              )
              .single;
          expect(edited.content, 'saved edit');
          expect(edited.parts.whereType<FilePart>(), isEmpty);
        });
        await tester.pumpWidget(const SizedBox());
        await finishWidget(tester, service.composerDrafts!.flush());
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final (laterInput, callbackFails, navigate) in [
    ('text', false, true),
    ('attachment', false, true),
    ('none', false, true),
    ('text', true, true),
    ('none', false, false),
  ]) {
    testWidgets(
      'save-only preserves $laterInput ${navigate ? 'after A-B-A navigation' : 'while staying in A'} (callback fails: $callbackFails)',
      (tester) async {
        final controller = await pumpHarness(tester, withComposer: true);
        final state = tester.state<_ControllerHarnessState>(
          find.byType(_ControllerHarness),
        );
        late Conversation a;
        late Conversation b;
        late ChatMessage original;
        await tester.runAsync(() async {
          a = await service.createConversation(title: 'A');
          b = await service.createConversation(title: 'B');
          original = await service.addMessage(
            conversationId: a.id,
            role: 'user',
            content: 'original',
          );
          await controller.debugViewModel.switchConversation(a.id);
          await waitFor(
            () => state._mediaController.draftOwnerId == a.id,
            'A draft',
          );
          state._inputController.text = 'ordinary draft';
          await controller.startUserMessageEdit(original);
        });
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(EditableText), 'saved edit');
        service.versionSaveHold = Completer<void>();
        service.failAfterVersionSave = callbackFails;
        final saving = controller.saveUserMessageEditOnly();
        await waitForWidget(
          tester,
          () => service.versionSaveEntered,
          'save-only persistence',
        );
        expect(state._mediaController.restoringDraft, isTrue);
        for (final id in navigate ? [b.id, a.id] : <String>[]) {
          await finishWidget(tester, controller.switchConversationAnimated(id));
          await waitForWidget(
            tester,
            () =>
                state._mediaController.draftOwnerId == id &&
                !state._mediaController.restoringDraft,
            'restored composer',
          );
        }
        if (laterInput == 'text') {
          await tester.enterText(
            find.byType(EditableText),
            'new edit after returning',
          );
        } else if (laterInput == 'attachment') {
          state._mediaController.addFiles([
            const DocumentAttachment(
              path: '/later.txt',
              fileName: 'later.txt',
              mime: 'text/plain',
            ),
          ]);
        }
        service.versionSaveHold!.complete();
        await finishWidget(tester, saving);
        await finishWidget(tester, service.composerDrafts!.flush());
        expect(streamRequestCount, 0);
        final draft = service.composerDrafts!.peek(a.id)!;
        expect(draft.compose.text, 'ordinary draft');
        expect(draft.pending, isNull);
        expect(state._mediaController.restoringDraft, isFalse);
        if (laterInput == 'none') {
          expect(controller.isUserMessageEditActive, isFalse);
          expect(state._inputController.text, 'ordinary draft');
        } else {
          expect(controller.userMessageEditState?.messageId, original.id);
          if (laterInput == 'text') {
            expect(state._inputController.text, 'new edit after returning');
            expect(draft.edit!.text, 'new edit after returning');
          } else {
            expect(
              state._mediaController
                  .snapshotDraft(state._inputController.text)
                  .documents
                  .single
                  .fileName,
              'later.txt',
            );
            expect(draft.edit!.documents.single.fileName, 'later.txt');
          }
          controller.cancelUserMessageEdit();
          expect(state._inputController.text, 'ordinary draft');
        }
        await tester.runAsync(() async {
          final messages = await service.loadMessages(a.id);
          expect(
            messages.where((message) => message.version == 1).single.content,
            'saved edit',
          );
        });
        await tester.pumpWidget(const SizedBox());
        await finishWidget(tester, service.composerDrafts!.flush());
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final targetText in ['', 'existing target draft']) {
    testWidgets(
      'share keeps its target through preset loading and animated navigation (target: $targetText)',
      (tester) async {
        final controller = await pumpHarness(tester, withComposer: true);
        final state = tester.state<_ControllerHarnessState>(
          find.byType(_ControllerHarness),
        );
        late Conversation b;
        await tester.runAsync(() async {
          b = await service.createConversation(title: 'B');
          await controller.debugViewModel.switchConversation(b.id);
          await waitFor(
            () => state._mediaController.draftOwnerId == b.id,
            'B draft',
          );
          await assistantProvider.updateAssistant(
            assistantProvider.currentAssistant!.copyWith(
              presetMessages: [
                PresetMessage(role: 'user', content: 'preset question'),
              ],
            ),
          );
        });
        service.presetHold = Completer<void>();
        bool? accepted;
        Object? failure;
        final delivery = controller
            .openIncomingShareDraft(
              const ChatInputData(text: 'shared input'),
              shareIds: ['share-owner-test'],
            )
            .then<void>(
              (value) {
                accepted = value;
              },
              onError: (Object error) {
                failure = error;
              },
            );
        await waitForWidget(
          tester,
          () => service.presetConversationId != null,
          'preset insertion',
        );
        final target = service.presetConversationId!;
        expect(target, isNot(b.id));
        await waitForWidget(
          tester,
          () => state._mediaController.draftOwnerId == target,
          'share target binding',
        );
        state._inputController.text = targetText;
        await finishWidget(tester, controller.switchConversationAnimated(b.id));
        await waitForWidget(
          tester,
          () => state._mediaController.draftOwnerId == b.id,
          'B binding',
        );
        expect(state._inputController.text, isEmpty);
        service.presetHold!.complete();
        await finishWidget(tester, delivery);
        expect(controller.currentConversation!.id, b.id);
        expect(state._inputController.text, isEmpty);
        expect(service.composerDrafts!.peek(b.id)!.active.isEmpty, isTrue);
        expect(find.byType(AlertDialog), findsNothing);
        if (targetText.isEmpty) {
          expect(failure, isNull);
          expect(accepted, isTrue);
          expect(
            service.composerDrafts!.peek(target)!.active.text,
            'shared input',
          );
          await tester.runAsync(() async {
            expect(
              await service.composerDrafts!.hasShareReceipt('share-owner-test'),
              isTrue,
            );
            expect(
              (await service.loadMessages(target)).single.content,
              'preset question',
            );
          });
          await finishWidget(
            tester,
            controller.switchConversationAnimated(target),
          );
          await waitForWidget(
            tester,
            () => state._mediaController.draftOwnerId == target,
            'shared draft restore',
          );
          expect(state._inputController.text, 'shared input');
        } else {
          expect(failure, isStateError);
          expect(accepted, isNull);
          expect(service.composerDrafts!.peek(target)!.active.text, targetText);
          await tester.runAsync(() async {
            expect(
              await service.composerDrafts!.hasShareReceipt('share-owner-test'),
              isFalse,
            );
          });
        }
        await tester.pumpWidget(const SizedBox());
        await finishWidget(tester, service.composerDrafts!.flush());
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('new entry reopens preset messages without reinjecting them', (
    tester,
  ) async {
    final controller = await pumpHarness(tester, withComposer: true);
    final state = tester.state<_ControllerHarnessState>(
      find.byType(_ControllerHarness),
    );
    await tester.runAsync(() async {
      await assistantProvider.updateAssistant(
        assistantProvider.currentAssistant!.copyWith(
          presetMessages: [
            PresetMessage(role: 'user', content: 'preset question'),
            PresetMessage(role: 'assistant', content: 'preset answer'),
          ],
        ),
      );
      await controller.debugViewModel.createNewConversation();
      final entry = controller.currentConversation!;
      await waitFor(
        () => state._mediaController.draftOwnerId == entry.id,
        'new entry binding',
      );
      state._inputController.text = 'unsent question';
      await service.composerDrafts!.flush();
      expect(service.getMessageCount(entry.id), 2);
      final other = await service.createConversation(title: 'other');
      await controller.debugViewModel.switchConversation(other.id);
      await waitFor(
        () => state._mediaController.draftOwnerId == other.id,
        'other conversation binding',
      );
      await controller.debugViewModel.createNewConversation();
      await waitFor(
        () => state._mediaController.draftOwnerId == entry.id,
        'restored entry binding',
      );
      expect(controller.currentConversation!.id, entry.id);
      expect(controller.messages.map((m) => m.content), [
        'preset question',
        'preset answer',
      ]);
      expect(service.getMessageCount(entry.id), 2);
      expect(state._inputController.text, 'unsent question');
    });
    await tester.pumpWidget(const SizedBox());
    await finishWidget(tester, service.composerDrafts!.flush());
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

  testWidgets(
    'suggestion requests isolate rules and preserve literal placeholders',
    (tester) async {
      final controller = await pumpHarness(tester, withSuggestions: true);
      await tester.runAsync(() async {
        final convo = await openConversation(controller);
        await controller.sendMessage(
          ChatInputData(text: 'Explain {locale} and {content}'),
        );
        await waitFor(
          () => service.getConversation(convo.id)!.chatSuggestions.isNotEmpty,
          'suggestions',
        );
        final request = suggestionRequests.single;
        final messages = request['messages'] as List;
        expect(messages.first['role'], 'system');
        expect(messages.first['content'], contains('JSON object'));
        expect(messages.last['role'], 'user');
        expect(
          messages.last['content'],
          contains('Explain {locale} and {content}'),
        );
        expect(messages.last['content'], contains('"role":"assistant"'));
        expect(request.containsKey('response_format'), isFalse);
      });
      expect(tester.takeException(), isNull);
    },
  );

  for (final mutation in [
    'clear context',
    'edit answer',
    'disable',
    'send again',
  ]) {
    testWidgets('discard delayed suggestions after $mutation', (tester) async {
      final controller = await pumpHarness(tester, withSuggestions: true);
      await tester.runAsync(() async {
        suggestionHold = Completer<void>();
        final convo = await openConversation(controller);
        await controller.sendMessage(ChatInputData(text: 'hello'));
        await waitFor(
          () => suggestionRequests.length == 1,
          'pending suggestions',
        );
        await waitFor(
          () => !controller.chatController.isConversationLoading(convo.id),
          'first reply to finish',
        );
        switch (mutation) {
          case 'clear context':
            await controller.clearContext();
          case 'edit answer':
            final messages = await service.loadMessages(convo.id);
            await service.updateMessage(
              messages.last.id,
              content: 'Edited answer',
            );
          case 'disable':
            await settings.disableSuggestionGeneration();
          case 'send again':
            streamHold = Completer<void>();
            await controller.sendMessage(ChatInputData(text: 'new question'));
            await waitFor(
              () => streamRequestCount == 2,
              'second stream to start',
            );
        }
        suggestionHold!.complete();
        await waitFor(() => suggestionResponsesSent == 1, 'delayed response');
        await Future<void>.delayed(const Duration(milliseconds: 200));
        expect(service.getConversation(convo.id)!.chatSuggestions, isEmpty);
        if (streamHold != null) {
          await settings.disableSuggestionGeneration();
          streamHold!.complete();
          await waitFor(
            () => !controller.chatController.isConversationLoading(convo.id),
            'second reply to finish',
          );
        }
      });
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('an empty suggestions array is not a background error', (
    tester,
  ) async {
    final controller = await pumpHarness(tester, withSuggestions: true);
    final errors = <Object>[];
    controller.debugViewModel.onBackgroundTaskError = (_, error) =>
        errors.add(error);
    await tester.runAsync(() async {
      suggestionResponse = '{"suggestions":[]}';
      final convo = await openConversation(controller);
      await controller.sendMessage(ChatInputData(text: 'Thanks, that is all.'));
      await waitFor(() => suggestionResponsesSent == 1, 'empty response');
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(service.getConversation(convo.id)!.chatSuggestions, isEmpty);
      expect(errors, isEmpty);
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'background suggestions use that conversations selected version',
    (tester) async {
      final controller = await pumpHarness(tester, withSuggestions: true);
      await tester.runAsync(() async {
        final convo = await openConversation(controller);
        await service.addMessage(
          conversationId: convo.id,
          role: 'user',
          content: 'Compare storage',
        );
        final answer = await service.addMessage(
          conversationId: convo.id,
          role: 'assistant',
          content: 'SELECTED ANSWER',
        );
        await service.addMessage(
          conversationId: convo.id,
          role: 'assistant',
          groupId: answer.groupId ?? answer.id,
          version: 1,
          content: 'UNSELECTED ANSWER',
        );
        await service.setSelectedVersion(
          convo.id,
          answer.groupId ?? answer.id,
          0,
        );
        final other = await service.createConversation(title: 'Other');
        await controller.chatController.setCurrentConversationAndLoad(other);
        controller.debugViewModel.debugChatActions.onMaybeGenerateSuggestions!(
          convo.id,
        );
        await waitFor(
          () => service.getConversation(convo.id)!.chatSuggestions.isNotEmpty,
          'background suggestions',
        );
        final prompt =
            (suggestionRequests.single['messages'] as List).last['content']
                as String;
        expect(prompt, contains('SELECTED ANSWER'));
        expect(prompt, isNot(contains('UNSELECTED ANSWER')));
        expect(controller.currentConversation!.id, other.id);
        expect(service.getConversation(other.id)!.chatSuggestions, isEmpty);
      });
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('older suggestion requests cannot overwrite a newer result', (
    tester,
  ) async {
    final controller = await pumpHarness(tester, withSuggestions: true);
    await tester.runAsync(() async {
      final convo = await openConversation(controller);
      await service.addMessage(
        conversationId: convo.id,
        role: 'user',
        content: 'Question',
      );
      await service.addMessage(
        conversationId: convo.id,
        role: 'assistant',
        content: 'Answer',
      );
      final oldHold = Completer<void>();
      suggestionHold = oldHold;
      suggestionResponse = '{"suggestions":["old suggestion"]}';
      controller.debugViewModel.debugChatActions.onMaybeGenerateSuggestions!(
        convo.id,
      );
      await waitFor(() => suggestionRequests.length == 1, 'old request');
      suggestionHold = null;
      suggestionResponse = '{"suggestions":["new suggestion"]}';
      controller.debugViewModel.debugChatActions.onMaybeGenerateSuggestions!(
        convo.id,
      );
      await waitFor(
        () => service.getConversation(convo.id)!.chatSuggestions.isNotEmpty,
        'new result',
      );
      expect(service.getConversation(convo.id)!.chatSuggestions, [
        'new suggestion',
      ]);
      oldHold.complete();
      await waitFor(() => suggestionResponsesSent == 2, 'old response');
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(service.getConversation(convo.id)!.chatSuggestions, [
        'new suggestion',
      ]);
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
  testWidgets('scheduled send uses its model over the conversation pin', (
    tester,
  ) async {
    final controller = await pumpHarness(tester);
    await tester.runAsync(() async {
      final target = await openConversation(controller);
      await controller.sendMessage(ChatInputData(text: 'Previous question'));
      await waitFor(
        () => !controller.chatController.isConversationLoading(target.id),
        'initial reply',
      );
      await service.setConversationModel(
        target.id,
        providerKey: 'SiliconFlow',
        modelId: 'pinned-model',
      );
      final foreground = await openConversation(controller);
      String? startedMessage;
      final result = await controller.debugViewModel.sendScheduledMessage(
        input: ChatInputData(text: 'Scheduled follow-up'),
        conversation: service.getConversation(target.id)!,
        assistant: assistantProvider.currentAssistant!,
        modelOverride: (providerKey: 'SiliconFlow', modelId: 'scheduled-model'),
        onGenerationStarted: (id) => startedMessage = id,
      );
      expect(result.success, isTrue);
      expect(startedMessage, result.assistantMessage!.id);
      await waitFor(
        () => !controller.chatController.isConversationLoading(target.id),
        'scheduled reply',
      );
      expect(streamRequests.last['model'], 'scheduled-model');
      final messages = streamRequests.last['messages'] as List;
      expect(
        messages.where((m) => m['role'] == 'user').map((m) => m['content']),
        ['Previous question', 'Scheduled follow-up'],
      );
      expect(service.getConversation(target.id)!.chatModelId, 'pinned-model');
      expect(settings.currentModelId, 'test-model');
      expect(controller.chatController.currentConversation!.id, foreground.id);
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'scheduled rerun preserves later messages and the foreground chat',
    (tester) async {
      final controller = await pumpHarness(tester);
      await tester.runAsync(() async {
        final target = await openConversation(controller);
        for (final question in ['First question', 'Later question']) {
          await controller.sendMessage(ChatInputData(text: question));
          await waitFor(
            () => !controller.chatController.isConversationLoading(target.id),
            'reply to $question',
          );
        }
        final before = List<ChatMessage>.of(
          await service.loadMessages(target.id),
        );
        final question = before.firstWhere((m) => m.role == 'user');
        await settings.setRegenerateDeleteTrailingMessages(true);
        final foreground = await openConversation(controller);
        final selections = Map<String, int>.of(
          controller.debugViewModel.versionSelections,
        );
        final result = await controller.debugViewModel
            .regenerateScheduledMessage(
              message: question,
              conversation: service.getConversation(target.id)!,
              assistant: assistantProvider.currentAssistant!,
              modelOverride: (
                providerKey: 'SiliconFlow',
                modelId: 'rerun-model',
              ),
            );
        expect(result.success, isTrue);
        expect(result.generationRunId, isNotNull);
        await waitFor(
          () => !controller.chatController.isConversationLoading(target.id),
          'scheduled rerun',
        );
        final after = await service.loadMessages(target.id);
        expect(after, hasLength(before.length + 1));
        expect(after.map((m) => m.id), containsAll(before.map((m) => m.id)));
        expect(streamRequests.last['model'], 'rerun-model');
        final messages = streamRequests.last['messages'] as List;
        expect(
          messages.where((m) => m['role'] == 'user').map((m) => m['content']),
          ['First question'],
        );
        expect(
          controller.chatController.currentConversation!.id,
          foreground.id,
        );
        expect(controller.debugViewModel.versionSelections, selections);
      });
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a busy scheduled target and stale cancellation leave the user stream running',
    (tester) async {
      final controller = await pumpHarness(tester);
      await tester.runAsync(() async {
        streamHold = Completer<void>();
        final target = await openConversation(controller);
        await controller.sendMessage(ChatInputData(text: 'User is chatting'));
        await waitFor(() => streamRequestCount == 1, 'held user request');
        final question = (await service.loadMessages(
          target.id,
        )).firstWhere((m) => m.role == 'user');
        var starts = 0;
        final send = await controller.debugViewModel.sendScheduledMessage(
          input: ChatInputData(text: 'Scheduled follow-up'),
          conversation: target,
          assistant: assistantProvider.currentAssistant!,
          onGenerationStarted: (_) => starts++,
        );
        final rerun = await controller.debugViewModel
            .regenerateScheduledMessage(
              message: question,
              conversation: target,
              assistant: assistantProvider.currentAssistant!,
              onGenerationStarted: (_) => starts++,
            );
        expect(send.errorMessage, 'in_flight');
        expect(rerun.errorMessage, 'in_flight');
        expect(starts, 0);
        await ChatActions.cancelActiveGenerationFor(
          target.id,
          expectedMessageId: 'finished-scheduled-run',
        );
        expect(
          controller.chatController.isConversationLoading(target.id),
          isTrue,
        );
        streamHold!.complete();
        await waitFor(
          () => !controller.chatController.isConversationLoading(target.id),
          'original user reply',
        );
        expect(streamRequestCount, 1);
        expect((await service.loadMessages(target.id)).last.content, 'ok');
      });
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'scheduled rerun before context reset succeeds without changing the cutoff',
    (tester) async {
      final controller = await pumpHarness(tester);
      await tester.runAsync(() async {
        final target = await openConversation(controller);
        await controller.sendMessage(ChatInputData(text: 'Original question'));
        await waitFor(
          () => !controller.chatController.isConversationLoading(target.id),
          'original reply',
        );
        final question = (await service.loadMessages(
          target.id,
        )).firstWhere((m) => m.role == 'user');
        await service.toggleTruncateAtTail(target.id);
        final current = service.getConversation(target.id)!;
        final choices = await repository.getSelectedMessageProjections(
          target.id,
        );
        expect(choices.any((m) => m.id == question.id), isTrue);
        expect(await repository.getMessage(question.id), isNotNull);
        final result = await controller.debugViewModel
            .regenerateScheduledMessage(
              message: question,
              conversation: current,
              assistant: assistantProvider.currentAssistant!,
            );
        expect(result.success, isTrue);
        await waitFor(
          () => !controller.chatController.isConversationLoading(target.id),
          'scheduled rerun',
        );
        expect(streamRequestCount, 2);
        expect(
          service.getConversation(target.id)!.truncateIndex,
          current.truncateIndex,
        );
        expect(
          (streamRequests.last['messages'] as List)
              .where((m) => m['role'] == 'user')
              .map((m) => m['content']),
          ['Original question'],
        );
        await controller.debugViewModel.sendScheduledMessage(
          input: ChatInputData(text: 'After clear'),
          conversation: service.getConversation(target.id)!,
          assistant: assistantProvider.currentAssistant!,
        );
        await waitFor(
          () => !controller.chatController.isConversationLoading(target.id),
          'follow-up after clear',
        );
        expect(
          (streamRequests.last['messages'] as List)
              .where((m) => m['role'] == 'user')
              .map((m) => m['content']),
          ['After clear'],
        );
      });
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'scheduled nonstream rerun returns a run while user input is pending',
    (tester) async {
      final controller = await pumpHarness(tester);
      await tester.runAsync(() async {
        final target = await openConversation(controller);
        await controller.sendMessage(ChatInputData(text: 'Original question'));
        await waitFor(
          () => !controller.chatController.isConversationLoading(target.id),
          'original reply',
        );
        final question = (await service.loadMessages(
          target.id,
        )).firstWhere((m) => m.role == 'user');
        var returned = false;
        final run = controller.debugViewModel
            .regenerateScheduledMessage(
              message: question,
              conversation: service.getConversation(target.id)!,
              assistant: assistantProvider.currentAssistant!.copyWith(
                streamOutput: false,
                localToolIds: [AskUserToolNames.askUser],
              ),
              modelOverride: (providerKey: 'SiliconFlow', modelId: 'gpt-4o'),
            )
            .then((result) {
              returned = true;
              return result;
            });
        try {
          await waitFor(
            () => questions.pendingRequests.isNotEmpty,
            'real ask-user tool request',
          );
          await Future<void>.delayed(const Duration(milliseconds: 700));
          expect(returned, isTrue);
          final result = await run;
          expect(result.success, isTrue);
          expect(result.generationRunId, isNotNull);
          expect(
            (await repository.getGenerationRun(
              result.generationRunId!,
            ))!.state.isTerminal,
            isFalse,
          );
          expect(
            questions.pendingRequests.values.single.conversationId,
            target.id,
          );
        } finally {
          await ChatActions.cancelActiveGenerationFor(target.id);
          await run.timeout(const Duration(seconds: 10));
        }
      });
      expect(tester.takeException(), isNull);
    },
  );
}

Map<String, dynamic> _nativeReasoning(String id) => {
  'type': 'reasoning',
  'id': id,
  'summary': [],
  'encrypted_content': 'opaque-$id',
};

Map<String, dynamic> _nativeText(String text) => {
  'type': 'message',
  'id': 'message-$text',
  'role': 'assistant',
  'content': [
    {'type': 'output_text', 'text': text, 'annotations': []},
  ],
};

Future<void> _writeResponses(
  HttpRequest request,
  Map<String, dynamic> body,
  List<Map<String, dynamic>> output,
) async {
  if (body['stream'] == true) {
    request.response.headers.contentType = ContentType('text', 'event-stream');
    void emit(Map<String, dynamic> event) =>
        request.response.write('data: ${jsonEncode(event)}\n\n');
    for (final (index, item) in output.indexed) {
      emit({
        'type': 'response.output_item.added',
        'output_index': index,
        'item': item,
      });
      if (item['type'] == 'message') {
        emit({
          'type': 'response.output_text.delta',
          'output_index': index,
          'delta': (item['content'] as List).first['text'],
        });
      }
      emit({
        'type': 'response.output_item.done',
        'output_index': index,
        'item': item,
      });
    }
    emit({
      'type': 'response.completed',
      'response': {'output': output},
    });
  } else {
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({'output': output}));
  }
  await request.response.close();
}

class _ControllerHarness extends StatefulWidget {
  const _ControllerHarness({
    required this.onCreated,
    this.withComposer = false,
    this.onSend,
  });

  final ValueChanged<HomePageController> onCreated;
  final bool withComposer;
  final Future<ChatInputSubmissionResult> Function(ChatInputData)? onSend;

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
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => Scaffold(
      key: _scaffoldKey,
      body: widget.withComposer
          ? Align(
              alignment: Alignment.bottomCenter,
              child: ChatInputBar(
                key: _inputBarKey,
                controller: _inputController,
                mediaController: _mediaController,
                focusNode: _inputFocus,
                conversationId: _controller.currentConversation?.id,
                onSend: widget.onSend ?? _controller.sendMessage,
              ),
            )
          : null,
    ),
  );
}
