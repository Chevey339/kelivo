# Markdown backdrop tokens: validation and performance

This is the historical report for the two original commits, before independent
review. Subsequent correctness repairs and fresh measurements are documented in
[`markstream_backdrop_review.md`](markstream_backdrop_review.md). The source
hashes and passing phase batch below must not be attributed to later revisions.

Date: 2026-10-22. Comparison baseline: `a8364707`. Branch parent: `22c384b5`
(the intervening change is the already-merged long-image export fix).
The surface commit is `ec0a355e`; this report accompanies the subsequent
comment-contrast commit and measures the combined final sources.

The final five-round plain and wallpaper batches pass the fixed-fixture
**build/layout/paint regression gates**: every cold, content-median and
content-p95 phase is at most +3% relative to the baseline. Improvements larger
than 3% are retained. **The broader all-metric ±3% target is not met.** Some
scrolling, long-streaming and scheduling samples remain above +3%, as shown
below. On October 22 the user explicitly accepted completion with these
boundaries recorded. The raw exceptions have not been removed or reclassified
as passing.

## Retained changes

- Plain, wallpaper, frosted/tinted and solid-bubble contexts choose immutable
  alpha colors for existing decorations. No new render object or compositing
  layer is added. The existing chat backdrop scope publishes its already
  resolved `backgroundActive` boolean; per-message provider selectors and file
  checks are avoided. Gradient phase and live/cached blur mode are not inputs.
- Theme equality has a reflexive identity fast path. Distinct theme values
  still compare all fields, and all new fields participate in equality,
  `copyWith` and hashing. No parser, streaming, prefix-identity, viewport,
  virtualization, selection or cache algorithm is changed.
- Diagram preview areas no longer repaint the same translucent fill on top of
  their enclosing surface. Plain `<kbd>` keeps its old fill; the raised fill
  applies to wallpaper/bubble contexts. Export chooses the plain context, and
  table image capture composites its header onto the explicit opaque fill.
- Comment/quote/meta overrides preserve upstream emphasis and all other syntax
  colors. Plain colors are `#57606A` / `#9DA5B0`; wallpaper colors are
  `#4A525C` / `#BDC5D0` (light/dark). This wallpaper adjustment was authorized
  to prioritize contrast over the original fixed comment colors. Override
  maps and highlighter instances are canonical constants.

## Measurement protocol

Apple M4 Pro, Flutter 3.47.6 (framework `5fc346839b`), Dart 3.13.5. Same SDK,
lockfile and benchmark source on both sides. Five fresh processes per
benchmark/context/revision; A/B in odd rounds and B/A in even rounds, with
plain/wallpaper order also alternating. Processes ran serially; no validation
suite or build was intentionally run alongside the paired batches. Ordinary
desktop background work was not eliminated.

The final batch contains 60 processes: three benchmarks × two contexts × two
revisions × five rounds. Fixed-fixture phase collection uses five cycles,
280 content samples per process, the unchanged 30k/100k inputs, 720 × 900 at
DPR 1. Timeline and long-streaming loops, sample counts and fixtures are
unchanged. Wallpaper mode adds the same real chat backdrop host and fixed
gradient on both sides, with no image I/O, animation or blur consumers.

Tables use the median of five **per-process statistics**, not pooled p95s or
selected best runs. Percent change is `100 × (current / baseline − 1)`.
All raw output lines, commands, durations, source hashes, diagnostic summaries
and reproduction sources are in
[`markstream_backdrop_tokens.json`](markstream_backdrop_tokens.json).

These are debug test-VM UI measurements, not GPU raster timings, a native
profile, or iOS/Android device FPS. Build/layout markers can overlap and must
not be added together. A +3% threshold here is not a cross-device guarantee.

## Main phase gates

All values below are microseconds. Each cell is baseline → current (change).

