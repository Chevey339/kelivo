import 'package:Kelivo/core/models/compression_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'request timeout inherits, round trips, and clears to mode defaults',
    () {
      const defaults = CompressionConfig(requestTimeoutMinutes: 10);
      expect(const CompressionConfig().requestTimeout, isNull);
      expect(
        defaults.withOverrides({}).requestTimeout,
        const Duration(minutes: 10),
      );
      final override = defaults.withOverrides({'requestTimeoutMinutes': 1.5});
      final restored = CompressionConfig.fromJson(override.toJson());
      expect(restored.requestTimeout, const Duration(seconds: 90));
      expect(
        restored.withOverrides({'requestTimeoutMinutes': null}).requestTimeout,
        isNull,
      );
    },
  );

  test('request timeout rejects nonpositive and nonfinite values', () {
    for (final value in [0, -1, double.nan, double.infinity, 1e308]) {
      expect(
        () => CompressionConfig.fromJson({'requestTimeoutMinutes': value}),
        throwsFormatException,
      );
    }
  });

  test('output budget round trips and can be cleared independently', () {
    final config = CompressionConfig.fromJson({
      'summaryTokens': 4096,
      'maxOutputTokens': 32768,
    });
    final restored = CompressionConfig.fromJson(config.toJson());
    expect(restored.summaryTokens, 4096);
    expect(restored.maxOutputTokens, 32768);
    final cleared = restored.withOverrides({'maxOutputTokens': null});
    expect(cleared.summaryTokens, 4096);
    expect(cleared.maxOutputTokens, isNull);
  });

  test('total output must cover the summary and remain bounded', () {
    for (final budget in [-1, 0, 4095, 1048577]) {
      expect(
        () => CompressionConfig.fromJson({'maxOutputTokens': budget}),
        throwsFormatException,
      );
    }
  });
}
