import 'dart:async';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/app_exit_flush.dart';

void main() {
  tearDown(AppExitFlush.debugReset);

  test('flushAll invokes every registered handler in order', () async {
    final calls = <String>[];
    AppExitFlush.register(() async => calls.add('first'));
    AppExitFlush.register(() async => calls.add('second'));

    await AppExitFlush.flushAll();

    expect(calls, <String>['first', 'second']);
  });

  test('unregister removes a handler', () async {
    final calls = <String>[];
    Future<void> gone() async => calls.add('gone');
    AppExitFlush.register(gone);
    AppExitFlush.unregister(gone);

    await AppExitFlush.flushAll();
    expect(calls, isEmpty);
  });

  test('flushAll skips a failing handler and still runs the rest', () async {
    final calls = <String>[];
    AppExitFlush.register(() async => throw StateError('boom'));
    AppExitFlush.register(() async => calls.add('after'));

    await AppExitFlush.flushAll();

    expect(calls, <String>['after']);
  });

  test('exit stops producers and drains writes before closing once', () async {
    final calls = <String>[];
    final write = Completer<void>();
    AppExitFlush.configureShutdown(
      prepare: () async => calls.add('stop'),
      close: () async => calls.add('close'),
    );
    AppExitFlush.register(() async {
      calls.add('write');
      await write.future;
      calls.add('written');
    });

    final trayExit = AppExitFlush.shutdown();
    final systemExit = AppExitFlush.shutdown();
    expect(AppExitFlush.isExiting, isTrue);
    expect(systemExit, same(trayExit));
    await pumpEventQueue();
    expect(calls, ['stop', 'write']);

    write.complete();
    await Future.wait([trayExit, systemExit, AppExitFlush.flushAll()]);
    await AppExitFlush.shutdown();
    expect(calls, ['stop', 'write', 'written', 'close']);
  });

  test('ordinary flush leaves the database open for continued use', () async {
    var closed = false;
    AppExitFlush.configureShutdown(
      prepare: () async {},
      close: () async => closed = true,
    );
    await AppExitFlush.flushAll();
    expect(AppExitFlush.isExiting, isFalse);
    expect(closed, isFalse);
  });

  test('deadline never closes underneath an unfinished flush', () async {
    final write = Completer<void>();
    var closeCount = 0;
    AppExitFlush.register(() => write.future);
    AppExitFlush.configureShutdown(
      prepare: () async {},
      close: () async => closeCount++,
    );

    await AppExitFlush.shutdown(timeout: Duration.zero);
    await AppExitFlush.shutdown();
    expect(closeCount, 0);
    write.complete();
    await pumpEventQueue();
    expect(closeCount, 1);
  });

  test('a failed flush handler still permits database cleanup', () async {
    var closed = false;
    AppExitFlush.register(() async => throw StateError('write failed'));
    AppExitFlush.configureShutdown(
      prepare: () async {},
      close: () async => closed = true,
    );
    await AppExitFlush.shutdown();
    expect(closed, isTrue);
  });

  test('a failed preparation still flushes and closes the database', () async {
    final calls = <String>[];
    AppExitFlush.configureShutdown(
      prepare: () async => throw StateError('terminal checkpoint failed'),
      close: () async => calls.add('close'),
    );
    AppExitFlush.register(() async => calls.add('flush'));
    await AppExitFlush.shutdown();
    expect(calls, ['flush', 'close']);
  });
}
