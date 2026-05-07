import 'dart:ui' show PointerDeviceKind;

import 'package:Kelivo/features/home/widgets/scroll_nav_buttons.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('desktop hover hot zone reveals hidden navigation buttons', (
    tester,
  ) async {
    var hovered = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              ScrollNavButtonsPanel(
                visible: hovered,
                hoverEnabled: true,
                onHoverChanged: (value) {
                  hovered = value;
                },
                onScrollToTop: () {},
                onPreviousMessage: () {},
                onNextMessage: () {},
                onScrollToBottom: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byIcon(Lucide.ChevronsDown), findsOneWidget);
    expect(
      tester
          .widget<AnimatedOpacity>(find.byType(AnimatedOpacity).first)
          .opacity,
      0,
    );

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer();
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(find.byKey(scrollNavHoverRegionKey)));
    await tester.pump();

    expect(hovered, isTrue);
  });
}
