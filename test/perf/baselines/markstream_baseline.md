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

## C36 shared structure and Unicode-line diagnostic

The non-rendering consumers now use the block parser for fence/container
boundaries. The LLM profile also recognizes LS/PS separators. Incremental
line-start lookup stops at the nearest separator instead of searching the
entire prefix separately for each possible delimiter.

The existing pure-Dart parser harness ran five rounds in one process on the
same SDK/host. The table reports the median of those rounds. These are parser
timings, not application frames or the final five-process C41 acceptance run.
An earlier C36 implementation used separate delimiter searches; that run also
coincided with visible Spotlight indexing. Do not attribute all differences
between that exploratory run and this final state to the code change.

| Metric | C33 median / p95 (ms) | C36 median / p95 (ms) |
| --- | ---: | ---: |
| Full parse, 30k characters | 2.049 / 2.341 | 2.173 / 2.447 |
| Full parse, 100k characters | 6.431 / 6.795 | 6.936 / 7.288 |
| Incremental append | 0.182 / 0.194 | 0.029 / 0.036 |

Command: `cd dependencies/markstream && dart run test/perf/parse_bench.dart`.


## C38 renderer regression diagnostic

After the native test migration and fixes for nested details, fold/table state,
image dimensions and table capture, one isolated application benchmark batch
reported the following values on the same SDK, host and fixed fonts as above.
No other Flutter test was running during this measurement. This is a diagnostic
sample, not the final five-process C41 performance acceptance run.

```text
MARKSTREAM_RENDER {"run":1,"appAdapters":true,"appendChars":30000,"coldChars":100000,"samples":56,"firstPumpMedianUs":385,"firstPumpP95Us":701,"contentPumpMedianUs":2055,"contentPumpP95Us":3145,"coldFirstFrameUs":503841}
```

The real content frame remains near the C04 median/p95 (2.003/3.147 ms), but
both the 2 ms content target and 100 ms cold target remain open. The parser
harness, five rounds in one process, reports median-of-rounds median/p95:
30k full parse 2.209/2.710 ms, 100k 6.942/7.726 ms, incremental append
0.029/0.035 ms. These parse timings do not establish rendering performance.


## C39 chat migration: native macOS diagnostic

The assistant body and both reasoning views now use markstream. The existing
long-stream harness completed all 12 shapes/sizes for direct rendering and
all 12 for reasoning. Its combined three-pump timings are diagnostic, not the
fixed 30k first-content-frame acceptance metric. One isolated fixed-fixture
application batch reported:

```text
MARKSTREAM_RENDER {"run":1,"appAdapters":true,"appendChars":30000,"coldChars":100000,"samples":56,"firstPumpMedianUs":323,"firstPumpP95Us":475,"contentPumpMedianUs":1928,"contentPumpP95Us":3196,"coldFirstFrameUs":477168}
```

The native macOS 26.5.2 arm64 profile integration run used Flutter 3.47.6,
in-memory business databases and mock preferences. It exercised MessageListView
with semantics enabled, default backgrounds and 100 streaming updates per case.
The device reported a 120 Hz display. `liveFrames=false` means the integration
binding scheduled frames explicitly; these are native FrameTiming observations,
not physical Android results or the fixed-fixture five-process C41 comparison.

```sh
flutter drive --profile -d macos --no-pub \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/long_streaming_performance_test.dart \
  --dart-define=STREAM_MAX_BLOCKS=300 --dart-define=STREAM_TIMELINE=true
```

| Case | Characters | Frames | Build p50 / p95 (ms) | Raster p95 (ms) | Frames over 16.7 ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| reply-20 | 2478 | 301 | 0.630 / 2.833 | 2.397 | 0 |
| reply-200 | 18238 | 301 | 0.988 / 2.644 | 1.929 | 0 |
| reply-300 | 27038 | 301 | 0.640 / 2.726 | 1.918 | 0 |
| reasoning-20 | 2478 | 301 | 0.513 / 3.902 | 2.088 | 0 |
| reasoning-200 | 18238 | 301 | 0.553 / 3.617 | 1.768 | 0 |
| reasoning-300 | 27038 | 301 | 0.533 / 3.862 | 1.949 | 0 |

All six cases passed their nonempty-frame and exception checks, and the driver
returned success with all six records in `build/integration_response_data.json`.
The binding emitted a missing native integration-test-plugin warning on macOS;
the Dart driver response still contained the complete reported measurements.
The largest case contains 27,038 characters, so it does not establish the exact
30k target. Desktop content p95 and 100k cold-render targets remain open for C41.


## M3 application checkpoint — C41

Measurement tree: `1dcb110a` plus the C41 scaling/empty-bracket repairs. Same
host, Flutter 3.47.6, fixed 30k/100k corpus, fonts, viewport and five fresh
process protocol as C04. The app's actual Markdown wrapper and adapters are
installed. The host uses SelectionArea, without a MarkstreamSelectionController
(the message-menu controller is introduced by C44). No other Flutter tests or
native QA app were running during this batch.

