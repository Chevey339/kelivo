# Markdown style tokens — validation and performance review

Date: 2026-10-20. Baseline: `cf2af98e`; implementation: `feat/markdown-style-tokens`.

These are the historical measurements for the style implementation in
`437e7c50`. See [the UI allocation follow-up](markstream_ui_optimization.md) for
the subsequent three-version comparisons; the batches should not be mixed.

The style and geometry changes are ready for human review. **The strict ±3%
performance acceptance criterion is not fully satisfied by the final measurements.**
The remaining tail-latency differences are retained below; no zero-regression or
physical-device frame-rate claim is made.

## Measurement protocol

Apple M4 Pro, macOS 26.5.2, Flutter 3.47.6 / Dart 3.13.5, debug Flutter test VM,
720 × 900 viewport at DPR 1. Both versions use the unchanged 30k/100k fixtures,
app adapters, selection controller and JetBrains Mono setup documented in
`../markstream_bench.md`. A tracked-file archive of `cf2af98e` received exactly
the same diagnostic benchmark file as the implementation. Five fresh processes
per version were interleaved, alternating which version ran first. Other
Flutter suites and image-report generation were stopped during these final runs.

The ordinary run keeps the original 64-token window and eight warm-up samples.
The separate instrumented batch repeats that window five times (280 measured
content frames per process). Rewinds and scrolling are outside the timing
windows. Cold rendering is measured once per fresh process. Phase collection
uses Flutter's native BUILD and root LAYOUT/PAINT markers; nested builders can
contribute to both BUILD and LAYOUT, so phase values must not be added together.
Raster time and operating-system frame scheduling are not measured.

All tables show the median of five per-process statistics, in milliseconds.
Raw final results are checked in alongside this report as
`markstream_style_tokens.json`. Earlier exploratory runs are not substituted
for these final paired batches.

## Original-protocol comparison

| Metric | cf2af98e | Style tokens | Change |
| --- | ---: | ---: | ---: |
| Scheduling median | 0.363 | 0.370 | +1.93% |
| Scheduling p95 | 0.652 | 0.762 | +16.87% |
| Content median | 2.051 | 2.084 | +1.61% |
| Content p95 | 3.376 | 3.486 | +3.26% |
| 100k cold frame | 517.125 | 503.460 | -2.64% |

The checked-in C46 baseline in `markstream_baseline.md` reported content
median/p95 2.334/3.599 ms and cold rendering 538.990 ms. The new measurements are
below those historical figures, but the same-batch `cf2af98e` comparison above
is the relevant non-regression check. Its content p95 increase exceeds 3%.

## Instrumented phases

| Metric | cf2af98e | Style tokens | Change |
| --- | ---: | ---: | ---: |
| Cold build | 334.695 | 334.032 | -0.20% |
| Cold layout | 341.466 | 342.132 | +0.20% |
| Cold paint | 4.853 | 3.869 | -20.28% |
| Content median build | 0.245 | 0.225 | -8.16% |
| Content median layout | 0.437 | 0.402 | -8.01% |
| Content median paint | 0.118 | 0.119 | +0.85% |
| Content p95 build | 0.517 | 0.564 | +9.09% |
| Content p95 layout | 0.891 | 1.049 | +17.73% |
| Content p95 paint | 0.213 | 0.251 | +17.84% |

The common-case phase medians and cold phases are within the non-regression
bound or faster. Content p95 is above the bound: build +0.047 ms, layout
+0.158 ms and paint +0.038 ms. These are diagnostic observations, not proof
of a causal or physical-device regression. A separate render-tree count found
15 visible paragraphs at the final append position in both versions, so the
paint difference must not be attributed to an increased visible paragraph
count. New token objects retain their private comparison values to avoid
allocating those lists again during value comparisons; the existing theme
value-equality rules and renderer caches are unchanged.

## Visual and geometry review

