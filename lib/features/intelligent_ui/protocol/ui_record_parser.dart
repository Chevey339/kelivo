import 'dart:convert';
import 'package:petitparser/petitparser.dart';
import 'package:Kelivo/features/intelligent_ui/catalog/ui_budgets.dart';
import 'package:Kelivo/features/intelligent_ui/protocol/ui_ir.dart';
import 'ui_diagnostic.dart';
import 'ui_expression_walk.dart';

typedef _DeclarationFactory = UiDeclaration Function(UiSourceLocation location);

final class UiRecordResult {
  const UiRecordResult({this.declaration, this.error});
  final UiDeclaration? declaration;
  final UiDiagnostic? error;
}

/// Cached grammar; only immutable ASTs escape a parse. Calls are synchronous.
final class UiRecordParser {
  UiRecordParser() {
    _parser = _RecordGrammar(_depth).build();
  }
  final _ParseDepth _depth = _ParseDepth();
  late final Parser<_DeclarationFactory> _parser;

  UiRecordResult parse(String record, int line) {
    _depth.exceeded = false;
    try {
      final result = _parser.parse(record);
      if (result is Success<_DeclarationFactory>) {
        final declaration = result.value(UiSourceLocation(line));
        final expressions = switch (declaration) {
          UiValueDeclaration(:final expression) => [expression],
          UiNodeDeclaration(:final arguments) => arguments.values.expand(
            uiArgumentExpressions,
          ),
          _ => const <UiExpression>[],
        };
        for (final expression in expressions) {
          if (walkUiExpression(
            expression,
          ).any((entry) => entry.$2 > UiBudgets.expressionDepth)) {
            throw const _RecordError(UiDiagnosticCode.expressionDepth);
          }
        }
        return UiRecordResult(declaration: declaration);
      }
      return UiRecordResult(
        error: UiDiagnostic(
          _depth.exceeded
              ? UiDiagnosticCode.expressionDepth
              : UiDiagnosticCode.syntax,
          line: line,
          column: result.position + 1,
        ),
      );
    } on _RecordError catch (error) {
      return UiRecordResult(error: UiDiagnostic(error.code, line: line));
    } on FormatException {
      return UiRecordResult(
        error: UiDiagnostic(UiDiagnosticCode.syntax, line: line),
      );
    }
  }
}

final class _RecordError implements Exception {
  const _RecordError(this.code);
  final UiDiagnosticCode code;
}

final class _ParseDepth {
  int current = 0;
  bool exceeded = false;
}

final class _BoundedParser<T> extends DelegateParser<T, T> {
  _BoundedParser(super.delegate, this.depth);
  final _ParseDepth depth;
  @override
  Result<T> parseOn(Context context) {
    if (depth.current >= UiBudgets.expressionDepth) {
      depth.exceeded = true;
      return context.failure('expression depth exceeded');
    }
    depth.current++;
    try {
      return delegate.parseOn(context);
    } finally {
      depth.current--;
    }
  }

  @override
  _BoundedParser<T> copy() => _BoundedParser(delegate, depth);
}

final class _RecordGrammar extends GrammarDefinition<_DeclarationFactory> {
  _RecordGrammar(this.depth);
  final _ParseDepth depth;
  @override
  Parser<_DeclarationFactory> start() =>
      [ref0(state), ref0(derived), ref0(node)].toChoiceParser().end();

  Parser<String> identifier() =>
      (pattern('A-Za-z_') & pattern('A-Za-z_0-9').star()).flatten().trim();
  Parser<String> keyword(String value) =>
      string(value).skip(after: pattern('A-Za-z_0-9').not()).trim();

