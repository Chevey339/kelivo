import 'package:flutter/material.dart';
import 'package:flutter_math_fork/ast.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_math_fork/src/encoder/tex/encoder.dart';
import 'package:flutter_math_fork/src/parser/tex/parser.dart';
import 'package:flutter_test/flutter_test.dart';

EquationRowNode parse(String source, {bool displayMode = true}) =>
    TexParser(source, TexParserSettings(displayMode: displayMode)).parse();

Iterable<GreenNode> descendants(GreenNode node) sync* {
  yield node;
  for (final child in node.children) {
    if (child != null) yield* descendants(child);
  }
}

String symbols(GreenNode node) => descendants(node)
    .whereType<SymbolNode>()
    .map((symbol) => symbol.symbol)
    .join();

void main() {
  group('AMS environments', () {
    for (final name in ['equation', 'equation*']) {
      test('$name preserves the equation body', () {
        final result =
            parse(r'\begin{' + name + r'}a^2+b^2=c^2\end{' + name + '}');
        expect(symbols(result), 'a2+b2=c2');
      });
    }

    for (final name in ['align', 'align*', 'aligned', 'split']) {
      test('$name preserves alignment and omits a trailing empty row', () {
        final result =
            parse(r'\begin{' + name + r'}a&=b\\c&=d\\\end{' + name + '}');
        final array = descendants(result).whereType<EquationArrayNode>().single;
        expect(array.body.map(symbols), ['a=b', 'c=d']);
        expect(
            descendants(array)
                .whereType<SpaceNode>()
                .where((space) => space.alignerOrSpacer),
            isNotEmpty);
      });
    }

    for (final name in ['gather', 'gather*', 'gathered']) {
      test('$name keeps independent centered rows', () {
        final result =
            parse(r'\begin{' + name + r'}a=b\\c=d\end{' + name + '}');
        final array = descendants(result).whereType<EquationArrayNode>().single;
        expect(array.body.map(symbols), ['a=b', 'c=d']);
        expect(
            descendants(array)
                .whereType<SpaceNode>()
                .where((space) => space.alignerOrSpacer),
            isEmpty);
      });
    }

    for (final name in ['alignat', 'alignat*', 'alignedat']) {
      test('$name validates its column count', () {
        expect(() => parse(r'\begin{' + name + r'}{1}a&=b\end{' + name + '}'),
            returnsNormally);
        expect(() => parse(r'\begin{' + name + r'}{1}a&b&c\end{' + name + '}'),
            throwsA(isA<ParseException>()));
      });
    }

    test('nested aligned environment and outer tag stay together', () {
      for (final source in [
        r'\begin{equation}\begin{aligned}'
            r'a&=b\\c&=d\end{aligned}\tag{A}\end{equation}',
        r'\begin{equation}\tag{A}\begin{aligned}'
            r'a&=b\\c&=d\\\end{aligned}\end{equation}',
      ]) {
        final result = parse(source);
        expect(symbols(result), 'a=bc=d(A)');
        final arrays = descendants(result).whereType<EquationArrayNode>();
        final tagged = arrays.singleWhere((array) => array.displayLayout);
        final aligned = arrays.singleWhere((array) => !array.displayLayout);
        expect(tagged.tags.map((tag) => tag == null ? null : symbols(tag)), [
          '(A)',
        ]);
        expect(aligned.body.map(symbols), ['a=b', 'c=d']);
      }
    });

    test('rejects mismatched environments and invalid columns', () {
      for (final source in [
        r'\begin{equation}x\end{align}',
        r'\begin{gather}a&b\end{gather}',
        r'\begin{split}a&b&c\end{split}',
      ]) {
        expect(() => parse(source), throwsA(isA<ParseException>()));
      }
    });
  });

  group('explicit equation labels', () {
    test('tag is placed after the equation regardless of source position', () {
      expect(symbols(parse(r'\tag{A}x+y')), 'x+y(A)');
      expect(symbols(parse(r'x+y\tag{A}')), 'x+y(A)');
      expect(symbols(parse(r'x+y\tag*{A}')), 'x+yA');
    });

    test('tag contents retain text formatting and inline math', () {
      expect(symbols(parse(r'x\tag{\textbf{A} $n+1$}')), 'x(A n+1)');
    });

    test('encoding retains tag commands and their environments', () {
      final regular = parse(r'x\tag{A}').encodeTeX(
        conf: TexEncodeConf.mathParamConf,
      );
      final literal = parse(r'x\tag*{A}').encodeTeX(
        conf: TexEncodeConf.mathParamConf,
      );
      final multiline = parse(
        r'\begin{align}a=b\tag{A}\\c=d\tag*{B}\end{align}',
      ).encodeTeX(conf: TexEncodeConf.mathParamConf);

      expect(regular, r'x\tag{A}');
      expect(literal, r'x\tag*{A}');
      expect(
        multiline,
        r'\begin{align}a=b\tag{A}\\c=d\tag*{B}\end{align}',
      );
    });

    test('each alignment row owns its tag', () {
      for (final name in ['align', 'align*', 'alignat', 'alignat*', 'gather']) {
        final columns = name.startsWith('alignat') ? '{1}' : '';
        final result = parse(r'\begin{' +
            name +
            '}' +
            columns +
            r'a=b\tag{A}\\c=d\tag*{B}\\e=f\end{' +
            name +
            '}');
        final array = descendants(result).whereType<EquationArrayNode>().single;
        expect(array.body.map(symbols), ['a=b', 'c=d', 'e=f']);
        expect(array.tags.map((tag) => tag == null ? null : symbols(tag)), [
          '(A)',
          'B',
          null,
        ]);
      }
    });

    test('rejects inline and duplicate labels', () {
      expect(() => parse(r'x\tag{1}', displayMode: false),
          throwsA(isA<ParseException>()));
      for (final source in [
        r'x\tag{1}\tag{2}',
        r'\begin{align}a\tag{1}\tag{2}\\b\end{align}',
      ]) {
        expect(() => parse(source), throwsA(isA<ParseException>()));
      }
    });
  });

  group('operator names', () {
    test('allows whitespace before the optional star', () {
      final result = parse(r'\operatorname *{arg\,max}_x f(x)');
      expect(symbols(result), 'argmaxxf(x)');
      final operator = descendants(result).whereType<OperatorNameNode>().single;
      expect(operator.limitsInDisplayStyle, isTrue);
      expect(operator.lowerLimit, isNotNull);
    });

    test('leaves right delimiters and environment endings for their owner', () {
      for (final source in [
        r'\left(\operatorname{Var}\right)',
        r'\begin{equation}\operatorname{Var}\end{equation}',
        r'\begin{aligned}\operatorname{Var}&=x\\y&=\operatorname{Var}\end{aligned}',
      ]) {
        expect(() => parse(source), returnsNormally);
      }
    });

    test('starred names retain their default and explicit limit policy', () {
      const source = r'\operatorname*{arg\,max}_{x}f(x)';
      final starred =
          descendants(parse(source)).whereType<OperatorNameNode>().single;
      expect(starred.limitsInDisplayStyle, isTrue);
      expect(starred.limits, isNull);
      expect(starred.lowerLimit, isNotNull);

      final noLimits = descendants(
        parse(r'\operatorname*{arg\,max}\nolimits_x f(x)'),
      ).whereType<OperatorNameNode>().single;
      expect(noLimits.limitsInDisplayStyle, isTrue);
      expect(noLimits.limits, isFalse);
    });
  });

  testWidgets(
      'renders environments, labels and nested operators without fallback',
      (tester) async {
    for (final source in [
      r'\begin{equation}a^2+b^2=c^2\tag{1}\end{equation}',
      r'\begin{align}a&=b\tag{A}\\c&=d\tag*{B}\end{align}',
      r'\begin{gather}a=b\\c=d\end{gather}',
      r'\operatorname{Var}\left(\frac{1}{n}\sum_{i=1}^n a_i X_i\right)',
      r'\operatorname*{arg\,max}_{x}\left(f(x)\right)',
    ]) {
      await tester.pumpWidget(MaterialApp(
        home: Center(
          child: Math.tex(source,
              settings: const TexParserSettings(displayMode: true),
              onErrorFallback: (error) => throw error),
        ),
      ));
      expect(tester.takeException(), isNull, reason: source);
    }
  });
}
