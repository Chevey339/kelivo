import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream.dart';

mixin _SelectionSeed on MultiSelectableSelectionContainerDelegate {
  void selectChild() {
    currentSelectionStartIndex = currentSelectionEndIndex = 0;
    layoutDidChange();
  }
}

class _NativeDelegate extends StaticSelectionContainerDelegate
    with _SelectionSeed {}

class _OptimizedDelegate extends StableSelectionDelegate with _SelectionSeed {}

class _Selectable extends ChangeNotifier with Selectable {
  double offset = 0;
  int transforms = 0, rangeReads = 0;
  @override
  Matrix4 getTransformTo(RenderObject? ancestor) {
    transforms++;
    return Matrix4.translationValues(0, offset, 0);
  }

  @override
  List<Rect> get boundingBoxes => [Offset.zero & size];
  @override
  Size get size => const Size(200, 300);
  @override
  int get contentLength => 20;
  @override
  SelectionGeometry get value => SelectionGeometry(
    status: SelectionStatus.uncollapsed,
    hasContent: true,
    startSelectionPoint: const SelectionPoint(
      localPosition: Offset(5, 12),
      lineHeight: 12,
      handleType: TextSelectionHandleType.left,
    ),
    endSelectionPoint: const SelectionPoint(
      localPosition: Offset(25, 220),
      lineHeight: 12,
      handleType: TextSelectionHandleType.right,
    ),
    selectionRects: List.generate(100, (i) => Rect.fromLTWH(5, i * 2, 20, 2)),
  );
  @override
  SelectedContentRange? getSelection() {
    rangeReads++;
    return const SelectedContentRange(startOffset: 0, endOffset: 20);
  }

  @override
  SelectedContent? getSelectedContent() =>
      const SelectedContent(plainText: 'abcdefghijklmnopqrst');
  @override
  SelectionResult dispatchSelectionEvent(SelectionEvent event) =>
      SelectionResult.end;
  @override
  void pushHandleLayers(LayerLink? startHandle, LayerLink? endHandle) {}
}

void main() {
  testWidgets(
    'selection geometry matches Flutter with one transform per child per update',
    (tester) async {
      final native = _NativeDelegate();
      final optimized = _OptimizedDelegate();
      final children = [_Selectable(), _Selectable()];
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 300,
            height: 400,
            child: Stack(
              children: [
                for (final delegate in [native, optimized])
                  SelectionContainer(
                    delegate: delegate,
                    child: const SizedBox.expand(),
                  ),
              ],
            ),
          ),
        ),
      );
      native.add(children[0]);
      optimized.add(children[1]);
      await tester.pump();
      expect(optimized.getSelection(), isNull);
      expect(children[1].rangeReads, 0);
      for (final offset in [0.0, 25.0, -20.0]) {
        for (var i = 0; i < 2; i++) {
          final delegate = <_SelectionSeed>[native, optimized][i];
          children[i]
            ..offset = offset
            ..transforms = 0;
          delegate.selectChild();
        }
        expect(optimized.value, native.value);
        expect(children[0].transforms, greaterThanOrEqualTo(100));
        expect(children[1].transforms, 1);
        expect(optimized.getSelection(), native.getSelection());
      }
      native.remove(children[0]);
      optimized.remove(children[1]);
      await tester.pumpWidget(const SizedBox.shrink());
      native.dispose();
      optimized.dispose();
      for (final child in children) {
        child.dispose();
      }
      expect(tester.takeException(), isNull);
    },
  );
}
