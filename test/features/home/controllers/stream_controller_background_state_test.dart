import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';
import 'package:Kelivo/features/home/controllers/stream_controller.dart';
import 'package:Kelivo/features/chat/widgets/timeline_projection.dart';
import '../../../support/business_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final startsInBackground in [false, true]) {
    test(
      'background tool result refreshes the timeline (background start=$startsInBackground)',
      () async {
        var currentConversationId = 'conversation-1';
        final settings = SettingsProvider(createBusinessTestPreferences());
        final controller = StreamController(
          onStateChanged: () {},
          getSettingsProvider: () => settings,
          getCurrentConversationId: () => currentConversationId,
        );
        addTearDown(controller.dispose);
        final message = ChatMessage(
          id: 'assistant-1',
          role: 'assistant',
          content: '',
          conversationId: currentConversationId,
          isStreaming: true,
        );
        final state = StreamingState(
          GenerationContext(
            assistantMessage: message,
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
        var events = <Map<String, dynamic>>[];
        controller.markStreamingStarted(message.id);
        controller.restoreMessageUiState(
          message,
          getToolEventsFromDb: (_) => events,
        );
        if (startsInBackground) currentConversationId = 'new-draft';
        const start = ToolCallStart(id: 'tool-1', toolName: 'search_web');
        state.partsHandler.handle(start);
        await controller.handleToolCallsChunk(
          start,
          state,
          updateReasoningSegmentsInDb: (_, _) async {},
          getToolEventsFromDb: (_) => events,
          setToolEventsInDb: (_, next) async {
            events = next;
          },
        );
        expect(controller.toolParts[message.id]!.single.loading, isTrue);

        currentConversationId = 'new-draft';
        controller.clearAllState(keepMessageIds: {message.id});
        const result = ToolCallResult(id: 'tool-1', output: 'search result');
        state.partsHandler.handle(result);
        await controller.handleToolResultsChunk(
          result,
          state,
          upsertToolEventInDb:
              (
                _, {
                required id,
                required name,
                required arguments,
                content,
                metadata,
              }) async {
                events = [
                  {
                    'id': id,
                    'name': name,
                    'arguments': arguments,
                    'content': content,
                  },
                ];
              },
        );
        final finished = message.copyWith(
          parts: state.partsHandler.parts,
          isStreaming: false,
        );
        controller.markStreamingEnded(message.id);
        currentConversationId = message.conversationId;
        controller.restoreMessageUiState(
          finished,
          getToolEventsFromDb: (_) => events,
        );
        final projection = projectAssistantTimeline(
          parts: finished.parts,
          liveTools: [
            for (final part in controller.toolParts[message.id] ?? [])
              TimelineToolRef(
                providerId: part.id,
                fallbackOrdinal: 0,
                toolName: part.toolName,
                arguments: part.arguments,
                content: part.content,
                loading: part.loading,
              ),
          ],
          reasoningSegments: const [],
          visualContent: '',
        );
        final projected = projection.blocks
            .expand((b) => b.steps)
            .where((s) => s.isTool)
            .single
            .tool!;
        expect(projected.loading, isFalse);
        expect(projected.content, 'search result');
      },
    );
  }
}
