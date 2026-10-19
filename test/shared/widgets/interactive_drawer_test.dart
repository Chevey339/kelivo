import 'package:Kelivo/shared/widgets/interactive_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('disposing a replaced drawer does not detach its new owner', (
    tester,
  ) async {
    final controller = InteractiveDrawerController();
    Widget app(int generation) => MaterialApp(
      home: InteractiveDrawer(
        key: ValueKey(generation),
        controller: controller,
        drawer: const Text('Topics'),
        child: const Text('Conversation'),
      ),
    );
    await tester.pumpWidget(app(0));
    await controller.open();
    await tester.pumpAndSettle();
    expect(controller.isOpen, isTrue);
    await tester.pumpWidget(app(1));
    await tester.pumpAndSettle();
    expect(controller.isOpen, isTrue);
    await controller.close();
    await tester.pumpAndSettle();
    expect(controller.isClosed, isTrue);
    await controller.open();
    await tester.pumpAndSettle();
    expect(controller.isOpen, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets(
    'drawer motion retains paint and local semantics while content stays live',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final drawer = InteractiveDrawerController();
        final value = ValueNotifier(0);
        addTearDown(drawer.dispose);
        addTearDown(value.dispose);
        var bodyPaints = 0, drawerPaints = 0, taps = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: InteractiveDrawer(
              controller: drawer,
              drawerWidth: 240,
              drawer: _PaintProbe(
                onPaint: () => drawerPaints++,
                child: TextButton(
                  onPressed: () => taps++,
                  child: const Text('Sidebar action'),
                ),
              ),
              child: _PaintProbe(
                onPaint: () => bodyPaints++,
                child: ColoredBox(
                  color: Colors.white,
                  child: Center(
                    child: ValueListenableBuilder<int>(
                      valueListenable: value,
                      builder: (_, count, __) => Text('Live $count'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final initialBodyPaints = bodyPaints;
        final initialDrawerPaints = drawerPaints;
        final node = tester.getSemantics(find.text('Live 0'));
        final initialTransform = node.transform?.storage.toList();
        for (final progress in [.2, .4, .6, .8, 1.0]) {
          drawer.jumpTo(progress);
          await tester.pump();
          final moved = tester.getSemantics(find.text('Live 0'));
          expect(moved.id, node.id);
          expect(moved.transform?.storage, initialTransform);
          expect(bodyPaints, initialBodyPaints);
          expect(drawerPaints, initialDrawerPaints);
        }
        await tester.tap(find.text('Sidebar action'));
        await tester.pumpAndSettle();
        expect(taps, 1);
        value.value = 1;
        await tester.pump();
        expect(tester.getSemantics(find.text('Live 1')).label, 'Live 1');
        expect(bodyPaints, greaterThan(initialBodyPaints));
        final updatedPaints = bodyPaints;
        drawer.jumpTo(.5);
        await tester.pump();
        expect(bodyPaints, updatedPaints);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );
}

class _PaintProbe extends SingleChildRenderObjectWidget {
  const _PaintProbe({required this.onPaint, required super.child});
  final VoidCallback onPaint;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _PaintProbeBox(onPaint);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant _PaintProbeBox renderObject,
  ) {
    renderObject.onPaint = onPaint;
  }
}

class _PaintProbeBox extends RenderProxyBox {
  _PaintProbeBox(this.onPaint);
  VoidCallback onPaint;
  @override
  void paint(PaintingContext context, Offset offset) {
    onPaint();
    super.paint(context, offset);
  }
}
