import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/shared/widgets/custom_bottom_sheet.dart';

void main() {
  void setTallTestWindow(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
    'custom bottom sheet renders handle, header count, and initial panel',
    (tester) async {
      setTallTestWindow(tester);

      var dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomBottomSheet(
              title: '搜索结果',
              count: 3,
              closeSemanticLabel: '关闭',
              onDismiss: () => dismissed = true,
              child: const Text('第一条来源'),
            ),
          ),
        ),
      );
      final panel = find.byKey(CustomBottomSheet.panelKey);
      expect(tester.getTopLeft(panel).dy, greaterThanOrEqualTo(800));

      await tester.pumpAndSettle();

      expect(find.byKey(CustomBottomSheet.dragHandleKey), findsOneWidget);
      expect(find.text('搜索结果'), findsOneWidget);
      expect(tester.widget<Text>(find.text('搜索结果')).style?.fontSize, 15);
      expect(
        tester.getTopLeft(find.text('搜索结果')).dy -
            tester
                .getBottomLeft(find.byKey(CustomBottomSheet.dragHandleKey))
                .dy,
        closeTo(24, 0.1),
      );
      expect(find.text('3'), findsOneWidget);
      expect(find.text('第一条来源'), findsOneWidget);

      final panelSize = tester.getSize(panel);
      expect(panelSize.height, 720);

      await tester.tap(find.byKey(CustomBottomSheet.closeButtonKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getSize(panel).height, 720);
      expect(tester.getTopLeft(panel).dy, greaterThan(320));
      expect(dismissed, isFalse);

      await tester.pumpAndSettle();
      expect(dismissed, isTrue);
    },
  );

  testWidgets(
    'short list drag keeps expanding instead of snapping to partial',
    (tester) async {
      setTallTestWindow(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomBottomSheet(
              title: '搜索结果',
              count: 12,
              closeSemanticLabel: '关闭',
              onDismiss: () {},
              builder: (context, controller) {
                return ListView.builder(
                  controller: controller,
                  itemCount: 40,
                  itemBuilder: (context, index) =>
                      SizedBox(height: 44, child: Text('Source $index')),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final panel = find.byKey(CustomBottomSheet.panelKey);
      final partialTop = tester.getTopLeft(panel).dy;

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Source 0')),
      );
      await gesture.moveBy(const Offset(0, -96));
      await tester.pump();
      expect(tester.getTopLeft(panel).dy, lessThan(partialTop));

      await gesture.up();
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(panel).dy, lessThan(partialTop));
    },
  );

  testWidgets(
    'list drag expands, scrolls, collapses, and dismisses after a long pull',
    (tester) async {
      setTallTestWindow(tester);
      var dismissed = false;
      late ScrollController listController;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomBottomSheet(
              title: '搜索结果',
              count: 12,
              closeSemanticLabel: '关闭',
              onDismiss: () => dismissed = true,
              builder: (context, controller) {
                listController = controller;
                return ListView.builder(
                  controller: controller,
                  itemCount: 40,
                  itemBuilder: (context, index) =>
                      SizedBox(height: 44, child: Text('Source $index')),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final panel = find.byKey(CustomBottomSheet.panelKey);
      final partialTop = tester.getTopLeft(panel).dy;
      expect(partialTop, 320);

      await tester.drag(find.text('Source 0'), const Offset(0, -260));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(panel).dy, closeTo(80, 0.1));
      expect(tester.getSize(panel).height, 720);
      expect(listController.offset, 0);

      await tester.drag(find.text('Source 0'), const Offset(0, -260));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(panel).dy, lessThan(partialTop));
      expect(listController.offset, greaterThan(0));

      listController.jumpTo(0);
      await tester.pump();

      await tester.drag(find.text('Source 0'), const Offset(0, 120));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(panel).dy, partialTop);
      expect(dismissed, isFalse);

      await tester.drag(find.text('Source 0'), const Offset(0, -260));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(panel).dy, closeTo(80, 0.1));

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Source 0')),
      );
      await gesture.moveBy(const Offset(0, 560));
      await tester.pump();
      expect(tester.getTopLeft(panel).dy, greaterThan(partialTop));
      expect(tester.getSize(panel).height, 720);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(dismissed, isTrue);
    },
  );

  testWidgets('short list fling settles to partial instead of dismissing', (
    tester,
  ) async {
    setTallTestWindow(tester);
    var dismissed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomBottomSheet(
            title: '搜索结果',
            count: 12,
            closeSemanticLabel: '关闭',
            onDismiss: () => dismissed = true,
            builder: (context, controller) {
              return ListView.builder(
                controller: controller,
                itemCount: 40,
                itemBuilder: (context, index) =>
                    SizedBox(height: 44, child: Text('Source $index')),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final panel = find.byKey(CustomBottomSheet.panelKey);
    final partialTop = tester.getTopLeft(panel).dy;

    await tester.drag(find.text('Source 0'), const Offset(0, -260));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(panel).dy, closeTo(80, 0.1));

    await tester.fling(find.text('Source 0'), const Offset(0, 80), 1600);
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(panel).dy, partialTop);
    expect(dismissed, isFalse);
  });

  testWidgets(
    'handle drag follows below partial and dismisses only after a long pull',
    (tester) async {
      setTallTestWindow(tester);
      var dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomBottomSheet(
              title: '搜索结果',
              count: 3,
              closeSemanticLabel: '关闭',
              onDismiss: () => dismissed = true,
              child: const Text('第一条来源'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final panel = find.byKey(CustomBottomSheet.panelKey);
      final partialTop = tester.getTopLeft(panel).dy;
      expect(partialTop, 320);

      final shortDrag = await tester.startGesture(
        tester.getCenter(find.byKey(CustomBottomSheet.dragHandleKey)),
      );
      await shortDrag.moveBy(const Offset(0, 120));
      await tester.pump();
      expect(tester.getTopLeft(panel).dy, greaterThan(partialTop));
      await shortDrag.up();
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(panel).dy, partialTop);
      expect(dismissed, isFalse);

      final longDrag = await tester.startGesture(
        tester.getCenter(find.byKey(CustomBottomSheet.dragHandleKey)),
      );
      await longDrag.moveBy(const Offset(0, 260));
      await tester.pump();
      expect(tester.getTopLeft(panel).dy, greaterThan(partialTop));
      await longDrag.up();
      await tester.pumpAndSettle();
      expect(dismissed, isTrue);
    },
  );
}
