import 'dart:convert';

import 'package:Kelivo/features/intelligent_ui/catalog/ui_catalog.dart';
import 'package:Kelivo/features/intelligent_ui/protocol/ui_diagnostic.dart';
import 'package:Kelivo/features/intelligent_ui/protocol/ui_ir.dart';
import 'package:Kelivo/features/intelligent_ui/protocol/ui_stream_parser.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_evaluator.dart';
import 'package:flutter_test/flutter_test.dart';

UiEvaluationBatch _batch(
  String declarations, {
  Map<String, Object?> inputs = const {},
  int limit = 50000,
}) {
  final parsed = UiStreamParser().update(
    '${UiCatalog.header}\nroot = Text(text="Example")\n$declarations',
    closed: true,
  );
  expect(parsed.program.diagnostics, isEmpty);
  return UiEvaluationBatch(parsed.program, inputs, operationLimit: limit);
}

UiComputedValue _expression(String expression) =>
    _batch('let result = $expression').readValue('result');

void main() {
  test('precedence, left association and conditional right association', () {
    expect(_expression('2 + 3 * 4').value, 14);
    expect(_expression('10 - 3 - 2').value, 5);
    expect(_expression('20 / 2 / 5').value, 2);
    expect(_expression('false ? 1 : true ? 2 : 3').value, 2);
    expect(_expression('!false && (3 >= 2)').value, isTrue);
  });

  test('inactive branches do not evaluate domain or division errors', () {
    for (final entry in {
      'false && (1 / 0 > 1)': false,
      'true || (@sqrt(-1) > 0)': true,
      'true ? 12 : @pow(-2, 0.5)': 12.0,
      'false ? 1 / 0 : 7': 7.0,
    }.entries) {
      final result = _expression(entry.key);
      expect(result.error, isNull, reason: entry.key);
      expect(result.value, entry.value);
    }
  });

  test('all scalar pure functions have bounded concrete results', () {
    for (final entry in {
      '@abs(-3)': 3.0,
      '@min(3, 8)': 3.0,
      '@max(3, 8)': 8.0,
      '@round(1.234, 2)': 1.23,
      '@round(1.6)': 2.0,
      '@clamp(8, 1, 5)': 5.0,
      '@pow(2, 3)': 8.0,
      '@sqrt(9)': 3.0,
      '@sin(0)': 0.0,
      '@cos(0)': 1.0,
      '@formatNumber(1.2, 3)': '1.200',
    }.entries) {
      final result = _expression(entry.key);
      expect(result.error, isNull, reason: entry.key);
      expect(result.value, entry.value);
    }
  });

  test('division, overflow, domain and invalid arguments are diagnostics', () {
    for (final entry in {
      '1 / 0': UiDiagnosticCode.divisionByZero,
      '1e308 * 1e308': UiDiagnosticCode.nonFinite,
      '@sqrt(-1)': UiDiagnosticCode.domain,
      '@pow(-2, 0.5)': UiDiagnosticCode.domain,
      '@clamp(3, 5, 1)': UiDiagnosticCode.invalidValue,
      '@round(1.23, 1.5)': UiDiagnosticCode.invalidValue,
      '@formatNumber(1.23, 11)': UiDiagnosticCode.invalidValue,
    }.entries) {
      final result = _expression(entry.key);
      expect(result.error?.code, entry.value, reason: entry.key);
      expect(result.value, isNull);
    }
  });

  test('null is preserved and numeric strings are never coerced', () {
    expect(_expression('null').value, isNull);
    expect(_expression('null').valid, isTrue);
    final invalid = _batch(
      r'$a: number = 2'
      '\n'
      r'let result = $a * 2',
      inputs: {'a': '3'},
    );
    expect(invalid.inputErrors['a']?.code, UiDiagnosticCode.typeMismatch);
    expect(
      invalid.readValue('result').error?.code,
      UiDiagnosticCode.typeMismatch,
    );
    final batch = _batch('');
    expect(
      batch
          .readExpression(
            'root',
            const UiBinary('+', UiLiteral(null), UiLiteral(1)),
          )
          .error
          ?.code,
      UiDiagnosticCode.typeMismatch,
    );
    expect(
      batch
          .readExpression(
            'root',
            const UiBinary('+', UiLiteral('2'), UiLiteral(1)),
          )
          .error
          ?.code,
      UiDiagnosticCode.typeMismatch,
    );
  });

  test(
    'samples preserve endpoints and report null gaps without filling zero',
    () {
      final result = _expression('@sample(x => @sqrt(x), -1, 1, 3)');
      expect(result.error, isNull);
      expect(result.value, [
        {'x': -1.0, 'y': null},
        {'x': 0.0, 'y': 0.0},
        {'x': 1.0, 'y': 1.0},
      ]);
      expect(result.gaps, hasLength(1));
      expect(result.gaps.single.x, -1);
      expect(result.gaps.single.code, UiDiagnosticCode.domain);
      expect(_expression('@sample(x => x, -1e308, 1e308, 3)').value, [
        {'x': -1e308, 'y': -1e308},
        {'x': 0.0, 'y': 0.0},
        {'x': 1e308, 'y': 1e308},
      ]);
      final points =
          _expression('@sample(x => x * 2, 0, 1, 501)').value as List;
      expect(points, hasLength(501));
      expect(points.first, {'x': 0.0, 'y': 0.0});
      expect(points.last, {'x': 1.0, 'y': 2.0});
    },
  );

  test('cross-zero sample grids preserve actual function boundaries', () {
    final root = _expression('@sample(x => @sqrt(x), -2, 4, 13)');
    expect(root.error, isNull);
    expect((root.value as List)[4], {'x': 0.0, 'y': 0.0});
    expect(root.gaps.map((gap) => gap.index), [0, 1, 2, 3]);
    final reciprocal = _expression('@sample(x => 1 / x, -2, 4, 13)');
    expect(reciprocal.error, isNull);
    expect((reciprocal.value as List)[4], {'x': 0.0, 'y': null});
    expect(reciprocal.gaps.single.index, 4);
    expect(reciprocal.gaps.single.code, UiDiagnosticCode.divisionByZero);
  });

  test('sample parameters read current surface inputs and local scope', () {
    final value = _batch(
      r'$a: number = 2'
      '\n'
      r'let points = @sample(x => $a * x, 0, 2, 3)',
      inputs: {'a': 3},
    );
    expect(value.readValue('points').value, [
      {'x': 0.0, 'y': 0.0},
      {'x': 1.0, 'y': 3.0},
      {'x': 2.0, 'y': 6.0},
    ]);
    expect(
      _expression('@sample(x => x, 1, 0, 2)').error?.code,
      UiDiagnosticCode.invalidSample,
    );
  });

  test('narrow sample ranges stay ordered and never invent domain gaps', () {
    for (final (start, end) in [
      (2.5, 2.5000000000000004),
      (1.7976931348623155e308, 1.7976931348623157e308),
      (-1.7976931348623157e308, -1.7976931348623155e308),
    ]) {
      final result = _expression(
        '@sample(x => @sqrt(x - ($start)), $start, $end, 51)',
      );
      expect(result.error, isNull);
      expect(result.gaps, isEmpty);
      final points = result.value as List;
      expect(points.first['x'], start);
      expect(points.last['x'], end);
      var previous = start;
      for (final point in points) {
        expect(point['x'], inInclusiveRange(previous, end));
        expect(point['y'], isNotNull);
        previous = point['x'] as double;
      }
    }
  });

  test(
    'signed zero has the same representation after cached and fresh input',
    () {
      final first = _batch(
        r'''$a: number = 0
let result = @formatNumber($a, 1)''',
        inputs: {'a': -0.0},
      );
      expect(first.inputs['a'].toString(), '0.0');
      expect(first.readValue('result').value, '0.0');
      final cached = UiEvaluationBatch(first.program, {
        'a': 0.0,
      }, previous: first);
      final fresh = UiEvaluationBatch(first.program, {'a': 0.0});
      expect(cached.readValue('result').value, fresh.readValue('result').value);
      expect(cached.operations, 0);
      expect(_expression('@round(-0.1)').value.toString(), '0.0');
      expect(_expression('0 * -1').value.toString(), '0.0');
    },
  );

  test(
    'shared references cannot amplify a small program into unbounded data',
    () {
      final text = StringBuffer('let v0 = 1\n');
      for (var i = 1; i <= 6; i++) {
        text.writeln('let v$i = [${List.filled(10, 'v${i - 1}').join(',')}]');
      }
      final batch = _batch(text.toString());
      expect(batch.readValue('v4').valid, isTrue);
      expect(batch.readValue('v5').error?.code, UiDiagnosticCode.dataBudget);
      expect(batch.readValue('v6').error?.code, UiDiagnosticCode.dependency);
      expect(batch.readValue('v5').value, isNull);
      expect(jsonEncode(batch.readValue('v5').error!.toJson()), isNotEmpty);
      expect(batch.operations, lessThan(10));
    },
  );

  test('derived aliases obey the same result depth and UTF-8 byte budgets', () {
    final deep = StringBuffer('let v0 = 1\n');
    for (var i = 1; i <= 40; i++) {
      deep.writeln('let v$i = [v${i - 1}]');
    }
    final nested = _batch(deep.toString());
    expect(nested.readValue('v31').valid, isTrue);
    expect(
      nested.readValue('v32').error?.code,
      UiDiagnosticCode.expressionDepth,
    );
    expect(nested.readValue('v40').error?.code, UiDiagnosticCode.dependency);
    final large = _batch('''let text = "${'界' * 10000}"
let copies = [${List.filled(10, 'text').join(',')}]''');
    expect(large.readValue('text').valid, isTrue);
    expect(large.readValue('copies').error?.code, UiDiagnosticCode.dataBudget);
  });

  test(
    'exhausted batches reject partial output while constant content remains readable',
    () {
      final batch = _batch(
        'let points = @sample(x => x * 2, 0, 1, 2)',
        limit: 4,
      );
      final result = batch.readValue('points');
      expect(result.error?.code, UiDiagnosticCode.operationsBudget);
      expect(result.value, isNull);
      expect(result.gaps, isEmpty);
      expect(batch.operations, 4);
      expect(
        batch.readExpression('root', const UiLiteral('Still readable')).value,
        'Still readable',
      );
    },
  );

  test('input changes only invalidate dependent cached values', () {
    final a = _batch(r'''$a: number = 1
$b: number = 10
let left = $a * 2
let right = $b * 3
let total = left + right''');
    expect(a.readValue('total').value, 32);
    final unchanged = a.readValue('right');
    final b = UiEvaluationBatch(a.program, {'a': 2}, previous: a);
    expect(b.readValue('total').value, 34);
    expect(b.readValue('right'), same(unchanged));
    expect(b.operations, 2);
    expect(b.dirtySymbols, containsAll(['a', 'left', 'total']));
    expect(b.dirtySymbols, isNot(contains('right')));
  });

  test('failed cached calculations can recover with a fresh batch budget', () {
    final a = _batch('let result = 1 + 2 * 3', limit: 1);
    expect(
      a.readValue('result').error?.code,
      UiDiagnosticCode.operationsBudget,
    );
    final b = UiEvaluationBatch(a.program, const {}, previous: a);
    expect(b.readValue('result').value, 7);
    expect(b.dirtySymbols, contains('result'));
  });

  test('one batch gives consistent current inputs and derived results', () {
    final batch = _batch(
      r'$a: number = 2'
      '\n'
      r'let result = $a * 3',
      inputs: {'a': 5},
    );
    final projection = batch.readExpression(
      'root',
      UiObject({
        'input': const UiRead('a', state: true),
        'result': const UiRead('result'),
      }),
    );
    expect(projection.value, {'input': 5.0, 'result': 15.0});
    expect(() => (projection.value as Map).clear(), throwsUnsupportedError);
    final samples = _expression('@sample(x => x, 0, 1, 2)').value as List;
    expect(() => samples.clear(), throwsUnsupportedError);
    expect(() => (samples.first as Map).clear(), throwsUnsupportedError);
  });

  test(
    '500 deep derived declarations stay iterative within the shared budget',
    () {
      final text = StringBuffer();
      for (var i = 0; i < 500; i++) {
        text.writeln('let v$i = ${i == 499 ? '1' : 'v${i + 1}'}${' + 1' * 29}');
      }
      final batch = _batch(text.toString());
      expect(batch.readValue('v0').value, 14501);
      expect(batch.operations, 14500);
    },
  );
}
