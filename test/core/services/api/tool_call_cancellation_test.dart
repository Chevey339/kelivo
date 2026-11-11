import 'dart:async';

import 'package:Kelivo/core/services/api/tool_call_cancellation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'completed tools unregister while active and late tools still cancel',
    () async {
      final cancelled = Completer<void>();
      var stopped = false;
      final token = ToolCallCancellation(
        isCancelled: () => stopped,
        cancelled: cancelled.future,
      );
      var calls = 0;
      for (var i = 0; i < 5000; i++) {
        final unregister = token.onCancel(() => calls++);
        unregister();
        unregister();
      }
      expect(token.listenerCount, 0);
      token.onCancel(() => calls++);
      expect(token.listenerCount, 1);
      stopped = true;
      cancelled.complete();
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);
      expect(token.listenerCount, 0);
      token.onCancel(() => calls++);
      expect(calls, 2);
      expect(token.listenerCount, 0);
    },
  );
}
