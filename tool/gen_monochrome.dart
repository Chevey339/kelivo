// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

// Derives an adaptive-icon monochrome (themed icon) asset from the launcher
// foreground: traces the logo's color-band edges as line art, output
// white-on-transparent so the launcher can tint the alpha channel.
//
// The upstream foreground PNG has an opaque white background, so its alpha
// cannot be used directly (the launcher would render a solid shape).

const gradThreshold = 48;
const maskWhiteDistance = 24;
const nearMaskRadius = 4;
const lineRadius = 2;

Uint8List dilate(Uint8List src, int w, int h, int rad) {
  final tmp = Uint8List(src.length);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      int v = 0;
      for (int d = -rad; d <= rad; d++) {
        final xx = x + d;
        if (xx >= 0 && xx < w && src[y * w + xx] > v) v = src[y * w + xx];
      }
      tmp[y * w + x] = v;
    }
  }
  final out = Uint8List(src.length);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      int v = 0;
      for (int d = -rad; d <= rad; d++) {
        final yy = y + d;
        if (yy >= 0 && yy < h && tmp[yy * w + x] > v) v = tmp[yy * w + x];
      }
      out[y * w + x] = v;
    }
  }
  return out;
}

Float32List boxBlur(Uint8List src, int w, int h, int rad) {
  final tmp = Float32List(src.length);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      int sum = 0, n = 0;
      for (int d = -rad; d <= rad; d++) {
        final xx = x + d;
        if (xx >= 0 && xx < w) {
          sum += src[y * w + xx];
          n++;
        }
      }
      tmp[y * w + x] = sum / n;
    }
  }
  final out = Float32List(src.length);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      double sum = 0;
      int n = 0;
      for (int d = -rad; d <= rad; d++) {
        final yy = y + d;
        if (yy >= 0 && yy < h) {
          sum += tmp[yy * w + x];
          n++;
        }
      }
      out[y * w + x] = sum / n;
    }
  }
  return out;
}

void main() {
  final srcPath =
      'android/app/src/main/res/drawable-xxxhdpi/ic_launcher_foreground.png';
  final im = img.decodePng(File(srcPath).readAsBytesSync());
  if (im == null) {
    stderr.writeln('cannot decode $srcPath');
    exit(1);
  }
  final w = im.width, h = im.height;
  final r = Int32List(w * h), g = Int32List(w * h), b = Int32List(w * h);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final p = im.getPixel(x, y);
      final i = y * w + x;
      r[i] = p.r.toInt();
      g[i] = p.g.toInt();
      b[i] = p.b.toInt();
    }
  }

  // Logo mask: anything meaningfully non-white.
  final mask = Uint8List(w * h);
  for (int i = 0; i < w * h; i++) {
    final d = max(max(255 - r[i], 255 - g[i]), 255 - b[i]);
    mask[i] = d > maskWhiteDistance ? 1 : 0;
  }
  final near = dilate(mask, w, h, nearMaskRadius);

  // Edge magnitude via central differences, max across RGB channels so
  // boundaries between similarly-luminous color bands are caught too.
  final edges = Uint8List(w * h);
  for (int y = 1; y < h - 1; y++) {
    for (int x = 1; x < w - 1; x++) {
      final i = y * w + x;
      if (near[i] == 0) continue;
      int mag = 0;
      for (final c in [r, g, b]) {
        final gx = (c[i + 1] - c[i - 1]).abs();
        final gy = (c[i + w] - c[i - w]).abs();
        final m = gx + gy;
        if (m > mag) mag = m;
      }
      edges[i] = mag > gradThreshold ? 1 : 0;
    }
  }

  final thick = dilate(edges, w, h, lineRadius);
  final soft = boxBlur(thick, w, h, 1);

  // numChannels: 4 — the v4 default is RGB and silently drops the alpha.
  final mono = img.Image(width: w, height: h, numChannels: 4);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      mono.setPixelRgba(x, y, 255, 255, 255, (soft[y * w + x] * 255).round());
    }
  }

  // Grayscale preview of the alpha mask (white art on white is invisible).
  final preview = img.Image(width: w, height: h);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final a = (soft[y * w + x] * 255).round();
      preview.setPixelRgba(x, y, a, a, a, 255);
    }
  }
  File('tool/monochrome_preview.png').writeAsBytesSync(img.encodePng(preview));

  final densities = {
    'mdpi': 108,
    'hdpi': 162,
    'xhdpi': 216,
    'xxhdpi': 324,
    'xxxhdpi': 432,
  };
  densities.forEach((name, size) {
    final resized = size == w
        ? mono
        : img.copyResize(
            mono,
            width: size,
            height: size,
            interpolation: img.Interpolation.average,
          );
    final out = File(
      'android/app/src/main/res/drawable-$name/'
      'ic_launcher_monochrome.png',
    );
    out.writeAsBytesSync(img.encodePng(resized));
    print('wrote ${out.path} (${size}x$size)');
  });
}
