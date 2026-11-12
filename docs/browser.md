# In-app browser

The browser is a self-contained UI pilot. It does not change the appearance of
other Kelivo pages. Open it from the chat attachment menu or chat tools menu;
desktop chat tools also contain an **Open browser** entry. On desktop this opens
a resizable browser beside chat; its expand action opens the full browser route.
Browser tool results return to the corresponding conversation's browser.

## Features

- Up to eight persistent tabs; address/search input, back/forward, reload/stop,
  page loading/error states, and tab overview.
- Bookmarks with editing and search; searchable history grouped by date, with
  individual removal and confirmed clearing.
- Search-engine selection, desktop website mode, tab restoration, history
  recording, Agent access, and clearing cookies/storage/cache.
- Downloads using website cookies, bounded redirects, progress, cancellation,
  opening completed files and removing download records.
- Find in page, copy link and opening a page in the system browser.
- A mobile toolbar floating over the webpage: back, address and more controls
  contract to a short address capsule while scrolling, and expand on return
  scrolling or a tap. When navigation history exists, the left control is a
  shared back/forward capsule. Desktop keeps tabs above the address row.
- Browser-only liquid glass, frosted and solid styles, saved in browser
  settings. Menus and controls use the selected material, without Material
  ink or the app's older press decoration. Mobile bookmarks, history, downloads,
  settings and tab overview are full pages. Desktop management uses dialogs;
  tab overview fills the browser content area with a preview grid and new-tab
  card while retaining the header and existing native page.

## Browser material and interaction

Android and iOS share the Flutter controls, menus, gestures and motion. There
is no separate UIKit button or UIMenu implementation. Apple platform views are
passive material renderers and WebViews; they do not own browser interactions.

The mobile webpage extends behind the floating toolbar, so the material has
real page content to sample. Collapsing the toolbar changes its own geometry;
it does not resize, replace or capture the WebView. The more menu opens from
the lower-right control. Mobile management uses full Cupertino page routes;
desktop uses dialogs rather than bottom sheets.

| Style | Apple native rendering | Flutter rendering |
| --- | --- | --- |
| Liquid glass | `UIGlassEffect` on iOS 26+; `NSGlassEffectView` on macOS 26+. Earlier Apple releases use native blur and do not reproduce the refractive material. | The vendored `liquid_glass_widgets` Impeller shader uses an edge-displacement lens derived from Telegram's legacy mesh. It leaves the center undistorted and disables chromatic separation. Android requests a texture-backed TLHC WebView so the shader can sample webpage pixels. |
| Frosted | `UIBlurEffect` / within-window `NSVisualEffectView`, with rounded clipping on the effect view itself. | A rounded, clipped backdrop blur with a translucent tint. |
| Solid | No native material host is created. | The same opaque Flutter surface on every platform; also the deliberate fallback when shader image filters are unavailable. |

The Apple bridge is a passive material underneath sharp Flutter text and icons.
It does not synthesize native touches. A light/dark tint on the system glass
keeps those Flutter foregrounds legible when webpage colors change. Each native
effect owns its rounded shape; Flutter opacity layers and ancestor masks are
avoided so UIKit can sample the live backdrop. Changing style removes the
previous style's clipping requirements. Native effects are reused during press
animation rather than recreated for every frame. Switching from solid keeps
a Flutter cover until the new material reports readiness, then fades only that
cover. Switching back covers the material before releasing its native host;
the foreground remains a single stable subtree.

`BrowserPress` supplies pointer, keyboard and accessibility actions. Mobile
touch expands the control, a drag stretches it toward the finger with bounded
displacement, and spring physics return it to rest. A local radial highlight
tracks the touch inside the rounded surface. Nested controls own their own
feedback; scrolling cancels an active control. Management rows use static feedback with
no press scaling or dragging. Standalone mobile icon/text buttons retain
spring and touch-light feedback; the navigation pair shares one pressed glass
capsule with two independent actions. Mobile switches use an oval glass thumb
and a ring-only highlight that leaves the center sampling the real track. Desktop mouse input uses hover,
pressed tint and focus without touch scaling or dragging. There is no ink ripple
or rectangular pressed overlay. Reduced motion removes geometric movement;
high contrast selects Flutter solid surfaces. When a native liquid/frosted
adapter is active, Apple accessibility settings may also make that effect opaque.

Touch menus prepare their source-sized material at zero opacity while keeping
the original More control visible. `BrowserGlass.onReady` waits for shader
preparation on the shader path, or native creation and queued parameter updates
on Apple, followed by a framework frame containing the host. Only then does
the menu start its animation and take over the source. This readiness signal
does **not** mean the GPU has presented the material. Cancellation, host removal
and replacement suppress pending starts; the original held pointer is acquired
synchronously and its early up/cancel events survive preparation. Solid uses
the Flutter frame path and needs neither a native material view nor a backdrop.
Back and More retain their State in `Offstage` only at fully collapsed progress
(`t >= .995`); the address is never offstaged. More's fixed 48 × 48 resting
anchor remains outside that subtree. While a menu owns a held pointer, its
zero-opacity source stays in the native view hierarchy so hiding the material
does not cancel the operating-system gesture.

On macOS, `BrowserWindowChrome` also owns a route-scoped keyboard bridge.
WKWebView or AppKit can consume Command shortcuts before Flutter receives
them, so a local key-event monitor forwards Cmd-F/L/T/W/R from the active
browser window to its Flutter page. It consumes the original event and ignores
autorepeat, preventing duplicate actions or Cmd-W closing the app window.
Covered browser routes stop receiving commands; queued callbacks recheck the
current route. This bridge receives operating-system keyboard events, not
commands from webpage JavaScript. Repeated Cmd-F focuses the existing find
query instead of toggling the panel closed.

The current touch response follows Telegram's custom `TouchEffect`: 20-point
long-side growth, bounded 24-point drag, reciprocal directional stretch and
separate press/release springs. A 300-point radial field contributes at most
10% white inside the control. Source constants and the distinctions between
Telegram's custom and native paths are recorded in
[the Telegram source audit](browser-telegram-reference.md).

Mobile scroll geometry is pushed from the actual main document, coalesced by
`requestAnimationFrame`. CSS pixels are converted using the rendered viewport
height. Twelve logical points of downward intent minimize the toolbar; six
points of reverse intent expand it. The top and bottom eight points also expand
it. A critically damped spring starts from the current presentation position
and velocity, so batched native callbacks never assign a new frame geometry
directly. Duplicate updates, metrics and scroll-end notifications do not restart
the spring. Navigation invalidates the old document's event stream.

Mobile menus morph from the actual painted bounds of the triggering control.
The silhouette passes through an ellipse before settling into its panel corners;
content scales and briefly blurs independently of the material. Companion
toolbar controls fade through the renderer's visibility parameter, preserving
their native view identity. A 320 ms hold keeps the original pointer through
menu creation; moving between rows and footer entries moves one selection
capsule, and release executes the current item once. An already open menu also
supports press-and-slide selection. Long, scrollable menus keep normal scrolling
instead. Cancellation and other fingers cannot execute the held selection.
The menu lives in a page-owned portal, supports system Back, and returns the
source control only after its closing morph completes. Closing partway through
opening continues from the visible shape. Grouped actions and a page-options submenu keep their
height bounded. The mobile submenu is a second layer anchored to its source row above a
receding parent; it clamps to the usable screen on short displays. Back restores
the parent. Mobile row icons sit 24pt from the outer surface and 12pt inside
the shared selection capsule, with matching footer selection insets. Desktop submenus open beside their source row, with
a hover corridor between the two surfaces. Desktop menus use 32-point rows and 256-point width, constrained
by available space; outside clicks and Escape dismiss them. Desktop panels are
centered, window-constrained dialogs. Desktop has compact tabs above an address capsule between navigation/action
groups. Closing a tab and reload use smaller icons than mobile controls. Desktop tab
overview keeps the native view mounted but hidden; selecting a card or entering
an address returns to it, and Escape dismisses the overview. Find controls
float at the upper right without resizing the webpage. The macOS browser route
uses wider traffic-light spacing aligned with its toolbar, restoring the
application's original spacing on exit. The embedded pane leaves window-control
spacing alone, and only takes native keyboard commands after focus or a pointer
enters it. Hidden panes stop listening. On macOS 26, a uniquely marked WKWebView
uses the public obscured-content inset API to scroll underneath the translucent
header without hiding website controls. Acknowledged native support is required
before underlap is enabled; other engines reserve header space. Native glass hosts include transparent room for AppKit's
shadow, avoiding rectangular clipping at the material's outer bounds.

## Agent and user control

Enable **Browser control** for the assistant in chat tools, then enable assistant
browser access in browser settings. Each conversation owns its tabs. A different
conversation cannot address those tab IDs through the tool. The website login
profile is shared by the browser, so tab ownership is not separate cookie jars.

**Ask AI about this page** returns to the visible tab's owning conversation and
appends a page task draft to its composer, preserving existing text and attachments. The user
sends the task to start the model. It neither enables tools nor submits a request
automatically. The entry uses the same effective assistant resolution as chat.
Idle browsing has no control banner or takeover command. A compact status chip
appears only for an action belonging to the visible tab's conversation or an actual pause;
allowing further actions only removes the pause gate. The standalone smoke
entry has no real chat/model session and reports that this entry is unavailable.

The `browser` tool offers navigation, snapshots, text/HTML/Markdown extraction,
element/coordinate actions, scrolling, keys, JavaScript, screenshots and tab
management. Routine actions use compact DOM snapshots with up to 4,000 characters
of page text by default, so confirmation text outside interactive controls can
be observed. `include_text: false` opts out. Agents must confirm the result from
page text or extraction before repeating a mutation. Requested screenshots
are passed as actual model image input through the existing typed tool-result
path, including conversation replay. Image and CSS viewport dimensions accompany
screenshots so coordinate actions can be mapped correctly.

Takeover, or touching a page while automation is active, invalidates queued
Agent work. Resume is explicit. Cancellation cannot reverse a web request or
script that has already run; such operations report an unknown outcome. Website
text is marked as untrusted content. This marker is not a security sandbox.

DOM-generated input is synthetic. Sites requiring trusted native input,
cross-origin frame interaction, CAPTCHA or embedded-browser-restricted login
require the user to take over, or use the system browser. Kelivo does not expose
an unrestricted remote debugging port or a native app command bridge to pages.
Website camera/microphone permission requests are currently denied; sites that
need those permissions must be opened in the system browser.

## Runtime and performance

`BrowserService` owns state and native engines independently of route lifetime.
Android uses Android WebView, iOS/macOS use WKWebView, and Windows uses WebView2
through `flutter_inappwebview` 6.1.5. Linux has an explicit unsupported state.
The resolved Windows plugin does not implement complete website-data clearing;
that control is disabled with an explanation before any tabs or cookies change.
Android, iOS and macOS support the complete clear operation.

Only three native views are retained. Other tab URLs remain available and are
reloaded on demand; an evicted page's unsaved DOM/form state is not serialized.
Inactive views pause media where supported, and detached idle engines expire
after 30 minutes. The browser state snapshot is atomically replaced, writes are
serialized, URL/title persistence is debounced, and history is capped at 2,000
entries. Downloads throttle progress notifications.

The service owns a separate native controller, and each mounted host keeps one
stable WebView widget. Widget disposal therefore does not disable background
Agent callbacks. Popup closure waits for platform-view detachment and attempts
to drain pending renderer tasks before releasing the native view. The renderer
acknowledgement is bounded to three seconds; this reduces the observed stale
focus/blur-message race but does not guarantee that every renderer task drains.

Popup families share WebKit script resources. Closing an opener removes its tab
and navigates its retained native context to `about:blank`; that context still
counts toward the three-view limit until its descendants close. Eviction and
shutdown release descendants before their shared owner. A family is evicted as
a unit, and its URLs subsequently restore as independent tabs. A popup is refused
when its family cannot fit in the bounded native pool.

Glass effects are bounded to individual controls and open panels. Shader
initialization is shared and occurs before the browser's first transition;
there is no screenshot loop or animated wallpaper. The native bridge coalesces
pending parameter updates and unregisters its channel and accessibility
observers on disposal. A visible active page caches one small JPEG preview on
load completion and refreshes before switching away or opening tab overview.
The capture requests snapshot width 440 and JPEG quality 70; Apple may encode
more pixels at its display scale. Decoding is capped at 640px wide and the
eight-tab quota bounds the cache. New navigation invalidates its image; URL,
renderer identity and document epochs reject late results. It never captures
frames continuously or wakes an inactive engine. These previews are separate
from the Agent's full-resolution screenshot tool.

iOS platform views do not support Flutter shader filters over WKWebView, which
is why Apple platforms use their native material. Android sets
`useHybridComposition: false` for both headless setup and the visible host,
requesting Flutter's texture-layer composition. TLHC has platform tradeoffs,
including fast-scroll and text-magnifier behavior; an emulator smoke test does
not establish their performance on every device or webpage. Windows retains
the WebView2 browser engine, but is not claimed to have equivalent optical glass.

