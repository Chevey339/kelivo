import 'package:Kelivo/core/models/token_usage.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk_emit.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk_handler.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk_ids.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'fallback counts are marked estimates, reported zero remains actual',
    () async {
      final estimated = await emitDone(
        ids: StreamChunkIds('estimate'),
        totalTokens: 42,
      ).toList();
      expect(estimated.whereType<Usage>().single.estimated, isTrue);
      final reported = await emitDone(
        ids: StreamChunkIds('reported'),
        usage: const TokenUsage(promptTokens: 0, completionTokens: 0),
        totalTokens: 42,
      ).toList();
      expect(reported.whereType<Usage>().single.estimated, isFalse);
      expect(reported.whereType<Usage>().single.usage.totalTokens, 0);
    },
  );

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
    'reusing emitImages ids appends a second ImagePart on the same handler',
    () async {
      final handler = StreamChunkHandler();
      final ids = StreamChunkIds('images');
      await for (final chunk in emitImages([
        (uri: 'https://img.example/a.png', mimeType: 'image/png'),
      ], ids: ids)) {
        handler.handle(chunk);
      }
      await for (final chunk in emitImages([
        (uri: 'https://img.example/b.png', mimeType: 'image/png'),
      ], ids: ids)) {
        handler.handle(chunk);
      }

      final images = handler.parts.whereType<ImagePart>().toList();
      expect(images, hasLength(2));
      expect(images[0].uri, 'https://img.example/a.png');
      expect(images[1].uri, 'https://img.example/b.png');
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
