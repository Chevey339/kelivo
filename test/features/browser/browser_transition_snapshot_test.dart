import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/features/browser/widgets/browser_transition_snapshot.dart';

void main() {
  testWidgets('one resolved page is reused until motion settles or cancels', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(200, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final motion = AnimationController(vsync: tester, value: 1);
    final color = ValueNotifier<Color>(Colors.blue);
    var paints = 0;
    var mounts = 0;
    var taps = 0;
    Color? lastPaint;
    await tester.pumpWidget(
      MaterialApp(
        home: BrowserTransitionSnapshot(
          animation: motion,
          child: _MountProbe(
            onMount: () => mounts++,
            child: ValueListenableBuilder<Color>(
              valueListenable: color,
              builder: (_, value, _) => GestureDetector(
                onTap: () => taps++,
                child: CustomPaint(
                  painter: _CountPaint(value, () {
                    paints++;
                    lastPaint = value;
                  }),
                  child: const Center(child: Text('Action')),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Action'));
    expect(taps, 1);
    motion.value = .9;
    await tester.pump();
    final capturedPaints = paints;
    expect(capturedPaints, greaterThan(0));
    expect(
      tester
          .widget<SnapshotWidget>(find.byType(SnapshotWidget))
          .controller
          .allowSnapshotting,
      isTrue,
    );
    for (final value in [.7, .4, .75]) {
      motion.value = value;
      await tester.pump();
      expect(paints, capturedPaints);
    }
    color.value = Colors.red;
    await tester.pump();
    expect(paints, capturedPaints);
    await tester.tap(find.text('Action'), warnIfMissed: false);
    expect(taps, 1);

    // Cancelling a back gesture restores the same live widgets, including
    // changes that arrived while their resolved image was being shown.
    motion.value = 1;
    await tester.pump();
    expect(paints, greaterThan(capturedPaints));
    expect(lastPaint, Colors.red);
    expect(mounts, 1);
    expect(
      tester
          .widget<SnapshotWidget>(find.byType(SnapshotWidget))
          .controller
          .allowSnapshotting,
      isFalse,
    );
    await tester.tap(find.text('Action'));
    expect(taps, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    motion.dispose();
    color.dispose();
  });

  testWidgets(
    'zero-duration arrival restores input without taking a snapshot',
    (tester) async {
      final motion = AnimationController(vsync: tester);
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: BrowserTransitionSnapshot(
            animation: motion,
            child: GestureDetector(
              onTap: () => taps++,
              child: const Center(child: Text('Ready')),
            ),
          ),
        ),
      );
      motion.value = 1;
      await tester.pump();
      await tester.tap(find.text('Ready'));
      expect(taps, 1);
      expect(
        tester
            .widget<SnapshotWidget>(find.byType(SnapshotWidget))
            .controller
            .allowSnapshotting,
        isFalse,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      motion.dispose();
    },
  );
}

class _CountPaint extends CustomPainter {
  _CountPaint(this.color, this.onPaint);
  final Color color;
  final VoidCallback onPaint;
  @override
  void paint(Canvas canvas, Size size) {
    onPaint();
    canvas.drawRect(Offset.zero & size, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_CountPaint oldDelegate) => oldDelegate.color != color;
}

class _MountProbe extends StatefulWidget {
  const _MountProbe({required this.onMount, required this.child});
  final VoidCallback onMount;
  final Widget child;
  @override
  State<_MountProbe> createState() => _MountProbeState();
}

class _MountProbeState extends State<_MountProbe> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
