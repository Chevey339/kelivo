import 'dart:ui' as ui;

import 'package:Kelivo/features/chat/widgets/frosted/chat_frosted_backdrop.dart';
import 'package:Kelivo/features/chat/widgets/frosted/frosted_surface.dart';
import 'package:Kelivo/features/home/controllers/scroll_controller.dart';
import 'package:Kelivo/shared/widgets/interactive_drawer.dart';
import 'package:Kelivo/theme/chat_bubble_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:markstream/markstream.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('moving retained transcript matches a freshly painted drawer', (
    tester,
  ) async {
    final previousPolicy = binding.framePolicy;
    final previousDispatcher = binding.deviceEventDispatcher;
    final previousGlass = debugFrostedForceLiveBackdropFilter;
    binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.onlyPumps;
    binding.deviceEventDispatcher = null;
    final scene = ValueNotifier((frame: 0, progress: 0.0, source: ''));
    final captures = [GlobalKey(), GlobalKey()];
    var checkedBytes = 0, checkedFrames = 0;
    try {
      for (final glass in [false, true]) {
        debugFrostedForceLiveBackdropFilter = glass;
        var source = List.generate(
          80,
          (i) => 'Paragraph $i **bold** 中文 text.',
        ).join('\n\n');
        scene.value = (frame: 0, progress: 0, source: source);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 360,
                height: 620,
                child: ValueListenableBuilder(
                  valueListenable: scene,
                  builder: (_, value, __) => Stack(
                    children: [
                      for (var i = 0; i < 2; i++)
                        RepaintBoundary(
                          key: captures[i],
                          child: _DrawerScene(
                            key: i == 0
                                ? const ValueKey('retained')
                                : ValueKey(value.frame),
                            progress: value.progress,
                            source: value.source,
                            glass: glass,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        for (var frame = 0; frame <= 20; frame++) {
          if (frame >= 10) source += ' **appended $frame**';
          scene.value = (
            frame: frame + 1,
            progress: frame <= 10 ? frame / 10 : (20 - frame) / 10,
            source: source,
          );
          await tester.pump();
          final images = [
            for (final key in captures)
              (key.currentContext!.findRenderObject()! as RenderRepaintBoundary)
                  .toImageSync(),
          ];
          try {
            final left = (await images[0].toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            final right = (await images[1].toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            final actual = left.buffer.asUint8List(
              left.offsetInBytes,
              left.lengthInBytes,
            );
            final expected = right.buffer.asUint8List(
              right.offsetInBytes,
              right.lengthInBytes,
            );
            expect(actual.length, expected.length);
            var different = 0;
            for (var i = 0; i < actual.length; i++) {
              if (actual[i] != expected[i]) different++;
            }
            expect(
              different,
              0,
              reason: 'drawer frame $frame (glass=$glass) changed pixels',
            );
            checkedBytes += actual.length;
            checkedFrames++;
          } finally {
            for (final image in images) {
              image.dispose();
            }
          }
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      }
      binding.reportData = {
        ...?binding.reportData,
        'drawerPixels': {
          'frames': checkedFrames,
          'checkedRgbaBytes': checkedBytes,
          'differentBytes': 0,
        },
      };
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      scene.dispose();
      debugFrostedForceLiveBackdropFilter = previousGlass;
      binding.framePolicy = previousPolicy;
      binding.deviceEventDispatcher = previousDispatcher;
    }
  });
}

class _DrawerScene extends StatefulWidget {
  const _DrawerScene({
    super.key,
    required this.progress,
    required this.source,
    required this.glass,
  });
  final double progress;
  final String source;
  final bool glass;
  @override
  State<_DrawerScene> createState() => _DrawerSceneState();
}

class _DrawerSceneState extends State<_DrawerScene> {
  late final _drawer = InteractiveDrawerController(
    initialValue: widget.progress,
  );
  final _scroll = ChatAutoFollowScrollController()
    ..shouldAutoFollow = () => true;
  @override
  void didUpdateWidget(_DrawerScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    _drawer.jumpTo(widget.progress);
  }

  @override
  void dispose() {
    _drawer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget text = Padding(
      padding: const EdgeInsets.all(12),
      child: MarkstreamView(source: widget.source),
    );
    if (widget.glass) {
      text = FrostedSurface(
        style: const ResolvedBubbleStyle(
          background: Color(0xAADDDEEF),
          border: Color(0x24777777),
          text: Colors.black,
          borderWidth: .8,
          radius: 16,
          blurSigma: 14,
        ),
        borderRadius: BorderRadius.circular(16),
        child: text,
      );
    }
    return InteractiveDrawer(
      controller: _drawer,
      drawerWidth: 270,
      maxScrimOpacity: .12,
      scrimColor: Colors.black,
      drawer: const ColoredBox(
        color: Color(0xffe8e4ef),
        child: Center(child: Text('Sidebar')),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xffe0d1ff),
                  Color(0xffb1e7df),
                  Color(0xffffd9c3),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          SelectionArea(
            child: SingleChildScrollView(controller: _scroll, child: text),
          ),
        ],
      ),
    );
  }
}