| Metric | Plain | Wallpaper |
| --- | ---: | ---: |
| Cold build | 368526 → 360500 (-2.18%) | 358192 → 356758 (-0.40%) |
| Cold layout | 377142 → 362090 (-3.99%) | 475883 → 474165 (-0.36%) |
| Cold paint | 4084 → 4049 (-0.86%) | 2536 → 2372 (-6.47%) |
| Content median build | 313 → 282 (-9.90%) | 305 → 302 (-0.98%) |
| Content median layout | 550 → 528 (-4.00%) | 670 → 654 (-2.39%) |
| Content median paint | 157 → 156 (-0.64%) | 128 → 128 (+0.00%) |
| Content p95 build | 616 → 595 (-3.41%) | 671 → 600 (-10.58%) |
| Content p95 layout | 1024 → 1001 (-2.25%) | 1347 → 1260 (-6.46%) |
| Content p95 paint | 278 → 279 (+0.36%) | 238 → 228 (-4.20%) |

## Fixed-fixture pump boundaries

These are supplemental scheduling/whole-pump metrics, in microseconds.
The plain scheduling p95 is +3.30%, a remaining exception.

| Metric | Plain | Wallpaper |
| --- | ---: | ---: |
| Cold first frame | 545774 → 533469 (-2.25%) | 533088 → 531871 (-0.23%) |
| Scheduling median | 312 → 305 (-2.24%) | 518 → 530 (+2.32%) |
| Scheduling p95 | 545 → 563 (+3.30%) | 1048 → 1032 (-1.53%) |
| Content median | 1567 → 1465 (-6.51%) | 1464 → 1431 (-2.25%) |
| Content p95 | 2816 → 2812 (-0.14%) | 2945 → 2699 (-8.35%) |

## Supplemental scrolling

Milliseconds; all three tool-count scenarios are retained. The zero-tool
scroll averages and p90s remain above +3% in both contexts. Maximum-scroll and
root-rebuild measurements are also retained in JSON.

| Context | Tools | Scroll average | Scroll p90 |
| --- | ---: | ---: | ---: |
| plain | 0 | 13.92 → 14.95 (+7.40%) | 16.8 → 17.58 (+4.64%) |
| plain | 4 | 19.15 → 18.4 (-3.92%) | 24.62 → 22.77 (-7.51%) |
| plain | 12 | 22.46 → 22.59 (+0.58%) | 24.78 → 24.89 (+0.44%) |
| wallpaper | 0 | 14.07 → 15.08 (+7.18%) | 17.74 → 19.24 (+8.46%) |
| wallpaper | 4 | 19.56 → 19.31 (-1.28%) | 26.15 → 23.88 (-8.68%) |
| wallpaper | 12 | 23.88 → 23.03 (-3.56%) | 27.52 → 24.4 (-11.34%) |

## Supplemental long streaming

Microseconds. All 12 scenarios per context are shown. Scheduling, content and
scroll-stage timings are additionally retained in JSON, including every
above-threshold result. Neither an improving p95 nor a fast main phase gate
cancels a regressing median in this table.

