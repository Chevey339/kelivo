# C24 acceptance work record

This record distinguishes deterministic tests, native Flutter execution, real
keyboard interaction and profile measurements. Unfinished items below are not
passing evidence. Windows is paused at the user's request after a blue screen;
Linux acceptance, physical iPhone work and macOS Chinese IME are deferred by
the user. No cause of the Windows crash has been established.

## Composed scenarios and visual coverage

The shared synthetic S1–S6 sources live in
`lib/features/intelligent_ui/widgets/gallery/scenario_sources.dart`. They use the
production MessageListView, GenUI adapter, native controls, ChatInputBar, draft
staging dialogs and database context-write transaction. The test send sink stays
local; it does not claim provider or network-generation coverage. S1 storage is
closed and reopened against the same temporary SQLite file, which verifies
repository/widget reconstruction, not process-kill recovery.

The scenario flow verifies three calculator inputs and result/unit, restored
values, theme/scale/RTL preservation, sampled domain gaps and chart/table
agreement, legend/tooltip/data access, stable sort ties/null-last/filter/page,
hidden empty required fields, first-error focus and hidden-value retention. Ask
freezes known values, produces an editable composer chip, sends the frozen text
and preserves the historical context after later successful UI mutations.

Native runs observed zero GenUI WebView creations for all six scenes:

| Environment | Current evidence |
| --- | --- |
| Android physical 2112123AC, Android 11, adb fee8c1be | Six scenes passed including interpolation and rendering corrections; final C26 rerun follows the last semantic-projection repair |
| macOS 26.5.2 (25F84) | Six scenes passed including Ctrl/Cmd+A; final C26 rerun follows the last semantic-projection repair |
| iPhone 17 simulator, iOS 26.5 (23F77) | Six scenes passed including the interpolation correction; this is not physical-iPhone acceptance |

Ignored raw logs and machine-readable results are in `build/genui/c24/` and
`build/genui/logs/c24-native-ios-simulator.log`. The simulator uses the separate
`psyche.kelivo.genuiacceptance` bundle; all five temporary iOS identity files were
restored after the run. App-wide providers remain alive across scenario changes,
matching application lifetime; only the isolated chat repository is reopened.
The first Mac fixture incorrectly recreated TTS between scenes and failed during
asynchronous disposal. That failed run is retained and is not counted as passing.

The new visual matrix contains 104 goldens: 32 combinations each for S1, S6 and
the five shell states (light/dark, solid/frosted wallpaper, LTR/RTL, 1.0/1.3,
390/900), plus mobile-light and desktop-dark views of S2–S5. It reuses
`markdown_backdrop_host.dart` and the existing deterministic test font. Existing
component, chip, dialog, expansion and Web-card matrices remain in the normal
test suite. Six additional checks verify opaque card and chart/text contrast in
solid, frosted and tinted scopes. Goldens are not evidence of keyboard behavior
or operating-system screen-reader operation.

Seven existing `chart_gaps_*` baselines were reviewed and refreshed for the
measured dense-marker optimization. Their 81 records, 19 missing points, curve,
axes, gap hatching and hit targets are unchanged; only overlapping decorative
markers are spaced. The first full run correctly detected these seven stale
baselines and is retained as a failed run. The final G result below must come
from a complete run after the refresh, not from the focused golden update.

## Native keyboard acceptance

Android physical 2112123AC passed the real Sogou keyboard flow, driven by native
adb touches rather than TestTextInput. Chinese `ni` remains in Sogou's candidate
bar; the app receives no composing range for that stage. Native F8 observation
acknowledgements before and after the appearance change distinguish this from
a range assertion. No retyping is allowed between those observations. The candidate stayed
available through the appearance change and choosing `你` committed exactly that
text. English `abc` did produce a real composing range: the test verified that
changing theme and scale preserved the same controller, text, selection and
range, while accepted state remained `你` until the literal candidate committed.
Sogou's native Select All selected all four characters, native typing replaced
them with `kelivo`, and the multiline Return produced `a\nb` without an Ask.

