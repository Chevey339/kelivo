import 'package:Kelivo/features/home/controllers/scroll_controller.dart';
import 'package:Kelivo/shared/widgets/scroll_layout_anchor.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final wheelFirst in [false, true]) {
    testWidgets(
      'image layout and wheel input share a frame: wheelFirst=$wheelFirst',
      (tester) async {
        final controller = ChatAutoFollowScrollController();
        addTearDown(controller.dispose);
        final height = ValueNotifier(200.0);
        addTearDown(height.dispose);
        final imageKey = GlobalKey();
        await tester.pumpWidget(_history(controller, height, imageKey));
        controller.jumpTo(tester.getCenter(find.text('Reading 40')).dy - 300);
        await tester.pump();
        final before = tester.getCenter(find.text('Reading 40')).dy;

        Future<void> wheel() => tester.sendEventToBinding(
          const PointerScrollEvent(
            position: Offset(400, 300),
            scrollDelta: Offset(0, -80),
          ),
        );

        if (wheelFirst) await wheel();
        preserveScrollLayoutAnchor(imageKey.currentContext!);
        height.value += 400;
        if (!wheelFirst) await wheel();
        await tester.pump();
        expect(
          tester.getCenter(find.text('Reading 40')).dy,
          closeTo(before + 80, .5),
        );
        await tester.pump();
        expect(
          tester.getCenter(find.text('Reading 40')).dy,
          closeTo(before + 80, .5),
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('an existing layout correction is not applied twice', (
    tester,
  ) async {
    final controller = ChatAutoFollowScrollController();
    addTearDown(controller.dispose);
    final height = ValueNotifier(200.0);
    addTearDown(height.dispose);
    final imageKey = GlobalKey();
    await tester.pumpWidget(_history(controller, height, imageKey));
    controller.jumpTo(tester.getCenter(find.text('Reading 40')).dy - 300);
    await tester.pump();
    final before = tester.getCenter(find.text('Reading 40')).dy;

    preserveScrollLayoutAnchor(imageKey.currentContext!);
    height.value += 400;
    // Virtualized message blocks can already compensate their prefix delta
    // with correctBy, before the outer viewport performs its next layout.
    controller.position.correctBy(400);
    await tester.pump();
    expect(tester.getCenter(find.text('Reading 40')).dy, closeTo(before, .5));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a pending image anchor yields to explicit bottom navigation', (
    tester,
  ) async {
    final controller = ChatAutoFollowScrollController();
    addTearDown(controller.dispose);
    final height = ValueNotifier(200.0);
    addTearDown(height.dispose);
    final imageKey = GlobalKey();
    await tester.pumpWidget(_history(controller, height, imageKey));
    controller.jumpTo(tester.getCenter(find.text('Reading 40')).dy - 300);
    await tester.pump();

    preserveScrollLayoutAnchor(imageKey.currentContext!);
    height.value += 400;
    final request = controller.requestPositionAtBottomDuringLayout();
    await tester.pump();
    expect(controller.offset, controller.position.maxScrollExtent);
    controller.finishPositionAtBottomDuringLayout(request);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Widget _history(
  ChatAutoFollowScrollController controller,
  ValueNotifier<double> height,
  Key imageKey,
) => MaterialApp(
  home: Scaffold(
    body: CustomScrollView(
      controller: controller,
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ValueListenableBuilder<double>(
                valueListenable: height,
                builder: (_, value, _) =>
                    SizedBox(key: imageKey, height: value),
              ),
              for (var i = 0; i < 100; i++) Text('Reading $i'),
            ],
          ),
        ),
      ],
    ),
  ),
);