| Context | Input size / shape | Median | p95 |
| --- | --- | ---: | ---: |
| plain | 20-paragraphs | 3007 → 2792 (-7.15%) | 4806 → 4600 (-4.29%) |
| plain | 20-lines | 3512 → 3496 (-0.46%) | 6041 → 6744 (+11.64%) |
| plain | 20-single | 2341 → 2564 (+9.53%) | 3811 → 4144 (+8.74%) |
| plain | 20-code | 5294 → 5557 (+4.97%) | 6364 → 6590 (+3.55%) |
| plain | 200-paragraphs | 2233 → 2356 (+5.51%) | 3657 → 3656 (-0.03%) |
| plain | 200-lines | 5834 → 5988 (+2.64%) | 7862 → 7584 (-3.54%) |
| plain | 200-single | 4291 → 4012 (-6.50%) | 4839 → 4772 (-1.38%) |
| plain | 200-code | 4755 → 4818 (+1.32%) | 6795 → 6779 (-0.24%) |
| plain | 2000-paragraphs | 2357 → 2375 (+0.76%) | 4544 → 4383 (-3.54%) |
| plain | 2000-lines | 41197 → 39162 (-4.94%) | 59510 → 58213 (-2.18%) |
| plain | 2000-single | 26683 → 25839 (-3.16%) | 40055 → 36019 (-10.08%) |
| plain | 2000-code | 9000 → 10159 (+12.88%) | 19570 → 17261 (-11.80%) |
| wallpaper | 20-paragraphs | 2957 → 2902 (-1.86%) | 5227 → 5003 (-4.29%) |
| wallpaper | 20-lines | 3345 → 3368 (+0.69%) | 5343 → 4747 (-11.15%) |
| wallpaper | 20-single | 2508 → 2667 (+6.34%) | 4093 → 4048 (-1.10%) |
| wallpaper | 20-code | 5382 → 5779 (+7.38%) | 6879 → 6592 (-4.17%) |
| wallpaper | 200-paragraphs | 2883 → 2684 (-6.90%) | 4732 → 4316 (-8.79%) |
| wallpaper | 200-lines | 6250 → 6046 (-3.26%) | 7767 → 8385 (+7.96%) |
| wallpaper | 200-single | 4338 → 4327 (-0.25%) | 5570 → 5278 (-5.24%) |
| wallpaper | 200-code | 4916 → 5044 (+2.60%) | 6988 → 6717 (-3.88%) |
| wallpaper | 2000-paragraphs | 2523 → 2372 (-5.98%) | 4031 → 3981 (-1.24%) |
| wallpaper | 2000-lines | 40631 → 39978 (-1.61%) | 63191 → 58130 (-8.01%) |
| wallpaper | 2000-single | 27333 → 26910 (-1.55%) | 40129 → 38310 (-4.53%) |
| wallpaper | 2000-code | 9487 → 9692 (+2.16%) | 18295 → 14599 (-20.20%) |

## A/A control and diagnostic limits

A separate five-round control ran **a8364707 on both sides**, using the same
final host and both supplemental benchmarks (40 processes). It also contained
above-3% measurements: 14 of 72 plain metric rows and 26 of 72 wallpaper rows.
The final candidate batch has 24 of 86 plain rows and 14 of 86 wallpaper rows
above +3% (these denominators additionally include the fixed-fixture metrics).
These are correlated metrics, not independent statistical trials.

For example, the same-revision wallpaper 2000-paragraph scheduling measurement
varied by about +23%, and plain 20-line p95 by about −29%. However, the A/A
zero-tool scroll average was near −1%, so the control does **not** establish
that the candidate's +7% zero-tool scroll result is only noise. Supplemental
regressions remain unresolved under this short debug protocol; no general
zero-regression or 120 FPS claim is made.

A separate VM CPU sample of the 20-single scenario used a 50 µs period and
128-frame stack limit. Baseline/current had 1,986/1,872 samples over
185,308/171,412 µs. Most exclusive ticks were VM/debug dispatch or waiting;
the sample did not locate a new backdrop/highlighter hotspot. Sampling overhead
and this single scenario prevent a causal conclusion. Instrumented elapsed
times are not used as speedup evidence; compact function samples are in JSON.

All exploratory batches are retained separately, never pooled with the final
batch. The initial literal-selector version (`final` in the raw filenames)
failed several main gates. `scope` reused stable scene metadata, and
`optimized` additionally used reflexive equality. The initial manual wallpaper
host was replaced by the real publisher in **both** sides of the later batches;
only the final identical-host comparison is used for the reported gate result.

## Geometry, contrast and visual evidence

Timeline render-object counts are unchanged in every pair: plain
1,268/1,026/1,014 and wallpaper 1,277/1,035/1,023 for 0/4/12 tools.
The new inherited surface context adds 5/4/2 non-rendering elements in these
scenarios. It does not add render objects. Raw extents, correction counts and
all five geometry measurements are in JSON.

The streaming regression test appends 20 times while preserving the exact
prefix code widget, equivalent theme/hash and layer topology. Existing frosted
surface golden tests remain unchanged. New wallpaper snapshots cover
light/dark × code/table/details/diagram with the fixed provided photo. These
exercise actual chrome and fills; diagram content is a deterministic mocked
bitmap, not a live renderer or network response.

