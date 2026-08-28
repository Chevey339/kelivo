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

/// Fails every terminal write, which is what makes the cleanup inside the
/// send-failure handler throw.
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
    throw StateError('cleanup write failed');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(const {});

  testWidgets('后台生成失败时收尾写库再失败，原始错误仍然送到 UI', (tester) async {
    final service = _ThrowingFinalizeChatService();
    final settings = SettingsProvider(createBusinessTestPreferences());
    final streamErrors = <String>[];
    final clearedIndicatorIds = <String?>[];
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
              viewModel.debugChatActions.onFileProcessingFinished =
                  clearedIndicatorIds.add;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    final assistantMessage = ChatMessage(
      id: 'assistant-1',
      role: 'assistant',
      content: '',
      conversationId: 'conversation-1',
      isStreaming: true,
    );

    // Must complete rather than throw: nobody awaits the send generation
    // future, so an escaping error would become an unhandled async error.
    await viewModel.debugChatActions.handleSendGenerationFailure(
      error: StateError('generation failed'),
      conversationId: 'conversation-1',
      assistantMessage: assistantMessage,
    );

    expect(service.terminalStates, [GenerationRunState.failed]);
    expect(streamErrors, ['Bad state: generation failed']);
    // The indicator is released for this message only, never globally.
    expect(clearedIndicatorIds, ['assistant-1']);
  });
}
