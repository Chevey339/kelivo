// Headless CPU replay, not a frame-rate or real-device benchmark.
// flutter test --no-pub test/perf/long_tool_session_bench.dart
import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/models/message_part_snapshot.dart';
import 'package:Kelivo/core/models/tool_event_snapshot.dart';
import 'package:Kelivo/features/chat/widgets/incremental_timeline_projection.dart';
import 'package:Kelivo/features/chat/widgets/timeline_projection.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, int> percentiles(List<int> samples) {
  samples.sort();
  int percentile(double value) =>
      samples[((samples.length - 1) * value).round()];
  return {
    'p50_us': percentile(.5),
    'p95_us': percentile(.95),
    'p99_us': percentile(.99),
  };
}

void main() {
  test('replay 10/100/1000/5000 completed tools with growing text', () async {
    for (final count in [10, 100, 1000, 5000]) {
      final directory = await Directory.systemTemp.createTemp(
        'kelivo_tool_replay_',
      );
      final repository = ChatDatabaseRepository.open(
        file: File('${directory.path}/chat.sqlite'),
      );
      try {
        await repository.ensureReady();
        final events = ToolEventSnapshot(
          List.generate(
            count,
            (i) => {
              'id': 't$i',
              'name': 'shell',
              'arguments': {'command': 'echo done'},
              'content': 'done',
            },
          ),
        );
        final parts = <MessagePart>[
          for (final event in events) ToolCallPart(jsonEncode(event)),
          const TextPart('tail'),
        ];
        final builder = MessagePartSnapshotBuilder(arrivalOrdered: true);
        var snapshot = builder.update(parts);
        final projector = IncrementalTimelineProjection();
        projector.project(
          parts: snapshot,
          liveTools: const [],
          reasoning: const [],
        );
        final message = ChatMessage(
          id: 'message',
          role: 'assistant',
          conversationId: 'conversation',
          parts: snapshot,
          isStreaming: true,
        );
        await repository.putMigrationBatch(
          conversations: [
            Conversation(
              id: 'conversation',
              title: 'Replay',
              messageIds: const ['message'],
            ),
          ],
          messages: [(message: message, messageOrder: 0)],
          toolEventsByMessageId: const {},
          geminiSignaturesByMessageId: const {},
        );
        await repository.updateStreamingCheckpoint(message, events);
        final projectedBefore = projector.projectedPartCount;
        final incremental = <int>[], full = <int>[], checkpoints = <int>[];
        for (var tick = 0; tick < 30; tick++) {
          parts[count] = TextPart('tail ${'output ' * (tick + 1)}');
          snapshot = builder.update(parts, changed: {count});
          final timer = Stopwatch()..start();
          projector.project(
            parts: snapshot,
            liveTools: const [],
            reasoning: const [],
          );
          incremental.add(timer.elapsedMicroseconds);
          timer.reset();
          projectAssistantTimeline(
            parts: snapshot,
            liveTools: const [],
            reasoningSegments: const [],
            visualContent: (parts.last as TextPart).text,
            partsArrivalOrdered: true,
            parseInlineThinking: false,
          );
          full.add(timer.elapsedMicroseconds);
          timer.reset();
          await repository.updateStreamingCheckpoint(
            message.copyWith(parts: snapshot),
            events,
          );
          checkpoints.add(timer.elapsedMicroseconds);
          timer.stop();
        }
        // Printed timings are descriptive; correctness is covered by *_test.dart.
        // ignore: avoid_print
        print(
          jsonEncode({
            'tools': count,
            'updates': 30,
            'incremental_projection': percentiles(incremental),
            'full_projection_reference': percentiles(full),
            'checkpoint_transaction': percentiles(checkpoints),
            'parts_reprojected': projector.projectedPartCount - projectedBefore,
          }),
        );
      } finally {
        await repository.close();
        await directory.delete(recursive: true);
      }
    }
  });
}
