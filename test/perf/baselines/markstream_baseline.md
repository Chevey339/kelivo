# Markstream renderer performance baseline

## Before migration — 2026-10-17

- Measurement revision: `78574c13129bd25c11c6488933018daf7aecde06` (C03).
  Production renderer is unchanged from `4588c264`.
- Flutter 3.47.6 stable, framework `5fc346839b`, Dart 3.13.5.
- macOS 26.5.2, Apple M4 Pro, arm64, 24 GiB RAM.
- Mode: debug Flutter test VM, viewport 720 × 900, pixel ratio 1.
- Fixtures: `test/fixtures/markdown/markstream_documents.dart`; synthetic only.
  Both fixtures have five fenced code blocks and two tables. Fingerprints are
  asserted by `test/shared/markdown/markstream_fixture_test.dart`.
- Method: five fresh processes, one cold document render followed by 64 tail
  tokens per process; the first eight append samples warm up. An empty host
  initializes the framework before timing, without invoking Markdown code.
  See `../markstream_bench.md` for the exact commands and measurement boundary.

### Fixed-fixture results

These summaries are the median of five per-round metrics, not a pooled p95.
All values below are milliseconds. The observed range is reported without
inventing a noise tolerance or turning benchmark timings into assertions.

| Metric | Median of five rounds (ms) | Observed range (ms) |
| --- | ---: | ---: |
| 30k first pump: median | 1.270 | 1.242–1.538 |
| 30k first pump: p95 | 2.413 | 2.237–2.599 |
| 30k deferred content pump: median | 2.003 | 1.892–2.544 |
| 30k deferred content pump: p95 | 3.147 | 2.982–3.622 |
| 100k cold document: first frame | 814.392 | 796.361–840.875 |

The first pump in the old renderer only schedules its 50ms coalescing timer;
its deferred content pump includes the new token's parse/build/layout/paint.
Both are retained so a cheap request frame cannot conceal deferred rendering
work. Neither measurement includes raster time. Scrolling is outside the two
append samples; the fake-clock 50ms advance is not 50ms of wall-clock waiting.

The migration targets are both append median/p95 ≤2ms on desktop, no worse
than the corresponding baseline, and 100k cold document rendering ≤100ms.
The old renderer's deferred append p95 and cold frame exceed those targets.
This baseline establishes the comparison; it does not claim the target is met.

Raw output (five independent test processes):

```text
MARKSTREAM_RENDER {"run":1,"appendChars":30000,"coldChars":100000,"samples":56,"firstPumpMedianUs":1242,"firstPumpP95Us":2273,"contentPumpMedianUs":1892,"contentPumpP95Us":2982,"coldFirstFrameUs":840875}
MARKSTREAM_RENDER {"run":2,"appendChars":30000,"coldChars":100000,"samples":56,"firstPumpMedianUs":1243,"firstPumpP95Us":2237,"contentPumpMedianUs":1995,"contentPumpP95Us":3088,"coldFirstFrameUs":796361}
MARKSTREAM_RENDER {"run":3,"appendChars":30000,"coldChars":100000,"samples":56,"firstPumpMedianUs":1270,"firstPumpP95Us":2599,"contentPumpMedianUs":2003,"contentPumpP95Us":3147,"coldFirstFrameUs":822426}
MARKSTREAM_RENDER {"run":4,"appendChars":30000,"coldChars":100000,"samples":56,"firstPumpMedianUs":1538,"firstPumpP95Us":2576,"contentPumpMedianUs":2544,"contentPumpP95Us":3622,"coldFirstFrameUs":814392}
MARKSTREAM_RENDER {"run":5,"appendChars":30000,"coldChars":100000,"samples":56,"firstPumpMedianUs":1405,"firstPumpP95Us":2413,"contentPumpMedianUs":2229,"contentPumpP95Us":3602,"coldFirstFrameUs":811443}
```

### Existing diagnostic benchmarks

The existing long-stream benchmark reports three pumps plus scrolling, and its
`stages` are averages. Those figures must not replace the fixed-fixture first
pump/content-frame distributions. Skill preview figures retain their existing
font and loading setup and can only be compared with the same benchmark after
migration. These are one diagnostic batch each, not five-round summaries.