The supplied `deliverable(1)` notes and Safari screenshots informed the floating
controls and motion direction. The optical implementation supersedes the
initial blur-and-rim prototype; it does not claim that a painted highlight is
refraction. Renderer provenance and local changes are recorded in
[the vendored package notes](../dependencies/liquid_glass_widgets/UPSTREAM.md).
Relevant platform references are [Apple's Liquid Glass overview](https://developer.apple.com/videos/play/wwdc2025/219/),
[UIKit custom glass](https://developer.apple.com/videos/play/wwdc2025/284/),
[menu guidance](https://developer.apple.com/design/human-interface-guidelines/menus),
[popover guidance](https://developer.apple.com/design/human-interface-guidelines/popovers),
[UIKit 2026 updates](https://developer.apple.com/videos/play/wwdc2026/278/),
[AppKit 2026 updates](https://developer.apple.com/videos/play/wwdc2026/289/),
[Flutter platform-view composition](https://docs.flutter.dev/platform-integration/android/platform-views)
and [Flutter shader filters](https://docs.flutter.dev/ui/design/graphics/fragment-shaders).
See [Agent design references](browser-agent-design.md) for OpenMinis and
upstream automation research.

## Verification

```sh
dart analyze --fatal-infos lib test
flutter test test/core/services/browser test/features/browser
flutter test test/view_image_provider_test.dart
KELIVO_PLAYWRIGHT_MODULE=/path/to/playwright node tool/browser_dom_smoke.mjs
flutter run -d macos --profile -t tool/browser_smoke.dart
flutter run -d <ios-or-android-device> -t tool/browser_smoke.dart
```

The native smoke entry uses an isolated browser store and an in-memory settings
database, without model credentials. It exercises native DOM input, clicks,
promises, screenshots, view transfer/form retention, background-tab Agent
input, session isolation, takeover/resume, persistence, invisible Agent
browsing, navigation/history and
cookie-authenticated redirect downloads. It writes `result.json` and a native
WebView PNG under its reported `browser-smoke-*` directory. Its frame timings
describe that scene and execution mode only; they do not establish physical
device battery, memory, thermal or third-party-site performance.

Widget tests cover mobile/desktop layouts, browser controls, settings, library
operations, material selection and reduced motion. Widget tests and the web
preview use a software fallback and cannot establish native optical fidelity.
Native material checks must include light/dark webpage content, colored content
behind a menu, style switching, and press/drag/collapse behavior. Programmatic
scroll callbacks validate the collapse state machine but do not prove the
behavior or performance of physical touch scrolling. Provider tests verify
screenshot pixels on streaming/non-streaming continuation and persisted replay
for the supported provider paths. Neither test suite constitutes a live
model-account test.

For native popup lifecycle checks, serve `tool/browser_popup_fixture` with
`python3 -m http.server 8764 --bind 127.0.0.1 --directory tool/browser_popup_fixture`.
Open `http://127.0.0.1:8764/` in the iOS simulator (Android emulator:
`http://10.0.2.2:8764/`). Tap the page's open and close buttons using real input.
The child must show **Opener preserved**; after it closes, the parent must still
show **Popup connected** without another parent request. Repeat and leave/reopen
the browser route to verify retained DOM state.

### Revised UI validation

#### iOS 18 physical-device follow-up (2026-10-17)

- The user reproduced severe jank/heat on **iPhone 14 Pro Max, iOS 18.2.1,
  self-signed Release IPA**. The supplied 96.87-second recording was inspected.
  Earlier iOS 26 simulator results do not establish performance on this device.
- The macOS workaround that kept three native renderers participating in paint
  had incorrectly applied to mobile too. Mobile now paints only the active tab,
  keeping inactive engines/state without their compositing work. A fully opaque
  management route also disables the underlying host through `TickerMode`,
  pauses its media and suppresses new preview requests. Transparent menus and
  incomplete route transitions keep the page available. iOS swipe-back remains
  enabled; hidden pages no longer sit behind the blank start page in the scene.
- URL and webpage keyboards use the window's stable safe area. The toolbar
  follows `max(safeBottom, keyboardInset)` through the complete dismissal,
  including 34, 20, 1 and 0 point insets, and stays expanded for native forms.
- Settings selects only its settings/capability values, and its route retains
  the content child on unrelated page notifications. Switch shader programs
  warm after the first browser frame; per-switch shader instances are created
  only for a pressed thumb. The tab edge blur keeps its two-pass gradient but
  reduces each axis from 49 to 25 samples and logical sigma from 14 to 10.
  The start-page grain is batched into one point draw rather than 650 circles.
- iOS 18's previous `liquid` and `frosted` branches both used the same ordinary
  blur. The legacy liquid material now adds stationary rim/sheen layers and a
  bounded shadow over live thin blur; frosted uses the denser system material.
  This is **not** iOS 26's refractive `UIGlassEffect`. There is no webpage
  snapshot loop or idle animation in this material, and corner paths are cached
  by geometry. The system glass path on iOS 26 remains separate.
- **327 browser UI/service tests passed** (`/tmp/browser-ios18-final-tests.log`),
  with fatal-info analysis of `lib test` clean, formatting and diff checks clean.
  The changed progressive shader compiled for Metal/GLES/Vulkan and retained
  its uniform/sampler interface. No iOS 18 runtime or connected physical phone
  was available locally; real-device temperature, frame pacing and the legacy
  material's appearance still require the user's Release-build verification.
- `flutter build ios --release --no-codesign --no-pub` passed
  (`/tmp/browser-ios18-release-build.log`). The unsigned device IPA is
  `build/ios/ipa/Kelivo-browser-ios18-20261017-unsigned.ipa` (43 MiB); archive
  integrity verification passed. SHA-256:
  `a6af4c783d8e5d9b5bc8b83d9f2ce413db52196c6cd60dc2bb03f6fe6b8a0fad`.
  No physical-device installation or temperature/frame-rate measurement was
  performed, and the full repository test suite was not rerun.

#### Pointer ownership, retained tabs and edge gestures (2026-10-16)

- The supplied 39-second desktop and 21-second mobile recordings were inspected
  alongside their source paths. The sidebar grip now paints its entire 6pt hit
  area. On macOS a gesture-scoped AppKit monitor owns dragging across native
  views and ends on mouse-up, cancellation or focus loss. It forwards to the
  same Flutter controller, keeping a single pointer stream and clearing both
  the engine's button state and Dart gesture state. Asynchronous capture binds
  to the original down timestamp, so stale cleanup cannot release a later press.
  Width updates no longer rebuild the BrowserPage subtree. Native cursor
  ownership covers the grip and the complete held gesture, including WebKit
  cursor-update events.
- Visited tabs keep keyed native hosts participating in composition. Offstage
  was insufficient: Flutter's macOS compositor removes unpainted NSView hosts.
  Hidden hosts now stay behind an opaque backing and the selected tab, with
  input, focus and semantics excluded. They remain eligible for the existing
  three-runtime eviction limit; retiring families leave acquisition before
  listener notification and detach before disposal. Insets remain leased to
  each retained WebView until presentation disposal, including blank-tab swaps.
  Desktop presentation handoffs use 180/150ms opacity-only transitions, with
  the last-view image covering asynchronous native attachment. Reduced motion
  switches immediately. Full-page title-row whitespace moves the desktop window;
  tabs and controls retain their own actions.
- Desktop menu dismissal keeps a fixed rectangle and fades its material and
  foreground over 110ms. Bookmark editor actions use actual text layout, with
  symmetric space for the centered title; Chinese and English Save labels are
  verified with rendered pixels. History clearing is a 44pt action beside the
  search field and retains its confirmation dialog.
- Mobile scroll observation tracks trusted touch start/move/end/cancel.
  Momentum and rubber-band recovery update the baseline without changing the
  toolbar. The top remains expanded; deliberate motion at the bottom expands
  it even when scrollY is clamped. Transparent gradients now protect the actual
  webpage's status-bar and toolbar edges. These are color gradients over native
  WebViews, not a claim of shader-based WKWebView blur.
- All **315** browser UI/service tests passed after the physical-mouse follow-up
  in `/tmp/browser-final-interaction-regression.log`. Full `lib test` fatal-info
  analysis passed (`/tmp/browser-final-interaction-analyze.log`). Native Swift
  checks cover press ordering and real WKWebView inset transfer, restoration,
  and weak-reference release. The injected
  JavaScript event-order harness also passed
  (`/tmp/browser-scroll-input-regression.log`). Full repository tests were not
  rerun. New lifecycle tests use an in-memory store to avoid mixing real file
  writes with fakeAsync. Two existing page tests now address the selected engine
  or hit-testable view explicitly: retained inactive renderers also remain in
  the tree, while the original state-identity and agent-takeover checks remain.
- Final macOS profile (235.7 MB), iOS Simulator debug and Android arm64 profile
  (85.3 MB) builds passed after the composition/inset/cursor follow-up. Logs:
  `/tmp/browser-final-interaction-{macos,ios,android}-build.log`.
  The iOS Simulator was updated in place and launched; the Chinese Save label,
  centered title and history search-row trash action were visually confirmed.
  No physical phone was installed. Android had no connected emulator in this
  run, so its evidence is a successful build rather than a fresh runtime check.
  The desktop app rendered both loaded tabs and retained the selected website
  on expansion. Follow-up physical-mouse testing confirmed repeated left/right
  drags no longer get stuck; native logs show matching releases for all five
  recorded gestures. App-local automation bypassed both the AppKit monitor and
  window event dispatch, so its synthetic drag results were not treated as proof
  of the physical-input path. The user's follow-up still reported cursor churn,
  tab flashes and abrupt docking; the composition, cursor and fade changes above
  address that feedback. The rebuilt desktop app was reopened, both existing
  website tabs loaded, and full-page-to-sidebar handoff returned the selected
  website successfully. The final build is left in the sidebar; native cursor
  feel and animation quality still need the user's physical-input feedback.

#### Fractional native layout, nested controls and site icons (2026-10-16)

- **347 focused tests passed** across browser UI/service and affected chat
  paths (`/tmp/browser-layout-repair-focused-final.log`). Fatal-info analysis
  of `lib`, `test` and both browser integration entries is clean. Full
  repository tests were not rerun. Initial new-test failures were corrected
  at their real boundaries: asynchronous native acknowledgement, widget-test
  service disposal/platform override cleanup, and tapping the actual address
  entry before checking keyboard focus. No product expectations were relaxed.
- The growing desktop black gap was reproduced in the running app: the same
  WKWebView's leading margin grew from 5.5pt to 9pt while its host bounds and
  obscured insets stayed correct. The macOS plugin's nested autoresizing-mask
  constraints accumulated pixel-alignment error under fractional sizes.
  `flutter_inappwebview_macos` 1.1.2 is vendored locally; public four-edge
  constraints pin the WKWebView to its immediate host. No global package cache
  was changed. The initial manual-frame candidate fixed only outer geometry
  and exposed an internal zero-size WebKit content view in the real app, so it
  was replaced. The native regression now checks both outer and internal
  content geometry across headless/zero-size transfer and 800 fractional
  resizes: upstream drifts up to 8.5pt, while four-edge constraints keep both
  viewports aligned and nonzero (`/tmp/browser-native-constrained-regression.log`).
- Divider movement now accumulates every pointer delta received before a
  layout frame. Full-page desktop browsing has an explicit sidebar action at
  wide and narrow widths. Route disposal completes before the retained view
  is attached to the pane, preserving the current document rather than reload.
  Presentation changes explicitly hand off the selected tab ID, including a
  manually selected tab from another chat or an unowned tab. This prevents
  conversation-based initialization from replacing it with a blank tab;
  agent ownership checks remain unchanged. All 59 page/panel regressions passed
  (`/tmp/browser-exact-tab-handoff-tests.log`).
  Compact desktop controls also paint their complete local rounded hit area
  at 1/255 alpha so AppKit's foreground paint regions include icon padding.
  Five-platform raster and click/cancel checks passed with the 22 glass tests
  (`/tmp/browser-control-footprint-tests.log`); mobile paint is unchanged.
- Press ownership separates child switches/buttons from their containing row,
  including held and disabled child controls. Search-engine selection uses
  the same grouped shape. The mobile bookmark editor is a complete page with
  top Close/Save actions and a grouped icon/title/URL form; desktop keeps a dialog.
- Submenus retain the recessed parent's material and readable text, masking
  only the area actually covered by the child panel. The parent no longer
  becomes an empty translucent slab. Native hosts and held-pointer paths stay
  mounted throughout entry and return.
- On iOS 26, the browser applies public WKWebView obscured content insets to
  put the webpage backdrop beneath the status bar while keeping fixed/sticky
  content legible. Older hosts keep a safe-area viewport. The start wallpaper
  always fills the screen. URL editing keeps the webpage behind the system
  keyboard until dismissal completes; webpage form input retains native
  viewport avoidance. Keyboard material itself remains system-owned.
- Site icons now load in the actual WebView session using image/canvas decoding
  (PNG/ICO/SVG), without a third-party favicon service or separate Dart HTTP
  session. The cache is bounded to 48 origins and 32KiB/64px per icon; persistence
  follows saved tabs/history/bookmarks. URL/generation checks reject stale
  results. Cross-origin icons without canvas permission fall back to the
  site's own favicon or local glyph. Tabs, start favorites, bookmarks, history
  and the editor share the cache.
- Complete iOS Simulator debug, macOS profile (235.6 MB), and Android arm64
  profile (85.3 MB) builds passed. Both simulators were updated in place;
  Android installation reported Success.
  Logs use `/tmp/browser-layout-repair-{ios,macos,android}-*`. After unlocking,
  the iOS app was launched and the final macOS constraint build was restarted.
  The Kelivo website rendered in the resized sidebar and full page; its actual
  favicon also rendered. A read-only native snapshot confirmed that the host,
  WKWebView, internal content view and clipping layer all had matching nonzero
  `(0, 0, 1404, 788)` geometry in full-page mode. Evidence:
  `/tmp/browser-view-geometry-constraints-final.log`. The final macOS profile
  build also passed (`/tmp/browser-final-hit-footprint-macos-build.log`) and
  was launched from this worktree. In the running app, the selected Kelivo
  website and its icon survived sidebar → full page → sidebar; the explicit
  dock action worked, and a subsequent divider drag kept the rendered page
  aligned with the sidebar edge. The app was left running in the chat sidebar.
  No physical phone was installed, and no subjective optical acceptance is
  claimed.


#### Menu compositing, progressive edges and control geometry (2026-10-16)

- **321 focused tests passed** across browser UI/service and affected chat
  entry/replay paths (`/tmp/browser-optics-polish-focused.log`). Fatal-info
  analysis of `lib`, `test` and both browser integration entries is clean
  (`/tmp/browser-optics-polish-analyze.log`). The repository-wide test suite
  was not rerun. Shader coverage includes actual switch-lens pixels and
  edgeWarp visibility; these are not subjective optical acceptance results.
- Desktop menus paint a continuous, near-transparent foreground footprint.
  This keeps the Flutter overlay cursor region continuous across text and
  padding above AppKit platform views. Selection registration is disabled
  inside the menu, and hover transfers focus instead of retaining two rows.
- The desktop tab row is 44pt with 32pt capsules and 6pt vertical clearance.
  Its address row is 40pt, with a 32pt field capped at 640pt, 12.5pt resting
  text and a 14pt reload glyph. The field shares the header's material instead
  of adding a second tinted native backdrop. Header inset is consistently 84pt.
- A hard clip bounds the embedded browser pane. The native bridge now honors
  non-elevated header surfaces without their 64pt shadow outset; floating
  controls retain their shadow. Resize tests cover retained pane identity,
  hit testing and clipped overflow. This fixes confirmed boundary handling,
  without claiming every black region in the supplied screenshots has one cause.
- Mobile tab cards scroll beneath fixed controls and safe areas. Two bounded
  progressive blur regions fade from the top and bottom; reduced transparency
  and solid mode use a tint gradient. The mobile switch uses a clear expanding
  lens with edge displacement, adapted from [Glass-HQ's MIT-licensed control
  thumb](https://github.com/Glass-HQ/liquid-glass). Lists stay stationary;
  group-end and bookmark feedback now match their clipping geometry.
- Android edgeWarp opacity now fades the final premultiplied surface, including
  its rim, to zero. Parent/submenu text handoff is staged to avoid two refracted
  labels during close. Native hosts remain mounted through the transition.
  The overall Apple native-material / Android shader split remains unchanged.
- Final complete-app builds passed for iOS Simulator debug, macOS profile
  (235.5 MB), and Android arm64 profile (85.3 MB). iOS was installed in place
  and launched; Android emulator replacement installation reported Success.
  The old macOS process was exited, the newly built app launched,
  and its browser opened in the chat sidebar. Build/install evidence uses
  `/tmp/browser-optics-polish-{ios,macos,android}-*`. Visual and gesture
  acceptance is left to the user; no extended recording or physical-phone
  installation was performed in this pass.


#### Mobile spacing, controls and cancelled navigation (2026-10-16)

- **312 focused tests passed**, including 46 Page tests, 45 menu tests,
  20 management/control tests and 28 engine/observer tests. Whole `lib`/`test`
  fatal-info analysis passed, followed by a clean check of the final navigation
  capsule changes. Logs: `/tmp/browser-mobile-polish-focused.log`,
  `/tmp/browser-mobile-polish-analyze.log`, `/tmp/browser-capsule-final-analyze.log`.
  The repository-wide test suite was not rerun.
- Final iOS Simulator debug, macOS profile (235.4 MB), and Android arm64 profile
  (85.3 MB) builds succeeded. iOS was installed in place and launched; Android
  emulator replacement installation succeeded. The newly built macOS process
  was restarted and its browser sidebar opened. Build/install logs use
  `/tmp/browser-mobile-polish-{ios,macos,android}-*`.
- Mobile tab actions now have equal 52pt side controls around an actually
  centered count capsule; Done explicitly uses a white check on blue. Search
  is a circular control that expands on demand. Management pages retain their
  own background and button material rather than inheriting the old app UI.
- Independent controls press their complete surface, including management Done
  and the shared Back/Forward capsule. List rows remain stationary. Focused
  geometry/gesture checks exercise both navigation halves, drag cancellation,
  action dispatch, light, narrow widths and enlarged text.
- WebKit `NSURLErrorCancelled` (`-999`, plugin `CANCELLED`) no longer replaces
  an otherwise valid page with an error or finishes a newer navigation waiter.
  Real main-frame network/HTTP failures remain errors; subframe failures and
  explicit Stop retain their own behavior. See Apple's
  [cancelled definition](https://developer.apple.com/documentation/foundation/urlerror/cancelled).
- The desktop profile app was actually launched and its chat-side browser was
  opened for the user. Visual acceptance remains with the user, without another
  prolonged recording/comparison pass.

#### Full management pages and desktop pane (2026-10-16)

- **301 focused tests passed** across browser UI, service/engine/tools and the
  affected chat entry/replay paths (`/tmp/browser-pages-panel-focused.log`).
  Fatal-info analysis of `lib`, `test` and both browser integration entries
  found no issues (`/tmp/browser-pages-panel-final-analyze.log`). The full
  repository suite was not rerun.
- Final complete-app builds passed: iOS Simulator debug, macOS profile
  (**235.4 MB**), and Android arm64 profile (**85.2 MB APK**). iOS was installed
  in place and launched as the full app; Android emulator replacement install
  reported `Success`. Logs use `/tmp/browser-pages-panel-{ios,macos,android}-*`.
  No physical phone was installed or updated.
- The iOS simulator native-renderer integration passed held-pointer selection,
  cancellation, native document scroll events, layered submenu Back, full-page
  management and switching all three materials while keeping the active tab.
  `/tmp/browser-pages-panel-ios-integration.log` records that run. Its first
  attempt used a wrong English test label ("Find in page" versus "Find on
  page"); correcting that assertion passed the unchanged behavior. Later
  desktop-only overview/focus changes are covered by the 45-test Page run.
- Mobile management now uses full routes, with an oval glass switch and static
  row feedback. Desktop overview fills its content area rather than opening a
  dialog, and keeps the native page mounted underneath. Active visited pages
  provide bounded, on-demand thumbnail caches for the preview cards.
- Review found and fixed sidebar shortcut activation without actual focus,
  hidden pane pointer handling, late initialization after disposal, and lost
  Flutter keyboard focus when opening the desktop overview. The related
  focused regressions passed without bypassing those paths.
- The user explicitly chose to judge visual quality and operation feel. No
  additional manual recording, visual acceptance claim, physical-device
  installation or new real-device frame-rate claim is part of this revision.
  The historical optical/motion recordings below predate these changes.

#### Retained-controls revision (2026-10-16)

- The latest combined run passed **246 focused tests**, and fatal-info analysis
  of `lib`, `test` and both browser integration entries found no issues. The
  scoped page run passed **37 tests**, included in that combined result. Logs:
  `/tmp/browser-telegram-retained-final-focused.log`,
  `/tmp/browser-telegram-retained-final-analyze.log`, and
  `/tmp/browser-telegram-retained-ios-page-tests.log`. The full repository
  test suite was not rerun. Final complete-app builds passed for iOS Simulator
  debug, Android arm64 profile (**85.2 MB APK**) and macOS profile (**235.1 MB**).
  iOS was installed in place and is the retained version used for the real
  long-press recheck; Android `adb install -r` reported `Success`. All retained
  final build/install commands completed successfully. Earlier three-platform
  results below remain historical checkpoints, not additional acceptance runs.
- The retained change keeps Back/More State only when fully collapsed
  (`t >= .995`) and keeps More's resting anchor at 48 × 48 outside Offstage.
  The address has no Offstage wrapper, and zero opacity while the menu is open
  does not remove the source platform layer.
- An intermediate optimization also offstaged that source during menu opening.
  Actual CUA 700ms long presses exposed an operating-system pointer-cancel
  regression: the menu opened then closed automatically, while tap-open stayed
  visible. **That menu-period Offstage change was withdrawn.** Widget tests and
  native-renderer integration with synthetic Flutter pointers had not exercised
  this OS cancellation path; their passing results did not cover it.
- After the rollback, actual CUA **700ms long press remained open**, and dragging
  inside the open menu across rows to the Bookmarks footer reached Bookmarks.
  The [retained long-press screenshot](../build/browser_validation/telegram-ios-retained-longpress.png)
  preserves the open state. This verifies recovery of those real input flows,
  not smooth frame delivery or physical-device behavior.
- Closing/scroll geometry remains unresolved. The readiness recording below
  retains its close discontinuity. The later
  [Offstage diagnostic scroll audit](../build/browser_validation/telegram_offstage_diagnostic_audit/review.md)
  examines only the final ±100px fixture actions, whose collapse implementation
  is retained: **348 → 140px** at **347.755 → 347.758333s**, and expansion
  **215 → 378px** at **379.310 → 379.325s** in 600px-wide decoded frames. Its
  menu portion is a withdrawn regression version, not delivery evidence.
  These image steps do not identify a thread-stall cause. Final visual and
  performance acceptance is still **not achieved**.

#### Readiness revision (2026-10-16)

- The readiness checkpoint passed **245 focused tests**; fatal-info analysis of
  `lib`, `test` and both browser integration entries found no issues. This
  supersedes the 235-test checkpoint below and includes preparation/late-ready
  cancellation and source-visibility checks. Logs:
  `/tmp/browser-telegram-ready-final-focused.log` and
  `/tmp/browser-telegram-ready-final-analyze.log`. The full repository suite
  was not rerun. Final complete-app builds passed for **iOS Simulator debug,
  Android arm64 profile and macOS profile**. The iOS simulator app and Android
  APK were installed in place without uninstalling or clearing their data;
  the final macOS profile app was launched. Build/install commands completed
  successfully, with logs under `/tmp/browser-telegram-ready-final-*`.
  This establishes build/install status, not frame-rate or visual acceptance.
- Native interaction integration passed again on both iOS and Android. The
  reports confirm trusted DOM scroll updates, real `scrollend`, collapse and
  expand, cross-row/footer held selection, exactly-once release, cancellation
  without action and release-in-place followed by a tap. Reports:
  `build/browser_validation/telegram-ios-ready-integration.json` and
  `build/browser_validation/telegram-android-ready-integration.json`. iOS used
  the passive native material; Android reported shader-filter support. These
  are renderer/interaction contracts, not physical-touch or performance results.
- Actual CUA checks in that checkpoint's complete macOS **profile** app started with
  a native webpage input focused. Cmd-F opened the floating find panel;
  repeating it preserved the query and returned focus to that field. Cmd-L
  focused the address, Cmd-T created exactly one test tab, Cmd-W closed only
  that tab while the window remained open, and Cmd-R reloaded the local page.
  The [find-panel screenshot](../build/browser_validation/telegram-macos-shortcut-find.png)
  records its visible state. These runtime checks establish the native-focus
  shortcut behavior, not animation smoothness or general website reliability.
- The new complete-app [readiness recording](../build/browser_validation/telegram-ios-ready.mov)
  uses the same **700ms long press** for the first opening after launch and a
  repeat in the same instance. Sequential source-frame inspection shows
  circle → lifted ellipse → larger blurred ellipse → sharp panel in both.
  The predecessor's first-open bare ellipsis → whole panel sequence was not
  reproduced, and no bare or duplicated ellipsis was observed. The first
  opening still has one blank-circle frame at **22.126667s**, with the ellipsis
  returning at **22.161667s**. This observation supports improved opening, not
  a claim that all handoff defects or cold-start work are eliminated.
- Closing is still inconsistent in that recording: adjacent frames at
  **105.536667 → 105.545s** change from an almost full panel to a small lens.
  The first closing's initial changed frame is already a medium ellipse, so
  its full timing cannot be reconstructed. The predecessor's approximately
  247ms complete return is historical evidence and does not make these two
  closes pass. Final visual/performance acceptance remains **not achieved**.
- This recording's buttons request **±100 CSS-pixel smooth scroll**, confirmed
  in `build/browser_validation/site/index.html`; the old ±480 fixture is
  preserved as `site/scroll-fast-reference.html`. Product travel (54) and the
  motion curve did not change. Collapse still records approximately **348 →
  140px** at **141.350 → 141.353333s**; expand records **140 → 188 → 282 → 317 →
  378px**. These are surface bounds in 600px-wide decoded images, not CSS sizes
  or measured thread stalls. The changed input prevents treating these clips
  as a matched scrolling performance before/after. No physical scrolling was
  performed. [PTS contacts and review](../build/browser_validation/telegram_ready_audit/review.md)
  and the [8.15s, 1× edited clip](../build/browser_validation/telegram-ios-ready-edited-normal-speed.mov)
  preserve the evidence; the clip removes idle time with six documented cuts.
- The preceding [235-test-build recording](../build/browser_validation/telegram-ios-latest.mov)
  is retained as historical evidence in its
  [review](../build/browser_validation/telegram_latest_audit/review.md). It had
  one long-press opening and one click opening, a roughly 247ms multi-frame
  outside close, and ±480px fixture scrolling. It cannot verify this readiness
  revision or provide a matched scrolling performance comparison.

#### Telegram-derived interaction revision

- The preceding capsule/address checkpoint passed **235 focused tests** across browser UI/engine/service,
  screenshot provider replay, chat integration and the five shader lens
  tests. This includes held-pointer ownership, source and open-menu slide
  selection, source handoff, interrupted closing and the global haptic switch.
  Final fatal-info analysis of `lib`, `test` and both browser integration
  entries passed, as did scoped formatting and `git diff --check`. The full
  repository test suite was not run. This supersedes the earlier 231-test
  checkpoint and includes the three final address-bar regressions and the
  actual-shader capsule-equivalence check. Logs:
  `/tmp/browser-telegram-final-ui-tests.log` and
  `/tmp/browser-telegram-final-ui-analyze.log`. Complete builds passed for iOS
  Simulator debug, Android arm64 profile and macOS profile at that checkpoint;
  Android was installed with `adb install -r`. These precede the readiness
  revision above.
- Source handoff corrections at that checkpoint hid More immediately while retaining its
  element/native-view identity, and retargeted closing toward its current
  unpressed 48-point bounds instead of the initial pressed bounds. Host text
  measurement is outside the opacity/motion builders, and unused drag-return
  tickers are no longer created during disposal. The combined menu/page checks
  passed **62 tests** at that checkpoint. The readiness revision now delays
  source hiding until material preparation completes. The later recordings
  above preserve remaining visual discontinuities; tests alone did not prove
  the recorded return or collapse smooth.
- Separate focused checks also passed **35 menu/shader tests** and **41 page/surface-control
  tests**. These are overlapping scoped runs, not additional tests to add to
  235. The last three page regressions cover a long domain, 3× text scaling,
  and stable address material/text weight through collapse and expansion.
  The collapsed capsule's target width is capped at its expanded width, so a
  long domain or large text cannot make it grow during collapse. The address
  surface stays on the regular material and the label stays at `w500`; font
  size interpolates continuously from 16 to 13 instead of changing material
  or weight at the collapsed threshold. These widget checks preserve address
  and WebView identity; they do not establish native visual acceptance.
- The iPhone 17 / iOS 26.5 simulator integration test ran the real WKWebView
  and passive glass renderer with isolated in-memory settings and temporary
  browser storage. Actual DOM scroll/update/end events drove collapse and
  expansion. Flutter test pointers held the menu open, crossed rows and footer
  (checking the selection's actual global bounds), released exactly once,
  cancelled without action, and released in place before tapping settings.
  This is native-renderer integration evidence, not physical-touch or device
  performance evidence. Report:
  `build/browser_validation/telegram-ios-integration.json`.
- The same flow also passed on the Android API 36 emulator in **profile mode**.
  The runtime reports shader image-filter support and the test found the
  `AdaptiveGlass` renderer, so this run exercised the enabled edge-warp path
  rather than the solid fallback. Report:
  `build/browser_validation/telegram-android-integration.json`.
- Complete-app CUA interaction confirmed long-press opening, release in place,
  dragging an open menu from a row to the Bookmarks footer, and outside dismissal.
  `telegram-ios-interactions.mov` and its explicitly cut, normal-speed excerpt
  are diagnostic evidence, **not final visual acceptance**: sequential inspection
  still found abrupt menu close/collapse frames and an overlapping source icon.
  The source handoff has since been changed and covered by regressions as
  described above; the old recording cannot verify the revised appearance.
- A fresh debug simulator timeline isolated an early closing frame with
  **63.609 ms** in Metal `waitUntilScheduled`, before portal removal. A separate
  first-menu layout took **91.465 ms**, including only **3.368 ms** of foreground
  JIT work; the trace does not identify the remaining child-layout cost. The
  text-measurement/ticker cleanups do not establish a fix for those stalls.
  The first material capture was interrupted when the Mac locked and was
  excluded from comparisons. A later capture lost menu phase boundaries to
  the timeline ring buffer; it is retained as partial and is not a menu baseline.
  Complete replacement captures are described below. All VM timeline flags
  were restored. A matching CUA drag also failed to scroll Safari; it is not
  treated as a Kelivo-only bug. Physical finger scrolling remains unverified.
- `integration_test/browser_motion_bench.dart` has now completed matched before
  and after runs on the iPhone 17 / iOS 26.5 debug simulator. Each has **36/36
  complete phases**: three materials × three measured rounds × menu open,
  menu close, collapse and expand, after one warm-up per material. Each phase
  has a separate trace; the 2-second FrameTiming drain is outside those traces.
  The protocol fields match. The only product difference in this pair is the
  menu's capsule-stage radius: while `corners == 0`, a constant `1000` replaces
  a width-derived radius so native capsule configuration can be reused. Every
  renderer still clamps it to half the shorter side, and the final rounded
  panel transition is unchanged. **18 actual-shader geometry comparisons**
  (three sizes × DPR 1/2/3 × two shape types) are byte-for-byte equal.
  Earlier no-op layout and geometry-cache guards were already present in both
  captures; they are not additional A/B variables. The later address-bar
  corrections are covered separately above.
- The matched probe does **not** establish an overall stall reduction. Liquid
  menu-open `waitUntilScheduled` max changed from **47.033 to 13.181 ms**, but
  after still contains **44.144 ms** in frosted round 3 menu-open, **35.597 ms**
  in solid round 3 menu-close, and **28.713 ms** in liquid round 1 expand. The
  largest after root layout is **17.088 ms**, including a nested BUILD of
  **11.472 ms** with **3.045 ms** old-generation GC; the largest Animator span
  is **23.971 ms**. Submit, wait, layout and Animator spans are analyzed
  separately, never summed. There was no Compiler stream in this probe, so
  unexplained time is not attributed to JIT. Three rounds provide descriptive
  observations, not causal or statistical significance; this warm standalone
  fixture is neither a matched comparison with the older complete-app traces
  nor a physical-device performance result. Phase completeness, per-phase
  count/max/P90, and exact outlier windows are retained in the
  [comparison report](../build/browser_validation/complete-before-after-comparison.md)
  and [JSON](../build/browser_validation/complete-before-after-comparison.json).
- To repeat the material probe, run
  `flutter drive -d <simulator> --keep-app-running --no-dds
  --driver=test_driver/integration_test.dart
  --target=integration_test/browser_motion_bench.dart`; the existing driver
  writes `build/integration_response_data.json`. Preserve that file under a
  per-run name before the next run. The latest source inputs are
  `build/browser_validation/telegram-ios-materials-complete-before.json` and
  `build/browser_validation/telegram-ios-materials-complete-after.json`.
  SDK FrameTiming summaries cover whole rounds including the drain, not
  individual phases. **Both archived captures used the native carrier for
  Apple solid**; they compare materials, not carrier versus carrier-free
  composition. The readiness revision's Flutter solid path is newer and was
  not measured in that pair. Current recordings and the remaining acceptance
  failures are documented above.
- Native validation exposed two repaired lifecycle defects: a same-position
  scroll update after `scrollend` could overwrite the target before the next
  Flutter frame; and an unnecessary initial `about:blank` navigation could
  race `loadHtml`, clear `hasContent` and suppress mobile chrome updates.
  Both received failing regressions before their fixes. The integration test
  waits for the visible viewport geometry before starting smooth scrolling;
  scrolling during headless-to-visible transfer is not a stable test setup.
- **Validation incident:** early `flutter drive` runs used its default cleanup,
  which uninstalled Kelivo from this iOS simulator and removed its prior data
  container. No matching task backup or local Time Machine snapshot was found;
  that prior simulator data has not been recovered. The physical phone was not
  touched. Later runs use `--keep-app-running`. The Android emulator's existing
  persistent data was archived locally with mode 0600 before its integration
  run. Reinstalling the full application does not restore deleted simulator data.

#### Shared interaction and desktop layout revision

- **188 focused tests** passed across browser UI/engine/service, screenshot
  provider replay, tool registration, notification navigation and chat draft
  switching. Full `dart analyze --fatal-infos lib test` passed. The full
  repository suite was not rerun for this revision.
- Android and iOS use the same Flutter menu morph, pressure/drag, touch-light,
  and material-visibility logic. Tests cover intermediate shape/content
  transforms, rounded touch selection, fixed desktop pointer shape, native
  material identity, fallback fade pixels, reduced motion and accessible actions.
- After the screen was unlocked, complete-app interaction checks passed on
  macOS and the iOS simulator: browser entry, both branches of the AI permission
  flow, and returning to the conversation that owns the visible tab with a URL
  draft. The draft was not sent automatically. The centered desktop toolbar,
  wider traffic-light spacing, equal-width tab strip and floating find panel
  were also visually inspected.
- macOS interaction checks verified the menu's 64-point shadow without clipping,
  outside-click dismissal, and webpage input through the transparent part of the
  native host (`Edge click passed` in the fixture). These are runtime interaction
  checks, rather than conclusions inferred from widget tests.
- The earlier normal-speed, complete-app iOS recording was reviewed at its actual source
  frame timestamps. It shows the More button's internal press highlight and
  rounded expansion, menu geometry progressing from a circle through an oval to
  a panel, and text scaling from blurred to clear. No old rectangular press
  background or Material ripple was visible in the reviewed frames. Closing
  appeared quick, with recording gaps limiting precise timing conclusions.
  Fixture **Scroll** buttons exercised toolbar collapse and restore; physical
  finger scrolling and drag-follow behavior remain unverified.
- That recording contains an abrupt first-collapse size change. A clean runtime
  timeline subsequently identified a **141.807 ms** main-thread Metal
  `waitUntilScheduled` stall; the corresponding build and raster work measured
  **7.089 ms** and **4.907 ms**. After warming, four callback-driven rounds had
  approximately **16.7 ms** callback gaps. This is simulator diagnostic evidence,
  not a physical-device or profile-mode performance result. The cold stall has
  **not been fixed**.
- Stable toolbar slot keys fix a separate remount defect when an overlay is
  inserted. A stable glass radius of `1000` and cached iOS capsule configuration
  reduce redundant updates. Neither change establishes a fix for the recorded
  cold-collapse jump or the Metal stall.
- The final installed app's [normal-speed iOS recording](../build/browser_validation/ios-final-shared-ui.mov)
  was sequentially decoded. Both fixture-button collapse/restore rounds completed.
  The earlier 360-to-151-pixel jump was not reproduced exactly, but adjacent
  frames still show approximately 378-to-226 and 360-to-224-pixel changes before
  further intermediate widths (measured in 600-pixel-wide decoded frames).
  [The two-round contact sheet](../build/browser_validation/ios_final_audit/collapse-both-rounds.jpg)
  preserves this remaining visual discontinuity. These local `build/` artifacts
  do not establish a cold-stall fix, physical finger-scroll behavior, or device
  performance.
- AI actions use the visible tab's owner when the browser switches between
  conversations. A cross-owner touch test verifies interruption of the actual
  visible page's action. Delayed draft restoration tests verify that an A task
  never enters B's composer and is restored when the user returns to A. The first
  real model request returned **HTTP 503 `model_not_found`** because the provider
  had no available channel for the selected model. A subsequent iOS request to
  an already configured `ling-3.0-flash` model did fill the test field and click
  Apply; the visible page showed **Hello browser qa**. Its final answer incorrectly
  reported no change, exposing the default snapshot's omission of ordinary page
  text. Snapshots now include bounded text by default, with an explicit opt-out;
  19 Chromium DOM checks cover this observation contract. After the rebuild,
  one continuation ended without a final answer after reopening the page. A
  subsequent bounded retry completed the task: the model filled **browser qa two**,
  clicked Apply and correctly reported **Hello browser qa two**. The final tool
  call was a snapshot with no `include_text` override. Opening the same browser
  confirmed the displayed result matched the model's answer. Local evidence:
  [model answer](../build/browser_validation/ios-live-agent-answer-final.png) and
  [actual webpage](../build/browser_validation/ios-live-agent-result-final.png).
  This establishes one real-provider local-page flow, not general website or
  model reliability.
- The supplied 49.5-second reference recording was inspected at 8 frames/second
  to compare shape, content clarity and relative motion. This is visual reference
  evidence, not a claim of recovered Apple timing constants or pixel equivalence.
- Final complete-app builds without diagnostic code passed for macOS (profile),
  the iOS simulator (debug), and Android arm64 (profile). The final iOS app was
  installed and launched from Home. The Android package was installed with data
  preserved. All three complete-app builds passed again after the snapshot-text
  correction; iOS and Android were reinstalled without clearing app data, and
  the final macOS app was restarted. Android native smoke results below precede
  this last correction; the final Android package has build/install evidence,
  without a new manual gesture or optical-material acceptance pass.
- A signed iOS device profile build also passed, including deep/strict signature
  verification (`build/ios/iphoneos/Runner.app`, 129.6 MB). The paired iPhone 14 Pro
  Max already has Kelivo 1.3.1 installed. Installing this worktree build on that
  physical phone was declined by the user, so it was not installed. Further
  investigation stays on simulators; building the package establishes no
  device-performance result.
- The earlier Android profile native smoke for this revision passed navigation,
  DOM input and click actions, screenshots, conversation isolation, takeover,
  retained and headless views, persistence and authenticated download. Its
  42 fixture frames recorded build P90 2.565 ms and raster P90 24.964 ms. That
  includes fixture startup and does not establish smooth sustained scrolling,
  menu animation, or physical-device performance. Both Apple-platform native
  browser smoke runs also passed before the final rebuilds.

#### Earlier UI correction

The following checks cover the second UI correction (2026-10-15):

- All **126 focused tests** passed: browser service/engine/UI, material and
  touch feedback, menu geometry and closing progress, keyboard/accessibility
  activation, nested press ownership, cancellation on scroll, 320-point large
  text layouts, macOS title controls, panel dismissal, and provider screenshot
  continuation/replay. Full `dart analyze --fatal-infos lib test`, formatting and
  whitespace checks passed. The full repository suite was not rerun in this pass.
- iPhone 17 / iOS 26.5 simulator: the final normal-speed native smoke passed.
  UI inspection verified centered collapsed text, compact grouped/submenus,
  accessibility clicks and outside dismissal. A native screen recording with
  the optional smoke-only `BROWSER_SLOW_MOTION` flag was inspected in intermediate
  frames for press, menu growth/return, and native-scroll-driven collapse. This
  diagnostic flag is off by default and is absent from the final running build.
- macOS profile native smoke passed. Visual inspection confirmed clear space for traffic lights, compact
  desktop menu density, outside-click dismissal of both menus and settings,
  and removal of rectangular material clipping around the address field.
- A separate review caught and repaired the mobile find bar's missing material
  over dark webpages. Its regression check also verifies that showing the bar
  does not resize or remount the webpage.
- Android 16 / API 36 profile native smoke passed after repairing an additional
  HTML identity race: late/repeated `data:` load-start callbacks must not replace
  the explicit rendered document. Two regressions first reproduced the failure
  and then passed; real navigation and same-URL POST still replace the document.
  The initial retry was blocked by an unresponsive emulator/ADB guest path;
  a cold boot retained its user data and restored the test environment. The
  final runtime used Android WebView 134.0.6998.135. Its 42-frame smoke recorded
  build P90 1.812 ms and raster P90 16.183 ms; these fixture timings are not a
  steady-state animation or physical-device performance measurement.

Apple's 2026 guidance was consulted, but these runtime checks use iOS/macOS 26,
not a 27 SDK or runtime. The earlier optical rewrite results below are historical
and are not measurements of the final interaction changes.

#### First optical rewrite checks

- `dart analyze --fatal-infos lib test`: no issues. Formatting and diff checks
  passed. The final focused run passed **104 tests**, including browser
  service/UI, material selection, 320 px large-text settings, stable address
  and WebView identity during collapse, and provider screenshot continuation
  and replay. The earlier full-suite result below was not rerun for this UI pass.
- iPhone 17 / iOS 26.5 simulator: native browser smoke passed. Visual checks
  covered light/dark webpages, webpage colors through glass controls and menus,
  native-scroll-driven collapse, all three materials, rounded frosted surfaces,
  and saving the selected material. Press/drag physics and reduced motion have
  widget-test coverage; physical-device touch performance remains unmeasured.
- Android 16 / API 36 emulator, profile: the full native smoke passed, including
  visible and invisible Agent rendering, HTML identity persistence, view transfer,
  takeover, history and authenticated downloads. The visible texture-backed page
  and its optical toolbar were inspected. A diagnostic run confirmed Android's
  `about:blank` callback / `data:` current-URL alias; temporary tracing was removed
  after fixing its false load timeout. That run recorded 68 frames, build P90
  5.214 ms and raster P90 20.888 ms; this includes test startup/actions and is not
  a steady-state scrolling benchmark or a physical-device frame-rate guarantee.
- macOS, profile: the complete native smoke passed; the native material and
  centered settings dialog were inspected. Its fixture recorded 68 frames,
  build P90 1.100 ms and raster P90 8.663 ms.

### Baseline validation before the optical UI rewrite (2026-10-14)

These results were recorded for the first browser implementation, before the
native glass bridge, texture-backed Android composition and new toolbar/menu
were introduced. They establish the earlier feature/lifecycle baseline, not
fresh optical or performance validation of the revised UI.

- Android 16 / API 36 emulator, debug: the complete native smoke passed,
  including Agent input after a visible tab is detached.
- iPhone 17 / iOS 26.5 simulator, debug: the native smoke passed. Real pointer
  input in the full app also verified popup opener identity, repeated child
  closure without parent reload, route reentry, and child reload/find after
  closing its parent. The final full iOS simulator app built and launched.
- macOS 26.5.2, profile: the native smoke passed. Its 92 recorded frames had
  build P90 0.858 ms and raster P90 2.125 ms for this fixture only.
- Chromium 155.0.8059.79: all 15 DOM automation checks passed.
- Focused lifecycle tests: 21 passed. UI tests: 15 passed, including 320 px
  English layout at 3x text scaling. Static analysis and diff whitespace checks
  passed.
- Final full suite: `flutter test --no-pub --concurrency 4` passed all 7,918
  tests in 10m54s after the source freeze. An earlier run during development had
  five failures; its affected files passed individually before this clean run.

No physical Android/iOS device, live model account, or Windows runtime was used
for these checks. Emulator debug timing is not a device performance benchmark.

## iOS 18 follow-up: keyboard, history, tab motion and refraction (2026-10-17)

This revision addresses the next physical-device report (iPhone 14 Pro Max,
iOS 18.2.1, self-signed Release). The supplied phone clip shows the webpage
resizing on URL-keyboard dismissal; the screenshots also show parent menu
text erased outside its child and clipped tab-overview controls during return.

- URL keyboard ownership now lasts through the actual final zero-inset frame.
  Tapping the webpage no longer switches Scaffold avoidance on mid-dismissal.
  Native webpage form keyboards retain their separate existing avoidance path.
- Chrome consumes finger direction without waiting for coalesced WebKit scroll
  offsets, and avoids counting both reports for one movement. Released momentum
  and rubber-band recovery do not create fresh collapse intent.
- Native history availability refreshes at page commit and after back/forward.
  Sequenced queries prevent a delayed old result from overwriting newer flags.
  Forward exists only while available; one retained navigation material changes
  from 48 to 84 points over 220 ms, moving the address continuously with it.
- Flutter-only start, settings and tab pages explicitly use the Flutter glass
  renderer. They no longer create UIKit backdrop hosts inside moving routes.
  Actual WKWebView chrome retains native material. Shader programs are prewarmed
  once; there is no idle capture/ticker loop.
- Mobile tab navigation uses a retained preview zoom between the full page and
  the actual visible card. A single preview refresh gets at most 100 ms before
  opening; if no fresh image arrives, opening fades instead of zooming an old
  scroll position. New/offscreen cards also fade. Edge-back cancellation,
  reduced motion and a later active card in a long grid are covered by tests.
- The submenu no longer subtracts a sibling portal's geometry from parent text.
  Normal compositing covers only the rows behind the child material.
- iOS versions earlier than 26 use public UIKit blur with stationary edge
  lighting for liquid material. The private Core Animation mesh implementation
  was removed after App Store validation rejected its non-public API usage.
  There are no screenshot or display-link loops. iOS 26 keeps its system glass
  branch; reduced transparency and high contrast still use opaque material.

Original validation (before removing the legacy mesh): 347 focused browser
UI/service tests passed, fatal-info analysis
of `lib test` is clean, formatting and `git diff --check` pass. The full
repository Flutter suite was not rerun. C mesh checks passed with sanitizers;
a native UIKit runtime probe successfully created/reused the legacy mesh and
checked all theme/clear combinations on iOS 26.5 Simulator. A separate native
visual probe displayed live checkerboard/color-line edge distortion with
legible light/dark foregrounds; its image is
`build/browser_validation/ios18-legacy-mesh-probe.png`. The disposable probe app
was removed after inspection, without touching Kelivo data. The main simulator
app was updated in place: the parent bookmark row remained visible with its
submenu open, and the tab Done control rendered fully. This does not establish
physical iOS 18 rendering, frame rate or thermal improvement.

The unsigned Release build succeeded (`Runner.app` 113.2 MB). Self-signing
artifact: `build/ios/ipa/Kelivo-browser-ios18-20261017-r2-unsigned.ipa` (43 MiB).
Archive integrity passed; SHA-256:
`4018d2edf714e04b2f8e1fa2016ccc5279983dc7274f9a92a234924c505d694c`.
No physical-device installation or signing was performed. No commit or push.
Logs: `/tmp/browser-ios18-round2-final-all-tests.log`,
`/tmp/browser-ios18-round2-final-analyze.log`,
`/tmp/browser-ios18-round2-release-build.log`.

## iOS follow-up: tab raster flight and native scroll ownership (2026-10-18)

The next device report identified remaining tab/management jank, yellow text
underlines during the start-page flight, intermittent chrome gesture loss,
wallpaper escaping a swiped route, and overly hard legacy-glass rims.

- Tab flights reuse the actual start page's bounded raster, or a fresh webpage
  preview prepared when the menu opens. Tapping Tabs no longer waits for a
  screenshot. The card and flight share one decoded image; the overview does
  not capture again. Missing/stale previews fade rather than zoom stale pixels.
  Fallback content has explicit Material typography. The existing card zoom,
  cancellation and reduced-motion paths remain.
- New native WebViews are created after route entry, and after a covering
  management route has fully finished returning. Bookmark navigation and new
  tabs also wait for the management return. Retained WebViews use the already
  decoded preview while native composition reattaches. Shader preparation is
  limited to the used renderer programs and scheduled after route entry.
- iOS chrome observes WKWebView's existing UIScrollView pan recognizer and
  scroll metrics directly. It neither replaces the delegate nor competes for
  gestures. Released momentum does not acquire finger ownership. Exact native
  view IDs distinguish popup/shared-configuration and same-URL tabs. Missing
  hosts use bounded-rate attachment retries; hiding/disposal cancels them.
  There is no idle display-link, screenshot loop or scroll-time view-tree scan.
- The wallpaper painter clips its wave paths to its own bounds, so a translated
  route cannot draw across the page being revealed. Management routes also
  clip their viewport, use a left back button and a genuinely centered title.
- Legacy native glass uses a thinner fading white rim and a softer shadow,
  removing the dark lower rim/wash while retaining background refraction.
  Flutter glass also reduces edge-light strength. Mobile management groups
  use neutral fills without an outline, while preserving high-contrast borders;
  this adds no backdrop filters.

The iOS plugin is vendored at its existing resolved version, 1.1.2, with only
a public readonly instance-ID getter; see
`dependencies/flutter_inappwebview_ios/UPSTREAM.md`. A native shared-popup
fixture and UIScrollView pan/KVO fixture validate attachment, handoff,
visibility and disposal. Twelve Dart bridge tests cover late attachment and
hide/show/view replacement while platform replies are in flight. These are
lifecycle checks, not physical-device frame-rate or thermal measurements.

Runtime probe: `integration_test/browser_navigation_perf.dart` completed 18
phases on the iPhone 17 / iOS 26.5 simulator in Debug. It uses real WKWebViews,
temporary browser storage and an in-memory settings database, without changing
the user's browser state. Fully-live engine FrameTiming is partitioned by
engine frame number; no synthetic frame pumping occurs during measurements.
Data: `build/browser_validation/navigation-r3-simulator.json`.

In the two warm tab-open/select rounds, 163 recorded frames had no UI or raster
duration above 16.7 ms. UI P95 ranged 3.919–4.916 ms, raster P95 4.009–12.115 ms.
The first blank-browser presentation still had a 114.871 ms UI maximum;
warm settings entry had one approximately 24 ms UI frame in each round. The
fixture's browser readiness was 238 ms cold and 57–69 ms warm, but this excludes
app startup and initializes its temporary store before timing. Settings/tabs
entry includes menu dismissal. These numbers establish neither a before/after
speedup nor physical iOS 18 FPS, WebKit compositor latency or thermal behavior.

Visual checks on the normal simulator app confirmed left-back/centered-title
management navigation, fully visible tab controls and start-page text without
yellow underlines after selection. The actual native legacy-glass surface was
also rendered in a disposable probe using the softer rim; capture:
`build/browser_validation/ios18-rim-r3.png`. That temporary probe was removed.

Final focused browser suite: 370 tests passed. Fatal-info analysis of `lib`,
`test` and the runtime probe is clean; formatting and `git diff --check` pass.
The full repository suite was not rerun. Logs:
`/tmp/browser-round3-final-tests.log`,
`/tmp/browser-round3-final-analyze.log`,
`/tmp/browser-round3-navigation-perf-final.log`.

The final normal app was rebuilt and installed in place on the simulator;
user data was retained. Final visual captures are
`build/browser_validation/settings-r3-final.png` and
`build/browser_validation/tabs-r3-final.png`. CUA drag/scroll input did not move
the native webpage in the final manual attempt, so that attempt is not evidence
of a real finger-driven collapse/expand pass. Native pan fixtures, bridge tests
and actual WebView metrics are the available scroll-path evidence.

Unsigned Release build succeeded (`Runner.app` 113.2 MB), targeting
`lib/main.dart`, bundle `psyche.kelivo`, version 1.3.1 (80). Artifact:
`build/ios/ipa/Kelivo-browser-ios18-20261018-r3-unsigned.ipa` (44,725,051 bytes).
Archive integrity passed; SHA-256:
`112092bd7346689ac0ea0d4dacec09f7cace305ca5ed6b3779fa002a65c53f86`.
Build log: `/tmp/browser-round3-release-build.log`. No physical-device install,
signing, commit or push was performed.

## Material and transition follow-up (2026-10-18, r4)

The supplied `1802190bc0977b8ab93fc870e63ab960.mp4` shows the third of three
tabs flying toward the first row, followed by the grid moving underneath it.
`fa1e275affe224c7db2cad403db9ab28.mp4` shows repeated toolbar press/drag
feedback. Both clips were decoded locally; no source media was uploaded.

- The tab grid previously started at `activeRow * rowExtent`, even when its
  content fit without scrolling. iOS bouncing physics then moved it back into
  range after the flight had recorded the temporary card rectangle. The grid
  now starts at the minimum bounded offset that reveals the selected card;
  changed scroll metrics invalidate its target. Regressions include third of
  three, nonfirst cards in four, and later cards in longer grids.
- Flutter glass now uses the same 62% theme wash (47% clear) as native legacy
  glass. Start-page ribbons remain, with a much lighter neutral palette.
  Management pages use a neutral solid background, full-screen scrolling and
  bounded progressive masks at both edges. Safe-area/header space is scroll
  padding, so content can pass beneath the floating header. Back buttons are
  48 points with 23-point arrows and equal opposite spacing for centered titles.
- Cold or reattached optical surfaces no longer begin with an opaque cover.
  Explicit changes to/from Solid still retain their controlled transition.
  Keyboard/collapse transitions retain the side controls and their material,
  using opacity, pointer exclusion and semantic exclusion instead of removal.
- The search-engine dialog uses one glass material; its inner option group
  has no additional white plate. Lists delay press feedback until tap-down
  arbitration, cancel immediately when scrolling wins, and do not install a
  competing surface-drag recognizer. Toolbar drag/release feedback remains.
- The vendored renderer updates screen-relative uniforms in the same scene
  that moves a retained glass layer. Shape geometry tracks its containing
  group/layer instead of absolute screen movement, avoiding unnecessary matte
  regeneration. Its transform tracker now records the initial identity matrix
  rather than treating it as an absent baseline. See the dependency's
  `UPSTREAM.md` for local change details.

390 focused app and shader tests passed. The new regressions check actual
flight destinations and absence of grid rebound, keyboard material identity,
no opaque preparation plate, scroll/tap arbitration, full-screen management
content and edge input, larger back targets, and retained transform updates.

The actual Impeller probe passed six light/dark translation/stretch cases. All
first-frame versus forced-repaint comparisons had zero RGB error in the checked
region. Images were inspected as well as compared; the fixture had no dark
crescent. Results and PNGs: `build/browser_validation/glass-r4-gpu/`. This is
simulator GPU evidence, not a physical iOS 18 transition recording.

The fully-live navigation probe again completed all 18 phases. Its two warm
tab-open/select rounds recorded 170 frames with no UI or raster duration above
16.7 ms. Settings entry still had isolated long frames (two and three in the
warm rounds); first browser entry also had two long UI frames. This is Debug
simulator timing, without a physical-device thermal test or a controlled
before/after benchmark. Data: `build/browser_validation/navigation-r4-simulator.json`.

Normal-app screenshots: `build/browser_validation/start-r4-final.png`,
`settings-r4-final.png`, `chooser-r4-final.png`, and `tabs-r4-final.png` in the
same directory. The bookmark editor's left close button was also increased to
48/23 points; its five targeted tests were rerun successfully. Fatal-info
analysis and diff/format checks pass. The full repository suite was not rerun.

Unsigned Release: `build/ios/ipa/Kelivo-browser-ios18-20261018-r4-unsigned.ipa`
(44,729,873 bytes), bundle `psyche.kelivo`, version 1.3.1 (80), normal
`lib/main.dart` target. Archive integrity passed. SHA-256:
`5e68fb4def2d5c462c7fe8fcbad9ba4552acabfbd4a217e9d8b64064233989ba`.
The simulator app was updated in place and source data retained. No physical
device installation, signing, commit or push. Logs:
`/tmp/browser-r4-final-tests.log`, `/tmp/browser-r4-final-analyze.log`,
`/tmp/browser-r4-glass-gpu.log`, `/tmp/browser-r4-navigation-perf.log`,
`/tmp/browser-r4-release-build.log`.

## Native composition and navigation follow-up (2026-10-18, r5)

The user-reported crescent was reproduced on the simulator display with a real
WKWebView behind the management route. The r4 `toImage` check covered Flutter
rendering only; it did not exercise the iOS platform-view overlay split.
Flutter's native view slicer separates Flutter paint at WKWebView's boundary.
Cupertino's secondary parallax moved that boundary through a foreground glass
button, leaving its two halves with different backdrop inputs.

`BrowserManagementRoute` keeps the underlying page stationary by declining the
secondary transition, while inheriting Cupertino's foreground animation and
interactive back gesture. The production-equivalent native composition probe
showed the crescent disappear. Display captures are
`build/browser_validation/compositor-r5-baseline.png` and
`build/browser_validation/compositor-r5-native_stationary.png`. The separate
`compositor-r5-no-progressive.png` capture shows that removing the edge blur
alone did not remove the seam. Regression tests exercise entry, cancelled
swipe, completed swipe and result propagation.

Tab flights now keep their image opaque through the endpoint. The stationary
grid is no longer placed in a changing whole-page opacity layer during a real
image flight, and unrelated native progress cannot rebuild its cards. Entry
uses 360 ms and return 320 ms with an ease-in-out curve. A retained copy of the
same flight image bridges route disposal to the selected native view's ready
frame. It occupies the full mobile viewport, independent of the status-bar
inset being applied to the webpage. Readiness, errors, tab replacement,
disposal and reduced-motion paths release the copy; no new screenshot is taken
at return time.

Library search is a 48-point upper-right action; history clearing is beside it
and keeps its existing confirmation. The page owns one header with a centered
title and symmetric reserved space; large text can use a second title row.
Search is shown on demand and cancelling clears its filter. Library pages
subscribe only to their current collection: page loading progress and changes
to other collections no longer rebuild the entire header/list. Download item
progress and inherited material changes still update normally.

The first real WK history run caught a further gap that mocked tests did not:
same-document URL notifications can arrive before the back-forward list index
changes, without a later commit or load-stop callback. The initial serialized
history implementation waited for its timeout in rapid SPA traversal. The
runtime probe explicitly tests these cases rather than treating ordinary-page
Back/Forward success as sufficient coverage.

History availability now comes from one atomic native back-forward-list
snapshot, and superseded reads cannot overwrite newer queries. Commands are
serialized internally until the native current item actually changes. A
main-frame document-start observer coalesces `popstate`, `pushState` and
`replaceState` into one callback after their event task; it only requests an
authoritative native-list read, without accepting availability flags from the
webpage or running a polling loop. The successful WK probe checks 30 endpoints
and five rapid batches, including new branches and same-URL entries. The four
URL-observable batches took 96/82/46/23 ms to acknowledge in this run; the 23 ms
SPA batch previously stalled until the timeout. These are simulator command
acknowledgment observations, not device FPS or general latency guarantees.
Report: `build/browser_validation/history-r5-simulator.json`.

408 focused browser tests passed, including delayed attachment, failures,
reduced-motion cleanup, full-viewport return geometry and collection-only
library subscriptions. Fatal-info analysis of `lib`, `test` and the three
runtime probes passed. The full repository suite was not rerun. Logs:
`/tmp/browser-r5-final-tests.log`, `/tmp/browser-r5-final-analyze.log`, and
`/tmp/browser-r5-history-event-runtime.log`.

The 18-phase fully-live navigation probe also passed. Its two warm tab
open/select rounds had 197 engine frames: none exceeded 16.7 ms on UI or
raster, while five exceeded 8.3 ms. Settings return had no frame above 16.7 ms;
each warm settings entry still had one UI frame around 19.5 ms. First browser
entry had five frames above 16.7 ms, with a maximum UI duration of 107 ms.
These Debug simulator observations do not establish 120 Hz device smoothness,
physical-device temperature, or a controlled before/after performance gain.
Data: `build/browser_validation/navigation-r5-simulator.json`.

The normal simulator application was rebuilt and updated in place, preserving
its data. The actual history header, on-demand search, cancellation and return
were checked in that app. Screenshot: `build/browser_validation/history-r5-final.png`.

Unsigned Release: `build/ios/ipa/Kelivo-browser-ios18-20261018-r5-unsigned.ipa`
(44,748,061 bytes), bundle `psyche.kelivo`, version 1.3.1 (80),
normal `lib/main.dart` target. ZIP integrity and bundle metadata passed. SHA-256:
`b99be09577ebb3880c7c4e777e85470b9f2fc025c1597b30bcea1b05308a094f`.
No physical-device installation, signing, commit or push was performed. Release
and simulator build logs: `/tmp/browser-r5-release-build.log` and
`/tmp/browser-r5-simulator-build.log`. iPhone 14 Pro Max / iOS 18.2.1 thermal
and subjective motion verification remain outside this simulator evidence.


## Content-only previews and resolved optical transitions (2026-10-18, r6)

Tab previews now have one content-only coordinate contract. The exact native
WKWebView reports its snapshot rectangle; iOS 26 excludes its obscured top
inset, while the older inset layout already places the WebView below the status
bar. Flutter start-page captures are cropped to the same content rectangle.
Card, flight and retained attachment cover all use top-aligned fit-width
rendering. The full-screen overview does not stretch a webpage screenshot to
include the status bar. Full agent screenshots keep their separate contract.

WK snapshotWidth is measured in points. The native screen scale is used to
request an actual 440-pixel-wide thumbnail, instead of generating a 1320-pixel
image on a 3x screen. This matters with the app's 48 MiB image cache: eight tall
1320-pixel previews can exceed 100 MiB decoded. A route retains one immutable
map of predecoded previews, shared by its cards and flight, so an asynchronous
replacement cannot freeze a different image's undecoded first frame.

Management routes retain the Cupertino back detector, but keep its ancestor
transforms at identity and translate a resolved page image instead. The opaque
Flutter-only page is captured at its own viewport origin, avoiding translated
backdrop UVs. At rest, or after cancelling Back, live glass painting resumes;
page State stays mounted. The tab overview uses the same single-capture
primitive with the flight outside it. Animation frames no longer rerun all the
page's optical passes. Native WK views remain outside this capture subtree.

The progressive blur's separable intermediate shader now samples its full
kernel only inside the visible edge plus its sampling halo. Outside that area,
one texture lookup is enough because the second pass cannot sample those
pixels. This bounds sampling work; it does not eliminate the intermediate
texture allocation. Material shaders are prepared before a management route
can capture its first frame, and an already loaded edge shader renders without
an extra FutureBuilder blank frame.

The Forward menu entry has been removed on both layouts; toolbar and keyboard
navigation remain. History's upper-right search and clear actions now share
one 96 x 48 material capsule, with two independent 48 x 48 hit targets and one
press response. Other management pages retain their left Back control.

The actual Impeller optical probe compared cached and live pictures at the
view's real 3x pixel ratio. All four liquid/frosted entry/cancel comparisons
had zero RGB difference. In that simulator workload, mean raster duration was
2.895 to 1.068 ms for liquid and 2.799 to 0.989 ms for frosted. Mean build time
rose from 1.420 to 2.199 ms and 1.280 to 2.081 ms, respectively; both variants
already had no raster frame above 16.7 ms. This is a bounded GPU-work comparison,
not evidence of physical-device FPS or temperature. Report and captured PNGs:
`build/browser_validation/management-snapshot-r6/`.

The real WK thumbnail probe passed both viewport geometries: underlap had a
native top of 0 with a 62pt obscured inset; the older layout placed WK at 62pt.
Both produced 440 x 889 images, with top pixels [18, 52, 87] matching the
webpage's blue stripe rather than status padding. Each decoded image occupies
1,564,640 bytes, one ninth of the previous 1320 x 2667 bitmap. The older geometry
was exercised on iOS 26.5 with the inset layout selected; it is not an iOS 18
runtime test. Report: `build/browser_validation/thumbnail-r6-simulator.json`;
log: `/tmp/browser-r6-thumbnail-440-probe.log`.

418 focused browser tests passed. This includes real decoded image fixtures,
a controlled pending decoder, a native screenshot arriving during that wait,
card/return-flight identity, pixel landmark geometry, delayed/failed viewport
attachment, cancelled gestures, and shared history-header feedback. Fatal-info
analysis of lib, test and the three R6 probes passed. The full repository suite
was not rerun. Logs: `/tmp/browser-r6-final-tests.log` and
`/tmp/browser-r6-final-analyze.log`.

The final 18-phase fully-live navigation probe uses the same 200-entry / 48 MiB
image cache as main.dart. Its two warm tab open/select rounds captured 191
engine frames, none above 16.7 ms on UI/raster and three above 8.3 ms. Settings
returns had no frame above 16.7 ms; warm settings entry still had single UI
frames of 22.748 and 20.680 ms. Cold browser entry had two long UI frames,
maximum 90.325 ms. This is a Debug simulator trace, not proof of 120 Hz device
performance, native compositor timing or thermal behavior. It is not a
controlled before/after benchmark. Data:
`build/browser_validation/navigation-r6-simulator.json`; log:
`/tmp/browser-r6-navigation-perf-final.log`.

The normal main.dart simulator application was rebuilt and installed in place,
without uninstalling its data. The actual menu, history's grouped header,
search/cancel and history Back were checked. The normal app's selected webpage
card now begins at its website header without the former status-area strip.
Captures: `build/browser_validation/history-r6-final.png` and
`build/browser_validation/tabs-r6-final.png`. Physical Mac input then locked
the UI session before the final manual card selection; actual tab selection
and return remain covered by the completed native runtime probe above.

Unsigned Release: `build/ios/ipa/Kelivo-browser-ios18-20261018-r6-unsigned.ipa` (44743735 bytes), bundle `psyche.kelivo`, version 1.3.1 (80), normal `lib/main.dart`. ZIP integrity and bundle metadata passed. SHA-256: `92a9a761e7d2b4459a06c665537ddcad4f5bc594cf5ab2093cbda230dee913f3`.

No physical-device installation, signing, commit or push was performed. Build logs: `/tmp/browser-r6-release-build.log` and `/tmp/browser-r6-simulator-build.log`. Physical iPhone 14 Pro Max / iOS 18.2.1 remains necessary to assess perceived motion and heating.


## Control polish and Android validation (2026-10-18, r7)

Bookmark editing now constructs its header/form below the management page's
Material text-style boundary. This prevents a Cupertino route's diagnostic red
and yellow-underlined DefaultTextStyle from leaking into the title. Filled text
and icon actions use the same bounded BrowserPress drag response as optical
controls; cancellation, scrolling ownership, desktop input and reduced-motion
rules remain shared. Neutral surface icons explicitly use onSurface rather
than inheriting CupertinoButton's primary tint; destructive actions stay red.

The mobile find dock has a blue Done control, a glass search field, and a shared
previous/next capsule. It sits above the keyboard or lower safe area, replacing
the visible address dock while preserving that dock's existing widget/native
hosts. Narrow displays and large text can wrap the arrow group to a second row.
Desktop retains its upper-right compact panel without nested glass. Search
callbacks, tab-scoped debounce and keyboard shortcuts retain their existing
behavior; an empty query disables traversal.

On an accepted tab return, the existing navigation/address/More materials are
hidden during the image flight, then revealed over 220 ms after route disposal.
The fade uses each renderer's opacity rather than enclosing native backdrop
views in a saveLayer. Reduced motion switches directly to the endpoint. The
same reveal restores the address dock after closing Find. No additional live
WebView or full-screen optical pass is added.

Focused regressions cover four iOS/Android toolbar fade/reduced-motion cases,
Cupertino-route title style, filled-control drag/cancel/keyboard activation,
neutral history actions, ten responsive find-dock cases and keyboard avoidance.
The scoped browser run had 435 passes and one obsolete wrapper-based field
finder; after updating that finder, all 79 page tests passed. No production
change was needed for that test adaptation. Logs: `/tmp/browser-r7-browser-tests.log`,
`/tmp/browser-r7-page-final.log`, `/tmp/browser-r7-forms-tests.log`.
Fatal-info analysis of lib/test and formatting passed. The full repository test
suite was not rerun.

Android Profile arm64 build and in-place installation succeeded on the existing Pixel_10 AVD (Android 16/API 36). It is shown in Android Studio Running Devices; existing app data was preserved. The connected physical Android device was not used. Runtime log confirms Impeller OpenGLES; the webpage and translucent material were visibly rendered. UI checks covered loading kelivo.psycheas.top, Find highlight and next-match traversal, closing Find, adding/editing/saving the site bookmark, dragging Save without activation, and opening/selecting the tab. The bookmark title is neutral without an underline. Evidence: `build/browser_validation/find-r7-android.png`, `bookmark-r7-android.png`, and `android-r7-runtime.log`. No physical-device FPS or thermal claim follows from these emulator checks.

android: `build/app/outputs/flutter-apk/Kelivo-browser-20261018-r7-profile-arm64.apk`, 85351281 bytes, SHA-256 `598f0a2f6cc79e2654e356a3038955813f718a3ebded3f1490b86fef63ae9164`; ZIP integrity passed.

ios: `build/ios/ipa/Kelivo-browser-ios18-20261018-r7-unsigned.ipa`, 44763194 bytes, SHA-256 `2edb59a1a4cfc4e22be01c0facdf3e902c397c05ccf1d241d317bd5e05cbda6f`; ZIP integrity passed.

Both builds use normal `lib/main.dart`. Build logs: `/tmp/browser-r7-android-build.log` and `/tmp/browser-r7-ios-release-build.log`. iOS Release is unsigned; it was not installed on a physical phone. No commit or push was performed.


## Android overscroll glass (2026-10-18, r8)

Android Material 3's StretchingOverscrollIndicator places a moving scroll
viewport inside an ImageFilterLayer. Liquid glass within that viewport then
loses access to the page background outside the scroll subtree. On the pale
management-page background this produces a flat gray tile while the pointer
is held at an edge; it recovers after release.

BrowserScrollConfiguration disables only Android's overscroll decoration,
while delegating physics, scrollbars and input-device policies to the ambient
ScrollBehavior. The scope covers the browser, independent management routes,
selection dialogs, embedded panels and the separate desktop-style More dialog.
The latter is scoped for consistency; its outer glass was not shown to suffer
this same defect. Non-Android platforms return the original child unchanged.
No WebView scrolling, iOS material, or native glass code changed in this round.

The explicit Android Profile GPU probe passed on the existing Pixel_10 AVD
(Android 16/API 36), using Impeller OpenGLES. It renders the actual BrowserGlass
on the management page's #f2f2f7 background, captures at the scene origin and
real device pixel ratio, and compares an interior glass region while the
pointer remains held at both ends. The baseline glass luminance fell from
238.08 to 155 at both edges, with an RGB error of about 83.37; the independent
background stayed stable and the released material returned exactly. With the
scope enabled, both held and released RGB errors are zero. This measures the
rendering defect, not physical-device FPS or thermal performance. Evidence:
`build/browser_validation/overscroll-r8/report.json` and its twelve PNGs;
log: `/tmp/browser-r8-overscroll-gpu-final.log`.

The iOS 26 appearance question was investigated without editing its behavior.
Webpage controls currently use native UIGlassEffect.regular plus an explicit
white tint in light mode; management controls use the Flutter glass renderer.
The webpage bottom-edge color wash is also stronger. Increasing native
transparency is localized material/contrast tuning, but needs readability
checks on varied webpage backgrounds because Flutter foreground controls do
not receive UIKit's automatic vibrancy.

The browser/service regression run passed 442 tests with one new-fixture
failure (comparing ListView's composed physics type against its base behavior).
After correcting the fixture to compare the inherited behavior itself, all
seven overscroll-scope tests passed, covering 443 distinct browser/service
tests across the runs. Production behavior did not change for that correction.
Fatal-info analysis of lib, test and the probe passed; formatting and diff
checks passed. The full repository suite was not rerun.
Logs: `/tmp/browser-r8-browser-tests-final.log`,
`/tmp/browser-r8-scope-tests-final.log`, `/tmp/browser-r8-analyze-final.log`.

Normal `lib/main.dart` Android Profile arm64 was built and installed in place
on emulator-5554; adb reported installation success and the normal app process
started. No uninstall or app-data reset was used. The Mac locked before the
final native UI check, so this round's visual proof is the completed GPU probe,
not a claim of post-installation manual interaction. The connected physical
Android was not used.

Artifact: `build/app/outputs/flutter-apk/Kelivo-browser-20261018-r8-profile-arm64.apk` (85349830 bytes), SHA-256
`40f6c84f5c7240b7957c1b7634d53373ac49f3b6ea0cf4fabf96c7a93dec3e79`; ZIP integrity passed. Build log:
`/tmp/browser-r8-android-build.log`; metadata:
`build/browser_validation/release-r8.json`. No iOS rebuild, commit or push was
performed.


After the user unlocked the Mac, the normal installed Android app was opened
through its Tools > Browser entry. Existing five tabs and the saved bookmark
were visible; one blank tab was added for the start-page check. The start page
and settings were dragged in both directions and their glass remained normal
in the resulting frames. Settings fits the current portrait viewport, so this
UI check supplements rather than replaces the held-overscroll GPU probe above.
The settings menu and search-engine picker opened and closed correctly without
changing browser preferences. The app was left on browser settings for further
inspection. Captures: `build/browser_validation/start-r8-android.png` and
`build/browser_validation/settings-r8-android.png`. No new source or package
changes were needed after unlocking.


## iOS 26 renderer comparison and lighter tint (2026-10-18, r9)

The production change only reduces light-mode native iOS 26 liquid tint from
opaque white to UIColor.white.withAlphaComponent(0.18). It retains regular
material, the existing bottom edge wash, dark-mode tint, accessibility handling,
and all iOS 18 / Android / macOS behavior. This applies to native webpage
controls and menus; mobile management pages still render Flutter glass. The
alpha is an input tint parameter, not a promise of 18% final material opacity.
Original native source is preserved in the ignored validation directory.

`integration_test/browser_glass_renderer_probe.dart` compares three fixed
BrowserGlass controls over the same opaque animated Flutter scene. It uses
actual vsync, two seconds of warmup, four seconds of measurement, and three
counterbalanced rounds (native/Flutter, Flutter/native, native/Flutter).
FrameTiming samples are selected by engine frame IDs after draining callbacks;
no screenshots or synthetic pump frames occur inside measured intervals. A
separate process sampler records application CPU time and resident memory via
ps every 200 ms. CPU percentages use one-core capacity. This is Debug iPhone 17
Simulator / iOS 26.5 evidence, not physical-device FPS, total GPU, battery, or
thermal evidence. Native render-server work is outside both application CPU
and Flutter raster measurements, so these numbers cannot rank total system
rendering cost.

| Run | Renderer | Frames | UI P95 ms | Raster P50 / P95 ms | App CPU median |
| --- | --- | ---: | ---: | ---: | ---: |
| Original tint | Native | 720 | 0.539 | 0.842 / 1.162 | 17.53% |
| Original tint | Flutter | 720 | 0.977 | 2.378 / 3.543 | 25.28% |
| Light tint | Native | 721 | 0.764 | 0.853 / 1.741 | 18.28% |
| Light tint | Flutter | 720 | 0.868 | 2.415 / 3.146 | 24.32% |

None of these samples exceeded 16.7 ms in either UI or raster. The lighter tint
is a visual adjustment, not a demonstrated performance optimization: native
median raster time was similar, while its P95 increased in this run. CPU is
consistently lower on the native path in this workload; this does not imply
native hosts are optimal for every Flutter route. RSS ranges vary/overlap and
shift across fresh processes, so there is no reliable memory-saving ranking.

After timing, static Flutter and local-only WK backgrounds are inspected on
the actual simulator display. The WK fixtures are explicitly excluded from
performance comparison, since the custom Flutter refractive shader cannot
sample WK's native pixels. The final probe asserts document identity, ready
state, three visible column bounds and computed white/black/cyan colors before
publishing a visual stage. With light tint, native controls show the real WK
colors and blurred content while retaining readable black labels; Flutter
shader controls are flat gray on that same verified document. These displays
confirm that replacing native webpage refraction with the existing Flutter
shader is not equivalent. Ordinary Gaussian Flutter BackdropFilter blur has a
separate native bridge and is not covered by that limitation.

The first baseline WK observation was captured before its visual content was
confirmed; it is retained as `baseline-unready-wk.png` and is not evidence of a
rendering failure. Its timed Flutter-background samples were independent of
that visual fixture. The final probe adds explicit readiness and Next controls;
its timing workload and measurement function are unchanged between runs.

Data and display captures: `build/browser_validation/renderer-r9/`, including
both report/process JSON files, `summary.json`, and
`light-{native,flutter}-{flutter,wk}-backdrop.png`. Driver logs:
`/tmp/browser-r9-baseline.log` and `/tmp/browser-r9-light.log`.


The final simulator probe passed with all WK document checks. Fatal-info
analysis of lib, test and the new probe passed, as did Dart formatting and diff
checks. Native Swift compiled both in the probe build and in the normal
main.dart simulator application. No full repository test suite was rerun for
the tint-only production change.

Normal main.dart was rebuilt and installed in place on the existing iOS 26.5
simulator. Browser storage was retained. Its real webpage dock and native More
menu were checked against a local dark/color/light document; enabled controls
and menu text remain readable, and background colors are visibly less washed
out. Captures: `ios-contrast-after.png` and `ios-menu-after.png` under the R9
validation directory. The original pre-change contrast capture used an HTML
fixture before a missing UTF-8 declaration was corrected; it is a qualitative
color reference only, not a pixel-aligned before/after image. The normal browser
was then navigated to kelivo.psycheas.top for continued user inspection.
Build log: `/tmp/browser-r9-main-simulator-build.log`; analyze log:
`/tmp/browser-r9-analyze.log`. No iOS 18/physical-device install, IPA package,
commit or push was performed.


## Balanced light/dark native tint (2026-10-18, r10)

The iOS 26 native liquid material now uses white at 0.12 tint alpha in light
mode (previously 0.18), and neutral 0.08 gray at 0.55 alpha in dark mode
(previously alpha 1). This retains regular/clear material selection and the
existing theme-dependent foreground colors. It covers native webpage controls
and menus without changing the Flutter page material or iOS 18 renderer. A
0.12-alpha dark trial was rejected because white enabled icons lost contrast
over the white/cyan parts of the test webpage; dark tint deliberately retains
more backing for its white foreground.

The existing renderer probe adds an opt-in GLASS_VISUAL_ONLY path to inspect
native controls in light then dark mode over the same verified white/black/cyan
WK document. It skips performance measurements; the default renderer benchmark
keeps its existing scene and sample protocol.


The final light and dark WK visual stages passed on iOS 26.5. Display captures
`build/browser_validation/tint-r10/light-final.png` and `dark-final.png` show
the final values; the rejected dark trial is `dark-too-light.png`. The final
dark screenshot was captured on the already-built probe after the first timed
capture missed its stage; no additional material change was made. White dark-
mode chevron/ellipsis remain visibly distinct over bright white/cyan content,
and the address label remains readable over the dark column. This is visual
validation, not a new performance or formal contrast-compliance measurement.

Report: `build/browser_validation/tint-r10/final-visual-report.json`;
logs: `/tmp/browser-r10-visual-final.log`, `/tmp/browser-r10-capture.log`.
Fatal-info analysis of lib/test/probe and formatting/diff checks passed. Native
Swift compiled in the probe. The full suite and performance benchmark were not
rerun for this color adjustment.

Normal main.dart simulator build also passed and was installed in place with
app data retained. The browser was opened to the existing Kelivo website tab.
Build log: `/tmp/browser-r10-main-build.log`. No IPA packaging, physical-device
installation, commit or push was performed.

## Dark webpage dock transparency (2026-10-18, r11)

The R10 isolated-control probe omitted the production bottom-edge gradient.
R11 checks the complete BrowserPage instead. The iOS 26 dark native tint is
reduced from 0.55 to 0.46; light tint stays at 0.12. A 0.38 dark trial showed
good color transmission but weak white foregrounds over a white document, so
it is retained only as rejected visual evidence in `trial-038/`.

For dark liquid webpages with confirmed native viewport underlap, the bottom
gradient now fades earlier behind the expanded and collapsed toolbar while
retaining its maximum 0.64 alpha at the home-indicator edge. Its alpha stops
are `[0.64, 0.40, 0.06, 0]` at `[0, 0.18, 0.42, 1]`. The top edge, light mode,
other materials, Flutter start page, iOS 18 and Android retain their previous
gradient. The native material, platform-view count and blur passes are retained.

Only the enabled native dark webpage toolbar foregrounds receive a small
zero-blur black shadow (alpha 0.40, 0.5-point vertical offset). Address display,
editing and placeholder text share it; disabled icons, management pages,
menus, other materials and high-contrast/reduced-transparency modes do not.
This is foreground edge protection, not another backdrop filter or layer.

The existing viewport bridge now queries the actual iOS Reduce Transparency
preference once per mounted host group and listens for its change notification.
Previously Flutter's high-contrast-derived glass scope did not carry that
separate system preference. Unknown state retains the original edge; live
changes update only the fade decision without moving the WebView. Shared
subscription ownership and query revisions prevent stale replies or disposed
hosts from overwriting newer preferences. macOS's window shortcut callback is
not replaced.

`integration_test/browser_dark_chrome_probe.dart` mounts the actual BrowserPage
with temporary browser storage and an in-memory settings database. It checks
white, color and black local documents. An optional
`DARK_CHROME_MANUAL_SCROLL=true` stage requires an actual native swipe for the
collapsed white-page scene. Each visual stage verifies the visible
native viewport and the production underlap/fade branch. The test explicitly
allows device pointer events so its Next button and native gestures work.
Native UIScrollView bounds are compared with the Flutter host; DOM innerHeight
differs by the obscured status-bar inset and is not equated with native bounds.

Evidence belongs in `build/browser_validation/dark-chrome-r11/`. These are
simulator visual/functional checks, not a new performance comparison or
physical-device thermal/battery validation.

The initial probe incorrectly equated DOM and native heights, and its first
manual-scroll attempt dropped device pointers in the Flutter test binding.
Both test issues were corrected. Even with device pointer propagation enabled,
the available simulator automation could tap Next but did not scroll the native
WK page with drag or scroll commands; manual-scroll runs consequently timed
out and are not claimed as gesture validation. The final automatic run covers
the three expanded scenes. Collapsed-edge geometry/brightness is covered by
the focused raster test, not by a successful native swipe in this run.

All 165 focused control, menu, page, viewport, edge and layout tests passed.
Fatal-info analysis of lib/test/probe and formatting checks passed. The full
repository suite and renderer performance benchmark were not rerun for this
visual adjustment. Logs: `/tmp/browser-r11-final-tests.log` and
`/tmp/browser-r11-final-analyze.log`.

The final three-scene visual probe passed on iPhone 17 / iOS 26.5 Simulator.
Report: `final-expanded-report.json`; captures: `white-expanded-final.png`,
`color-expanded-final.png`, `black-expanded-final.png`; log:
`/tmp/browser-r11-visual-expanded.log`. The normal main.dart simulator app also
built successfully and was installed in place, retaining browser data. Its
Kelivo webpage and More menu were checked on screen (`normal-after.png`,
`normal-menu-after.png`), then left on the webpage for user inspection.
Build log: `/tmp/browser-r11-main-build.log`. No IPA, physical-device install,
commit or push was performed. A separate read-only review found no actionable
defect in the final accessibility/foreground wiring.

## Dark tint correction (2026-10-19, r12)

After the R11 white-page result looked too pale, only the iOS 26 dark native
tint changed: gray 0.08 at alpha 0.46 becomes black at alpha 0.64. Light tint,
gradients, foreground effects and renderer behavior are unchanged. This is a
one-line production adjustment with no new rendering layer. The normal iOS
simulator build passed (`/tmp/browser-r12-main-build.log`) and was installed
in place with browser data retained. Visual captures are under
`build/browser_validation/dark-tint-r12/`; no new performance claim is made.

## Stable dark native tint (2026-10-19, r13)

Per the user's preference for consistently dark chrome, restore the iOS 26
dark tint to gray 0.08 at alpha 1. The previous translucent tint could still
appear pale over a bright page. Light tint and the renderer are unchanged;
no new layer or adaptive color logic was added. The normal simulator build
passed (`/tmp/browser-r13-main-build.log`) and was installed in place.
Repeatedly opening and closing More over the same white Bing page retained
the dark appearance. Captures: `build/browser_validation/dark-tint-r13/`.

## Stationary held menu (2026-10-19, r14)

Remove the More menu's held-pointer translation, stretch and release spring,
including their state and transform wrappers. The pointer still highlights
rows, enters submenus and selects on release; opening/closing and submenu
transitions retain their existing behavior. Ordinary scrollable menus still
scroll. No shared button/card drag feedback was changed.

The existing held-selection regression now compares the menu's actual painted
screen bounds before and during movement across a row and footer. It failed
against the old implementation, then passed after removal, including highlight
placement and exactly one selected action. All 128 menu/page tests passed;
fatal-info lib/test analysis, formatting and diff checks passed. Logs:
`/tmp/browser-r14-tests.log`, `/tmp/browser-r14-analyze.log`.

The normal iOS simulator build passed (`/tmp/browser-r14-main-build.log`) and
was installed in place. A long press still opens More in the running app;
capture: `build/browser_validation/menu-stationary-r14/normal-menu.png`.
Continuous held-drag geometry is established by the widget regression above,
not by a physical-device gesture test. No commit or push was performed.

## Browser app-font inheritance (2026-10-20, r15)

The menu's explicit DefaultTextStyle now preserves the app theme's font family
and fallbacks for its primary rows, footer and submenu. Address editing, find,
shared library/tab search fields and mobile bookmark editing explicitly pass
the same typography to CupertinoTextField; its placeholders inherit that input
style. Only font family/fallback are supplied, preserving each control's existing
size, spacing and colors. The collapsed address width now measures the same
inherited typography as its visible label. Existing management-page, dialog and
tab-preview text already inherit the app text theme and need no replacement.

The new typography regressions failed against the original implementation:
menu font family was null, input/placeholder text resolved to CupertinoSystemText,
and a custom-spaced collapsed address was 15 points too narrow. RenderParagraph
and RenderEditable checks now cover primary/submenu/footer text, mobile/desktop
inputs, placeholder-to-input transitions and bookmark headers/actions. All 354
browser widget tests passed, along with fatal-info analysis of lib, test and
integration_test. Logs: `/tmp/browser-r15-browser-tests.log` and
`/tmp/browser-r15-analyze.log`. These checks verify font routing and layout,
not the appearance of every imported font file.

The normal `lib/main.dart` iOS simulator build also passed and was installed
in place. The browser menu was opened on iPhone 17 / iOS 26.5 and its text and
layout visually checked. This is simulator evidence, not a physical-device run.

## Browser mobile interaction and UA controls (2026-10-20, r16)

The preceding font-only change was independently reviewed and committed locally
as `98d4e768`. Before that commit, root analysis and all 8,352 root tests passed.
This branch still uses gpt_markdown; the requested markstream gate was run in the
main checkout's existing package, where analysis and all 290 tests passed.

The mobile address action now shows the session's cached favicon. Address edit
mode animates capsule width and companion-control visibility together. Collapsing
uses fixed expanded/collapsed text layouts with a crossfade, so a long hostname
is not re-ellipsized at each animation frame. Android adds bottom clearance and
exits address editing when the IME is dismissed by the system Back action.

BrowserTextField shares decoration and app fonts while choosing Material editing
on Android/Windows/Linux and Cupertino editing on Apple platforms. Management
and bookmark routes use the host platform's transitions. The custom tab-overview
zoom and the iOS snapshot transition remain intact.

Menu preview capture starts only after opening motion completes. Tab navigation
does not await that background capture. The shipped DOM observer coalesces
bridge delivery to 16ms during finger input and 64ms during passive momentum;
start/release/cancel/end boundaries still flush immediately. Its executable JS
regression simulates 120 momentum frames and observes 15 bridge updates. This
measures bridge work, not device FPS or WebView rendering speed.

Settings offer mobile, desktop and custom UA choices, with validation,
persistence, live-engine application and a reload of the active webpage.
Inactive engines receive settings without being reloaded or created. Apple
plugin setters now clear WKWebView.customUserAgent when switching back to a
preset. New/missing assistant-browser preferences default on; a saved explicit
off remains off, and assistant tool selection and session ownership still apply.

Per the user's request, no browser UI acceptance automation was performed in
this round. ADB identified the connected arm64 Android phone; the app was not
running when read-only frame diagnostics were queried, so no physical-device
performance improvement is claimed from that query.

Validation: all 489 browser widget/core-service tests passed, as did
`dart analyze --fatal-infos lib test integration_test` and the executable scroll
observer regression. Coverage includes intermediate keyboard-transition geometry,
Android IME Back, collapsed dock clearance, menu capture deferral, Android/Apple
text editing with custom fonts, adaptive routes, UA dialog/persistence/native
application/preset restoration/download-header invalidation, and saved permission
opt-out. Logs are `/tmp/browser-r16-focused-tests.log`,
`/tmp/browser-r16-analyze.log`, `/tmp/browser-r16-android-release.log` and
`/tmp/browser-r16-ios-build.log`.

The final arm64 Android Release APK built successfully, was signed with the
existing main-project release configuration, and its certificate matched the
installed app. `adb -s fee8c1be install -r` completed successfully without an
uninstall or data reset. The signed artifact is
`build/app/outputs/flutter-apk/kelivo-browser-r16-arm64-release.apk`.
The final normal-entry iOS simulator build also passed; the macOS WebView setter
passed Swift syntax parsing. Physical-device interaction and FPS are left for
the user's manual acceptance. The follow-up review found that non-ASCII custom UA values could fail in Dart
HTTP download headers. Input, service updates and persisted values now share
printable-ASCII validation, with localized guidance and regressions for Chinese,
emoji and accented characters. The same reviewer rechecked the fix and reported
no remaining findings.

Pre-commit validation after the review fix: all 8,371 root tests passed
(`flutter test --concurrency=4`), static analysis passed for lib/test/integration_test,
and the markstream package passed analysis and all 290 tests in the primary
checkout (this browser branch predates the package rename). One unrelated backup
isolate timing test failed in the first full run, then passed both its isolated
retry and the complete lower-concurrency run; its code and assertions were unchanged.


### R17: adaptive address motion and Android scroll composition

R16 was independently reviewed, repaired and committed as `b3d7d483` before
this work. Address labels now retain continuous layout/font interpolation when
they fit at both endpoints. Labels needing ellipsis retain the two stable
endpoint layouts. Measurements use the inherited font and text scale outside
the per-frame spring builder.

Android solid surfaces now use hybrid composition, while liquid/frosted surfaces
retain texture composition for live Flutter backdrop sampling. Changing style
reattaches the same keep-alive WebView, without navigation/reload. Coalesced
style changes retain the existing host and cannot strand the attachment future.
The browser route disables Flutter route snapshots, which cannot capture native
hybrid views. The vendored Android plugin remains at 1.1.3; its local patches
synchronize the input proxy/container/layer when reattaching a retained view and
avoid scroll/overscroll channel messages without Dart subscribers. Native
scrolling, content quality and system refresh requests are unchanged.

The user's initial manual comparison was captured on Android 11/API 30,
1080x2400 at an actual 120 Hz. In this capture, Kelivo's Android main-thread
Choreographer span p95 was 7.40 ms versus Bothub's 5.76 ms, and
syncAndDrawFrame p95 was 5.23 ms versus 1.91 ms. Kelivo had 3,553 DrawFrame spans
for 1,776 WebView draws, versus Bothub's 2,071/2,071. These are Android trace
costs, not end-to-end Flutter FPS or a controlled lab benchmark; interactions
were manually performed and aggregate gfxinfo jank includes input-latency
classification. SurfaceFlinger did not return valid presentation timestamps.
The initial evidence is `/tmp/browser-r17-scroll-compare.atrace` and
`/tmp/browser-r17-trace-summary.json`. The Bothub package was inspected read-only
using Android SDK tools after REA reported its Android backend unavailable.

Focused validation: 493 browser tests passed, including retained document/history,
style changes without reload, short-label scaling and long-label stability.
The final native-engine/page subset passed all 129 tests after adding the
coalesced-style regression. Static analysis and the JS scroll-observer regression
passed. The two Android Robolectric tests passed: unsubscribed scroll events
are suppressed while subscribed/other events still arrive, and switching
composition clears the old IME proxy and permits a new proxy on return.
No automated browser UI acceptance was performed.

The arm64 Release APK built and was signed with the existing project certificate
(SHA-256 `00cdebef78297ab3e7df18792d43df6c734acd22a7a71d286928eea5cef1b6c1`).
`adb -s fee8c1be install -r` succeeded without uninstalling or resetting data.
Artifact: `build/app/outputs/flutter-apk/kelivo-browser-r17-arm64-release.apk`.


The user completed the second comparison and reported improved webpage scrolling,
but retained jank in menus, keyboard and chrome motion, plus pages where chrome
would not collapse. Read-only Android view hierarchy and R8 mapping confirmed the
solid page was hosted by FlutterMutatorView/FlutterImageView (hybrid composition).
The capture also exposed WebView screenshot work taking about 80-90 ms of main
thread CPU in individual long messages. The upstream screenshot implementation
allocated a full viewport bitmap, cropped/scaled it and compressed it on main;
Android thumbnails additionally multiplied the requested 440 width by density.

The follow-up draws directly at the requested dimensions, bounds Android tab
previews to 440 physical pixels like iOS, and encodes on one background worker,
returning the channel result on main. Agent PNG screenshot requests keep their
original size/format contract. Android chrome direction now observes Flutter's
raw pointer stream rather than depending on DOM touches surviving compositor
scroll ownership. DOM scroll metrics also follow scrollable inner elements;
root gestures restore root metrics. Pinches, keyboard editing and passive
momentum cannot reverse the chrome.

Follow-up checks: all 494 browser tests, static analysis and the executable JS
observer regression passed. All three Android Robolectric tests passed, including
native Skia pixel verification of scaled/cropped screenshots, async completion
and main-thread replies. This is not a final real-device smoothness result for
the follow-up; the user has only confirmed improvement in the earlier build's
webpage scrolling. R17 remains uncommitted, separately from R16.

The final follow-up Release build also passed and was installed with `adb install -r`
on `fee8c1be`, with the same certificate and no uninstall/data reset. Its distinct
artifact is `build/app/outputs/flutter-apk/kelivo-browser-r17b-arm64-release.apk`;
logs: `/tmp/browser-r17-ui-release.log`, `/tmp/browser-r17-ui-followup-tests.log`,
`/tmp/browser-r17-next-analyze.log`, `/tmp/browser-r17-native-followup-final.log`.
Both passive atrace captures were stopped. Final UI smoothness is awaiting the
user's manual check; no further automated UI actions were performed.

### R18: Android controls, idle previews and address baseline

The user confirmed smooth solid-mode webpage scrolling but reported delayed
controls, retained optical-mode scroll cost and a moving address baseline.
The baseline now uses one fixed line box plus a paint transform; changing
fractional font sizes no longer rounds the ascent/descent separately each frame.
Long truncated hosts still use stable endpoint layouts; fitting hosts retain
continuous motion. Android keyboard dock changes interpolate over 240 ms while
retaining the webpage's bounds and element; reduced motion skips interpolation.

More no longer requests a native tab screenshot during presentation. The active
preview is prepared after one second without viewport input/scroll updates,
provided no keyboard, menu, find UI, tab transition or Flutter animation is active.
The callback rechecks those conditions and the route before capturing; unchanged
previews are reused. Android menu text keeps its scale/fade without the additional
large foreground blur. Its background material is unchanged. Fully hidden
Flutter optical surfaces now skip paint via Visibility while retaining their
prepared renderers, size and state. A zero shader visibility alone still submitted
backdrop/refraction passes. Visible surfaces retain their blur, tint and render path;
native iOS hosts retain their existing material-opacity handling.

An explicit profile probe lives in
`integration_test/browser_android_composition_bench.dart`. It uses a local HTML
fixture, temporary browser files and an in-memory settings database, records
menu/IME/collapse/expand phases in all three styles, and does not navigate or
modify the user's real tabs. Run drive with `--keep-app-running` to avoid the
integration driver's default uninstall. FrameTiming reports engine build/raster
and total span, not display presentation FPS. The Android 11 physical device
remained at 120 Hz; samples are not controlled lab or iOS measurements.

Initial A/B results (`/tmp/browser-r18-baseline.json` and
`/tmp/browser-r18-lean.json`) reduced warmed solid-menu raster maximum from
22.308 ms to 8.595 ms and p95 from 6.040 ms to 5.335 ms; total-span p95 was nearly
unchanged (13.782 vs 13.936 ms). Frosted/liquid results were mixed, so this does
not establish that optical scrolling is fully fixed. The final probe repeats
with stricter idle-capture guards. Uniform texture composition, forcing hardware
layers, shared backdrop groups and disabling Flutter's native-view synchronization
were also measured; none gave a consistent improvement and none of those
experiments is shipped. In particular, the shared group increased some liquid
collapse/expand samples, so the final change only skips fully hidden material paint.

Flutter's platform-view tradeoffs are documented at
https://docs.flutter.dev/platform-integration/android/platform-views and
https://flutter.googlesource.com/mirrors/flutter/+/HEAD/docs/platforms/android/Android-Platform-Views.md.
The current API 30 device cannot use the newer API 34+ HCPP path. The final code
retains R17's solid hybrid/optical texture split, and does not change the global
renderer, system refresh policy or webpage rendering resolution.

Final candidate evidence: `/tmp/browser-r18-hidden.json` and
`/tmp/browser-r18-hidden-drive.log` completed all 36 measured phases. Warmed
solid menu raster maximum was 7.317 ms versus baseline 22.308 ms; raster p95
5.289 vs 6.040 ms and total-span p95 13.161 vs 13.782 ms. Solid address-open
raster p95 was essentially unchanged (2.732 vs 2.685 ms). Liquid collapse raster
p95 was 5.137 vs 5.213 ms, while expand was 6.183 vs 5.270 ms; frosted collapse
was 9.395 vs 8.840 ms and expand 10.551 vs 10.721 ms. These mixed optical results
do not establish consistent scroll improvement. Battery temperature during the
last run was around 39.5 C; sample order, thermal conditions and native pipeline
latency were not controlled. No claim of stable 120 FPS or complete jank removal.

Validation: the combined browser core/widget run passed 498 tests before the
last paint-gate change; the final browser widget suite passed all 376 tests after
it. Static analysis of lib/test/integration_test, changed-file formatting,
`git diff --check`, and executable JS observer checks passed. New regressions
cover continuous address baselines, deferred/cancelled idle capture, retained
viewport geometry during keyboard motion, Android menu content without extra
foreground blur, and hidden optical renderers surviving hide/show without remount.
The initial opacity-wrapper experiment tripped the existing backdrop-isolation
regression and was replaced by Flutter Visibility, which skips paint without
an opacity layer. R18 remains uncommitted along with R17.

The final normal-entry arm64 Release build passed and was signed with the existing
project certificate (`00cdebef78297ab3e7df18792d43df6c734acd22a7a71d286928eea5cef1b6c1`).
`adb -s fee8c1be install -r` returned Success and the normal MainActivity launched;
no uninstall or user-data reset was performed. The temporary profile probe was
replaced by `build/app/outputs/flutter-apk/kelivo-browser-r18-arm64-release.apk`.
Final analyzer log: `/tmp/browser-r18-analyze-final.log`; build log:
`/tmp/browser-r18-release-build.log`. No real-tab UI acceptance was automated.

### R19 candidate (withdrawn with R20): one Android composition path for browser materials

R18 did not resolve the reported tradeoff: solid webpage scrolling improved but
Flutter controls remained uneven, while optical modes had different scroll costs.
The experimental API 30+ browser embeds the real Chromium hierarchy in a
`SurfaceControlViewHost`/`SurfaceView`. Flutter's texture controller selects its
virtual-display path for that surface, instead of replaying `WebView.draw` into
a second canvas or inserting a hybrid-composition Flutter overlay. All three
styles retain the same native host/document. Android versions below API 30 keep
the ordinary texture path; iOS is unchanged. The global renderer, display mode,
webpage resolution and material appearance are unchanged.

The host forwards native input connections, retains the embedded hierarchy when
Android 11 replaces a destination surface during resize, and transfers a separate
SurfacePackage handle to SurfaceView. Native selection uses an Android floating
toolbar anchored to the Flutter viewport. Native hosts for one retained document
are serialized: outstanding resize replies complete before disposal/reattachment.
The virtual-display input client is released before destroying its view, without
clearing a Flutter text field that has already taken focus. These are required
lifetime contracts, not delays inserted in interaction animations.

The isolated physical-device probe now covers native HTML input/IME, six retained
tab round trips (form value and scroll position), long-press selection and closing
the focused tab while its keyboard is resizing. Temporary browser data and an
in-memory settings database are used. It can measure the public homepage via
`BROWSER_BENCH_URL`, and reports the source in its output. No real user tabs are
navigated by the probe. Performance timings describe Flutter engine work, not
SurfaceFlinger presentation FPS or a guarantee of stable 120 FPS.

Rejected experiments are not shipped: Vulkan failed to initialize on this phone;
this Flutter build does not support separating platform/UI threads; forcing the
older GL texture producer did not consistently improve the measurements. The
phone's existing Android 11 renderer policy remains Skia. Shader image filters
are unavailable there, so liquid mode exercises the established non-shader
fallback, not the premium refraction shader on newer devices.

At the end of the R19 investigation this candidate was **not ready for delivery**. The final 507 browser Dart tests, four Android
native tests and JS scroll-observer regression passed, but the physical-device
probe still finds the IME reappearing after closing an input-focused tab. Earlier
crashes in resize/disposal and stale input clients were fixed; the remaining
functional failure must not be counted as a performance-test pass. The full
homepage probe recorded all 36 timing phases before failing its final keyboard
assertion (`/tmp/browser-r19-complete-drive.log`). Results remain mixed and do not
establish that all modes are completely smooth. A subsequent run was invalidated
by device lock; its driver printed success despite the actual test timing out,
so both device logs and assertions must be checked, not only the driver exit.

The device has been restored with `adb install -r` to the existing normal-entry
`kelivo-browser-r18-arm64-release.apk` (Success, MainActivity launch confirmed).
No uninstall or data reset was used. The original stay-awake setting, `7`, was
restored. That candidate was left uncommitted, with no R19 production APK delivered.
Device validation was waiting for the phone to be unlocked. Logs: `/tmp/browser-r19-browser-tests.log`,
`/tmp/browser-r19-native-tests.log`, `/tmp/browser-r19-observer-tests.log`,
`/tmp/browser-r19-finalhost-drive.log`; final keyboard failure is also in the
Flutter logcat for PID 29201. R20 passed the synthetic probe below but was
subsequently withdrawn for a real input-dispatch regression.


### R20 (withdrawn): input ownership and valid native gesture sampling

**Do not install this candidate.** Actual user touch failed after installation:
clicks and horizontal gestures stopped working. The emergency rollback below
supersedes the synthetic probe's pass and the delivery notes in this section.

Input cleanup now retains the focused native view's ancestor chain before it
is detached. Focus returning to that same page/route is released; focus moving
to any other branch is preserved, including custom editors that do not use
EditableText. The controller releases its owned input client before native
teardown and rechecks ownership afterwards. No widget-type heuristics, global
input interception or delayed keyboard-dismiss timers were retained.

The native-gesture probe had a separate defect: WidgetTester's default
longPressAt sends zero timestamps for both down and up. Android could therefore
recognize a held gesture yet the native IME bridge classify its release as a
short tap. Native presses and flings now use monotonic timestamps and elapsed
movement/hold times. Selection must leave the keyboard hidden, and closing the
focused tab must leave it hidden after an additional settled interval. Previous
zero-timestamp gesture samples must not be used as a controlled before/after
performance comparison.

The final physical-device run completed all 36 homepage phases and its native
input, selection, six retained-tab/form/scroll checks, and closing-while-IME-
resizing checks. Both the test assertions and driver result passed. Evidence:
`/tmp/browser-r20-complete-drive.log`, `/tmp/browser-r20-final-metrics.json`.
It used temporary browser storage, not the user's tabs. The Android 11 Skia
renderer still reports shader image filters unsupported, so liquid selection
uses the established fallback. No iOS or newer Android GPU performance claim.

Warm second-round raster p95 in milliseconds (engine timing, not presentation
FPS):

| Phase | Solid | Frosted | Liquid selection |
| --- | ---: | ---: | ---: |
| Menu open | 8.925 | 9.499 | 8.796 |
| Address open | 4.127 | 7.021 | 3.821 |
| Collapse | 6.434 | 9.462 | 5.873 |
| Expand | 4.760 | 9.684 | 9.512 |

The shared native host removes the material-dependent composition switch and
second WebView Canvas replay. This run still contains long frames, particularly
in frosted mode; these results do **not** prove all scenes stay within the
8.33 ms/120 Hz budget or that all jank has been eliminated. Battery temperature
was approximately 38 C during sampling, and this is not a controlled lab A/B.

Final validation: 509 browser core/widget tests, four Android native regressions,
JS observer checks, root fatal-info analysis and formatting/diff checks passed.
The changed vendored files have no new diagnostics; their two existing
`overridden_fields` infos match the saved upstream baseline. This was focused
browser validation, not the complete repository/markstream suite. No commit or
push was made.

The normal-entry arm64 Release built successfully and was signed with the
existing project certificate. `adb -s fee8c1be install -r` returned Success,
MainActivity launched, and process 23005 was confirmed alive. The temporary
profile app was replaced; no uninstall/data reset occurred. The original
stay-awake value is still `7`.
Artifact: `build/app/outputs/flutter-apk/kelivo-browser-r20-arm64-release.apk`.
SHA-256: `afba441a3be1003cc1b311ecd70cc3f8c203a235e95c23103fce0d95a5ad9c42`.
Logs: `/tmp/browser-r20-browser-tests.log`, `/tmp/browser-r20-native-tests.log`,
`/tmp/browser-r20-analyze.log`, `/tmp/browser-r20-release-build.log`.
Real-tab UI acceptance is left to the user as requested.

### R20 emergency rollback: physical input dispatch regression

The user reported loss of taps and horizontal gestures across the phone after
R20, not only inside the webpage. The app was force-stopped and the existing R18
normal Release restored with `adb install -r` (Success); no uninstall/data reset
was used. The user confirmed that normal input returned.

The new host created its SurfaceControlViewHost on `owner.getDisplay()` (the
physical display) while its SurfaceView belonged to Flutter's virtual display.
This incorrectly registered the embedded input window on the physical display.
The device's retained input log shows events dispatched to that embedded window;
after rollback it is absent from the live input-window list. The prior injected
WidgetTester gestures bypassed that system dispatch path and did not validate
physical input routing. The R20 pass therefore must not be used as functional
acceptance or proof that the user's performance problem is fixed.

R19/R20's host, input bridge and lifetime wrapper were withdrawn from the active
browser checkout; R18 hosting and its material-change document retention are
restored. The withdrawn source is retained in `/tmp/browser-r20-withdrawn-20261020`
for diagnosis. Further host experiments run in the separate
`browser-input-probe` worktree with package `com.psyche.kelivo.browserprobe`,
not the user's installed application. Input validation must pass through Android
InputDispatcher and check foreground/background window ownership. Performance
remains unresolved in the restored R18 application.

### Isolated R21 experiment rejected after system-input comparison

A separate `com.psyche.kelivo.browserprobe` application corrected the embedded
host's display to its actual virtual display and rejected a physical-display
attachment. A local coordinator sent gestures through `adb shell input`;
`shouldPropagateDevicePointerEvents` was enabled in the test binding, which
otherwise silently drops real device events. Before each gesture it checked
that no embedded input window existed on display 0 and that the probe remained
foreground. The existing production app/data were never replaced by this probe.

The corrected candidate passed 36 fixture phases plus native input, selection,
retained tab/document checks and keyboard dismissal. Its live embedded window
was on virtual display 5; the display reports a nominal 60 Hz mode. A matching
R18-host baseline also completed all 36 phases with the same system-input path.
These are profile/local-fixture engine timings, not physical finger acceptance,
homepage measurements, presentation FPS, or a controlled thermal laboratory A/B.

Selected warmed total-span p95 in ms (R18 baseline -> R21 candidate):

| Phase | Baseline | Candidate |
| --- | ---: | ---: |
| Solid menu open | 11.979 | 8.932 |
| Solid address close | 10.093 | 12.785 |
| Frosted collapse | 13.519 | 15.818 |
| Frosted expand | 16.811 | 17.441 |
| Liquid expand | 10.004 | 8.816 |

The mixed results do not justify replacing R18. The experimental host remains
withdrawn. Logs: `/tmp/browser-r21-system-drive.log`,
`/tmp/browser-r21-baseline-drive.log`, `/tmp/browser-r21-system-input.log`;
parsed comparison and retained candidate: `/tmp/browser-r21-candidate/`.
The diagnostic application and its ADB reverse mapping were removed afterwards;
the normal R18 application remains installed and was reopened.

The user-selected Bothub APK was also inspected read-only. Package
`com.jiangzikang.bothub`, SHA-256
`004055a63e71cda9198e0657f18abac85681ede2a539717a03b484783d268587`,
has Compose metadata and two classes directly extending `android.webkit.WebView`,
with no `libflutter.so` or Flutter assets in the sole installed APK. This
establishes a different packaged implementation, not why every frame is faster.
REA artifact evidence: `ev_81ad36d153b1e138eafab44fc25eef70b32c57d7150aba2da629636abef7185d`.
DEX structure was separately read with Android SDK apkanalyzer and a bounded
header parser; REA's Android decompiler was unavailable because its JADX provider
was not installed. No prerequisite was installed and no Bothub data was read.

Rollback validation: 499 browser core/widget tests, three Android native tests,
root fatal-info analysis, JS observer checks and diff checks passed. No commit
or push was made. The performance objective remains unresolved.


### R22: isolated Android rendering and interaction validation

R22 uses the restored R18 WebView host. It adds no SurfaceControlViewHost,
input window, custom virtual-display controller or device input setting. Work
was first exercised in the separate `com.psyche.kelivo.browserprobe` package;
normal application data was not used by the fixture.

Changes:

- Match composition to the effective material: on Android renderers without
  shader-filter support, liquid already paints the opaque fallback, so it now
  uses the same hybrid host as solid instead of paying for a texture host.
  Supported shader glass and frosted still use the texture composition path.
- Replace Android blurred box shadows with `Canvas.drawShadow`. Frosted blurs
  use a smaller intermediate with the same effective radius; page content and
  foreground controls remain full resolution. Pixel comparisons cover light/
  dark, 1x/3x and three opacity levels against the original Gaussian filter.
- Visible Android 29+ WebView snapshots record a RenderNode on UI, render/read
  it on a dedicated worker and encode off UI. The single-frame ImageReader is
  drained before the producer is destroyed. This creates no window/input host.
  Headless/hidden screenshots retain software capture. Automatic thumbnails
  wait for native presentation, and a screenshot already on UI does not post
  another main-loop turn that could race tab detachment.
- Android management pages retain Material foreground motion while leaving the
  underlying native browser stationary. A uniform frosted settings sample
  skips its redundant blur; two pixel checks confirm the same appearance.

Physical-device evidence: Xiaomi 2112123AC, Android 11/API 30, same public Kelivo
homepage, profile/AOT, two menu/address/scroll rounds per style plus settings
and tabs. Input goes through Android InputDispatcher, not WidgetTester taps.
Each style switch checks an ordinary native Activity for taps, horizontal and
vertical swipes, and rejects embedded input windows on physical display 0.
All 48 phases completed successfully. Separate tests passed on all three
styles for real Sogou IME input, selection without opening IME, six retained-tab
round trips per style (text and scroll preserved), closing a focused tab during
IME resize, and fresh nonblank 440px native previews. Hardware key injection
was unsuitable for testing IME commits; actual keyboard touches were used.

Selected warmed Flutter total-span p95, R18 comparison -> R22, milliseconds:

| Operation | R18 | R22 |
| --- | ---: | ---: |
| Solid menu open | 13.119 | 12.311 |
| Solid menu close | 11.415 | 9.444 |
| Solid address open | 10.084 | 8.632 |
| Solid collapse / expand | 11.754 / 12.332 | 10.836 / 11.264 |
| Frosted menu open / close | 12.383 / 12.263 | 14.295 / 13.376 |
| Frosted collapse / expand | 14.313 / 17.934 | 13.118 / 15.139 |
| Frosted settings open / close | 16.530 / 18.111 | 13.461 / 13.096 |
| Liquid collapse / expand | 12.077 / 12.669 | 11.111 / 11.113 |

Across those 48 sampling windows, total spans over 16.67ms were 31/101/11
(solid/frosted/liquid) in the comparison and 28/46/12 in R22. Counts and phase
p95s include dispatch/settling frames, are not display-presented FPS, and are
not a controlled thermal benchmark. Some individual phases did not improve.
Device battery temperature was roughly 39-41 C, thermal service status 0.
This Android 11 device exercises liquid's existing unsupported-renderer
fallback; it does not validate shader glass on newer Android GPUs.

A subsequent six-phase settings run after skipping the uniform preview blur
passed: frosted open/close p95 12.381/11.634ms, solid close 8.587ms, liquid
open/close 9.042/9.950ms. First settings entry still had a roughly 118ms total
outlier (96ms raster). Disabling Material snapshotting did not remove that
cold outlier and was rejected. This is measurable improvement, not proof of
zero jank or stable 120 FPS across all actions/websites. Diagnostic visible
snapshot recording was usually 0.15-0.45ms versus roughly 9-14ms for hidden
software drawing; GPU rendering/readback and encoding occur separately.

Validation: 527 focused browser tests (including 26 pixel comparisons), three
Android native tests, the native scroll observer test, fatal-info root analysis
and diff/format checks. The full root/markstream suites were not rerun; R22 does
not change markstream and no commit was requested. Temporary timing logs and
input diagnostic Activity are excluded from the normal application. Normal
release entry is explicitly `lib/main.dart`; never use a diagnostic APK as the
normal application. The previous named R18 APK remains available for rollback.

R22 promotion status: keep the normal installed R18 package while real Release
interaction is checked in the separate, normally launchable Browser Probe app.
The cold outlier above is still open; do not interpret the successful functional
checks as acceptance of the complete performance objective. The normal installed
base APK was rehashed and still matched the named R18 rollback artifact
(`48f6e3bbf091af4ef883025d44b5a9ecc95a1a94204e74753f733b9c13c1ef96`).
The probe's diagnostic Activity was moved to the profile source set before its
normal-entry Release build, so that application contains no input-test Activity.

The normally launchable independent ARM64 Release was installed successfully as
`com.psyche.kelivo.browserprobe`, label `Kelivo Browser Probe`, version code 2080.
APK SHA-256: `f1ce1ccb27a5f4901665cc420455134d801713d51cf8a38a8a266186e5418409`.
Its debug signing certificate matches the isolated profile package; it cannot
replace the separately identified normal application. Launch completed (1079ms
Activity cold-start time, not browser-open latency). The input coordinator and
its ADB reverse mapping were stopped/removed. Normal R18 remains installed.
Manual Release feedback is pending; no commit or push was made.

After installing the independent Release, a read-only 66-second compositor
sample contained only 6 Flutter and 1 window presentation timestamps: it was
idle, not a manual browser interaction sample, and is not performance evidence.
Both installed APK hashes were rechecked: normal R18 unchanged, probe R22 exact.


### R22.1: repair independent Release startup and dependency parity

The first normally launchable R22 probe showed recovery, despite Android
reporting a successful Activity start. Its screen exposed
`NoSuchMethodError: SharedPreferencesApiRegistrar.getAll(...Continuation)`.
This was a dependency/build failure, not evidence of a damaged database.
`ActivityManager Status: ok` was insufficient startup validation.

The restored probe worktree had regenerated its ignored `pubspec.lock` instead
of retaining the normal browser worktree's graph. Its preferences implementation
was 2.5.1 (JNI/Pigeon suspend bindings), while the normal checkout used 2.4.28
(method channels). Its Release R8 mapping changed `kotlin.coroutines.Continuation`
to `p4.c`, and the APK method descriptor used `Lp4/c;`; the generated Dart JNI
binding still looked for `Lkotlin/coroutines/Continuation;`. Other Kotlin JNI
runtime type names were also obfuscated. Profile tests do not exercise R8.
The problem was confirmed from the package's bindings, its R8 mapping and DEX.

The scoped correction is to use the same dependency graph for the probe and
normal app. Copy `pubspec.lock` from the reference checkout before running
`flutter pub get --enforce-lockfile`, verify byte-for-byte equality before and after the Release build. Let Flutter
regenerate its Release plugin registrant: using `--no-pub` immediately after an
ordinary pub-get left the dev-only integration_test/native_splash registrations
in this SDK and failed Java compilation. Keep the graph outside discarded/archived generated state or
recopy the current reference lock when recreating an independent checkout.
The temporary keep-rule experiment for the unplanned upgrade was removed;
production application behavior and recovery safeguards are unchanged. No
reset, restore action, database deletion, or normal-package install was used.

Reference/probe lock SHA-256 after alignment:
`a834a14e792b70ec9c90eadb83de1cf1fa4975b8468ed299a7eb47d0531593a2`.
The invalid named R22 APK was quarantined as
`WITHDRAWN-r22-probe-invalid-dependencies.apk`. The prior relative profile
comparison used the same graph within its two arms, but that graph differed
from production; it must not be presented as full-app Release acceptance.


Dependency alignment also required a clean compile in the probe checkout.
The first incremental rebuild had correct old-version DEX but still carried the
new JNI registrar string in `libapp.so`; the actual startup therefore changed
from NoSuchMethodError to ClassNotFoundException. This was verified in the
artifact rather than attributed to device data. Before `flutter clean`, probe
APKs/reports and the matching lock were preserved outside the build tree.
After the clean, the freshly compiled Dart AOT no longer contained that JNI
registrar. Both native DEX and Dart AOT must match the locked graph, followed by
an actual application-page check; Activity-start success is not sufficient.


R22.1 final verification: clean independent Release installed successfully;
SHA-256 `5e71a8fff88c37ac743f9ae13e2fd55b14587b989340c123a0ec3a06c3866ef6`.
Both DEX and `lib/arm64-v8a/libapp.so` were checked for absence of the unintended
2.5.x JNI registrar, and root dependency locks matched before/after build.
Two cold launches were visually verified at the real New Conversation home
screen. The Kelivo website/browser menu was subsequently observed with the
foreground package confirmed as `com.psyche.kelivo.browserprobe`; input automation
was stopped for manual use. The installed normal package hash still exactly
matches R18. No data-reset or recovery action was performed. Performance
acceptance remains pending on this dependency-aligned, normally launched Release.

### R23: current tab previews, solid defaults and control updates

Tab overview explicitly requests a fresh thumbnail before covering the live
viewport. A request started after an older capture waits past that capture;
load completion during an in-flight partial image queues a completed-page
capture. Navigation, disposal and renderer-version checks still discard stale
results. The overview decodes and freezes one set of pixels before starting the
page-to-card flight, so the image is not swapped halfway through the animation.
Explicit overview requests may capture a page that is still loading resources;
automatic background captures still wait for load completion. The existing
440-physical-pixel preview limit and background Android encoder remain in use.
This introduces a bounded wait for a fresh thumbnail on tab-overview entry;
normal menu/keyboard transitions do not request a screenshot.

Solid is now the default in settings construction, missing/invalid serialized
settings and the page-local material scope. Explicitly saved liquid/frosted
choices are preserved. UA and search-engine rows share one trailing-value layout,
including ellipsis at narrow widths and large text scales.

A confirmed native history-item movement reconnects the scroll observer even
when a hash/History API/BFCache traversal does not produce load-stop. Android's
raw-pointer chrome path also retains the document-edge and short-content
rules, in CSS-normalized screen coordinates. Momentum alone still does not
reopen controls at the bottom. Selection-menu cleanup is initialized for both
Android composition modes, so a retained solid-created WebView can later use
texture composition without leaving its selection menu behind.

Control rendering changes:

- Press illumination and focus updates rebuild their own small feedback layers;
  unchanged optical surfaces do not subscribe to every touch-light frame.
- Navigation button widgets remain stable while their capsule widths animate.
- Menu contents retain a repaint layer during the morph. This uses a temporary
  display list/cache while the menu is mounted; contents remain live and retain
  their normal input and accessibility behavior.
- Solid startup and management entry do not wait for unused glass shader warmup.
  Selecting an optical material still prepares its renderer before use.

These changes do not replace Android's platform-view input host or add any
system input window. The normal application remains on its previous installed
version. The independent probe uses the same pinned dependencies as this tree.

Validation of the R23 source includes independent subagent review. Its selection
cleanup, Android edge behavior and partial-capture/load-stop findings were fixed
with regressions and re-reviewed with no remaining actionable finding. Native
Robolectric checks cover callback subscriptions, bounded screenshot encoding,
composition input-proxy switching, and selection cleanup after changing mode.

`integration_test/browser_ui_motion_bench.dart` uses a real Android WebView and
local HTTP pages, invokes the app's control callbacks for repeated back/forward
and menu motion, then scrolls and opens the overview without an idle capture.
It decodes the card thumbnail and verifies pixels from the new viewport. Control
callback invocation does not certify physical touch/IME dispatch. The independent
Android 36.1 emulator passed this current-pixel assertion.

In one emulator profile comparison (four warmed rounds, excluding round zero),
the means of each round's frame p50 were:

| Motion | UI build before/after (ms) | Raster before/after (ms) |
| --- | --- | --- |
| Back / one-to-two buttons | 0.651 / 0.480 | 15.474 / 13.643 |
| Forward / two-to-one buttons | 0.644 / 0.502 | 14.578 / 12.787 |
| Menu open | 0.598 / 0.472 | 28.619 / 21.585 |
| Menu close | 0.422 / 0.389 | 24.514 / 21.939 |

These are emulator frame-work samples, not screen-presented FPS or physical
Android 11 results. Host scheduling and slow outliers remain: the mean total-span
p95 improved for Back/menu-open, was nearly unchanged for Forward, and increased
for menu-close. This is evidence of reduced routine work, not proof that every
frame is within the refresh budget or that all modes are universally smooth.

Final R23 checks: fatal-info analysis of `lib test integration_test`, the full
root suite (8,417 tests), four Android host tests, and the native JS scroll
observer test passed. The main checkout's separate `markstream` package also
passed its analyzer and 290 tests; this older browser worktree does not yet
contain that path package. Changed project/patched vendor Dart sources are
formatted, and the staged whitespace check passes. Upstream vendor trailing
whitespace was normalized without reformatting its implementation.

The full suite exposed a pre-existing backup progress error: generated manifest
bytes increased the processed count although the total measured only source
files. The writer now excludes generated metadata from that progress counter,
while preserving archive bytes, hashes and per-chunk cancellation. The repair
and its additional progress assertions received independent review too.

The final independent normal-entry ARM64 Release was verified on emulator cold
startup and installed with `adb install -r` as `com.psyche.kelivo.browserprobe`.
APK SHA-256: `73e6378b37c61d3d4cd87435e042220e9b727aef02858298edb432c80b17bd2c`.
The physical phone remained locked, so R23 physical-device frame/input checks
were not performed. The normal `com.psyche.kelivo` APK still hashes to
`48f6e3bbf091af4ef883025d44b5a9ecc95a1a94204e74753f733b9c13c1ef96`;
it was not replaced, cleared or reset.
