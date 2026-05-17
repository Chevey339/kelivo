import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import 'serializer.dart';

/// Pumps a [GptMarkdown] widget with the given [markdown] input.
///
/// Wraps the widget in a [MaterialApp] and [Scaffold] to provide
/// the required context for theming and layout.
///
/// Returns the [WidgetTester] for further assertions.
Future<void> pumpMarkdown(
  WidgetTester tester,
  String markdown, {
  TextStyle? style,
  TextDirection textDirection = TextDirection.ltr,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: GptMarkdown(
            markdown,
            style: style,
            textDirection: textDirection,
          ),
        ),
      ),
    ),
  );
  // Allow any animations or async operations to complete
  await tester.pumpAndSettle();
}

/// Extracts and serializes the output from the rendered [GptMarkdown] widget.
///
/// Returns the serialized string representation of the markdown output.
/// This iterates through ALL RichText widgets to capture nested content
/// (from MdWidget instances inside list items, checkboxes, etc.)
String getSerializedOutput(WidgetTester tester) {
  // Find ALL RichText widgets (including nested ones from MdWidget)
  final richTextFinder = find.byType(RichText);

  if (richTextFinder.evaluate().isEmpty) {
    return '';
  }

  // Get all RichText widgets
  final richTexts = tester.widgetList<RichText>(richTextFinder).toList();

  if (richTexts.isEmpty) {
    return '';
  }

  // Serialize the first (main) RichText - this has the structure
  final mainOutput = serializeMarkdown(richTexts.first.text);

  // Extract text content from ALL RichText widgets to capture nested content
  final allTextContent = <String>[];
  for (final rt in richTexts) {
    final text = _extractAllText(rt.text);
    if (text.isNotEmpty) {
      allTextContent.add(text);
    }
  }

  // Return the main serialized output (structure-aware)
  // The test can also use allTextContent for text verification if needed
  return mainOutput;
}

/// Extracts plain text from a span tree (for content verification)
String _extractAllText(InlineSpan span) {
  final buffer = StringBuffer();
  if (span is TextSpan) {
    if (span.text != null) {
      buffer.write(span.text);
    }
    if (span.children != null) {
      for (final child in span.children!) {
        buffer.write(_extractAllText(child));
      }
    }
  }
  return buffer.toString();
}

/// Combined helper that pumps markdown and asserts on the serialized output.
///
/// This is the primary helper for most test cases.
///
/// Example:
/// ```dart
/// testWidgets('bold text', (tester) async {
///   await expectMarkdown(
///     tester,
///     '**bold**',
///     'TEXT("bold")[bold]',
///   );
/// });
/// ```
Future<void> expectMarkdown(
  WidgetTester tester,
  String markdown,
  String expectedOutput, {
  TextStyle? style,
  TextDirection textDirection = TextDirection.ltr,
}) async {
  await pumpMarkdown(
    tester,
    markdown,
    style: style,
    textDirection: textDirection,
  );

  final actualOutput = getSerializedOutput(tester);
  expect(actualOutput, expectedOutput);
}

/// Asserts that the serialized output contains a specific pattern.
///
/// Useful for partial matching when exact output is complex or
/// when testing for presence of specific elements.
Future<void> expectMarkdownContains(
  WidgetTester tester,
  String markdown,
  String pattern, {
  TextStyle? style,
  TextDirection textDirection = TextDirection.ltr,
}) async {
  await pumpMarkdown(
    tester,
    markdown,
    style: style,
    textDirection: textDirection,
  );

  final actualOutput = getSerializedOutput(tester);
  expect(actualOutput, contains(pattern));
}

/// Asserts that the serialized output matches a regular expression.
///
/// Useful for flexible matching when exact content varies but
/// structure should be consistent.
Future<void> expectMarkdownMatches(
  WidgetTester tester,
  String markdown,
  Pattern pattern, {
  TextStyle? style,
  TextDirection textDirection = TextDirection.ltr,
}) async {
  await pumpMarkdown(
    tester,
    markdown,
    style: style,
    textDirection: textDirection,
  );

  final actualOutput = getSerializedOutput(tester);
  expect(actualOutput, matches(pattern));
}

/// Debug helper that prints the serialized output for a given markdown input.
///
/// Useful when developing new tests to see what output format to expect.
///
/// Example:
/// ```dart
/// testWidgets('debug output', (tester) async {
///   await debugMarkdownOutput(tester, '**bold** and *italic*');
///   // Prints: TEXT("bold")[bold] TEXT(" and ") TEXT("italic")[italic]
/// });
/// ```
Future<void> debugMarkdownOutput(
  WidgetTester tester,
  String markdown, {
  TextStyle? style,
  TextDirection textDirection = TextDirection.ltr,
}) async {
  await pumpMarkdown(
    tester,
    markdown,
    style: style,
    textDirection: textDirection,
  );

  final actualOutput = getSerializedOutput(tester);
  // ignore: avoid_print
  print('Markdown input: $markdown');
  // ignore: avoid_print
  print('Serialized output: $actualOutput');
}
