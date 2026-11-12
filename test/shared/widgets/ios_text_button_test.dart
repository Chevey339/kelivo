import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/shared/widgets/ios_text_button.dart';

void main() {
  testWidgets('text actions fade their text without painting a press block', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IosTextButton(label: 'Cancel', onPressed: () => taps++),
        ),
      ),
    );
    final button = find.byType(IosTextButton);
    Color textColor() => tester.widget<Text>(find.text('Cancel')).style!.color!;
    final original = textColor();
    expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
    final gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 150));
    expect(textColor().a, lessThan(original.a));
    expect(
      find.descendant(of: button, matching: find.byType(DecoratedBox)),
      findsNothing,
    );
    expect(
      find.descendant(of: button, matching: find.byType(InkWell)),
      findsNothing,
    );
    await gesture.up();
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(textColor(), original);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(taps, 2);
  });
}
