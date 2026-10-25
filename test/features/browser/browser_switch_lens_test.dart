import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/features/browser/widgets/browser_switch_lens.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'lens uniforms preserve viewport origin and logical strength at each DPR',
    () {
      for (final dpr in [1.0, 2.0, 3.0]) {
        expect(
          browserSwitchLensUniforms(
            origin: const ui.Offset(17.5, 90),
            size: const ui.Size(50, 31),
            dpr: dpr,
            progress: .75,
            dark: true,
          ),
          [17.5 * dpr, 90 * dpr, 50 * dpr, 31 * dpr, dpr, .75, 1],
        );
      }
    },
  );

  test(
    'actual switch shader refracts track detail and release restores identity',
    () async {
      final program = await ui.FragmentProgram.fromAsset(
        'shaders/browser_switch_lens.frag',
      );
      for (final dpr in [1.0, 2.0]) {
        const origin = ui.Offset(14, 10);
        const size = ui.Size(50, 31);
        final width = (96 * dpr).round();
        final height = (64 * dpr).round();
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder)..scale(dpr);
        canvas.drawRect(
          const ui.Rect.fromLTWH(0, 0, 96, 64),
          ui.Paint()..color = const ui.Color(0xff000000),
        );
        // A sharp boundary inside the Flutter track distinguishes displacement
        // from an ordinary clear/blurred or tinted thumb.
        canvas.drawRect(
          const ui.Rect.fromLTWH(20, 0, 76, 64),
          ui.Paint()..color = const ui.Color(0xff00ff00),
        );
        final picture = recorder.endRecording();
        final background = await picture.toImage(width, height);
        picture.dispose();
        final shader = program.fragmentShader();
        shader.setFloat(0, width.toDouble());
        shader.setFloat(1, height.toDouble());
        shader.setImageSampler(0, background);
        Future<ui.Image> render(double progress) async {
          final uniforms = browserSwitchLensUniforms(
            origin: origin,
            size: size,
            dpr: dpr,
            progress: progress,
            dark: false,
          );
          for (var i = 0; i < uniforms.length; i++) {
            shader.setFloat(i + 2, uniforms[i]);
          }
          final recorder = ui.PictureRecorder();
          ui.Canvas(recorder).drawRect(
            ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
            ui.Paint()..shader = shader,
          );
          final picture = recorder.endRecording();
          final image = await picture.toImage(width, height);
          picture.dispose();
          return image;
        }

        final idle = await render(0);
        final pressed = await render(1);
        final a = (await idle.toByteData())!;
        final b = (await pressed.toByteData())!;
        final index =
            (((origin.dy + size.height / 2) * dpr).floor() * width +
                ((origin.dx + 3) * dpr).floor()) *
            4;
        expect(a.getUint8(index + 1), lessThan(5));
        expect(b.getUint8(index + 1), greaterThan(200));
        // The unmoved centre keeps the track's saturated green, not an invented
        // opaque white material or chromatic rim fill.
        final center = ((25 * dpr).floor() * width + (40 * dpr).floor()) * 4;
        expect(b.getUint8(center + 1), greaterThan(245));
        expect(b.getUint8(center), lessThan(10));
        shader.dispose();
        background.dispose();
        idle.dispose();
        pressed.dispose();
      }
    },
  );
}
