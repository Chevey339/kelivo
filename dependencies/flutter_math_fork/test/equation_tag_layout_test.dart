import 'package:flutter/material.dart';
import 'package:flutter_math_fork/ast.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_math_fork/src/parser/tex/parser.dart';
import 'package:flutter_math_fork/src/render/layout/eqn_array.dart';
import 'package:flutter_math_fork/src/render/layout/line.dart';
import 'package:flutter_math_fork/src/render/layout/line_editable.dart';
import 'package:flutter_test/flutter_test.dart';

EquationRowNode _row(String text, {Mode mode = Mode.math}) => EquationRowNode(
      children: [
        for (final rune in text.runes)
          SymbolNode(symbol: String.fromCharCode(rune), mode: mode),
      ],
    );

Widget _arrayHarness({
  required double width,
  required List<Widget> rows,
  required List<Widget?> tags,
  TextDirection textDirection = TextDirection.ltr,
}) =>
    MaterialApp(
      home: Directionality(
        textDirection: textDirection,
        child: Center(
          child: SizedBox(
            key: const ValueKey('display'),
            width: width,
            child: DefaultTextStyle(
              style: const TextStyle(fontSize: 16, color: Colors.black),
              child: EqnArray(
                ruleThickness: 1,
                jotSize: 0,
                arrayskip: 12,
                tagGap: 16,
                expandToMaxWidth: true,
                hlines: List.filled(
                  rows.length + 1,
                  MatrixSeparatorStyle.none,
                ),
                rowSpacings: List.filled(rows.length, 0),
                rows: rows,
                tags: tags,
              ),
            ),
          ),
        ),
      ),
    );

Rect _rect(WidgetTester tester, Finder finder) => tester.getRect(finder);

Line _alignedRow({
  required String left,
  required String right,
  required Key leftKey,
  required Key rightKey,
}) =>
    Line(
      children: [
        Text(left, key: leftKey),
        const LineElement(
          alignerOrSpacer: true,
          child: SizedBox.shrink(),
        ),
        Text(right, key: rightKey),
      ],
    );