| Metric | C04 median of rounds (ms) | C41 median of rounds (ms) | C41 range (ms) |
| --- | ---: | ---: | ---: |
| Scheduling frame median | 1.270 | 0.365 | 0.327–0.453 |
| Scheduling frame p95 | 2.413 | 0.695 | 0.576–0.785 |
| Actual content frame median | 2.003 | 2.064 | 1.896–2.220 |
| Actual content frame p95 | 3.147 | 3.355 | 3.281–3.604 |
| 100k cold first frame | 814.392 | 520.010 | 498.538–552.710 |

The cheap scheduling frame is below 2ms, but it does not paint the new token.
The actual content frame median/p95 and cold frame **do not meet** the desktop
acceptance targets. This batch's content median/p95 also exceed C04 slightly;
no noise tolerance was agreed, so no non-regression claim is made. Cold render
is materially faster than C04 but remains well above 100ms. Physical Android
profile timing is deferred; its 4ms target has no measurement.

A preliminary five-process batch before these visual repairs measured content
median/p95 1.714/2.849ms and cold 462.551ms. It is not the final code state and
must not replace the final results above. A diagnostic CPU profile (280 samples)
at that earlier state still found native widget mounting/rebuild work dominant
(149–157 inclusive samples; not additive). The existing viewport culling avoids
offscreen paint/semantics; it does not avoid all initial layout and mounting.
This report leaves the unmet performance criteria explicit.

Raw final output:

```text
MARKSTREAM_RENDER {"run":1,"renderer":"markstream","appAdapters":true,"appendChars":30000,"coldChars":100000,"samples":56,"firstPumpMedianUs":327,"firstPumpP95Us":785,"contentPumpMedianUs":1896,"contentPumpP95Us":3604,"coldFirstFrameUs":498538}
MARKSTREAM_RENDER {"run":2,"renderer":"markstream","appAdapters":true,"appendChars":30000,"coldChars":100000,"samples":56,"firstPumpMedianUs":348,"firstPumpP95Us":695,"contentPumpMedianUs":2040,"contentPumpP95Us":3281,"coldFirstFrameUs":504894}
MARKSTREAM_RENDER {"run":3,"renderer":"markstream","appAdapters":true,"appendChars":30000,"coldChars":100000,"samples":56,"firstPumpMedianUs":365,"firstPumpP95Us":576,"contentPumpMedianUs":2064,"contentPumpP95Us":3355,"coldFirstFrameUs":520010}
MARKSTREAM_RENDER {"run":4,"renderer":"markstream","appAdapters":true,"appendChars":30000,"coldChars":100000,"samples":56,"firstPumpMedianUs":367,"firstPumpP95Us":670,"contentPumpMedianUs":2084,"contentPumpP95Us":3327,"coldFirstFrameUs":526017}
MARKSTREAM_RENDER {"run":5,"renderer":"markstream","appAdapters":true,"appendChars":30000,"coldChars":100000,"samples":56,"firstPumpMedianUs":453,"firstPumpP95Us":750,"contentPumpMedianUs":2220,"contentPumpP95Us":3421,"coldFirstFrameUs":552710}
```

The complete visual/interaction review is in `markstream_visual_review.md`.


## C42 directive-card diagnostic

One app fixed-fixture batch on the same host/SDK after C41, before the C42 full
test run: scheduling median/p95 0.433/0.941ms, actual content 2.384/3.560ms,
cold 534.131ms. This is a diagnostic, not a five-round acceptance result; the
C41 unmet targets remain open. Directive selection, scaling and live closure
are checked by widget assertions.

```text
MARKSTREAM_RENDER {"run":1,"renderer":"markstream","appAdapters":true,"appendChars":30000,"coldChars":100000,"samples":56,"firstPumpMedianUs":433,"firstPumpP95Us":941,"contentPumpMedianUs":2384,"contentPumpP95Us":3560,"coldFirstFrameUs":534131}
```

## C43 native HTML subset diagnostic

One fixed-fixture diagnostic after the sub/sup baseline repair, before the
final C43 full suite, with the same host, SDK and app adapters: scheduling
median/p95 0.493/1.028ms, actual content 2.482/4.128ms, cold 584.193ms. This is
not a five-round acceptance measurement; C41 performance targets remain open.

```text
MARKSTREAM_RENDER {"run":1,"renderer":"markstream","appAdapters":true,"appendChars":30000,"coldChars":100000,"samples":56,"firstPumpMedianUs":493,"firstPumpP95Us":1028,"contentPumpMedianUs":2482,"contentPumpP95Us":4128,"coldFirstFrameUs":584193}
```

## C44 message-selection controller diagnostic

The fixed-fixture host now uses the application's `AppSelectionArea`, including
its Markdown selection controller, matching the message-menu configuration.
The previous C41–C43 diagnostic host used a raw `SelectionArea`. This difference
is recorded in each new result as `selectionController: true`.

