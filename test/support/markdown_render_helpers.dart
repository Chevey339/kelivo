import 'package:flutter/material.dart' show MaterialApp;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream.dart';

/// Native paragraph batches have render objects without individual elements.
List<RenderParagraph> markdownParagraphs(WidgetTester tester) {
  return renderParagraphs(find.byType(MarkstreamView));
}

List<RenderParagraph> renderParagraphs(Finder roots) {
  final paragraphs = <RenderParagraph>[];
  void visit(RenderObject object) {
    if (object is RenderParagraph) paragraphs.add(object);
    object.visitChildren(visit);
  }

  for (final element in roots.evaluate()) {
    visit(element.findRenderObject()!);
  }
  return paragraphs;
}

RenderParagraph markdownParagraph(WidgetTester tester, String label) =>
    markdownParagraphs(
      tester,
    ).firstWhere((p) => p.text.toPlainText().contains(label));
Offset markdownGlyphCenter(WidgetTester tester, String label) {
  final paragraph = markdownParagraph(tester, label);
  final offset = paragraph.text.toPlainText().indexOf(label);
  final rect = paragraph
      .getBoxesForSelection(
        TextSelection(baseOffset: offset, extentOffset: offset + 1),
      )
      .first
      .toRect();
  return paragraph.localToGlobal(rect.center);
}

/// Matches rendered text even when a native batch has no per-paragraph Element.
List<RenderParagraph> renderedParagraphsWith(
  Pattern pattern, {
  bool exact = false,
}) => renderParagraphs(find.byType(MaterialApp)).where((paragraph) {
  final text = paragraph.text.toPlainText();
  return exact ? text == pattern : text.contains(pattern);
}).toList();

List<Offset> markdownGlyphCenters(WidgetTester tester, String label) => [
  for (final paragraph in markdownParagraphs(tester))
    for (final match in RegExp(
      RegExp.escape(label),
    ).allMatches(paragraph.text.toPlainText()))
      paragraph.localToGlobal(
        paragraph
            .getBoxesForSelection(
              TextSelection(
                baseOffset: match.start,
                extentOffset: match.start + 1,
              ),
            )
            .first
            .toRect()
            .center,
      ),
];
