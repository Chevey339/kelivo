import 'dart:math' as math;

import 'package:decimal/decimal.dart';
import 'package:petitparser/petitparser.dart';
import 'package:rational/rational.dart';

/// Evaluates decimal literals without converting them to binary floating point.
class CalculatorService {
  CalculatorService._();

  static final _parser = _CalculatorGrammar().build<_Value>();

  static Map<String, dynamic> evaluate(String expression) {
    // Bound recursive parsing and arbitrary-precision work on the UI isolate.
    if (expression.length > 4096 ||
        RegExp(r'[\(^]').allMatches(expression).length > 64) {
      throw const CalculatorException('Expression exceeds calculator limits.');
    }
    final parsed = _parser.parse(expression);
    if (parsed is Failure) {
      throw FormatException(parsed.message, expression, parsed.position);
    }
    final value = parsed.value;
    final exactDecimal = value.approximate ? null : _exactDecimal(value.number);
    final approximate = exactDecimal == null;
    return {
      'result': exactDecimal?.toString() ?? _roundedDecimal(value.number),
      'approximate': approximate,
      if (approximate)
        'note': value.approximate
            ? 'Uses double-precision approximations for functions/constants. '
                  'Rounded to 15 significant digits; numerical error may accumulate.'
            : 'Repeating decimal rounded to 15 significant digits.',
    };
  }

  static Decimal? _exactDecimal(Rational value) {
    // A reduced fraction terminates only when its denominator contains 2 and 5.
    // Build its decimal scale directly: Rational.toDecimal repeatedly multiplies
    // and reduces the fraction, blocking for inputs such as 1 / 2^16000.
    var denominator = value.denominator;
    var twos = 0;
    var fives = 0;
    final five = BigInt.from(5);
    while (denominator.isEven) {
      denominator >>= 1;
      twos++;
    }
    while (denominator % five == BigInt.zero) {
      denominator ~/= five;
      fives++;
    }
    if (denominator != BigInt.one) return null;
    final scale = math.max(twos, fives);
    final coefficient =
        (value.numerator << (scale - twos)) * five.pow(scale - fives);
    return Decimal.fromBigInt(coefficient).shift(-scale);
  }

  /// Round once, in rational arithmetic, including very large/small fractions.
  static String _roundedDecimal(Rational value, {int significantDigits = 15}) {
    if (value == Rational.zero) return '0';
    final numerator = value.numerator.abs();
    final denominator = value.denominator;
    var exponent = numerator.toString().length - denominator.toString().length;
    final power = Rational.fromInt(10).pow(exponent);
    if (value.abs() < power) exponent--;
    final decimalPlaces = significantDigits - 1 - exponent;
    final scale = Rational.fromInt(10).pow(decimalPlaces);
    return Decimal.fromBigInt(
      (value * scale).round(),
    ).shift(-decimalPlaces).toString();
  }
}

class CalculatorException implements Exception {
  const CalculatorException(this.message);

  final String message;
}

const _maxBits = 16384;
const _maxExponent = 1000;

class _Value {
  _Value(this.number, {this.approximate = false}) {
    if (number.numerator.abs().bitLength > _maxBits ||
        number.denominator.bitLength > _maxBits) {
      throw const CalculatorException('Result exceeds calculator limits.');
    }
  }

  factory _Value.parse(String literal) {
    final exponent = RegExp(r'[eE]([+-]?\d+)$').firstMatch(literal);
    if (exponent != null &&
        BigInt.parse(exponent.group(1)!).abs() > BigInt.from(_maxExponent)) {
      throw const CalculatorException('Exponent exceeds calculator limits.');
    }
    return _Value(Rational.parse(literal));
  }

  factory _Value.fromDouble(double value) {
    if (!value.isFinite) {
      throw const CalculatorException(
        'The result is not a finite real number. Check the function domain.',
      );
    }
    return _Value(Rational.parse(value.toString()), approximate: true);
  }

  final Rational number;
  final bool approximate;

  _Value map(Rational Function(Rational) operation) =>
      _Value(operation(number), approximate: approximate);

  _Value combine(
    _Value other,
    Rational Function(Rational, Rational) operation,
  ) => _Value(
    operation(number, other.number),
    approximate: approximate || other.approximate,
  );

  _Value operator -() => map((value) => -value);
  _Value operator +(_Value other) => combine(other, (a, b) => a + b);
  _Value operator -(_Value other) => combine(other, (a, b) => a - b);
  _Value operator *(_Value other) => combine(other, (a, b) => a * b);

  _Value operator /(_Value other) {
    other.requireNonZero();
    return combine(other, (a, b) => a / b);
  }

  _Value operator %(_Value other) {
    other.requireNonZero();
    return combine(other, (a, b) => a % b);
  }

  void requireNonZero() {
    if (number == Rational.zero) {
      throw const CalculatorException('Division by zero is undefined.');
    }
  }

  double toDouble() {
    // Convert the ratio as a whole. Rational.toDouble converts each BigInt
    // separately, which can overflow even when their ratio is representable.
    final value = double.parse(
      CalculatorService._roundedDecimal(number, significantDigits: 17),
    );
    if (!value.isFinite || (value == 0 && number != Rational.zero)) {
      throw const CalculatorException(
        'Argument is outside the range of double-precision functions.',
      );
    }
    return value;
  }

