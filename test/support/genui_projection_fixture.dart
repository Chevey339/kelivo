import 'dart:convert';
import 'package:Kelivo/features/intelligent_ui/catalog/ui_catalog.dart';
import 'package:Kelivo/features/intelligent_ui/text/ui_text_projection.dart';

final testUiProjection = UiTextProjection(
  UiProjectionLabels(
    defaultTitle: 'Interface',
    yes: 'Yes',
    no: 'No',
    empty: 'No fields.',
    omitted: '[Some fields omitted]',
    waiting: (id) => 'Waiting for $id',
    diagnostic: (d) => 'Error: ${d.code.name}',
    fieldIssue: (e) => 'Field: ${e.error.name}',
    chartKind: (kind, donut) => donut ? 'donut' : kind.name,
    chartSummary: (kind, series, rows, missing) =>
        '$kind, $series series, $rows rows, $missing missing',
    pieSummary: (kind, items, total) => '$kind, $items items, total $total',
    range: (name, min, max) => '$name: $min–$max',
    tablePage: (from, to, total) => 'Rows $from–$to of $total',
    filter: (query) => 'Filter: $query',
    domainGaps: (n) => '$n undefined points',
    trend: (value) => 'Change $value',
  ),
);
String genUiRepeatedMarkdownFixture(int blocks) =>
    '${UiCatalog.header}\nlet big = ${jsonEncode('**word** ' * 12000)}\n'
    'root = Column(children=[${List.generate(blocks, (i) => 'm$i').join(',')}])\n'
    '${List.generate(blocks, (i) => 'm$i = Markdown(text=big)').join('\n')}\n';