  Parser<String> jsonString() =>
      (char('"') &
              ((char(r'\') & any()) | anyOf('"\\').neg()).star() &
              char('"'))
          .flatten()
          .map((raw) => jsonDecode(raw) as String)
          .trim();
  Parser<num> number() =>
      (char('-').optional() &
              (char('0') | (pattern('1-9') & digit().star())) &
              (char('.') & digit().plus()).optional() &
              (anyOf('eE') & anyOf('+-').optional() & digit().plus())
                  .optional())
          .flatten()
          .map((text) {
            final value = num.parse(text);
            if (!value.isFinite) {
              throw const _RecordError(UiDiagnosticCode.nonFinite);
            }
            return value;
          })
          .trim();
  Parser<Object?> scalar() => <Parser<Object?>>[
    ref0(jsonString),
    ref0(number),
    ref1(keyword, 'true').map((_) => true),
    ref1(keyword, 'false').map((_) => false),
    ref1(keyword, 'null').map((_) => null),
  ].toChoiceParser();

  Parser<_DeclarationFactory> state() =>
      seq6(
        char(r'$').trim(),
        ref0(identifier),
        char(':').trim(),
        ref0(identifier),
        char('?').trim().optional(),
        ref0(scalar).skip(before: char('=').trim()),
      ).map6((_, name, _, type, nullable, initial) {
        final scalarType = UiScalarType.values
            .where((value) => value.name == type)
            .firstOrNull;
        if (scalarType == null) {
          throw const _RecordError(UiDiagnosticCode.typeMismatch);
        }
        return (location) => UiStateDeclaration(
          name,
          location,
          type: scalarType,
          nullable: nullable != null,
          initialValue: initial,
        );
      });

  Parser<_DeclarationFactory> derived() =>
      seq4(
        ref1(keyword, 'let'),
        ref0(identifier),
        char('=').trim(),
        ref0(expression),
      ).map4(
        (_, name, _, value) =>
            (location) => UiValueDeclaration(name, location, value),
      );

  Parser<_DeclarationFactory> node() =>
      seq5(
        ref0(identifier),
        char('=').trim(),
        ref0(identifier),
        char('(').trim(),
        ref0(
          namedArgument,
        ).starSeparated(char(',').trim()).skip(after: char(')').trim()),
      ).map5((name, _, component, _, args) {
        final properties = _unique(args.elements);
        return (location) => UiNodeDeclaration(
          name,
          location,
          component: component,
          arguments: properties,
        );
      });

  Parser<MapEntry<String, UiArgument>> namedArgument() => seq3(
    ref0(identifier),
    char('=').trim(),
    [ref0(action), ref0(expression)].toChoiceParser(),
  ).map3((name, _, value) => MapEntry(name, value));

  Parser<UiArgument> action() =>
      seq3(
        ref0(identifier),
        char('(').trim(),
        seq3(ref0(identifier), char('=').trim(), ref0(expression))
            .map3((name, _, expression) => MapEntry(name, expression))
            .starSeparated(char(',').trim())
            .skip(after: char(')').trim()),
      ).map3((name, _, args) {
        final values = _unique(args.elements);
        if (name == 'Reset' && values.isEmpty) return const UiReset();
        if (name == 'Ask' &&
            values.length == 2 &&
            values.containsKey('text') &&
            values.containsKey('context')) {
          return UiAsk(text: values['text']!, context: values['context']!);
        }
        throw const _RecordError(UiDiagnosticCode.invalidAction);
      });

  Parser<UiExpression> expression() => _BoundedParser(ref0(conditional), depth);
  Parser<UiExpression> conditional() =>
      seq2(
        ref0(logicalOr),
        seq4(
          char('?').trim(),
          ref0(expression),
          char(':').trim(),
          ref0(expression),
        ).optional(),
      ).map2(
        (condition, branches) => branches == null
            ? condition
            : UiConditional(condition, branches.$2, branches.$4),
      );
  Parser<UiExpression> logicalOr() => _binary(ref0(logicalAnd), ['||']);
  Parser<UiExpression> logicalAnd() => _binary(ref0(equality), ['&&']);
  Parser<UiExpression> equality() => _binary(ref0(relational), ['==', '!=']);
  Parser<UiExpression> relational() =>
      _binary(ref0(additive), ['<=', '>=', '<', '>']);
  Parser<UiExpression> additive() => _binary(ref0(multiplicative), ['+', '-']);
  Parser<UiExpression> multiplicative() => _binary(ref0(unary), ['*', '/']);
  Parser<UiExpression> _binary(
    Parser<UiExpression> operand,
    List<String> operators,
  ) => operand
      .plusSeparated(
        operators.map((op) => string(op).trim()).toList().toChoiceParser(),
      )
      .map(
        (parts) => parts.foldLeft(
          (left, operator, right) => UiBinary(operator, left, right),
        ),
      );
  Parser<UiExpression> unary() => [
    seq2(
      anyOf('!-').trim(),
      _BoundedParser(ref0(unary), depth),
    ).map2((operator, operand) => UiUnary(operator, operand)),
    ref0(primary),
  ].toChoiceParser();
  Parser<UiExpression> primary() => <Parser<UiExpression>>[
    ref0(sample),
    ref0(call),
    ref0(scalar).map(UiLiteral.new),
    seq2(
      char(r'$').trim(),
      ref0(identifier),
    ).map2((_, name) => UiRead(name, state: true)),
    ref0(identifier).map(UiRead.new),
    ref0(array),
    ref0(object),
    seq3(
      char('(').trim(),
      ref0(expression),
      char(')').trim(),
    ).map3((_, value, _) => value),
  ].toChoiceParser();
  Parser<UiExpression> call() => seq4(
    char('@').trim(),
    ref0(identifier),
    char('(').trim(),
    ref0(
      expression,
    ).starSeparated(char(',').trim()).skip(after: char(')').trim()),
  ).map4((_, name, _, args) => UiCall(name, args.elements));
  Parser<UiExpression> sample() =>
      seq6(
        string('@sample').trim().skip(after: char('(').trim()),
        ref0(identifier),
        string('=>').trim(),
        ref0(expression),
        ref0(expression).skip(before: char(',').trim()),
        seq2(
          ref0(expression).skip(before: char(',').trim()),
          ref0(expression).skip(before: char(',').trim()),
        ).skip(after: char(')').trim()),
      ).map6(
        (_, parameter, _, body, start, rest) =>
            UiSample(parameter, body, start, rest.$1, rest.$2),
      );
  Parser<UiExpression> array() => seq3(
    char('[').trim(),
    ref0(expression).starSeparated(char(',').trim()),
    char(']').trim(),
  ).map3((_, items, _) => UiArray(items.elements));
  Parser<UiExpression> object() => seq3(
    char('{').trim(),
    seq3(ref0(jsonString), char(':').trim(), ref0(expression))
        .map3((key, _, value) => MapEntry(key, value))
        .starSeparated(char(',').trim()),
    char('}').trim(),
  ).map3((_, entries, _) => UiObject(_unique(entries.elements)));

  Map<String, T> _unique<T>(Iterable<MapEntry<String, T>> entries) {
    final values = <String, T>{};
    for (final entry in entries) {
      if (values.containsKey(entry.key)) {
        throw const _RecordError(UiDiagnosticCode.duplicateProperty);
      }
      values[entry.key] = entry.value;
    }
    return values;
  }
}
