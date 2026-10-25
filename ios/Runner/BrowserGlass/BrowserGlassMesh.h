// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright 2026 Kelivo contributors. See UPSTREAM.md for runtime ABI provenance.
#ifndef KLV_BROWSER_GLASS_MESH_H
#define KLV_BROWSER_GLASS_MESH_H

#include <CoreGraphics/CoreGraphics.h>
#include <math.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

// Core Animation's mesh ABI, also described by Telegram's MeshTransformApi.
typedef struct { CGFloat x, y, z; } KLVGlassPoint3D;
typedef struct { CGPoint from; KLVGlassPoint3D to; } KLVGlassVertex;
typedef struct { uint32_t indices[4]; float weights[4]; } KLVGlassFace;
enum { KLVGlassAxisCapacity = 29, KLVGlassMaxVertices = 841, KLVGlassMaxFaces = 784 };

static inline CGFloat KLVGlassClamp(CGFloat value, CGFloat low, CGFloat high) {
  return fmax(low, fmin(high, value));
}

static inline CGFloat KLVGlassCubic(CGFloat t, CGFloat first, CGFloat second) {
  return t * (3 * first + t * (3 * second - 6 * first + t * (1 + 3 * first - 3 * second)));
}

// Same bounded edge profile as Kelivo's existing edge_warp.glsl. The mesh is
// updated for geometry changes only; this is never evaluated per display tick.
static inline CGFloat KLVGlassEdgeCurve(CGFloat weight) {
  if (weight <= 0 || weight >= 1) return KLVGlassClamp(weight, 0, 1);
  CGFloat low = 0, high = 1;
  for (int i = 0; i < 8; i++) {
    CGFloat mid = (low + high) * 0.5;
    if (KLVGlassCubic(mid, 0.816137566137566, 0.5806878306878306) < weight) low = mid;
    else high = mid;
  }
  CGFloat xLow = KLVGlassCubic(low, 0.816137566137566, 0.5806878306878306);
  CGFloat xHigh = KLVGlassCubic(high, 0.816137566137566, 0.5806878306878306);
  CGFloat t = low + (high - low) * KLVGlassClamp((weight - xLow) / fmax(xHigh - xLow, 1e-7), 0, 1);
  CGFloat value = KLVGlassCubic(t, 0.20502645502645533, 0.873015873015873);
  return value >= 0.997 ? 1 : value;
}

static inline size_t KLVGlassAxis(CGFloat extent, CGFloat radius, CGFloat band, CGFloat *values) {
  size_t count = 0;
  for (int i = 0; i <= 12; i++) values[count++] = extent * i / 12;
  for (int i = 1; i <= 5; i++) {
    values[count++] = radius * i / 5;
    values[count++] = extent - radius * i / 5;
  }
  for (int i = 1; i <= 3; i++) {
    values[count++] = band * i / 3;
    values[count++] = extent - band * i / 3;
  }
  // At most 29 entries: insertion sorting needs no allocations or global cache.
  for (size_t i = 1; i < count; i++) {
    CGFloat value = values[i];
    size_t j = i;
    while (j > 0 && values[j - 1] > value) { values[j] = values[j - 1]; j--; }
    values[j] = value;
  }
  size_t unique = 0;
  for (size_t i = 0; i < count; i++) {
    if (unique == 0 || values[i] - values[unique - 1] > 1e-6) values[unique++] = values[i];
  }
  return unique;
}

static inline bool KLVBuildGlassMesh(CGSize size, CGFloat requestedRadius,
                                    KLVGlassVertex *vertices, size_t *vertexCount,
                                    KLVGlassFace *faces, size_t *faceCount) {
  *vertexCount = 0; *faceCount = 0;
  if (!isfinite(size.width) || !isfinite(size.height) || !isfinite(requestedRadius) ||
      size.width <= 0 || size.height <= 0 || size.width > 16384 || size.height > 16384) return false;
  CGFloat radius = KLVGlassClamp(requestedRadius, 0, fmin(size.width, size.height) * 0.5);
  CGFloat band = fmin(12, radius);
  CGFloat xs[KLVGlassAxisCapacity], ys[KLVGlassAxisCapacity];
  size_t columns = KLVGlassAxis(size.width, radius, band, xs);
  size_t rows = KLVGlassAxis(size.height, radius, band, ys);
  for (size_t row = 0; row < rows; row++) {
    for (size_t column = 0; column < columns; column++) {
      CGFloat x = xs[column], y = ys[row];
      CGFloat px = x - size.width * 0.5, py = y - size.height * 0.5;
      CGFloat qx = fabs(px) - size.width * 0.5 + radius;
      CGFloat qy = fabs(py) - size.height * 0.5 + radius;
      CGFloat outside = hypot(fmax(0, qx), fmax(0, qy));
      CGFloat distance = outside + fmin(fmax(qx, qy), 0) - radius;
      CGFloat nx = 0, ny = 0;
      if (qx > 0 && qy > 0 && outside > 0) { nx = qx / outside; ny = qy / outside; }
      else if (qx > qy) nx = 1;
      else ny = 1;
      if (px < 0) nx = -nx;
      if (py < 0) ny = -ny;
      CGFloat weight = band > 0 ? KLVGlassClamp(1 + distance / band, 0, 1) : 0;
      CGFloat edge = KLVGlassClamp(1 + distance / 2, 0, 1);
      CGFloat boost = 1 + 0.5 * edge * edge * (3 - 2 * edge);
      CGFloat displacement = fmin(20, radius) * KLVGlassEdgeCurve(weight) * boost;
      vertices[(*vertexCount)++] = (KLVGlassVertex){
        .from = CGPointMake(KLVGlassClamp((x - nx * displacement) / size.width, 0, 1),
                            KLVGlassClamp((y - ny * displacement) / size.height, 0, 1)),
        .to = { x / size.width, y / size.height, 0 }
      };
    }
  }
  for (size_t row = 0; row + 1 < rows; row++) {
    for (size_t column = 0; column + 1 < columns; column++) {
      uint32_t first = (uint32_t)(row * columns + column);
      faces[(*faceCount)++] = (KLVGlassFace){
        .indices = { first, first + 1, first + (uint32_t)columns + 1, first + (uint32_t)columns },
        .weights = { 0, 0, 0, 0 }
      };
    }
  }
  return *vertexCount > 0 && *faceCount > 0;
}
#endif