void main() {
  test('equation arrays retain parallel body and tag slots', () {
    final firstBody = _row('a');
    final firstTag = _row('(A)', mode: Mode.text);
    final secondBody = _row('b');
    final array = EquationArrayNode(
      body: [firstBody, secondBody],
      tags: [firstTag, null],
      displayLayout: true,
    );

    expect(array.children, [firstBody, firstTag, secondBody, null]);
    expect(array.toJson()['tags'], isNotNull);
    expect(array.copyWith().tags, [firstTag, null]);

    final replacementTag = _row('B', mode: Mode.text);
    final updated = array.updateChildren([
      firstBody,
      replacementTag,
      secondBody,
      null,
    ]);
    expect(updated.body, [firstBody, secondBody]);
    expect(updated.tags, [replacementTag, null]);
  });

  for (final direction in TextDirection.values) {
    testWidgets(
        'centers a single body and keeps its tag at the physical right in $direction',
        (tester) async {
      const bodyKey = ValueKey('body');
      const tagKey = ValueKey('tag');
      await tester.pumpWidget(_arrayHarness(
        width: 360,
        textDirection: direction,
        rows: const [Text('x + y', key: bodyKey)],
        tags: const [Text('(A)', key: tagKey)],
      ));

      final display = _rect(tester, find.byKey(const ValueKey('display')));
      final body = _rect(tester, find.byKey(bodyKey));
      final tag = _rect(tester, find.byKey(tagKey));

      expect(body.center.dx, closeTo(display.center.dx, 0.01));
      expect(tag.right, closeTo(display.right, 0.01));
      expect(body.top, closeTo(tag.top, 0.01));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('shares body alignment columns without including row tags',
      (tester) async {
    const leftOneKey = ValueKey('left-one');
    const rightOneKey = ValueKey('right-one');
    const leftTwoKey = ValueKey('left-two');
    const rightTwoKey = ValueKey('right-two');
    const tagOneKey = ValueKey('tag-one');
    const tagTwoKey = ValueKey('tag-two');
    await tester.pumpWidget(_arrayHarness(
      width: 420,
      rows: [
        _alignedRow(
          left: 'LLLL',
          right: 'r',
          leftKey: leftOneKey,
          rightKey: rightOneKey,
        ),
        _alignedRow(
          left: 'l',
          right: 'RRRR',
          leftKey: leftTwoKey,
          rightKey: rightTwoKey,
        ),
      ],
      tags: const [
        Text('(A)', key: tagOneKey),
        Text('LONG', key: tagTwoKey),
      ],
    ));

    final display = _rect(tester, find.byKey(const ValueKey('display')));
    final bodyLeft = _rect(tester, find.byKey(leftOneKey)).left;
    final bodyRight = _rect(tester, find.byKey(rightTwoKey)).right;
    expect((bodyLeft + bodyRight) / 2, closeTo(display.center.dx, 0.01));
    expect(
      _rect(tester, find.byKey(rightOneKey)).left,
      closeTo(_rect(tester, find.byKey(rightTwoKey)).left, 0.01),
    );
    expect(
      _rect(tester, find.byKey(tagOneKey)).right,
      closeTo(display.right, 0.01),
    );
    expect(
      _rect(tester, find.byKey(tagTwoKey)).right,
      closeTo(display.right, 0.01),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('moves a colliding tag below a centered body at tight widths',
      (tester) async {
    const bodyKey = ValueKey('body');
    const tagKey = ValueKey('tag');
    await tester.pumpWidget(_arrayHarness(
      width: 80,
      rows: const [Text('a very wide equation', key: bodyKey)],
      tags: const [Text('(wide tag)', key: tagKey)],
    ));

    final display = _rect(tester, find.byKey(const ValueKey('display')));
    final body = _rect(tester, find.byKey(bodyKey));
    final tag = _rect(tester, find.byKey(tagKey));
    expect(body.center.dx, closeTo(display.center.dx, 0.01));
    expect(tag.right, closeTo(display.right, 0.01));
    expect(tag.top, greaterThanOrEqualTo(body.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('root equation rows pass display constraints through',
      (tester) async {
    final array = EquationArrayNode(
      body: [_row('x+y')],
      tags: [_row('(1)', mode: Mode.text)],
      displayLayout: true,
    );
    final ast = SyntaxTree(
      greenRoot: EquationRowNode(children: [array]),
    );

    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: SizedBox(
          width: 320,
          child: Math(ast: ast),
        ),
      ),
    ));

    expect(tester.getSize(find.byType(EqnArray)).width, closeTo(320, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('selectable display arrays use the parent display width',
      (tester) async {
    final ast = SyntaxTree(
      greenRoot: TexParser(
        r'x\tag{1}',
        const TexParserSettings(displayMode: true),
      ).parse(),
    );

    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: SizedBox(
          width: 320,
          child: SelectableMath(ast: ast),
        ),
      ),
    ));
    await tester.tap(find.byType(SelectableMath));
    await tester.pump();

    expect(ast.greenRoot.key, isNotNull);
    final arrayRenderObject =
        tester.renderObject<RenderEqnArray>(find.byType(EqnArray));
    final body = arrayRenderObject.firstChild!;
    final bodyParentData = body.parentData! as EqnArrayParentData;
    final tag = bodyParentData.nextSibling!;
    final tagParentData = tag.parentData! as EqnArrayParentData;
    final editableLine = ast.greenRoot.key!.currentContext!.findRenderObject()!
        as RenderEditableLine;

    expect(arrayRenderObject.constraints.minWidth, closeTo(320, 0.01));
    expect(arrayRenderObject.constraints.maxWidth, closeTo(320, 0.01));
    expect(arrayRenderObject.size.width, closeTo(320, 0.01));
    expect(
      bodyParentData.offset.dx + body.size.width / 2,
      closeTo(arrayRenderObject.size.width / 2, 0.01),
    );
    expect(
      tagParentData.offset.dx + tag.size.width,
      closeTo(arrayRenderObject.size.width, 0.01),
    );
    expect(
      ast.greenRoot.key!.currentContext!.findRenderObject(),
      same(editableLine),
    );
    expect(editableLine.toStringShort(), isNot(contains('OVERFLOWING')));
    expect(tester.takeException(), isNull);
  });
}
