import "../../../support/business_test_harness.dart";
import 'dart:convert';

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/generation/text_generation_result.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';
import 'package:Kelivo/features/home/controllers/stream_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(const {});

  StreamingState buildState(List<MessagePart> parts) {
    final settings = SettingsProvider(createBusinessTestPreferences());
    return StreamingState(
      GenerationContext(
        assistantMessage: ChatMessage(
          id: 'assistant-message',
          role: 'assistant',
          parts: parts,
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
  }

  test('StreamingState seeds partsHandler from the assistant message', () {
    final state = buildState(const [
      TextPart('before'),
      ReasoningPart('plan'),
      ToolCallPart('{"id":"call_1","name":"lookup"}'),
    ]);

    expect(state.fullContentRaw, 'before');
    expect(state.partsHandler.parts.map((part) => part.kind).toList(), [
      'text',
      'reasoning',
      'tool_call',
    ]);
    expect((state.partsHandler.parts[0] as TextPart).text, 'before');
  });

  test('non-stream handleResult keeps seeded parts and joins all text', () {
    final state = buildState(const [TextPart('before'), ReasoningPart('plan')]);
    state.partsHandler.handleResult(
      const TextGenerationResult(parts: [TextPart('after')]),
    );
    state.fullContentRaw = [
      for (final part in state.partsHandler.parts)
        if (part is TextPart) part.text,
    ].join();

    expect(state.fullContentRaw, 'beforeafter');
    expect(
      state.partsHandler.parts.whereType<TextPart>().map((part) => part.text),
      ['before', 'after'],
    );
    expect(
      state.partsHandler.parts.whereType<ReasoningPart>().single.text,
      'plan',
    );
  });

  test('continuation text after a tool answer does not drop prior cards', () {
    final state = buildState([
      const TextPart('before'),
      ToolCallPart(
        jsonEncode(<String, dynamic>{
          'id': 'call_1',
          'name': 'lookup',
          'arguments': <String, dynamic>{'q': 'kelivo'},
        }),
      ),
    ]);
    state.partsHandler.handle(
      const TextDelta(id: 'round-1:text-1', text: 'after'),
    );

    expect(state.partsHandler.parts.map((part) => part.kind).toList(), [
      'text',
      'tool_call',
      'text',
    ]);
    expect((state.partsHandler.parts.first as TextPart).text, 'before');
    expect((state.partsHandler.parts.last as TextPart).text, 'after');
  });
}
