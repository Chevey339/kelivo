import 'package:Kelivo/features/media/widgets/creation_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('slider snaps touch and keyboard input in both directions', (
    tester,
  ) async {
    for (final direction in TextDirection.values) {
      var value = 5.0;
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: direction,
            child: Center(
              child: SizedBox(
                width: 204,
                child: StatefulBuilder(
                  builder: (context, update) => CreationSlider(
                    value: value,
                    max: 10,
                    divisions: 10,
                    label: 'Position',
                    onChanged: (next) => update(() => value = next),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final bounds = tester.getRect(find.byType(CreationSlider));
      await tester.tapAt(Offset(bounds.left + 54, bounds.center.dy));
      await tester.pump();
      final leftToRight = direction == TextDirection.ltr;
      expect(value, leftToRight ? 2 : 8);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      expect(value, leftToRight ? 3 : 7);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      expect(value, 10);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
