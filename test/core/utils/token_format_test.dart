import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/utils/token_format.dart';

void main() {
  test('formatTokenCount scales with at most one decimal', () {
    expect(formatTokenCount(512), '512');
    expect(formatTokenCount(4096), '4k');
    expect(formatTokenCount(1500), '1.5k');
    expect(formatTokenCount(128000), '128k');
    expect(formatTokenCount(200000), '200k');
    expect(formatTokenCount(1048576), '1M');
    expect(formatTokenCount(2000000), '2M');
  });
}
