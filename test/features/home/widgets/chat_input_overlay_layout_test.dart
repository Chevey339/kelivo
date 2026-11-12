import 'dart:ui' as ui;

import 'package:Kelivo/features/home/widgets/chat_input_overlay_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

void main() {
  const mobilePlatforms = TargetPlatformVariant({
    TargetPlatform.iOS,
    TargetPlatform.android,
  });
  const inputKey = Key('safe-area-input');

  void configureView(WidgetTester tester, {double width = 400}) {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = Size(width * 3, 800 * 3);
    tester.view.viewPadding = const FakeViewPadding(bottom: 102);
    tester.view.padding = const FakeViewPadding(bottom: 102);
    addTearDown(tester.view.reset);
  }

  Widget scrollableLayout(
    ScrollController controller, {
    bool backgroundImageActive = false,
    VoidCallback? onInputTap,
  }) {
    return MaterialApp(
      home: Scaffold(
        resizeToAvoidBottomInset: true,
        body: ChatInputOverlayLayout(
          topInset: 100,
          backgroundImageActive: backgroundImageActive,
          topBackground: const ColoredBox(color: Colors.green),
          content: SuperListView.builder(
            controller: controller,
            padding: const EdgeInsets.only(top: 108, bottom: 144),
            itemCount: 40,
            itemBuilder: (_, index) =>
                SizedBox(height: 80, child: Text('Message $index')),
          ),
          bottomOverlay: SafeArea(
            top: false,
            left: false,
            right: false,
            child: GestureDetector(
              key: inputKey,
              behavior: HitTestBehavior.opaque,
              onTap: onInputTap,
              child: const SizedBox(width: 200, height: 50),
            ),
          ),
        ),
      ),
    );
  }

  for (final width in [400.0, 1024.0]) {
    for (final backgroundImageActive in [false, true]) {
      testWidgets('底部安全区阻止列表拖动，输入栏和正常滚动不受影响 '
          '(width=$width, background=$backgroundImageActive)', (tester) async {
        configureView(tester, width: width);
        final controller = ScrollController(initialScrollOffset: 200);
        addTearDown(controller.dispose);
        var inputTaps = 0;
        await tester.pumpWidget(
          scrollableLayout(
            controller,
            backgroundImageActive: backgroundImageActive,
            onInputTap: () => inputTaps++,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.getBottomLeft(find.byType(SuperListView)).dy, 800);
        expect(tester.getBottomLeft(find.byKey(inputKey)).dy, 766);
        // Cover the entire safe area, including beside a narrow composer.
        for (final x in [2.0, width / 2, width - 2]) {
          await tester.dragFrom(Offset(x, 795), const Offset(0, -120));
          await tester.pumpAndSettle();
          expect(controller.offset, 200);
        }

        await tester.tap(find.byKey(inputKey));
        await tester.pump();
        expect(inputTaps, 1);
        await tester.dragFrom(Offset(width / 2, 300), const Offset(0, -120));
        await tester.pumpAndSettle();
        expect(controller.offset, greaterThan(200));
      }, variant: mobilePlatforms);
    }
  }

  testWidgets('键盘弹出后底部可交互，收起后恢复安全区拦截', (tester) async {
    configureView(tester);
    final controller = ScrollController(initialScrollOffset: 200);
    addTearDown(controller.dispose);
    var inputTaps = 0;
    await tester.pumpWidget(
      scrollableLayout(controller, onInputTap: () => inputTaps++),
    );
    await tester.pumpAndSettle();

    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    tester.view.padding = FakeViewPadding.zero;
    await tester.pumpAndSettle();
    expect(tester.getBottomLeft(find.byType(SuperListView)).dy, 500);
    expect(tester.getBottomLeft(find.byKey(inputKey)).dy, 500);
    await tester.dragFrom(const Offset(2, 495), const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(200));
    // A stale 34px guard would also block the bottom of the composer.
    await tester.tapAt(const Offset(200, 495));
    await tester.pump();
    expect(inputTaps, 1);

    tester.view.viewInsets = FakeViewPadding.zero;
    tester.view.padding = const FakeViewPadding(bottom: 102);
    await tester.pumpAndSettle();
    expect(tester.getBottomLeft(find.byType(SuperListView)).dy, 800);
    expect(tester.getBottomLeft(find.byKey(inputKey)).dy, 766);
    final before = controller.offset;
    await tester.dragFrom(const Offset(200, 795), const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(controller.offset, before);
  }, variant: mobilePlatforms);

  testWidgets('无底部安全区时不拦截底部触摸', (tester) async {
    configureView(tester);
    tester.view.viewPadding = FakeViewPadding.zero;
    tester.view.padding = FakeViewPadding.zero;
    final controller = ScrollController(initialScrollOffset: 200);
    addTearDown(controller.dispose);
    await tester.pumpWidget(scrollableLayout(controller));
    await tester.pumpAndSettle();

    await tester.dragFrom(const Offset(2, 795), const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(200));
  }, variant: mobilePlatforms);

  testWidgets('消息画布铺到系统状态栏后方，底部覆盖层贴住底部', (tester) async {
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

    expect(tester.getTopLeft(find.byKey(contentKey)).dy, 0);
    expect(tester.getBottomLeft(find.byKey(contentKey)).dy, 600);
    expect(tester.getTopLeft(find.byKey(overlayKey)).dy, 550);
  });

  testWidgets('底部覆盖层最高只到顶栏下方，不会压住标题', (tester) async {
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
              bottomOverlay: SizedBox(key: overlayKey, width: 200, height: 900),
            ),
          ),
        ),
      ),
    );

    expect(tester.getTopLeft(find.byKey(overlayKey)).dy, 112);
    expect(tester.getBottomLeft(find.byKey(overlayKey)).dy, 600);
  });

  testWidgets('输入框层位于前景遮罩上方', (tester) async {
    var inputTaps = 0;
    var foregroundTaps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 600,
            child: ChatInputOverlayLayout(
              topInset: 100,
              content: const ColoredBox(color: Colors.blue),
              foreground: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => foregroundTaps++,
              ),
              bottomOverlay: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => inputTaps++,
                child: const SizedBox(width: 400, height: 88),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(200, 560));
    await tester.pump();

    expect(inputTaps, 1);
    expect(foregroundTaps, 0);
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
    expect(tester.getTopLeft(fadeFinder).dy, 420);
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

  testWidgets('顶部导航栏后方有渐变遮罩隔开消息内容', (tester) async {
    const fadeKey = Key('chat-input-overlay-top-fade');

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
    expect(tester.getTopLeft(fadeFinder).dy, 0);
    expect(tester.getBottomLeft(fadeFinder).dy, 116);

    final decoration = tester.widget<DecoratedBox>(
      find.descendant(of: fadeFinder, matching: find.byType(DecoratedBox)),
    );
    final boxDecoration = decoration.decoration as BoxDecoration;
    final gradient = boxDecoration.gradient as LinearGradient;
    expect(gradient.begin, Alignment.topCenter);
    expect(gradient.end, Alignment.bottomCenter);
    expect(gradient.stops, const [0.0, 0.48, 0.78, 1.0]);
    expect(gradient.colors.first.a, 1);
    expect(gradient.colors[1].a, inInclusiveRange(0.98, 0.995));
    expect(gradient.colors[2].a, inInclusiveRange(0.85, 0.90));
    expect(gradient.colors.last.a, 0);
  });

  testWidgets('滚动中的消息持续绘制到系统状态栏区域', (tester) async {
    const firstMessageKey = Key('overflow-message');
    final scrollController = ScrollController(initialScrollOffset: 132);
    final listController = ListController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 600,
            child: ChatInputOverlayLayout(
              topInset: 100,
              content: SuperListView.builder(
                controller: scrollController,
                listController: listController,
                padding: const EdgeInsets.only(top: 108),
                itemCount: 12,
                itemBuilder: (context, index) => ColoredBox(
                  key: index == 0 ? firstMessageKey : null,
                  color: index.isEven
                      ? const Color(0xFF0055FF)
                      : const Color(0xFF00CC66),
                  child: const SizedBox(height: 80),
                ),
              ),
              bottomOverlay: const SizedBox(width: 200, height: 50),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final listFinder = find.byType(SuperListView);
    expect(tester.getTopLeft(listFinder).dy, 0);
    expect(tester.getTopLeft(find.byKey(firstMessageKey)).dy, -24);

    scrollController.dispose();
    listController.dispose();
  });

  testWidgets('背景图模式下用背景覆盖顶部且不渲染纯色遮罩', (tester) async {
    const bottomFadeKey = Key('chat-input-overlay-bottom-fade');
    const bottomBackgroundKey = Key('chat-input-overlay-bottom-background');
    const topFadeKey = Key('chat-input-overlay-top-fade');
    const topBackgroundKey = Key('chat-input-overlay-top-background');
    const backgroundKey = Key('background');

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 600,
            child: ChatInputOverlayLayout(
              topInset: 100,
              backgroundImageActive: true,
              topBackground: ColoredBox(
                key: backgroundKey,
                color: Colors.green,
              ),
              content: ColoredBox(color: Colors.blue),
              bottomOverlay: SizedBox(width: 200, height: 50),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(bottomFadeKey), findsNothing);
    expect(find.byKey(bottomBackgroundKey), findsOneWidget);
    expect(find.byKey(topFadeKey), findsNothing);
    expect(find.byKey(topBackgroundKey), findsOneWidget);
    expect(find.byKey(backgroundKey), findsNWidgets(2));

    final topMask = find.descendant(
      of: find.byKey(topBackgroundKey),
      matching: find.byType(ShaderMask),
    );
    final bottomMask = find.descendant(
      of: find.byKey(bottomBackgroundKey),
      matching: find.byType(ShaderMask),
    );
    // The composited masks themselves must fit the strips, not just their
    // outer clips. Their full-window artwork must still share one origin.
    expect(tester.getRect(topMask), const Rect.fromLTWH(0, 0, 400, 116));
    expect(tester.getRect(bottomMask), const Rect.fromLTWH(0, 420, 400, 180));
    for (final mask in [topMask, bottomMask]) {
      expect(
        tester.getRect(
          find.descendant(of: mask, matching: find.byType(ClipRect)),
        ),
        tester.getRect(mask),
      );
    }
    for (final background in find.byKey(backgroundKey).evaluate()) {
      final renderBox = background.renderObject! as RenderBox;
      expect(renderBox.size, const Size(400, 600));
      expect(renderBox.localToGlobal(Offset.zero), Offset.zero);
    }
  });

  for (final brightness in Brightness.values) {
    testWidgets('背景图加载和透明区域不会让正文穿过覆盖层 ($brightness)', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 800);
      addTearDown(tester.view.reset);
      final boundaryKey = GlobalKey();
      final wallpaper = ValueNotifier<Color?>(null);
      addTearDown(wallpaper.dispose);
      final surface = brightness == Brightness.dark
          ? Colors.black
          : Colors.white;

      void expectColor(Color actual, Color expected, String reason) {
        for (final channel in [
          (actual.r, expected.r),
          (actual.g, expected.g),
          (actual.b, expected.b),
          (actual.a, expected.a),
        ]) {
          expect(channel.$1, closeTo(channel.$2, 2 / 255), reason: reason);
        }
      }

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.purple,
              brightness: brightness,
            ).copyWith(surface: surface),
          ),
          home: RepaintBoundary(
            key: boundaryKey,
            child: Scaffold(
              body: ValueListenableBuilder<Color?>(
                valueListenable: wallpaper,
                builder: (context, color, _) => ChatInputOverlayLayout(
                  topInset: 100,
                  backgroundImageActive: true,
                  topBackground: color == null
                      ? const SizedBox.expand()
                      : ColoredBox(color: color),
                  content: const ColoredBox(color: Colors.red),
                  bottomOverlay: const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
      );

      for (final color in [
        null,
        Colors.green.withValues(alpha: 0.5),
        Colors.green,
        null,
      ]) {
        wallpaper.value = color;
        await tester.pumpAndSettle();
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = boundary.toImageSync();
        final bytes = await tester.runAsync(
          () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
        );
        Color sample(int y) {
          final offset = (y * image.width + 200) * 4;
          return Color.fromARGB(
            bytes!.getUint8(offset + 3),
            bytes.getUint8(offset),
            bytes.getUint8(offset + 1),
            bytes.getUint8(offset + 2),
          );
        }

        final top = sample(24);
        final middle = sample(400);
        final bottom = sample(799);
        image.dispose();
        final background = Color.alphaBlend(
          color ?? Colors.transparent,
          surface,
        );
        expectColor(top, background, 'Top bar: $color');
        expectColor(middle, Colors.red, 'Visible messages: $color');
        final expectedBottom = Color.alphaBlend(
          background.withValues(
            alpha: brightness == Brightness.dark ? 0.92 : 0.98,
          ),
          Colors.red,
        );
        expectColor(bottom, expectedBottom, 'Bottom bar: $color');
      }
    });
  }

  for (final brightness in Brightness.values) {
    testWidgets('横屏键盘缩短视口时保持底部渐变范围 ($brightness)', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 390);
      addTearDown(tester.view.reset);
      final boundaryKey = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: RepaintBoundary(
            key: boundaryKey,
            child: const Scaffold(
              resizeToAvoidBottomInset: true,
              body: ChatInputOverlayLayout(
                topInset: 56,
                backgroundImageActive: true,
                topBackground: ColoredBox(color: Colors.white),
                content: ColoredBox(color: Colors.black),
                bottomOverlay: SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      Future<List<int>> sampleColumn() async {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = boundary.toImageSync();
        try {
          final bytes = await tester.runAsync(
            () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
          );
          return [
            for (var y = 0; y < image.height; y++)
              bytes!.getUint8((y * image.width + image.width ~/ 2) * 4),
          ];
        } finally {
          image.dispose();
        }
      }

      final baseline = await sampleColumn();
      for (final height in [180, 160, 140, 120]) {
        tester.view.viewInsets = FakeViewPadding(bottom: 390.0 - height);
        await tester.pumpAndSettle();
        final actual = await sampleColumn();
        // Below the 56px toolbar + 16px top fade, opacity depends only on
        // distance from the bottom, even when part of the fade is offscreen.
        for (var y = 72; y < height; y++) {
          expect(
            actual[y],
            closeTo(baseline[y + 390 - height], 1),
            reason: 'body height=$height, y=$y',
          );
        }
      }
    });
  }

  testWidgets('键盘弹出时背景仍按键盘收起时的高度布局', (tester) async {
    const backgroundKey = Key('background');
    const contentKey = Key('content');

    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Widget build() {
      return const MaterialApp(
        home: Scaffold(
          resizeToAvoidBottomInset: true,
          body: ChatInputOverlayLayout(
            topInset: 100,
            backgroundImageActive: true,
            topBackground: ColoredBox(key: backgroundKey, color: Colors.green),
            content: ColoredBox(key: contentKey, color: Colors.blue),
            bottomOverlay: SizedBox(width: 200, height: 50),
          ),
        ),
      );
    }

    await tester.pumpWidget(build());
    final closedContentHeight = tester.getSize(find.byKey(contentKey)).height;
    final closedBackgroundHeight = tester
        .getSize(find.byKey(backgroundKey).first)
        .height;
    expect(closedBackgroundHeight, closedContentHeight);

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpWidget(build());

    // The body really did shrink around the keyboard...
    expect(
      tester.getSize(find.byKey(contentKey)).height,
      closedContentHeight - 300,
    );
    // ...but the artwork keeps its original box, so BoxFit.cover does not
    // re-crop and the background stays put.
    expect(
      tester.getSize(find.byKey(backgroundKey).first).height,
      closedBackgroundHeight,
    );
    expect(tester.getTopLeft(find.byKey(backgroundKey).first).dy, 0);
  });
}
