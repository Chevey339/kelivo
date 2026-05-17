import 'package:flutter/material.dart';
import 'package:gpt_markdown/custom_widgets/code_field.dart';
import 'package:gpt_markdown/custom_widgets/custom_divider.dart';
import 'package:gpt_markdown/custom_widgets/custom_rb_cb.dart';
import 'package:gpt_markdown/custom_widgets/indent_widget.dart';
import 'package:gpt_markdown/custom_widgets/link_button.dart';
import 'package:gpt_markdown/custom_widgets/unordered_ordered_list.dart';
import 'package:gpt_markdown/gpt_markdown.dart'
    show MarkdownComponent, MdWidget;

/// Serializes a Flutter span tree into a stable, comparable string format.
///
/// This serializer walks the [InlineSpan] tree produced by GptMarkdown and
/// outputs a deterministic string representation that can be used for
/// snapshot-style testing.
///
/// ## Output Format Examples:
/// - `TEXT("content")` - plain text
/// - `TEXT("content")[bold]` - text with bold style
/// - `TEXT("content")[bold,italic]` - text with multiple styles
/// - `LINK("text", url="...")` - hyperlinks
/// - `IMAGE(url="...")` - images
/// - `H1("content")` through `H6("content")` - headings
/// - `UL_ITEM(...)` - unordered list items
/// - `OL_ITEM(n, ...)` - ordered list items
/// - `CHECKBOX(checked=true, ...)` - checkboxes
/// - `RADIO(checked=false, ...)` - radio buttons
/// - `CODE_BLOCK(lang="dart", "...")` - code blocks
/// - `LATEX_INLINE("...")` - inline LaTeX
/// - `LATEX_BLOCK("...")` - block LaTeX
/// - `BLOCKQUOTE(...)` - block quotes
/// - `HR` - horizontal rules
/// - `NEWLINE` - paragraph breaks
class MarkdownSerializer {
  final StringBuffer _buffer = StringBuffer();
  int _depth = 0;

  /// Serializes a [TextSpan] (typically the root span from RichText) into
  /// a stable string representation.
  String serialize(InlineSpan span) {
    _buffer.clear();
    _depth = 0;
    _visitSpan(span);
    return _buffer.toString().trim();
  }

  void _visitSpan(InlineSpan span) {
    if (span is TextSpan) {
      _visitTextSpan(span);
    } else if (span is WidgetSpan) {
      _visitWidgetSpan(span);
    }
  }

  void _visitTextSpan(TextSpan span) {
    // Handle text content
    if (span.text != null && span.text!.isNotEmpty) {
      final text = span.text!;

      // Check for newlines (paragraph breaks)
      if (text == '\n\n') {
        _write('NEWLINE');
      } else if (text.trim().isNotEmpty || text == ' ') {
        _writeTextWithStyle(text, span.style);
      }
    }

    // Recursively handle children
    if (span.children != null) {
      for (final child in span.children!) {
        _visitSpan(child);
      }
    }
  }

  void _writeTextWithStyle(String text, TextStyle? style) {
    final modifiers = <String>[];

    if (style != null) {
      if (style.fontWeight == FontWeight.bold ||
          style.fontWeight == FontWeight.w700) {
        modifiers.add('bold');
      }
      if (style.fontStyle == FontStyle.italic) {
        modifiers.add('italic');
      }
      if (style.decoration == TextDecoration.lineThrough) {
        modifiers.add('strike');
      }
      if (style.decoration == TextDecoration.underline) {
        modifiers.add('underline');
      }
      // Highlight detection: check for background paint
      if (style.background != null) {
        modifiers.add('highlight');
      }
    }

    final escapedText = _escapeText(text);
    if (modifiers.isNotEmpty) {
      _write('TEXT("$escapedText")[${modifiers.join(',')}]');
    } else {
      _write('TEXT("$escapedText")');
    }
  }

