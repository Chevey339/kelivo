# Markdown UI allocation optimization

Date: 2026-10-20. Parent: `437e7c50`. The comparison baseline `cf2af98e`
is **before the style work**, after the markstream migration.

The fixed-fixture debug phase gate passes: cold, median and p95 build/layout/paint
are all no more than 3% above `cf2af98e`, for both the original plain tail and a
supplemental inline-code tail. macOS profile engine frame p95 is essentially
unchanged. **This is not an all-metric zero-regression result:** native profile
BUILD median/p95 remain above +3%, and the original short debug content-pump p95
also remains above the baseline. Both exceptions are reported below.

## Retained implementation

Only two production files change:

- `InlineCodeCapsule` uses canonical immutable corner values for the existing
  4 px and 6 px radii. Other radii keep their existing construction path.
- `MarkstreamTheme.fromColorScheme` keeps a supplied body style when all four
  defaults are already resolved, instead of copying that identical style.
  Incomplete styles still receive the original defaults.

There are no new render objects, wrappers, caches or dependencies. Token values,
value equality, `_values`, copyWith, parser/streaming logic, widget prefix reuse,
selection/copy, viewport culling and virtualization are unchanged. No paint or
layout algorithm changes. The temporary baseline-wrapper merging experiments
and identity-comparison experiment were rejected and are absent from this patch.

All 384 final golden captures are pixel-identical to the prior style commit:
48 fixtures × two widths × light/dark × two text scales, with zero changed pixels.
Local comparison: `test_goldens/out/styles-optimization-report/index.html`.

## Protocol and interpretation

Apple M4 Pro, macOS 26.5.2, Flutter 3.47.6 / Dart 3.13.5. Three versions run in
six fresh processes each, with a balanced rotating order: each version runs
first, second and third twice. Every completed sample in the final batches is
included; no individual timing outliers were removed. Earlier experiments use
separate logs and are not substituted for these final results.

The runner waits for detected competing Flutter builds/tests before starting a
round. Normal desktop/IDE background work remains present; this is not a quiet
laboratory host. Percentages close to the threshold should not be treated as
cross-device guarantees.

Tables use milliseconds and the median of six per-process statistics. They are
not pooled p95s. The raw output, source hashes and diagnostic sources are in
`markstream_ui_optimization.json`. The benchmark and original fixed fixtures are
unchanged. UI BUILD markers can include layout-time builders, so phase values
must not be added together.

## Fixed-fixture debug phases

Same 30k/100k fixtures, 720 × 900 at DPR 1, app adapters and selection enabled.
The phase diagnostic repeats the original 64-token window five times; the first
eight tokens of every cycle warm up, leaving 280 content samples per process.

| Metric | cf2af98e | 437e7c50 | Optimized | vs cf2af98e | vs 437e7c50 |
| --- | ---: | ---: | ---: | ---: | ---: |
| Cold build | 337.1555 | 339.4225 | 330.0800 | -2.10% | -2.75% |
| Cold layout | 344.3245 | 344.2970 | 338.3665 | -1.73% | -1.72% |
| Cold paint | 4.9155 | 3.8350 | 3.6645 | -25.45% | -4.45% |
| Content median build | 0.2270 | 0.2260 | 0.2310 | +1.76% | +2.21% |
| Content median layout | 0.3955 | 0.3940 | 0.4030 | +1.90% | +2.28% |
| Content median paint | 0.1130 | 0.1160 | 0.1135 | +0.44% | -2.16% |
| Content p95 build | 0.5420 | 0.5430 | 0.5070 | -6.46% | -6.63% |
| Content p95 layout | 0.9800 | 0.9035 | 0.8755 | -10.66% | -3.10% |
| Content p95 paint | 0.2195 | 0.2200 | 0.2095 | -4.56% | -4.77% |

## Supplemental inline-code tail

This adds 20 closed inline-code atoms to the active final paragraph. It exercises
capsule rebuilding that the original plain-text tail does not exercise. The
prefix ends immediately before `Fixed padding paragraph 64`; a new final
paragraph contains the 20 atoms and enough `x` characters to keep the document
at exactly 30,000 characters. The final 64 appended characters are still `x`.
The 100k cold document is unchanged. This scenario supplements the original
fixture; it does not replace it.

