import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream.dart';

class _NativeOrder extends StaticSelectionContainerDelegate {
  Comparator<Selectable> get order => compareOrder;
}

class _CachedOrder extends StableSelectionDelegate {
  Comparator<Selectable> get order => compareOrder;
}

class _Selectable extends ChangeNotifier with Selectable {
  _Selectable(this.rect);
  Rect rect;
  int transforms = 0;
  final events = <SelectionEventType>[];
  @override
  Matrix4 getTransformTo(RenderObject? ancestor) {
    transforms++;
    return Matrix4.translationValues(rect.left, rect.top, 0);
  }

  @override
  List<Rect> get boundingBoxes => [Offset.zero & rect.size];
  @override
  Size get size => rect.size;
  @override
  SelectionGeometry get value =>
      const SelectionGeometry(status: SelectionStatus.none, hasContent: true);
  @override
  int get contentLength => 1;
  @override
  SelectedContent? getSelectedContent() => null;
  @override
  SelectedContentRange? getSelection() => null;
  @override
  SelectionResult dispatchSelectionEvent(SelectionEvent event) {
    events.add(event.type);
    return SelectionResult.none;
  }

  @override
  void pushHandleLayers(LayerLink? startHandle, LayerLink? endHandle) {}
}

void main() {
  testWidgets('an empty container remembers edges when new text registers', (
    tester,
  ) async {
    final delegate = StableSelectionDelegate();
    await tester.pumpWidget(
      MaterialApp(
        home: SelectionContainer(
          delegate: delegate,
          child: const SizedBox(width: 200, height: 100),
        ),
      ),
    );
    delegate.dispatchSelectionEvent(
      const SelectionEdgeUpdateEvent.forStart(globalPosition: Offset.zero),
    );
    delegate.dispatchSelectionEvent(
      const SelectionEdgeUpdateEvent.forEnd(globalPosition: Offset(200, 100)),
    );
    final child = _Selectable(const Rect.fromLTWH(0, 0, 200, 100));
    delegate.add(child);
    await tester.pump();
    expect(
      child.events,
      containsAll([
        SelectionEventType.startEdgeUpdate,
        SelectionEventType.endEdgeUpdate,
      ]),
    );
    delegate.remove(child);
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    child.dispose();
    delegate.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('registration ordering matches Flutter and releases geometry', (
    tester,
  ) async {
    final native = _NativeOrder();
    final cached = _CachedOrder();
    final items = List.generate(
      64,
      (i) => _Selectable(
        Rect.fromLTWH((i % 3) * 12, ((i * 29) % 64) * 20, 40, 24),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SelectionContainer(delegate: cached, child: const SizedBox()),
      ),
    );
    final expected = <Selectable>[...items]..sort(native.order);
    for (final item in items) {
      item.transforms = 0;
      cached.add(item);
    }
    final sorted = <Selectable>[...items]..sort(cached.order);
    expect(sorted, orderedEquals(expected));
    expect(items.every((item) => item.transforms == 1), isTrue);
    await tester.pump();

    // A later layout/input must never reuse a previous batch's screen bounds.
    for (final item in items) {
      item.rect = item.rect.translate(0, -2 * item.rect.top);
      item.transforms = 0;
    }
    expect(
      <Selectable>[...items]..sort(cached.order),
      orderedEquals(<Selectable>[...items]..sort(native.order)),
    );
    final extra = _Selectable(const Rect.fromLTWH(3, -900, 40, 24));
    cached.add(extra);
    final all = [...items, extra];
    expect(
      <Selectable>[...all]..sort(cached.order),
      orderedEquals(<Selectable>[...all]..sort(native.order)),
    );
    cached.dispatchSelectionEvent(const ClearSelectionEvent());
    extra.rect = extra.rect.translate(0, -1000);
    expect(
      <Selectable>[...all]..sort(cached.order),
      orderedEquals(<Selectable>[...all]..sort(native.order)),
    );
    for (final item in all) {
      cached.remove(item);
      item.dispose();
    }
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    cached.dispose();
    native.dispose();
    expect(tester.takeException(), isNull);
  });
}