  void _visitWidgetSpan(WidgetSpan span) {
    final widget = span.child;
    _visitWidget(widget);
  }

  void _visitWidget(Widget widget) {
    // Unwrap common wrapper widgets
    if (widget is Row) {
      for (final child in widget.children) {
        if (child is Flexible) {
          _visitWidget(child.child);
        } else {
          _visitWidget(child);
        }
      }
      return;
    }

    if (widget is Flexible) {
      _visitWidget(widget.child);
      return;
    }

    if (widget is Directionality) {
      _visitWidget(widget.child);
      return;
    }

    if (widget is Padding && widget.child != null) {
      _visitWidget(widget.child!);
      return;
    }

    if (widget is ClipRRect && widget.child != null) {
      _visitWidget(widget.child!);
      return;
    }

    if (widget is Center) {
      _visitWidget(widget.child!);
      return;
    }

    if (widget is Align) {
      _visitWidget(widget.child!);
      return;
    }

    // Code blocks
    if (widget is CodeField) {
      final lang = widget.name.isNotEmpty ? widget.name : '';
      final code = _escapeText(widget.codes);
      _write('CODE_BLOCK(lang="$lang", "$code")');
      return;
    }

    // Horizontal rule
    if (widget is CustomDivider) {
      _write('HR');
      return;
    }

    // Checkbox
    if (widget is CustomCb) {
      _depth++;
      final content = _serializeChildWidget(widget.child);
      _depth--;
      _write('CHECKBOX(checked=${widget.value}, $content)');
      return;
    }

    // Radio button
    if (widget is CustomRb) {
      _depth++;
      final content = _serializeChildWidget(widget.child);
      _depth--;
      _write('RADIO(checked=${widget.value}, $content)');
      return;
    }

    // Unordered list item
    if (widget is UnorderedListView) {
      _depth++;
      final content = _serializeChildWidget(widget.child);
      _depth--;
      _write('UL_ITEM($content)');
      return;
    }

    // Ordered list item
    if (widget is OrderedListView) {
      _depth++;
      final content = _serializeChildWidget(widget.child);
      _depth--;
      final no = widget.no.replaceAll('.', '');
      _write('OL_ITEM($no, $content)');
      return;
    }

    // Block quote
    if (widget is BlockQuoteWidget) {
      _depth++;
      final content = _serializeChildWidget(widget.child);
      _depth--;
      _write('BLOCKQUOTE($content)');
      return;
    }

    // Link button
    if (widget is LinkButton) {
      final urlPart =
          widget.url != null ? ', url="${_escapeText(widget.url!)}"' : '';
      _write('LINK("${_escapeText(widget.text)}"$urlPart)');
      return;
    }

    // GestureDetector wrapping links
    if (widget is GestureDetector && widget.child != null) {
      _visitWidget(widget.child!);
      return;
    }

    // MouseRegion wrapping links
    if (widget is MouseRegion && widget.child != null) {
      _visitWidget(widget.child!);
      return;
    }

    // Images
    if (widget is Image) {
      String url = '';
      if (widget.image is NetworkImage) {
        url = (widget.image as NetworkImage).url;
      }
      _write('IMAGE(url="$url")');
      return;
    }

    if (widget is SizedBox && widget.child is Image) {
      final image = widget.child as Image;
      String url = '';
      if (image.image is NetworkImage) {
        url = (image.image as NetworkImage).url;
      }
      final w = widget.width?.toInt();
      final h = widget.height?.toInt();
      if (w != null || h != null) {
        _write('IMAGE(url="$url", w=$w, h=$h)');
      } else {
        _write('IMAGE(url="$url")');
      }
      return;
    }

    // Tables
    if (widget is Scrollbar) {
      _visitWidget(widget.child);
      return;
    }

    if (widget is SingleChildScrollView && widget.child is Table) {
      _visitWidget(widget.child!);
      return;
    }

    if (widget is Table) {
      _serializeTable(widget);
      return;
    }

    // RichText (nested markdown content)
    if (widget is RichText) {
      _visitSpan(widget.text);
      return;
    }

    // SelectableText.rich
    if (widget is SelectableText) {
      if (widget.textSpan != null) {
        _visitSpan(widget.textSpan!);
      }
      return;
    }

    // LaTeX - Math widget from flutter_math_fork
    // We detect it by checking the widget type name since we can't import the type
    final typeName = widget.runtimeType.toString();
    if (typeName.contains('Math') || typeName.contains('Tex')) {
      // For LaTeX, we'll mark it as such - the actual content is harder to extract
      _write('LATEX("...")');
      return;
    }

    // SelectableAdapter wraps LaTeX
    if (typeName == 'SelectableAdapter') {
      _write('LATEX("...")');
      return;
    }

    // Fallback: unknown widget
    // _write('WIDGET($typeName)');
  }

