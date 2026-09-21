import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/message_part.dart';
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
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/business_test_harness.dart';

({ChatActions actions, HomeViewModel viewModel}) _actionsFor(
  BuildContext context,
  ChatService service,
  SettingsProvider settings,
  MobileBackgroundCoordinator background,
  String? Function() currentConversation,
) {
  final chatController = ChatController(chatService: service);
  final streamController = StreamController(
    onStateChanged: () {},
    getSettingsProvider: () => settings,
    getCurrentConversationId: currentConversation,
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

  testWidgets(
    'production reasoning dispatch publishes once per presentation tick',
    (tester) async {
      final service = ChatService();
      final settings = SettingsProvider(createBusinessTestPreferences());
      final background = MobileBackgroundCoordinator(
        platform: TargetPlatform.linux,
      );
      var currentConversation = 'conversation-1';
      late ChatActions actions;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) {
                actions = _actionsFor(
                  context,
                  service,
                  settings,
                  background,
                  () => currentConversation,
                ).actions;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      final state = StreamingState(
        GenerationContext(
          assistantMessage: ChatMessage(
            id: 'assistant',
            role: 'assistant',
            conversationId: 'conversation-1',
            isStreaming: true,
          ),
          apiMessages: const [],
          userImagePaths: const [],
          allowImagesApiRouting: false,
          providerKey: 'test',
          modelId: 'test',
          assistant: null,
          settings: settings,
          config: ProviderConfig(
            id: 'test',
            enabled: true,
            name: 'test',
            apiKey: '',
            baseUrl: '',
          ),
          toolDefs: const [],
          supportsReasoning: true,
          enableReasoning: true,
          streamOutput: true,
        ),
      );
      final controller = actions.streamController;
      addTearDown(controller.dispose);
      addTearDown(background.dispose);
      final notifier = controller.streamingContentNotifier.getNotifier(
        state.messageId,
      );
      var notifications = 0;
      notifier.addListener(() => notifications++);
      for (var i = 0; i < 5; i++) {
        await actions.debugHandleStreamChunk(
          ReasoningDelta(id: 'reasoning', text: '$i'),
          state,
        );
      }
      // ignore: avoid_print
      print(
        'DISPATCH_PROBE reasoning_deltas=5 notifications_before_tick=$notifications',
      );
      expect(notifications, 0);
      await tester.pump(const Duration(milliseconds: 50));
      expect(notifications, 1);
      expect(notifier.value.reasoningText, '01234');
      expect(
        notifier.value.parts!.whereType<ReasoningPart>().single.text,
        '01234',
      );
      currentConversation = 'other';
      final beforeHidden = notifications;
      await actions.debugHandleStreamChunk(
        const ReasoningDelta(id: 'reasoning', text: 'hidden'),
        state,
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(notifications, beforeHidden);
      expect(controller.getReasoningData(state.messageId)!.text, '01234hidden');
      currentConversation = 'conversation-1';
      controller.refreshPresentation();
      await tester.pump(const Duration(milliseconds: 50));
      expect(notifications, beforeHidden + 1);
      expect(notifier.value.reasoningText, '01234hidden');
      expect(
        notifier.value.parts!.whereType<ReasoningPart>().single.text,
        '01234hidden',
      );
    },
  );
}
