import 'package:Kelivo/shared/widgets/incremental_markdown_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('append-only updates retain completed block identities', () {
    final document = IncrementalMarkdownDocument();
    final initial = document.update('first paragraph\n\nsecond');
    final firstBlock = initial.first;

    final updated = document.update('first paragraph\n\nsecond grows');

    expect(identical(updated.first, firstBlock), isTrue);
    expect(updated.last.text, 'second grows');
  });

  test('blank lines inside fences do not split source blocks', () {
    final document = IncrementalMarkdownDocument();
    final blocks = document.update('before\n\n```dart\na\n\nb\n```\n\nafter');

    expect(blocks, hasLength(3));
    expect(blocks[1].text, contains('a\n\nb'));
  });

  test('1 MiB append stream scans each source code unit once', () {
    final document = IncrementalMarkdownDocument();
    var source = '';
    final chunk = List<String>.filled(256, '0123456789abcdef').join();
    for (var index = 0; index < 256; index++) {
      source += chunk;
      document.update(source);
    }

    expect(source.length, 1 << 20);
    expect(document.rescannedCodeUnits, source.length);
    expect(document.blocks, hasLength(1));
  });
}
