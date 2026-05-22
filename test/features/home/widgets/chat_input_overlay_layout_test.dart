import 'package:Kelivo/features/home/widgets/chat_input_overlay_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('底部覆盖层贴住可用区域底部', (tester) async {
    const rootKey = Key('root');
    const contentKey = Key('content');
    const overlayKey = Key('overlay');

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            key: rootKey,
            width: 400,
            height: 600,
            child: ChatInputOverlayLayout(
              topInset: 100,
              content: ColoredBox(key: contentKey, color: Colors.blue),
              bottomOverlay: SizedBox(key: overlayKey, width: 200, height: 50),
            ),
          ),
        ),
      ),
    );

    expect(tester.getTopLeft(find.byKey(contentKey)).dy, 100);
    expect(tester.getBottomLeft(find.byKey(contentKey)).dy, 600);
    expect(tester.getTopLeft(find.byKey(overlayKey)).dy, 550);
  });

  testWidgets('底部覆盖层内的居中包装不会把输入框推到中间', (tester) async {
    const overlayKey = Key('overlay');

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 600,
            child: ChatInputOverlayLayout(
              topInset: 100,
              content: ColoredBox(color: Colors.blue),
              bottomOverlay: Center(
                child: SizedBox(key: overlayKey, width: 200, height: 50),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.getTopLeft(find.byKey(overlayKey)).dy, 550);
  });

  testWidgets('底部覆盖层后方有渐变遮罩隔开消息内容', (tester) async {
    const fadeKey = Key('chat-input-overlay-bottom-fade');

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 600,
            child: ChatInputOverlayLayout(
              topInset: 100,
              content: ColoredBox(color: Colors.blue),
              bottomOverlay: SizedBox(width: 200, height: 50),
            ),
          ),
        ),
      ),
    );

    final fadeFinder = find.byKey(fadeKey);
    expect(fadeFinder, findsOneWidget);
    expect(tester.getBottomLeft(fadeFinder).dy, 600);

    final decoration = tester.widget<DecoratedBox>(
      find.descendant(of: fadeFinder, matching: find.byType(DecoratedBox)),
    );
    final boxDecoration = decoration.decoration as BoxDecoration;
    final gradient = boxDecoration.gradient as LinearGradient;
    expect(gradient.begin, Alignment.topCenter);
    expect(gradient.end, Alignment.bottomCenter);
    expect(gradient.colors.first.a, 0);
    expect(gradient.colors[1].a, greaterThan(0.80));
    expect(gradient.colors.last.a, greaterThan(0.95));
  });

  testWidgets('背景图模式下不渲染底部遮罩', (tester) async {
    const fadeKey = Key('chat-input-overlay-bottom-fade');

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 600,
            child: ChatInputOverlayLayout(
              topInset: 100,
              backgroundImageActive: true,
              content: ColoredBox(color: Colors.blue),
              bottomOverlay: SizedBox(width: 200, height: 50),
            ),
          ),
        ),
      ),
    );

    final fadeFinder = find.byKey(fadeKey);
    expect(fadeFinder, findsNothing);
  });
}
