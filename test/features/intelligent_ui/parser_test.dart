import 'dart:convert';
import 'dart:math';

import 'package:Kelivo/features/intelligent_ui/catalog/ui_budgets.dart';
import 'package:Kelivo/features/intelligent_ui/catalog/ui_catalog.dart';
import 'package:Kelivo/features/intelligent_ui/protocol/ui_diagnostic.dart';
import 'package:Kelivo/features/intelligent_ui/protocol/ui_ir.dart';
import 'package:Kelivo/features/intelligent_ui/protocol/ui_stream_parser.dart';
import 'package:flutter_test/flutter_test.dart';

String _source(String body) => '${UiCatalog.header}\n$body';
UiParseSnapshot _parse(String body) =>
    UiStreamParser().update(_source(body), closed: true);
Set<UiDiagnosticCode> _codes(UiParseSnapshot value) =>
    value.program.diagnostics.map((e) => e.code).toSet();

const _calculator = r'''root = Column(children=[form,result,ask,reset])
$a: number = 2
$b: number = 1
$useOffset: boolean = true
let offset = $useOffset ? $b : 0
let resultValue = $a * 5 + offset
form = Form(children=[slope,offsetToggle,offsetInput])
slope = Slider(label="斜率 😀", bind=$a, min=-5, max=5, step=0.1)
offsetToggle = Switch(label="启用截距", bind=$useOffset)
offsetInput = NumberField(label="截距", bind=$b, visible=$useOffset)
result = Metric(label="Result", value=resultValue)
ask = Button(label="Explain", form=form, action=Ask(text="Explain.", context={"a":$a,"result":resultValue}))
reset = Button(label="Reset", action=Reset())''';

