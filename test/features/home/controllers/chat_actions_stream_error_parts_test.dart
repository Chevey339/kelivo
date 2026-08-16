import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk_handler.dart';
import 'package:Kelivo/features/home/controllers/chat_actions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stream error without text keeps reasoning, tool, and image parts', () {
    final handler = StreamChunkHandler();
    handler.handle(const ReasoningStart(id: 'r1'));
    handler.handle(const ReasoningDelta(id: 'r1', text: 'plan'));
    handler.handle(const ReasoningEnd(id: 'r1'));
    handler.handle(const ToolCallStart(id: 'call_1', toolName: 'lookup'));
    handler.handle(const ToolCallEnd('call_1'));
    handler.handle(
      const ImageSnapshot(id: 'img', data: 'https://example.com/gen.png'),
    );

    expect(handler.parts.whereType<TextPart>(), isEmpty);

    final errorParts = ChatActions.assistantPartsForStreamError(
      parts: handler.parts,
      partialContent: '',
      errorText: 'Connection failed',
    );

    expect(
      errorParts.whereType<TextPart>().map((part) => part.text),
      contains('Connection failed'),
    );
    expect(errorParts.whereType<ReasoningPart>().map((part) => part.text), [
      'plan',
    ]);
    expect(
      errorParts.whereType<ToolCallPart>().map((part) => part.payloadJson),
      everyElement(contains('lookup')),
    );
    expect(errorParts.whereType<ImagePart>().map((part) => part.uri), [
      'https://example.com/gen.png',
    ]);
  });
}
