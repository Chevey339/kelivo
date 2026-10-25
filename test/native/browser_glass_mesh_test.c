// SPDX-License-Identifier: GPL-3.0-or-later
#include "../../ios/Runner/BrowserGlass/BrowserGlassMesh.h"
#include <assert.h>
#include <stdio.h>

static void verify(CGSize size, CGFloat radius) {
  KLVGlassVertex vertices[KLVGlassMaxVertices];
  KLVGlassFace faces[KLVGlassMaxFaces];
  size_t vertexCount, faceCount;
  assert(KLVBuildGlassMesh(size, radius, vertices, &vertexCount, faces, &faceCount));
  assert(vertexCount <= KLVGlassMaxVertices && faceCount <= KLVGlassMaxFaces);
  bool center = false, edge = false;
  for (size_t i = 0; i < vertexCount; i++) {
    KLVGlassVertex vertex = vertices[i];
    assert(isfinite(vertex.from.x) && isfinite(vertex.from.y));
    assert(vertex.from.x >= 0 && vertex.from.x <= 1);
    assert(vertex.from.y >= 0 && vertex.from.y <= 1);
    assert(vertex.to.x >= 0 && vertex.to.x <= 1);
    assert(vertex.to.y >= 0 && vertex.to.y <= 1 && vertex.to.z == 0);
    if (radius <= 0) {
      assert(fabs(vertex.from.x - vertex.to.x) < 1e-9);
      assert(fabs(vertex.from.y - vertex.to.y) < 1e-9);
    }
    if (fabs(vertex.to.x - .5) < 1e-9 && fabs(vertex.to.y - .5) < 1e-9) {
      center = true;
      assert(fabs(vertex.from.x - .5) < 1e-9 && fabs(vertex.from.y - .5) < 1e-9);
    }
    if (vertex.to.x == 0 && fabs(vertex.to.y - .5) < 1e-9) {
      edge = true;
      if (radius > 0) assert(vertex.from.x > 0);
    }
    // Each sample has a horizontally mirrored partner with mirrored sampling.
    bool mirrored = false;
    for (size_t j = 0; j < vertexCount; j++) {
      if (fabs(vertices[j].to.x + vertex.to.x - 1) < 1e-9 &&
          fabs(vertices[j].to.y - vertex.to.y) < 1e-9) {
        assert(fabs(vertices[j].from.x + vertex.from.x - 1) < 1e-8);
        assert(fabs(vertices[j].from.y - vertex.from.y) < 1e-8);
        mirrored = true;
        break;
      }
    }
    assert(mirrored);
  }
  assert(center && edge);
  for (size_t i = 0; i < faceCount; i++) {
    for (size_t j = 0; j < 4; j++) {
      assert(faces[i].indices[j] < vertexCount);
      assert(faces[i].weights[j] == 0);
    }
    KLVGlassPoint3D first = vertices[faces[i].indices[0]].to;
    KLVGlassPoint3D second = vertices[faces[i].indices[1]].to;
    KLVGlassPoint3D fourth = vertices[faces[i].indices[3]].to;
    assert(second.x > first.x && fourth.y > first.y);
  }
}

int main(void) {
  _Static_assert(sizeof(KLVGlassFace) == 32, "Core Animation face ABI");
  _Static_assert(sizeof(KLVGlassVertex) == 5 * sizeof(CGFloat), "Core Animation vertex ABI");
  const CGSize sizes[] = {{44, 44}, {300, 44}, {250, 400}, {500, 250}, {1, 1}, {16384, 1}};
  const CGFloat radii[] = {0, 16, 25, 1000};
  for (size_t i = 0; i < sizeof(sizes) / sizeof(sizes[0]); i++) {
    for (size_t j = 0; j < sizeof(radii) / sizeof(radii[0]); j++) verify(sizes[i], radii[j]);
  }
  CGFloat previous = 0;
  for (int i = 0; i <= 1000; i++) {
    CGFloat next = KLVGlassEdgeCurve(i / 1000.0);
    assert(next >= previous && next >= 0 && next <= 1);
    previous = next;
  }
  KLVGlassVertex vertices[KLVGlassMaxVertices];
  KLVGlassFace faces[KLVGlassMaxFaces];
  size_t vertexCount, faceCount;
  assert(!KLVBuildGlassMesh((CGSize){0, 44}, 22, vertices, &vertexCount, faces, &faceCount));
  assert(!KLVBuildGlassMesh((CGSize){NAN, 44}, 22, vertices, &vertexCount, faces, &faceCount));
  assert(!KLVBuildGlassMesh((CGSize){44, 44}, NAN, vertices, &vertexCount, faces, &faceCount));
  assert(!KLVBuildGlassMesh((CGSize){20000, 44}, 22, vertices, &vertexCount, faces, &faceCount));
  puts("browser glass mesh: bounded topology, refraction, symmetry, ABI and invalid geometry passed");
  return 0;
}
