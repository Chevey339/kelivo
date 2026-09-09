import 'dart:async';

import 'package:Kelivo/core/database/generation_run.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/mobile_background_settings.dart';
import 'package:Kelivo/core/services/mobile_background.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/home/controllers/chat_controller.dart';
import 'package:Kelivo/features/home/controllers/chat_actions.dart';
import 'package:Kelivo/features/home/controllers/generation_controller.dart';
import 'package:Kelivo/features/home/controllers/home_view_model.dart';
import 'package:Kelivo/features/home/controllers/stream_controller.dart';
import 'package:Kelivo/features/home/services/message_builder_service.dart';
import 'package:Kelivo/features/home/services/message_generation_service.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/business_test_harness.dart';

class _ThrowingFinalizeChatService extends ChatService {
  _ThrowingFinalizeChatService({this.failCompletion = true});
  final bool failCompletion;
  final terminalStates = <GenerationRunState>[];

  @override
  Future<GenerationRun?> finalizeGenerationRunSilent({
    required ChatMessage message,
    required List<Map<String, dynamic>> toolEvents,
    required String? generationRunId,
    required GenerationRunState? expectedState,
    required int? expectedStateRevision,
    required GenerationRunState terminalState,
    int? checkpointSeq,
    String? errorCode,
  }) async {
    terminalStates.add(terminalState);
    if (failCompletion && terminalState == GenerationRunState.completed) {
      throw StateError('persist failed');
    }
    return null;
  }
}

