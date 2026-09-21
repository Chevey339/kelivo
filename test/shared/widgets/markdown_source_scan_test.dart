import 'package:Kelivo/shared/widgets/markdown_source_scan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('append scanning is bounded to newly arrived code units', () {
    final scan = MarkdownSourceScan();
    var source = '中文 **bold** and *italic* ' * 1000;
    scan.update(source);
    for (var i = 0; i < 100; i++) {
      source += '追加 ';
      scan.update(source);
      expect(scan.appended, isTrue);
    }
    expect(scan.scannedCodeUnits, source.length);
    expect(scan.needsPreprocessing, isFalse);
    expect(scan.hasBrackets, isFalse);
    expect(scan.hasHtml, isFalse);
    expect(scan.hasCarriageReturns, isFalse);
  });

  test('markers arriving across chunks and replacements reset the hints', () {
    final scan = MarkdownSourceScan();
    var source = '文字 !';
    scan.update(source);
    expect(scan.hasBrackets, isFalse);
    source += '[image';
    scan.update(source);
    expect(scan.hasBrackets, isTrue);
    source += '](/tmp/a b.png) <details>\r';
    scan.update(source);
    expect(scan.hasHtml, isTrue);
    expect(scan.hasCarriageReturns, isTrue);
    scan.update('replacement **bold**');
    expect(scan.appended, isFalse);
    expect(scan.needsPreprocessing, isFalse);
    expect(scan.hasBrackets, isFalse);
    expect(scan.hasHtml, isFalse);
    expect(scan.hasCarriageReturns, isFalse);
  });

  test('every preprocessing trigger is retained', () {
    for (final marker in '`~\$\\<\r#[]-|>'.split('')) {
      final scan = MarkdownSourceScan()..update('前文 $marker 后文');
      expect(scan.needsPreprocessing, isTrue, reason: marker);
    }
  });
}
