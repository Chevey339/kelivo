import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:liquid_glass_widgets/src/engine/liquid_glass_blend_group.dart';
import 'package:liquid_glass_widgets/src/engine/liquid_glass_settings.dart';
import 'package:liquid_glass_widgets/src/engine/render_liquid_glass_geometry.dart';
import 'package:liquid_glass_widgets/src/engine/rendering/liquid_glass_render_object.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ui.FragmentShader> shader(String name) async =>
      (await ui.FragmentProgram.fromAsset(
        'packages/liquid_glass_widgets/shaders/$name.frag',
      ))
          .fragmentShader();

  Future<ui.Image> paint(ui.Shader shader, int width, int height,
      {ui.Image? backdrop}) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    if (backdrop != null) {
      canvas.drawImage(backdrop, ui.Offset.zero, ui.Paint());
    }
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      ui.Paint()..shader = shader,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    picture.dispose();
    return image;
  }

  Future<ui.Image> geometry({
    double radius = 24,
    double dpr = 1,
    double shapeType = 3,
    ui.Size size = const ui.Size(96, 48),
  }) async {
    final s = await shader('liquid_glass_geometry_blended');
    final values = List<double>.filled(122, 0);
    values.setRange(0, 15, [
      size.width * dpr,
      size.height * dpr,
      1.2,
      0,
      10 * dpr,
      0,
      1,
      dpr,
      shapeType,
      size.width / 2 * dpr,
      size.height / 2 * dpr,
      size.width * dpr,
      size.height * dpr,
      radius * dpr,
      radius * dpr,
    ]);
    values[121] = GlassLensModel.edgeWarp.index.toDouble();
    for (var i = 0; i < values.length; i++) {
      s.setFloat(i, values[i]);
    }
    final image =
        await paint(s, (size.width * dpr).round(), (size.height * dpr).round());
    s.dispose();
    return image;
  }

  int channel(ByteData bytes, int width, int x, int y, int c) =>
      bytes.getUint8((y * width + x) * 4 + c);

  test('edge warp remains optional through settings copies and interpolation',
      () {
    const original = LiquidGlassSettings();
    final edge = original.copyWith(lensModel: GlassLensModel.edgeWarp);
    expect(original.lensModel, GlassLensModel.spherical);
    expect(edge.copyWith(blur: 2).lensModel, GlassLensModel.edgeWarp);
    expect(LiquidGlassSettings.lerp(original, edge, .75).lensModel,
        GlassLensModel.edgeWarp);
    expect(edge, isNot(original));
  });

  test(
      'geometry model changes invalidate, intensity and visibility retain matte',
      () async {
    final s = await shader('liquid_glass_geometry_blended');
    final groupLink = GlassGroupLink();
    final group = RenderLiquidGlassBlendGroup(
      renderLink: GeometryRenderLink(),
      devicePixelRatio: 1,
      geometryShader: s,
      settings: const LiquidGlassSettings(),
      link: groupLink,
      blend: 0,
    );
    group.geometryState = LiquidGlassGeometryState.updated;
    group.settings =
        group.settings.copyWith(lensModel: GlassLensModel.edgeWarp);
    expect(group.geometryState, LiquidGlassGeometryState.needsUpdate);
    group.geometryState = LiquidGlassGeometryState.updated;
    group.settings = group.settings.copyWith(
        visibility: .4, thickness: 42, refractiveIndex: 1.6, lightIntensity: 1);
    expect(group.geometryState, LiquidGlassGeometryState.updated);
    group.settings =
        group.settings.copyWith(lensModel: GlassLensModel.spherical);
    expect(group.geometryState, LiquidGlassGeometryState.needsUpdate);
    group.dispose();
    groupLink.dispose();
    s.dispose();
  });

  test('actual geometry shader limits the warp to radius and 12 logical pixels',
      () async {
    for (final dpr in [1.0, 2.0, 3.0]) {
      for (final radius in [6.0, 24.0]) {
        final image = await geometry(radius: radius, dpr: dpr);
        final data = (await image.toByteData())!;
        final x = (48 * dpr).floor();
        final band = radius < 12 ? radius : 12;
        // Blue is pull / 30: nonzero just inside the edge, zero beyond band.
        expect(channel(data, image.width, x, dpr.floor(), 2), greaterThan(20));
        expect(channel(data, image.width, x, ((band + 1) * dpr).floor(), 2), 0);
        expect(channel(data, image.width, x, (24 * dpr).floor(), 2), 0);
        image.dispose();
      }
    }
  });

  test('constant capsule radius has identical actual shader geometry',
      () async {
    for (final dpr in [1.0, 2.0, 3.0]) {
      for (final shapeType in [1.0, 3.0]) {
        for (final size in [
          const ui.Size(48, 48),
          const ui.Size(250, 360),
          const ui.Size(250, 100),
        ]) {
          final original = await geometry(
              radius: size.width / 2,
              dpr: dpr,
              shapeType: shapeType,
              size: size);
          final capsule = await geometry(
              radius: 1000, dpr: dpr, shapeType: shapeType, size: size);
          final a = (await original.toByteData())!.buffer.asUint8List();
          final b = (await capsule.toByteData())!.buffer.asUint8List();
          expect(listEquals(a, b), isTrue,
              reason: 'size=$size dpr=$dpr shape=$shapeType');
          original.dispose();
          capsule.dispose();
        }
      }
    }
  });

  test('actual render shader pulls the backdrop inward and fades to identity',
      () async {
    final matte = await geometry();
    final background = await paint(
        ui.Gradient.linear(
          const ui.Offset(0, 0),
          const ui.Offset(0, 48),
          [const ui.Color(0xFF000000), const ui.Color(0xFFFFFFFF)],
        ),
        96,
        48);
    final s = await shader('liquid_glass_render');
    final values = List<double>.filled(47, 0);
    values[0] = values[4] = 96;
    values[1] = values[5] = 48;
    values[10] = 1.2;
    values[12] = 10;
    values[13] = 1;
    values[16] = 1;
    values[30] = 1 / 3;
    values[33] = 1; // direct, untinted body
    values[40] = GlassLensModel.edgeWarp.index.toDouble();
    for (var i = 0; i < values.length; i++) {
      s.setFloat(i, values[i]);
    }
    s.setImageSampler(0, background);
    s.setImageSampler(1, matte);
    s.setFloat(46, 1);
    final warped = await paint(s, 96, 48, backdrop: background);
    s.setFloat(46, 0);
    final identity = await paint(s, 96, 48, backdrop: background);
    final a = (await warped.toByteData())!;
    final b = (await identity.toByteData())!;
    expect(
        channel(a, 96, 48, 1, 0), greaterThan(channel(b, 96, 48, 1, 0) + 80));
    expect(channel(a, 96, 48, 46, 0), lessThan(channel(b, 96, 48, 46, 0) - 80));
    expect(channel(a, 96, 48, 24, 0), closeTo(channel(b, 96, 48, 24, 0), 1));
    s.dispose();
    warped.dispose();
    identity.dispose();
    background.dispose();
    matte.dispose();
  });

  test('edge-warp coverage fades its last bright rim without an opaque copy',
      () async {
    final matte = await geometry();
    final background = await paint(
        ui.Gradient.linear(
          const ui.Offset(0, 0),
          const ui.Offset(96, 0),
          [const ui.Color(0xFF000000), const ui.Color(0xFF000000)],
        ),
        96,
        48);
    final s = await shader('liquid_glass_render');
    final values = List<double>.filled(47, 0);
    values[0] = values[4] = 96;
    values[1] = values[5] = 48;
    values[6] = values[7] = values[8] = 1;
    values[13] = 1;
    values[17] = .73;
    values[18] = -.68;
    values[30] = 1 / 3;
    values[33] = 1;
    values[40] = GlassLensModel.edgeWarp.index.toDouble();
    var previousPeak = 256;
    for (final visibility in [1.0, .5, .1, .01, 0.0]) {
      values[9] = .14 * visibility;
      values[10] = 1 + .2 * visibility;
      values[12] = 10 * visibility;
      values[14] = .8 * visibility;
      values[15] = .15 * visibility;
      values[16] = 1 + .08 * visibility;
      values[28] = .16 / 3 * visibility;
      values[29] = visibility;
      values[46] = visibility;
      for (var i = 0; i < values.length; i++) {
        s.setFloat(i, values[i]);
      }
      s.setImageSampler(0, background);
      s.setImageSampler(1, matte);
      final output = await paint(s, 96, 48);
      final pixels = (await output.toByteData())!;
      expect(channel(pixels, 96, 48, 24, 3), closeTo(255 * visibility, 1));
      var peak = 0;
      for (var offset = 0; offset < pixels.lengthInBytes; offset += 4) {
        final value = pixels.getUint8(offset);
        if (value > peak) peak = value;
        expect(pixels.getUint8(offset + 3),
            lessThanOrEqualTo((255 * visibility).ceil()));
      }
      expect(peak, lessThanOrEqualTo(previousPeak));
      if (visibility == 0) expect(peak, 0);
      previousPeak = peak;
      output.dispose();
    }
    s.dispose();
    matte.dispose();
    background.dispose();
  });
}
