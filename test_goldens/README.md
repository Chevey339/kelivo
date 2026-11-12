# Markdown migration visual baselines

Run from the repository root, on the same machine and Flutter SDK for both
captures. These tests live outside `test/` and are deliberately opt-in.

```sh
flutter test test_goldens --dart-define=MARKSTREAM_GOLDEN_SET=baseline
flutter test test_goldens --dart-define=MARKSTREAM_GOLDEN_SET=current
dart analyze --fatal-infos test_goldens
dart run test_goldens/tool/diff_report.dart \
  test_goldens/out/baseline test_goldens/out/current test_goldens/out/report
```

The matrix covers widths 720/390, light/dark themes and chat font scales 1/1.3.
Width 720 uses the macOS target platform; width 390 uses Android. Each fixture
is captured completely with viewport culling disabled, using real local fonts,
pixel ratio 1, locale zh_CN and deterministic citation indices. Fixtures with
`_open_` in their names run with streaming enabled. Baseline images describe
existing behavior, including existing rendering defects.

The default Latin font is macOS Arial; CJK uses Hiragino Sans GB; code uses the
vendored JetBrains Mono. Current captures also load Apple Color Emoji so decoded
entities have a real emoji face. Package fonts (including KaTeX and icons) are loaded
from Flutter's font manifest. On another machine pass `MARKSTREAM_LATIN_FONT` and
`MARKSTREAM_CJK_FONT` and `MARKSTREAM_EMOJI_FONT` with `--dart-define` to specify local font files. Missing
fonts fail explicitly. The capture manifest records the font file paths and
sizes; use the same files for comparisons. System fonts are never copied into
the repository.

PNG files and manifests are written below ignored `test_goldens/out/<set>/`.
The default set is `current`, so ordinary reruns preserve the baseline.
`MARKSTREAM_GOLDEN_FILTER` optionally selects fixture names by substring.
The harness checks successful rendering, finite geometry and nonempty PNGs;
visual changes are assessed through the comparison report, not by automatically
accepting a new reference image. PNG encoding runs in `tester.runAsync` because
awaiting `toByteData` in the fake async test zone can hang.

All 48 fixtures in `fixtures/synthetic/` are synthetic. The separate `real/`
directory is reserved for user-supplied, reviewed conversation exports.

The report contains JSON measurements and a local HTML page with the baseline,
current capture and red difference mask side by side. Pixel ratios compare
exact RGBA values over the union of both image footprints, so size changes count
as differences. The HTML can filter unchanged captures. Changes require visual
review and do not fail the command; missing images do fail with exit code 2.
When a capture manifest exists, it defines the current run's image set so stale
PNG files from a previous run cannot silently stand in for missing captures.
