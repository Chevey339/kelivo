import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/memory/memory_prompts.dart';

void main() {
  group('formatCurrentTimeTag (§9.1)', () {
    test(
      'formats across weekdays, year boundary, and single-digit month/day',
      () {
        // 2026-08-03 is a Monday in the Gregorian calendar.
        final monday = DateTime(2026, 8, 3, 14, 3, 22);
        expect(monday.weekday, DateTime.monday);
        expect(
          MemoryPrompts.formatCurrentTimeTag(monday),
          '<current_time>Mon 2026-08-03 14:03:22</current_time>',
        );

        final samples = <DateTime, String>{
          DateTime(2026, 8, 3, 0, 0, 0): 'Mon',
          DateTime(2026, 8, 4, 0, 0, 0): 'Tue',
          DateTime(2026, 8, 5, 0, 0, 0): 'Wed',
          DateTime(2026, 8, 6, 0, 0, 0): 'Thu',
          DateTime(2026, 8, 7, 0, 0, 0): 'Fri',
          DateTime(2026, 8, 8, 0, 0, 0): 'Sat',
          DateTime(2026, 8, 9, 0, 0, 0): 'Sun',
        };
        for (final entry in samples.entries) {
          final formatted = MemoryPrompts.formatCurrentTimeTag(entry.key);
          expect(formatted, contains('<current_time>${entry.value} '));
        }

        // Year boundary uses a four-digit year.
        expect(
          MemoryPrompts.formatCurrentTimeTag(
            DateTime(2025, 12, 31, 23, 59, 59),
          ),
          '<current_time>Wed 2025-12-31 23:59:59</current_time>',
        );
        expect(
          MemoryPrompts.formatCurrentTimeTag(DateTime(2026, 1, 1, 0, 0, 1)),
          '<current_time>Thu 2026-01-01 00:00:01</current_time>',
        );

        // Single-digit month and day are zero-padded.
        expect(
          MemoryPrompts.formatCurrentTimeTag(DateTime(2026, 3, 5, 9, 8, 7)),
          '<current_time>Thu 2026-03-05 09:08:07</current_time>',
        );
      },
    );
  });

  group('detectTimeVariablesInSystemPrompt (§9.3)', () {
    test('detects the three time variables; ignores {timezone}', () {
      expect(
        MemoryPrompts.detectTimeVariablesInSystemPrompt('Today is {cur_date}.'),
        ['{cur_date}'],
      );
      expect(
        MemoryPrompts.detectTimeVariablesInSystemPrompt('Clock: {cur_time}'),
        ['{cur_time}'],
      );
      expect(
        MemoryPrompts.detectTimeVariablesInSystemPrompt('Now {cur_datetime}'),
        ['{cur_datetime}'],
      );
      expect(
        MemoryPrompts.detectTimeVariablesInSystemPrompt(
          'TZ={timezone} locale={locale}',
        ),
        isEmpty,
      );
      // Fixed order: cur_date, cur_time, cur_datetime; {timezone} ignored.
      expect(
        MemoryPrompts.detectTimeVariablesInSystemPrompt(
          '{cur_datetime} {cur_time} {cur_date} {timezone}',
        ),
        ['{cur_date}', '{cur_time}', '{cur_datetime}'],
      );
    });
  });
}
