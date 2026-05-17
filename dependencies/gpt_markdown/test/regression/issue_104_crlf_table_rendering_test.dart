// Regression test for: https://github.com/Infinitix-LLC/gpt_markdown/issues/104
//
// Bug: Tables whose rows are separated with `\r\n` (or bare `\r`) line endings
// were not recognized and rendered as raw text, because the block-level regexes
// in `lib/markdown_component.dart` (e.g. `TableMd.expString`) assume LF-only
// separators and do not consume a trailing `\r` between the closing `|` and
// the next `\n`.
//
// Fix: Normalize `\r\n` and bare `\r` to `\n` at the entry point of
// `GptMarkdown.build()` in `lib/gpt_markdown.dart`. This is a single
// normalization at the input boundary that benefits every block-level
// component, not just tables.

import 'package:flutter_test/flutter_test.dart';
import '../utils/test_helpers.dart';

void main() {
  group('issue #104: tables with CRLF / CR line endings', () {
    testWidgets('table with \\r\\n separators renders as a table', (
      tester,
    ) async {
      await pumpMarkdown(tester, '| a | b |\r\n| --- | --- |\r\n| 1 | 2 |');
      final output = getSerializedOutput(tester);
      expect(output, contains('TABLE'));
    });

    testWidgets('table with bare \\r separators renders as a table', (
      tester,
    ) async {
      await pumpMarkdown(tester, '| a | b |\r| --- | --- |\r| 1 | 2 |');
      final output = getSerializedOutput(tester);
      expect(output, contains('TABLE'));
    });

    testWidgets(
      'table with mixed \\r\\n and \\n separators renders as a table',
      (tester) async {
        await pumpMarkdown(
          tester,
          '| Name | Value |\r\n|------|-------|\n| foo  | bar   |\r\n',
        );
        final output = getSerializedOutput(tester);
        expect(output, contains('TABLE'));
      },
    );
  });
}
