# Markdown backdrop review corrections

Date: 2026-10-22. Independent review scope: `ec0a355e` and `28f4e4b4`.
This report supplements, rather than replaces, the historical measurements in
[`markstream_backdrop_tokens.md`](markstream_backdrop_tokens.md).

## Correctness findings and fixes

Five concrete rendering paths required correction:

1. Plain opaque blocks inherited custom bubble foregrounds without changing
   their backgrounds. A light app with a black bubble and white text produced
   white code on a near-white block (contrast 1.02); the inverted dark case
   was 1.23. Plain block ink now stays paired with the global scheme; paragraph
   text keeps its inherited color. With wallpaper, explicit bubble RGB is
   carried through the existing inherited surface context and paired with a
   local surface/brightness, so the syntax theme matches the actual block.
   RGB remains opaque; table PNG capture does not inherit bubble alpha.
2. Default user tints (.08 light / .15 dark) were classified as frosted .66
   surfaces. The resulting block was too transparent: base-ink contrast was
   3.10 / 2.36 and comments 1.22 / 1.00 on the extreme underlay model. Tints
   and bubble opacity below .66 now use wallpaper coverage. Semi-transparent
   solid bubbles with opacity at least .66 use frosted coverage; fully opaque
   solid bubbles retain their ink tint. Explicit custom translucent backgrounds
   use wallpaper coverage to protect the local syntax palette.
3. Default frosted blocks still selected plain comment colors (3.75 / 3.82).
   They now use the existing stronger comment/quote/meta constants and ink3.
4. HTML/XML extension dispatch and PlantUML's code callback retained the plain
   highlighter. They now use the same canonical theme-dependent factory. The
   pre-existing plain-text fallback for unsupported language aliases is kept.
5. PlantUML directly renders remote SVG, which can be transparent. In an
   inverted custom bubble, a black graphic landed on RGB(13,13,13), about 1.08
   contrast. Only the custom image tab now uses its existing ColoredBox to
   retain the original global canvas and matching loading/error ink. Code
   retains local colors. Mermaid and SVG PNG paths already paint an opaque
   canvas; they were checked and left alone.

These repairs change color/context selection, not parsing, streaming,
selection, caching or virtualization. No new render objects, blur, masking,
compositing layers, dependencies or release assets are added. Brightness
estimation and the local ColorScheme copy run only for explicit bubble colors.

## Focused verification

The user explicitly requested **no full test suite** for this review. Results:

- App analysis: `dart analyze --fatal-infos lib test integration_test test_goldens`,
  including the final PlantUML change: no issues.
- Related app widget, adapter, streaming/static-block and golden tests: 239 pass.
- Separate markstream analysis: no issues; theme/backdrop/rich-block/view tests:
  42 pass. An initial command named a nonexistent `view_test.dart`; the corrected
  `markstream_view_test.dart` invocation is recorded separately in JSON.
- Final PlantUML + surface contrast + wallpaper goldens: 19 pass, including
  four new PlantUML tests after the isolated image-tab fix.
- All 384 existing plain captures are pixel-identical to `28f4e4b4` output,
  with no dimension changes. The local comparison is
  `test_goldens/out/backdrop-review-report/index.html`. This capture preceded
  the custom-only PlantUML follow-up; plain mode bypasses that follow-up.
- Default light/dark user tints, frosted/solid bubbles, opacity .2/.5/.8/1,
  masks 0/1/2 and black/white/gray underlays pass the specified base-ink >=7,
  comment/table >=4.5 and ink3 >=3 checks. Existing all-mask wallpaper checks
  remain. Inverted custom black/white bubbles test syntax selection, base and
  selected keyword contrast, opaque table PNG pixels and plain message export.
- PlantUML tests use the actual `SvgPicture.network` path with controlled SVG
  HTTP responses and inspect pixels, then switch to the code tab. Loading and
  the registered error widget's colors are also checked. This is component
  evidence, not a successful live PlantUML-service response or device test.

The earlier 8,265 app / 296 package full-suite totals belong to the pre-review
commits. They are not presented as full-suite evidence for these new repairs.

## Performance protocol and result boundary

Apple M4 Pro, Flutter 3.47.6 / Dart 3.13.5. The unchanged fixed benchmark uses
five fresh processes per revision/context, five cycles and 280 content samples
per process. Both plain and wallpaper are measured. Full tests were not running
alongside either batch. All completed samples are retained; no outlier deletion
or pooling across batches is used. These remain debug UI-pipeline timings, not
GPU/raster or physical-device frame rates.

The first follow-up batch compares a8364707/current in 20 processes. Some cold
paint and phase-p95 values exceed +3%, despite stable/improving content-pump
medians. A second batch adds the actual reviewed revision `28f4e4b4`, using 30
processes and five interleaved rounds. Baseline/current order alternates each
round, with the reviewed version placed at different positions. It helps
separate a new repair from changes already present in the reviewed commits.
It does not prove that every remaining difference is measurement noise.

