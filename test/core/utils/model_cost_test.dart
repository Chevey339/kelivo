import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/models/model_spec.dart';
import 'package:Kelivo/core/models/token_usage.dart';
import 'package:Kelivo/core/utils/model_cost.dart';

void main() {
  group('estimateModelCost', () {
    test('returns null when pricing is missing or both rates are null', () {
      const usage = TokenUsage(promptTokens: 1000, completionTokens: 500);
      expect(estimateModelCost(usage, null), isNull);
      expect(estimateModelCost(usage, const ModelPricing()), isNull);
      expect(
        estimateModelCost(
          usage,
          const ModelPricing(cacheRead: 0.1, cacheWrite: 0.2),
        ),
        isNull,
      );
    });

    test('applies input and output rates per 1M tokens', () {
      final cost = estimateModelCost(
        const TokenUsage(promptTokens: 1000000, completionTokens: 2000000),
        const ModelPricing(input: 1, output: 3, currency: 'USD'),
      );
      expect(cost, const ModelCost(amount: 7, currency: 'USD'));
    });

    test('treats a missing single rate as 0', () {
      expect(
        estimateModelCost(
          const TokenUsage(promptTokens: 1000000, completionTokens: 500000),
          const ModelPricing(input: 2),
        ),
        const ModelCost(amount: 2, currency: 'USD'),
      );
      expect(
        estimateModelCost(
          const TokenUsage(promptTokens: 1000000, completionTokens: 500000),
          const ModelPricing(output: 4, currency: 'CNY'),
        ),
        const ModelCost(amount: 2, currency: 'CNY'),
      );
    });

    test('bills cache reads at cacheRead or input fallback', () {
      const usage = TokenUsage(promptTokens: 2000000, cachedTokens: 500000);
      expect(
        estimateModelCost(usage, const ModelPricing(input: 1, output: 2)),
        const ModelCost(amount: 2, currency: 'USD'),
      );
      expect(
        estimateModelCost(
          usage,
          const ModelPricing(input: 1, output: 2, cacheRead: 0.1),
        ),
        const ModelCost(amount: 1.55, currency: 'USD'),
      );
    });

    test('bills cache writes at cacheWrite or input fallback', () {
      const usage = TokenUsage(
        promptTokens: 1000000,
        cacheWriteTokens: 1000000,
      );
      expect(
        estimateModelCost(usage, const ModelPricing(input: 2, output: 5)),
        const ModelCost(amount: 2, currency: 'USD'),
      );
      expect(
        estimateModelCost(
          usage,
          const ModelPricing(input: 2, output: 5, cacheWrite: 0.4),
        ),
        const ModelCost(amount: 0.4, currency: 'USD'),
      );
    });

    test('clamps prompt minus cache read at 0', () {
      final cost = estimateModelCost(
        const TokenUsage(
          promptTokens: 100,
          cachedTokens: 250,
          completionTokens: 1000000,
        ),
        const ModelPricing(input: 1, output: 2, cacheRead: 0.2),
      );
      expect(cost!.currency, 'USD');
      expect(cost.amount, closeTo(2 + 250 * 0.2 / 1000000, 1e-12));
    });

    test('combines cache read, write, prompt, and completion', () {
      final cost = estimateModelCost(
        const TokenUsage(
          promptTokens: 3000000,
          cachedTokens: 1000000,
          cacheWriteTokens: 500000,
          completionTokens: 2000000,
        ),
        const ModelPricing(
          input: 1,
          output: 4,
          cacheRead: 0.1,
          cacheWrite: 1.25,
          currency: 'EUR',
        ),
      );
      expect(cost, const ModelCost(amount: 10.225, currency: 'EUR'));
    });
  });

  group('formatModelCost', () {
    const cases = <({double amount, String currency, String expected})>[
      (amount: 0.0123, currency: 'USD', expected: r'$0.0123'),
      (amount: 0.12, currency: 'CNY', expected: '¥0.12'),
      (amount: 1.2, currency: 'EUR', expected: '€1.2'),
      (amount: 12, currency: 'GBP', expected: '£12'),
      (amount: 0.5, currency: 'JPY', expected: '¥0.5'),
      (amount: 0.0123, currency: 'KRW', expected: '0.0123 KRW'),
      (amount: 0, currency: 'USD', expected: r'$0'),
      (amount: 0.00009, currency: 'USD', expected: r'<$0.0001'),
      (amount: 0.00009, currency: 'KRW', expected: '<0.0001 KRW'),
      (amount: 1.23456, currency: 'USD', expected: r'$1.2346'),
    ];

    for (final c in cases) {
      test('${c.amount} ${c.currency} -> ${c.expected}', () {
        expect(
          formatModelCost(ModelCost(amount: c.amount, currency: c.currency)),
          c.expected,
        );
      });
    }
  });
}
