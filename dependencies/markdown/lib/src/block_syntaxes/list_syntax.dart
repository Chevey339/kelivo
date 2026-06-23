// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast.dart';
import '../block_parser.dart';
import '../charcode.dart';
import '../line.dart';
import '../patterns.dart';
import '../text_parser.dart';
import '../util.dart';
import 'block_syntax.dart';
import 'ordered_list_with_checkbox_syntax.dart';
import 'unordered_list_with_checkbox_syntax.dart';

class ListItem {
  const ListItem(this.lines, {this.taskListItemState});

  final List<Line> lines;
  final TaskListItemState? taskListItemState;
}

enum TaskListItemState { checked, unchecked }

/// Base class for both ordered and unordered lists.
abstract class ListSyntax extends BlockSyntax {
  @override
  bool canParse(BlockParser parser) =>
      pattern.hasMatch(parser.current.content) &&
      !hrPattern.hasMatch(parser.current.content);

  @override
  bool canEndBlock(BlockParser parser) {
    // An empty list cannot interrupt a paragraph. See
    // https://spec.commonmark.org/0.30/#example-285.
    // Ideally, [BlockSyntax.canEndBlock] should be changed to be a method
    // which accepts a [BlockParser], but this would be a breaking change,
    // so we're going with this temporarily.
    final match = pattern.firstMatch(parser.current.content)!;

    // Allow only lists starting with 1 to interrupt paragraphs, if it is an
    // ordered list. See https://spec.commonmark.org/0.30/#example-304.
    // But there should be an exception for nested ordered lists, for example:
    // ```
    // 1. one
    // 2. two
    //   3. three
    //   4. four
    // 5. five
    // ```
    if (parser.parentSyntax is! ListSyntax &&
        match[1] != null &&
        match[1] != '1') {
      return false;
    }

    // An empty list item cannot interrupt a paragraph. See
    // https://spec.commonmark.org/0.30/#example-285
    return match[2]?.isNotEmpty ?? false;
  }

  const ListSyntax();

  /// A list of patterns that can start a valid block within a list item.
  static final blocksInList = [
    blockquotePattern,
    headerPattern,
    hrPattern,
    indentPattern,
    listPattern,
  ];

