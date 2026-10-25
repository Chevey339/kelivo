# Fixed Markdown rendering measurements

The checked-in fixtures contain exactly 30,000 and 100,000 ASCII/UTF-16 code
units, each with five fenced code blocks and two tables. A unit test guards
their lengths, structural counts and SHA-256 digests. Both renderers must use
these same fixtures.

Run from the repository root, with the same Flutter version, hardware and build
mode before and after migration. Use five fresh test processes so each cold
measurement starts before that isolate has rendered any Markdown:

```sh
for markstream_run in 1 2 3 4 5; do
  MARKSTREAM_RUN="$markstream_run" flutter test --no-pub \
    test/perf/markstream_render_bench.dart --reporter expanded
done
```

Each `MARKSTREAM_RENDER` JSON line records:

- `coldFirstFrameUs`: the first `pumpWidget` of the 100k fixture, including
  parse, build, layout and paint. Fonts/settings and an empty application host
  are initialized beforehand, without invoking any Markdown code. This isolates
  the document's first render from application startup.
  Viewport culling is enabled; the viewport is 720 by 900 at pixel ratio 1.
- `firstPumpMedianUs` / `firstPumpP95Us`: the first `pump()` after each
  one-character token appended at the tail of the 30k fixture. The first eight
  of 64 samples warm up; the remaining 56 form the distribution.
- `contentPumpMedianUs` / `contentPumpP95Us`: the subsequent pump after advancing
  the fake clock 50ms. The current renderer schedules a 50ms timer inside
  `didUpdateWidget`, so its first pump does not include parsing or painting the
  new token. This second metric exposes that deferred render work.

The synthetic 50ms clock advance is not included as wall-clock waiting. Scrolling
to keep the tail visible is measured outside both append samples. These are
test-VM UI-pipeline observations, excluding raster time and physical-device
scheduling; they are not Android frame timings. Benchmarks have no timing
assertions and are excluded from the default `_test.dart` glob.

Optional phase diagnostics use Flutter's existing timeline markers. Run the
same benchmark file and SDK against both revisions:

```sh
flutter test --no-pub test/perf/markstream_render_bench.dart \
  --dart-define=MARKSTREAM_PROFILE_PHASES=true \
  --dart-define=MARKSTREAM_BENCH_CYCLES=5 --reporter expanded
```

This adds cold-frame and content-frame build/layout/paint measurements. Root
layout and paint markers include descendant pipeline owners; child markers are
not added again. BUILD may include layout-time builders, so these phases are
not additive. Collection adds instrumentation overhead and excludes raster time.
Compare instrumented runs only with other instrumented runs.

`MARKSTREAM_BENCH_CYCLES` defaults to 1, preserving the original 56-sample
protocol. A larger value repeats the same 64-character append window, rewinding
outside the timers and discarding the first eight samples of every cycle. Five
cycles produce 280 content-frame samples per fresh process; the cold document
still renders only once. Phase collection defaults to off and runs only in this
diagnostic test, never in the application renderer.

Record all five output lines and the median of each round's metric in
`baselines/markstream_baseline.md`. Android profile results require a physical
device, independently collected `FrameTiming.buildDuration`, and the recorded
device model; simulator results cannot satisfy that part of the plan.
