import '../../ast/nodes.dart';
import '../../ast/source_span.dart';

final class TableLine {
  const TableLine(this.cells, this.hasPipe);
  final List<TableCellNode> cells;
  final bool hasPipe;
}

/// Pipes are separators even inside code spans; an escaped pipe is cell text.
TableLine splitTableLine(String source, int start, int end) {
  while (start < end && _space(source.codeUnitAt(start))) start++;
  while (end > start && _space(source.codeUnitAt(end - 1))) end--;
  final separators = <int>[];
  var slashes = 0;
  for (var i = start; i < end; i++) {
    final c = source.codeUnitAt(i);
    if (c == 124 && slashes.isEven) separators.add(i);
    slashes = c == 92 ? slashes + 1 : 0;
  }
  final boundaries = [start - 1, ...separators, end];
  if (separators.isNotEmpty && separators.first == start)
    boundaries.removeAt(0);
  if (separators.isNotEmpty && separators.last == end - 1)
    boundaries.removeLast();
  final cells = <TableCellNode>[];
  for (var n = 1; n < boundaries.length; n++) {
    var a = boundaries[n - 1] + 1;
    var b = boundaries[n];
    while (a < b && _space(source.codeUnitAt(a))) a++;
    while (b > a && _space(source.codeUnitAt(b - 1))) b--;
    final fragments = <TextNode>[];
    var run = a;
    for (var i = a; i < b; i++) {
      if (source.codeUnitAt(i) != 92) continue;
      if (i + 1 < b && source.codeUnitAt(i + 1) == 124) {
        if (i > run)
          fragments.add(
            TextNode(span: SourceSpan(run, i), text: source.substring(run, i)),
          );
        fragments.add(TextNode(span: SourceSpan(i, i + 2), text: '|'));
        run = i + 2;
      }
      i++;
    }
    if (run < b)
      fragments.add(
        TextNode(span: SourceSpan(run, b), text: source.substring(run, b)),
      );
    cells.add(TableCellNode(span: SourceSpan(a, b), children: fragments));
  }
  return TableLine(cells, separators.isNotEmpty);
}

bool _space(int c) => c == 32 || c == 9;

List<TableAlignment>? tableDelimiter(TableLine line, String source) {
  if (line.cells.isEmpty) return null;
  final result = <TableAlignment>[];
  for (final cell in line.cells) {
    final text = cell.span.slice(source);
    if (!RegExp(r'^:?-+:?$').hasMatch(text)) return null;
    result.add(
      text.startsWith(':')
          ? text.endsWith(':')
                ? TableAlignment.center
                : TableAlignment.left
          : text.endsWith(':')
          ? TableAlignment.right
          : TableAlignment.none,
    );
  }
  return result;
}