({ChatActions actions, HomeViewModel viewModel}) _actionsFor(
  BuildContext context,
  ChatService service,
  SettingsProvider settings,
  MobileBackgroundCoordinator background,
) {
  final chatController = ChatController(chatService: service);
  final streamController = StreamController(
    onStateChanged: () {},
    getSettingsProvider: () => settings,
    getCurrentConversationId: () => 'conversation-1',
  );
  final messageBuilder = MessageBuilderService(
    chatService: service,
    contextProvider: context,
  );
  final generationController = GenerationController(
    chatService: service,
    chatController: chatController,
    streamController: streamController,
    messageBuilderService: messageBuilder,
    contextProvider: context,
    onStateChanged: () {},
    getTitleForLocale: (_) => 'title',
  );
  final messageGeneration = MessageGenerationService(
    chatService: service,
    messageBuilderService: messageBuilder,
    generationController: generationController,
    streamController: streamController,
    contextProvider: context,
  );
  final viewModel = HomeViewModel(
    chatService: service,
    messageBuilderService: messageBuilder,
    messageGenerationService: messageGeneration,
    generationController: generationController,
    streamController: streamController,
    chatController: chatController,
    contextProvider: context,
    getTitleForLocale: (_) => 'title',
  );
  final actions = ChatActions(
    chatService: service,
    chatController: chatController,
    streamController: streamController,
    generationController: generationController,
    messageGenerationService: messageGeneration,
    contextProvider: context,
    viewModel: viewModel,
    backgroundCoordinator: background,
  );
  return (actions: actions, viewModel: viewModel);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(const {});

  testWidgets('终态写库失败仍走 failed 收尾并通知 onStreamError', (tester) async {
    final service = _ThrowingFinalizeChatService();
    final settings = SettingsProvider(createBusinessTestPreferences());
    final streamErrors = <String>[];
    var assistantFinishedCount = 0;
    late ChatActions actions;
    const channel = MethodChannel('test.chat_actions.background');
    final notifications = <String?>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => call.method == 'sync' ? <String, dynamic>{} : null,
        );
    final background = MobileBackgroundCoordinator(
      platform: TargetPlatform.iOS,
      channel: channel,
      notificationSender: ({required conversationId, title, body}) async {
        expect(service.terminalStates.last, GenerationRunState.failed);
        notifications.add(body);
      },
    );
    addTearDown(background.dispose);
    await background.configure(
      const MobileBackgroundSettings(notificationsEnabled: true),
      await AppLocalizations.delegate.load(const Locale('en')),
    );
    await background.start(
      id: 'assistant-1',
      conversationId: 'conversation-1',
      title: 'Test',
      cancel: () async {},
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<ChatService>.value(value: service),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              final graph = _actionsFor(context, service, settings, background);
              actions = graph.actions;
              actions.onStreamError = streamErrors.add;
              actions.onAssistantMessageFinished = (_) {
                assistantFinishedCount++;
              };
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    final state = StreamingState(
      GenerationContext(
        assistantMessage: ChatMessage(
          id: 'assistant-1',
          role: 'assistant',
          content: 'partial',
          conversationId: 'conversation-1',
          isStreaming: true,
        ),
        apiMessages: const [],
        userImagePaths: const [],
        allowImagesApiRouting: false,
        providerKey: 'test',
        modelId: 'test-model',
        assistant: null,
        settings: settings,
        config: ProviderConfig(
          id: 'test',
          enabled: true,
          name: 'Test',
          apiKey: '',
          baseUrl: '',
        ),
        toolDefs: const [],
        supportsReasoning: true,
        enableReasoning: true,
        streamOutput: true,
      ),
    );
    state.fullContentRaw = 'partial';

    await expectLater(
      actions.debugFinishStreaming(state),
      throwsA(isA<StateError>()),
    );
    expect(state.finishHandled, isTrue);
    expect(state.terminalPersisted, isFalse);
    expect(service.terminalStates, [GenerationRunState.completed]);
    expect(background.activeTaskIds, {'assistant-1'});
    expect(notifications, isEmpty);

    await actions.debugHandleStreamError(StateError('persist failed'), state);

    expect(state.terminalPersisted, isTrue);
    expect(service.terminalStates, [
      GenerationRunState.completed,
      GenerationRunState.failed,
    ]);
    expect(streamErrors, ['Bad state: persist failed']);
    expect(assistantFinishedCount, 0);
    expect(background.activeTaskIds, isEmpty);
    expect(notifications, ['Generation failed. Open the chat for details.']);
  });

  testWidgets(
    'generation waits for narration handoff through the ViewModel callback',
    (tester) async {
      final service = _ThrowingFinalizeChatService(failCompletion: false);
      final settings = SettingsProvider(createBusinessTestPreferences());
      const channel = MethodChannel('test.chat_actions.handoff');
      final owners = <String>{};
      final terminalOwners = <Set<String>>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        final args = call.arguments;
        if (call.method == 'audioOwner') {
          final map = args as Map;
          if (map['active'] == true) {
            owners.add(map['owner'] as String);
          } else {
            owners.remove(map['owner']);
          }
        } else if (call.method == 'sync' && (args as Map)['terminal'] != null) {
          terminalOwners.add(Set.of(owners));
        }
        return call.method == 'sync' ? <String, dynamic>{} : null;
      });
      final background = MobileBackgroundCoordinator(
        platform: TargetPlatform.iOS,
        channel: channel,
      );
      addTearDown(background.dispose);
      addTearDown(settings.dispose);
      await background.configure(
        const MobileBackgroundSettings(
          iosEnabled: true,
          backgroundSpeechEnabled: true,
        ),
        await AppLocalizations.delegate.load(const Locale('en')),
      );
      await background.start(
        id: 'assistant-1',
        conversationId: 'conversation-1',
        title: 'Test',
        cancel: () async {},
      );
      final preparing = Completer<void>();
      final ready = Completer<void>();
      late ChatActions actions;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SettingsProvider>.value(value: settings),
            ChangeNotifierProvider<ChatService>.value(value: service),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) {
                final graph = _actionsFor(
                  context,
                  service,
                  settings,
                  background,
                );
                actions = graph.actions;
                actions.onAssistantMessageFinished =
                    graph.viewModel.debugChatActions.onAssistantMessageFinished;
                graph.viewModel.onAssistantMessageFinished = (_) async {
                  expect(service.terminalStates, [
                    GenerationRunState.completed,
                  ]);
                  preparing.complete();
                  await ready.future;
                  await background.setAudioOwner('speechBuffering', true);
                };
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      final state = StreamingState(
        GenerationContext(
          assistantMessage: ChatMessage(
            id: 'assistant-1',
            role: 'assistant',
            content: 'reply',
            conversationId: 'conversation-1',
            isStreaming: true,
          ),
          apiMessages: const [],
          userImagePaths: const [],
          allowImagesApiRouting: false,
          providerKey: 'test',
          modelId: 'test-model',
          assistant: null,
          settings: settings,
          config: ProviderConfig(
            id: 'test',
            enabled: true,
            name: 'Test',
            apiKey: '',
            baseUrl: '',
          ),
          toolDefs: const [],
          supportsReasoning: true,
          enableReasoning: true,
          streamOutput: true,
        ),
      )..fullContentRaw = 'reply';
      final finished = actions.debugFinishStreaming(state);
      await preparing.future;
      await tester.pump(const Duration(milliseconds: 40));
      await background.flush();
      expect(background.activeTaskIds, {'assistant-1'});
      expect(terminalOwners, isEmpty);
      ready.complete();
      await finished;
      await background.flush();
      expect(background.activeTaskIds, isEmpty);
      expect(terminalOwners, [
        {'speechBuffering'},
      ]);
      await background.setAudioOwner('speechBuffering', false);
    },
  );
}