  _Value pow(_Value exponent) {
    if (exponent.number.isInteger) {
      final n = exponent.number.numerator;
      final baseBits = math.max(
        number.numerator.abs().bitLength,
        number.denominator.bitLength,
      );
      if (n.abs() > BigInt.from(_maxExponent) ||
          baseBits * n.abs().toInt() > _maxBits) {
        throw const CalculatorException('Power exceeds calculator limits.');
      }
      if (n.isNegative) requireNonZero();
      return combine(exponent, (base, _) => base.pow(n.toInt()));
    }
    final base = toDouble();
    // Only exact rational exponents can establish a real root of a negative
    // base; a decimal approximation of an irrational exponent cannot.
    if (base < 0) {
      if (exponent.approximate || exponent.number.denominator.isEven) {
        throw const CalculatorException(
          'Negative bases require an integer or an exact rational exponent '
          'with an odd denominator.',
        );
      }
      final result = math.pow(-base, exponent.toDouble()).toDouble();
      return _Value.fromDouble(
        exponent.number.numerator.isOdd ? -result : result,
      );
    }
    return _Value.fromDouble(math.pow(base, exponent.toDouble()).toDouble());
  }

  _Value factorial() {
    if (!number.isInteger || number.signum < 0) {
      throw const CalculatorException(
        'Factorial requires a non-negative integer.',
      );
    }
    if (number.numerator > BigInt.from(1000)) {
      throw const CalculatorException('Factorial is limited to 1000.');
    }
    var result = BigInt.one;
    final n = number.numerator.toInt();
    for (var i = 2; i <= n; i++) {
      result *= BigInt.from(i);
    }
    return _Value(Rational(result), approximate: approximate);
  }
}

class _CalculatorGrammar extends GrammarDefinition<_Value> {
  @override
  Parser<_Value> start() => ref0(sum).end();

  Parser<_Value> sum() => _binary(ref0(product), '+-');
  Parser<_Value> product() => _binary(ref0(unary), '*/%');

  Parser<_Value> _binary(Parser<_Value> operand, String operators) => operand
      .plusSeparated(anyOf(operators).trim())
      .map(
        (parts) => parts.foldLeft(
          (left, operator, right) => switch (operator) {
            '+' => left + right,
            '-' => left - right,
            '*' => left * right,
            '/' => left / right,
            '%' => left % right,
            _ => throw StateError('Unknown operator'),
          },
        ),
      );

  Parser<_Value> unary() => seq2(anyOf('+-').trim().star(), ref0(power)).map2(
    (signs, value) =>
        signs.where((s) => s == '-').length.isOdd ? -value : value,
  );

  Parser<_Value> power() => seq2(
    ref0(postfix),
    seq2(char('^').trim(), ref0(unary)).map2((_, value) => value).optional(),
  ).map2((base, exponent) => exponent == null ? base : base.pow(exponent));

  Parser<_Value> postfix() =>
      seq2(ref0(primary), char('!').trim().star()).map2((value, operators) {
        for (final _ in operators) {
          value = value.factorial();
        }
        return value;
      });

  Parser<_Value> primary() => [
    ref0(number),
    ref0(binding),
    seq3(
      char('(').trim(),
      ref0(sum),
      char(')').trim(),
    ).map3((_, value, _) => value),
  ].toChoiceParser();

  Parser<_Value> number() =>
      (((digit().plus() & (char('.') & digit().star()).optional()) |
                  (char('.') & digit().plus())) &
              (anyOf('eE') & anyOf('+-').optional() & digit().plus())
                  .optional())
          .flatten()
          .trim()
          .map(_Value.parse);

  Parser<_Value> binding() =>
      seq2(
        (letter() & (letter() | digit() | char('_')).star()).flatten().trim(),
        seq3(
          char('(').trim(),
          ref0(sum).starSeparated(char(',').trim()),
          char(')').trim(),
        ).map3((_, arguments, _) => arguments.elements).optional(),
      ).map2((name, arguments) {
        if (arguments != null) return _function(name, arguments);
        final constant = _constants[name];
        if (constant == null) throw FormatException('Unknown constant: $name');
        return _Value.fromDouble(constant);
      });

  static const _constants = {
    'pi': math.pi,
    'e': math.e,
    'ln10': math.ln10,
    'ln2': math.ln2,
    'log10e': math.log10e,
    'log2e': math.log2e,
    'sqrt1_2': math.sqrt1_2,
    'sqrt2': math.sqrt2,
  };

  static final _functions = <String, double Function(double)>{
    'sin': math.sin,
    'cos': math.cos,
    'tan': math.tan,
    'arcsin': math.asin,
    'arccos': math.acos,
    'arctan': math.atan,
    'sqrt': math.sqrt,
    'ln': math.log,
    'e': math.exp,
  };

  _Value _function(String name, List<_Value> arguments) {
    switch ((name, arguments)) {
      case ('abs', [final a]):
        return a.map((value) => value.abs());
      case ('floor', [final a]):
        return a.map((value) => Rational(value.floor()));
      case ('ceil', [final a]):
        return a.map((value) => Rational(value.ceil()));
      case ('sgn', [final a]):
        return a.map((value) => Rational.fromInt(value.signum));
      case ('log', [final base, final value]):
        if (base.number <= Rational.zero || base.number == Rational.one) {
          throw const CalculatorException(
            'Logarithm base must be positive and not 1.',
          );
        }
        return _Value.fromDouble(
          math.log(value.toDouble()) / math.log(base.toDouble()),
        );
      case ('nrt', [final degree, final value]):
        return value.pow(_Value(Rational.one) / degree);
    }
    final function = _functions[name];
    if (function == null || arguments.length != 1) {
      throw FormatException(
        'Unknown function or invalid argument count: $name',
      );
    }
    return _Value.fromDouble(function(arguments.single.toDouble()));
  }
}
