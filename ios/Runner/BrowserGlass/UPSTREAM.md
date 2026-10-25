# Browser legacy live glass

The runtime mechanism and mesh ABI in `BrowserLegacyGlassRuntime.h/.m` and
`BrowserGlassMesh.h` are adapted from Telegram-iOS, commit
`f1dd7a2dbd02cbbf513e75d5695d8d36d1cf5838`, copyright the Telegram-iOS contributors:

- `submodules/TelegramUI/Components/GlassBackgroundComponent/Sources/LegacyGlassView.swift`
- `submodules/TelegramUI/Components/MeshTransform/Sources/MeshTransform.swift`
- `submodules/TelegramUI/Components/MeshTransform/MeshTransformApi/PublicHeaders/MeshTransformApi/MeshTransformApi.h`
- `submodules/UIKitRuntimeUtils/Source/UIKitRuntimeUtils/UIKitUtils.m`

Source: https://github.com/TelegramMessenger/Telegram-iOS/tree/f1dd7a2dbd02cbbf513e75d5695d8d36d1cf5838

Telegram identifies its iOS source as GPL version 2 or later at
https://telegram.org/apps#source-code . This adaptation uses the GPL version 3
or later option; `COPYING` contains GPLv3. The combined application remains
subject to Kelivo's AGPLv3 terms and the GPLv3/AGPLv3 combination provisions.

The bounded Cartesian grid and signed-distance mapping are a Kelivo
implementation, not a copy of Telegram's mesh generator. The edge profile is
the same as Kelivo's existing independently authored `edge_warp.glsl`. There
are at most 841 vertices and 784 faces, with a per-view last-geometry cache and
no global cache of continuously changing radii. No screenshot or display-link
loop is used: Core Animation samples the live backdrop.

The native path is used only for liquid browser material on iOS 17–25. It
explicitly uses undocumented `CABackdropLayer`, `CAFilter`,
`CAMutableMeshTransform` and `meshTransform` runtime facilities. Class,
selector, method shape and result checks plus Objective-C exception handling
reject unsupported runtimes; the existing UIKit blur remains in that case.
These checks cannot establish compatibility with a physical iOS 18 runtime.
iOS 26 continues to use `UIGlassEffect`; reduced transparency/high contrast
uses opaque material and removes the legacy backdrop. Flutter-only routes use
their separate Flutter renderer, avoiding native views in those transitions.

The existing color-matrix pass blends the sampled page toward the foreground
theme, with a weaker tint for clear material. This retains page distortion
while preventing white Flutter glyphs on white pages or black glyphs on dark
pages. There is no extra backdrop/filter pass for this contrast protection.

`test/native/browser_glass_mesh_test.c` checks geometry with address/undefined
behavior sanitizers. `test/native/browser_legacy_glass_runtime_test.m` directly
constructs the legacy layer in a headless UIKit executable, checking the actual
runtime factory (including const-qualified Objective-C pointer encodings),
mesh cache, theme matrix and invalid-geometry cleanup. The runtime test passed
on the installed iOS 26.5 simulator on 2026-10-17. This validates the runtime
mechanism there, not iOS 18 compatibility, GPU appearance or physical-device
frame/thermal performance.
