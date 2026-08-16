import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk_emit.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk_handler.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk_ids.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'per-round emit ids keep fallback text out of the previous TextPart',
    () async {
      final handler = StreamChunkHandler();
      await for (final chunk in emitDelta(
        ids: StreamChunkIds('round-0'),
        content: 'before',
      )) {
        handler.handle(chunk);
      }
      handler.handle(const ToolCallStart(id: 'call_1', toolName: 'lookup'));
      handler.handle(const ToolCallEnd('call_1'));
      await for (final chunk in emitDelta(
        ids: StreamChunkIds('round-1'),
        content: 'after',
      )) {
        handler.handle(chunk);
      }

      expect(handler.parts.map((part) => part.kind).toList(), [
        'text',
        'tool_call',
        'text',
      ]);
      expect((handler.parts[0] as TextPart).text, 'before');
      expect((handler.parts[2] as TextPart).text, 'after');
    },
  );

  test(
    'reusing an emit sourceId merges later text into the first part',
    () async {
      final handler = StreamChunkHandler();
      await for (final chunk in emitDelta(
        ids: StreamChunkIds('legacy'),
        content: 'before',
      )) {
        handler.handle(chunk);
      }
      handler.handle(const ToolCallStart(id: 'call_1', toolName: 'lookup'));
      handler.handle(const ToolCallEnd('call_1'));
      await for (final chunk in emitDelta(
        ids: StreamChunkIds('legacy'),
        content: 'after',
      )) {
        handler.handle(chunk);
      }

      expect(handler.parts.map((part) => part.kind).toList(), [
        'text',
        'tool_call',
      ]);
      expect((handler.parts[0] as TextPart).text, 'beforeafter');
    },
  );
}
