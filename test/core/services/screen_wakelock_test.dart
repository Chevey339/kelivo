import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/screen_wakelock.dart';

void main() {
  tearDown(ScreenWakelock.debugReset);

  test('acquire twice then one release stays held; two releases debounce', () {
    fakeAsync((async) {
      final calls = <bool>[];
      ScreenWakelock.debugReset(platformApply: calls.add);
      ScreenWakelock.setEnabled(true);

      ScreenWakelock.acquire();
      ScreenWakelock.acquire();
      expect(calls, <bool>[true]);
      expect(ScreenWakelock.debugHolders, 2);
      expect(ScreenWakelock.debugHeld, isTrue);

      ScreenWakelock.release();
      expect(calls, <bool>[true]);
      expect(ScreenWakelock.debugHolders, 1);
      expect(ScreenWakelock.debugHeld, isTrue);

      ScreenWakelock.release();
      expect(ScreenWakelock.debugHolders, 0);
      expect(ScreenWakelock.debugHeld, isTrue);
      expect(calls, <bool>[true]);

      async.elapse(const Duration(seconds: 9));
      expect(calls, <bool>[true]);
      expect(ScreenWakelock.debugHeld, isTrue);

      async.elapse(const Duration(seconds: 1));
      expect(calls, <bool>[true, false]);
      expect(ScreenWakelock.debugHeld, isFalse);
    });
  });

  test('acquire within 10s cancels release and does not re-enable', () {
    fakeAsync((async) {
      final calls = <bool>[];
      ScreenWakelock.debugReset(platformApply: calls.add);
      ScreenWakelock.setEnabled(true);

      ScreenWakelock.acquire();
      expect(calls, <bool>[true]);

      ScreenWakelock.release();
      async.elapse(const Duration(seconds: 5));
      expect(calls, <bool>[true]);
      expect(ScreenWakelock.debugHeld, isTrue);

      ScreenWakelock.acquire();
      expect(calls, <bool>[true]);
      expect(ScreenWakelock.debugHolders, 1);
      expect(ScreenWakelock.debugHeld, isTrue);

      async.elapse(const Duration(seconds: 10));
      expect(calls, <bool>[true]);
      expect(ScreenWakelock.debugHeld, isTrue);

      ScreenWakelock.releaseNow();
    });
  });

  test(
    'setEnabled(false) releases immediately; true with holders acquires',
    () {
      final calls = <bool>[];
      ScreenWakelock.debugReset(platformApply: calls.add);

      ScreenWakelock.acquire();
      expect(ScreenWakelock.debugHolders, 1);
      expect(calls, isEmpty);
      expect(ScreenWakelock.debugHeld, isFalse);

      ScreenWakelock.setEnabled(true);
      expect(calls, <bool>[true]);
      expect(ScreenWakelock.debugHeld, isTrue);

      ScreenWakelock.setEnabled(false);
      expect(calls, <bool>[true, false]);
      expect(ScreenWakelock.debugHeld, isFalse);
      expect(ScreenWakelock.debugHolders, 1);

      ScreenWakelock.setEnabled(true);
      expect(calls, <bool>[true, false, true]);
      expect(ScreenWakelock.debugHeld, isTrue);
    },
  );

  test('releaseNow zeros holders, held flag, and pending timer', () {
    fakeAsync((async) {
      final calls = <bool>[];
      ScreenWakelock.debugReset(platformApply: calls.add);
      ScreenWakelock.setEnabled(true);

      ScreenWakelock.acquire();
      ScreenWakelock.acquire();
      ScreenWakelock.release();
      expect(ScreenWakelock.debugHolders, 1);

      ScreenWakelock.releaseNow();
      expect(ScreenWakelock.debugHolders, 0);
      expect(ScreenWakelock.debugHeld, isFalse);
      expect(ScreenWakelock.debugEnabled, isTrue);
      expect(calls, <bool>[true, false]);

      async.elapse(const Duration(seconds: 10));
      expect(calls, <bool>[true, false]);
    });
  });

  test(
    'failed async platform apply rolls back held so the next apply retries',
    () {
      fakeAsync((async) {
        var shouldFail = true;
        final calls = <bool>[];
        ScreenWakelock.debugReset();
        ScreenWakelock.debugPlatformApply = (enable) async {
          calls.add(enable);
          if (shouldFail) {
            throw Exception('platform apply failed');
          }
        };
        ScreenWakelock.setEnabled(true);

        ScreenWakelock.acquire();
        async.flushMicrotasks();
        expect(calls, <bool>[true]);
        expect(ScreenWakelock.debugHeld, isFalse);

        shouldFail = false;
        ScreenWakelock.acquire();
        async.flushMicrotasks();
        expect(calls, <bool>[true, true]);
        expect(ScreenWakelock.debugHeld, isTrue);
        expect(ScreenWakelock.debugHolders, 2);
      });
    },
  );

  test('reassert force-enables even when already held', () {
    final calls = <bool>[];
    ScreenWakelock.debugReset(platformApply: calls.add);
    ScreenWakelock.setEnabled(true);
    ScreenWakelock.acquire();
    expect(calls, <bool>[true]);
    expect(ScreenWakelock.debugHeld, isTrue);

    ScreenWakelock.reassert();
    expect(calls, <bool>[true, true]);
    expect(ScreenWakelock.debugHeld, isTrue);
  });
}
