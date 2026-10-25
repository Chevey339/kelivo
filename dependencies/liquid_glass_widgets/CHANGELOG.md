# 1.12.0

## Features

- **Opt-in scroll edge pointer absorption (PR #413):** `GlassScrollEdgeEffect` and `GlassScaffold` can absorb touches in their fade zones when `absorbPointer` (`edgeFadeAbsorbsPointers` on `GlassScaffold`) is enabled; defaults to `false`.

  Thanks to [@yohom](https://github.com/yohom) for the contribution (#413).

## Bug Fixes

- **Anti-aliased premium pill and curved silhouettes (PR #415):** Fixed stair-stepping artifacts on curved glass silhouettes (notably `GlassTabBar`'s indicator pill during drags) by extending the geometry matte's coverage fade to full transparency and filtering transformed mattes bilinearly.

  Thanks to [@gbahry](https://github.com/gbahry) for the fix (#415).

## Performance

- **Morph spring early settle & frame savings (PR #417):** `GlassMorphController` now uses an optimized settling tolerance so springs complete once motion is visually imperceptible. Eliminates trailing rebuild and repaint ticks across `GlassMenu`, `GlassPopover`, and modal sheets, reducing frame draw overhead by ~30%.

  Thanks to [@Ahmadre](https://github.com/Ahmadre) for the contribution (#417).

# 1.11.1

## Bug Fixes

- **`GlassBackdropGroup` dropped `backerColor` on members after the first (fixes #412):** Surfaces with a visible `backerColor` now take an isolated backdrop read so their dimming pad is preserved, while members without a backer continue sharing the group's backdrop read.

- **Engine lifecycle hardening (PR #410):** Fragment shaders are no longer reloaded on every rebuild. Blend groups release their group link on dispose and follow `renderLink` changes when reparented. Removing a glass shape from a layer repaints its matte, so no ghost of it remains. Duplicate shape registrations on detached render objects are prevented, and the native picture recorded for an asynchronous geometry cache is released as soon as it is rendered.

- **Fragment shaders are now disposed:** `MultiShaderBuilder` disposes the shaders it creates when it unmounts, and the ones it replaces when its keys change (after the frame that last used them), instead of leaving them to the garbage collector.

# 1.11.0

## Features

- **Layered `GlassMenu` submenus (PR #386):** `GlassMenuItem.submenu` opens a native iOS-style card over its parent. The parent recedes to 0.971× and dims its rows to 50%; the full-width card's bold header repeats the source row's icon and title with a downward chevron and sits on that row. Selecting the header, or tapping or gliding onto the exposed parent, collapses one level. Submenus nest, only the top card is interactive or exposed to semantics, and Reduce Motion makes transitions instant. The card's rows arrive with its material while the parent rows it covers cross-fade away, and closing reverses this; the fade drives the glass visibility channel, so the card keeps blurring its backdrop. `GlassMenu.onLevelChanged` reports the depth and the whole stack's extent so an owner can make room for a card that overhangs the parent, and `GlassMenu.maxStackHeight` constrains the stack, scrolling a card that would not otherwise fit. `GlassMenuController.submenuDepth` reports the current depth.

  Thanks to [@F1orian](https://github.com/F1orian) for the contribution (#386).

- **`stripRowTop` on `GlassPinnedBarChrome` and `GlassNavBarRegistration` (fixes #398, PR #399):** In iPhone Duo's vertical bar strip, the items that stay horizontal were always pinned in the row `GlassAppBar` draws its title in, so beside a bespoke header lower down they sat a row above it. `stripRowTop` puts that row where the bar's own header is.

  Thanks to [@JakeThomson](https://github.com/JakeThomson) for the contribution (#399).

- **`GlassVerticalBar.disabled` keeps a subtree's bars horizontal (fixes #400, PR #401):** In a list/detail split on iPhone Duo the strip belongs to the column against it, as with `UISplitViewController`, and the other column keeps horizontal bars. Wrap that column in `GlassVerticalBar.disabled`. A pinned bar inside it draws its chrome in-route rather than handing it to the shell, which would pin it against the window, in the strip.

  Thanks to [@JakeThomson](https://github.com/JakeThomson) for the contribution (#401).

- **`GlassModalSheet.restingWidthOf` (fixes #402, PR #403):** The width a sheet rests at, for content measured before the sheet is presented. In iPhone Duo's vertical bar strip layout a window 800pt wide or more lays every detent out as a card the display's shorter side wide, so content measured at the screen's width less the margins gained a wrapped row the sheet's height did not allow for.

  Thanks to [@JakeThomson](https://github.com/JakeThomson) for the contribution (#403).

- **The vertical `GlassTabBar` shows its labels under a finger (fixes #406, PR #407):** In iPhone Duo's vertical bar strip the tab bar is icons only, as natively, so its tabs had no visible names. Touching it now behaves as UIKit's does: the capsule swells, then after a short hold grows into a labelled form with each label beneath its icon, and the indicator lifts into a lens that follows the finger and selects the tab under it on release. A drag shows the labels at once. `GlassTabBar.indicatorSettings` now reaches the vertical bar's lens.

  Thanks to [@JakeThomson](https://github.com/JakeThomson) for the contribution (#407).

## Bug Fixes

- **`GlassTabBar.searchable` in iPhone Duo's vertical bar strip (fixes #392, PR #393):** With `GlassSearchBarConfig.showPill` false the strip still ended the capsule with a search slot; it now leaves search out, as a native `TabView` without its search tab does. `GlassTabBar.searchable` and `GlassTabBar.minimizable` also take `passthroughOverPlatformView`, which only the internal layout accepted, so a bar over a map no longer has to drive that layout directly, which kept it horizontal in the strip.

  Thanks to [@JakeThomson](https://github.com/JakeThomson) for the fix (#393).

- **Vertical `GlassTabBar` asserted outside a `GlassScaffold` (fixes #394, PR #395):** In iPhone Duo's vertical bar strip, the tab bar's capsule, search field and ✕ relied on the `GlassScaffold` around them for a glass layer, so at `GlassQuality.premium` a bar placed any other way failed the `renderLink != null` assertion. Each now brings its own layer, as the horizontal bar does; under a `GlassScaffold` nothing changes.

  Thanks to [@JakeThomson](https://github.com/JakeThomson) for the fix (#395).

- **`GlassPinnedBarChrome` builder can now tell the package draws the strip (fixes #396, PR #397):** On iPhone Duo, a `GlassPinnedBarChrome` the shell has not hoisted, such as one in a nested navigator, draws the vertical bar strip itself, but `builder` still got `hoisted: false`, so a bar drawing its own capsules from it showed the back button and actions twice. The new `GlassPinnedBarChromeData.inStrip` is true whenever the chrome is laid out for the strip, which the package draws whatever `hoisted` says.

  Thanks to [@JakeThomson](https://github.com/JakeThomson) for the fix (#397).

- **iPhone Duo's vertical bar strip now follows the status cluster (fixes #404, PR #405):** The strip's first control sat at a height measured on the 27.1 simulator, so on a device, where the cluster grows with live activities and goes with the status bar, the controls no longer lined up with it. The strip's ends now come from the regions UIKit reserves for the cluster and the camera, `UIView.reservedRegions(kind: .occlusion)`, read by a small iOS plugin and updated as they change. `GlassVerticalBar.resolve` takes them as cutout `displayFeatures`, which is where Flutter will report them once it does on iOS (flutter/flutter#193025).

  Thanks to [@JakeThomson](https://github.com/JakeThomson) for the fix (#405).

- **iPhone Duo's vertical bar strip in Split View (fixes #408, PR #409):** The strip was only found where the top inset was zero and one side was inset, so in Split View the app fell back to horizontal bars. The left-hand app gets no inset for its strip at all, only `UITraitCollection.verticalBarEdge`, which the iOS plugin now reports; the shell keeps an 84pt strip on that edge and insets the content for it. Below a status bar along the top, the strip and the title row start beneath it.

  Thanks to [@JakeThomson](https://github.com/JakeThomson) for the fix (#409).

- **Submenu card touch glow was opaque white:** A layered submenu card defaulted its interaction glow to fully opaque white, so the highlight under a finger blew out the card's rows. It now uses the same theme-aware specular colour as the root menu (white at `GlassDefaults.specularLightAlpha` in dark mode, black at `GlassDefaults.specularDarkAlpha` in light mode). An explicit `GlassMenu.glowColor` still wins.

- **`GlassPullDownButton` dropped item properties when `onSelected` was set:** Wrapping each `GlassMenuItem` to report the selection rebuilt it with only a few fields, so `submenu`, `height`, `titleStyle`, `subtitleStyle`, `iconColor`, `iconSize`, `maxLines`, `enablePressScale`, `closeDelay`, `isPressed` and `isSelected` were lost. A submenu row in a pull-down button showed no chevron and opened nothing. All properties are now forwarded.

# 1.10.0

## Features

- **`GlassBarItem.spacer()` multi-capsule rendering (#245, PR #390):** A spacer now splits a pinned bar's run of shared items into separate capsules, as `ToolbarSpacer(.fixed)` does natively, where it used to assert. Across a transition each capsule follows its items, matched by `id` and otherwise by position, rather than one capsule morphing into another. A capsule the destination adds beside one buds out of it through a liquid bridge, as on iOS 27, and one it drops merges back in.

  Thanks to [@JakeThomson](https://github.com/JakeThomson) for the contribution (#390).

- **External slide-to-select on `GlassMenu` (discussion #369, PR #384):** Added `glideTo(Offset)`, `endGlide()`, and `cancelGlide()` to `GlassMenuController`. Enables external gesture recognizers (such as a long-press on an outer card) to drive menu item highlighting, selection haptics, and activation without needing direct touch ownership.

  Thanks to [@F1orian](https://github.com/F1orian) for the contribution (#384).

- **Dynamic sheet appearance with `expandedDarkColor` (PR #385):** Added optional `expandedDarkColor` parameter to `GlassModalSheet` and `GlassModalSheet.show` so presented full-height sheets and morph droplets dynamically follow system light/dark appearance switches while open.

  Thanks to [@DFelten](https://github.com/DFelten) for the contribution (#385).

- **Accessibility semantic label overrides (PR #387):** Added optional `semanticLabel` parameters across `GlassPicker`, `GlassMenu`, `GlassPopover`, `GlassTextField`, `GlassChip`, `GlassPasswordField`, `GlassSearchBar`, and `GlassSearchBarConfig` to allow custom screen reader announcements.

  Thanks to [@Ahmadre](https://github.com/Ahmadre) for the contribution (#387).

## Bug Fixes

- **Tinted `GlassBarItem` dropped the bar's `buttonSettings` (fixes #372, PR #389):** A `GlassBarItem` with a `tintColor` built its capsule's settings from scratch, so under `LiquidGlassSettings.ios27Light` it lost the outline, rim light and shadow the untinted capsules beside it kept. The tint now replaces only the body colour of the bar's button settings, hoisted and in-route.

  Thanks to [@JakeThomson](https://github.com/JakeThomson) for the fix (#389).

- **`LiquidGlassSettings.ios27Dark` over bright backdrops (fixes #373, PR #388):** From mid-grey up, `ios27Dark` lifted the backdrop and drew a light rim where the native dark material darkens it and keeps a dark outline, and over a white page it stayed white where native greys to about 184. The new `bodyShade` term pulls a bright backdrop down by its luminance squared, outline included; `ios27Dark` sets it to `0.28` and raises `rimShade` to `1`.

  Thanks to [@JakeThomson](https://github.com/JakeThomson) for the fix (#388).

- **Screen reader, dynamic type, and Reduce Motion pass (PR #387):** Exposed missing button semantics and dismiss actions on menu/popover barriers and plain triggers; prevented chip delete buttons from merging into name text; allowed `GlassPicker` to grow with large system fonts; and honored Reduce Motion across toasts, page controls, and searchable tabs.

  Thanks to [@Ahmadre](https://github.com/Ahmadre) for the contribution (#387).

- **Controlled `GlassSwitch` state synchronization (PR #383):** Fixed visual state desynchronization when `widget.value` is unchanged or rejected by the parent. Reconciles the position controller to authoritative `widget.value` after gestures and settles thickness bloom correctly.

  Thanks to [@sbezhuk](https://github.com/sbezhuk) for the fix (#383).

- **One screen-reader node per control (issue #381):** Every interactive control now surfaces as a single semantics node carrying its label, role, state, tap and focus. Previously `GlassFocusRegion` split its focus semantics into a second node — unlabelled on switches, icon buttons, tabs, steppers and button groups (an extra TalkBack stop), and a repeat of the visible text on segments, chips and menu rows (read twice by VoiceOver). The drag detectors on `GlassSegmentedControl` and `GlassSwitch`, and the inner detector on `GlassListTile`, no longer add unlabelled scroll/tap nodes either.
  - An explicit label (`GlassButton.label`, `GlassSegment.semanticLabel`, `GlassMenuItem.title`, …) now replaces the control's visible text instead of being announced alongside it, as `GlassButton.label` documents.
  - `GlassMenuItem.subtitle` is announced as the row's value; `GlassListTile.onLongPress` is reachable by screen readers.
  - `GlassChip`'s delete button defaults to "Remove ‹label›" instead of being unnamed.
  - `canRequestFocus: false` is now honoured; it was silently overridden, so such controls still took keyboard focus.

  Thanks to [@cosmeao](https://github.com/cosmeao) for the detailed report and reproduction (#381).

# 1.9.0

## Features

- **Vertical bars on iPhone Duo (#348, PR #365):** Under a `GlassNavigationShell`, the pinned chrome, `GlassTabBar.bottom` and `GlassToolbar` now move into the 84pt strip iOS 27.1 reserves on the outer display and on the inner display in landscape, laid out to the native strip's measured geometry. The title stays in a row at the top of the content, and `GlassBarItem.axisBehavior` decides which items go vertical. Where the strip runs short, the chrome overflows into a ••• menu and the tab bar collapses to its selected tab. The strip is read from `MediaQuery.viewPadding` and published as `GlassVerticalBar`; `GlassNavigationShell.verticalBarBehavior` and `verticalBarCompression` mirror UIKit's `preferredVerticalBarBehavior` and `verticalBarCompressionBehavior`. Nothing changes on any other device.

  ```dart
  GlassNavigationShell(
    verticalBarBehavior: GlassVerticalBarBehavior.automatic,
    verticalBarCompression: GlassVerticalBarCompression.automatic,
    child: child!,
  )
  ```

  Thanks to [@JakeThomson](https://github.com/JakeThomson) for the contribution (#365).

- **Plain cross-fade for pinned chrome after committed back-swipe (PR #360):** Added `swipeCommitTransition` to `GlassNavigationShell` (`GlassSwipeCommitTransition.crossFade` vs `GlassSwipeCommitTransition.effect`) to perform a plain cross-fade without capsule swell, scale, or blur after an interactive back-swipe commits.

  Thanks to [@DFelten](https://github.com/DFelten) for the contribution (#360).

- **Search and large titles in iPhone Duo's strip (#366, PR #370):** `GlassTabBar.searchable` now joins the strip's capsule with search as its last slot, and opens its field in the row at the top of the content. A `GlassLargeTitle` moves into that row at 28pt, drawn by the `GlassAppBar.pinned` sharing its controller, and scrolls away with the content; its `searchBar` becomes a magnifier at the bottom of the strip, which opens the field along the bottom of the content and hides the bar, as `searchable` does natively. The row's insets are physical, as natively, so in a right-to-left app the title ends against the strip.

  Thanks to [@JakeThomson](https://github.com/JakeThomson) for the contribution (#370).

- **Sheets, popovers and Reduce Transparency in iPhone Duo's strip (#367, PR #371):** A `GlassModalSheet` now takes the strip's place where it covers it, as natively: on the outer display its `GlassAppBar.pinned` stacks down a strip of its own, and the sheet rises to 8pt from the top with its margins kept. On the inner display it is a 653pt card with a horizontal bar, placed by the new `placement` (`GlassSheetPlacement`, mirroring `presentationPlacement(_:)`); `.trailing` docks it over the strip and moves its bar into it. A `GlassMenu` or `GlassPopover` opened from the strip opens towards the content, centred on its item. Under Reduce Transparency the strip and the title row turn opaque behind a hairline. A pinned bar inside a presented route no longer registers with the shell, since the presentation is its container.

  Thanks to [@JakeThomson](https://github.com/JakeThomson) for the contribution (#371).

- **`GlassAdaptiveScope.frostStep`** (also on `GlassAdaptiveScopeConfig`): opt-in step through
  premium without frost. The first step down from premium only switches the frost off,
  standing a regular blur in for it, and keeps the premium lens, rim and highlight; the next
  step goes to standard, and recovery takes the same steps back. `GlassAdaptiveScopeData`
  gains `frostEnabled`. Default off.

## Performance

- **`GlassBackdropGroup` (#357):** On Impeller every `BackdropFilter` copies the whole
  screen, and premium glass uses two or three per surface. Glass inside a group shares one
  backdrop read for its blur and frost; refraction stays per surface. Same idea as SwiftUI's
  `GlassEffectContainer`. Glass under an opacity, shader mask, save-layer clip or inside
  another glass surface stays out on its own. Wrap a screen's bars rather than a `Navigator`.
  No effect on web or Skia.
- **`GlassTabBar` and `GlassAppBar` group their glass by default:** new `groupBackdrop`
  (default `true`; set `false` to opt out). Inside your own `GlassBackdropGroup` the bars join
  it. Glass that overlaps the bar (selected-tab indicator, search pill while the keyboard is
  up, extra button, bottom accessory) stays out. iPhone Air, `ios27Light`, opening a sheet:
  23.6 → 9.3 ms average GPU time per frame. No visible change.
- **Cheaper iOS 27 material on premium:** The shader skips frost and light work that has no
  visible effect, and the frost's ghost takes 6 taps instead of 45 at the floor sigma
  (`ios27Light`, `blur: 0`, glass cards: 59.7 → 50.0 ms GPU).
- **Less work for moving and resting glass:** Frost rows are shifted instead of rebuilt, the
  geometry matte is kept when glass moves as a whole, and the light-mode shadow is baked into
  an image once the shape holds still.
- **Benchmark:** `example/integration_test/perf_glass_test.dart` measures raster and GPU frame
  times on a device in profile mode.

  Thanks to [@Ahmadre](https://github.com/Ahmadre) for the contribution (#357, PR #359), and
  to [@JakeThomson](https://github.com/JakeThomson) for the review.

## Bug Fixes

- **`GlassMenu` slide-to-select released between two rows (PR #375):** Releasing over the 2px gap between two rows activated nothing and left the menu open. Each row's hit zone now includes half of the gap on either side, so a release there activates the nearer row.

  Thanks to [@F1orian](https://github.com/F1orian) for the fix (#375).

- **`GlassMenu` keyboard and screen-reader activation (PR #376):** On menus that don't scroll, pressing Enter or Space on a focused row, or activating it with VoiceOver or TalkBack, did nothing; only touch worked. These now activate the row, and a touch tap still activates it exactly once.

  Thanks to [@F1orian](https://github.com/F1orian) for the fix (#376).

- **`GlassMenu` pointer events after unmount (fixes #363, PR #364):** Ignore events from active menu and continuous-swipe pointers after disposal, preventing unmounted context and disposed notifier errors when a route is removed during a gesture.

  Thanks to [@yairsts](https://github.com/yairsts) for the fix (#364).

- **In-route bar items slot size (PR #362):** Size in-route bar items in `GlassPinnedBarChrome` to match the pinned cluster's slot geometry even with custom icon sizes.

  Thanks to [@DFelten](https://github.com/DFelten) for the fix (#362).

- **Pinned chrome icons blur on pop to a route with no pinned bar (follow-up to #351):** When popping from a route with a pinned capsule to a route with no pinned bar, item icons no longer blur out on the first frame while the glass capsule stays visible. Items now dissolve together with the capsule glass, matching native iOS behaviour.

- **`GlassPinnedBarChrome` action items order in RTL (fixes #374):** Keep action items in consistent visual order when a modal sheet triggers hand-over under RTL layout.

- **iOS 27 presets on the standard path and web (visible change):** `ios27Light` and
  `ios27Dark` came out flat and nearly clear on standard and on web, since the lightweight
  shader draws neither the frost nor the rim light. They now get a regular blur in place of
  the frost and the highlight in place of the rim light.
- **`LiquidGlassWidgets.wrap()` passes the warm-up thresholds on:** `warmupPremiumThresholdMs`
  and `warmupStandardThresholdMs` from `GlassAdaptiveScopeConfig` never reached the scope, and
  the config's `==` and `hashCode` ignored them.
- **Docs:** The adaptive scope degrades after 2 windows (not 3) and caps explicit `quality:`
  parameters too; `docs/ARCHITECTURE.md` no longer claims resting premium glass skips live
  backdrop passes.

# 1.8.1

## Bug Fixes

- **`GlassScrollEdgeEffect` stale texture on theme switch (fixes #352):** Recaptures the background when brightness or `fadeColor` changes; stale in-flight captures are discarded via a generation counter.
- **Pinned navigation chrome `buttonSettings` and inset on pop (fixes #351):** `buttonSettings` and `horizontalInset` now adopt the destination route's values from the first frame of a pop transition, rather than snapping at completion.
- **`GlassButton` / `GlassIconButton` isolated semantics node (fixes #354):** The button label, role, and tap action now land on a single isolated semantics node. Previously they merged into an ancestor boundary or split across two nodes.
- **Glow layout crash during route transitions (fixes #355):** Eliminates `StateError: RenderBox was not laid out` crashes that occurred when a glow animation updated in the same frame a route transition wrapper (e.g. `SlideTransition`) was inserted above the route.
- **Interactive widget `CurvedAnimation` and `ValueNotifier` disposal (fixes #356):** All interactive and overlay widgets now correctly dispose their `CurvedAnimation` instances and `ValueNotifier`s on unmount, preventing listener leaks and `leak_tracker` failures in widget tests.

# 1.8.0

## Features

- **iOS 27 material for `GlassQuality.premium`:** New `LiquidGlassSettings` terms, each
  measured against a SwiftUI `glassEffect(.regular)` control on the same screen: `frost`,
  `frostOpacity`, `frostClamp` and `frostWeight` for the cloud that a copy of the content
  still shows through (`blurWeight` shapes that copy), `rimShade` and `rimShadeEnds` for the
  half-point outline, `rimLight` for its highlight lobes, and `GlassLensModel.paraxial` for
  the evenly folded rim band. `LiquidGlassSettings.ios27Light` and `ios27Dark` put them
  together, and `GlassThemeSettings` carries each term so a theme can apply them app-wide.
  All default to off, and existing settings render exactly as before. The frost
  costs one blur pass, written to alternate pixel rows of the shape, plus a colour pass when
  `frostWeight` is not 1.

  Thanks to [@JakeThomson](https://github.com/JakeThomson) for the contribution (#347).

- **`GlassMenuItem.closeDelay`:** New optional `Duration` that defers menu dismissal after `onTap` fires. Useful when the item hosts an animated `trailing` widget (e.g. `GlassSwitch`) so its animation completes before the menu morphs away. Defaults to `null` (synchronous close — backward compatible).
- **Apple Mail iOS 26/27 showcase demo:** Added an Apple Mail showcase in `example/lib/apple_mail/` featuring pinned bar navigation with gel-morph across mailbox, inbox, and detail screens, living liquid morph compose sheet via `GlassMorphTrigger` and `GlassModalSheet`, floating triage bar with `GlassButtonGroup`, options popover with `GlassMenu`, and full Cupertino styling. Includes a `GlassSwitch` row (with `closeDelay: 650 ms`) in the Inbox `···` menu to toggle between iOS 26 and iOS 27 glass modes, with state persisted globally across the full navigation stack via `kMailUseIos27` and `MailGlassScope`.
- **Liquid droplet morph return and metaball fusion for `GlassMenu` and `GlassPopover`:** Implements centroid flight trajectory on close for `GlassMenu` and `GlassPopover`, unpinning the returning shape from the trigger corner to fly directly toward the trigger anchor center. Adds an ease-in droplet contraction curve and early `anchorScale` ramp-in to enable authentic SDF metaball bridging, morphs border radius directly to capsule/droplet shape on close, rapidly flushes menu items over the first 15% of close to maintain a pure liquid droplet in flight, and resolves narrow constraint layout in `GlassMenuItem`.

## Bug Fixes

- **Graceful quality tier routing for standard and minimal overlay close:** Standard and minimal tiers in `GlassMenu` and `GlassPopover` cleanly route through simplified fade and scale fallbacks on close rather than attempting premium shader metaball blending.
- **`GlassModalSheet` submerged offset tracking via `SheetStateInfo.submergedBottom`:** Exposes `submergedBottom` on `SheetStateInfo` via `GlassModalSheetStateProvider` so sheet descendants can accurately compensate for the submerged depth of `GlassModalSheet` in `GlassSheetState.full` when positioning keyboard toolbars, floating action bars, or scroll view insets above the software keyboard and safe area floor.
- **Scoped backdrop pass rect resolution for nested glass and layer coordinators:** Differentiates descendants painted inside a glass shape's `BackdropFilterLayer` (such as `GlassButton` inside `GlassModalSheet`) from children painted outside the pass via `super.paint` (such as `AnimatedGlassIndicator` inside `AdaptiveLiquidGlassLayer` / `GlassTabBar.bottom`). Retains `backdropPassClipRectLocal` across frames for isolated descendant repaints (preventing buttons in modal sheets from disappearing when clicked or animated), while ensuring peer children of layer coordinators correctly resolve against root screen coordinates.
- **Nested `AdaptiveGlass` honors `useOwnLayer`:** Ensures nested glass controls explicitly marked with `useOwnLayer: true` preserve their own refractive shader layer and specular highlights rather than collapsing into an ancestor's 2D vibrancy backer.
- **`GlassNavPinnedHost` trailing action groups align to the trailing edge:** Pairs action groups from the anchored trailing edge when `anchoredAtStart` is false instead of raw index 0. When navigating between routes with differing numbers of trailing groups, the rightmost buttons now correctly morph into each other in place on the trailing edge while remaining groups cleanly materialize or dematerialize without unexpected layout shifting.
- **`GlassGlow` touch specular coordinates in nested layers:** Corrects screen-to-pass coordinate translation in `_TouchSpecularBridge` so touch specular highlights track accurately within nested backdrop passes.

# 1.7.2

## Bug Fixes

- **`GlassTabBar` no longer exposes an unlabelled bar-wide semantics node (fixes #340, PR #343):** The drag and tap detector that spans the full bar is now excluded from semantics across both `GlassTabBar.bottom` and `GlassTabBar.searchable`, leaving the labelled per-tab controls as the only announced actions.

  Thanks to [@DeepanshuPal](https://github.com/DeepanshuPal) for the fix (#343).

- **`GlassTabBar` default indicator follows app brightness (fixes #341, PR #344):** The selected pill now resolves its default black/white tint through `GlassTheme.brightnessOf(context)` across both `GlassTabBar.bottom` and `GlassTabBar.searchable` instead of the device appearance, so app-level light and dark overrides remain visible.

  Thanks to [@DeepanshuPal](https://github.com/DeepanshuPal) for the fix (#344).

- **iOS Reduce Motion is now respected (fixes #342, PR #345):** Accessibility motion handling now combines Flutter's `disableAnimations` flag with iOS's separate `reduceMotion` platform feature, including popover, menu, and modal-sheet morph controllers.

  Thanks to [@DeepanshuPal](https://github.com/DeepanshuPal) for the fix (#345).

# 1.7.1

## Bug Fixes

- **Prevent infinite `borderRadius` from collapsing clipping and shadows (#339):** Guards against `double.infinity` evaluating to `0.0` in Flutter's corner-scaling formula across clipping layers, drop shadows, and shader uniforms. Centralizes safe radius handling on `GlassDefaults` and `LiquidShape`.

  Thanks to [@iimrudy](https://github.com/iimrudy) for the fix (#339).

- **`GlassTabBar.searchable` RTL support (fixes #338):** Fixes miscalculated indicator positioning, drag hit-testing, and tab selection under `TextDirection.rtl`.

# 1.7.0

## Features

- **Continuous swipe-to-select for `GlassMenu` and `GlassPullDownButton` (#331):** Adds native iOS-style continuous press-and-slide interaction. Users can press and hold the trigger, slide directly onto an item, and release to select in a single fluid motion without requiring a second tap.
  - Enabled by default on `GlassPullDownButton` (`enableContinuousSwipe: true`), opt-in on `GlassMenu`.
  - Configurable `continuousSwipeSlop` (defaults to 10 logical px) to distinguish quick taps from deliberate swipes without latency.
  - Pointer-ID isolation for multi-touch safety, haptic feedback on item boundary crossings, optional glow tracking, and automatic deactivation on scrollable menus.

## Performance

- **Geometry matte pixel budget while a premium surface animates (#330):** `GlassQuality.premium`
  surfaces that resize (e.g. a `GlassModalSheet` opening) now rasterize their geometry matte at a
  capped 1 MP budget during animation, settling at full resolution once the shape comes to rest.
  Reduces animation memory peaks from 400–800 MB to ~340–394 MB on iPhone 17 Pro Max at 120 Hz.

  Thanks to [@JakeThomson](https://github.com/JakeThomson) for the contribution (#330).

## Bug Fixes

- **Async sheet presenters no longer lose their hoisted capsule (#335, fixes #334):** A
  `GlassBarItem.sheet` presenter that does async work before calling `GlassModalSheet.show`
  (e.g. measuring content offscreen, awaiting a fetch) could lose the shell's hold, reverting to
  the pre-#325 symptom. `GlassBarItem.sheet` no longer requires a synchronous present.

  Thanks to [@JakeThomson](https://github.com/JakeThomson) for the fix (#335).

- **`GlassTabBar.searchable`: `textColor` is no longer overridden by `hintStyle`'s colour (#336):**
  When both `GlassSearchBarConfig.textColor` and a colour on `hintStyle` were set, the hint colour
  was applied to typed text too, ignoring `textColor`. The standard iOS look — muted placeholder,
  strong typed text — can now be expressed by setting both. Callers using only `hintStyle` are
  unaffected; font metrics are shared between hint and text in all cases.

  Thanks to [@jfhair](https://github.com/jfhair) for the fix (#336).

- **Rim refraction no longer bleeds past the glass boundary on small surfaces (#337):** On small
  `GlassQuality.premium` pills and icon buttons the rim refraction could reach far enough to sample
  content above the surface's top edge, producing rainbow-coloured artefacts once chromatic
  dispersion split it. Displacement is now capped to the surface's own footprint. Larger surfaces
  are unaffected.

  Thanks to [@hinata-platform](https://github.com/hinata-platform) for the fix (#337).

- **Premium glass inside a `BackdropFilter` ancestor no longer renders displaced on Impeller (#333):**
  Glass nested inside any backdrop-reading ancestor was displaced by the ancestor's screen origin
  due to `FlutterFragCoord()` being relative to the offscreen pass. `LiquidGlassRenderObject` now
  resolves uniforms relative to the enclosing Impeller compositor pass. Top-level surfaces are
  unaffected.

  Thanks to [@brockbrunson](https://github.com/brockbrunson) for the root-cause analysis and fix (#333).

# 1.6.2

## Features

- **Native interaction glow for `GlassTabBar` (#329, fixes #323):** `interactionGlowRadius` is now nullable (defaulting to `null`), bringing `GlassTabBar` to parity with `GlassButton`'s iOS 26 native glow calibration (1.6 radius, sigma-16 blur, soft sheen). Explicit values still preserve custom palettes and geometry.

  Thanks to [@azizibahram](https://github.com/azizibahram) for the contribution (#329, fixes #323).

- **Configurable `GlassSlider.thumbShadow` with softer default (#327):** Adds `thumbShadow` to `GlassSlider` for custom resting thumb shadow lists (pass `[]` to disable), while softening the default resting shadow opacity from 25% to 15% black for a cleaner look on light backgrounds.

  Thanks to [@leoluobuqi](https://github.com/leoluobuqi) for the contribution (#327).

## Bug Fixes

- **`GlassTabBar` overdrag no longer clips the edge tab icon (#328):** Rubber-banding past the first or last tab no longer slides the selection window off the edge icon. `JellyClipper` now clamps the clip window against the bar boundary so the icon stays visible and the pill presses elastically against the wall.


# 1.6.1

## Bug Fixes

- **Hoisted capsule kept through sheet morph (#325, fixes #324):** When a
  `GlassBarItem.sheet` was tapped, the capsule it morphed out of vanished mid-flight
  and the route's copy appeared under the sheet barrier in its place. The shell now
  keeps only the tapped capsule hoisted through the presentation while all other chrome
  hands back. `GlassPinnedBarChrome` exposes the presenting item via `chrome.presenting`.
  `GlassNavBarRegistration.presentSheet` is deprecated.

  Thanks to [@JakeThomson](https://github.com/JakeThomson) for the fix (#325).

- **`GlassSlider` resting shadow no longer clipped on light backgrounds (#319):** The
  thumb's `BoxShadow` was part of the material child inside `GlassEffect`, whose content
  is clipped to the glass shape — hiding the shadow on white backgrounds. The shadow is
  now painted as a sibling behind `GlassEffect`, outside the clip, and its alpha is
  multiplied by the material's own fade so it vanishes cleanly during interaction and
  returns on release or cancellation.

  Thanks to [@leoluobuqi](https://github.com/leoluobuqi) for the fix (#319).

- **Cupertino back-swipe no longer crashes with a layout assertion (#326):** Returning
  through a Cupertino page transition could throw a layout assertion when glass surfaces
  were present. The coordinate snapshot is now refreshed during paint, after all ancestors
  have been laid out, preserving UV freeze behaviour across repeated sheet presentations.

  Thanks to [@leoluobuqi](https://github.com/leoluobuqi) for the fix (#326).

- **Glow highlight no longer dies when dragging off a bar (#322):** `GlassGlow` was
  forwarding unclamped pointer coordinates to `GlassGlowLayer`. On captured moves outside
  the widget the centre walked past the layer's clip and the light faded out mid-gesture,
  while the selection indicator — which does clamp — kept tracking the same finger. The
  position is now clamped to the layer bounds so the highlight parks on the nearest edge
  and keeps travelling with the finger, matching platform behaviour.

  Thanks to [@azizibahram](https://github.com/azizibahram) for the fix (#322).


# 1.6.0

## Features

- Added `tintColor` to `GlassBarItem` — floods the entire glass capsule with the colour;
  foreground flips to white or black automatically. Separate-background items only.
  Demonstrated in the example app under **Nav Patterns → Tinted Bar Items** (#312) with
  an interactive 8-color palette switcher and before/after comparison.

## Bug Fixes

- **Slow drags over glass inside a scroll view no longer freeze (#317):**
  `GeometryTransformTrackingLayer` was calling `onTransformChanged` directly from
  `addToScene` — inside a frame — where no new frame gets scheduled. The callback now
  defers to a post-frame callback during compositing.

  Thanks to [@almazfm](https://github.com/almazfm) for the fix (#317).

- **`GlassTabBar.bottom` no longer drags backwards under RTL (#313):** The drag path was
  mirroring the pointer twice — a press landed on the correct tab but the slide ran
  backwards. `DraggableIndicatorPhysics.getAlignmentFromGlobalPosition` now takes a
  `mirrorForRtl` flag; `TabDragGestureMixin` passes `false`.

  Thanks to [@azizibahram](https://github.com/azizibahram) for the fix (#316).

- **`GlassTabBar` tabs expose a semantics tap action (#314):** Tab nodes were buttons with
  a selected state but no `SemanticsAction.tap` — TalkBack and VoiceOver could read every
  destination but activate none of them.

  Thanks to [@azizibahram](https://github.com/azizibahram) for the fix (#315).

- Fixed `AdaptiveGlass` ignoring explicit `settings` when inside a glass container
  (`useOwnLayer: false`). Broke `GlassBodyMode.clear` tinting at standard quality.

- **Fixed UV freeze jitter with `responsive_framework` (#292):** UV freezing now requires
  an explicit `LiquidGlassPushBackScope` signal emitted by `GlassPage` during a real
  CupertinoSheet push-back. Static app-level scales from `responsive_framework`,
  `FittedBox`, and `InteractiveViewer` no longer trigger the freeze. **Zero user code
  changes required.**

---

# 1.5.0


## Features

- **Shader-level touch specular (`uTouchPosition`):** When a `GlassGlow` touch is active,
  the specular highlight on the glass rim now concentrates on the side facing the finger — a
  physically correct optical glint matching Apple iOS 26 Liquid Glass, driven by two new GLSL
  uniforms (`uTouchPosition vec2`, `uTouchIntensity float`). The specular calculation is isotropic
  in physical pixels (immune to aspect ratio warping on wide pills and bars), includes contact
  distance falloff (`smoothstep`), aligns outward rim normals (`anisoN`) with touch rays, is
  Reinhard-compressed, and costs zero at rest (GPU uniform coherence culls the branch when
  `uTouchIntensity == 0`). Wired with zero frame lag via synchronous controller listeners on
  `GlassGlowLayerState` and dual-direction propagation: child `_RenderGlassGlowLayer` objects
  propagate directly to ancestor `LiquidGlassRenderObject`s, while ancestor `GlassGlowLayer`s
  feed `_TouchSpecularBridge` on `RenderLiquidGlassLayer` without widget rebuilds.

- **Vibrancy fill for nested glass (`avoidsRefraction: true`):** When a `GlassEffect` or
  `AdaptiveGlass` sits inside a `GlassContainer` (or any surface that sets
  `InheritedLiquidGlass.avoidsRefraction`), it now renders a proper `_VibrancyFill` — a translucent
  tinted `ShapeDecoration` with `_SpecularRimPainter` rim highlights and full `GlassMaterializeScope`
  support — instead of silently routing to `GlassQuality.minimal` and producing a near-invisible
  widget. No `BackdropFilter`, no compositor stall, zero GPU overhead. Matches iOS 26 UIKit behaviour:
  a `UIVibrancyEffect` nested inside a `UIVisualEffectView` never issues a second backdrop read.
  `AdaptiveGlass.vibrancy()` static factory added as the public entry-point.

- **Continuous menu pointer tracking (`GlassMenu.glowOnTapOnly` default: `false`):**
  Changed the default value of `glowOnTapOnly` from `true` to `false` in `GlassMenu`.
  Because `GlassMenu` operates within a modal dismiss barrier without nested scroll rows,
  pointer tracking now continuously moves the specular glow across menu items during touch drag,
  matching native iOS 26 context menu optics. Menus containing scrollable content can still explicitly
  set `glowOnTapOnly: true` to prevent persistent glow during scrolling.

- **Official AI Agent Skill for vibecoding & pair programming (#306):** Added a
  comprehensive agent skill (`skills/liquid-glass-widgets/SKILL.md`) and onboarding guide
  (`skills/README.md`) that teaches AI assistants (Antigravity, Cursor, Claude Code, GitHub Copilot)
  the library's architecture, setup lifecycle (`LiquidGlassWidgets.initialize()`), `GlassScaffold`
  layout, component substitution dictionary, and anti-hallucination checklists to prevent synthetic
  `BackdropFilter` implementations or obsolete pre-1.0 APIs. Complemented by repository-level
  `AGENTS.md` and `README.md` integration instructions.

## Bug Fixes

- **Native press parity for collapsed search-active tab indicator:** When search is active on
  `GlassTabBar.searchable` and the tab bar collapses to the left dismiss/reopen button, tapping
  it now features the native press growth (`LiquidStretch.nativePressGrowth`), micro-tremor
  (`AnchorStretchSettings.nativeTremor`), and surface highlight (`PressAmbientLift`), exactly
  matching `GlassButton`, `SearchPill`, and `MinimizableTrailingPill` (PR #272 parity).

## Tests

- **Light-mode golden snapshots for key widgets:** Added `goldenTestLight()` helper and companion `LightGoldenTestGroup` / `LightGoldenTestScenario` / `buildWithLightBackground()` utilities to `test/shared/test_helpers.dart`. New `test/golden/light_mode_widgets_golden_test.dart` provides 5 targeted light-mode goldens — `GlassButton`, `GlassAppBar`, `GlassTabBar.bottom`, `AdaptiveGlass`/`GlassCard`, and `GlassToolbar` — exercising subsystems that the all-dark suite cannot reach: `_InverseShapeClipper`/`_InverseBarClipper` drop-shadow rendering, `ambientBaseLight` doubling (`0.14` vs `0.07`), and Rec.709 adaptive glass strength (`0.8×` on high-luminance backgrounds). Goldens generated on macOS (Impeller); excluded from CI by existing `dart_test.yaml` tag filter.

## Chores

- **Engine organization & attribution:** Consolidated foundational rendering primitives into `lib/src/engine/` with formal attribution (`lib/src/engine/ATTRIBUTION.md`) crediting original work by Tim Lehmann. Internal refactoring only; no public API changes.

- **Shader rename:** `liquid_glass_final_render.frag` → `liquid_glass_render.frag`. Drops the redundant `_final_` prefix, aligning the on-disk filename 1:1 with the Dart constant `ShaderKeys.liquidGlassRender`. All references updated across `pubspec.yaml`, `shaders.dart`, setup docs, attribution, ROADMAP, and changelogs.

- **Touch specular `pow()` elimination:** Replaced `pow(rimTouchDot, 6.0)` in the touch-specular block of `liquid_glass_render.frag` with a two-multiply chain `(x²)³ = x⁶`. `pow()` compiles as `exp2(6·log2(x))` on Mali/Adreno/Apple GPU — two transcendental SFU calls. The multiply chain is exact, branchless, and 4–8× faster per fragment on mobile.

- **Beer-Lambert meniscus deduplication in `lightweight_glass.frag`:** Extracted the 5-line hemisphere-lens × light-modulated absorption formula (previously copy-pasted at 3 call sites: PATH A fallback, PATH A normal, and PATH B) into a shared `meniscusAbsorption()` function. Mathematically identical output; reduces maintenance surface and compiled shader binary size.

# 1.4.4

## Features

- **`GlassPinnedBarChrome.horizontalInset` — the guide a hoisted bar is drawn on (#307):** The chrome was always positioned at `GlassNavPinnedMetrics.horizontalPadding`, which is right for a bar the package draws at both ends and wrong for one the app draws. Presenting a sheet hands the chrome back to its route, and a bar aligned to its own page gutter stepped sideways at every hand-over. It now takes the inset its bar reports, defaulting to the old one.

Thanks to [@JakeThomson](https://github.com/JakeThomson) for the feature (#308).

- **`GlassPinnedBarChrome.platformViewBackdrop` — pinned chrome over a platform view (#310):** The shell drew a hoisted capsule with its own `GlassButton` on the shader path, whose captured backdrop excludes a platform view — so over a map the capsule had nothing to refract and rendered clear with a rim, whatever `buttonSettings` said, while the bar's own capsule blurred through a live `BackdropFilter`. The registration carries the flag now and the host forwards it to the capsule and menu it draws, resolved to the route being entered so a pop back over the view is on the backdrop from its first frame.

Thanks to [@JakeThomson](https://github.com/JakeThomson) for the feature (#311).

## Bug Fixes

- **`GlassSheet` removes redundant inner `SafeArea` (#309):** `GlassSheet`'s inner column wrapped its content in `SafeArea(bottom: true)` without disabling `top: true`, causing unconsumed top status-bar padding from the window to leak into the sheet and push the top drag handle 50+ dp down. In addition, the inner wrapper forced bottom safe-area insetting even when `GlassSheet.show(useSafeArea: false)` was requested. The redundant inner `SafeArea` has been removed while preserving outer `useSafeArea` behavior.

Thanks to [@yohom](https://github.com/yohom) for the fix (#309).

# 1.4.3

## Features

- **`GlassBarItem.sheet` — a bar item whose sheet morphs out of the capsule (#304):** Nothing reached the capsule a pinned bar draws, so an app wanting the liquid morph had to hoist its cluster as one `GlassBarItemBackground.own` item and give up the cross-route morph. The new item hands its tap a `GlassMorphAnchor` for `GlassModalSheet.show(morphFrom:)` — the route's own capsule, which is the one still on screen once the sheet has handed the chrome back, and the only one a sheet can cover.

  ```dart
  GlassAppBar.pinned(
    actions: [
      GlassBarItem.sheet(
        icon: const Icon(CupertinoIcons.add),
        onPresent: (anchor) => GlassModalSheet.show<void>(
          context: context,
          morphFrom: anchor,
          builder: (context) => const AddSheet(),
        ),
      ),
    ],
  )
  ```

Thanks to [@JakeThomson](https://github.com/JakeThomson) for the feature (#304).

## Bug Fixes

- **Pinned chrome morphs over a sprung route's full duration (#302):** The shell drove its choreography from the route's animation value, which is non-linear for spring-based transitions (zoom), so the morph completed in the first few frames while the page was still flying. A route that answers `createSimulation` now plays chrome on the shell's own controller over `transitionDuration`; duration-driven routes are unchanged.

- **Two custom items that draw their own glass no longer overlap mid-morph (#302):** A matched pair of `GlassBarItemBackground.own` items sharing the same id cross-faded like plain content, stacking both surfaces mid-transition and causing a visible brightness artifact. The outgoing surface now dissolves before the incoming one materializes.

Thanks to [@JakeThomson](https://github.com/JakeThomson) for the fix (#302).

- **`GlassTabBar.searchable` text colour now follows the app's ThemeMode, not the device OS brightness (#305):** `GlassSearchBarConfig.textColor` defaulted to `CupertinoColors.label.resolveFrom(context)`, which reads `MediaQuery.platformBrightness` rather than the app's `ThemeData`. On a device in OS dark mode with the app forced to light mode this produced invisible white-on-white text. Resolution now routes through `GlassTheme.brightnessOf`, the package's single brightness authority, consistent with how icon colours are resolved in the same widget.

# 1.4.2

## Bug Fixes

- **Custom bar items that draw their own glass no longer flash across a push or pop (#296):** The pinned chrome fades and blurs item content by painting it under opacity and image-filter layers, and a glass surface painted under either has no backdrop to sample — a `GlassBarItem.custom` carrying its own `GlassButton.custom` capsule rendered as its opaque backer for the whole transition and snapped to glass on the last frame. `GlassBarItemBackground.own` marks such an item, and the cluster dissolves it through the surface's own visibility instead.

- **Pinned clusters now dissolve across a push or pop instead of popping in and out:** `GlassMenu` wraps its trigger in a resting `GlassMaterializeScope` so the trigger can fade under an open menu, and every pinned cluster sits inside that wrapper — so the materialize the shell runs around a cluster only one route has never reached the glass. The outgoing shell stayed solid until it was dropped, the incoming one appeared solid, and for a few frames both were drawn. The menu's scope now composes with an enclosing one.

Thanks to [@JakeThomson](https://github.com/JakeThomson) for the fix (#297).

- **Dismissible modal sheets retain their frame below the lowest enabled detent (#298):** Sheets without a small detent no longer jump to peek width, margins, or corners during dismissal. Large-only sheets slide away with their full frame; medium+large sheets preserve the medium frame below that detent.

Thanks to [@hank205](https://github.com/hank205) for the fix (#299).

- **Menu & Popover dismissal during page transitions and declarative navigation (#274):**
  - **Zero Transition Overlap**: Replaced `OverlayChildLocation.rootOverlay` with `OverlayChildLocation.nearestOverlay` in both `GlassMenu` and `GlassPopover`. In addition, trigger position is now calculated locally relative to `nearestOverlay` (`renderBox.localToGlobal(Offset.zero, ancestor: overlayBox)`), preventing menu positioning drift in nested layouts while ensuring the menu lives in the same overlay stack as its route. As a result, incoming pushed routes render in front of closing menus instead of allowing the menu and its glass blur to float above the incoming page.
  - **Declarative Navigation Safety (`go_router` / `Navigator.pages`)**: Immediate route dismissal calls that fire during Flutter's persistent callbacks phase (`SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks`) are now deferred to post-frame callbacks via `SchedulerBinding.instance.addPostFrameCallback`. This completely eliminates the `SchedulerBinding.instance.schedulerPhase != SchedulerPhase.persistentCallbacks` assertion crash when updating pages in declarative routers.
  - **Standalone Navigation Demo**: Added `GlassMenuNavigationDemoPage` (`example/lib/demos/glass_menu_navigation_demo.dart`) providing an interactive demonstration of clean overlay dismissal across imperative, declarative (`go_router`), and nested tab navigator setups with slow-motion transition controls.

## Calibration

- **Corrected luminance weights to ITU-R Rec.709 across all rendering paths:** All
  shader and Dart-side luminance computations now use `0.2126 R / 0.7152 G / 0.0722 B`
  (the standard for sRGB and Display P3) instead of the legacy BT.601 SDTV coefficients
  that were previously in use. The correction is most visible on blue- and cyan-heavy
  backgrounds where BT.601 measurably overestimated perceived brightness.

# 1.4.1

## Bug Fixes

- **`GlassNavigationShell` no longer marks its chrome dirty mid-build (#293):** The shell listens to every registered route's animations and re-resolved the pinned chrome synchronously on each tick. A page-based `Navigator` applies its pages inside `didUpdateWidget` — the build phase — and a route with no transition completes its animation right there, so the tick landed as `setState() or markNeedsBuild() called during build` on the chrome's `ListenableBuilder` for every such push and pop, and the chrome missed that frame. Ticks now defer past build the way status changes already did.

Thanks to [@JakeThomson](https://github.com/JakeThomson) for the fix (#294).

- **`GlassScaffold` dark mode stuck white in `MaterialApp` (#289):** `GlassScaffold` now scopes its internal `CupertinoTheme` and `GlassStatusBarStyle.auto` icon style through `GlassTheme.brightnessOf`. This correctly honours `ThemeMode.dark` / `.light` even when the device OS brightness differs from the app theme.

- **Menu and popover dismissal across nested Navigators (#274):** `GlassMenu` and `GlassPopover` now listen to transitions across all ancestor `ModalRoute`s up to the root. When navigation occurs on an enclosing shell or root `Navigator`, the overlay dismisses immediately instead of lingering over the incoming destination page.

Thanks to [@Vincen-dev](https://github.com/Vincen-dev) for the reproduction and test (#274).

# 1.4.0

## Features

- **`GlassBodyMode` (`adaptive` vs `clear`) — exact design token color fidelity (#269):**
  Introduced `GlassBodyMode` enum and `bodyMode` property on `LiquidGlassSettings` (defaulting to `GlassBodyMode.adaptive`), achieving 1:1 parity with Apple iOS 26 Liquid Glass `Glass.regular` vs `Glass.clear`.
  - `GlassBodyMode.adaptive` (default): Employs iOS 26 dynamic luminosity normalization, ambient tint modulation, and brightness compensation based on underlying backdrop luminance.
  - `GlassBodyMode.clear`: Bypasses luminosity normalization, white-point lift, and content-adaptive modulation. Directly composites the designer's exact hex color and alpha from `glassColor` over the refracted scene while preserving all 3D optical properties (specular rim reflections, Fresnel edge glow, meniscus edge absorption, and surface refraction).
  - Perfectly resolves color fidelity when `blur: 0` is combined with custom tinted glass surfaces.
  - Fully integrated across all shader tiers (Impeller `liquid_glass_render.frag`, standard `lightweight_glass.frag`, and Skia `_FrostedFallback`).

- **Decoupled track background quality in `GlassTabBar`:**
  Added `backgroundQuality: GlassQuality?` across `GlassTabBar.bottom`, `GlassTabBar.inline`, `GlassTabBar.searchable`, and `GlassTabBar.minimizable`.
  - Directly matches UIKit's `UITabBarAppearance.backgroundEffect` decoupling from the active selection capsule.
  - Allows tab bar containers to render with lightweight frosted glass (e.g., `backgroundQuality: GlassQuality.minimal` or `.standard`) while the moving selection pill retains full liquid refraction (`quality: GlassQuality.premium`).
  - Defaults to `null`, which seamlessly inherits from `quality` without any visual regression.

- **`GlassTabBarTrailingButton.menu` and `GlassTabBarExtraButton.menu` — native pull-down menus from tab bars (#275):** Both the trailing pill on `GlassTabBar.minimizable` and the extra action button on `GlassTabBar.bottom` and `GlassTabBar.searchable` now support an optional `GlassMenu` pull-down, using the same `.menu` named-constructor pattern established by `GlassButtonGroupItem.menu` and `GlassBarItem.menu`.

  ```dart
  // Minimizable trailing pill → opens a menu on tap
  GlassTabBarTrailingButton.menu(
    icon: const Icon(CupertinoIcons.ellipsis_circle),
    label: 'More',
    menuItems: [
      GlassMenuItem(label: 'Edit', onTap: _edit),
      GlassMenuItem(label: 'Share', onTap: _share),
    ],
  )

  // Bottom-bar extra button → opens a menu on tap
  GlassTabBarExtraButton.menu(
    icon: const Icon(CupertinoIcons.plus),
    label: 'New',
    menuItems: [
      GlassMenuItem(label: 'New Note', onTap: _newNote),
      GlassMenuDivider(),
      GlassMenuItem(label: 'Import', onTap: _import),
    ],
  )
  ```

  - **Liquid spring origin:** The menu expansion spring originates from the button's actual render coordinates — identical behaviour to `GlassBarItem.menu` and `UIBarButtonItem(image:menu:)` in SwiftUI.
  - **Auto-upward expansion:** `autoAdjustToScreen: true` is always applied, so menus anchored inside a bottom bar always expand upward, matching the iOS 26 Liquid Glass `UIMenu` behaviour on toolbar items.
  - **`enabled` toggle:** Setting `enabled: false` on either constructor dims the button and suppresses the menu — consistent with the existing tap-callback variant.
  - **Accessibility:** Both triggers are wrapped in a `Semantics` node using the required `label` so screen readers announce the control correctly.
  - **API surface:**
    - `GlassTabBarTrailingButton` gains: `menuItems`, `menuAlignment`, `menuWidth`, `label`, `enabled`.
    - `GlassTabBarExtraButton` gains: `menuItems`, `menuAlignment`, `menuWidth`. The `label` and `enabled` fields were already present.
    - The `isMenu` getter on both classes returns true when the menu variant is active.
  - **No scope creep:** Direct pass-through of arbitrary widget trees to the trigger position is explicitly deferred; use `GlassMenu.triggerBuilder` directly for fully custom triggers.

  Thanks to [@JoetineY](https://github.com/JoetineY) for the feature request (#275).

- **`GlassModalSheet` drag indicator geometry (#288):** `dragIndicatorHeight` (default 4) and `dragIndicatorTopPadding` (default 8) join `dragIndicatorWidth`, so a sheet can match a host's own pill. Apple's own apps vary the pill's thickness, width and inset from sheet to sheet, and sit it higher where a control row follows (Maps), so there is no one right value to bake in; the defaults are unchanged.

  Thanks to [@jfhair](https://github.com/jfhair) for the feature (#288).

## Bug Fixes

- **Color configuration is uncertain when blur=0 (#269):** When developers configured custom tint colors with `blur: 0`, the surface previously suffered from unexpected luminance and saturation drift because the shader applied adaptive ambient and light calculations intended for blurred glass. Developers can now set `bodyMode: GlassBodyMode.clear` on `LiquidGlassSettings` to bypass adaptive tinting and composite the exact designer hex color while maintaining specular highlights, Fresnel sheen, and 3D meniscus edge refraction.

Thanks to [@JoetineY](https://github.com/JoetineY) for the bug report (#269).

- **Minimized bar keeps the selected tab's icon colour (#279):** On `GlassTabBar.minimizable`, the minimized pill drew the selected tab's icon in `unselectedIconColor`, so a custom `selectedIconColor` dropped out on minimize and returned on expand. The pill now uses `selectedIconColor`, as the native bar does — the tab is still selected, only the bar has shrunk. `GlassTabBar.searchable` is unchanged: its collapsed pill shows the tab search was opened from, which is no longer the selected one.

Thanks to [@JakeThomson](https://github.com/JakeThomson) for the fix (#280).

- **`GlassScrollEdgeStyle.blur` stays on its own route (#278):** The progressive blur is a backdrop filter, and left unclipped a backdrop filter frosts everything beneath it up to the nearest ancestor clip — under a Cupertino pop that included the route being revealed, which showed the outgoing screen's top and bottom bands until the transition settled. The shader path lost its `ClipRect` when the region moved to paint time in 0.30.1; it is back, so a `ProgressiveBlur` now frosts nothing outside its own rectangle wherever it sits.

Thanks to [@JakeThomson](https://github.com/JakeThomson) for the fix and on-device integration tests (#281).

- **`GlassAppBar` title alignment (#282):** Left-aligned titles (`centerTitle: false`) no longer add an unintended 8 px start gap when no leading widget is present, correctly aligning with content padding.

Thanks to [@Vincen-dev](https://github.com/Vincen-dev) for the bug report and reproduction test (#282).

- **Menu and popover dismiss instantly on route navigation (#274):** When an item or action navigates to another page, `GlassMenu` and `GlassPopover` dismiss immediately instead of playing the close spring across the destination route transition.

Thanks to [@Vincen-dev](https://github.com/Vincen-dev) for the bug report (#274).

- **`GlassModalSheet` finishes its travel when a drag hands over to the content (#284):** An upward content drag hands the pointer to the scroll view once the sheet is within 5% of its top detent, and that pointer's release is a scroll, not a drag — so the sheet parked up to 5% short of the top with no `onStateChanged`, the host still believed it sat at the lower detent, and the next collapse skipped its scroll-to-top. The sheet now snaps the remainder at the moment of handover: it arrives, reports `full` and gives its haptic as the content starts to scroll, not when the finger eventually lifts.

Thanks to [@jfhair](https://github.com/jfhair) for the fix (#284).

- **`GlassModalSheetController.progress` and `value` are current inside `progressListenable` (#285):** Both reported the position the sheet had last *built* at, and the listener fires before that build — a frame behind, so the final tick of any drag never showed where the sheet stopped. They now refresh on every controller tick, before listeners run.

Thanks to [@jfhair](https://github.com/jfhair) for the fix (#285).

- **`GlassModalSheet` drags after a background launch (#290):** The sheet read the window size once, in its first post-frame callback, and re-read it only on a change *from* a non-zero size. An app the system launches in the background for a push builds against a 0×0 window, so a sheet created then kept the zero for life: when the app came to the foreground, its first drag divided by that zero and parked the sheet at infinity — nothing painted, no `onStateChanged`, and every later `snapToState` starting from infinity — until the process was killed. The size is now taken from the view whenever the cache still holds that zero and refreshed on every window-size change, and a drag on a window with no size is ignored.

Thanks to [@jfhair](https://github.com/jfhair) for the fix (#290).

---

# 1.3.0

## Bug Fixes

- **`GlassButton` presses like a native button (behaviour change) (#267):** Measured at 120 fps, the press now grows by ~17 pt on a snappy spring (`interactionScale: null`), drags stretch no more than ~5 %, and the surface combines ambient lift (`ambientBaseLight: 0.3`) with a subtle shape-clipped specular sheen (`glowRadius: null`, resolving to a wide 1.6 radius with soft sigma-16 blur). The highlight is clipped strictly to `shape` via `ShapeBorderClipper`, staying bounded within the button geometry and sweeping across grouped buttons without creating a pointy hotspot. `LiquidStretch` declares its scale through `LiquidGlassSelfScaleScope` so the release undershoot no longer freezes refraction.

  > **Migration:** Pass `glowRadius: 0.0` to disable the directional sheen (pure ambient lift). Pass `interactionScale: 1.05`, `ambientBaseLight: 0.08`, or use `GlassInteractionSettings` theme-wide to customize.

- **Search circle and trailing pill press like native buttons (#272, #276):** The collapsed pills now use `GlassButton`'s ~17 pt growth, tremor stretch, and ambient lift, staying round through inflation. The expanded search field follows a lengthwise drag (≈7 pt saturation) and gives a couple of points of vertical stretch, measured against Photos. `pressScale` and `ambientBaseLight` are both nullable — null means the native behaviour, a number is a fixed override.

Thanks to [@JakeThomson](https://github.com/JakeThomson) for the native press implementation, `LiquidOval` corner fix, and axis-constrained expanded field stretch (#276).

- **Transform tracking crash on route pop fixed (#268):** `GeometryTransformTrackingLayer.addToScene` now checks `renderObject.attached` and wraps `getTransformTo(null)` in a try-catch, preventing the `StateError` that occurred while render objects were detaching during page transitions.

Thanks to [@kdbhalala](https://github.com/kdbhalala) for the fix (#268).

## Performance

- **O(N) Quickselect for frame timing percentiles (#268):** The Phase 3 P95 hysteresis check now uses in-place Quickselect (Hoare partition, midpoint pivot) instead of a full sort, eliminating per-evaluation heap allocations on the frame callback path.

Thanks to [@kdbhalala](https://github.com/kdbhalala) for the optimisation (#268).

- **Zero-allocation glow paint path (`_RenderGlassGlowLayer`):** Eliminates per-frame `Path` allocations during gesture spring animations. `_RenderGlassGlowLayer` now follows the Flutter engine's `RenderCustomClip` pattern: clip paths are cached keyed on `size`, `shouldReclip` prevents re-clipping on value-equal rebuilds, and `canvas.translate` replaces `.shift()`. Drops native path heap churn from up to 240 allocations/s on 120 Hz ProMotion displays to zero steady-state allocations during drags.

## Internal

- **`THIRD_PARTY_NOTICES` added (#273):** The pub.dev archive now includes full MIT copyright notices for the vendored `liquid_glass_renderer` and adapted `motor` spring utilities. README updated to link to the notices file.

---


# 1.2.3

## Bug Fixes

- **Inline bottom accessory reaches the trailing edge without a trailing button (#264):** On `GlassTabBar.minimizable`, a minimized bar with a bottom accessory and no trailing button left a dead gap on the trailing edge — the accessory geometry reserved space for the trailing pill regardless of whether one was present. The accessory now extends flush to the horizontal padding when no trailing button is configured, and still clears the pill when one is.

Thanks to [@eomgerm](https://github.com/eomgerm) for the fix (#265).

## Internal

- **`MinimizableTrailingPill` — dedicated stateless pill for the trailing slot:** The trailing-button pill was previously synthesised by re-using `GlassSearchBarConfig` with a dummy search config, creating a double-source-of-truth between `_buildMinimizable` and the layout engine. It is now a dedicated `MinimizableTrailingPill` widget sharing the same `LayoutBuilder`/oval-detection morph pattern as `SearchPill` — identical pill physics, single authoritative gate. A debug-mode assert now fires if `searchConfig` and `trailingButton` are both non-null; these are mutually exclusive rendering slots.

---

# 1.2.2

## New Features

- **Scrollable segmented control — selection stability and picker behaviors (#263):** The pill no longer slides in from the track edge on mount or blinks out on list changes (`VelocitySpringBuilder.teleportEpoch`). `GlassSegment.id` keeps surviving cells mounted across list changes. New opt-in picker behaviors: `SegmentSelectionAlignment.center`, `SegmentDragBehavior.scroll`, `regridDuration` (anchored re-grid morph, default `Duration.zero`), and an externally injectable `scrollController`.

Thanks to [@jfhair](https://github.com/jfhair) for the full implementation, tests, and example demo (#263).

---

# 1.2.1

## Bug Fixes

- **Quality recovery is reachable again (#261):** Glass quality demoted by a transient cost spike (a map, large images, a native view) now recovers after a sustained run of under-budget frames. Previously, frames landing in the neutral band between the upgrade and downgrade thresholds reset the recovery counter, making recovery essentially unreachable in practice.

- **Tab indicator settles back when host declines selection (#255):** Dragging or tapping to a new tab when the host declines the selection (action tab, navigation guard, failed route push) previously left the indicator parked on the wrong tab. It now springs back to the host's current tab on the next frame across all gesture paths.

- **Sheet ↔ content scroll handover (#258):** A multi-detent `GlassModalSheet` now grows and then scrolls its content on one unbroken drag, and reverses the same way. Content on a `ScrollController` of its own is now observed too — no call-site changes required.

- **`GlassNavigationShell` pinning no longer gated on blur quality (#262):** Pinning is chrome geometry, not a shader effect — it costs no render pass of its own. The `minimal` quality gate that previously switched pinning off has been removed. `GlassQualityAdapter` steps down to `minimal` automatically under frame pressure, so pinning was silently disabling itself in debug builds and on low-end devices that need it most.

Thanks to [@Nixxx19](https://github.com/Nixxx19) for the quality recovery, tab indicator, and pinning gate fixes (#255, #261, #262).

Thanks to [@JakeThomson](https://github.com/JakeThomson) for the sheet ↔ content scroll handover (#258).

---

# 1.2.0

## New Features

- **Native gel morph for pinned clusters:** A cluster present on both routes now reshapes the way the iOS 26 bar does instead of gliding between widths. Its width and item positions ride the package's bouncy spring profile for the full length of the route transition, settling in the same breath the page lands; the spring's overshoot is deliberately not walked in width — it is expressed as a whole-shell squeeze instead, layered on a gel pulse that inflates the shell early — height, radius and glyphs together, as real geometry through the glass renderer. Glyphs no longer plainly cross-fade: an outgoing glyph smears away under heavy blur while the shell reshapes beneath it, and an incoming one arrives soft and sharpens last. A pop plays the same forward choreography toward the other cluster rather than the push in reverse. The morph stays a pure function of the route clock; timing and blur constants live together in `GlassNavPinnedMetrics`, and the choreography is locked down by a frame-by-frame trace test. (Clusters only one route has materialize instead — see below.)
- **Header Actions Morph demo:** New pattern in the example app's Navigation Patterns page — a repository-style drill-down where each destination carries a different trailing cluster (contract to one, identifier-matched hold, widen to three), so every capsule morph can be exercised and scrubbed in isolation.
- **Progressive Blur Scroll Edge Style (`GlassScrollEdgeStyle.blur`):** Introduces a hardware-accelerated GPU progressive Gaussian frost option via `ProgressiveBlur`, applying an `ImageFilter.shader` pass with ease-in quadratic falloff (`falloff: 1.2`) directly over live scrolling content. Default remains `GlassScrollEdgeStyle.soft` (the diffused gradient fade matching iOS 26's `.scrollEdgeEffectStyle(.soft)`). Developers can opt into `.blur` for richer frosting over custom dynamic gradients, video backdrops, or media grids.
- **Configurable `maxSigma` & Signed Fade Extents:** Exposes `maxSigma` (default 18.0) for `GlassScrollEdgeStyle.blur`, alongside signed `topEdgeFadeExtent` and `bottomEdgeFadeExtent` (default 20.0) on `GlassScaffold` and `GlassScrollEdgeEffect` for granular transition zone control (including negative extents for tight floating-bar insets).
- **Materialize entrance & exit transitions (`GlassMaterialize`):** Glass items now appear and disappear the way iOS 26 does, mirroring SwiftUI's `glassEffectTransition(.materialize)`: the glass fades up as it settles inward from slightly oversized, and its content sharpens only after the shape has resolved — reversed on the way out, where the content blurs away first and leaves the shell briefly empty before it dissolves. `GlassMaterialize` is the implicit `visible:`-driven form (the `AnimatedOpacity` idiom); `GlassMaterializeTransition` is the explicit `Animation`-driven form (the `FadeTransition` idiom), and doubles as an `AnimatedSwitcher.transitionBuilder` via `GlassMaterializeTransition.switcherBuilder`. Works on any glass surface at any quality tier: rather than fading a layer — which pops, because a backdrop pass renders fully or not at all — the effect drives the glass shader's own visibility uniforms, where the refraction warp lerps to identity and the render pass drops out entirely at zero.
- **Pinned navigation chrome materializes (behaviour change):** A pinned back button or actions capsule that only one of the two routes has no longer switches on or off at the transition midpoint — it materializes or dematerializes over a window straddling it. The phase is a pure function of route progress, so a pop plays the windows in reverse with the exit still leading the entrance in both directions. An interactive back-swipe does *not* scrub them: the page and title track the finger, but the chrome holds still until the gesture commits and then plays its transition over the travel that remains, so a swipe you abandon never half-dissolves anything. A capsule present on *both* routes is unaffected: it still morphs in place with one persistent glass shell. Opt out with `GlassNavigationShell.effectTransition: GlassEffectTransition.identity`, which restores the 1.1.0 behaviour exactly; **Reduce Motion selects it automatically**, and the standalone widgets likewise fall back to a plain cross-dissolve with no scale or blur.
- **Materialize Playground Demo:** Added `example/lib/demos/materialize_demo.dart` — a single glass button, a multi-item capsule, and an `AnimatedSwitcher` swapping glass chips, each toggleable, over a busy backdrop with a live Reduce Motion switch.
- **`GlassPinnedBarChrome` — pin a bar that isn't a `GlassAppBar`:** The registration handshake behind `GlassAppBar.pinned` is now public, so an app whose bars are its own widgets — a Material `AppBar` with a bespoke backdrop, a collapsing large-title sliver — can join a `GlassNavigationShell` without reimplementing it. Items are declared once as data; the builder receives `chrome.leading` and `chrome.actions`, which hold the real glass buttons until the shell has both accepted the registration and had a frame to render its copy, and same-sized unpainted placeholders after — so the bar never builds a second copy and nothing shifts at the hand-over. `GlassAppBar.pinned` now builds its own slots the same way, so there is one implementation rather than two. An `enabled` flag keeps a nested navigator's roots out of the shell, which ranks routes within a single `Navigator`. New **Custom Bar Pinning** pattern in the nav-patterns demo pins a plain Material `AppBar`.
- **Pinned leading items (`GlassAppBar.pinned(leading:)`):** The pinned bar's leading slot is no longer limited to its own automatic back button, so a screen with a Cancel, a close button or a profile photo can pin its chrome instead of falling back whole. `leading` takes the same `GlassBarItem` vocabulary as `actions` and inherits the whole morph — width interpolation, `id` matching, icon cross-fade, taps swallowed mid-transition — because the cluster render object now anchors to whichever edge it is pinned to rather than always the trailing one. A non-empty `leading` **replaces** the back button, matching `UINavigationItem.leftBarButtonItems` and Flutter's own `AppBar.leading`; `leadingItemsSupplementBackButton: true` shows both, mirroring `UINavigationItem.leftItemsSupplementBackButton`. A lone back button renders exactly as before.
- **`GlassBarItemBackground` — per-item glass:** Collapses the two booleans iOS 26 added to `UIBarButtonItem` into their three distinct results: `shared` (the default — `sharesBackground`, items form one capsule), `separate` (`sharesBackground: NO` — its own shell, which at a lone icon's size is the circular button iOS 26 draws for a single bar item) and `none` (`hidesSharedBackground` — no glass at all, for content that carries its own shape, such as a profile photo). A cluster now renders one shell per group rather than always one capsule.
- **Leading Items demo:** The nav-patterns showcase gains a pattern walking the four leading configurations — a bare avatar, the implied back button, a leading that replaces it, and one beside it — plus the lone circular shell growing into a two-item capsule.
- **Scroll Edge Playground Demo:** Added a comprehensive interactive showcase in the example app (`example/lib/demos/scroll_edge_style_demo.dart`) featuring live style switching (`soft`, `hard`, `blur`), real-time extent/sigma sliders, top/bottom toggles, and floating `GlassAppBar` & `GlassTabBar.bottom` integration with solid content cards.
- **Bottom accessory follows the bar (behaviour change) (#226):** on
  `GlassTabBar.minimizable`, a `bottomAccessory` with no explicit
  `bottomAccessoryPlacement` now resolves to
  `GlassTabBarAccessoryPlacement.inline` while the bar is minimized, matching
  how iOS 26 animates a `tabViewBottomAccessory` down into the minimized bar.
  Previously it stayed `expanded` unless `inline` was passed explicitly.

  **This changes what `GlassTabBarAccessoryPlacementScope.of(context)` returns**
  for affected callers — an accessory that switches on it will render its
  compact variant on scroll where it previously did not, with no code change on
  your side — and shrinks `preferredSize` by
  `bottomAccessorySpacing + bottomAccessoryHeight` while minimized. Affects only
  bars that have an accessory, pass no explicit placement, and reach the
  minimized state. Pass `GlassTabBarAccessoryPlacement.expanded` to keep the
  previous behaviour.

  `GlassTabBar.searchable` is deliberately unchanged. Auto-collapsing on search
  was removed in 0.x because it hid the mini-player behind the search capsule,
  and that decision stands — a search field expanding is not the bar minimizing.

## API

- **`PlatformViewGlassMode.passthrough` — glass over platform views (#247):** New enum value on `LiquidGlassSettings`. Instead of resolving to black where the backdrop capture held nothing (over a map, camera, video, or WebView), coverage follows what was actually sampled so the live view shows through. Default is `PlatformViewGlassMode.fallbackColor` — no behaviour change for existing callers. `GlassTabBar` gains a matching `passthroughOverPlatformView` flag that lifts selected-tab content above the glass to avoid the doubled-label the refracted icon layer would otherwise cause.

- **`GlassChip.platformViewBackdrop` (#250):** `GlassButton` already exposed this parameter; `GlassChip` now surfaces and forwards it, closing the gap for chips rendered over platform views. Default is `false`, no change for existing callers.

- **`GlassNavPinnedMetrics` is now exported from the package barrel:** The geometry the pinned shell redraws hoisted chrome at — 44pt back circle, 46pt action slots, 44pt toolbar band, 8pt edge inset. A bar that is not a `GlassAppBar` had no supported way to reach it and had to hardcode the numbers, which drift the first time the package retunes them. The `show` clause exposes the metrics only; `GlassNavPinnedHost` and the cluster render objects stay internal. Documented under [Glass Navigation Transition](docs/GLASS_NAVIGATION_TRANSITION.md#if-your-bar-is-not-a-glassappbar).

## Bug Fixes

- **`GlassNavPinnedMetrics.crossFadeStart`/`crossFadeEnd` changed meaning:** These are now fractions of the morph window (`morphStart`..`morphEnd`) rather than raw route progress; `glyphSharpenStart`/`glyphSharpenEnd` follow the same convention. Read them through `GlassNavPinnedMetrics.morphProgressAt` to align custom chrome.
- **Matched icons no longer spuriously cross-fade:** Icons were compared by reference rather than value, so two identical `Icon(Icons.x)` literals on different routes cross-faded with themselves on every push. Icons are now compared by value (glyph, size, colour, key).
- **`GlassTabBarMinimizeController` drivable without a `ScrollController`:** `handleSample` is no longer `@visibleForTesting`, and a new `handleNotification(ScrollNotification)` method drives the bar directly from a `NotificationListener`. Leave `GlassTabBar.minimizable`'s `scrollController` unset when using this path.
- **`blur: 0` no longer downgrades any tier to `_FrostedFallback` (#253):** A `blur: 0` surface now keeps its rim, Fresnel, and specular — the shader's own guard already handles the zero-blur pass cleanly. **Visual change at standard:** surfaces that previously resolved to `_FrostedFallback` now render the lightweight shader. Use `GlassQuality.minimal` explicitly if frost fallback was intentional.
- **Presented routes now cover the pinned chrome (#259):** A dialog, action sheet, `GlassModalSheet`, or `fullscreenDialog` previously left the pinned glass back button and actions capsule painted above the presentation at full brightness. The shell now hands the chrome back to the presented route so it dims with everything else.

Thanks to [@JakeThomson](https://github.com/JakeThomson) for the materialize transitions, pinned navigation chrome, leading API and per-item glass backgrounds, scroll-to-minimize controller improvements, bottom accessory inline behaviour, metrics export, and the presented-route chrome fix (#240, #238, #236, #239, #233, #234, #259).

Thanks to [@marco242424](https://github.com/marco242424) for the native gel morph (#243).

Thanks to [@Nixxx19](https://github.com/Nixxx19) for the platform-view glass passthrough mode, `GlassChip` backdrop parameter, and the blur tier-downgrade fix (#247, #250, #253).

---

# 1.1.0

## New Features

- **GlassNavigationTransition — pinned navigation-bar chrome:** New `GlassNavigationShell` hosts the glass back button and trailing actions capsule *above* the `Navigator`, reproducing the iOS 26 navigation bar: page content and title slide during push/pop (including the interactive back-swipe, scrubbed proportionally) while the glass chrome stays pinned and morphs in place. Screens opt in with the `GlassAppBar.pinned` constructor, declaring actions as data (`GlassBarItem.icon` / `GlassBarItem.custom`); items sharing an `id` are treated as the same item across routes, mirroring `UIBarButtonItem.identifier`. Custom widgets are measured at intrinsic width, exactly as UIKit measures a `customView`. Works with any Pages-API router (go_router, auto_route, beamer) — the shell only reads `ModalRoute` animations. Without a shell, or where the effect cannot render, the same data renders in-route as today's glass capsule.
- **`GlassBarItem.menu` — pull-down menus in a pinned bar:** The `UIBarButtonItem.menu` analogue, and the iOS 26 overflow button. The whole capsule morphs into the pull-down, matching `GlassButtonGroupItem.menu`. Menus cannot be opened mid-transition, and one already open is dismissed when navigation starts — the pinned capsule outlives the route that owns it, so nothing else would. Falls back to `GlassButtonGroupItem.menu` in-route wherever pinning does.
- **GlassAppBar single-line titles:** The inline title no longer wraps to a second line when wide actions squeeze it; it truncates with an ellipsis, matching iOS.
- **`GlassModalSheet` swipe-dismissals morph back from the release point (#223):** Dragging a morphed sheet away used to skip the morph and slide the sheet off. Below the lowest detent the sheet now shrinks about the grabbed point as it follows the finger — the interactive zoom-dismissal measured off iOS 26 — and the release hands that exact frame to the closing morph. Sideways, the card chases the finger through a tracking spring, pinning at the screen edge. A release short of the dismiss threshold springs back. Sheets shown without `morphFrom` keep their plain slide-away unchanged.
- **Scroll-to-minimize for `GlassTabBar.minimizable` (#228):** A new `GlassTabBarMinimizeController` drives the minimize from scrolling — the Flutter equivalent of SwiftUI's `.tabBarMinimizeBehavior(_:)`. `GlassBarMinimizeBehavior` mirrors Apple's enum case for case. The trigger is accumulated distance, not a per-frame delta — fixing the 1.0.0 ProMotion 120 Hz reliability issue.

## Bug Fixes

- **Spring reversals no longer stall (#228):** `SearchableBottomBarController.makeSpring` now carries in-flight velocity through retargets; reversing mid-morph no longer reads as a stall followed by a restart. Also benefits `GlassTabBar.searchable`.
- **Shared `ScrollController` crash fixed (#228):** The searchable and minimizable placements reading `ScrollController.position` now safely guard when multiple scroll views share one controller during transitions.
- **Premium glass shape no longer stranded during swipe-dismiss (#229):** `RenderLiquidGlassLayer` froze shader UVs under any uniform scale-down, which was correct for the CupertinoSheet push-back but wrong for a swiped `GlassModalSheet` whose backdrop holds still. A new internal `LiquidGlassSelfScaleScope` lets the sheet declare which arrangement it is; the push-back path is unchanged.

## Improvements

- **`GlassNavActionSlot.crossFades` — documented widget-equality behaviour:** Cross-fade detection uses reference equality; `const` icon widgets share an instance across routes and never trigger a spurious cross-fade. Documented in the API dartdocs and the navigation guide.
- **Multiple `GlassBarItem.menu` in one cluster — debug warning:** Using more than one menu item in a single cluster silently treated the extras as plain icons. A debug-mode `debugPrint` now surfaces this so developers see the constraint immediately rather than wondering why a second menu does not open.
- **`GlassModalSheet` fling velocity carried into the closing morph (#227):** A fast swipe no longer stalls at the release point — the closing droplet now starts at the speed the fling was running at rather than from rest.

## Documentation

- **`GlassModalSheet.peekSize` docs:** Clarified that `peekSize` accepts both absolute pixels (`> 1.0`) and a screen-height fraction (`≤ 1.0`), consistent with `halfSize` and `fullSize`.
- **New guide:** `docs/GLASS_NAVIGATION_TRANSITION.md` — setup (including `.router`), matching rules, a behaviour table, a direction section, and known limitations.
- **`ROADMAP.md`** — `GlassNavigationTransition` checked off; the "pinning becomes the default" trajectory and parity work recorded.

Thanks to [@JakeThomson](https://github.com/JakeThomson) for the navigation transition, modal sheet, tab bar scroll-to-minimize, and premium renderer fix improvements (#221, #223, #227, #228, #230).

---

# 1.0.0

## Major Milestone: General Availability

This release marks the **1.0.0 General Availability** of `liquid_glass_widgets`, delivering a stable, unified API surface, zero third-party dependencies, and production-grade iOS 26-style liquid glass with hardware-adaptive quality tiers (Metal, Vulkan, Skia, and shader-free fallbacks) across all supported Flutter platforms.

### New Features

- **`GlassTabBar.minimizable()` — SwiftUI `tabBarMinimizeBehavior` parity (#217):** A new named constructor that collapses the tab bar to a single selected-tab circle without requiring a search bar. `minimized` replaces `isSearchActive`, `onMinimizedTabTap` handles the restore tap, `minimizedBarHeight` shrinks both pills while minimized, and an optional `GlassTabBarTrailingButton` fills the trailing slot — exactly modelling `Tab(role: .search)` priority-visibility behaviour. Scroll-driven minimize is caller-controlled, matching the SwiftUI `.onScrollDown` pattern.
- **`GlassSearchBarConfig.showPill` (#217):** A new boolean on `GlassSearchBarConfig` (default `true`) that removes the search pill entirely and returns its width to the tab pill. Hiding is done by unmounting the pill and spring-scaling it at its slot — `Opacity` and zero-width leave a glass remnant fused to the tab pill on the shared blend layer; only absence can hide a grouped glass surface.

Thanks to [@JakeThomson](https://github.com/JakeThomson) for the contribution (#217).

- **`GlassModalSheet` morphs from a trigger button (#219):** `show()` gains `morphFrom` — the `GlassMorphAnchor` from a new `GlassMorphTrigger` wrapper — presenting the sheet with the iOS 26 liquid morph instead of the slide-up: the trigger empties, a glass droplet detaches and inflates as it travels, and lands as the sheet. Makes the sheet the second consumer of the Liquid Morph Engine after `GlassMenu`. `morphSpeed` tunes the spring.
- **`GlassMorphTrigger` / `GlassMorphAnchor` (#219):** The wrapper owns the trigger's key and opacity so the trigger can empty itself for the morph and take the closing bounce on its own ticker. `morphFromRect` remains for triggers that can't be wrapped, blooming from a point. The morph degrades gracefully to the slide presentation on Skia/web, `GlassQuality.minimal`, and `platformViewBackdrop`.

Thanks to [@JakeThomson](https://github.com/JakeThomson) for the contribution (#219).

### Breaking Changes & API Unification

- **Unified Navigation Surface (`GlassTabBar`)**:
  - Consolidated bottom navigation into `GlassTabBar` via named constructors: `GlassTabBar.bottom()`, `GlassTabBar.searchable()`, and `GlassTabBar.inline()`.
  - Removed legacy transitional shims `GlassBottomBar` and `GlassSearchableBottomBar`.
  - Tab items are now canonically represented by `GlassTab` across all tab bars.
  - Tab bar collapse types `GlassTabBarCollapseConfig` and `GlassTabBarCollapseDirection` have been **removed**. The collapse-to-extra-button pattern is not an iOS 26 design primitive and was unreliable on 120 Hz ProMotion displays. Use `GlassTabBar.minimizable` instead — it directly mirrors SwiftUI's `tabBarMinimizeBehavior(.onScrollDown)` with spring physics.
- **Modal Sheet Simplification**:
  - Removed deprecated `enablePeek` parameter from `GlassModalSheet`, `GlassModalSheet.show()`, and `GlassModalSheetScaffold`. Sizing and peeking behavior is now governed cleanly and declaratively by `detents` and `mode`.
- **Initialization & Setup Cleanup**:
  - Removed deprecated `respectsAccessibility` from `LiquidGlassWidgets.initialize()`. System accessibility preferences (Reduce Motion, Reduce Transparency) are now automatically detected and respected out of the box.
  - Removed deprecated `warmUpImpellerPipeline` from `LiquidGlassWidgets.initialize()`. Shader bytecode preloading is handled asynchronously and safely during app bootstrap.
- **Shader Quality & Scope Purge**:
  - Removed deprecated `usesBackdropFilter` getter from `GlassQuality`.
  - Removed deprecated `LiquidGlassScope.stack`, `GlassRefractionSource`, and `LiquidGlassBackground` in favor of `GlassPage` and `GlassBackgroundSource`.
  - Removed deprecated `GlassBackdropScope` stub.

### Documentation & Tooling

- Added comprehensive [Migration Guide](docs/MIGRATION_0.x_TO_1.0.md) detailing step-by-step code upgrades for 0.x projects.
- Updated documentation and all example demo screens for 1.0.0 APIs.

---


---

For pre-1.0 history see [CHANGELOG_ARCHIVE.md](https://github.com/sdegenaar/liquid_glass_widgets/blob/main/CHANGELOG_ARCHIVE.md) or the [GitHub Releases page](https://github.com/sdegenaar/liquid_glass_widgets/releases).