  @override
  Node parse(BlockParser parser) {
    final match = pattern.firstMatch(parser.current.content);
    final ordered = match![1] != null;

    final taskListParserEnabled =
        this is UnorderedListWithCheckboxSyntax ||
        this is OrderedListWithCheckboxSyntax;
    final items = <ListItem>[];
    var childLines = <Line>[];
    TaskListItemState? taskListItemState;

    void endItem() {
      if (childLines.isNotEmpty) {
        items.add(ListItem(childLines, taskListItemState: taskListItemState));
        childLines = <Line>[];
      }
    }

    String parseTaskListItem(String text) {
      final pattern = RegExp(r'^ {0,3}\[([ xX])\][ \t]');

      if (taskListParserEnabled && pattern.hasMatch(text)) {
        return text.replaceFirstMapped(pattern, (match) {
          taskListItemState = match[1] == ' '
              ? TaskListItemState.unchecked
              : TaskListItemState.checked;

          return '';
        });
      } else {
        taskListItemState = null;
        return text;
      }
    }

    late Match? possibleMatch;
    bool tryMatch(RegExp pattern) {
      possibleMatch = pattern.firstMatch(parser.current.content);
      return possibleMatch != null;
    }

    String? listMarker;
    int? indent;
    // In case the first number in an ordered list is not 1, use it as the
    // "start".
    int? startNumber;

    int? blankLines;

    while (!parser.isDone) {
      final currentIndent =
          parser.current.content.indentation() +
          (parser.current.tabRemaining ?? 0);

      if (parser.current.isBlankLine) {
        childLines.add(parser.current);

        if (blankLines != null) {
          blankLines++;
        }
      } else if (indent != null && indent <= currentIndent) {
        // A list item can begin with at most one blank line. See:
        // https://spec.commonmark.org/0.30/#example-280
        if (blankLines != null && blankLines > 1) {
          break;
        }

        final indentedLine = parser.current.content.dedent(indent);

        childLines.add(
          Line(
            blankLines == null
                ? indentedLine.text
                : parseTaskListItem(indentedLine.text),
            tabRemaining: indentedLine.tabRemaining,
          ),
        );
      } else if (tryMatch(hrPattern)) {
        // Horizontal rule takes precedence to a new list item.
        break;
      } else if (tryMatch(listPattern)) {
        blankLines = null;
        final match = possibleMatch!;
        final textParser = TextParser(parser.current.content);
        var precedingWhitespaces = textParser.moveThroughWhitespace();
        final markerStart = textParser.pos;
        final digits = match[1] ?? '';
        if (digits.isNotEmpty) {
          startNumber ??= int.parse(digits);
          textParser.advanceBy(digits.length);
        }
        textParser.advance();

        // See https://spec.commonmark.org/0.30/#ordered-list-marker
        final marker = textParser.substring(markerStart, textParser.pos);

        var isBlank = true;
        var contentWhitespances = 0;
        var containsTab = false;
        int? contentBlockStart;

        if (!textParser.isDone) {
          containsTab = textParser.charAt() == $tab;
          // Skip the first whitespace.
          textParser.advance();
          contentBlockStart = textParser.pos;
          if (!textParser.isDone) {
            contentWhitespances = textParser.moveThroughWhitespace();

            if (!textParser.isDone) {
              isBlank = false;
            }
          }
        }

        // Changing the bullet or ordered list delimiter starts a new list.
        if (listMarker != null && listMarker.last() != marker.last()) {
          break;
        }

        // End the current list item and start a new one.
        endItem();

        // Start a new list item, the last item will be ended up outside of the
        // `while` loop.
        listMarker = marker;
        precedingWhitespaces += digits.length + 2;
        if (isBlank) {
          // See https://spec.commonmark.org/0.30/#example-278.
          blankLines = 1;
          indent = precedingWhitespaces;
        } else if (contentWhitespances >= 4) {
          // See https://spec.commonmark.org/0.30/#example-270.
          //
          // If the list item starts with indented code, we need to _not_ count
          // any indentation past the required whitespace character.
          indent = precedingWhitespaces;
        } else {
          indent =
              precedingWhitespaces +
              contentWhitespances +
              (parser.current.tabRemaining ?? 0);
        }

        taskListItemState = null;
        var content = contentBlockStart != null && !isBlank
            ? parseTaskListItem(textParser.substring(contentBlockStart))
            : '';

        if (content.isEmpty && containsTab) {
          content = content.prependSpace(2);
        }

        childLines.add(Line(content, tabRemaining: containsTab ? 2 : null));
      } else if (BlockSyntax.isAtBlockEnd(parser)) {
        // Done with the list.
        break;
      } else {
        // If the previous item is a blank line, this means we're done with the
        // list and are starting a new top-level paragraph.
        if (childLines.isNotEmpty && childLines.last.isBlankLine) {
          parser.encounteredBlankLine = true;
          break;
        }

        // Anything else is paragraph continuation text.
        childLines.add(parser.current);
      }
      parser.advance();
    }

    endItem();
    final itemNodes = <Element>[];

    items.forEach(_removeLeadingEmptyLine);
    final anyEmptyLines = _removeTrailingEmptyLines(items);
    var anyEmptyLinesBetweenBlocks = false;
    var containsTaskList = false;
    const taskListClass = 'task-list-item';

    for (final item in items) {
      Element? checkboxToInsert;
      if (item.taskListItemState != null) {
        containsTaskList = true;
        checkboxToInsert = Element.withTag('input')
          ..attributes['type'] = 'checkbox';
        if (item.taskListItemState == TaskListItemState.checked) {
          checkboxToInsert.attributes['checked'] = 'true';
        }
      }

      final itemParser = BlockParser(item.lines, parser.document);
      final children = itemParser.parseLines(parentSyntax: this);
      final itemElement = checkboxToInsert == null
          ? Element('li', children)
          : (Element('li', _addCheckbox(children, checkboxToInsert))
              ..attributes['class'] = taskListClass);

      itemNodes.add(itemElement);
      anyEmptyLinesBetweenBlocks =
          anyEmptyLinesBetweenBlocks || itemParser.encounteredBlankLine;
    }

    // Must strip paragraph tags if the list is "tight".
    // https://spec.commonmark.org/0.30/#lists
    final listIsTight = !anyEmptyLines && !anyEmptyLinesBetweenBlocks;

    if (listIsTight) {
      // We must post-process the list items, converting any top-level paragraph
      // elements to just text elements.
      for (final item in itemNodes) {
        final isTaskList = item.attributes['class'] == taskListClass;
        final children = item.children;
        if (children != null) {
          Node? lastNode;
          for (var i = 0; i < children.length; i++) {
            final child = children[i];
            if (child is Element && child.tag == 'p') {
              final childContent = child.children!;
              if (lastNode is Element && !isTaskList) {
                childContent.insert(0, Text('\n'));
              }

              children
                ..removeAt(i)
                ..insertAll(i, childContent);
            }

            lastNode = child;
          }
        }
      }
    }

    final listElement = Element(ordered ? 'ol' : 'ul', itemNodes);
    if (ordered && startNumber != 1) {
      listElement.attributes['start'] = '$startNumber';
    }

    if (containsTaskList) {
      listElement.attributes['class'] = 'contains-task-list';
    }
    return listElement;
  }

  List<Node> _addCheckbox(List<Node> children, Element checkbox) {
    if (children.isNotEmpty) {
      final firstChild = children.first;
      if (firstChild is Element && firstChild.tag == 'p') {
        firstChild.children!.insert(0, checkbox);
        return children;
      }
    }
    return [checkbox, ...children];
  }

  void _removeLeadingEmptyLine(ListItem item) {
    if (item.lines.isNotEmpty && item.lines.first.isBlankLine) {
      item.lines.removeAt(0);
    }
  }

  /// Removes any trailing empty lines and notes whether any items are separated
  /// by such lines.
  bool _removeTrailingEmptyLines(List<ListItem> items) {
    var anyEmpty = false;
    for (var i = 0; i < items.length; i++) {
      if (items[i].lines.length == 1) continue;
      while (items[i].lines.isNotEmpty && items[i].lines.last.isBlankLine) {
        if (i < items.length - 1) {
          anyEmpty = true;
        }
        items[i].lines.removeLast();
      }
    }
    return anyEmpty;
  }
}
