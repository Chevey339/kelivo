import '../../ast/nodes.dart';
import '../../ast/source_span.dart';
import 'math_inline.dart';

final class TableLine {
  const TableLine(this.cells, this.hasPipe, this.outerPipes);
  final List<TableCellNode> cells;
  final bool hasPipe;
  final bool outerPipes;
}

/// Pipes are separators even inside code spans; an escaped pipe is cell text.
TableLine splitTableLine(
  String source,
  int start,
  int end, {
  bool math = false,
  bool dollarMath = true,
  int maxMathLength = 512,
}) {
  while (start < end && _space(source.codeUnitAt(start))) start++;
  while (end > start && _space(source.codeUnitAt(end - 1))) end--;
  final separators = <int>[];
  final formulas = <InlineMathMatch>[];
  var codeEnd = -1;
  var slashes = 0;
  for (var i = start; i < end; i++) {
    final c = source.codeUnitAt(i);
    if (c == 96 && i > codeEnd && slashes.isEven) {
      var run = i + 1;
      while (run < end && source.codeUnitAt(run) == 96) run++;
      final marker = source.substring(i, run);
      var candidate = source.indexOf(marker, run);
      while (candidate >= 0 && candidate + marker.length <= end) {
        var after = candidate + marker.length;
        while (after < end && source.codeUnitAt(after) == 96) after++;
        if (after - candidate == marker.length) {
          codeEnd = after - 1;
          break;
        }
        candidate = source.indexOf(marker, after);
      }
      i = run - 1;
      slashes = 0;
      continue;
    }
    if (math &&
        i > codeEnd &&
        slashes.isEven &&
        ((c == 36 && dollarMath) || c == 92)) {
      final formula = readInlineMath(
        source,
        i,
        end: end,
        maxLength: maxMathLength,
        adjacent: formulas.isNotEmpty && formulas.last.end == i,
      );
      if (formula != null) {
        formulas.add(formula);
        i = formula.end - 1;
        slashes = 0;
        continue;
      }
    }
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
      if (formulas.any(
        (formula) => i >= formula.bodyStart && i < formula.bodyEnd,
      )) {
        i++;
        continue;
      }
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
  return TableLine(
    cells,
    separators.isNotEmpty,
    separators.isNotEmpty &&
        separators.first == start &&
        separators.last == end - 1,
  );
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