Commands:

```sh
flutter test --no-pub test/perf/long_streaming_bench.dart \
  test/perf/skill_preview_bench.dart --concurrency=1 --reporter expanded
```

```text
LONG_STREAM shape=paragraphs paragraphs=20 chars=1974 medianUs=3413 p95Us=7285 stages=[3238, 377, 448]
LONG_STREAM shape=lines paragraphs=20 chars=1859 medianUs=1587 p95Us=2592 stages=[1587, 74, 76]
LONG_STREAM shape=single paragraphs=20 chars=1859 medianUs=1335 p95Us=3007 stages=[1331, 105, 93]
LONG_STREAM shape=code paragraphs=20 chars=1867 medianUs=6332 p95Us=8835 stages=[5667, 801, 240]
LONG_STREAM shape=paragraphs paragraphs=200 chars=17734 medianUs=2630 p95Us=4709 stages=[978, 1751, 271]
LONG_STREAM shape=lines paragraphs=200 chars=17439 medianUs=1838 p95Us=3570 stages=[598, 1351, 80]
LONG_STREAM shape=single paragraphs=200 chars=17439 medianUs=2072 p95Us=6339 stages=[692, 2101, 175]
LONG_STREAM shape=code paragraphs=200 chars=17447 medianUs=3834 p95Us=5423 stages=[553, 3318, 175]
LONG_STREAM shape=paragraphs paragraphs=2000 chars=177134 medianUs=2455 p95Us=3910 stages=[899, 1516, 238]
LONG_STREAM shape=lines paragraphs=2000 chars=175039 medianUs=1622 p95Us=2390 stages=[560, 1219, 58]
LONG_STREAM shape=single paragraphs=2000 chars=175039 medianUs=2067 p95Us=2892 stages=[667, 1412, 88]
LONG_STREAM shape=code paragraphs=2000 chars=175047 medianUs=3884 p95Us=7164 stages=[929, 3545, 43]
RESULT sections=100 blocks=false chars=23718 loadMedianMs=339.32 scrollMedianMs=1.53 scrollP90Ms=2.11
RESULT sections=100 blocks=true chars=23718 loadMedianMs=235.26 scrollMedianMs=1.68 scrollP90Ms=2.62
RESULT sections=250 blocks=false chars=59463 loadMedianMs=1028.19 scrollMedianMs=3.41 scrollP90Ms=4.47
RESULT sections=250 blocks=true chars=59463 loadMedianMs=658.66 scrollMedianMs=2.12 scrollP90Ms=3.93
```

### Device evidence

Physical Android profile measurements are deferred as requested by the user.
Only an Android emulator was connected during M0. There is no physical-device
`FrameTiming.buildDuration` median/p95 or raster p95 in this baseline, and no
claim against the Android ≤4ms target. Real conversation exports are likewise
deferred; the current corpus is synthetic.

## M2 package checkpoint — C30

- Measurement tree: C30 implementation following `41ab9b24`; same machine, SDK, fixed fixtures, font, viewport and sampling protocol as M0.
- Five fresh Flutter test VM processes; package renderer with rich blocks and a selection controller. Application highlighter, math, image and link adapters are not installed in this package benchmark.
- Host is macOS; the Flutter test theme platform is Android, matching the test framework default used by the original harness. Font weights use the same application mapping as the original harness.
- Other Flutter suites had finished before these five runs. iOS Simulator services and WindowServer were active (observed load averages 6.52 / 6.93 / 6.23). Treat this as a local checkpoint with background load, not controlled evidence attributing a regression to one change.

| Metric | Median of five rounds (ms) | Observed range (ms) |
| --- | ---: | ---: |
| 30k first pump: median | 0.383 | 0.368–0.395 |
| 30k first pump: p95 | 0.613 | 0.496–0.822 |
| 30k deferred content pump: median | 2.478 | 2.391–2.525 |
| 30k deferred content pump: p95 | 3.729 | 3.449–3.830 |
| 100k cold document: first frame | 484.370 | 481.829–495.843 |

