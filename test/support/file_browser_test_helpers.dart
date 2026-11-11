import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

/// Wait for a file-browser refresh that may share a scan started in FakeAsync.
/// Keep pumping that zone while allowing real filesystem I/O to finish;
/// runAsync must not await the whole refresh behind an earlier widget read.
Future<void> waitForFileBrowserOperation<T>(
  WidgetTester tester,
  Future<T> operation,
) async {
  var completed = false;
  Object? failure;
  StackTrace? failureStack;
  unawaited(
    operation.then<void>(
      (_) => completed = true,
      onError: (Object error, StackTrace stack) {
        failure = error;
        failureStack = stack;
        completed = true;
      },
    ),
  );
  for (var i = 0; i < 100; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();
    if (completed) {
      final error = failure;
      if (error != null) Error.throwWithStackTrace(error, failureStack!);
      return;
    }
  }
  fail('The filesystem operation and browser refresh did not complete');
}
