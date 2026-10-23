import 'package:Kelivo/features/intelligent_ui/protocol/ui_ir.dart';

/// Dependency-first traversal without recursion across declarations. Cycles
/// include only their members, so consumers can report a dependency error.
({List<String> order, Set<String> cyclic}) uiDependencyOrder(
  Map<String, Set<String>> edges,
) {
  final done = <String>{};
  final active = <String, int>{};
  final cyclic = <String>{};
  final order = <String>[];
  final stack = <({String name, Iterator<String> children})>[];
  void push(String name) {
    active[name] = stack.length;
    stack.add((
      name: name,
      children: edges[name]!.where(edges.containsKey).iterator,
    ));
  }

  for (final root in edges.keys) {
    if (done.contains(root)) continue;
    push(root);
    while (stack.isNotEmpty) {
      final frame = stack.last;
      if (frame.children.moveNext()) {
        final child = frame.children.current;
        if (active[child] case final start?) {
          cyclic.addAll(stack.skip(start).map((entry) => entry.name));
        } else if (!done.contains(child)) {
          push(child);
        }
      } else {
        stack.removeLast();
        active.remove(frame.name);
        done.add(frame.name);
        order.add(frame.name);
      }
    }
  }
  return (order: List.unmodifiable(order), cyclic: Set.unmodifiable(cyclic));
}

Iterable<UiExpression> uiExpressionChildren(UiExpression value) =>
    switch (value) {
      UiLiteral() || UiRead() => const [],
      UiUnary(:final operand) => [operand],
      UiBinary(:final left, :final right) => [left, right],
      UiConditional(:final condition, :final whenTrue, :final whenFalse) => [
        condition,
        whenTrue,
        whenFalse,
      ],
      UiArray(:final items) => items,
      UiObject(:final fields) => fields.values,
      UiCall(:final arguments) => arguments,
      UiSample(:final body, :final start, :final end, :final count) => [
        body,
        start,
        end,
        count,
      ],
    };

Iterable<UiExpression> uiArgumentExpressions(UiArgument value) =>
    switch (value) {
      UiExpression() => [value],
      UiAsk(:final text, :final context) => [text, context],
      _ => const [],
    };

/// Iterative so malformed long chains cannot overflow before depth validation.
Iterable<(UiExpression, int)> walkUiExpression(UiExpression expression) sync* {
  final pending = [(expression, 1)];
  while (pending.isNotEmpty) {
    final (value, depth) = pending.removeLast();
    yield (value, depth);
    for (final child in uiExpressionChildren(value)) {
      pending.add((child, depth + 1));
    }
  }
}

Set<String> uiExpressionDependencies(UiExpression expression) {
  final result = <String>{};
  final pending = <(UiExpression, Set<String>)>[(expression, const {})];
  while (pending.isNotEmpty) {
    final (value, locals) = pending.removeLast();
    if (value case UiRead(:final name, :final state)) {
      if (state || !locals.contains(name)) result.add(name);
    } else if (value case UiSample(
      :final parameter,
      :final body,
      :final start,
      :final end,
      :final count,
    )) {
      pending.add((body, {...locals, parameter}));
      pending.addAll([(start, locals), (end, locals), (count, locals)]);
    } else {
      pending.addAll(
        uiExpressionChildren(value).map((child) => (child, locals)),
      );
    }
  }
  return result;
}
