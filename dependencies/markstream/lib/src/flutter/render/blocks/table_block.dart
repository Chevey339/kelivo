import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../../core/ast/nodes.dart';
import '../../../core/ast/source_span.dart';
import '../../../core/serialize/to_markdown.dart';
import '../../../core/serialize/to_plain_text.dart';
import '../../extensions/registry.dart';
import '../../selection/table_selection.dart';
import '../../selection/selection_controller.dart';
import '../../theme/markstream_theme.dart';
import '../block_list.dart';
import '../chrome.dart';
import '../prose_direction.dart';
import '../../performance_limits.dart';

typedef _CellWidthContent = ({String text, bool hasImage});

class MarkstreamTableBlock extends StatefulWidget {
  const MarkstreamTableBlock({
    super.key,
    required this.node,
    required this.source,
    required this.theme,
    required this.extensions,
    required this.labels,
    required this.buildCell,
    this.streaming = false,
    this.exporting = false,
  });
  final TableNode node;
  final String source;
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
  final _scroll = ScrollController();
  Object? _columnMeasureKey;
  List<double> _preferredWidths = const [];
  List<_CellWidthContent>? _measuredHeader;
  int _measuredRows = 0;
  int _visibleRows = PerformanceLimits.initialTableRows;
  int _revealedRows = 0;
  bool _capturing = false;
  @override
  void didUpdateWidget(MarkstreamTableBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.node.span.start != oldWidget.node.span.start ||
        !widget.source.startsWith(oldWidget.source)) {
      _visibleRows = PerformanceLimits.initialTableRows;
      _revealedRows = 0;
      if (_scroll.hasClients) _scroll.jumpTo(0);
    }
  }

  bool _prepareRange(SourceSpan range) {
    final rows = widget.node.children;
    final index = rows.indexWhere((row) => row.span.contains(range.start));
    final count = math.max(
      _revealedRows,
      widget.streaming ? PerformanceLimits.streamingTableRows : _visibleRows,
    );
    if (index < count) return true;
    setState(() {
      _revealedRows = index + 1;
      _visibleRows = math.max(_visibleRows, index + 1);
    });
    return false;
  }

  @override
  void dispose() {
    _scroll.dispose();
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
          width > PerformanceLimits.tableImageDimension ||
          height > PerformanceLimits.tableImageDimension ||
          width * height > PerformanceLimits.tableImagePixels)
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
    action: MarkstreamAction(
      kind: kind,
      label: label,
      onInvoke: invoke,
      chrome: widget.theme.chrome,
    ),
  );

  Widget _cell(TableRowNode row, int column) {
    final cell = column < row.children.length ? row.children[column] : null;
    final alignment = column < widget.node.alignments.length
        ? widget.node.alignments[column]
        : TableAlignment.none;
    return directionalBlock(
      context,
      cell == null
          ? null
          : widget.extensions.proseDirection.forNodes(cell.children),
      Padding(
        padding: widget.theme.table.cellPadding,
        child: DefaultTextStyle.merge(
          textAlign: switch (alignment) {
            TableAlignment.center => TextAlign.center,
            TableAlignment.right => TextAlign.right,
            TableAlignment.left => TextAlign.left,
            TableAlignment.none => TextAlign.start,
          },
          child: Align(
            alignment: switch (alignment) {
              TableAlignment.center => Alignment.center,
              TableAlignment.right => Alignment.centerRight,
              TableAlignment.left => Alignment.centerLeft,
              TableAlignment.none => AlignmentDirectional.centerStart,
            },
            child: cell != null
                ? Builder(
                    builder: (context) => widget.buildCell(
                      context,
                      cell,
                      row.header
                          ? widget.theme.table.heading
                          : widget.theme.table.body,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ),
      align: false,
    );
  }

  List<double> _measureColumns(BuildContext context, int columns, int count) {
    final theme = widget.theme.table;
    final rows = widget.node.children;
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final locale = Localizations.maybeLocaleOf(context);
    final padding = theme.cellPadding.resolve(direction).horizontal;
    final defaults = DefaultTextStyle.of(context).style;
    final bold = MediaQuery.boldTextOf(context);
    final letterSpacing = MediaQuery.maybeLetterSpacingOverrideOf(context);
    final wordSpacing = MediaQuery.maybeWordSpacingOverrideOf(context);
    TextStyle measureStyle(TextStyle style) => defaults
        .merge(style)
        .copyWith(
          fontWeight: bold ? FontWeight.bold : null,
          letterSpacing: letterSpacing,
          wordSpacing: wordSpacing,
        );

    final heading = measureStyle(theme.heading);
    final body = measureStyle(theme.body);
    final headerOnly = widget.streaming && !_capturing && !widget.exporting;
    // The open table is reparsed on append, including its unchanged header.
    // Match its rendered content so body updates don't reshape the labels.
    final header = headerOnly
        ? rows.first.children.map(_cellWidthContent).toList()
        : null;
    final key = (
      headerOnly ? rows.first.header : widget.node,
      widget.exporting,
      columns,
      heading,
      body,
      scaler,
      direction,
      locale,
      padding,
    );
    final cached =
        _columnMeasureKey == key && listEquals(_measuredHeader, header);
    final measuredRows = cached ? _measuredRows : 0;
    final sampleRows = headerOnly ? 1 : count;
    if (measuredRows >= sampleRows) return _preferredWidths;

    final minimum = math.max(1.0, padding + scaler.scale(24));
    final maximum = math.max(minimum, padding + scaler.scale(640));
    final preferred = cached
        ? List<double>.of(_preferredWidths)
        : List.filled(columns, minimum);
    final painter = TextPainter(
      textDirection: direction,
      textScaler: scaler,
      locale: locale,
    );
    try {
      for (var rowIndex = measuredRows; rowIndex < sampleRows; rowIndex++) {
        final row = rows[rowIndex];
        final style = row.header ? heading : body;
        for (
          var column = 0;
          column < math.min(columns, row.children.length);
          column++
        ) {
          if (preferred[column] >= maximum) continue;
          final (:text, :hasImage) =
              header?[column] ?? _cellWidthContent(row.children[column]);
          if (text.length > PerformanceLimits.staticNativeCharacters) {
            preferred[column] = maximum;
            continue;
          }
          painter.text = TextSpan(text: text, style: style);
          painter.layout();
          final textWidth = painter.maxIntrinsicWidth;
          // Images can have empty alt text but still need room in the cell.
          final contentWidth = hasImage ? math.max(textWidth, 240) : textWidth;
          preferred[column] = math.max(
            preferred[column],
            math.min(maximum, padding + contentWidth),
          );
        }
      }
    } finally {
      painter.dispose();
    }
    // A standalone PNG temporarily lays out hidden rows. Their widths do not
    // persist in the interactive table unless the user reveals those rows.
    if (!_capturing) {
      _columnMeasureKey = key;
      _preferredWidths = preferred;
      _measuredHeader = header;
      _measuredRows = sampleRows;
    }
    return preferred;
  }

  _CellWidthContent _cellWidthContent(TableCellNode cell) =>
      switch (cell.children) {
        [TextNode(:final text)] => (text: text, hasImage: false),
        _ => (text: toPlainText(cell), hasImage: _hasImage(cell)),
      };

  bool _hasImage(MarkdownNode node) =>
      node is ImageNode ||
      (node is HtmlElementNode && node.tag == 'img') ||
      node.children.any(_hasImage);

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
        : math.min(
            rows.length,
            math.max(
              _revealedRows,
              widget.streaming
                  ? PerformanceLimits.streamingTableRows
                  : _visibleRows,
            ),
          );
    final content = LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final desktop =
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.windows;
        final mobile = !desktop;
        final compact = mobile || width < theme.compactBreakpoint;
        final preferred = columns == 1
            ? [width]
            : _measureColumns(context, columns, count);
        final preferredTotal = preferred.fold(0.0, (sum, value) => sum + value);
        final wrapWidth = MediaQuery.textScalerOf(
          context,
        ).scale(theme.columnWrapWidth);
        final minimums = [
          for (final value in preferred) math.min(value, wrapWidth),
        ];
        final minimumTotal = minimums.fold(0.0, (sum, value) => sum + value);
        final scroll = !widget.exporting && minimumTotal > width;
        final tableWidth = scroll ? minimumTotal : width;
        // A message export has a fixed canvas. Give each cell a common share
        // before squeezing the rest so a short label keeps room after padding.
        final exportFloor = tableWidth < minimumTotal
            ? math.min(tableWidth / columns, minimums.reduce(math.min))
            : 0.0;
        final exportFloorTotal = exportFloor * columns;
        double columnWidth(int column) {
          if (columns == 1) return width;
          if (tableWidth >= preferredTotal) {
            return preferred[column] * (tableWidth / preferredTotal);
          }
          if (tableWidth < minimumTotal) {
            final fraction =
                math.max(0.0, tableWidth - exportFloorTotal) /
                (minimumTotal - exportFloorTotal);
            return exportFloor + (minimums[column] - exportFloor) * fraction;
          }
          final fraction =
              (tableWidth - minimumTotal) / (preferredTotal - minimumTotal);
          return minimums[column] +
              (preferred[column] - minimums[column]) * fraction;
        }

        final radius = compact ? theme.compactRadius : theme.wideRadius;
        final header = _capturing
            ? Color.alphaBlend(
                theme.headerBackgroundColor,
                widget.theme.colors.fillBlockOpaque,
              )
            : theme.headerBackgroundColor;
        final body = _capturing
            ? widget.theme.colors.fillBlockOpaque
            : theme.bodyBackgroundColor;
        final table = Table(
          columnWidths: {
            for (var column = 0; column < columns; column++)
              column: FixedColumnWidth(columnWidth(column)),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          border: TableBorder(
            horizontalInside: BorderSide(
              color: theme.borderColor,
              width: MarkstreamTheme.stroke,
            ),
            verticalInside: BorderSide(
              color: theme.borderColor,
              width: MarkstreamTheme.stroke,
            ),
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
                      child: _cell(rows[row], column),
                    ),
                ],
              ),
          ],
        );
        Widget clipped = ColoredBox(
          color: mobile && !_capturing ? Colors.transparent : body,
          // Disable culling for capture while keeping the cells mounted. A
          // resized image can keep its previously decoded frame this way.
          child: BlockCullScope(
            enabled: !all && BlockCullScope.of(context),
            child: table,
          ),
        );
        if (!mobile) {
          clipped = DecoratedBox(
            key: const ValueKey('markstream-table-surface'),
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              border: Border.all(
                color: theme.outerBorderColor,
                width: MarkstreamTheme.stroke,
              ),
              borderRadius: BorderRadius.circular(radius),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: clipped,
            ),
          );
        }
        final surface = RepaintBoundary(key: _boundary, child: clipped);
        final actionContext = TableActionContext(
          table: widget.node,
          theme: widget.theme,
          capturePng: _capture,
        );
        final toolbar = SelectionContainer.disabled(
          child: mobile && widget.extensions.mobileTableToolbarBuilder != null
              ? widget.extensions.mobileTableToolbarBuilder!(
                  context,
                  actionContext,
                )
              : Container(
                  key: const ValueKey('markstream-table-toolbar'),
                  height: mobile
                      ? widget.theme.chrome.height
                      : widget.theme.chrome.actionSize,
                  padding: mobile
                      ? widget.theme.chrome.padding
                      : EdgeInsets.zero,
                  decoration: mobile
                      ? BoxDecoration(
                          color: widget.theme.chrome.background,
                          border: Border(
                            bottom: BorderSide(
                              color: widget.theme.chrome.divider,
                              width: MarkstreamTheme.stroke,
                            ),
                          ),
                        )
                      : null,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    primary: false,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: mobile
                            ? math.max(
                                0,
                                width -
                                    widget.theme.chrome.padding
                                        .resolve(Directionality.of(context))
                                        .horizontal,
                              )
                            : 0,
                        minHeight: mobile
                            ? widget.theme.chrome.height -
                                  MarkstreamTheme.stroke
                            : widget.theme.chrome.actionSize,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
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
                            actionContext,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        );
        Widget result = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!widget.exporting && mobile) toolbar,
            if (scroll)
              SingleChildScrollView(
                key: const ValueKey('markstream-table-scroll'),
                controller: _scroll,
                physics: const ClampingScrollPhysics(),
                primary: false,
                scrollDirection: Axis.horizontal,
                child: SizedBox(width: tableWidth, child: surface),
              )
            else
              surface,
            if (!all &&
                !widget.streaming &&
                rows.length > PerformanceLimits.initialTableRows)
              SelectionContainer.disabled(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    if (_visibleRows > PerformanceLimits.initialTableRows)
                      _action(
                        MarkstreamActionKind.collapse,
                        widget.labels.collapse,
                        () async {
                          setState(() {
                            _visibleRows = PerformanceLimits.initialTableRows;
                            _revealedRows = 0;
                          });
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
                              _visibleRows + PerformanceLimits.tablePageRows,
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
          ],
        );
        if (mobile) {
          result = Container(
            key: const ValueKey('markstream-table-surface'),
            decoration: BoxDecoration(
              color: theme.bodyBackgroundColor,
              borderRadius: BorderRadius.circular(theme.compactRadius),
            ),
            foregroundDecoration: BoxDecoration(
              border: Border.all(
                color: theme.outerBorderColor,
                width: MarkstreamTheme.stroke,
              ),
              borderRadius: BorderRadius.circular(theme.compactRadius),
            ),
            clipBehavior: Clip.antiAlias,
            child: result,
          );
        } else if (!widget.exporting) {
          result = _DesktopTableToolbar(
            height: widget.theme.chrome.actionSize,
            toolbar: toolbar,
            child: result,
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: SizedBox(width: width, child: result),
        );
      },
    );
    return SourceRangePreparer(
      span: widget.node.span,
      prepare: _prepareRange,
      child: SelectionContainer.maybeOf(context) == null
          ? content
          : SelectionContainer(delegate: _selection, child: content),
    );
  }
}

