import 'package:flutter_test/flutter_test.dart';

import 'package:Cuplivo/core/models/token_usage.dart';

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
  });

  group('fromGeminiUsageMetadata', () {
    test('null input returns zero TokenUsage', () {
      final result = TokenUsage.fromGeminiUsageMetadata(null);

      expect(result.promptTokens, 0);
      expect(result.completionTokens, 0);
      expect(result.cachedTokens, 0);
      expect(result.totalTokens, 0);
    });

    test('empty map returns zero TokenUsage', () {
      final result = TokenUsage.fromGeminiUsageMetadata(<String, dynamic>{});

      expect(result.promptTokens, 0);
      expect(result.completionTokens, 0);
      expect(result.cachedTokens, 0);
      expect(result.totalTokens, 0);
    });

    test('all fields present with cachedContentTokenCount > 0', () {
      final result = TokenUsage.fromGeminiUsageMetadata({
        'promptTokenCount': 100,
        'candidatesTokenCount': 50,
        'cachedContentTokenCount': 42,
        'totalTokenCount': 192,
      });

      expect(result.promptTokens, 100);
      expect(result.completionTokens, 50);
      expect(result.cachedTokens, 42);
      expect(result.totalTokens, 192);
    });

    test('cachedContentTokenCount is 0', () {
      final result = TokenUsage.fromGeminiUsageMetadata({
        'promptTokenCount': 100,
        'candidatesTokenCount': 50,
        'cachedContentTokenCount': 0,
        'totalTokenCount': 150,
      });

      expect(result.cachedTokens, 0);
    });

    test('cachedContentTokenCount is missing', () {
      final result = TokenUsage.fromGeminiUsageMetadata({
        'promptTokenCount': 100,
        'candidatesTokenCount': 50,
        'totalTokenCount': 150,
      });

      expect(result.cachedTokens, 0);
    });

    test('all fields are zero', () {
      final result = TokenUsage.fromGeminiUsageMetadata({
        'promptTokenCount': 0,
        'candidatesTokenCount': 0,
        'cachedContentTokenCount': 0,
        'totalTokenCount': 0,
      });

      expect(result.promptTokens, 0);
      expect(result.completionTokens, 0);
      expect(result.cachedTokens, 0);
      expect(result.totalTokens, 0);
    });
  });
}
