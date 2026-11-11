import 'package:Kelivo/core/models/compression_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