  void _serializeTable(Table table) {
    _write('TABLE(');
    _depth++;

    bool isFirstRow = true;
    for (final row in table.children) {
      final cells = <String>[];
      for (final cell in row.children) {
        cells.add(_extractCellContent(cell));
      }

      if (isFirstRow) {
        _write('HEADER(${cells.map((c) => '"$c"').join(', ')})');
        isFirstRow = false;
      } else {
        _write('ROW(${cells.map((c) => '"$c"').join(', ')})');
      }
    }

    _depth--;
    _write(')');
  }

  String _extractCellContent(Widget cell) {
    if (cell is Padding && cell.child != null) {
      return _extractCellContent(cell.child!);
    }
    if (cell is Align && cell.child != null) {
      return _extractCellContent(cell.child!);
    }
    if (cell is Center && cell.child != null) {
      return _extractCellContent(cell.child!);
    }
    if (cell is RichText) {
      return _extractTextFromSpan(cell.text);
    }
    if (cell is SizedBox) {
      return '';
    }
    // Try to extract from any widget with a child
    return '';
  }

  String _extractTextFromSpan(InlineSpan span) {
    final buffer = StringBuffer();
    if (span is TextSpan) {
      if (span.text != null) {
        buffer.write(span.text);
      }
      if (span.children != null) {
        for (final child in span.children!) {
          buffer.write(_extractTextFromSpan(child));
        }
      }
    }
    return buffer.toString().trim();
  }

  String _serializeChildWidget(Widget widget) {
    final childSerializer = MarkdownSerializer();
    childSerializer._depth = _depth;

    if (widget is RichText) {
      return childSerializer.serialize(widget.text);
    }

    // Handle MdWidget by parsing its markdown expression into spans
    if (widget is MdWidget) {
      final content = widget.exp.trim();
      if (content.isNotEmpty) {
        // Parse the markdown into spans using the same config
        final spans = MarkdownComponent.generate(
          widget.context,
          content,
          widget.config,
          widget.includeGlobalComponents,
        );
        // Serialize the parsed spans
        final childSerializer = MarkdownSerializer();
        childSerializer._depth = _depth;
        for (final span in spans) {
          childSerializer._visitSpan(span);
        }
        return childSerializer._buffer.toString().trim();
      }
      return '';
    }

    // Handle StatefulWidget by trying to find RichText in the tree
    // This is a simplification - in real tests we'd have access to the element tree
    childSerializer._visitWidget(widget);
    return childSerializer._buffer.toString().trim();
  }

  void _write(String content) {
    if (_buffer.isNotEmpty && !_buffer.toString().endsWith('\n')) {
      _buffer.write(' ');
    }
    _buffer.write(content);
  }

  String _escapeText(String text) {
    return text
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll('\t', '\\t');
  }
}

/// Convenience function to serialize a span tree.
String serializeMarkdown(InlineSpan span) {
  return MarkdownSerializer().serialize(span);
}