| Metric | cf2af98e | 437e7c50 | Optimized | vs cf2af98e | vs 437e7c50 |
| --- | ---: | ---: | ---: | ---: | ---: |
| Cold build | 339.2380 | 341.1325 | 333.2540 | -1.76% | -2.31% |
| Cold layout | 345.3305 | 346.4535 | 341.0520 | -1.24% | -1.56% |
| Cold paint | 4.8085 | 3.6890 | 3.7505 | -22.00% | +1.67% |
| Content median build | 0.7855 | 0.7705 | 0.7950 | +1.21% | +3.18% |
| Content median layout | 1.2725 | 1.2500 | 1.2745 | +0.16% | +1.96% |
| Content median paint | 0.2420 | 0.2185 | 0.2245 | -7.23% | +2.75% |
| Content p95 build | 1.6730 | 1.6810 | 1.6515 | -1.29% | -1.75% |
| Content p95 layout | 2.4605 | 2.5295 | 2.4935 | +1.34% | -1.42% |
| Content p95 paint | 0.5020 | 0.4385 | 0.4085 | -18.63% | -6.84% |

## Original short debug protocol, without phase collection

The original one-cycle benchmark is retained as a separate six-round batch,
with 56 samples per fresh process. Its content-pump p95 has not met +3%.
Exploratory longer debug runs showed substantial warm-up sensitivity, but that
alone does not establish the cause of this particular remaining gap.

| Metric | cf2af98e | 437e7c50 | Optimized | vs cf2af98e | vs 437e7c50 |
| --- | ---: | ---: | ---: | ---: | ---: |
| Scheduling median | 0.3385 | 0.3225 | 0.3385 | +0.00% | +4.96% |
| Scheduling p95 | 0.6395 | 0.6610 | 0.6685 | +4.53% | +1.13% |
| Content median | 1.9075 | 1.9275 | 1.9030 | -0.24% | -1.27% |
| Content p95 | 3.0245 | 3.2875 | 3.5370 | +16.94% | +7.59% |
| 100k cold pump | 508.1995 | 504.3100 | 501.8855 | -1.24% | -0.48% |

## macOS profile: native visible window

These are AOT profile applications, not debug test VMs. The three apps are built
first and then their existing binaries are launched in balanced order. The
native window is visible and focused. `setSurfaceSize` supplies a 720 × 900 logical
test surface using the real DPR 2 view; no fake physical view size is used.
The surface is fitted to the native window by the integration-test binding.

The harness checks that every content pump captured all three phases and that
the native surface actually rasterized frames. It uses `onlyPumps`, one 64-token
window and eight warm-up tokens. Engine FrameTiming covers scheduling, content
and scroll frames, discarding the first 24 frames. Each run retained 168 frames.
Wall-clock pump durations include real timer/vsync waits and are deliberately
not used as CPU-rendering measurements.

### Engine frame timings

| Metric | cf2af98e | 437e7c50 | Optimized | vs cf2af98e | vs 437e7c50 |
| --- | ---: | ---: | ---: | ---: | ---: |
| Engine UI build p95 | 2.3975 | 2.4625 | 2.4055 | +0.33% | -2.31% |
| GPU raster p95 | 1.6525 | 1.6575 | 1.6440 | -0.51% | -0.81% |
| Total frame p95 | 4.1765 | 4.2335 | 4.1745 | -0.05% | -1.39% |
| Vsync overhead p95 | 0.2205 | 0.2145 | 0.2205 | +0.00% | +2.80% |
| 100k cold pump | 109.3010 | 110.1690 | 109.6865 | +0.35% | -0.44% |

### Content phase diagnostics

The native BUILD subphase is still +5.45% at the median and +5.91% at p95 versus
`cf2af98e`. The preceding style commit shows a similar gap. The follow-up does
not eliminate it, even though total-frame p95 stays effectively unchanged.

