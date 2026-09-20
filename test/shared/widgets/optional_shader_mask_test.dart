import 'dart:ui' as ui;

import 'package:Kelivo/shared/widgets/optional_shader_mask.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'toggle matches native masking and disabled pass-through pixels',
    (tester) async {
      final enabled = ValueNotifier(false);
      final actualKey = GlobalKey();
      final expectedKey = GlobalKey();
      ui.Shader shader(Rect rect) => const LinearGradient(
        colors: [Colors.transparent, Colors.white, Colors.transparent],
        stops: [0, .5, 1],
      ).createShader(rect);
      const content = ColoredBox(color: Color(0xff247bd4));
      Widget capture(GlobalKey key, Widget child) => RepaintBoundary(
        key: key,
        child: SizedBox(width: 40, height: 40, child: child),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: ValueListenableBuilder<bool>(
              valueListenable: enabled,
              builder: (_, value, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  capture(
                    actualKey,
                    OptionalShaderMask(
                      enabled: value,
                      shaderCallback: shader,
                      blendMode: BlendMode.dstIn,
                      child: content,
                    ),
                  ),
                  capture(
                    expectedKey,
                    value
                        ? ShaderMask(
                            shaderCallback: shader,
                            blendMode: BlendMode.dstIn,
                            child: content,
                          )
                        : content,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      Future<List<int>> pixels(GlobalKey key) async {
        final render =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = render.toImageSync();
        try {
          final data = (await tester.runAsync(
            () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
          ))!;
          return data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          );
        } finally {
          image.dispose();
        }
      }

      for (final value in [false, true, false, true]) {
        enabled.value = value;
        await tester.pump();
        expect(await pixels(actualKey), await pixels(expectedKey));
        final mask = tester.renderObject<RenderShaderMask>(
          find.byType(OptionalShaderMask),
        );
        expect(mask.debugLayer, value ? isA<ShaderMaskLayer>() : isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      enabled.dispose();
    },
  );
}
