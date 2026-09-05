import 'package:flutter/material.dart';
import 'package:flutter_math_fork/ast.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_math_fork/src/encoder/tex/encoder.dart';
import 'package:flutter_math_fork/src/parser/tex/parser.dart';
import 'package:flutter_math_fork/src/render/layout/multiscripts.dart';
import 'package:flutter_math_fork/src/render/layout/vlist.dart';
import 'package:flutter_test/flutter_test.dart';

EquationRowNode _parse(
  String source, {
  bool displayMode = false,
}) =>
    TexParser(
      source,
      TexParserSettings(displayMode: displayMode),
    ).parse();

Iterable<GreenNode> _descendants(GreenNode node) sync* {
  yield node;
  for (final child in node.children) {
    if (child != null) yield* _descendants(child);
  }
}

Future<void> _pumpOperator(
  WidgetTester tester,
  String source, {
  MathStyle style = MathStyle.display,
  bool parserDisplayMode = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: Math.tex(
          source,
          mathStyle: style,
          settings: TexParserSettings(displayMode: parserDisplayMode),
          onErrorFallback: (error) => throw error,
        ),
      ),
    ),
  );
  expect(tester.takeException(), isNull);
}

void _expectLimitsLayout() {
  expect(find.byType(VList), findsOneWidget);
  expect(find.byType(Multiscripts), findsNothing);
}

void _expectScriptsLayout() {
  expect(find.byType(Multiscripts), findsOneWidget);
  expect(find.byType(VList), findsNothing);
}

void main() {
  test(r'operator argument lookahead leaves \middle for enclosing \left', () {
    final result = _parse(
      r'\left\{\operatorname{dom}\middle|x\right\}',
      displayMode: true,
    );
    final leftRight = _descendants(result).whereType<LeftRightNode>().single;

    expect(leftRight.middle, ['|']);
    expect(leftRight.body, hasLength(2));
  });

  group(r'\operatorname* script layout', () {
    const source = r'\operatorname*{argmax}_{x}';

    testWidgets('uses the widget MathStyle instead of parser displayMode',
        (tester) async {
      await _pumpOperator(tester, source);
      _expectLimitsLayout();

      await _pumpOperator(
        tester,
        source,
        style: MathStyle.text,
        parserDisplayMode: true,
      );
      _expectScriptsLayout();
    });

    testWidgets('honors local style overrides', (tester) async {
      await _pumpOperator(
        tester,
        r'\textstyle\operatorname*{argmax}_{x}',
      );
      _expectScriptsLayout();

      await _pumpOperator(
        tester,
        r'\displaystyle\operatorname*{argmax}_{x}',
        style: MathStyle.text,
      );
      _expectLimitsLayout();
    });

    testWidgets(r'explicit \limits and \nolimits take precedence',
        (tester) async {
      await _pumpOperator(
        tester,
        r'\operatorname*{argmax}\limits_{x}',
        style: MathStyle.text,
      );
      _expectLimitsLayout();

      await _pumpOperator(
        tester,
        r'\operatorname*{argmax}\nolimits_{x}',
      );
      _expectScriptsLayout();
    });
  });

  test('TeX encoding preserves starred operator scripts and limit controls',
      () {
    const source = r'\operatorname*{argmax}\nolimits_{x}f';
    final encoded = _parse(source).encodeTeX(
      conf: TexEncodeConf.mathParamConf,
    );

    expect(encoded, r'\operatorname*{argmax}\nolimits_{x}{f}');
    final operator =
        _descendants(_parse(encoded)).whereType<OperatorNameNode>().single;
    expect(operator.limitsInDisplayStyle, isTrue);
    expect(operator.limits, isFalse);
    expect(operator.lowerLimit, isNotNull);
  });
}