One fresh process before the C44 full suite: scheduling median/p95
0.252/0.548ms, actual content 1.589/2.234ms, cold 478.231ms. This remains a
single diagnostic, not the final five-round acceptance result. Cold render and
actual-content p95 exceed the plan's limits in this sample.

```text
MARKSTREAM_RENDER {"run":1,"renderer":"markstream","appAdapters":true,"selectionController":true,"appendChars":30000,"coldChars":100000,"samples":56,"firstPumpMedianUs":252,"firstPumpP95Us":548,"contentPumpMedianUs":1589,"contentPumpP95Us":2234,"coldFirstFrameUs":478231}
```

## C45 source-highlight diagnostic

One fresh process with app adapters and the C44 message-selection controller,
with no active highlight ranges: scheduling median/p95 0.325/0.566ms, actual
content 2.101/3.190ms, cold 497.743ms. Empty ranges bypass span splitting and
projection allocation. This is a diagnostic; final acceptance still requires
five independent rounds and the unmet limits are not waived.

```text
MARKSTREAM_RENDER {"run":1,"renderer":"markstream","appAdapters":true,"selectionController":true,"appendChars":30000,"coldChars":100000,"samples":56,"firstPumpMedianUs":325,"firstPumpP95Us":566,"contentPumpMedianUs":2101,"contentPumpP95Us":3190,"coldFirstFrameUs":497743}
```

## C46 final application configuration

Measured after rich-copy integration and the ordered-list serialization repair,
on the same M4 Pro host, Flutter 3.47.6 and test-VM mode. Five fresh processes
each start the 100k document before any Markdown rendering in that isolate;
app adapters and the message selection controller are enabled. No other Flutter
test/build ran concurrently. The 30k append fixture and sample protocol are
unchanged. These final-state rounds supersede the preceding diagnostic batch.

| Round | Scheduling median / p95 (ms) | Actual content median / p95 (ms) | 100k cold (ms) |
| --- | --- | --- | --- |
| 1 | 0.463 / 0.812 | 2.334 / 3.741 | 570.870 |
| 2 | 0.380 / 0.816 | 2.164 / 2.991 | 547.442 |
| 3 | 0.361 / 0.481 | 1.971 / 3.430 | 527.100 |
| 4 | 0.386 / 0.862 | 2.361 / 3.599 | 516.395 |
| 5 | 0.513 / 0.969 | 2.872 / 4.726 | 538.990 |
| Median of rounds | 0.386 / 0.816 | 2.334 / 3.599 | 538.990 |

The scheduling frame does not yet paint the appended token because the 50ms
coalescing timer is pending. It must not be substituted for the actual content
frame. C04 recorded actual 2.003/3.147ms and 814.392ms cold. In these final
rounds the actual median and p95 are higher than C04 and cold is lower. No
noise tolerance was agreed, so this is not proof of a non-regression. Both the
actual-content <=2ms goal and the <=100ms cold goal remain unmet. Implementation
completion does not waive those performance acceptance items. Android physical
device performance and real-chat corpus validation are deferred by the user;
these desktop results do not establish either.

```text
MARKSTREAM_RENDER {"run":1,"renderer":"markstream","appAdapters":true,"selectionController":true,"appendChars":30000,"coldChars":100000,"samples":56,"firstPumpMedianUs":463,"firstPumpP95Us":812,"contentPumpMedianUs":2334,"contentPumpP95Us":3741,"coldFirstFrameUs":570870}
MARKSTREAM_RENDER {"run":2,"renderer":"markstream","appAdapters":true,"selectionController":true,"appendChars":30000,"coldChars":100000,"samples":56,"firstPumpMedianUs":380,"firstPumpP95Us":816,"contentPumpMedianUs":2164,"contentPumpP95Us":2991,"coldFirstFrameUs":547442}
MARKSTREAM_RENDER {"run":3,"renderer":"markstream","appAdapters":true,"selectionController":true,"appendChars":30000,"coldChars":100000,"samples":56,"firstPumpMedianUs":361,"firstPumpP95Us":481,"contentPumpMedianUs":1971,"contentPumpP95Us":3430,"coldFirstFrameUs":527100}
MARKSTREAM_RENDER {"run":4,"renderer":"markstream","appAdapters":true,"selectionController":true,"appendChars":30000,"coldChars":100000,"samples":56,"firstPumpMedianUs":386,"firstPumpP95Us":862,"contentPumpMedianUs":2361,"contentPumpP95Us":3599,"coldFirstFrameUs":516395}
MARKSTREAM_RENDER {"run":5,"renderer":"markstream","appAdapters":true,"selectionController":true,"appendChars":30000,"coldChars":100000,"samples":56,"firstPumpMedianUs":513,"firstPumpP95Us":969,"contentPumpMedianUs":2872,"contentPumpP95Us":4726,"coldFirstFrameUs":538990}
```