**The latest detailed phase gate is not an all-metric +3% pass.** In the
three-version batch, overall content-pump median/p95 versus a8364707 stay
within +3% (plain +1.15%/+0.99%, wallpaper -1.63%/+1.53%), but some build/layout
medians or p95s exceed +3%. Different metrics exceed the threshold in the two
new batches. The historical passing phase batch must not be substituted for
these results. The original user's acceptance of supplemental measurement
limits is retained as history, not relabelled as a fresh phase-gate pass.

Both batches were collected before the final isolated PlantUML image-tab
correction. The fixed fixtures do not exercise PlantUML. JSON records the exact
measured hashes and final hashes separately; the only later production change
is `lib/shared/widgets/plantuml_block.dart`. This provides no new performance
claim for that custom image-preview path.

## Three-version measurements

Microseconds, median of five per-process statistics. P95s are not pooled.
BUILD can include layout-time work; phases must not be added together.

| Context | Metric | a8364707 | 28f4e4b4 | Repaired | vs a836 | vs reviewed |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| plain | firstPumpMedianUs | 233 | 223 | 228 | -2.15% | +2.24% |
| plain | firstPumpP95Us | 425 | 463 | 457 | +7.53% | -1.30% |
| plain | contentPumpMedianUs | 1128 | 1121 | 1141 | +1.15% | +1.78% |
| plain | contentPumpP95Us | 2230 | 2397 | 2252 | +0.99% | -6.05% |
| plain | coldFirstFrameUs | 508564 | 483209 | 484483 | -4.74% | +0.26% |
| plain | coldPhaseUs.build | 332729 | 323740 | 329676 | -0.92% | +1.83% |
| plain | coldPhaseUs.layout | 345764 | 327676 | 324936 | -6.02% | -0.84% |
| plain | coldPhaseUs.paint | 3853 | 3568 | 3391 | -11.99% | -4.96% |
| plain | contentPhaseMedianUs.build | 218 | 216 | 225 | +3.21% | +4.17% |
| plain | contentPhaseMedianUs.layout | 378 | 376 | 386 | +2.12% | +2.66% |
| plain | contentPhaseMedianUs.paint | 113 | 103 | 105 | -7.08% | +1.94% |
| plain | contentPhaseP95Us.build | 458 | 476 | 501 | +9.39% | +5.25% |
| plain | contentPhaseP95Us.layout | 777 | 766 | 852 | +9.65% | +11.23% |
| plain | contentPhaseP95Us.paint | 215 | 207 | 202 | -6.05% | -2.42% |
| wallpaper | firstPumpMedianUs | 414 | 426 | 411 | -0.72% | -3.52% |
| wallpaper | firstPumpP95Us | 924 | 844 | 875 | -5.30% | +3.67% |
| wallpaper | contentPumpMedianUs | 1106 | 1092 | 1088 | -1.63% | -0.37% |
| wallpaper | contentPumpP95Us | 2486 | 2404 | 2524 | +1.53% | +4.99% |
| wallpaper | coldFirstFrameUs | 474368 | 484021 | 471931 | -0.51% | -2.50% |
| wallpaper | coldPhaseUs.build | 315403 | 324014 | 314230 | -0.37% | -3.02% |
| wallpaper | coldPhaseUs.layout | 420560 | 429775 | 420435 | -0.03% | -2.17% |
| wallpaper | coldPhaseUs.paint | 2219 | 2085 | 2084 | -6.08% | -0.05% |
| wallpaper | contentPhaseMedianUs.build | 232 | 221 | 221 | -4.74% | +0.00% |
| wallpaper | contentPhaseMedianUs.layout | 484 | 473 | 483 | -0.21% | +2.11% |
| wallpaper | contentPhaseMedianUs.paint | 100 | 99 | 97 | -3.00% | -2.02% |
| wallpaper | contentPhaseP95Us.build | 515 | 502 | 526 | +2.14% | +4.78% |
| wallpaper | contentPhaseP95Us.layout | 1063 | 1063 | 1104 | +3.86% | +3.86% |
| wallpaper | contentPhaseP95Us.paint | 205 | 191 | 211 | +2.93% | +10.47% |

## Raw evidence and reproduction

[`markstream_backdrop_review.json`](markstream_backdrop_review.json) contains
both raw batches, every per-round value, commands, hashes, validation results
and runner sources. The preceding report retains the earlier 220 processes,
including the A/A control and all scrolling/long-streaming exceptions. Those
supplemental benchmarks were not rerun in this review; no new passing claim
is made for them.

Prepare `.scratch/backdrop-base` from `git archive a8364707` and
`.scratch/backdrop-reviewed-28f4e4b4` from `git archive 28f4e4b4`. Copy the same
lockfile, three benchmark files and `test/support/markdown_backdrop_host.dart`
to both, then resolve root dependencies offline with the recorded SDK. Restore
the runner sources from JSON under `.scratch/` and run
`python3 -u .scratch/run_backdrop_review_triple.py`. It creates a new output
directory and refuses to replace an existing batch. The two-revision runner
takes a distinct output label to keep its retained measurements separate.
