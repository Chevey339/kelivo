// Switch lens adapted from Glass-HQ/liquid-glass maps.wgsl and control-thumb.tsx.
// https://github.com/Glass-HQ/liquid-glass (MIT, Copyright (c) 2026 Glass HQ)
// The outline is evaluated analytically for a capsule; the backdrop is sampled
// directly by Flutter rather than producing an SVG displacement-map atlas.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
#include <flutter/runtime_effect.glsl>
uniform vec2 uSize;
uniform vec2 uOrigin;
uniform vec2 uRegionSize;
uniform float uDpr;
uniform float uProgress;
uniform float uDark;
uniform sampler2D uBackdrop;
out vec4 fragColor;
float sat(float x) { return clamp(x, 0.0, 1.0); }
void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 p = (frag - uOrigin - uRegionSize * .5) / uDpr;
  vec2 halfSize = uRegionSize * .5 / uDpr;
  float radius = min(halfSize.x, halfSize.y);
  vec2 core = max(halfSize - vec2(radius), vec2(0));
  vec2 delta = p - clamp(p, -core, core);
  float lengthToCore = length(delta);
  float d = lengthToCore - radius;
  vec2 normal = lengthToCore > .0001 ? delta / lengthToCore : vec2(0, -1);
  float depth = sat(-d * .05);
  float edge = 1.0 - sat(sqrt((2.0 - depth) * depth));
  // HQ's displacement map is encoded as .5 - normal * edge * .5 and its
  // SVG displacement scale is 2 * refraction; the switch uses 7.75 points.
  vec2 sampleAt = frag - normal * edge * 7.75 * uDpr * uProgress;
  vec4 backdrop = texture(uBackdrop, clamp(sampleAt / uSize, vec2(0), vec2(1)));
  // Analytic fwidth of this capsule SDF. Avoid derivative instructions so the
  // same shader is also executable by Skia's software runtime-effect tests.
  float aa = max(abs(normal.x) + abs(normal.y), 1.0) / uDpr;
  float directional = pow(sat((abs(normal.y) - cos(1.08)) / (1.0 - cos(1.08))), 1.25);
  float diffuseDir = pow(sat((abs(normal.y) - cos(1.08 * .65)) / (1.0 - cos(1.08 * .65))), 1.25);
  float stroke = sat((d + .9) / aa + .5) * sat(.5 - d / aa);
  float specular = directional * stroke;
  specular /= 1.0 + .5 * (1.0 - specular);
  float diffuse = diffuseDir * .18 * pow(1.0 - sat(-d / 4.5), 2.0);
  float highlight = sat(specular * mix(1.0, .82, uDark) + diffuse * mix(1.0, .4, uDark));
  float side = pow(abs(normal.x), 8.0) * (1.0 - smoothstep(0.0, 1.3, abs(d)));
  vec3 color = backdrop.rgb * (1.0 - side * .24 * uProgress);
  color = mix(color, vec3(backdrop.a), highlight * .82 * uProgress);
  fragColor = vec4(color, backdrop.a);
}
