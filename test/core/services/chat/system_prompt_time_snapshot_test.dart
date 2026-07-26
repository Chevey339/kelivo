import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/services/chat/prompt_transformer.dart';
import 'package:Kelivo/core/services/chat/system_prompt_time_snapshot.dart';

class _ScheduledTimer implements Timer {
  _ScheduledTimer(this.delay, this.callback);

  final Duration delay;
  final void Function() callback;
  bool _isActive = true;

  void fire() {
    if (!_isActive) return;
    _isActive = false;
    callback();
  }

  @override
  void cancel() => _isActive = false;

  @override
  bool get isActive => _isActive;

  @override
  int get tick => _isActive ? 0 : 1;
}

class _TimerHarness {
  final List<_ScheduledTimer> timers = [];

  Timer schedule(Duration delay, void Function() callback) {
    final timer = _ScheduledTimer(delay, callback);
    timers.add(timer);
    return timer;
  }

  _ScheduledTimer get active => timers.lastWhere((timer) => timer.isActive);
}

void main() {
  group('SystemPromptTimeSnapshotService', () {
    test('captures the startup time when initialized', () {
      var now = DateTime(2026, 7, 24, 8);
      final timers = _TimerHarness();
      final service = SystemPromptTimeSnapshotService(
        clock: () => now,
        timerScheduler: timers.schedule,
      );

      now = DateTime(2026, 7, 24, 9, 15);
      service.initialize();

      expect(service.current.localDateTime, DateTime(2026, 7, 24, 9, 15));
      expect(timers.active.delay, const Duration(hours: 2, minutes: 45));
      service.dispose();
    });

    test('keeps startup prompt values stable within the same half-day', () {
      var now = DateTime(2026, 7, 24, 9, 15, 30);
      final timers = _TimerHarness();
      final service = SystemPromptTimeSnapshotService(
        clock: () => now,
        timerScheduler: timers.schedule,
        timezoneName: (_) => 'CST',
      );

      service.initialize();
      final startup = service.current;
      final startupValues = PromptTransformer.buildTimePlaceholders(
        snapshot: startup,
      );
      now = DateTime(2026, 7, 24, 11, 59, 59);
      final repeated = service.current;
      final repeatedValues = PromptTransformer.buildTimePlaceholders(
        snapshot: repeated,
      );

      expect(repeated, same(startup));
      expect(repeatedValues, startupValues);
      expect(repeatedValues, <String, String>{
        '{cur_date}': '2026-07-24',
        '{cur_time}': '09:15',
        '{cur_datetime}': '2026-07-24 09:15',
        '{timezone}': 'CST',
      });
      expect(
        timers.active.delay,
        const Duration(hours: 2, minutes: 44, seconds: 30),
      );
      service.dispose();
    });

    test('refreshes at local noon without restarting the app', () {
      var now = DateTime(2026, 7, 24, 11, 59, 30);
      final timers = _TimerHarness();
      final service = SystemPromptTimeSnapshotService(
        clock: () => now,
        timerScheduler: timers.schedule,
      );

      service.initialize();
      final beforeNoon = service.current;
      expect(timers.active.delay, const Duration(seconds: 30));

      now = DateTime(2026, 7, 24, 12);
      timers.active.fire();
      final afterNoon = service.current;

      expect(afterNoon, isNot(same(beforeNoon)));
      expect(afterNoon.localDateTime, DateTime(2026, 7, 24, 12));
      expect(timers.active.delay, const Duration(hours: 12));
      service.dispose();
    });

    test('refreshes at local midnight without restarting the app', () {
      var now = DateTime(2026, 7, 24, 23, 59, 45);
      final timers = _TimerHarness();
      final service = SystemPromptTimeSnapshotService(
        clock: () => now,
        timerScheduler: timers.schedule,
      );

      service.initialize();
      final beforeMidnight = service.current;
      expect(timers.active.delay, const Duration(seconds: 15));

      now = DateTime(2026, 7, 25);
      timers.active.fire();
      final afterMidnight = service.current;

      expect(afterMidnight, isNot(same(beforeMidnight)));
      expect(afterMidnight.localDateTime, DateTime(2026, 7, 25));
      expect(timers.active.delay, const Duration(hours: 12));
      service.dispose();
    });

    test('a delayed timer refreshes using its actual execution time', () {
      var now = DateTime(2026, 7, 24, 11, 30);
      final timers = _TimerHarness();
      final service = SystemPromptTimeSnapshotService(
        clock: () => now,
        timerScheduler: timers.schedule,
      );

      service.initialize();
      final noonTimer = timers.active;
      now = DateTime(2026, 7, 24, 12, 45);
      noonTimer.fire();

      expect(service.current.localDateTime, DateTime(2026, 7, 24, 12, 45));
      expect(timers.active.delay, const Duration(hours: 11, minutes: 15));
      service.dispose();
    });

    test('the next read catches a missed boundary before building a prompt', () {
      var now = DateTime(2026, 7, 24, 10);
      final timers = _TimerHarness();
      final service = SystemPromptTimeSnapshotService(
        clock: () => now,
        timerScheduler: timers.schedule,
      );

      service.initialize();
      final staleNoonTimer = timers.active;
      now = DateTime(2026, 7, 24, 14, 20);

      final promptValues = PromptTransformer.buildTimePlaceholders(
        snapshot: service.current,
      );

      expect(promptValues['{cur_datetime}'], '2026-07-24 14:20');
      expect(staleNoonTimer.isActive, isFalse);
      expect(timers.active.delay, const Duration(hours: 9, minutes: 40));
      service.dispose();
    });
  });

  test('message-template date and time still use the request time', () {
    final first = PromptTransformer.applyMessageTemplate(
      '{{ date }} {{ time }} {{ message }}',
      role: 'user',
      message: 'hello',
      now: DateTime(2026, 7, 24, 11, 59),
    );
    final second = PromptTransformer.applyMessageTemplate(
      '{{ date }} {{ time }} {{ message }}',
      role: 'user',
      message: 'hello',
      now: DateTime(2026, 7, 24, 12, 1),
    );

    expect(first, '2026-07-24 11:59 hello');
    expect(second, '2026-07-24 12:01 hello');
  });
}
