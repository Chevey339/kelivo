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
  });
}
