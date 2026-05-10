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

  testWidgets('visible navigation panel only captures touches on buttons', (
    tester,
  ) async {
    var backgroundTapCount = 0;
    var bottomTapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    backgroundTapCount++;
                  },
                ),
              ),
              ScrollNavButtonsPanel(
                visible: true,
                onScrollToTop: () {},
                onPreviousMessage: () {},
                onNextMessage: () {},
                onScrollToBottom: () {
                  bottomTapCount++;
                },
              ),
            ],
          ),
        ),
      ),
    );

    final hoverRegion = tester.getRect(find.byKey(scrollNavHoverRegionKey));
    final emptyPanelPoint = hoverRegion.topLeft + const Offset(4, 4);
    await tester.tapAt(emptyPanelPoint);
    await tester.pump();

    expect(backgroundTapCount, 1);
    expect(bottomTapCount, 0);

    await tester.tap(find.byIcon(Lucide.ChevronsDown));
    await tester.pump();

    expect(backgroundTapCount, 1);
    expect(bottomTapCount, 1);
  });

  testWidgets('dragging a visible navigation button forwards vertical scroll', (
    tester,
  ) async {
    var dragStartCount = 0;
    var forwardedDelta = 0.0;
    var bottomTapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              ScrollNavButtonsPanel(
                visible: true,
                onScrollDragStart: () {
                  dragStartCount++;
                },
                onScrollDragUpdate: (delta) {
                  forwardedDelta += delta;
                },
                onScrollToTop: () {},
                onPreviousMessage: () {},
                onNextMessage: () {},
                onScrollToBottom: () {
                  bottomTapCount++;
                },
              ),
            ],
          ),
        ),
      ),
    );

    await tester.drag(find.byIcon(Lucide.ChevronsDown), const Offset(0, -80));
    await tester.pump();

    expect(dragStartCount, 1);
    expect(forwardedDelta, lessThan(0));
    expect(bottomTapCount, 0);
  });

  testWidgets('small drag on a navigation button forwards without waiting', (
    tester,
  ) async {
    var dragStartCount = 0;
    var forwardedDelta = 0.0;
    var bottomTapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              ScrollNavButtonsPanel(
                visible: true,
                onScrollDragStart: () {
                  dragStartCount++;
                },
                onScrollDragUpdate: (delta) {
                  forwardedDelta += delta;
                },
                onScrollToTop: () {},
                onPreviousMessage: () {},
                onNextMessage: () {},
                onScrollToBottom: () {
                  bottomTapCount++;
                },
              ),
            ],
          ),
        ),
      ),
    );

    final gesture = await tester.createGesture();
    await gesture.down(tester.getCenter(find.byIcon(Lucide.ChevronsDown)));
    await gesture.moveBy(const Offset(0, -4));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(dragStartCount, 1);
    expect(forwardedDelta, lessThan(0));
    expect(bottomTapCount, 0);
  });
}
