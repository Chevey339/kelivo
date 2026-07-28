import "../../../support/business_test_harness.dart";
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/home/controllers/stream_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(const {});

  StreamController buildController() {
    return StreamController(
      chatService: ChatService(),
      onStateChanged: () {},
      getSettingsProvider: () =>
          SettingsProvider(createBusinessTestPreferences()),
      getCurrentConversationId: () => 'conversation-1',
    );
  }

  ChatMessage buildAssistantMessage(
    StreamController controller, {
    String id = 'assistant-1',
    String? reasoningText,
    DateTime? reasoningStartAt,
    DateTime? reasoningFinishedAt,
    bool withSegments = true,
  }) {
    String? segmentsJson;
    if (withSegments) {
      final segment = ReasoningSegmentData()
        ..text = 'segment text'
        ..startAt = DateTime(2026, 1, 1, 12)
        ..finishedAt = DateTime(2026, 1, 1, 12, 0, 5)
        ..expanded = true
        ..toolStartIndex = 2;
      segmentsJson = controller.serializeReasoningSegmentsWithSplits(
        [segment],
        contentSplitOffsets: const [3],
        reasoningCountAtSplit: const [1],
        toolCountAtSplit: const [1],
        reasoningDetails: [
          {'type': 'reasoning.encrypted', 'data': 'sig'},
        ],
      );
    }
    return ChatMessage(
      id: id,
      role: 'assistant',
      content: 'answer',
      conversationId: 'conversation-1',
      reasoningText: reasoningText,
      reasoningStartAt: reasoningStartAt,
      reasoningFinishedAt: reasoningFinishedAt,
      reasoningSegmentsJson: segmentsJson,
    );
  }

  void restore(StreamController controller, ChatMessage message) {
    controller.restoreMessageUiState(
      message,
      getToolEventsFromDb: (id) => [
        {
          'id': 'tool-1',
          'name': 'search',
          'arguments': const {'q': 'kelivo'},
          'content': 'result body',
        },
      ],
      getGeminiThoughtSigFromDb: (id) => 'stored-sig',
    );
  }

  test('restore decodes reasoningSegmentsJson once per message', () {
    final controller = buildController();
    final message = buildAssistantMessage(
      controller,
      reasoningText: 'thinking',
      reasoningStartAt: DateTime(2026, 1, 1, 12),
      reasoningFinishedAt: DateTime(2026, 1, 1, 12, 0, 4),
    );

    restore(controller, message);

    // Segments + content splits + reasoning details now share one decode
    // (previously three).
    expect(controller.reasoningPayloadDecodeCount, 1);
    expect(controller.getReasoningSegments(message.id), hasLength(1));
    expect(controller.getContentSplitData(message.id), isNotNull);
    expect(controller.reasoningDetails[message.id], isNotNull);

    // A repeat restore for the same message performs no further decode.
    restore(controller, message);
    expect(controller.reasoningPayloadDecodeCount, 1);
  });

  test('restore populates the same UI state as the split deserializers', () {
    final controller = buildController();
    final startAt = DateTime(2026, 1, 1, 12);
    final finishedAt = DateTime(2026, 1, 1, 12, 0, 4);
    final message = buildAssistantMessage(
      controller,
      reasoningText: 'thinking',
      reasoningStartAt: startAt,
      reasoningFinishedAt: finishedAt,
    );

    restore(controller, message);

    expect(controller.geminiThoughtSigs[message.id], 'stored-sig');

    final reasoning = controller.getReasoningData(message.id);
    expect(reasoning, isNotNull);
    expect(reasoning!.text, 'thinking');
    expect(reasoning.startAt, startAt);
    expect(reasoning.finishedAt, finishedAt);
    expect(reasoning.expanded, isFalse);

    final segments = controller.getReasoningSegments(message.id)!;
    expect(segments, hasLength(1));
    expect(segments.single.text, 'segment text');
    expect(segments.single.startAt, startAt);
    expect(segments.single.finishedAt, DateTime(2026, 1, 1, 12, 0, 5));
    expect(segments.single.expanded, isTrue);
    expect(segments.single.toolStartIndex, 2);

    final splits = controller.getContentSplitData(message.id)!;
    expect(splits.offsets, [3]);
    expect(splits.reasoningCounts, [1]);
    expect(splits.toolCounts, [1]);

    expect(controller.reasoningDetails[message.id], [
      {'type': 'reasoning.encrypted', 'data': 'sig'},
    ]);

    final parts = controller.getToolParts(message.id)!;
    expect(parts, hasLength(1));
    expect(parts.single.id, 'tool-1');
    expect(parts.single.toolName, 'search');
    expect(parts.single.content, 'result body');
    expect(parts.single.loading, isFalse);
  });

  test('repeat restores skip messages already restored', () {
    final controller = buildController();
    final message = buildAssistantMessage(
      controller,
      reasoningText: 'persisted',
      reasoningStartAt: DateTime(2026, 1, 1, 12),
      reasoningFinishedAt: DateTime(2026, 1, 1, 12, 0, 4),
    );

    restore(controller, message);

    // Simulate live state evolving after the restore (e.g. user expanded the
    // reasoning block while streaming continued).
    final live = ReasoningData()
      ..text = 'live'
      ..expanded = true;
    controller.setReasoningData(message.id, live);

    // A paging pass re-walks the window with a fresh snapshot of the same
    // message; the already-restored message must not be clobbered.
    final resnapshot = buildAssistantMessage(
      controller,
      reasoningText: 'persisted',
      reasoningStartAt: DateTime(2026, 1, 1, 12),
      reasoningFinishedAt: DateTime(2026, 1, 1, 12, 0, 4),
    );
    restore(controller, resnapshot);

    expect(controller.getReasoningData(message.id)!.text, 'live');
    expect(controller.getReasoningData(message.id)!.expanded, isTrue);
  });

  test('clearMessageState allows the message to be restored again', () {
    final controller = buildController();
    final message = buildAssistantMessage(
      controller,
      reasoningText: 'persisted',
      reasoningStartAt: DateTime(2026, 1, 1, 12),
      reasoningFinishedAt: DateTime(2026, 1, 1, 12, 0, 4),
    );

    restore(controller, message);
    expect(controller.reasoningPayloadDecodeCount, 1);

    controller.clearMessageState(message.id);
    expect(controller.getReasoningData(message.id), isNull);

    restore(controller, message);
    expect(controller.reasoningPayloadDecodeCount, 2);
    expect(controller.getReasoningData(message.id)!.text, 'persisted');
  });

  test('clearAllState resets restore tracking', () {
    final controller = buildController();
    final message = buildAssistantMessage(controller);

    restore(controller, message);
    expect(controller.getReasoningSegments(message.id), isNotNull);

    controller.clearAllState();
    expect(controller.getReasoningSegments(message.id), isNull);

    restore(controller, message);
    expect(controller.getReasoningSegments(message.id), isNotNull);
    expect(controller.reasoningPayloadDecodeCount, 2);
  });
}