The scheduling frame improved, but the actual content median/p95 exceed the desktop 2 ms goal and the original content baseline. The cold frame is below the original baseline but remains above 100 ms. **The desktop performance acceptance criteria are not met.** Keep these gaps open through application integration and C41; do not substitute the cheap scheduling frame for the content frame. Physical Android measurements remain deferred.

```sh
cd dependencies/markstream
for markstream_round in 1 2 3 4 5; do
  MARKSTREAM_RUN=$markstream_round flutter test --no-pub \
    test/perf/streaming_append_bench.dart --reporter expanded
done
```

Raw output:

```text
MARKSTREAM_RENDER {"run":1,"appendChars":30000,"coldChars":100000,"samples":56,"firstPumpMedianUs":383,"firstPumpP95Us":496,"contentPumpMedianUs":2488,"contentPumpP95Us":3830,"coldFirstFrameUs":481907,"themePlatform":"android","hostOS":"macos","selectionController":true,"appAdapters":false}
MARKSTREAM_RENDER {"run":2,"appendChars":30000,"coldChars":100000,"samples":56,"firstPumpMedianUs":368,"firstPumpP95Us":613,"contentPumpMedianUs":2391,"contentPumpP95Us":3449,"coldFirstFrameUs":492316,"themePlatform":"android","hostOS":"macos","selectionController":true,"appAdapters":false}
MARKSTREAM_RENDER {"run":3,"appendChars":30000,"coldChars":100000,"samples":56,"firstPumpMedianUs":385,"firstPumpP95Us":645,"contentPumpMedianUs":2468,"contentPumpP95Us":3729,"coldFirstFrameUs":481829,"themePlatform":"android","hostOS":"macos","selectionController":true,"appAdapters":false}
MARKSTREAM_RENDER {"run":4,"appendChars":30000,"coldChars":100000,"samples":56,"firstPumpMedianUs":395,"firstPumpP95Us":822,"contentPumpMedianUs":2525,"contentPumpP95Us":3602,"coldFirstFrameUs":495843,"themePlatform":"android","hostOS":"macos","selectionController":true,"appAdapters":false}
MARKSTREAM_RENDER {"run":5,"appendChars":30000,"coldChars":100000,"samples":56,"firstPumpMedianUs":374,"firstPumpP95Us":554,"contentPumpMedianUs":2478,"contentPumpP95Us":3747,"coldFirstFrameUs":484370,"themePlatform":"android","hostOS":"macos","selectionController":true,"appAdapters":false}
```

## C33 static preview migration diagnostic

Code state: C32 parent `ae757f3f` plus the C33 file/Skill preview migration and
cross-paragraph display-math fix. This is one diagnostic batch on the same
Flutter 3.47.6 host, fixture generator, font and benchmark setup as C04, with
no other Flutter test process running during this batch. It is not the final
five-process streaming/cold-render comparison. Both values of the retained
`useBlockRendering` argument now use the same native block renderer; their
within-batch difference is warm-up/cache noise, not two rendering modes.

The static-preview (`blocks=true`) 100/250-section load medians changed from
235.26/658.66 ms in C04 to 105.14/230.31 ms here. Scroll medians changed from
1.68/2.12 ms to 1.06/1.14 ms. These measurements cover the existing synthetic
preview workload, not a physical device or a 100k-character cold render.

```sh
flutter test --no-pub test/perf/skill_preview_bench.dart --reporter expanded
```

```text
RESULT sections=100 blocks=false chars=23718 loadMedianMs=156.04 scrollMedianMs=1.52 scrollP90Ms=2.28
RESULT sections=100 blocks=true chars=23718 loadMedianMs=105.14 scrollMedianMs=1.06 scrollP90Ms=1.75
RESULT sections=250 blocks=false chars=59463 loadMedianMs=242.84 scrollMedianMs=1.21 scrollP90Ms=2.00
RESULT sections=250 blocks=true chars=59463 loadMedianMs=230.31 scrollMedianMs=1.14 scrollP90Ms=2.02
```
