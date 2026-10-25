# Telegram browser interaction reference

Read-only source audit of `/Users/psyche/tmp/projects/Telegram-iOS` at local HEAD
`f1dd7a2dbd02cbbf513e75d5695d8d36d1cf5838` (2026-10-15). The complete
`TouchEffect.swift`, its clipping/container setup, and the directly related
context-source, continuation, selection, cancellation and navigation handlers
were inspected. These are Telegram implementation facts, not recovered Apple
Safari constants.

## The shared touch effect and the native effect are separate paths

[TouchEffect.swift](/Users/psyche/tmp/projects/Telegram-iOS/submodules/TelegramUI/Components/GlassBackgroundComponent/Sources/TouchEffect.swift:5)
contains a passive `GlassHighlightGestureRecognizer`. It neither prevents nor
is prevented by another recognizer, allows simultaneous recognition, and does
not cancel or delay view touches. Down creates the effect, saves the initial
location, sets the highlight's local position, zeros the stretch and starts
tracking. Move updates both the local light position and displacement from the
initial point immediately. End/cancel/reset stop tracking; the effect removes
its highlight layer on deinitialization.

[GlassBackgroundView](/Users/psyche/tmp/projects/Telegram-iOS/submodules/TelegramUI/Components/GlassBackgroundComponent/Sources/GlassBackgroundComponent.swift:504)
uses `UIGlassEffect` on iOS 26 when `useCustomGlassImpl` is false. That branch
has no legacy highlight container or custom highlight recognizer. Older systems
or the custom branch use `LegacyGlassView` plus `GlassHighlightGestureRecognizer`.
The global switch follows the experimental `fakeGlass` setting in
`SharedAccountContext.swift:536`. `ButtonComponent.swift:574` also supplies the
same shared highlight recognizer for its `.glass` appearance; `.actualGlass`
instead delegates to `GlassBackgroundView(isInteractive: true)`.

## Transform and light parameters

The shared effect's [transform](/Users/psyche/tmp/projects/Telegram-iOS/submodules/TelegramUI/Components/GlassBackgroundComponent/Sources/TouchEffect.swift:186)
uses the highlight container's dimensions, falling back to its target view.

- Uniform pressed scale is `1 + 20 / max(width, height)`: the longer side grows
  by 20 points, so a circle and a wide capsule do not share a fixed percentage.
- With aspect `a = width / height`, drag is normalized as `(dx / a, dy)`.
  For its length `L`, resistance is `k = 1 - 1 / (L / height / (5a) + 1)`.
  Translation follows that normalized direction with maximum magnitude 24.
- Additional directional stretch is `16 / height * k`, weighted by the
  difference between the absolute direction components. The major axis grows;
  the other axis uses the reciprocal factor. This preserves area relative to
  the uniform pressed scale.
- Lift-on spring: mass 1.36, stiffness 568, damping 39.7, initial velocity 0.
  Lift-off: mass 2, stiffness 460, damping 21.8, initial velocity 0. Animated
  retargeting starts from the current presentation transform. Move updates are
  immediate and replace any in-progress transform animation.

The [light](/Users/psyche/tmp/projects/Telegram-iOS/submodules/TelegramUI/Components/GlassBackgroundComponent/Sources/TouchEffect.swift:258)
is a 300 × 300 radial gradient centered at the current contact. It has eight
stops: white alpha 1 at location 0; alpha .5 at location .5; the remaining
outer-half stops decay to zero using Bézier `(.42, 0, .58, 1)`. The **entire
layer's tracking opacity is only .1**, so its center contributes at most 10%
white. Configured opacity transitions are 120 ms ease-out on and 220 ms
ease-in-out off. The source releases its effect object on end/cancel, whose
cleanup removes the layer; that lifetime must not be confused with evidence
that every source path visibly completes the configured 220 ms fade.

