import 'package:Kelivo/features/chat/widgets/viewport_block_list.dart';
import 'package:Kelivo/features/home/controllers/scroll_controller.dart';
import 'package:Kelivo/shared/widgets/export_capture_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'export capture materializes the full source inside a scrollable',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ExportCaptureScope(
                enabled: true,
                child: ViewportBlockList(
                  itemCount: 100,
                  structureToken: 100,
                  itemKey: (i) => i,
                  estimateExtent: (i, width) => 40,
                  itemBuilder: (context, i) =>
                      SizedBox(height: 40, child: Text('export-$i')),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('export-0'), findsOneWidget);
      expect(find.text('export-99'), findsOneWidget);
      expect(find.byType(Text), findsNWidgets(100));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '5000 blocks share one scrollable and mount only the viewport range',
    (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      var mounted = 0;
      var peak = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              controller: controller,
              child: ViewportBlockList(
                itemCount: 5000,
                structureToken: 5000,
                itemKey: (i) => i,
                estimateExtent: (i, width) => 40,
                keepAlive: (i) => i == 0,
                itemBuilder: (context, i) => _Probe(
                  key: ValueKey('block-$i'),
                  onMount: () {
                    mounted++;
                    if (mounted > peak) peak = mounted;
                  },
                  onDispose: () => mounted--,
                  label: '$i',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Scrollable), findsOneWidget);
      expect(mounted, lessThan(100));
      expect(find.text('0'), findsOneWidget);
      controller.jumpTo(120000);
      await tester.pumpAndSettle();
      expect(find.text('3000'), findsOneWidget);
      expect(find.text('0'), findsOneWidget); // active input is retained
      expect(find.text('1'), findsNothing);
      expect(mounted, lessThan(100));
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(find.text('4999'), findsOneWidget);
      controller.jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.text('1'), findsOneWidget);
      expect(peak, lessThan(150));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'width and text scale changes retain the measured reading item and offset',
    (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final items = List.generate(100, (i) => i);

      await tester.pumpWidget(
        _anchorHost(controller: controller, items: items),
      );
      await tester.pumpAndSettle();
      await _visitOffset(tester, controller, 5025);
      final readingItem = find.byKey(const ValueKey('item-50'));
      expect(tester.getTopLeft(readingItem).dy, closeTo(-25, .5));

      await tester.pumpWidget(
        _anchorHost(controller: controller, items: items, width: 400),
      );
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(readingItem).dy, closeTo(-25, .5));

      await tester.pumpWidget(
        _anchorHost(
          controller: controller,
          items: items,
          width: 400,
          textScale: 2,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(readingItem).dy, closeTo(-25, .5));
      expect(find.byType(Text).evaluate().length, lessThan(60));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('structural changes retain the stable reading key', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final items = List.generate(100, (i) => i);
    await tester.pumpWidget(_anchorHost(controller: controller, items: items));
    await tester.pumpAndSettle();
    await _visitOffset(tester, controller, 5025);
    final readingItem = find.byKey(const ValueKey('item-50'));

    final inserted = [100, 101, 102, 103, 104, ...items];
    await tester.pumpWidget(
      _anchorHost(controller: controller, items: inserted),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(readingItem).dy, closeTo(-25, .5));

    final reordered = [...items.skip(10), ...items.take(10)];
    await tester.pumpWidget(
      _anchorHost(controller: controller, items: reordered),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(readingItem).dy, closeTo(-25, .5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('measured heights and reading anchor survive a state rebuild', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final bucket = PageStorageBucket();
    final items = List.generate(100, (i) => i);
    var generation = 0;

    Widget host() => MaterialApp(
      home: Scaffold(
        body: PageStorage(
          bucket: bucket,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 600,
              child: SingleChildScrollView(
                controller: controller,
                child: ViewportBlockList(
                  // A new key destroys the state while the bucket and the
                  // scroll position stay alive.
                  key: ValueKey(generation),
                  storageId: 'message-1',
                  itemCount: items.length,
                  structureToken: items,
                  itemKey: (i) => items[i],
                  estimateExtent: (i, width) => 40,
                  itemBuilder: (context, i) => SizedBox(
                    key: ValueKey('item-${items[i]}'),
                    height: 100,
                    child: Text('item-${items[i]}'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await _visitOffset(tester, controller, 5025);
    final readingItem = find.byKey(const ValueKey('item-50'));
    expect(tester.getTopLeft(readingItem).dy, closeTo(-25, .5));
    final measuredExtent = controller.position.maxScrollExtent;
    // Well past the 100 * 40 the list would guess without measurements.
    expect(measuredExtent, greaterThan(5000));

    generation++;
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(controller.offset, closeTo(5025, .5));
    expect(controller.position.maxScrollExtent, closeTo(measuredExtent, .5));
    expect(tester.getTopLeft(readingItem).dy, closeTo(-25, .5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('stored extents are keyed by item, width and text scale', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final bucket = PageStorageBucket();
    final items = List.generate(100, (i) => i);

    Widget host({double width = 600, double textScale = 1}) => MaterialApp(
      home: Scaffold(
        body: PageStorage(
          bucket: bucket,
          child: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: SingleChildScrollView(
                  controller: controller,
                  child: ViewportBlockList(
                    storageId: 'message-1',
                    itemCount: items.length,
                    structureToken: items,
                    itemKey: (i) => items[i],
                    estimateExtent: (i, width) => 40,
                    itemBuilder: (context, i) => SizedBox(
                      key: ValueKey('item-${items[i]}'),
                      height: 100 * MediaQuery.textScalerOf(context).scale(1),
                      child: Text('item-${items[i]}'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Map<Object, double> storedExtents() {
      final stored = bucket.readState(
        tester.element(find.byType(ViewportBlockList)),
        identifier: 'message-1',
      );
      expect(stored, isA<Map<Object, double>>());
      return stored as Map<Object, double>;
    }

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await _visitOffset(tester, controller, 5025);
    final atDefault = storedExtents();
    expect(atDefault, isNotEmpty);
    expect(
      atDefault.keys.cast<(Object, double, double)>().every(
        (key) => key.$2 == 600 && key.$3 == 1,
      ),
      isTrue,
    );

    await tester.pumpWidget(host(textScale: 2));
    await tester.pumpAndSettle();
    final atScale = storedExtents();
    expect(identical(atScale, atDefault), isTrue);
    expect(
      atScale.keys.cast<(Object, double, double)>().every(
        (key) => key.$2 == 600 && key.$3 == 2,
      ),
      isTrue,
    );

    await tester.pumpWidget(host(width: 400, textScale: 2));
    await tester.pumpAndSettle();
    expect(
      storedExtents().keys.cast<(Object, double, double)>().every(
        (key) => key.$2 == 400 && key.$3 == 2,
      ),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('changing storage identity switches the extent cache', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final bucket = PageStorageBucket();
    final items = List.generate(100, (i) => i);

    Widget host(String storageId) => MaterialApp(
      home: Scaffold(
        body: PageStorage(
          bucket: bucket,
          child: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              controller: controller,
              child: ViewportBlockList(
                storageId: storageId,
                itemCount: items.length,
                structureToken: items,
                itemKey: (i) => items[i],
                estimateExtent: (i, width) => 40,
                itemBuilder: (context, i) => SizedBox(
                  key: ValueKey('item-${items[i]}'),
                  height: 100,
                  child: Text('item-${items[i]}'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Map<Object, double> storedExtents(String storageId) {
      final stored = bucket.readState(
        tester.element(find.byType(ViewportBlockList)),
        identifier: storageId,
      );
      expect(stored, isA<Map<Object, double>>());
      return stored as Map<Object, double>;
    }

    await tester.pumpWidget(host('first'));
    await tester.pumpAndSettle();
    await _visitOffset(tester, controller, 5025);
    final first = storedExtents('first');

    await tester.pumpWidget(host('second'));
    await tester.pumpAndSettle();
    await _visitOffset(tester, controller, 5025);
    final second = storedExtents('second');
    expect(identical(first, second), isFalse);
    expect(second, isNotEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final changeStorageId in [false, true]) {
    testWidgets(
      changeStorageId
          ? 'changing bucket and storage id preserves each version after recycling'
          : 'changing only the bucket preserves each version after recycling',
      (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        final buckets = [PageStorageBucket(), PageStorageBucket()];
        var version = 0;
        var generation = 0;

        Widget host() {
          final message = version;
          return MaterialApp(
            home: Scaffold(
              body: PageStorage(
                bucket: buckets[message],
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 600,
                    child: SingleChildScrollView(
                      controller: controller,
                      child: ViewportBlockList(
                        key: ValueKey(generation),
                        storageId: changeStorageId ? 'body-$message' : 'body',
                        itemCount: 100,
                        structureToken: message,
                        itemKey: (i) => (message, i),
                        estimateExtent: (i, width) => 40,
                        itemBuilder: (context, i) => SizedBox(
                          key: ValueKey('version-$message-item-$i'),
                          height: message == 0 ? 100 : 130,
                          child: Text('version-$message-item-$i'),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        await tester.pumpWidget(host());
        await tester.pumpAndSettle();
        await _visitOffset(tester, controller, 5025);
        final firstExtent = controller.position.maxScrollExtent;
        final state = tester.state(find.byType(ViewportBlockList));

        controller.jumpTo(0);
        version = 1;
        await tester.pumpWidget(host());
        await tester.pumpAndSettle();
        expect(tester.state(find.byType(ViewportBlockList)), same(state));
        await _visitOffset(tester, controller, 6525);
        final secondExtent = controller.position.maxScrollExtent;
        final readingItem = find.byKey(const ValueKey('version-1-item-50'));
        expect(tester.getTopLeft(readingItem).dy, closeTo(-25, .5));

        // Recycle the new version while keeping its bucket and scroll offset.
        generation++;
        await tester.pumpWidget(host());
        await tester.pumpAndSettle();
        expect(controller.offset, closeTo(6525, .5));
        expect(controller.position.maxScrollExtent, closeTo(secondExtent, .5));
        expect(tester.getTopLeft(readingItem).dy, closeTo(-25, .5));

        // Measurements from the second version must not replace the first's.
        controller.jumpTo(0);
        version = 0;
        await tester.pumpWidget(host());
        await tester.pumpAndSettle();
        expect(controller.position.maxScrollExtent, closeTo(firstExtent, .5));
        controller.jumpTo(5025);
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(find.byKey(const ValueKey('version-0-item-50'))).dy,
          closeTo(-25, .5),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('resize yields to the outer controller following the bottom', (
    tester,
  ) async {
    final controller = ChatAutoFollowScrollController()
      ..shouldAutoFollow = () => true;
    addTearDown(controller.dispose);
    final items = List.generate(100, (i) => i);
    await tester.pumpWidget(_anchorHost(controller: controller, items: items));
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(controller.position.maxScrollExtent, .5));

    await tester.pumpWidget(
      _anchorHost(controller: controller, items: items, width: 400),
    );
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(controller.position.maxScrollExtent, .5));
    expect(find.byKey(const ValueKey('item-99')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final readingNestedList in [true, false]) {
    testWidgets(
      readingNestedList
          ? 'nested reading anchor owns simultaneous extent invalidation'
          : 'offscreen nested list leaves the reading anchor to the outer list',
      (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        Widget host(double width) => MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: SingleChildScrollView(
                  controller: controller,
                  child: ViewportBlockList(
                    itemCount: 100,
                    structureToken: 100,
                    itemKey: (i) => i,
                    keepAlive: (i) => i == 10,
                    estimateExtent: (i, width) => i == 10 ? 4000 : 40,
                    itemBuilder: (context, i) => i == 10
                        ? ViewportBlockList(
                            itemCount: 100,
                            structureToken: 100,
                            itemKey: (i) => i,
                            estimateExtent: (i, width) => 40,
                            itemBuilder: (context, i) => SizedBox(
                              key: ValueKey('nested-$i'),
                              height: 100,
                              child: Text('nested-$i'),
                            ),
                          )
                        : SizedBox(
                            key: ValueKey('outer-$i'),
                            height: 100,
                            child: Text('outer-$i'),
                          ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpWidget(host(600));
        await tester.pumpAndSettle();
        // Visit the preceding content so its extents are measured, not guessed.
        await _visitOffset(
          tester,
          controller,
          readingNestedList ? 6025 : 14925,
        );
        final readingItem = find.byKey(
          ValueKey(readingNestedList ? 'nested-50' : 'outer-50'),
        );
        expect(tester.getTopLeft(readingItem).dy, closeTo(-25, .5));

        await tester.pumpWidget(host(400));
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(readingItem).dy, closeTo(-25, .5));
        expect(find.byType(Scrollable), findsOneWidget);
        expect(find.byType(Text).evaluate().length, lessThan(100));
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Widget _anchorHost({
  required ScrollController controller,
  required List<int> items,
  double width = 600,
  double textScale = 1,
}) => MaterialApp(
  home: Scaffold(
    body: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: SingleChildScrollView(
            controller: controller,
            child: ViewportBlockList(
              itemCount: items.length,
              structureToken: items,
              itemKey: (i) => items[i],
              estimateExtent: (i, width) => 40,
              itemBuilder: (context, i) => SizedBox(
                key: ValueKey('item-${items[i]}'),
                height: 100 * MediaQuery.textScalerOf(context).scale(1),
                child: Text('item-${items[i]}'),
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);

Future<void> _visitOffset(
  WidgetTester tester,
  ScrollController controller,
  double target,
) async {
  for (var offset = 0.0; offset < target; offset += 500) {
    controller.jumpTo(offset);
    await tester.pumpAndSettle();
  }
  controller.jumpTo(target);
  await tester.pumpAndSettle();
}

class _Probe extends StatefulWidget {
  const _Probe({
    super.key,
    required this.onMount,
    required this.onDispose,
    required this.label,
  });
  final VoidCallback onMount, onDispose;
  final String label;
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      SizedBox(height: 40, child: Text(widget.label));
}
