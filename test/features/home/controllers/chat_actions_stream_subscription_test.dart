import 'dart:async' as async;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:Kelivo/features/home/controllers/chat_actions.dart';

void main() {
  group('ChatActions.listenSequentiallyToStream', () {
    test('正常流按顺序处理 chunk 并调用 done', () async {
      final controller = async.StreamController<int>();
      final done = async.Completer<void>();
      final seen = <int>[];

      final subscription = ChatActions.listenSequentiallyToStream<int>(
        stream: controller.stream,
        onData: (value) async {
          seen.add(value);
        },
        onError: (error, stackTrace) async {
          fail('unexpected stream error: $error');
        },
        onDone: () async {
          done.complete();
        },
      );
      addTearDown(subscription.cancel);

      controller
        ..add(1)
        ..add(2);
      await controller.close();
      await done.future.timeout(const Duration(seconds: 1));

      expect(seen, const [1, 2]);
    });

    test('空流直接调用 done', () async {
      final controller = async.StreamController<int>();
      final done = async.Completer<void>();

      final subscription = ChatActions.listenSequentiallyToStream<int>(
        stream: controller.stream,
        onData: (_) async {
          fail('empty stream should not process data');
        },
        onError: (error, stackTrace) async {
          fail('unexpected stream error: $error');
        },
        onDone: () async {
          done.complete();
        },
      );
      addTearDown(subscription.cancel);

      await controller.close();
      await done.future.timeout(const Duration(seconds: 1));

      expect(done.isCompleted, isTrue);
    });

    test('chunk 处理异步失败时进入 error 收尾且不再调用 done', () async {
      final controller = async.StreamController<int>();
      final errorSeen = async.Completer<Object>();
      var doneCalled = false;

      final subscription = ChatActions.listenSequentiallyToStream<int>(
        stream: controller.stream,
        onData: (value) async {
          if (value == 2) {
            throw StateError('chunk failed');
          }
        },
        onError: (error, stackTrace) async {
          errorSeen.complete(error);
        },
        onDone: () async {
          doneCalled = true;
        },
      );
      addTearDown(subscription.cancel);

      controller
        ..add(1)
        ..add(2)
        ..add(3);
      await controller.close();

      final error = await errorSeen.future.timeout(const Duration(seconds: 1));
      expect(error, isA<StateError>());
      await Future<void>.delayed(Duration.zero);
      expect(doneCalled, isFalse);
    });

    test('done 收尾异步失败时进入 error 收尾', () async {
      final controller = async.StreamController<int>();
      final errorSeen = async.Completer<Object>();

      final subscription = ChatActions.listenSequentiallyToStream<int>(
        stream: controller.stream,
        onData: (_) async {},
        onError: (error, stackTrace) async {
          errorSeen.complete(error);
        },
        onDone: () async {
          throw StateError('done failed');
        },
      );
      addTearDown(subscription.cancel);

      await controller.close();

      final error = await errorSeen.future.timeout(const Duration(seconds: 1));
      expect(error, isA<StateError>());
    });

    test(
      'error handler secondary failure is reported without escaping drain',
      () async {
        final controller = async.StreamController<int>();
        final reported = async.Completer<FlutterErrorDetails>();
        final previousHandler = FlutterError.onError;
        FlutterError.onError = (details) => reported.complete(details);
        addTearDown(() {
          FlutterError.onError = previousHandler;
        });

        final subscription = ChatActions.listenSequentiallyToStream<int>(
          stream: controller.stream,
          onData: (_) async => throw StateError('primary'),
          onError: (_, _) async => throw StateError('secondary'),
          onDone: () async {},
        );
        addTearDown(subscription.cancel);

        controller.add(1);
        await controller.close();
        final details = await reported.future.timeout(
          const Duration(seconds: 1),
        );
        expect(details.exception, isA<StateError>());
        expect(details.exception.toString(), contains('secondary'));
      },
    );

    test('异步 handler 未完成前不会并发处理后续 chunk', () async {
      final controller = async.StreamController<int>();
      final firstStarted = async.Completer<void>();
      final allowFirstToFinish = async.Completer<void>();
      final done = async.Completer<void>();
      final started = <int>[];

      final subscription = ChatActions.listenSequentiallyToStream<int>(
        stream: controller.stream,
        onData: (value) async {
          started.add(value);
          if (value == 1) {
            firstStarted.complete();
            await allowFirstToFinish.future;
          }
        },
        onError: (error, stackTrace) async {
          fail('unexpected stream error: $error');
        },
        onDone: () async {
          done.complete();
        },
      );
      addTearDown(subscription.cancel);

      controller
        ..add(1)
        ..add(2);
      await firstStarted.future.timeout(const Duration(seconds: 1));
      await Future<void>.delayed(Duration.zero);
      expect(started, const [1]);

      allowFirstToFinish.complete();
      await controller.close();
      await done.future.timeout(const Duration(seconds: 1));

      expect(started, const [1, 2]);
    });

    test('异步 handler 未完成时网络订阅保持读取并在本地排队', () async {
      final controller = async.StreamController<int>(sync: true);
      addTearDown(controller.close);
      final firstStarted = async.Completer<void>();
      final allowFirstToFinish = async.Completer<void>();
      final done = async.Completer<void>();
      final seen = <int>[];

      final subscription = ChatActions.listenSequentiallyToStream<int>(
        stream: controller.stream,
        onData: (value) async {
          seen.add(value);
          if (value == 1) {
            firstStarted.complete();
            await allowFirstToFinish.future;
          }
        },
        onError: (error, stackTrace) async {
          fail('unexpected stream error: $error');
        },
        onDone: () async => done.complete(),
      );
      addTearDown(subscription.cancel);

      controller.add(1);
      await firstStarted.future.timeout(const Duration(seconds: 1));
      expect(controller.isPaused, isFalse);
      controller
        ..add(2)
        ..add(3);
      expect(controller.isPaused, isFalse);
      expect(seen, const [1]);

      allowFirstToFinish.complete();
      await controller.close();
      await done.future.timeout(const Duration(seconds: 1));
      expect(seen, const [1, 2, 3]);
    });

    test(
      'cancel waits for in-flight chunk and drops queued late chunks',
      () async {
        final controller = async.StreamController<int>(sync: true);
        final firstStarted = async.Completer<void>();
        final releaseFirst = async.Completer<void>();
        final seen = <int>[];
        var doneCalled = false;

        final subscription = ChatActions.listenSequentiallyToStream<int>(
          stream: controller.stream,
          onData: (value) async {
            seen.add(value);
            if (value == 1) {
              firstStarted.complete();
              await releaseFirst.future;
            }
          },
          onError: (error, stackTrace) async {
            fail('unexpected stream error: $error');
          },
          onDone: () async {
            doneCalled = true;
          },
        );

        controller
          ..add(1)
          ..add(2)
          ..add(3);
        await firstStarted.future.timeout(const Duration(seconds: 1));
        var cancelCompleted = false;
        final cancelled = subscription.cancel().then((_) {
          cancelCompleted = true;
        });
        await Future<void>.delayed(Duration.zero);
        expect(cancelCompleted, isFalse);

        releaseFirst.complete();
        await cancelled.timeout(const Duration(seconds: 1));
        await controller.close();

        expect(seen, const [1]);
        expect(doneCalled, isFalse);
      },
    );

    test(
      'error terminal drops chunks already queued behind the error',
      () async {
        final controller = async.StreamController<int>(sync: true);
        addTearDown(controller.close);
        final firstStarted = async.Completer<void>();
        final releaseFirst = async.Completer<void>();
        final errorSeen = async.Completer<Object>();
        final seen = <int>[];

        final subscription = ChatActions.listenSequentiallyToStream<int>(
          stream: controller.stream,
          onData: (value) async {
            seen.add(value);
            if (value == 1) {
              firstStarted.complete();
              await releaseFirst.future;
            }
          },
          onError: (error, stackTrace) async => errorSeen.complete(error),
          onDone: () async => fail('error stream must not complete normally'),
        );
        addTearDown(subscription.cancel);

        controller.add(1);
        await firstStarted.future.timeout(const Duration(seconds: 1));
        controller
          ..addError(StateError('terminal'))
          ..add(2);
        releaseFirst.complete();

        expect(
          await errorSeen.future.timeout(const Duration(seconds: 1)),
          isA<StateError>(),
        );
        expect(seen, const [1]);
      },
    );
  });
}