The passing log/result and screenshots are in `build/genui/c24/` under
`android-native-ime-complete.log` and `android-native-ime.json`. Earlier runs
waiting for a Chinese composing range and a selection-driver timeout are
diagnostics, not passes. The original default input method was restored after
the temporary Baidu check. Chinese external-preedit observation is not evidence
that this Android keyboard emitted a composing range.

macOS Chinese IME was explicitly deferred by the user. A separate ordinary
WidgetsFlutterBinding probe verified native English entry, appearance changes
and Escape returning the same value to the inline view. It did not establish
Chinese composition or native Select All. The first integration-binding run
crashed in the engine's AccessibilityBridge on initial AX inspection; using
OS-controlled semantics removed that observed crash. The second integration
run had a reentrant editing assertion during a semantics callback and timed out
waiting for Chinese composition. Neither failed run is passing evidence. The
ordinary-binding English probe did not reproduce that assertion. No SDK or
production-input workaround was introduced on this evidence.

Native scenario runs now leave semantics enablement to the OS. Widget scenario
runs separately own a semantics handle and retain all tree assertions. This
avoids a test-only forced handle before the native bridge exists; it does not
disable platform accessibility. Upstream has a [related bridge crash report](https://github.com/flutter/flutter/issues/175041), but identical stack names do
not establish that our observed test failure has the same root cause.

## Corrections found by composed acceptance

- An expanded view's Ask action previously moved keyboard focus to the covered
  composer, so Esc no longer closed the expansion. External draft staging now
  focuses the composer only when its route is current. The combined flow and
  existing composer regressions passed (42 tests).
- Weighted interpolation across a finite cross-zero interval could make an
  exact grid zero slightly negative. In a 13-point [-2,4] sample this invented a
  square-root domain gap and missed reciprocal division-by-zero. Finite spans
  now use an offset interpolation; weighted interpolation remains for spans that
  would overflow. Endpoint, monotonic and extreme-range tests are retained, with
  explicit zero-boundary regressions added.
- Ordinary-binding Android profiling found repeated numeric identity-hash
  collisions in expression result-size checks, repeated axis/table paragraph
  measurement, and dense per-point marker painting. The shape cache now uses
  scalar value hashes (immutable List/Map values retain identity equality).
  A bounded per-widget text-width cache includes appearance and direction.
  Dense line/area charts space decorative markers along X while retaining every
  vertex, hit target, gap endpoint, isolated value and active marker; scatter
  points are unchanged. The focused evaluator/chart/table suite passed 62 tests,
  including an actual hit on a dense point whose default marker is hidden.
  A single repaint boundary retains the chart base during hover while a separate
  painter draws the active marker. On the same Android fixture, 2,000-slot hover
  changed from build/raster p95 17.8/21.2 ms and 99.58% slow frames to 4.885/5.927
  ms and 0.418%. This establishes benefit for this boundary; it does not make
  sustained data updates pass. The original trace and diagnostic CPU samples
  remain under `build/genui/c24/`.

The final cross-module review also found a historical-message boundary: a
persisted reasoning/tool split can cut the first raw fence into ordinary code,
leaving the original fourth fence within the visible three-card budget. Copy,
TTS, export capture and search previously truncated by raw ordinal and lost that
visible card. They now reuse the timeline's source resolution and presentation
ordinals for historical splits; raw source authority and storage leases are
unchanged. Regressions compare with the renderer for reasoning and tool splits,
retain frozen values, reject mismatched split counts and verify actual SQLite
search indexing. A shared stored-chronology adapter also keeps both PNG export
card variants aligned when thinking/tool cards are hidden, including single
reasoning text, multiple segments within one part and duplicate tool events.
Twelve additional production export-card cases and the existing stream event
deduplication regressions passed together (83 tests), including malformed tool fields and
overflowing JSON numbers. A compiler run stopped when disk space was exhausted;
only this worktree's rebuildable compiler caches were removed, and the full
focused run then passed. A later SQLite test also reported disk-full; after
space recovered to about 29 GiB, all ten tests in that search file passed
unchanged. Both infrastructure-failed logs remain under build/genui/. The earlier in-progress G was stopped to fix this finding.
These final text/index changes do not alter the profiled chart/input rendering.

## Ordinary-message profile comparison

The C01 `a11b9a9b` source was extracted with `git archive` into an ignored build
copy. Both builds use the same pinned Flutter executable and five identical
fixture files (recorded in `build/genui/c24/baseline/fixture-hashes.json`). The
candidate lockfile seeded the offline baseline resolution: fl_chart was absent,
webview_windows resolved to hosted 0.4.0 instead of the local fork, and two
WebView dependencies changed only direct/transitive classification. These
dependencies are not instantiated by the ordinary-message fixture.

Five eight-second traversals of the same 200-message history on the physical
Android device produced mean build time +2.292% and mean raster time -3.444%
relative to C01. Build is within the stated 3% band; the raster improvement is
slightly outside its literal symmetric band, so this is not an exact ±3% result.
The result shows no measured regression above 3% in either stage in this run,
not statistical equivalence. Baseline scroll itself has 3.58–6.11% slow frames
at the device's 120 Hz / 8.333 ms budget. Both versions produced zero frames
during five seconds of idle. Raw per-sample values are retained in
`build/genui/c24/ordinary-history-comparison.json` and both logs.

## Native profile observations

The detailed [profile record](performance-c24.json) retains every sample and the
refresh-rate/semantics conditions. On macOS M4 Pro / 120 Hz, input-to-raster p95
is 11.506–18.778 ms, drag/hover slow-frame ratios are 0–0.429%, and mixed-history
scroll is 0.415–0.831%. OS semantics was off in that performance run, so it does
not establish screen-reader performance.

On Android 2112123AC / Adreno 650 / Skia / 120 Hz, with the existing accessibility
service enabled, S1/S2/S6 response p95 is 17.283/40.636/27.041 ms; the maximum
500-row × 4-series chart is 55.298 ms and misses 50 ms. S2/S6/maximum-chart drag
has 13.107/57.801/100% frames above the 8.333 ms stage budget; maximum-chart hover
is 0.422%, mixed-history scroll 3.557–4.354%. These drag/scroll targets remain
unmet. On 2026-10-24 the user explicitly accepted these measured Android
performance limits for this delivery. This is an acceptance exception, not a
claim that the targets passed. No budget was silently reduced, no dashed
series or data point was removed to obtain a better score. A temporary
accessibility-off diagnostic did not fix the bottleneck and the original
service was restored. CPU traces identify remaining text layout and fl_chart
path-dashing cost. A trial custom stroke renderer provided no gain and was
removed.

Both native profiles reported zero idle frames in ten seconds, zero remaining
transient callbacks and zero GenUI WebViews. Eight mount/unmount cycles ended
at about 272 MiB Android RSS and 191 MiB Mac RSS. RSS includes engine/font/GPU
caches; these observations are not a proof that every allocation was released.

## C24 execution status

- macOS Chinese IME and physical iPhone remain deferred by the user.
- Completed print-only profile benches on the available physical Android and Mac.
  The first test-binding run is retained as a diagnostic only: this SDK's
  LiveTestWidgetsFlutterBinding schedules another engine frame even with
  benchmarkLive, so its idle and slow-frame figures are not product evidence.
  The replacement tool/*_profile_bench.dart executables use ordinary
  WidgetsFlutterBinding with timer-based idle waits. Input states are matched to
  raster completion by engine frameNumber; coalesced inputs are reported rather
  than counted as separately presented. Hardware input and display scanout are
  excluded; build and raster budgets are assessed separately.
- Completed five identical ordinary-history scroll samples against an archived
  C01 build snapshot on the same Android device. It is a build copy, not another
  development worktree. Record dependency resolution and fixture equality.
- Recorded 501-point sampling, 2,000-slot chart updates/hover, mixed native-history
  scroll, idle scheduling and mount/unmount memory observations. Process RSS
  includes engine/font/GPU caches and is not an assertion that all caches free.
- Independent review has no remaining findings. The frozen-source final G
  passed: root fatal-info analysis, 10,147 root tests (one existing skip),
  markstream dependency resolution and fatal-info analysis, 298 markstream
  tests, macOS debug build and diff whitespace check. The final run includes
  all refreshed and added golden baselines; earlier failed/aborted logs remain
  separate. All 31 changed Dart files were formatted.
- C25 final paid model evaluation and C26 final-HEAD builds/old-reader restore
  remain separate later steps.
