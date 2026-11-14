import 'package:Kelivo/features/home/controllers/scroll_controller.dart';
import 'package:Kelivo/shared/widgets/scroll_layout_anchor.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

void main() {
  for (final (wheelFirst, delta) in [
    for (final first in [false, true])
      for (final delta in [-80.0, 80.0]) (first, delta),
  ]) {
    testWidgets(
      'image layout and wheel input share a frame: wheelFirst=$wheelFirst, delta=$delta',
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
          PointerScrollEvent(
            position: const Offset(400, 300),
            scrollDelta: Offset(0, delta),
          ),
        );

        if (wheelFirst) await wheel();
        preserveScrollLayoutAnchor(imageKey.currentContext!);
        height.value += 400;
        if (!wheelFirst) await wheel();
        await tester.pump();
        expect(
          tester.getCenter(find.text('Reading 40')).dy,
          closeTo(before - delta, .5),
        );
        await tester.pump();
        expect(
          tester.getCenter(find.text('Reading 40')).dy,
          closeTo(before - delta, .5),
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

  testWidgets('a pending image anchor yields to a small navigation jump', (
    tester,
  ) async {
    final controller = ChatAutoFollowScrollController();
    addTearDown(controller.dispose);
    final height = ValueNotifier(200.0);
    addTearDown(height.dispose);
    final imageKey = GlobalKey();
    await tester.pumpWidget(_history(controller, height, imageKey));
    controller.jumpTo(500);
    await tester.pump();

    preserveScrollLayoutAnchor(imageKey.currentContext!);
    height.value += 400;
    controller.jumpTo(400);
    await tester.pump();
    expect(controller.offset, 400);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final imageGrowth in [0.0, 2000.0]) {
    testWidgets(
      'image anchor follows a shifted history window: growth=$imageGrowth',
      (tester) async {
        final scroll = ChatAutoFollowScrollController();
        final list = ListController();
        final messages = ValueNotifier(List.generate(30, (i) => i));
        final imageKey = GlobalKey();
        var height = 100.0;
        addTearDown(scroll.dispose);
        addTearDown(list.dispose);
        addTearDown(messages.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ValueListenableBuilder<List<int>>(
                valueListenable: messages,
                builder: (context, ids, _) => SuperListView.builder(
                  controller: scroll,
                  listController: list,
                  cacheExtent: 600,
                  delayPopulatingCacheArea: false,
                  extentEstimation: (_, _) => 100,
                  itemCount: ids.length,
                  findChildIndexCallback: (key) {
                    final index = ids.indexOf((key as ValueKey<int>).value);
                    return index < 0 ? null : index;
                  },
                  itemBuilder: (context, index) {
                    final id = ids[index];
                    return KeyedSubtree(
                      key: ValueKey(id),
                      child: SizedBox(
                        key: id == 4 ? imageKey : null,
                        height: id == 4 ? height : 100,
                        child: Text('Reading row $id'),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        scroll.jumpTo(500);
        await tester.pump();
        final before = tester.getTopLeft(find.text('Reading row 5')).dy;
        expect(before, closeTo(0, .5));

        preserveScrollLayoutAnchor(imageKey.currentContext!);
        height += imageGrowth;
        list.addItem(0);
        list.removeItem(30);
        messages.value = [-1, ...messages.value.take(29)];
        // Loading older history keeps the window's length while moving the
        // reading row to index 6. A tall image can also recycle it before the
        // anchor is applied. Neither case may paint a jump for even one frame.
        for (var frame = 0; frame < 3; frame++) {
          await tester.pump();
          expect(
            tester.getTopLeft(find.text('Reading row 5')).dy,
            closeTo(before, .5),
          );
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
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