void main() {
  for (final spec in UiCatalog.components.values) {
    test('${spec.name}: complete and arbitrarily chunked example', () {
      final expected = UiStreamParser().update(spec.example, closed: true);
      expect(expected.invalid, isFalse);
      expect(expected.program.diagnostics, isEmpty);
      final parser = UiStreamParser();
      final random = Random(1043);
      var end = 0;
      while (end < spec.example.length) {
        end = min(end + 1 + random.nextInt(7), spec.example.length);
        parser.update(spec.example.substring(0, end));
      }
      expect(
        parser.update(spec.example, closed: true).toJson(),
        expected.toJson(),
      );
    });
  }

  test('every cut is equivalent across CRLF, Unicode and named actions', () {
    for (final source in [
      _source(_calculator),
      _source(_calculator).replaceAll('\n', '\r\n'),
    ]) {
      final expected = UiStreamParser().update(source, closed: true);
      expect(expected.program.diagnostics, isEmpty);
      for (var cut = 0; cut <= source.length; cut++) {
        final parser = UiStreamParser();
        parser.append(source.substring(0, cut));
        final result = parser.append(source.substring(cut), closed: true);
        expect(result.toJson(), expected.toJson(), reason: 'cut=$cut');
      }
    }
  });

  test(
    'header, pending CR and the final unterminated declaration commit once',
    () {
      final parser = UiStreamParser();
      expect(parser.update(UiCatalog.header).headerAccepted, isFalse);
      expect(parser.update('${UiCatalog.header}\r').headerAccepted, isFalse);
      expect(parser.update('${UiCatalog.header}\r\n').headerAccepted, isTrue);
      final source = '${UiCatalog.header}\r\nroot = Text(text="Ready")';
      final open = parser.update(source);
      expect(open.committedRecords, 0);
      expect(open.program.declarations, isEmpty);
      final closed = parser.update(source, closed: true);
      expect(closed.committedRecords, 1);
      expect(closed.program.diagnostics, isEmpty);
      expect(parser.update(source, closed: true), same(closed));
    },
  );

  test(
    'forward references heal and only unresolved closed references fail',
    () {
      final parser = UiStreamParser();
      final source = _source(
        'root = Column(children=[a,b])\na = Text(text="A")\n',
      );
      final pending = parser.update(source);
      expect(pending.program.pendingSymbols, contains('b'));
      expect(pending.program.diagnostics, isEmpty);
      final complete = parser.update(
        '${source}b = Text(text="B")',
        closed: true,
      );
      expect(complete.program.diagnostics, isEmpty);
      final missing = UiStreamParser().update(source, closed: true);
      expect(missing.invalid, isFalse);
      expect(missing.program.failedSymbols, contains('b'));
      expect(missing.program.failedSymbols, isNot(contains('a')));
      expect(_codes(missing), contains(UiDiagnosticCode.missingReference));
    },
  );

  test('unknown component/property errors stay in their own branches', () {
    final value = _parse(
      'root = Column(children=[bad,other,good])\nbad = Gauge(value=1)\nother = Text(text="Wrong", color="red")\ngood = Text(text="Healthy")',
    );
    expect(value.invalid, isFalse);
    expect(value.program.failedSymbols, {'bad', 'other'});
    expect(_codes(value), {
      UiDiagnosticCode.unknownComponent,
      UiDiagnosticCode.unknownProperty,
    });
    expect(_parse('root = Gauge(value=1)').invalid, isTrue);
  });

  test(
    'duplicate symbols preserve the first declaration but poison the symbol',
    () {
      final value = _parse(
        'root = Column(children=[a,good])\na = Text(text="First")\na = Text(text="Second")\ngood = Text(text="Healthy")',
      );
      expect(value.invalid, isFalse);
      final a = value.program.declarations['a']! as UiNodeDeclaration;
      expect((a.arguments['text']! as UiLiteral).value, 'First');
      expect(value.program.failedSymbols, contains('a'));
      expect(value.program.diagnostics.single.line, 4);
    },
  );

  test('state, value and component names share one namespace', () {
    final result = _parse(r'''root = Column(children=[field])
$amount: number = 2
amount = Metric(label="Amount", value=3)
field = Slider(label="Amount", bind=$amount, min=0, max=10)''');
    expect(_codes(result), contains(UiDiagnosticCode.duplicateSymbol));
    expect(result.program.failedSymbols, containsAll(['amount', 'field']));
  });

  test('data cycles and their consumers fail without invalidating siblings', () {
    final result = _parse(
      'root = Column(children=[bad,good])\nlet a = b + 1\nlet b = a + 1\nbad = Metric(label="Bad", value=a)\ngood = Text(text="Healthy")',
    );
    expect(result.invalid, isFalse);
    expect(result.program.failedSymbols, containsAll(['a', 'b', 'bad']));
    expect(result.program.failedSymbols, isNot(contains('good')));
    expect(_codes(result), contains(UiDiagnosticCode.cycle));
  });

  test('structural cycles and multiple parents are rejected', () {
    expect(
      _codes(
        _parse('root = Column(children=[a])\na = Column(children=[root])'),
      ),
      contains(UiDiagnosticCode.cycle),
    );
    final duplicate = _parse(
      'root = Column(children=[a,b])\na = Column(children=[field])\nb = Column(children=[field])\nfield = Text(text="Once")',
    );
    expect(duplicate.program.failedSymbols, contains('field'));
    expect(_codes(duplicate), contains(UiDiagnosticCode.duplicateParent));
    expect(
      _codes(_parse('root = Column(children=[a,a])\na = Text(text="Once")')),
      contains(UiDiagnosticCode.duplicateParent),
    );
  });

  test('an internal button can associate with its containing Form', () {
    final value = UiStreamParser().update(
      UiCatalog.components['Form']!.example,
      closed: true,
    );
    expect(value.program.diagnostics, isEmpty);
    final button = value.program.declarations['ask']! as UiNodeDeclaration;
    expect(button.arguments['form'], isA<UiFormRef>());
    expect(value.program.children['root'], ['nameField', 'ask']);
    expect(value.program.dependencies['ask'], contains('root'));
    expect(value.program.children['ask'], isNull);
  });

  test('unreachable layout cycles are diagnosed without invalidating root', () {
    final value = _parse(
      'root = Text(text="Healthy")\na = Column(children=[b])\nb = Column(children=[a])',
    );
    expect(value.invalid, isFalse);
    final members = value.program.diagnostics
        .where((e) => e.code == UiDiagnosticCode.cycle)
        .map((e) => e.symbol)
        .toSet();
    expect(members, {'a', 'b'});
  });

  test('bindings require writable states of the declared input type', () {
    for (final body in [
      'let a = 2\nroot = Slider(label="A", bind=a, min=0, max=5)',
      r'$a: number = 2'
          '\n'
          r'root = Slider(label="A", bind=($a*2), min=0, max=5)',
      r'$a: string = "2"'
          '\n'
          r'root = Slider(label="A", bind=$a, min=0, max=5)',
      r'$a: number? = null'
          '\n'
          r'root = Slider(label="A", bind=$a, min=0, max=5)',
    ]) {
      expect(
        _codes(_parse(body)),
        contains(UiDiagnosticCode.invalidBinding),
        reason: body,
      );
    }
    expect(
      _parse(
        r'$a: number? = null'
        '\n'
        r'root = NumberField(label="A", bind=$a)',
      ).program.diagnostics,
      isEmpty,
    );
  });

  test('node references are not arithmetic values or writable paths', () {
    final value = _parse(
      'root = Column(children=[a,b])\na = Text(text="A")\nb = Metric(label="B", value=a + 1)',
    );
    expect(_codes(value), contains(UiDiagnosticCode.typeMismatch));
    expect(value.program.failedSymbols, {'b'});
  });

  test('syntax consumes the full record and rejects unsupported effects', () {
    for (final text in [
      'root = Text(text="A");',
      'root = Text(text="A") trailing',
      'root = Text(text="A", text="B")',
      'root = Text(text="bad\\q")',
      'root = Metric(label="A", value=@random())',
      'root = Button(label="A", action=OpenUrl(url="https://example.test"))',
      'root = Metric(label="A", value=some.member)',
      'root = Metric(label="A", value=[1,2,])',
    ]) {
      final result = _parse(text);
      expect(result.invalid, isTrue, reason: text);
      expect(result.program.diagnostics, isNotEmpty);
    }
  });

  test(
    'rewrite and truncation advance the epoch and discard consumed state',
    () {
      final parser = UiStreamParser();
      final original = _source('root = Text(text="Original")\n');
      final a = parser.update(original);
      final rewritten = original.replaceAll('Original', 'New');
      final b = parser.update(rewritten);
      expect(b.epoch, a.epoch + 1);
      expect(b.committedRecords, 1);
      expect(b.program.diagnostics, isEmpty);
      final truncated = parser.update('${UiCatalog.header}\n');
      expect(truncated.epoch, b.epoch + 1);
      expect(truncated.program.declarations, isEmpty);
      expect(
        parser.update(original, closed: true).program.diagnostics,
        isEmpty,
      );
    },
  );

  test('invalid headers and missing root are whole-surface errors', () {
    for (final header in [
      '',
      'ui 2 catalog "kelivo.native/1"',
      'ui 1 catalog "other"',
      'ui 1 catalog "kelivo.native/1" extra',
    ]) {
      expect(
        UiStreamParser()
            .update('$header\nroot = Text(text="A")', closed: true)
            .invalid,
        isTrue,
      );
    }
    expect(_parse('a = Text(text="A")').invalid, isTrue);
  });

  test('resource limits use UTF-8 bytes and do not truncate silently', () {
    final body = 'root = Text(text="${'中' * 50000}")';
    expect(body.length, lessThan(UiBudgets.declarationBytes));
    expect(utf8.encode(body).length, greaterThan(UiBudgets.declarationBytes));
    expect(_codes(_parse(body)), contains(UiDiagnosticCode.declarationBudget));
    expect(
      _codes(_parse('root = Text(text="${'中' * 100000}")')),
      contains(UiDiagnosticCode.sourceBudget),
    );
    expect(
      _codes(
        _parse(
          '${List.generate(65, (i) => '\$s$i: number = 0').join('\n')}\nroot = Text(text="A")',
        ),
      ),
      contains(UiDiagnosticCode.inputCount),
    );
    expect(
      _codes(
        _parse(
          '${List.generate(257, (i) => 'n$i = Text(text="A")').join('\n')}\nroot = Column(children=[])',
        ),
      ),
      contains(UiDiagnosticCode.componentCount),
    );
    expect(
      _codes(
        _parse(
          '${List.generate(513, (i) => 'let n$i = 1').join('\n')}\nroot = Column(children=[])',
        ),
      ),
      contains(UiDiagnosticCode.declarationCount),
    );
  });

  test(
    'parser and AST depth limits reject hostile nesting and long chains',
    () {
      for (final expression in [
        '${'(' * 1000}1${')' * 1000}',
        '${'-' * 1000}1',
        List.filled(1000, '1').join('+'),
      ]) {
        expect(
          _codes(_parse('root = Metric(label="A", value=$expression)')),
          contains(UiDiagnosticCode.expressionDepth),
        );
      }
      final deep = [
        'root = Column(children=[n0])',
        ...List.generate(17, (i) => 'n$i = Column(children=[n${i + 1}])'),
        'n17 = Text(text="Deep")',
      ].join('\n');
      expect(_codes(_parse(deep)), contains(UiDiagnosticCode.componentDepth));
    },
  );

  test('sample scopes are local and nested samples are rejected', () {
    final valid = _parse(
      'let points = @sample(x => x * x, 0, 10, 21)\nroot = Chart(kind="line", data=points, x="x", y=["y"])',
    );
    expect(valid.program.diagnostics, isEmpty);
    expect(valid.program.dependencies['points'], isEmpty);
    final nested = _parse(
      'let points = @sample(x => @sample(y => y, 0, 1, 2), 0, 10, 21)\nroot = Chart(kind="line", data=points, x="x", y=["y"])',
    );
    expect(_codes(nested), contains(UiDiagnosticCode.nestedSample));
    expect(
      _codes(
        _parse(
          'let points = @sample(x => x, 0, 10, 502)\nroot = Chart(kind="line", data=points, x="x", y=["y"])',
        ),
      ),
      contains(UiDiagnosticCode.invalidSample),
    );
  });

  test('diagnostic codes have distinct localization keys', () {
    final keys = UiDiagnosticCode.values.map((e) => e.messageKey).toSet();
    expect(keys, hasLength(UiDiagnosticCode.values.length));
    expect(keys.every((key) => key.startsWith('genuiError')), isTrue);
  });

  test('long valid dependency chains do not multiply the parser stack', () {
    final body = StringBuffer('root = Metric(label="A", value=v0)\n');
    for (var i = 0; i < 500; i++) {
      final next = i == 499 ? '1' : 'v${i + 1}';
      body.writeln('let v$i = $next${' + 1' * 29}');
    }
    final result = _parse(body.toString());
    expect(result.invalid, isFalse);
    expect(result.program.diagnostics, isEmpty);
    expect(result.program.declarations, hasLength(501));
    expect(() => jsonEncode(result.toJson()), returnsNormally);
  });

  test('rejected deep and nonfinite records remain safely serializable', () {
    for (final expression in [List.filled(20000, '1').join('+'), '1e999']) {
      final result = _parse(
        'root = Metric(label="Invalid", value=$expression)',
      );
      expect(result.invalid, isTrue);
      expect(result.program.declarations, isEmpty);
      expect(() => jsonEncode(result.toJson()), returnsNormally);
      expect(result.source, contains(expression));
    }
  });

  test('known syntax failures never become forward-reference placeholders', () {
    final result = UiStreamParser().update(
      _source(
        'root = Column(children=[bad,good])\n'
        'bad = Metric(label="Bad", value=1 + )\n'
        'good = Text(text="Healthy")\n'
        'let dependent = bad + 1\n',
      ),
    );
    expect(result.program.pendingSymbols, isNot(contains('bad')));
    expect(result.program.failedSymbols, containsAll(['bad', 'dependent']));
    expect(result.program.failedSymbols, isNot(contains('good')));
    expect(result.invalid, isFalse);
  });
}
