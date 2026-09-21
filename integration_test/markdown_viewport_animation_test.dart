import 'dart:convert';
import 'dart:ui' as ui;

import 'package:Kelivo/shared/widgets/incremental_markdown_document.dart';
import 'package:Kelivo/shared/widgets/markdown_block_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final nested in [false, true]) {
    testWidgets('device collapse has no blank frame (nested: $nested)', (
      tester,
    ) async {
      final framePolicy = binding.framePolicy;
      final deviceDispatcher = binding.deviceEventDispatcher;
      // Readback must not advance another frame and hide late invalidation.
      binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.onlyPumps;
      binding.deviceEventDispatcher = null;
      final top = ValueNotifier(1000.0);
      final scroll = ScrollController();
      final capture = GlobalKey();
      try {
        final blocks = IncrementalMarkdownDocument().update(
          List.generate(80, (i) => 'block $i').join('\n\n'),
        );
        final content = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder<double>(
              valueListenable: top,
              builder: (_, value, _) => SizedBox(height: value),
            ),
            RepaintBoundary(
              child: MarkdownBlockList(
                blocks: blocks,
                signature: 0,
                itemBuilder: (_, i) => SizedBox(
                  key: ValueKey(i),
                  width: 200,
                  height: 40,
                  child: const ColoredBox(color: Color(0xff0000ff)),
                ),
              ),
            ),
          ],
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 200,
                  height: 600,
                  child: RepaintBoundary(
                    key: capture,
                    child: ColoredBox(
                      color: const Color(0xffffffff),
                      child: SingleChildScrollView(
                        controller: scroll,
                        child: nested
                            ? MarkdownBlockList(
                                blocks: const [
                                  IncrementalMarkdownBlock(
                                    start: 0,
                                    text: '',
                                    stable: true,
                                  ),
                                ],
                                signature: 0,
                                itemBuilder: (_, _) => SizedBox(
                                  height: 6000,
                                  child: RepaintBoundary(child: content),
                                ),
                              )
                            : content,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        var checkedPixels = 0;
        final samples = <String, String>{};
        for (var frame = 0; frame < 21; frame++) {
          // The same 300 ms collapse curve as the AnimatedSize regression,
          // sampled deterministically so GPU readback cannot skip bad frames.
          top.value =
              1000 *
              (1 -
                  const Cubic(
                    0.2,
                    0.8,
                    0.2,
                    1,
                  ).transform(((frame + 1) * 16 / 300).clamp(0, 1)));
          await tester.pump();
          expect(scroll.offset, 0);
          final origin = tester.getTopLeft(find.byKey(capture));
          final boundary =
              capture.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          // Profile mode reads the just-composited picture, even if a broken
          // implementation marked the render object dirty after that frame.
          final image = boundary.toImageSync();
          try {
            final bytes = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            for (var i = 0; i < blocks.length; i++) {
              final rect = tester
                  .getRect(find.byKey(ValueKey(i)))
                  .shift(-origin);
              if (rect.top >= 598 || rect.bottom <= 2) continue;
              final y =
                  ((rect.top.clamp(2, 598) + rect.bottom.clamp(2, 598)) / 2)
                      .floor();
              final offset = (y * image.width + 10) * 4;
              expect(
                bytes.buffer.asUint8List(bytes.offsetInBytes + offset, 4),
                [0, 0, 255, 255],
                reason: 'Frame $frame must paint visible block $i at $rect',
              );
              checkedPixels++;
            }
            if (frame == 2 || frame == 20) {
              final png = (await image.toByteData(
                format: ui.ImageByteFormat.png,
              ))!;
              samples['$frame'] = base64Encode(
                png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
              );
            }
          } finally {
            image.dispose();
          }
        }
        expect(checkedPixels, greaterThan(100));
        binding.reportData = {
          ...?binding.reportData,
          'collapse-nested-$nested': {
            'frames': 21,
            'checkedPixels': checkedPixels,
            'blankPixels': 0,
            'sampleFramesPngBase64': samples,
          },
        };
        // ignore: avoid_print
        print(
          'COLLAPSE_DEVICE nested=$nested frames=21 checkedPixels=$checkedPixels blankPixels=0',
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        top.dispose();
        scroll.dispose();
        binding.framePolicy = framePolicy;
        binding.deviceEventDispatcher = deviceDispatcher;
      }
    });
  }
}
