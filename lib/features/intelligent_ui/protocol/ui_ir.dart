/// Platform-independent syntax and typed references for Kelivo UI DSL v1.
/// No widget, database, provider or platform imports belong in this library.
library;

enum UiScalarType { number, string, boolean }

final class UiSourceLocation {
  const UiSourceLocation(this.line, {this.column = 1});
  final int line;
  final int column;
}

sealed class UiArgument {
  const UiArgument();
  Object? toJson();
}

sealed class UiExpression extends UiArgument {
  const UiExpression();
}

final class UiLiteral extends UiExpression {
  const UiLiteral(this.value);
  final Object? value;
  @override
  Object? toJson() => {'literal': value};
}

/// Writable states use `$name`; bare names read derived values only.
final class UiRead extends UiExpression {
  const UiRead(this.name, {this.state = false});
  final String name;
  final bool state;
  @override
  Object toJson() => {state ? 'state' : 'value': name};
}

final class UiUnary extends UiExpression {
  const UiUnary(this.operator, this.operand);
  final String operator;
  final UiExpression operand;
  @override
  Object toJson() => {'unary': operator, 'operand': operand.toJson()};
}

final class UiBinary extends UiExpression {
  const UiBinary(this.operator, this.left, this.right);
  final String operator;
  final UiExpression left;
  final UiExpression right;
  @override
  Object toJson() => {
    'binary': operator,
    'left': left.toJson(),
    'right': right.toJson(),
  };
}

final class UiConditional extends UiExpression {
  const UiConditional(this.condition, this.whenTrue, this.whenFalse);
  final UiExpression condition;
  final UiExpression whenTrue;
  final UiExpression whenFalse;
  @override
  Object toJson() => {
    'if': condition.toJson(),
    'then': whenTrue.toJson(),
    'else': whenFalse.toJson(),
  };
}

final class UiArray extends UiExpression {
  UiArray(Iterable<UiExpression> items) : items = List.unmodifiable(items);
  final List<UiExpression> items;
  @override
  Object toJson() => {'array': items.map((e) => e.toJson()).toList()};
}

final class UiObject extends UiExpression {
  UiObject(Map<String, UiExpression> fields)
    : fields = Map.unmodifiable(fields);
  final Map<String, UiExpression> fields;
  @override
  Object toJson() => {
    'object': fields.map((key, value) => MapEntry(key, value.toJson())),
  };
}

final class UiCall extends UiExpression {
  UiCall(this.function, Iterable<UiExpression> arguments)
    : arguments = List.unmodifiable(arguments);
  final String function;
  final List<UiExpression> arguments;
  @override
  Object toJson() => {
    'call': function,
    'arguments': arguments.map((e) => e.toJson()).toList(),
  };
}

final class UiSample extends UiExpression {
  const UiSample(this.parameter, this.body, this.start, this.end, this.count);
  final String parameter;
  final UiExpression body;
  final UiExpression start;
  final UiExpression end;
  final UiExpression count;
  @override
  Object toJson() => {
    'sample': parameter,
    'body': body.toJson(),
    'start': start.toJson(),
    'end': end.toJson(),
    'count': count.toJson(),
  };
}

/// These slots are distinct from arithmetic expressions. In particular,
/// FormRef is not a layout edge and cannot introduce a structural cycle.
final class UiInputBinding extends UiArgument {
  const UiInputBinding(this.name);
  final String name;
  String get path => '/inputs/$name';
  @override
  Object toJson() => {'bind': name};
}

final class UiChildRefs extends UiArgument {
  UiChildRefs(Iterable<String> names) : names = List.unmodifiable(names);
  final List<String> names;
  @override
  Object toJson() => {'children': names};
}

final class UiFormRef extends UiArgument {
  const UiFormRef(this.name);
  final String name;
  @override
  Object toJson() => {'form': name};
}

sealed class UiAction extends UiArgument {
  const UiAction();
}

final class UiAsk extends UiAction {
  const UiAsk({required this.text, required this.context});
  final UiExpression text;
  final UiExpression context;
  @override
  Object toJson() => {
    'action': 'Ask',
    'text': text.toJson(),
    'context': context.toJson(),
  };
}

final class UiReset extends UiAction {
  const UiReset();
  @override
  Object toJson() => {'action': 'Reset'};
}

sealed class UiDeclaration {
  const UiDeclaration(this.name, this.location);
  final String name;
  final UiSourceLocation location;
  Map<String, Object?> toJson();
}

final class UiStateDeclaration extends UiDeclaration {
  const UiStateDeclaration(
    super.name,
    super.location, {
    required this.type,
    required this.initialValue,
    this.nullable = false,
  });
  final UiScalarType type;
  final bool nullable;
  final Object? initialValue;
  @override
  Map<String, Object?> toJson() => {
    'state': name,
    'line': location.line,
    'type': type.name,
    'nullable': nullable,
    'initial': initialValue,
  };
}

final class UiValueDeclaration extends UiDeclaration {
  const UiValueDeclaration(super.name, super.location, this.expression);
  final UiExpression expression;
  @override
  Map<String, Object?> toJson() => {
    'value': name,
    'line': location.line,
    'expression': expression.toJson(),
  };
}

final class UiNodeDeclaration extends UiDeclaration {
  UiNodeDeclaration(
    super.name,
    super.location, {
    required this.component,
    required Map<String, UiArgument> arguments,
  }) : arguments = Map.unmodifiable(arguments);
  final String component;
  final Map<String, UiArgument> arguments;
  @override
  Map<String, Object?> toJson() => {
    'node': name,
    'line': location.line,
    'component': component,
    'arguments': arguments.map((key, value) => MapEntry(key, value.toJson())),
  };
}
