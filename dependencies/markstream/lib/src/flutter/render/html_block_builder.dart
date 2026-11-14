part of 'block_builder.dart';

extension _HtmlBlockRenderer on MarkstreamRenderer {
  /// HTML block shells share the same paragraph, fold and selection pipeline.
  Widget htmlFlow(
    BuildContext context,
    List<InlineNode> nodes,
    TextStyle style, {
    required bool streaming,
  }) {
    final widgets = <Widget>[];
    var run = <InlineNode>[];
    void flush() {
      while (run.isNotEmpty &&
          run.first is TextNode &&
          (run.first as TextNode).text.trim().isEmpty) {
        run.removeAt(0);
      }
      while (run.isNotEmpty &&
          run.last is TextNode &&
          (run.last as TextNode).text.trim().isEmpty) {
        run.removeLast();
      }
      if (run.isNotEmpty) {
        widgets.add(
          inlineText(context, run.first, run, style, streaming: streaming),
        );
      }
      run = [];
    }

    for (final node in nodes) {
      if (node is! HtmlElementNode || !htmlBlockTags.contains(node.tag)) {
        run.add(node);
        continue;
      }
      flush();
      Widget child;
      if (node.tag == 'details') {
        final summary = node.children
            .whereType<HtmlElementNode>()
            .where((child) => child.tag == 'summary')
            .firstOrNull;
        child = MarkstreamDetailsBlock(
          node: node,
          expansionState: detailsExpansionState,
          stateKey: detailsStateKey,
          source: node.span.slice(document.source),
          open: node.attributes.containsKey('open'),
          theme: theme,
          summary: summary == null
              ? SelectionContainer.disabled(
                  child: Text(labels.details, style: theme.details.summary),
                )
              : _blockContent.inlineText(
                  context,
                  summary,
                  summary.children,
                  theme.details.summary,
                  streaming: streaming,
                ),
          body: (context) => _blockContent.htmlFlow(
            context,
            node.children.where((child) => !identical(child, summary)).toList(),
            style.copyWith(color: theme.colors.ink2),
            streaming: streaming,
          ),
        );
      } else if (RegExp(r'^h[1-6]$').hasMatch(node.tag)) {
        child = Padding(
          padding: theme.headingPadding,
          child: Semantics(
            header: true,
            child: htmlFlow(
              context,
              node.children,
              theme.headings[int.parse(node.tag.substring(1)) - 1],
              streaming: streaming,
            ),
          ),
        );
      } else if (node.tag == 'blockquote') {
        child = Padding(
          padding: theme.quote.margin,
          child: CustomPaint(
            painter: _QuoteBar(theme.quote, Directionality.of(context)),
            child: Padding(
              padding: theme.quote.padding,
              child: htmlFlow(
                context,
                node.children,
                style,
                streaming: streaming,
              ),
            ),
          ),
        );
      } else if (node.tag == 'hr') {
        child = Padding(
          padding: theme.rulePadding,
          child: ColoredBox(
            color: theme.ruleColor,
            child: SizedBox(
              width: double.infinity,
              height: theme.ruleThickness,
            ),
          ),
        );
      } else if (node.tag == 'ul' || node.tag == 'ol') {
        child = _htmlList(context, node, style, streaming);
      } else if (node.tag == 'table') {
        child = _htmlTable(context, node, style, streaming);
      } else if (node.tag == 'pre') {
        final fragments = <TextNode>[];
        void collect(InlineNode child) {
          if (child is TextNode)
            fragments.add(child);
          else
            for (final nested in child.children) collect(nested as InlineNode);
        }

        node.children.forEach(collect);
        final code = node.children
            .whereType<HtmlElementNode>()
            .where((n) => n.tag == 'code')
            .firstOrNull;
        final language =
            RegExp(
              r'(?:^|\s)language-([\w+-]+)',
            ).firstMatch(code?.attributes['class'] ?? '')?.group(1) ??
            '';
        child = MarkstreamCodeBlock(
          node: CodeBlockNode(
            span: node.span,
            children: fragments,
            info: language,
          ),
          theme: theme,
          extensions: extensions,
          options: codeOptions,
          labels: labels,
          highlighter: codeHighlighter,
          streaming: streaming,
          exporting: exporting,
        );
      } else {
        child = htmlFlow(context, node.children, style, streaming: streaming);
      }
      if (node.tag == 'center' || node.attributes['align'] == 'center') {
        child = Align(alignment: Alignment.topCenter, child: child);
      } else if (node.attributes['align'] == 'right') {
        child = Align(alignment: Alignment.topRight, child: child);
      }
      widgets.add(
        DocumentSelectionGroup(
          node: node,
          separator: node.tag == 'ul' || node.tag == 'ol' ? '\n' : '\n\n',
          child: child,
        ),
      );
    }
    flush();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < widgets.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : theme.blockSpacing),
            child: widgets[i],
          ),
      ],
    );
  }

  Widget _htmlList(
    BuildContext context,
    HtmlElementNode node,
    TextStyle style,
    bool streaming,
  ) {
    final children = <Widget>[];
    var run = <InlineNode>[];
    var index = int.tryParse(node.attributes['start'] ?? '') ?? 1;
    void flush() {
      if (run.any((n) => n is! TextNode || n.text.trim().isNotEmpty)) {
        children.add(htmlFlow(context, run, style, streaming: streaming));
      }
      run = [];
    }

    for (final item in node.children) {
      if (item is! HtmlElementNode || item.tag != 'li') {
        run.add(item);
        continue;
      }
      flush();
      children.add(
        DocumentSelectionGroup(
          node: item,
          prefix: node.tag == 'ol' ? '$index. ' : '- ',
          continuation: '  ',
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Padding(
                padding: theme.listMarkerPadding,
                child: SelectionContainer.disabled(
                  child: Text(node.tag == 'ol' ? '$index.' : '•', style: style),
                ),
              ),
              Expanded(
                child: htmlFlow(
                  context,
                  item.children,
                  style,
                  streaming: streaming,
                ),
              ),
            ],
          ),
        ),
      );
      index++;
    }
    flush();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _htmlTable(
    BuildContext context,
    HtmlElementNode node,
    TextStyle style,
    bool streaming,
  ) {
    final children = <Widget>[];
    var rows = <HtmlElementNode>[];
    var run = <InlineNode>[];
    void flushRows() {
      if (rows.isNotEmpty) {
        children.add(_htmlTableRows(context, rows, streaming));
        rows = [];
      }
    }

    void flushRun() {
      if (run.isNotEmpty) {
        children.add(htmlFlow(context, run, style, streaming: streaming));
        run = [];
      }
    }

    void collect(HtmlElementNode element) {
      for (final child in element.children) {
        if (child is TextNode && child.text.trim().isEmpty) {
          if (run.isNotEmpty) run.add(child);
          continue;
        }
        if (child is HtmlElementNode &&
            const {'thead', 'tbody', 'tfoot'}.contains(child.tag)) {
          collect(child);
        } else if (isNativeHtmlTableRow(child)) {
          flushRun();
          rows.add(child as HtmlElementNode);
        } else {
          flushRows();
          run.add(child);
        }
      }
    }

    collect(node);
    flushRows();
    flushRun();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _htmlTableRows(
    BuildContext context,
    List<HtmlElementNode> rows,
    bool streaming,
  ) {
    final cells = [
      for (final row in rows)
        row.children
            .whereType<HtmlElementNode>()
            .where((n) => n.tag == 'td' || n.tag == 'th')
            .toList(),
    ];
    final columns = cells.fold<int>(
      0,
      (max, row) => row.length > max ? row.length : max,
    );
    final owners = {
      for (final row in cells)
        for (final cell in row) cell.span: cell,
    };
    final span = SourceSpan(rows.first.span.start, rows.last.span.end);
    final table = TableNode(
      span: span,
      alignments: List.filled(columns, TableAlignment.none),
      children: [
        for (var row = 0; row < rows.length; row++)
          TableRowNode(
            span: rows[row].span,
            header: cells[row].any((c) => c.tag == 'th'),
            children: [
              for (var column = 0; column < columns; column++)
                TableCellNode(
                  span: column < cells[row].length
                      ? cells[row][column].span
                      : SourceSpan(rows[row].span.end, rows[row].span.end),
                  children: column < cells[row].length
                      ? cells[row][column].children
                      : [],
                ),
            ],
          ),
      ],
    );
    return MarkstreamTableBlock(
      node: table,
      source: span.slice(document.source),
      theme: theme,
      extensions: extensions,
      labels: labels,
      streaming: streaming,
      exporting: exporting,
      buildCell: (context, cell, style) {
        final owner = owners[cell.span];
        final content = _blockContent.inlineText(
          context,
          owner ?? cell,
          cell.children,
          style,
          streaming: streaming,
        );
        if (owner == null) return content;
        return DocumentSelectionGroup(
          node: owner,
          child: DefaultTextStyle.merge(
            textAlign: switch (owner.attributes['align']) {
              'center' => TextAlign.center,
              'right' => TextAlign.right,
              _ => TextAlign.start,
            },
            child: Align(
              alignment: switch (owner.attributes['align']) {
                'center' => Alignment.center,
                'right' => Alignment.centerRight,
                _ => AlignmentDirectional.centerStart,
              },
              child: content,
            ),
          ),
        );
      },
    );
  }
}