/// Keeps actions outside table layout so hovering cannot move selection targets.
class _DesktopTableToolbar extends StatefulWidget {
  const _DesktopTableToolbar({
    required this.height,
    required this.toolbar,
    required this.child,
  });
  final double height;
  final Widget toolbar, child;

  @override
  State<_DesktopTableToolbar> createState() => _DesktopTableToolbarState();
}

class _DesktopTableToolbarState extends State<_DesktopTableToolbar> {
  final _overlay = OverlayPortalController()..show();
  bool _hovered = false, _toolbarHovered = false, _focused = false;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.maybeOf(context);
    final visible =
        _hovered ||
        _toolbarHovered ||
        _focused ||
        (media?.accessibleNavigation ?? false);
    final reducedMotion = media?.disableAnimations ?? false;
    return Focus(
      onFocusChange: (value) => setState(() => _focused = value),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: OverlayPortal.overlayChildLayoutBuilder(
          controller: _overlay,
          overlayChildBuilder: (context, info) {
            final anchor = MatrixUtils.transformRect(
              info.childPaintTransform,
              Offset.zero & info.childSize,
            );
            final overlayBounds = Offset.zero & info.overlaySize;
            var visibleBounds = overlayBounds;
            // Read the main-tree anchor, not the overlay's rendering ancestors.
            // Unlike paragraph culling, floating controls need the exact clip.
            final clip = viewportClips(
              this.context.findRenderObject()! as RenderBox,
              paintOverflow: 0,
            ).paint;
            if (clip != null) {
              visibleBounds = visibleBounds.intersect(
                MatrixUtils.transformRect(info.childPaintTransform, clip),
              );
            }
            final above = anchor.top - widget.height;
            bool fitsAbove(Rect area) =>
                above >= area.top && anchor.top <= area.bottom;
            bool fitsBelow(Rect area) =>
                anchor.bottom >= area.top &&
                anchor.bottom + widget.height <= area.bottom;
            final fullyVisible =
                anchor.left >= visibleBounds.left &&
                anchor.right <= visibleBounds.right &&
                anchor.top >= visibleBounds.top &&
                anchor.bottom <= visibleBounds.bottom;
            // Short embedded scroll views can shrink to exactly the content.
            // Their fully visible tables may borrow outside overlay space.
            final bounds =
                fullyVisible &&
                    !fitsAbove(visibleBounds) &&
                    !fitsBelow(visibleBounds)
                ? overlayBounds
                : visibleBounds;
            // A table can fill the viewport. Wait for an outside edge to become
            // visible rather than covering cells and intercepting selection.
            final canShow =
                !visibleBounds.isEmpty &&
                anchor.overlaps(visibleBounds) &&
                (fitsAbove(bounds) || fitsBelow(bounds));
            final show = visible && canShow;
            final width = math.min(anchor.width, math.max(0.0, bounds.width));
            final top = fitsAbove(bounds) ? above : anchor.bottom;
            return Positioned(
              left: anchor.left.clamp(
                bounds.left,
                math.max(bounds.left, bounds.right - width),
              ),
              top: top.clamp(
                bounds.top,
                math.max(bounds.top, bounds.bottom - widget.height),
              ),
              width: width,
              child: IgnorePointer(
                ignoring: !show,
                child: Stack(
                  children: [
                    // Keep hover across the clear strip without taking clicks.
                    Positioned.fill(
                      child: MouseRegion(
                        opaque: false,
                        hitTestBehavior: HitTestBehavior.translucent,
                        onEnter: (_) => setState(() => _toolbarHovered = true),
                        onExit: (_) => setState(() => _toolbarHovered = false),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: MouseRegion(
                        onEnter: (_) => setState(() => _toolbarHovered = true),
                        onExit: (_) => setState(() => _toolbarHovered = false),
                        child: ExcludeFocus(
                          excluding: !show,
                          child: AnimatedOpacity(
                            key: const ValueKey(
                              'markstream-table-hover-toolbar',
                            ),
                            opacity: show ? 1 : 0,
                            duration: reducedMotion || !canShow
                                ? Duration.zero
                                : const Duration(milliseconds: 160),
                            curve: Curves.easeOutCubic,
                            child: widget.toolbar,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}
