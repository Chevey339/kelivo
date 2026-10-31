import 'package:Kelivo/core/services/auth/provider_oauth_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Kimi monthly aggregates retain ratios and detailed five-hour quota',
    () {
      final usage = parseKimiUsage({
        'limits': [
          {
            'window': {
              'duration': 300,
              'timeUnit': 'TIME_UNIT_MINUTE',
              'resetTime': '2026-11-01T12:00:00Z',
            },
            'detail': {
              'limit': '100',
              'used': '100',
              'resetTime': '2026-11-01T11:00:00Z',
            },
          },
        ],
        'usages': {
          'limit_5h': {'used_ratio': 0},
          'limit_month_total': {
            'used_ratio': 0.0795,
            'reset_time': '2026-12-01T00:00:00Z',
          },
          'limit_month_code': {'used_ratio': '0'},
          'over-limit': {'used_ratio': 1.2},
          'negative': {'used_ratio': -1},
          'unknown': {'used_ratio': 'NaN'},
        },
      });
      expect(usage.windows.map((window) => window.id), [
        'limit-0',
        'limit_month_total',
        'limit_month_code',
        'over-limit',
        'negative',
      ]);
      expect(usage.windows.first.usedPercent, 100);
      expect(usage.windows.first.duration, const Duration(hours: 5));
      expect(usage.windows.first.resetsAt, DateTime.utc(2026, 11, 1, 12));
      expect(usage.windows[1].usedPercent, closeTo(7.95, 0.00001));
      expect(usage.windows[1].resetsAt, DateTime.utc(2026, 12, 1));
      expect(usage.windows[2].usedPercent, 0);
      expect(usage.windows[3].usedPercent, 100);
      expect(usage.windows[4].usedPercent, 0);
    },
  );

  test(
    'Codex credit-only seats expose precise spend caps and explicit verdicts',
    () {
      for (final reached in [true, false, null]) {
        final usage = parseChatGptUsage({
          'plan_type': 'business',
          'spend_control': {
            if (reached != null) 'reached': reached,
            'individual_limit': {
              'used': '99.75',
              'limit': '100',
              'remaining': '0.25',
              'used_percent': 100,
              'reset_at': 1800000000,
            },
          },
        });
        expect(usage.hasData, isTrue);
        expect(usage.plan, 'business');
        final cap = usage.windows.single;
        expect(cap.id, 'spend-cap');
        expect(cap.unit, 'credits');
        expect(cap.used, 99.75);
        expect(cap.limit, 100);
        expect(cap.remaining, 0.25);
        expect(cap.usedPercent, 99.75);
        expect(
          cap.resetsAt,
          DateTime.fromMillisecondsSinceEpoch(1800000000000),
        );
        expect(usage.allowed, reached == null ? isNull : !reached);
        expect(usage.limitReached, reached);
      }
    },
  );

  test(
    'Codex keeps absent spend counters unknown and supports relative resets',
    () {
      expect(
        parseChatGptUsage({
          'spend_control': {'individual_limit': <String, dynamic>{}},
        }).hasData,
        isFalse,
      );
      for (final remaining in [0, 3]) {
        final usage = parseChatGptUsage({
          'spend_control': {
            'individual_limit': {
              'remaining': remaining,
              'reset_after_seconds': 60,
            },
          },
        });
        final cap = usage.windows.single;
        expect(cap.used, isNull);
        expect(cap.limit, isNull);
        expect(cap.remaining, remaining);
        expect(cap.usedPercent, remaining == 0 ? 100 : isNull);
        expect(
          cap.resetsAt!.difference(usage.fetchedAt),
          const Duration(minutes: 1),
        );
        expect(usage.allowed, isNull);
      }
    },
  );

  test(
    'Codex credits fund only plan overage while their spend cap permits it',
    () {
      for (final (remaining, reached, expectedAllowed) in [
        (3, null, true),
        (0, null, false),
        (0, false, true),
        (3, true, false),
      ]) {
        final usage = parseChatGptUsage({
          'rate_limit': {'allowed': false, 'limit_reached': true},
          'credits': {'has_credits': true},
          'spend_control': {
            if (reached != null) 'reached': reached,
            'individual_limit': {'remaining': remaining},
          },
        });
        expect(usage.allowed, expectedAllowed);
        expect(usage.limitReached, !expectedAllowed);
      }
      final planAvailable = parseChatGptUsage({
        'rate_limit': {'allowed': true, 'limit_reached': false},
        'spend_control': {
          'reached': true,
          'individual_limit': {'remaining': 0},
        },
      });
      expect(planAvailable.allowed, isTrue);
      expect(planAvailable.limitReached, isFalse);
    },
  );

  Map<String, dynamic> weekly({Object? percent, bool expired = false}) {
    final end = DateTime.now().toUtc().add(Duration(days: expired ? -1 : 7));
    return {
      'config': {
        'isUnifiedBillingUser': true,
        if (percent != null) 'creditUsagePercent': percent,
        'currentPeriod': {
          'type': 'WEEKLY',
          'start': end.subtract(const Duration(days: 7)).toIso8601String(),
          'end': end.toIso8601String(),
        },
        'onDemandCap': {'val': 50},
        'onDemandUsed': {'val': 20},
      },
    };
  }

  test(
    'Grok conflicting inferred weekly and spent monthly quota stays advisory',
    () {
      final monthly = {
        'config': {
          'monthlyLimit': {'val': 100},
          'used': {'val': 120},
        },
      };
      final usage = parseGrokUsage(weekly(), monthlyData: monthly);
      expect(usage.windows.single.id, 'monthly');
      expect(usage.windows.single.used, 120);
      expect(usage.windows.single.advisory, isTrue);
      expect(usage.allowed, isNull);
      expect(usage.limitReached, isNull);
      for (final data in [weekly(expired: true), weekly(percent: 'invalid')]) {
        final depleted = parseGrokUsage(data, monthlyData: monthly);
        expect(depleted.windows.single.advisory, isFalse);
        expect(depleted.allowed, isFalse);
      }
    },
  );

  test(
    'Grok merges explicit quotas and deduplicates usable on-demand headroom',
    () {
      final usage = parseGrokUsage(
        weekly(percent: 100),
        monthlyData: {
          'config': {
            'monthlyLimit': {'val': 100},
            'used': {'val': 100},
            'onDemandCap': {'val': 50},
            'onDemandUsed': {'val': 20},
          },
        },
      );
      expect(usage.windows.map((window) => window.id), [
        'weekly',
        'on-demand',
        'monthly',
      ]);
      expect(usage.allowed, isTrue);
      expect(usage.limitReached, isFalse);
      expect(usage.windows.every((window) => !window.advisory), isTrue);
      final depleted = parseGrokUsage({
        'config': {
          'monthlyLimit': {'val': 100},
          'used': {'val': 100},
          'onDemandCap': {'val': 50},
          'onDemandUsed': {'val': 50},
        },
      });
      expect(depleted.allowed, isFalse);
      expect(depleted.limitReached, isTrue);
    },
  );
}
