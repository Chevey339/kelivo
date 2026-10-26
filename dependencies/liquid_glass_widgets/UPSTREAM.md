# Vendored liquid_glass_widgets

Source: https://github.com/sdegenaar/liquid_glass_widgets
Version: 1.12.0
Pub archive SHA-256: ff26caa79c37531cf9a930e14fa9a4f75adba417254198d23ff02fd74d8acf08
License: see LICENSE and source notices.

Imported from the verified pub.dev archive without Git metadata or a submodule.
Kelivo maintains this copy as an ordinary path dependency.

## Local changes

- Retain geometry across no-op layout and invalidate it on effective pixel-ratio
  changes (including Kelivo desktop zoom).
- Route package haptics through GlassHaptics host callbacks so Kelivo's master
  switch and platform feedback implementation apply to every library control.
- Expose `preloadPremiumGlass()` to prepare only the Premium geometry and
  render programs used by browser surfaces, without loading unused lightweight
  and interactive renderer programs on the browser's first presentation.
- Reduce the progressive-edge Gaussian kernel from 49 to 25 samples per axis.
  Kelivo's only application caller is `BrowserProgressiveEdge`, with sigma
  capped by its fixed 10 logical-pixel setting. The horizontal/vertical passes,
  gradient, device-pixel coordinates, and bounded clip remain unchanged. This
  lowers shader sampling work; it does not establish a real-device frame-rate
  or temperature improvement.
- Refresh Premium live-shader screen/pass coordinates while the retained
  backdrop-filter layer joins the current scene. Ancestor route translation or
  button stretch no longer waits for a post-frame repaint to update its UVs.
  The same geometry texture and foreground display lists are retained; only a
  changed coordinate set creates a replacement filter. Capture, frost and shared
  backdrop paths keep their required paint-time updates.
- Track shape geometry relative to its containing blend group, and blend-group
  geometry relative to its render layer. Moving an entire route therefore does
  not invalidate unchanged local geometry. Record the initial identity matrix
  explicitly: Flutter's `matrixEquals(identity, null)` otherwise skips the
  baseline and misses the first real movement.

`test/composited_glass_transform_test.dart` checks same-scene translation and
scale with retained child paint, plus local-versus-route geometry invalidation.
Kelivo's explicit `integration_test/browser_glass_transform_probe.dart` compares
the first translated/stretched Impeller frame with a forced repaint at identical
geometry, in light and dark scenes. Layer tests alone do not establish the GPU
pixel result, physical-device smoothness, or temperature.

The 1.12.0 package includes its own maintained renderer. No separate
liquid_glass_renderer dependency is needed.

### Optional edge-warp lens

Kelivo adds `GlassLensModel.edgeWarp` to the existing Premium renderer. The
`spherical` default and `paraxial` calculations are unchanged. The new model is
an independently written GLSL implementation of the distance profile and tuning
parameters inspected in Telegram-iOS commit
`f1dd7a2dbd02cbbf513e75d5695d8d36d1cf5838`:

- [LegacyGlassView.swift](https://github.com/TelegramMessenger/Telegram-iOS/blob/f1dd7a2dbd02cbbf513e75d5695d8d36d1cf5838/submodules/TelegramUI/Components/GlassBackgroundComponent/Sources/LegacyGlassView.swift)
- [GenerateMesh.swift](https://github.com/TelegramMessenger/Telegram-iOS/blob/f1dd7a2dbd02cbbf513e75d5695d8d36d1cf5838/submodules/TelegramUI/Components/MeshTransform/Sources/GenerateMesh.swift)

No Swift/Metal source, private Core Animation mesh/backdrop API, or screenshot
capture loop is imported. The existing SDF gives the inward distance and normal.
The warp fades over `min(12pt, clamped corner radius)` using cubic control points
`(0.816137566137566, 0.20502645502645533)` and
`(0.5806878306878306, 0.873015873015873)`. A 20pt inward sample offset is multiplied
by a smooth 1–1.5 boost in the outer 2pt. Source positions remain within the
geometry bounds. Ellipses use their shorter semiaxis; blended shapes choose the
nearest constituent's radius. These extensions use the package's existing shape
SDF, so a superellipse retains its own outline rather than becoming a roundrect.

The existing geometry matte caches the profile: in this mode RG stores the
outward slope and B stores displacement normalized to 30pt. A new geometry-mode
uniform invalidates this encoding when switching models. Visibility scales the
render-stage displacement and final premultiplied coverage, without geometry
rebuilds. The coverage fade prevents a nearly hidden submenu from leaving an
opaque backdrop copy or a bright last-pixel rim; other lens models retain their
existing dematerialization behavior. Thickness and refractive
index retain their own meanings and do not set edge-warp distance. The live
backdrop pass only decodes the matte and samples the existing input texture.

Bezier inversion performs eight bounded bisections plus interpolation within
the final interval, only on geometry edge pixels. Comparing 100001 inputs to a
50-step converged inverse gives maximum curve error `7.31e-6` (under `0.00022pt`
at 30pt reach). This numerical comparison excludes GPU floating-point and matte
quantization error; the 8-bit B channel alone has a half-step of about `0.059pt`.
No new PSO, per-radius cache, image readback, or render pass is introduced.

This Flutter model is separate from Kelivo's iOS passive native-glass adapter.
The native adapter uses system glass on iOS 26 and public UIKit blur on earlier
iOS versions. Android's texture WebView supplies the Flutter backdrop input
normally.


### Browser edge work bound (2026-10-18)

The composed progressive blur's intermediate may be allocated over the full
backdrop by Impeller. Its shader now passes through pixels outside the widget
rectangle expanded by `max(12, 3 * maxSigma) + 1` physical pixels. The outer axis cannot
sample beyond that halo (including bilinear interpolation), so this avoids the
25-tap kernel outside the contributing region. It bounds expensive sampling
work, not intermediate texture allocation; it is not an engine coverage fix.
