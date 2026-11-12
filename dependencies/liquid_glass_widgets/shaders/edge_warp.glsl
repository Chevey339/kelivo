// Copyright 2026 Kelivo contributors. SPDX-License-Identifier: MIT
// Independently written distance-based refraction using parameters documented
// in Telegram-iOS LegacyGlassView / GenerateMesh, commit f1dd7a2d. This is not
// a port of its private Core Animation mesh/backdrop implementation.
// See UPSTREAM.md for source links, numerical validation and platform limits.

// Evaluate the monotonic cubic x(t) and y(t). Eight bracket reductions and
// interpolation inside the final bracket give sub-pixel precision without
// an unbounded Newton iteration. This runs in the cached geometry pass only.
float edgeWarpCubic(float t, float p1, float p2) {
    return t * (3.0 * p1 + t * (3.0 * p2 - 6.0 * p1
        + t * (1.0 + 3.0 * p1 - 3.0 * p2)));
}

float edgeWarpCurve(float weight) {
    if (weight <= 0.0) return 0.0;
    if (weight >= 1.0) return 1.0;
    const vec2 first = vec2(0.816137566137566, 0.20502645502645533);
    const vec2 second = vec2(0.5806878306878306, 0.873015873015873);
    float lo = 0.0;
    float hi = 1.0;
    for (int i = 0; i < 8; i++) {
        float mid = (lo + hi) * 0.5;
        if (edgeWarpCubic(mid, first.x, second.x) < weight) lo = mid;
        else hi = mid;
    }
    float xLo = edgeWarpCubic(lo, first.x, second.x);
    float xHi = edgeWarpCubic(hi, first.x, second.x);
    float t = mix(lo, hi, clamp((weight - xLo) / max(xHi - xLo, 1e-7), 0.0, 1.0));
    float value = edgeWarpCubic(t, first.y, second.y);
    // Legacy snaps its last 0.003 to the endpoint as well.
    return value >= 0.997 ? 1.0 : value;
}

float edgeWarpShapeRadius(float type, vec2 p, vec2 center, vec2 size,
                          float top, float bottom) {
    float limit = max(0.0, 0.5 * min(size.x, size.y));
    if (type > 1.5 && type < 2.5) return limit;
    float radius = mix(top, bottom, smoothstep(-2.0, 2.0, p.y - center.y));
    return clamp(radius, 0.0, limit);
}

// Match the existing SDF's constant array indices on GLES/SkSL. A browser
// capsule has one shape; groups choose the nearest constituent's corner
// radius while using the already-computed smooth-union distance/normal.
#define EDGE_WARP_RADIUS(BASE) edgeWarpShapeRadius(uShapeData[BASE], p, \
    vec2(uShapeData[BASE+1], uShapeData[BASE+2]), \
    vec2(uShapeData[BASE+3], uShapeData[BASE+4]), \
    uShapeData[BASE+5], uShapeData[BASE+6])
#define EDGE_WARP_NEAREST(INDEX, BASE) \
    if (n > INDEX) { \
        float candidate = SDF_SHAPE_N(BASE); \
        if (candidate < nearest) { nearest = candidate; radius = EDGE_WARP_RADIUS(BASE); } \
    }
float edgeWarpRadius(vec2 p, int n) {
    float radius = EDGE_WARP_RADIUS(0);
    if (n <= 1) return radius;
    float nearest = sdf0(p);
    EDGE_WARP_NEAREST(1, 7)
    EDGE_WARP_NEAREST(2, 14)
    EDGE_WARP_NEAREST(3, 21)
    EDGE_WARP_NEAREST(4, 28)
    EDGE_WARP_NEAREST(5, 35)
    EDGE_WARP_NEAREST(6, 42)
    EDGE_WARP_NEAREST(7, 49)
#ifndef LGR_OPENGLES_CAP_SHAPES
    EDGE_WARP_NEAREST(8, 56)
    EDGE_WARP_NEAREST(9, 63)
    EDGE_WARP_NEAREST(10, 70)
    EDGE_WARP_NEAREST(11, 77)
    EDGE_WARP_NEAREST(12, 84)
    EDGE_WARP_NEAREST(13, 91)
    EDGE_WARP_NEAREST(14, 98)
    EDGE_WARP_NEAREST(15, 105)
#endif
    return radius;
}
#undef EDGE_WARP_NEAREST
#undef EDGE_WARP_RADIUS