| Metric | cf2af98e | 437e7c50 | Optimized | vs cf2af98e | vs 437e7c50 |
| --- | ---: | ---: | ---: | ---: | ---: |
| Cold build | 32.4555 | 32.6755 | 31.8920 | -1.74% | -2.40% |
| Cold layout | 74.6300 | 73.3720 | 74.3165 | -0.42% | +1.29% |
| Cold paint | 0.5150 | 0.5115 | 0.4945 | -3.98% | -3.32% |
| Content median build | 0.5690 | 0.5980 | 0.6000 | +5.45% | +0.33% |
| Content median layout | 1.1710 | 1.1815 | 1.1955 | +2.09% | +1.18% |
| Content median paint | 0.2160 | 0.2075 | 0.2015 | -6.71% | -2.89% |
| Content p95 build | 0.7110 | 0.7535 | 0.7530 | +5.91% | -0.07% |
| Content p95 layout | 1.5130 | 1.5300 | 1.5340 | +1.39% | +0.26% |
| Content p95 paint | 0.3090 | 0.2985 | 0.2955 | -4.37% | -1.01% |

These synthetic component measurements do not establish Android performance,
concurrent drawer/glass behavior, or sustained 120 FPS in the complete app.

## Reproduction

The standard phase command is unchanged:

```sh
flutter test --no-pub test/perf/markstream_render_bench.dart \
  --dart-define=MARKSTREAM_PROFILE_PHASES=true \
  --dart-define=MARKSTREAM_BENCH_CYCLES=5 --reporter expanded
```

For the supplemental fixture, write `reproduction.richProbeSource` from the JSON
to `.scratch/markdown_rich_tail_probe.dart` in each checkout and use that target
with the same flags. For profile, reconstruct the recorded source before its
embedded font, append the base64 encoding of the recorded font fixture, and
write it to `integration_test/.scratch/markdown_profile_probe.dart`. The exact
full-source hash is recorded. The font is embedded only in the temporary test
app, without changing pubspec or shipping assets.

```python
import base64, hashlib, json
from pathlib import Path
r = json.loads(Path('test/perf/baselines/markstream_ui_optimization.json').read_text())['reproduction']
font = Path(r['profileFontPath']).read_bytes()
source = r['profileProbeSourceBeforeEmbeddedFont'] + "\nconst _fontBytes = '" + base64.b64encode(font).decode() + "';\n"
assert hashlib.sha256(source.encode()).hexdigest() == r['profileProbeSha256']
target = Path('integration_test/.scratch/markdown_profile_probe.dart')
target.parent.mkdir(parents=True, exist_ok=True)
target.write_text(source)
```

Build with `flutter build macos --profile --no-pub --target=integration_test/.scratch/markdown_profile_probe.dart`.
Run each prebuilt app using `flutter drive --profile --no-pub -d macos`,
`--driver=test_driver/integration_test.dart`, the same target, and
`--use-application-binary=<absolute path>/build/macos/Build/Products/Profile/kelivo.app`.
Set `MARKSTREAM_RUN=1..6` for the round. Use the same harness in all checkouts;
bootstrap the original baseline with the recorded benchmark file from the style
commit. Temporary harnesses and build outputs are not production changes.

## Functional validation

- Final 384-image matrix: all equal; golden harness 389 tests passed.
- Focused capsule, theme, geometry and adapter tests passed.
- Flutter 3.44.9 / Dart 3.12.2: application full suite, **8,127 passed**;
  markstream full suite, **290 passed**.
- `dart analyze --fatal-infos lib test integration_test`,
  `dart analyze --fatal-infos test_goldens`, full `flutter analyze --no-pub`,
  and the separate package analyzer all reported no issues.
- Both packages resolved dependencies with `flutter pub get --offline` before
  the final checks. No dependency/lockfile or CI change is included.
- Changed Dart files are formatted. Source hashes match the measured version
  after the full suite; `git diff --check` passes.

Functional and visual validation passes. The requested fixed-fixture phase
comparison and native engine frame p95 comparison meet the +3% non-regression
bound. The two broader measurement exceptions above remain explicit; this is
not a claim that every metric or every platform is within 3%.