Before the separate comment correction, all 384 plain captures were
pixel-identical to the branch-parent baseline. With comments, 368 are identical
and 16 change: only `07_code_dollars` and `43_html_block`, each at
390/720 × light/dark × 1.0/1.3. No image dimensions change. The two new wallpaper
code snapshots also change in the comment commit. Local HTML reports:

- `test_goldens/out/backdrop-surfaces-report/index.html`
- `test_goldens/out/backdrop-report/index.html`

Contrast tests use the actual default palette, both brightnesses, all 41 mask
steps from 0 to 2, and solid black/white/#808080 underlays. Assertions pass for
code ink ≥7, comments ≥4.5, table body ≥4.5 and ink3 ≥3. Plain comments also
meet ≥4.5 on the opaque fill. This validates the specified compositing model,
not arbitrary user-selected foreground colors or every possible palette.
Table PNG capture verifies opaque alpha and the expected blended header pixel.
Message-export context is locked to plain by a widget test.

## Validation

- `dart analyze --fatal-infos lib test integration_test test_goldens` (analyze): exit 0; `No issues found!`.
- `flutter analyze --no-pub lib test integration_test test_goldens` (flutter-analyze-app): exit 0; `No issues found! (ran in 11.2s)`.
- `flutter test --no-pub --concurrency=8 --reporter expanded` (root-tests): exit 0; `13:16 +8265: All tests passed!`.
- `dart analyze --fatal-infos` (nested-analyze): exit 0; `No issues found!`.
- `flutter test --no-pub --reporter expanded` (nested-tests): exit 0; `00:07 +296: All tests passed!`.

The additional unrestricted `flutter analyze --no-pub` is **not clean**:
1,594 diagnostics come from unrelated vendored packages whose test-only
dependencies are not initialized in this checkout. The same invocation on
the a8364707 baseline gives 1,595; normalized comparison finds no added
diagnostics (one existing token-estimator regexp diagnostic is absent on the
branch parent). The application-scoped analyzer and the separately initialized
markstream package are the repository's applicable pre-commit gates. No analyzer
rules were relaxed and no unrelated vendored dependencies were edited to hide
this boundary.

No CI, pubspec, dependency-version or l10n changes. The photo, PNGs, benchmark
data and diagnostic sources are test-only and are not added to application assets.
No new physical-device run or release artifact is claimed for this change.

## Reproduction

1. Check out the two local commits on a clean branch with the recorded SDK.
   Create an ignored `.scratch/backdrop-base` from `git archive a8364707`.
2. Copy the current `pubspec.lock`, the three `test/perf/*_bench.dart` files
   listed in the JSON harness hashes, and `test/support/markdown_backdrop_host.dart`
   into that baseline. Run root `flutter pub get --offline` in each checkout.
   Do not copy production sources into the baseline.
3. Restore the two Python files from JSON `reproductionSources` under `.scratch/`.
   `python3 -u .scratch/run_backdrop_bench.py optimized` runs the full final
   sequence; use a new output label to avoid replacing retained logs. The
   `control` label intentionally runs both sides against the baseline and
   only measures scrolling/long streaming.
4. Run the summarizer with the recorded JSON path to obtain the same aggregation:

   ```sh
   python3 .scratch/summarize_backdrop_bench.py .scratch/backdrop-perf-<label>/results.json
   ```

The underlying fixed-fixture command is:

```sh
flutter test --no-pub test/perf/markstream_render_bench.dart \
  --dart-define=MARKSTREAM_PROFILE_PHASES=true \
  --dart-define=MARKSTREAM_BENCH_CYCLES=5 --reporter expanded
```

Add `--dart-define=MARKSTREAM_BENCH_WALLPAPER=true` for the wallpaper context.
The other two commands replace the target with `timeline_scroll_bench.dart` or
`long_streaming_bench.dart` and omit the two phase/cycle defines. Source hashes
refer to the exact measured working-tree content; the then-current HEAD stored
in raw metadata predates the final amend and is not a standalone benchmark
revision. For the A/A control, the current-labelled process still executes
a8364707, as explicitly recorded in `measurementRevisions`.
