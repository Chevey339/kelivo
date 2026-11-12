import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';

void main() {
  testWidgets('queued Up after CRLF matches full paragraph layout', (
    tester,
  ) async {
    const style = TextStyle(fontFamily: 'Ahem', fontSize: 20);
    final layout = CodeNavigationLayout(style, 200, style);
    final paragraph = TextPainter(
      text: const TextSpan(text: 'abc\r\nsecond', style: style),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 200);
    addTearDown(layout.dispose);
    addTearDown(paragraph.dispose);
    const value = TextEditingValue(
      text: 'abc\r\nsecond',
      selection: TextSelection.collapsed(offset: 6),
    );
    final caret = paragraph.getOffsetForCaret(
      value.selection.extent,
      Rect.zero,
    );
    final expected = paragraph.getPositionForOffset(
      caret - Offset(0, paragraph.preferredLineHeight),
    );
    final target = layout.resolve(value, true, false);
    expect(target.extentOffset, expected.offset);
  });

  testWidgets('End reaches trailing whitespace on the visual row', (
    tester,
  ) async {
    const style = TextStyle(fontFamily: 'Ahem', fontSize: 20);
    final layout = CodeNavigationLayout(style, 200, style);
    addTearDown(layout.dispose);
    const value = TextEditingValue(
      text: 'abc  \nzzz',
      selection: TextSelection.collapsed(offset: 2),
    );
    final target = layout.resolve(value, false, false, lineEdge: true);
    expect(target.extentOffset, 5);
  });
}