- Captured `styles-baseline` before edits and `styles-current` after edits with
  Flutter 3.47.6, following `test_goldens/README.md`: all 48 synthetic fixtures ×
  720/390 × light/dark × 1/1.3 = 384 images per version. All captures passed
  finite-geometry and rendering checks. The comparison report has no missing
  images. Agent visual inspection covered all 384 current images; the final
  fixed-width list-marker refinements were re-inspected in their 16 changed
  captures. Human visual approval remains pending.
- Local report: `test_goldens/out/styles-report/index.html`; contact sheets are
  under its `contact/` directory. Captures and report images are ignored build
  artifacts and are not included in the application or this commit.
- Additional live-chrome captures cover default, blue and green palettes,
  light/dark, pureBackground on/off, both widths and scales (48 images).
  These use Flutter 3.44.9 and a full-height viewport to avoid clipping the
  review capture through viewport culling. Borders remain soft on white and
  black surfaces. Local outputs: `test_goldens/out/styles-palette-*`.
- Eight additional captures exercise the actual Mermaid and PlantUML host
  widgets across both widths, brightnesses and text scales. Their chrome is
  36 px high and the selected tab fills the 22 px interior of the 26 px track.
  These captures use a synthetic Mermaid bitmap and a mocked PlantUML response;
  they validate the component shells, not either diagram engine or service.
  Local outputs: `test_goldens/out/styles-report/diagrams/`.
- The committed geometry tests use real JetBrains Mono at body sizes 14/15.7
  and text scales 1/1.3. Inline code keeps the plain-text line height (±0.5 px),
  with code/checkbox/radio centers within 0.75 px of baseline minus 0.35em.
  Code, shared diagram and both table-toolbar paths measure 36 px; diagram
  tabs measure 22 px at both scales; ordered
  9/10 items share a text origin; details summary row and body share the inset.
  Existing golden captures use Arial, Hiragino Sans GB, JetBrains Mono and
  Apple Color Emoji. No claim of exhaustive font or physical-device coverage
  is implied.

## Protected behavior

Parser and extension registration, streaming scheduling, prefix identity
forest, viewport culling, selection/copy algorithms, single-scaling helper,
repaint-boundary placement, code virtualization, table row limits and syntax
highlighting themes are unchanged. The application extension adapter only
passes the existing Markdown theme into PlantUML's shared chrome. New diagnostic
flags live in the benchmark and default to off. No dependency or CI change is
included.

## Final automated checks

The final source was checked with the isolated Flutter 3.44.9 / Dart 3.12.2 SDK:

- `flutter analyze --no-pub`: no issues.
- `dart analyze --fatal-infos lib test integration_test`: no issues.
- `dart analyze --fatal-infos test_goldens`: no issues.
- `flutter test --no-pub --concurrency=4`: all 8,127 tests passed. This includes
  the streaming height, static block, static chat-message, selection/copy,
  cached-prefix identity and new geometry regressions.
- In `dependencies/markstream`: `flutter pub get --offline`,
  `dart analyze --fatal-infos` and `flutter test --no-pub`: all 290 tests passed.
- The opt-in phase benchmark also ran successfully on 3.44.9. This is an API
  compatibility smoke check, not a replacement for the paired performance
  measurements above.
- Final Flutter 3.47.6 golden capture: all 389 tests passed, yielding the full
  384-image matrix. The separate palette captures and diagram-shell checks
  also passed.
- Changed Dart files are formatted; `git diff --check` passes. Source hashes
  were checked after the full suite to confirm no subsequent source edits.

An earlier full-suite attempt encountered two failures in untouched tests:
the local HTTP streaming-timeout test and the migration retry test. Both
passed in isolated baseline and current runs; the final complete run above
passed without changing or skipping either test. An intermediate run was
stopped for the final tab-height correction and is not counted as a pass.

The functional and visual checks pass. Human visual approval and the strict
±3% performance gate remain open.