The [highlight container](/Users/psyche/tmp/projects/Telegram-iOS/submodules/TelegramUI/Components/GlassBackgroundComponent/Sources/GlassBackgroundComponent.swift:524)
is an ordinary noninteractive view with `clipsToBounds = true`.
`ClippingShapeContext` applies the surface's rounded-rectangle or four-corner
shape. **There is no edge-only highlight mask.** The narrow reflections visible
at a glass edge also depend on the optical material beneath this broad light.

The background lens is separate:
[LegacyGlassView.swift:198](/Users/psyche/tmp/projects/Telegram-iOS/submodules/TelegramUI/Components/GlassBackgroundComponent/Sources/LegacyGlassView.swift:198)
generates a mesh with 20-point displacement, edge distance `min(12, radius)`,
12 corner samples, 2-point outer edge, and displacement Bézier
`(.8161375661, .2050264550, .5806878307, .8730158730)`. It applies that mesh to
its backdrop layer, not to the touch light or action-selection capsule.

## Down → activation → held selection → release/cancel

1. [ContextControllerSourceNode / SourceView](/Users/psyche/tmp/projects/Telegram-iOS/submodules/Display/Source/ContextControllerSourceNode.swift:46)
   installs `ContextGesture` and exposes its activation to the caller. Its
   default activation-preview scale is a separate older shrink effect; callers
   can replace it through `customActivationProgress`. It should not be added on
   top of the glass lift.
2. [ContextGesture](/Users/psyche/tmp/projects/Telegram-iOS/submodules/Display/Source/ContextGesture.swift:74)
   checks `shouldBegin` and excludes the first 8 window points at the left edge.
   It defaults to a 120 ms delay followed by a 200 ms display-link activation
   progress. On completion while still possible, it invokes `activated`, cancels
   competing context/tap and ancestor gestures, then enters `.began`. Its
   delegate disallows simultaneous `UIPanGestureRecognizer` recognition, letting
   scrolling arbitrate before activation. The original recognizer remains the
   owner of the held touch.
3. [ContextControllerImpl](/Users/psyche/tmp/projects/Telegram-iOS/submodules/TelegramUI/Components/ContextControllerImpl/Sources/ContextControllerImpl.swift:270)
   assigns that same recognizer's `externalUpdated` and `externalEnded` closures.
   Coordinates are converted from the source view into the presentation. After
   entry animation completes, continuation selection starts after more than
   4 points of vertical motion from its first continuation point. The alternate
   tap-recognizer continuation branch uses 12 points. Disabled rows are excluded;
   changing highlighted rows produces haptic feedback. Merely releasing the
   long press without continuation movement does not immediately choose an item.
4. With extracted content, dispatch continues through
   `ContextSourceContainer.highlightGestureMoved` →
   `ContextControllerExtractedPresentationNode.highlightGestureMoved` →
   `ContextControllerActionsStackNodeImpl` → its top item container/list node.
   An ordinary end performs the current valid selection; cancellation must clear
   it without action. `ContextGesture.touchesCancelled` itself only fails and
   resets callbacks, whereas the menu's own selection recognizers explicitly
   dispatch a non-performing finish. The Flutter port therefore needs an
   explicit cancel/route-disposal path rather than relying on an up event.
5. An already open menu has its own
   [ItemSelectionRecognizer](/Users/psyche/tmp/projects/Telegram-iOS/submodules/TelegramUI/Components/ContextControllerImpl/Sources/ContextControllerActionsStackNode.swift:1405):
   down begins selection immediately, move changes it, end performs, cancel
   clears. Ineligible/custom items reject the gesture. Selection is disabled
   when content needs vertical scrolling. The horizontal navigation recognizer
   can coexist with selection but explicitly cancels it when a back swipe begins;
   it pops beyond fraction .2 and otherwise springs back over .45 s.

## One selection capsule, not individual rectangular pressed states

The modern list node owns a single
[highlightedItemBackgroundView](/Users/psyche/tmp/projects/Telegram-iOS/submodules/TelegramUI/Components/ContextControllerImpl/Sources/ContextControllerActionsStackNode.swift:1114).
Its horizontal inset is 10 points, its height follows the selected row, radius
is `min(20, rowHeight / 2)`, and monochromatic alpha is .1. A new selection moves
the shared view using 160 ms ease-in-out; first appearance avoids flying from an
unrelated origin and fades in over 200 ms. Finish clears it over 200 ms and
performs only when requested. This matches the Safari reference's traveling
rounded selection and cross-row movement; it is not a copy of Safari's private
physics. The older `ContextActionsContainerNode` uses a different per-row path,
so its rectangular highlighting is not the pattern chosen for this UI pilot.

