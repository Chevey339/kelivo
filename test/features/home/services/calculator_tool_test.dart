import 'dart:convert';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/features/home/services/calculator_service.dart';
import 'package:Kelivo/features/home/services/local_tools_service.dart';

const _assistant = Assistant(
  id: 'calculator',
  name: 'Calculator',
  localToolIds: [LocalToolNames.calculate],
);

Future<Map<String, dynamic>> _calculate(String expression) async {
  final result = await LocalToolsService.tryHandleToolCall(
    LocalToolNames.calculate,
    {'expression': expression},
    _assistant,
  );
  return jsonDecode(result!) as Map<String, dynamic>;
}

void main() {
  group('Calculator exact arithmetic', () {
    const cases = {
      '3.5 * 0.10': '0.35',
      '3.5 * 0.20': '0.7',
      '0.1 + 0.2': '0.3',
      '9007199254740992 + 1': '9007199254740993',
      '999999999999999999999999999999 + 1': '1000000000000000000000000000000',
      '123456789012345678901234567890 / 10': '12345678901234567890123456789',
      'floor((0.3 - 0.2) * 10)': '1',
      'ceil(0.1 + 0.2 - 0.3)': '0',
      'floor(-1.2)': '-2',
      'ceil(-1.2)': '-1',
      'abs(-0.1 - 0.2)': '0.3',
      'sgn(0.3 - 0.2 - 0.1)': '0',
      'sgn(-42)': '-1',
      '1 / 3 * 3': '1',
      '(1 / 7 + 2 / 7) * 7': '3',
      'floor(1 / 3 * 3)': '1',
      '0.3 % 0.1': '0',
      '-5 % 3': '1',
      '5 % -3': '2',
      '2 * 3 % 4': '2',
      '8 / 4 / 2': '1',
      '2^10': '1024',
      '0.1^3': '0.001',
      '2^-3': '0.125',
      '-2^2': '-4',
      '(-2)^2': '4',
      '2^3^2': '512',
      '0!': '1',
      '5!': '120',
      '20!': '2432902008176640000',
      '3!^2': '36',
      '(15 + 3) * 2': '36',
      '1e-20 + 2e-20': '0.00000000000000000003',
      '.1 + 2. + 3E-1': '2.4',
      '1.234567890123456789 * 10': '12.34567890123456789',
      '-0': '0',
    };
    for (final entry in cases.entries) {
      test(entry.key, () async {
        final result = await _calculate(entry.key);
        expect(result['result'], entry.value);
        expect(result['approximate'], isFalse);
        expect(result, isNot(contains('note')));
      });
    }
  });

  group('Calculator approximate output', () {
    final cases = {
      '1 / 3': '0.333333333333333',
      '2 / 3': '0.666666666666667',
      '-2 / 3': '-0.666666666666667',
      '1 / (3 * 10^30)': '0.000000000000000000000000000000333333333333333',
      '10^30 / 3': '333333333333333000000000000000',
      '1 / (3 * 10^400)': '0.${'0' * 400}333333333333333',
      '10^400 / 3': '${'3' * 15}${'0' * 385}',
      '29999999999999999 / 3000000000000000': '10',
      '37037036703703349 / 30000000000000000': '1.23456789012344',
      'sqrt(2)': '1.4142135623731',
      'sqrt(144) + 100 * 0.08': '20',
      'sin(pi/4)': '0.707106781186548',
      'cos(0)': '1',
      'tan(0)': '0',
      'ln(e)': '1',
      'log(2, 8)': '3',
      '2^0.5': '1.4142135623731',
      '(-8)^(1/3)': '-2',
      '(-8)^(2/3)': '4',
      'nrt(3, -8)': '-2',
      'floor(pi)': '3',
      'abs(-pi)': '3.14159265358979',
      '1 / 3 + sin(0)': '0.333333333333333',
      'sqrt((1e1000+1)/(1e1000+2))': '1',
      'ln((1e1000+1)/(1e1000+2))': '0',
    };
    for (final entry in cases.entries) {
      test(entry.key, () async {
        final result = await _calculate(entry.key);
        expect(result['result'], entry.value);
        expect(result['approximate'], isTrue);
        expect(result['note'], contains('15 significant digits'));
      });
    }

    for (final argument in ['1e-309', '1e-320', '5e-324']) {
      test('sqrt accepts representable subnormal argument $argument', () async {
        final result = await _calculate('sqrt($argument)');
        final expected = math.sqrt(double.parse(argument));
        expect(
          double.parse(result['result'] as String),
          closeTo(expected, expected * 1e-14),
        );
        expect(result['approximate'], isTrue);
      });
    }
  });

  test('formats small finite values within bounded time', () async {
    final port = ReceivePort();
    final isolate = await Isolate.spawn<SendPort>(
      (reply) => reply.send(CalculatorService.evaluate('1/(2^1000)^16')),
      port.sendPort,
      onError: port.sendPort,
    );
    try {
      final result =
          await port.first.timeout(const Duration(seconds: 5)) as Map;
      final digits = BigInt.from(5).pow(16000).toString();
      expect(result['result'], '0.${'0' * (16000 - digits.length)}$digits');
      expect(result['approximate'], isFalse);
    } finally {
      isolate.kill(priority: Isolate.immediate);
      port.close();
    }
  });

  group('Calculator errors', () {
    for (final expression in [
      '1 / 0',
      '0 / 0',
      '1 % 0',
      '0^-1',
      'sqrt(-1)',
      'ln(0)',
      'log(1, 10)',
      'log(-2, 8)',
      'log(2, -8)',
      '(-1)!',
      '1.5!',
      '(-1)^0.5',
      'nrt(0, 8)',
      'nrt(pi, -1)',
      '(-1)^(1/pi)',
      'nrt(e, -8)',
      'nrt(sqrt2, -8)',
      '(-1)^1.0000000000000001',
      '(-1)^(9007199254740993/2)',
      '(-1)^(pi+1e20)',
      'e(1000)',
      'sin(1e1000)',
      'sin(1e-1000)',
      '10^1000000000',
      '1e1000000000',
      '1000000000!',
      '(10^1000)^1000',
      '${'(' * 65}1${')' * 65}',
      '1' * 4097,
    ]) {
      final label = expression.length > 100
          ? 'oversized expression (${expression.length} characters)'
          : expression;
      test(label, () async {
        final result = await _calculate(expression);
        expect(result['error'], 'math_error');
        expect(result, isNot(contains('result')));
      });
    }
    for (final expression in [
      '1 +',
      'unknown(2)',
      'x + 1',
      'log(10)',
      'sin()',
      'sin(1, 2)',
      '2 3',
      '2pi',
      '(1 + 2',
      '1 + 2)',
    ]) {
      test('invalid expression: $expression', () async {
        final result = await _calculate(expression);
        expect(result['error'], 'parse_error');
        expect(result, isNot(contains('result')));
      });
    }
    test('empty expression', () async {
      expect((await _calculate('  '))['error'], 'empty_expression');
    });
  });

  test('tool description explains exact and approximate results', () {
    final tools = LocalToolsService.buildToolDefinitions(
      assistant: _assistant,
      supportsTools: true,
    );
    final description = tools.single['function']['description'] as String;
    expect(description, contains('exact rational arithmetic'));
    expect(description, contains('approximate'));
    expect(description, contains('15 significant digits'));
  });

  test('calculator respects the assistant tool setting', () async {
    expect(
      await LocalToolsService.tryHandleToolCall(LocalToolNames.calculate, {
        'expression': '3.5 * 0.1',
      }, const Assistant(id: 'disabled', name: 'Disabled')),
      isNull,
    );
  });
}
