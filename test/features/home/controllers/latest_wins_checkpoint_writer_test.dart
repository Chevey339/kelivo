import 'dart:async';

import 'package:Kelivo/features/home/controllers/chat_actions.dart';
import 'package:Kelivo/features/home/controllers/latest_wins_checkpoint_writer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LatestWinsCheckpointWriter', () {
    test('写入中只保留最新 checkpoint', () async {
      final firstStarted = Completer<void>();
      final releaseFirst = Completer<void>();
      final writes = <int>[];
      final writer = LatestWinsCheckpointWriter<int>(
        minimumInterval: Duration.zero,
        write: (value) async {
          writes.add(value);
          if (value == 1) {
            firstStarted.complete();
            await releaseFirst.future;
          }
        },
      );

      writer.add(1);
      await firstStarted.future;
      writer
        ..add(2)
        ..add(3);

      releaseFirst.complete();
      await writer.barrier();

      expect(writes, const [1, 3]);
    });

    test('相邻 checkpoint 起始时间至少间隔 250ms', () async {
      var now = DateTime(2026);
      final delays = <Duration>[];
      final firstStarted = Completer<void>();
      final releaseFirst = Completer<void>();
      final writes = <int>[];
      final writer = LatestWinsCheckpointWriter<int>(
        now: () => now,
        delay: (duration) async {
          delays.add(duration);
          now = now.add(duration);
        },
        write: (value) async {
          writes.add(value);
          if (value == 1) {
            firstStarted.complete();
            await releaseFirst.future;
          }
        },
      );

      writer.add(1);
      await firstStarted.future;
      writer.add(2);
      releaseFirst.complete();
      await writer.barrier();

      expect(writes, const [1, 2]);
      expect(delays, const [Duration(milliseconds: 250)]);
    });

    test('final 等待在途写并丢弃已被终态覆盖的 pending snapshot', () async {
      final firstStarted = Completer<void>();
      final releaseFirst = Completer<void>();
      final events = <String>[];
      final writer = LatestWinsCheckpointWriter<int>(
        minimumInterval: Duration.zero,
        write: (value) async {
          events.add('checkpoint:$value');
          if (value == 1) {
            firstStarted.complete();
            await releaseFirst.future;
          }
        },
      );

      writer.add(1);
      await firstStarted.future;
      writer.add(2);
      final finalized = writer.finalize(() async {
        events.add('final');
        return 7;
      });

      await Future<void>.delayed(Duration.zero);
      expect(events, const ['checkpoint:1']);
      releaseFirst.complete();

      expect(await finalized, 7);
      expect(events, const ['checkpoint:1', 'final']);
      expect(() => writer.add(3), throwsStateError);
    });

    test('checkpoint 失败可观察且成功 final 可恢复', () async {
      final errors = <Object>[];
      final writer = LatestWinsCheckpointWriter<int>(
        minimumInterval: Duration.zero,
        write: (_) async => throw StateError('write failed'),
        onError: (error, _) => errors.add(error),
      );
      var finalCalled = false;

      writer.add(1);

      await writer.finalize(() async {
        finalCalled = true;
      });

      expect(finalCalled, isTrue);
      expect(errors, hasLength(1));
      expect(errors.single, isA<StateError>());
    });

    test('没有 checkpoint 时 final 立即执行', () async {
      final writer = LatestWinsCheckpointWriter<int>(
        write: (_) async => fail('no checkpoint expected'),
      );

      final result = await writer.finalize(() async => 'done');

      expect(result, 'done');
    });

    test(
      '100 token/s and 1 MiB burst never waits for checkpoint I/O',
      () async {
        final firstWriteStarted = Completer<void>();
        final releaseFirstWrite = Completer<void>();
        final allChunksConsumed = Completer<void>();
        final streamDone = Completer<void>();
        final writes = <int>[];
        final writer = LatestWinsCheckpointWriter<int>(
          minimumInterval: Duration.zero,
          write: (bytes) async {
            writes.add(bytes);
            if (writes.length == 1) {
              firstWriteStarted.complete();
              await releaseFirstWrite.future;
            }
          },
        );
        final controller = StreamController<String>(sync: true);
        const chunkBytes = 1024;
        const chunkCount = 1024;
        var consumed = 0;
        final subscription = ChatActions.listenSequentiallyToStream<String>(
          stream: controller.stream,
          onData: (chunk) async {
            consumed += chunk.length;
            writer.add(consumed);
            if (consumed == chunkBytes * chunkCount) {
              allChunksConsumed.complete();
            }
          },
          onError: (error, stackTrace) async => fail('$error'),
          onDone: () async {
            await writer.finalize(() async => writes.add(consumed));
            streamDone.complete();
          },
        );
        addTearDown(subscription.cancel);

        final chunk = 'x' * chunkBytes;
        for (var index = 0; index < chunkCount; index++) {
          controller.add(chunk);
        }
        final closing = controller.close();

        await firstWriteStarted.future.timeout(const Duration(seconds: 1));
        await allChunksConsumed.future.timeout(const Duration(seconds: 1));
        expect(controller.isPaused, isFalse);
        expect(consumed, 1 << 20);
        expect(writes, hasLength(1));
        expect(streamDone.isCompleted, isFalse);

        releaseFirstWrite.complete();
        await streamDone.future.timeout(const Duration(seconds: 1));
        await closing;
        expect(writes, hasLength(2));
        expect(writes.last, 1 << 20);
      },
    );
  });
}