## Port and validation boundary

Kelivo's shared `BrowserPress` now uses the above longer-side growth, drag
resistance, reciprocal stretch and separate lift springs. Its material receives
a clipped 300-point, peak-10% radial field with the configured light timing.
The widget retains the light for its fade instead of dropping it at release.
Extra touch-driven brightening of the native/Impeller material is disabled so
it does not stack another pressure effect over this shared light. The change
preserves held-pointer transfer, nested ownership, scroll cancellation,
accessibility, reduced motion and desktop controls without touch deformation.

The context-menu path uses one 320 ms long-press recognizer (120 ms delay plus
200 ms activation in the reference), with Flutter's gesture arena still
allowing a scroll to cancel it first. The callback transfers the original
pointer identifier; accessibility actions retain their separate semantic path.

The touch-effect checkpoint passed **17 `browser_glass_test.dart` tests**, including 48 × 48 circles,
240 × 48 capsules, cancellation/return, area-preserving directional deformation,
low-alpha radial pixels and clipping, held-pointer continuation through overlay
insertion, and desktop behavior. Scoped fatal-info analysis passed. These are
widget/pixel/gesture-contract checks. Subsequent native WKWebView and Android
texture-WebView integration checks exercised the shared interactions; they do
not establish physical-touch quality, device performance or pixel-identical
Safari behavior. The historical complete-app recording supports improved opening but contains
closing/collapse discontinuities. The later page/pane revision replaces direct
scroll-to-size mapping with a direction-triggered critically damped transition;
its visual acceptance is assigned to the user. See the
[validation history](browser.md#revised-ui-validation) for each checkpoint.

## Edge refraction and renderer boundary

The vendored Impeller renderer now exposes `GlassLensModel.edgeWarp`. The
browser selects it with blur 2 (clear surfaces 0) and zero chromatic aberration.
It precomputes the LegacyGlassView-style displacement in the existing geometry
pass: a band of `min(12, radius)`, 20-point displacement, the source cubic
curve, and an outer 2-point 1.5 gain. The interior is unchanged. Geometry is
cached independently of pressure and visibility; this introduces no webpage
snapshot loop or additional image-filter pass. The shader checks cover
sampling, DPR 1/2/3, small radii, zero visibility and geometry invalidation.

This shader runs over Flutter-composited content, including the Android
texture-backed WebView. It does not claim to run over iOS's WKWebView. Apple's
passive material bridge still samples that live native view through public
system materials. Telegram's `CABackdropLayer` and `CAMeshTransform` custom
path is private and is not copied into Kelivo. Shared controls, menu rows,
selection, light and gesture animations remain Flutter implementations.

## The local menu-morph implementation

The supplied Telegram checkout also includes
`prototypes/ContextMenuMorph`, `LiquidMorphTransition` and
`docs/context-menu-liquid-morph.md`. This is a custom implementation present in
the supplied checkout; it must not be presented as proof of the behavior of
every released Telegram build. Its menu geometry uses the source's same-side
edge, keeps the source hidden through the return transition, and allows closing
to take over an opening immediately. Its runtime morph delegates to a private
UIKit coordinator, despite using custom buttons and rows. Kelivo transfers the
lifecycle and interruption behavior to the shared Flutter menu, rather than
using that iOS-only coordinator.

## Equivalent capsule configuration and address continuity

During the mobile menu's capsule stage (`corners == 0`), the Flutter port now
passes radius `1000` instead of recomputing it from the current width. Each
renderer clamps the effective radius to half the shorter side, preserving the
circle/ellipse/capsule outline while allowing the native capsule configuration
to remain cached. The final corner transition into the panel is unchanged.
An actual-shader regression compares the two radius inputs byte-for-byte over
18 combinations: three sizes, DPR 1/2/3 and two supported shape types. All
match. This establishes the tested geometry equivalence, not a measured
native-performance improvement or pixel identity with Apple's glass.

Existing no-op menu-layout guards and geometry-matte reuse remain in place;
effective DPR changes still invalidate geometry. Those guards preceded the
latest before/after probe. Its **only product variable** was the capsule-stage
radius configuration, so other cache changes must not be credited to that pair.

A separate address-bar correction caps the collapsed target width at the
expanded width, including long domains and enlarged text. The label uses
`w500` throughout, interpolating size from 16 to 13, while the material remains
regular instead of switching at the collapse endpoint. This removes discrete
configuration changes without changing the scroll target or remounting the
address surface/WebView. Three page regressions cover long domains, 3× text
and both directions across the endpoint threshold.

The capsule/address checkpoint passed **235 focused tests**, superseding the earlier
231-test checkpoint and including those three page regressions plus the actual
shader capsule-equivalence check. Fatal-info analysis passed for `lib`, `test`
and both browser integration entries. Separate scoped runs passed **35
menu/shader tests** and **41 page/surface-control tests**; these sets overlap
and are not additive totals. The full repository test suite was not rerun.
Its complete-app recording retained an abrupt first opening and toolbar steps.
The readiness revision and newer recording below supersede that checkpoint;
the older approximately 247ms closing sequence is not evidence that every
newer close is smooth.

## Material readiness and current observation

The Flutter menu now prepares its source-sized material transparently while
leaving More visible. `BrowserGlass.onReady` means shader preparation, or native
view creation plus queued parameter synchronization, and a framework frame
containing the host have completed. **It is not a GPU-presentation callback.**
The animation starts afterward, outside build, and takes over the source at
that point. Closing before readiness, replacing the overlay and removing the
host cancel pending starts. The held pointer is captured synchronously, so
up/cancel before mounting or readiness is retained rather than leaving a stuck
selection. Solid now uses an ordinary Flutter surface on all platforms, without
a native material view or backdrop; native liquid/frosted remain passive.
The retained-controls revision offstages Back/More only at fully collapsed
progress (`t >= .995`) to preserve their State. The address is never offstaged,
and More's 48 × 48 resting anchor is outside that subtree. A zero-opacity source
remains in the native hierarchy while a menu owns its pointer.

The latest retained-controls run passed **246 focused tests**, and fatal-info analysis
passed for `lib`, `test` and the two browser integration entries. The full
repository suite was not rerun. Its 37-test page run is included in that total.
The logs are `/tmp/browser-telegram-retained-final-focused.log`,
`/tmp/browser-telegram-retained-final-analyze.log` and
`/tmp/browser-telegram-retained-ios-page-tests.log`. Final retained builds passed
for iOS Simulator debug, Android arm64 profile (85.2 MB APK) and macOS profile
(235.1 MB). The iOS simulator app was installed in place and is the version
used for the actual long-press recheck; Android `adb install -r` reported
`Success`. All retained final build/install commands completed successfully.

An intermediate menu-period Offstage optimization caused actual OS-held
long presses to cancel: two CUA 700ms attempts opened then automatically closed
the menu while tap-open stayed visible. **That change was rolled back.** The
earlier widget and native-renderer integration tests injected Flutter pointers
and did not cover this operating-system cancellation. After rollback, actual
CUA 700ms long press remained open and open-menu row-to-Bookmarks drag selection
succeeded. The [open-state screenshot](../build/browser_validation/telegram-ios-retained-longpress.png)
records that recovery; it is not a frame-rate or physical-device acceptance.

The preceding readiness checkpoint passed 245 focused tests. Both iOS and Android readiness integration
reports passed scroll/update/end and held-menu ownership/action checks:
`telegram-ios-ready-integration.json` and
`telegram-android-ready-integration.json` in `build/browser_validation/`.
At that checkpoint, complete-app builds passed for iOS Simulator debug, Android arm64 profile
and macOS profile. The simulator app and APK were installed in place with data
preserved, and the latest macOS profile app was launched; build/install logs are
under `/tmp/browser-telegram-ready-final-*`. Build and test success does not
establish animation frame rate or remove the visual limits below.

That macOS profile app also received actual CUA keyboard checks with a
native webpage input focused. Cmd-F opened the floating find panel and repeated
Cmd-F preserved/focused the same query; Cmd-L focused the address, Cmd-T created
one test tab, Cmd-W closed that tab without closing the window, and Cmd-R
reloaded the local page. `BrowserWindowChrome` scopes a native key-event bridge
to the active browser route, consumes the original Command event to avoid
double dispatch, and rechecks route ownership for queued callbacks. The
[find-panel screenshot](../build/browser_validation/telegram-macos-shortcut-find.png)
supports the runtime record. This is a keyboard interaction result, not an
optical or frame-rate acceptance result.

The [new complete-app recording](../build/browser_validation/telegram-ios-ready.mov)
uses matched 700ms long presses for the first and repeat opening in one app
instance. Both now show a circle, growing blurred ellipses and a sharp panel;
neither shows bare or duplicated ellipses. A blank-circle frame still appears
at 22.126667s on first opening, with the glyph returning at 22.161667s.
The second outside close changes from nearly full panel to small lens between
105.536667 and 105.545s. Opening improvement is observed; overall visual and
performance acceptance is **not achieved**.

Its fixture scrolling requests ±100 CSS pixels smoothly; the predecessor used
±480, preserved in `site/scroll-fast-reference.html`. Product scroll travel and
curve did not change. A collapse image step of about 348 → 140px remains at
141.350 → 141.353333s, in 600px-wide decoded frames. This is not physical input,
a matched scroll-performance before/after, or evidence of a particular thread
stall. The [PTS review](../build/browser_validation/telegram_ready_audit/review.md)
and [8.15s normal-speed excerpt](../build/browser_validation/telegram-ios-ready-edited-normal-speed.mov)
retain both improvements and unresolved observations.

The subsequent [diagnostic scroll audit](../build/browser_validation/telegram_offstage_diagnostic_audit/review.md)
records the retained collapse path under the same ±100px fixture input:
348 → 140px at 347.755 → 347.758333s and 215 → 378px during expansion at
379.310 → 379.325s, again in 600px-wide decoded images. Its menu-period
Offstage code was withdrawn and is not a delivered menu implementation.
The readiness close discontinuity and these scroll steps remain unresolved;
overall visual/performance acceptance is **not achieved**.

## Complete material probe and remaining limits

The archived matched before/after captures use the iOS 26.5 debug simulator, one warm-up
and three measured rounds per material, with separate traces for opening,
closing, collapse and expand. Both have **36/36 complete phase boundaries** and
identical protocol fields. The earlier interrupted/partial captures are not
used as menu baselines. SDK FrameTiming summaries span each whole round and
drain; phase-specific native submit/wait/layout/Animator metrics come from the
timeline. Nested durations are never added together. Both captures predate
readiness and used a native material carrier for Apple solid; the new Flutter
solid path was not measured by that pair.

Liquid menu-open wait max fell from 47.033 to 13.181 ms in this pair, but the
after capture still records 44.144 ms in frosted menu-open, 35.597 ms in solid
menu-close and 28.713 ms in liquid expand. The largest after root layout is
17.088 ms, including an 11.472 ms BUILD with 3.045 ms old-generation GC;
the largest Animator interval is 23.971 ms. There is no Compiler stream in
these captures, so residual time cannot be called JIT. The observations do
not establish a consistent improvement or the cause of native scheduling
stalls. Three rounds are a small sample, and this warm fixture cannot serve
as a before/after for older full-app recordings or as physical-device evidence.
The [complete comparison](../build/browser_validation/complete-before-after-comparison.md)
retains phase maxima, P90, counts and exact outlier windows. The simulator-data
loss from earlier validation remains documented in
[the validation incident](browser.md#telegram-derived-interaction-revision);
these later successful runs did not restore that data.
