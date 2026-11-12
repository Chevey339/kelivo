import '../ast/nodes.dart';

/// Shared iterative postorder traversal, also safe for deeply nested containers.
Map<MarkdownNode, T> serializeNodes<T>(
  MarkdownNode root,
  T Function(MarkdownNode, Map<MarkdownNode, T>) render,
) {
  final output = <MarkdownNode, T>{};
  final pending = <(MarkdownNode, bool)>[(root, false)];
  while (pending.isNotEmpty) {
    final (node, visited) = pending.removeLast();
    if (!visited) {
      pending.add((node, true));
      for (final child in node.children.reversed) pending.add((child, false));
    } else {
      output[node] = render(node, output);
    }
  }
  return output;
}

String joinChildren(
  MarkdownNode node,
  Map<MarkdownNode, String> output, [
  String separator = '',
]) => node.children
    .map((n) => output[n]!)
    .where((s) => s.isNotEmpty)
    .join(separator);
String separatedCell(String text, String separator) =>
    text.contains(separator) ||
        text.contains('\n') ||
        text.contains('\r') ||
        text.contains('"')
    ? '"${text.replaceAll('"', '""')}"'
    : text;
String mathSource(
  String tex,
  String delimiter, {
  required bool block,
  bool closed = true,
}) {
  final end = delimiter == r'\('
      ? r'\)'
      : delimiter == r'\['
      ? r'\]'
      : delimiter;
  return block
      ? '$delimiter\n$tex${closed ? '\n$end' : ''}'
      : '$delimiter$tex${closed ? end : ''}';
}

String indentLines(String text, String prefix, [String? continuation]) {
  final lines = text.split('\n');
  return [
    for (var i = 0; i < lines.length; i++)
      '${i == 0 ? prefix : continuation ?? prefix}${lines[i]}',
  ].join('\n');
}

String taskMarker(ListItemNode node) => node.checked == null
    ? ''
    : node.radio
    ? '(${node.checked! ? 'x' : ' '}) '
    : '[${node.checked! ? 'x' : ' '}] ';
