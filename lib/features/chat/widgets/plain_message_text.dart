import 'package:flutter/widgets.dart';
import 'package:markstream/markstream.dart';

final _lineBreak = RegExp(r'\r\n|[\r\n\u2028\u2029]');

/// A plaintext bubble keeps its single native paragraph when its lines share
/// a base direction. Mixed-direction lines need separate Flutter paragraphs.
Widget plainMessageText({
  required String text,
  required TextStyle style,
  TextSpan Function(int start, int end)? buildSpan,
  StrutStyle? strutStyle,
  TextHeightBehavior? textHeightBehavior,
}) {
  TextSpan span(int start, int end) =>
      buildSpan?.call(start, end) ?? TextSpan(text: text.substring(start, end));
  Text paragraph(TextSpan content, TextDirection? direction) => Text.rich(
    content,
    style: style,
    textDirection: direction,
    strutStyle: strutStyle,
    textHeightBehavior: textHeightBehavior,
  );

  final first = firstStrongDirection(text);
  Widget wholeMessage() {
    if (buildSpan != null) return paragraph(span(0, text.length), first);
    return Text(
      text,
      style: style,
      textDirection: first,
      strutStyle: strutStyle,
      textHeightBehavior: textHeightBehavior,
    );
  }

  if (!_lineBreak.hasMatch(text) || !containsStrongRtl(text)) {
    return wholeMessage();
  }

  final lines = <({int start, int end, int next, TextDirection? direction})>[];
  var start = 0;
  void addLine(int end, int next) {
    lines.add((
      start: start,
      end: end,
      next: next,
      direction: firstStrongDirection(text.substring(start, end)),
    ));
    start = next;
  }

  for (final match in _lineBreak.allMatches(text)) {
    addLine(match.start, match.end);
  }
  addLine(text.length, text.length);
  if (lines.every((line) => line.direction == first)) {
    return wholeMessage();
  }

  // One intrinsic-width column takes the width of its longest line in a
  // compact bubble. Its cells fill the available width in a full-width bubble.
  return Table(
    defaultColumnWidth: const IntrinsicColumnWidth(),
    children: [
      for (final line in lines)
        TableRow(
          children: [
            Align(
              alignment: line.direction == TextDirection.rtl
                  ? Alignment.centerRight
                  : line.direction == TextDirection.ltr
                  ? Alignment.centerLeft
                  : AlignmentDirectional.centerStart,
              child: buildSelectableText(
                paragraph(
                  TextSpan(
                    children: [
                      span(line.start, line.end),
                      // Keep the actual separator selectable, including both CRLF code
                      // units. Let the Column supply the visual break exactly once.
                      if (line.next > line.end)
                        WidgetSpan(
                          child: SelectableSpanAdapter(
                            selectedText: text.substring(line.end, line.next),
                            child: const SizedBox.shrink(),
                          ),
                        ),
                    ],
                  ),
                  line.direction,
                ),
              ),
            ),
          ],
        ),
    ],
  );
}
