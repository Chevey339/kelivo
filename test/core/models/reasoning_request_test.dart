import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/model_spec.dart';
import 'package:Kelivo/core/models/reasoning_request.dart';

import '../../support/legacy_reasoning.dart';

void main() {
  group('ReasoningRequest', () {
    test('constants and copyWith', () {
      expect(ReasoningRequest.auto.level, ReasoningLevel.auto);
      expect(ReasoningRequest.auto.budgetTokens, isNull);
      expect(ReasoningRequest.off.level, ReasoningLevel.off);
      expect(
        const ReasoningRequest(
          ReasoningLevel.high,
        ).copyWith(level: ReasoningLevel.max, budgetTokens: 128000),
        const ReasoningRequest(ReasoningLevel.max, budgetTokens: 128000),
      );
    });

    test('JSON round-trip keeps level name and budgetTokens', () {
      for (final level in ReasoningLevel.values) {
        final original = ReasoningRequest(
          level,
          budgetTokens: level == ReasoningLevel.off ? null : 4096,
        );
        final restored = ReasoningRequest.fromJson(original.toJson());
        expect(restored, original, reason: level.name);
        expect(original.toJson()['level'], level.name);
      }
    });

    test('fromJson falls back to auto for unknown or missing level', () {
      expect(ReasoningRequest.fromJson(const {}), ReasoningRequest.auto);
      expect(
        ReasoningRequest.fromJson(const {
          'level': 'unknown',
          'budgetTokens': 8,
        }),
        const ReasoningRequest(ReasoningLevel.auto, budgetTokens: 8),
      );
      expect(
        ReasoningRequest.fromJson(const {
          'level': 'low',
          'budgetTokens': '1024',
        }),
        const ReasoningRequest(ReasoningLevel.low, budgetTokens: 1024),
      );
    });
  });

  group('legacyBudget', () {
    test('reproduces the deleted P1 integer mapping', () {
      expect(legacyBudget(null), ReasoningRequest.auto);
      expect(legacyBudget(-1), ReasoningRequest.auto);
      expect(legacyBudget(0), ReasoningRequest.off);
      expect(legacyBudget(1023), ReasoningRequest.off);
      expect(
        legacyBudget(1024),
        const ReasoningRequest(ReasoningLevel.low, budgetTokens: 1024),
      );
      expect(
        legacyBudget(2000),
        const ReasoningRequest(ReasoningLevel.low, budgetTokens: 2000),
      );
      expect(
        legacyBudget(2001),
        const ReasoningRequest(ReasoningLevel.medium, budgetTokens: 2001),
      );
      expect(
        legacyBudget(20000),
        const ReasoningRequest(ReasoningLevel.medium, budgetTokens: 20000),
      );
      expect(
        legacyBudget(20001),
        const ReasoningRequest(ReasoningLevel.high, budgetTokens: 20001),
      );
      expect(
        legacyBudget(32000),
        const ReasoningRequest(ReasoningLevel.high, budgetTokens: 32000),
      );
      expect(
        legacyBudget(32001),
        const ReasoningRequest(ReasoningLevel.xhigh, budgetTokens: 32001),
      );
      expect(
        legacyBudget(64000),
        const ReasoningRequest(ReasoningLevel.xhigh, budgetTokens: 64000),
      );
      expect(
        legacyBudget(64001),
        const ReasoningRequest(ReasoningLevel.max, budgetTokens: 64001),
      );
    });
  });
}
