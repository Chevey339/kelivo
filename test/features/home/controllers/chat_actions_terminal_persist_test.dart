import 'package:Kelivo/core/database/generation_run.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/home/controllers/chat_controller.dart';
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

class _ThrowingFinalizeChatService extends ChatService {
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
    if (terminalState == GenerationRunState.completed) {
      throw StateError('persist failed');
    }
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(const {});

  testWidgets('终态写库失败仍走 failed 收尾并通知 onStreamError', (tester) async {
    final service = _ThrowingFinalizeChatService();
    final settings = SettingsProvider(createBusinessTestPreferences());
    final streamErrors = <String>[];
    var assistantFinishedCount = 0;
    late HomeViewModel viewModel;

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
              viewModel = HomeViewModel(
                chatService: service,
                messageBuilderService: messageBuilder,
                messageGenerationService: messageGeneration,
                generationController: generationController,
                streamController: streamController,
                chatController: chatController,
                contextProvider: context,
                getTitleForLocale: (_) => 'title',
              );
              viewModel.debugChatActions.onStreamError = streamErrors.add;
              viewModel.onAssistantMessageFinished = (_) {
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
      viewModel.debugChatActions.debugFinishStreaming(state),
      throwsA(isA<StateError>()),
    );
    expect(state.finishHandled, isTrue);
    expect(state.terminalPersisted, isFalse);
    expect(service.terminalStates, [GenerationRunState.completed]);

    await viewModel.debugChatActions.debugHandleStreamError(
      StateError('persist failed'),
      state,
    );

    expect(state.terminalPersisted, isTrue);
    expect(service.terminalStates, [
      GenerationRunState.completed,
      GenerationRunState.failed,
    ]);
    expect(streamErrors, ['Bad state: persist failed']);
    expect(assistantFinishedCount, 0);
  });
}
