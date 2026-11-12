import 'package:Kelivo/desktop/macos_window_drag_area.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('window_manager');
  late List<String> calls;
  late bool maximized;

  setUp(() {
    calls = [];
    maximized = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          if (call.method == 'isMaximized') return maximized;
          if (call.method == 'maximize') maximized = true;
          if (call.method == 'unmaximize') maximized = false;
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> doubleClick(WidgetTester tester, Offset point) async {
    await tester.tapAt(point);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tapAt(point);
    await tester.pumpAndSettle();
  }

  testWidgets('empty app bar space zooms and restores the window', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            flexibleSpace: const MacosWindowDragArea(child: SizedBox.expand()),
            title: const Row(children: [Text('Conversation')]),
          ),
        ),
      ),
    );
    final point =
        tester.getTopLeft(find.byType(AppBar)) + const Offset(600, 20);

    await doubleClick(tester, point);
    expect(calls, ['isMaximized', 'maximize']);
    await tester.pump(const Duration(milliseconds: 500));
    await doubleClick(tester, point);
    expect(calls, ['isMaximized', 'maximize', 'isMaximized', 'unmaximize']);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('header controls retain clicks and text input', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MacosWindowDragArea(
            child: SizedBox(
              height: 56,
              child: Row(
                children: [
                  IosIconButton(
                    key: const Key('button'),
                    builder: (_) => const Text('Button'),
                    onTap: () => taps++,
                  ),
                  const SizedBox(width: 200, child: TextField()),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await doubleClick(
      tester,
      tester.getCenter(find.byKey(const Key('button'))),
    );
    expect(taps, 2);
    await tester.enterText(find.byType(TextField), 'search text');
    await doubleClick(tester, tester.getCenter(find.byType(TextField)));
    expect(find.text('search text'), findsOneWidget);
    expect(calls, isEmpty);

    await tester.dragFrom(const Offset(600, 20), const Offset(80, 20));
    await tester.pumpAndSettle();
    expect(calls, ['startDragging']);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets(
    'other platforms keep their existing header behavior',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MacosWindowDragArea(child: SizedBox(width: 800, height: 56)),
          ),
        ),
      );
      await doubleClick(tester, const Offset(600, 20));
      expect(calls, isEmpty);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.windows,
      TargetPlatform.linux,
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
  );
}
