import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';

void main() {
  testWidgets('Home and End use visual rows and retain the selection anchor', (
    tester,
  ) async {
    const style = TextStyle(fontFamily: 'Ahem', fontSize: 20);
    final layout = CodeNavigationLayout(style, 100, style);
    addTearDown(layout.dispose);
    // The test font has 20 px glyphs: this 15-character line occupies exactly
    // three five-character visual rows. The second paragraph starts at 16.
    const value = TextEditingValue(
      text: 'abcdefghijklmno\nsecond',
      selection: TextSelection.collapsed(offset: 7),
    );
    expect(layout.resolve(value, true, false, lineEdge: true).extentOffset, 5);
    final end = layout.resolve(value, false, false, lineEdge: true);
    expect(end.extentOffset, 10);
    expect(end.affinity, TextAffinity.upstream);
    expect(
      layout
          .resolve(value.copyWith(selection: end), true, false, lineEdge: true)
          .extentOffset,
      5,
    );
    final range = value.copyWith(
      selection: const TextSelection(baseOffset: 2, extentOffset: 7),
    );
    final extended = layout.resolve(range, false, true, lineEdge: true);
    expect(extended.baseOffset, 2);
    expect(extended.extentOffset, 10);
    final paragraph = value.copyWith(
      selection: const TextSelection.collapsed(offset: 18),
    );
    expect(
      layout.resolve(paragraph, true, false, lineEdge: true).extentOffset,
      16,
    );
    expect(
      layout.resolve(paragraph, false, false, lineEdge: true).extentOffset,
      21,
    );
  });
}
