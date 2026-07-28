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

  test('flushAll skips a failing handler and still runs the rest', () async {
    final calls = <String>[];
    AppExitFlush.register(() async => throw StateError('boom'));
    AppExitFlush.register(() async => calls.add('after'));

    await AppExitFlush.flushAll();

    expect(calls, <String>['after']);
  });
}
