import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'stable_selection_container.dart';

/// Keeps table copy in source row/column order, including empty cells, while
/// the standard delegate owns gesture routing and selection geometry.
class TableSelectionDelegate extends StableSelectionDelegate {
  final _cells = <_TableCellSelectionState>{};

  List<_TableCellSelectionState> get _orderedCells =>
      _cells.toList()..sort((a, b) {
        final row = a.widget.row.compareTo(b.widget.row);
        return row != 0 ? row : a.widget.column.compareTo(b.widget.column);
      });

  String _separator(_TableCellSelectionState a, _TableCellSelectionState b) =>
      a.widget.row == b.widget.row
      ? '\t' * (b.widget.column - a.widget.column)
      : '\n' * (b.widget.row - a.widget.row);

  @override
  SelectedContent? getSelectedContent() {
    final cells = _orderedCells;
    var start = cells.indexWhere(
      (cell) => cell.delegate.getSelectedContent() != null,
    );
    if (start < 0) return null;
    var end = cells.lastIndexWhere(
      (cell) => cell.delegate.getSelectedContent() != null,
    );
    final range = getSelection();
    final coversTable =
        range != null &&
        math.min(range.startOffset, range.endOffset) == 0 &&
        math.max(range.startOffset, range.endOffset) == contentLength;
    if (coversTable) {
      start = 0;
      end = cells.length - 1;
    }
    final buffer = StringBuffer();
    for (var index = start; index <= end; index++) {
      if (index > start) {
        buffer.write(_separator(cells[index - 1], cells[index]));
      }
      buffer.write(
        _tsvCell(cells[index].delegate.getSelectedContent()?.plainText ?? ''),
      );
    }
    return SelectedContent(plainText: buffer.toString());
  }

  String _tsvCell(String value) {
    // Soft wrap opportunities are layout aids, not TSV cell content.
    final text = value.replaceAll('\u200B', '');
    return text.contains(RegExp('[\\t\\r\\n"]'))
        ? '"${text.replaceAll('"', '""')}"'
        : text;
  }
}

/// Creates one selection participant per cell. Explicit coordinates prevent an
/// empty, unregistered text widget from shifting every subsequent TSV column.
class TableCellSelection extends StatefulWidget {
  const TableCellSelection({
    super.key,
    required this.table,
    required this.row,
    required this.column,
    required this.child,
  });

  final TableSelectionDelegate table;
  final int row;
  final int column;
  final Widget child;

  @override
  State<TableCellSelection> createState() => _TableCellSelectionState();
}

class _TableCellSelectionState extends State<TableCellSelection> {
  final delegate = StableSelectionDelegate();

  @override
  void initState() {
    super.initState();
    widget.table._cells.add(this);
  }

  @override
  void didUpdateWidget(covariant TableCellSelection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.table != widget.table) {
      oldWidget.table._cells.remove(this);
      widget.table._cells.add(this);
    }
  }

  @override
  Widget build(BuildContext context) =>
      SelectionContainer.maybeOf(context) == null
      ? widget.child
      : SelectionContainer(delegate: delegate, child: widget.child);

  @override
  void dispose() {
    widget.table._cells.remove(this);
    delegate.dispose();
    super.dispose();
  }
}
