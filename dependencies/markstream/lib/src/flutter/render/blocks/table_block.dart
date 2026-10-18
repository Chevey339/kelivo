import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../../core/ast/nodes.dart';
import '../../../core/serialize/to_markdown.dart';
import '../../../core/serialize/to_plain_text.dart';
import '../../extensions/registry.dart';
import '../../selection/table_selection.dart';
import '../../theme/markstream_theme.dart';
import '../block_list.dart';
import '../chrome.dart';

class MarkstreamTableBlock extends StatefulWidget {
  const MarkstreamTableBlock({
    super.key,
    required this.node,
    required this.theme,
    required this.extensions,
    required this.labels,
    required this.buildCell,
    this.streaming = false,
    this.exporting = false,
  });
  final TableNode node;
  final MarkstreamTheme theme;
  final MarkstreamExtensions extensions;
  final MarkstreamLabels labels;
  final Widget Function(BuildContext, TableCellNode, TextStyle) buildCell;
  final bool streaming, exporting;
  @override
  State<MarkstreamTableBlock> createState() => _MarkstreamTableBlockState();
}

class _MarkstreamTableBlockState extends State<MarkstreamTableBlock> {
  final _selection = TableSelectionDelegate();
  final _boundary = GlobalKey();
  int _visibleRows = 40;
  bool _capturing = false;
  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  Future<Uint8List> _capture(double pixelRatio) async {
    if (!pixelRatio.isFinite || pixelRatio <= 0)
      throw ArgumentError.value(pixelRatio, 'pixelRatio');
    if (!mounted || _capturing)
      throw StateError('Table capture is unavailable');
    final node = widget.node;
    setState(() => _capturing = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || !identical(node, widget.node))
        throw StateError('Table changed during capture');
      final boundary =
          _boundary.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null || !boundary.hasSize)
        throw StateError('Table has not been laid out');
      final width = (boundary.size.width * pixelRatio).ceil();
      final height = (boundary.size.height * pixelRatio).ceil();
      if (width <= 0 ||
          height <= 0 ||
          width > 32767 ||
          height > 32767 ||
          width * height > 64000000)
        throw StateError('Table image exceeds the capture size limit');
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        if (bytes == null) throw StateError('PNG encoding failed');
        return bytes.buffer.asUint8List(
          bytes.offsetInBytes,
          bytes.lengthInBytes,
        );
      } finally {
        image.dispose();
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Widget _action(
    MarkstreamActionKind kind,
    String label,
    Future<void> Function() invoke,
  ) => MarkstreamActionButton(
    builder: widget.extensions.actionButtonBuilder,
    action: MarkstreamAction(kind: kind, label: label, onInvoke: invoke),
  );
  @override
  Widget build(BuildContext context) {
    final theme = widget.theme.table;
    final rows = widget.node.children;
    if (rows.isEmpty) return const SizedBox.shrink();
    final columns = rows.first.children.length;
    if (columns == 0) return const SizedBox.shrink();
    final all = _capturing || widget.exporting;
    final count = all
        ? rows.length
        : math.min(rows.length, widget.streaming ? 30 : _visibleRows);
    final content = LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final desktop =
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.windows;
        final compact = !desktop || width < theme.compactBreakpoint;
        final columnWidth = columns == 1
            ? width.clamp(
                theme.singleColumnMinWidth,
                theme.singleColumnMaxWidth,
              )
            : (width / theme.visibleColumns).clamp(
                theme.columnMinWidth,
                theme.columnMaxWidth,
              );
        final scroll = compact && columns >= 4 && columnWidth * columns > width;
        final radius = compact ? theme.compactRadius : theme.wideRadius;
        final header = _capturing
            ? theme.headerBackgroundColor.withValues(alpha: 1)
            : theme.headerBackgroundColor;
        final body = _capturing
            ? theme.bodyBackgroundColor.withValues(alpha: 1)
            : theme.bodyBackgroundColor;
        Widget table = Table(
          defaultColumnWidth: scroll
              ? FixedColumnWidth(columnWidth)
              : const FlexColumnWidth(),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          border: TableBorder(
            horizontalInside: BorderSide(color: theme.borderColor, width: .5),
            verticalInside: BorderSide(color: theme.borderColor, width: .5),
          ),
          children: [
            for (var row = 0; row < count; row++)
              TableRow(
                decoration: rows[row].header
                    ? BoxDecoration(color: header)
                    : null,
                children: [
                  for (var column = 0; column < columns; column++)
                    TableCellSelection(
                      table: _selection,
                      row: row,
                      column: column,
                      child: Padding(
                        padding: theme.cellPadding,
                        child: Align(
                          alignment: switch (column <
                                  widget.node.alignments.length
                              ? widget.node.alignments[column]
                              : TableAlignment.none) {
                            TableAlignment.center => Alignment.center,
                            TableAlignment.right => Alignment.centerRight,
                            _ => Alignment.centerLeft,
                          },
                          child: column < rows[row].children.length
                              ? widget.buildCell(
                                  context,
                                  rows[row].children[column],
                                  rows[row].header ? theme.heading : theme.body,
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        );
        // Capture lays out every row and disables descendant viewport culling.
        if (all) {
          final completeTable = table;
          table = BlockList(
            blocks: [completeTable],
            signature: completeTable,
            cullToViewport: false,
            itemBuilder: (_, index) => completeTable,
          );
        }
        final surface = RepaintBoundary(
          key: _boundary,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: ColoredBox(color: body, child: table),
          ),
        );
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!widget.exporting)
                SelectionContainer.disabled(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    primary: false,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: width,
                        minHeight: theme.toolbarHeight,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _action(
                            MarkstreamActionKind.copyMarkdown,
                            widget.labels.copyMarkdown,
                            () => Clipboard.setData(
                              ClipboardData(text: toMarkdown(widget.node)),
                            ),
                          ),
                          _action(
                            MarkstreamActionKind.copyCsv,
                            widget.labels.copyCsv,
                            () => Clipboard.setData(
                              ClipboardData(text: tableToCsv(widget.node)),
                            ),
                          ),
                          ...?widget.extensions.tableExtraActions?.call(
                            context,
                            TableActionContext(
                              table: widget.node,
                              theme: widget.theme,
                              capturePng: _capture,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (scroll)
                SingleChildScrollView(
                  primary: false,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(width: columnWidth * columns, child: surface),
                )
              else
                surface,
              if (!all && !widget.streaming && rows.length > 40)
                SelectionContainer.disabled(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      if (_visibleRows > 40)
                        _action(
                          MarkstreamActionKind.collapse,
                          widget.labels.collapse,
                          () async {
                            setState(() => _visibleRows = 40);
                          },
                        ),
                      if (count < rows.length)
                        _action(
                          MarkstreamActionKind.showMore,
                          widget.labels.moreRows(rows.length - count),
                          () async {
                            setState(
                              () => _visibleRows = math.min(
                                rows.length,
                                _visibleRows + 100,
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
    return SelectionContainer.maybeOf(context) == null
        ? content
        : SelectionContainer(delegate: _selection, child: content);
  }
}
