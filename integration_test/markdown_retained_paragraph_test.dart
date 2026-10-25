import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:markstream/markstream.dart';

// flutter drive --profile -d DEVICE --driver=test_driver/integration_test.dart
//   --target=integration_test/markdown_retained_paragraph_test.dart
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('retained paragraphs match an uncropped reference on device', (
    tester,
  ) async {
    final framePolicy = binding.framePolicy;
    final dispatcher = binding.deviceEventDispatcher;
    binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.onlyPumps;
    binding.deviceEventDispatcher = null;
    final top = ValueNotifier(720.0);
    final source = ValueNotifier(
      List.generate(
        200,
        (i) => 'Paragraph $i **bold** 中文 text and more content.',
      ).join('\n\n'),
    );
    final controllers = [ScrollController(), ScrollController()];
    final captures = [GlobalKey(), GlobalKey()];
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < 2; i++)
                  RepaintBoundary(
                    key: captures[i],
                    child: SizedBox(
                      width: 180,
                      height: 600,
                      child: ColoredBox(
                        color: Colors.white,
                        child: SingleChildScrollView(
                          controller: controllers[i],
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ValueListenableBuilder<double>(
                                valueListenable: top,
                                builder: (_, height, _) =>
                                    SizedBox(height: height),
                              ),
                              ValueListenableBuilder<String>(
                                valueListenable: source,
                                builder: (_, text, _) => MarkstreamView(
                                  source: text,
                                  cullToViewport: i == 0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      var checkedBytes = 0;
      for (var frame = 0; frame < 41; frame++) {
        if (frame <= 20) {
          top.value = 720 * (1 - frame / 20);
        } else if (frame <= 35) {
          final progress = (frame - 20) / 15;
          for (final scroll in controllers) {
            scroll.jumpTo(scroll.position.maxScrollExtent * progress);
          }
        } else {
          source.value += ' **appended $frame**';
        }
        await tester.pump();
        expect(
          controllers[0].position.maxScrollExtent,
          closeTo(controllers[1].position.maxScrollExtent, .001),
        );
        final images = [
          for (final key in captures)
            (key.currentContext!.findRenderObject()! as RenderRepaintBoundary)
                .toImageSync(),
        ];
        try {
          final first = (await images[0].toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          final second = (await images[1].toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          final actual = first.buffer.asUint8List(
            first.offsetInBytes,
            first.lengthInBytes,
          );
          final reference = second.buffer.asUint8List(
            second.offsetInBytes,
            second.lengthInBytes,
          );
          expect(actual.length, reference.length);
          var different = 0;
          for (var i = 0; i < actual.length; i++) {
            if (actual[i] != reference[i]) different++;
          }
          expect(
            different,
            0,
            reason: 'retained frame $frame differs from the reference',
          );
          checkedBytes += actual.length;
        } finally {
          for (final image in images) {
            image.dispose();
          }
        }
        expect(tester.takeException(), isNull);
      }
      binding.reportData = {
        ...?binding.reportData,
        'retainedParagraphs': {
          'frames': 41,
          'checkedRgbaBytes': checkedBytes,
          'differentBytes': 0,
        },
      };
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      for (final scroll in controllers) {
        scroll.dispose();
      }
      top.dispose();
      source.dispose();
      binding.framePolicy = framePolicy;
      binding.deviceEventDispatcher = dispatcher;
    }
  });
}
