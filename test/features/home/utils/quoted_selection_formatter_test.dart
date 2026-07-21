import 'package:Kelivo/features/home/utils/quoted_selection_formatter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('insertQuotedSelectionIntoDraft', () {
    test('inserts a multiline Markdown quote into an empty draft', () {
      final result = insertQuotedSelectionIntoDraft(
        const TextEditingValue(),
        'first line\r\nsecond line',
      );

      expect(result.text, '> first line\n> second line\n\n');
      expect(
        result.selection,
        TextSelection.collapsed(offset: result.text.length),
      );
      expect(result.composing, TextRange.empty);
    });

    test('inserts at the caret without overwriting existing text', () {
      final result = insertQuotedSelectionIntoDraft(
        const TextEditingValue(
          text: 'beforeafter',
          selection: TextSelection.collapsed(offset: 6),
        ),
        'selected',
      );

      expect(result.text, 'before\n\n> selected\n\nafter');
      expect(result.selection.baseOffset, 'before\n\n> selected\n\n'.length);
    });

    test('replaces the current draft selection', () {
      final result = insertQuotedSelectionIntoDraft(
        const TextEditingValue(
          text: 'ask about this please',
          selection: TextSelection(baseOffset: 4, extentOffset: 14),
        ),
        'A\n\nB',
      );

      expect(result.text, 'ask \n\n> A\n>\n> B\n\n please');
      expect(result.selection.baseOffset, 'ask \n\n> A\n>\n> B\n\n'.length);
    });

    test('preserves meaningful indentation in the selected text', () {
      final result = insertQuotedSelectionIntoDraft(
        const TextEditingValue(),
        '\n  indented\n    child\n',
      );

      expect(result.text, '>   indented\n>     child\n\n');
    });

    test('uses the end of the draft when the selection is invalid', () {
      final result = insertQuotedSelectionIntoDraft(
        const TextEditingValue(text: 'question'),
        'answer',
      );

      expect(result.text, 'question\n\n> answer\n\n');
      expect(result.selection.baseOffset, result.text.length);
    });

    test('ignores whitespace-only selected text', () {
      const current = TextEditingValue(
        text: 'draft',
        selection: TextSelection.collapsed(offset: 2),
      );

      expect(insertQuotedSelectionIntoDraft(current, ' \r\n '), current);
    });
  });
}
