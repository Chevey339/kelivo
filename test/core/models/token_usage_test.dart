import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/token_usage.dart';

void main() {
  group('TokenUsage', () {
    test(
      'merge preserves explicit total when split token fields are missing',
      () {
        final merged = const TokenUsage().merge(
          const TokenUsage(totalTokens: 895),
        );

        expect(merged.promptTokens, 0);
        expect(merged.completionTokens, 0);
        expect(merged.cachedTokens, 0);
        expect(merged.totalTokens, 895);
      },
    );

    test('merge splices Claude halves instead of summing both sides', () {
      final merged = const TokenUsage(
        promptTokens: 100,
        completionTokens: 0,
      ).merge(const TokenUsage(promptTokens: 0, completionTokens: 20));

      expect(merged.promptTokens, 100);
      expect(merged.completionTokens, 20);
      expect(merged.totalTokens, 120);
    });

    test('merge keeps only the newest round, never the sum of rounds', () {
      final latest = const TokenUsage(promptTokens: 100, completionTokens: 20)
          .merge(const TokenUsage(promptTokens: 300, completionTokens: 40))
          .merge(const TokenUsage(promptTokens: 500, completionTokens: 10));

      expect(latest.promptTokens, 500);
      expect(latest.completionTokens, 10);
      expect(latest.totalTokens, 510);
    });

    test('merge keeps the prior snapshot when a round reports nothing', () {
      final kept = const TokenUsage(
        promptTokens: 100,
        completionTokens: 20,
      ).merge(const TokenUsage());

      expect(kept.promptTokens, 100);
      expect(kept.completionTokens, 20);
      expect(kept.totalTokens, 120);
    });

    test('merge newest non-zero wins for reasoning and cache-write', () {
      final merged = const TokenUsage(reasoningTokens: 5, cacheWriteTokens: 3)
          .merge(const TokenUsage(reasoningTokens: 0, cacheWriteTokens: 8))
          .merge(const TokenUsage(reasoningTokens: 9, cacheWriteTokens: 0));

      expect(merged.reasoningTokens, 9);
      expect(merged.cacheWriteTokens, 8);
    });

    test('JSON round-trip keeps reasoning and cache-write', () {
      const original = TokenUsage(
        promptTokens: 10,
        completionTokens: 4,
        cachedTokens: 2,
        reasoningTokens: 7,
        cacheWriteTokens: 3,
        totalTokens: 14,
      );

      final restored = TokenUsage.fromJson(original.toJson());
      expect(restored.promptTokens, 10);
      expect(restored.completionTokens, 4);
      expect(restored.cachedTokens, 2);
      expect(restored.reasoningTokens, 7);
      expect(restored.cacheWriteTokens, 3);
      expect(restored.totalTokens, 14);
    });
  });
}
