# Native chart dependency (C14)

Kelivo pins `fl_chart: 1.3.0` for native line, area, numeric/category bar,
scatter and pie/donut rendering. It supplies chart axes, line/marker rendering,
pie layout and native pointer hit testing, without a WebView or model request.
Using it avoids a second complete chart engine. No feature flag is added.

The package is MIT licensed. The official archive SHA-256 is
`5ed69b8be550c6276c8f0bc25c09704fb061018ed1b1681867ad18fcf477e7b7`.
Its SDK minimums are Dart 3.6.2 and Flutter 3.27.4; C01's Flutter 3.47.6 /
Dart 3.13.5 satisfy both. Package resolution added only fl_chart; the existing
equatable 2.1.0 and vector_math 2.4.3 versions did not change. It introduces no
native plugin, platform registration, additional native SDK or network access.

Sources: [published package](https://pub.dev/packages/fl_chart/versions/1.3.0),
[pinned package manifest](https://github.com/imaNNeo/fl_chart/blob/bcbc9f025c531d4c9c28992260676ba29a72bd2d/pubspec.yaml),
[MIT license](https://github.com/imaNNeo/fl_chart/blob/bcbc9f025c531d4c9c28992260676ba29a72bd2d/LICENSE).

## Integration boundaries

`UiChartData` validates at runtime-batch boundaries, before widget build. It
preserves missing values and source row identity, enforces four Cartesian
series / 2,000 total slots and twelve pie items, and rejects mixed X types,
nonfinite values, unknown fields and invalid pie totals as node-local errors.
Finite affine axes preserve narrow large-number spacing without overflowing
opposite finite endpoints. Sampling failures remain null, with separate domain
gap shading. An empty input is an empty state rather than invented zeroes.

All colors come from GenUiTheme. Cartesian series always use distinct line
patterns and marker shapes. Legends retain their original series indices when
hidden; source X/time order stays left-to-right in RTL. Units, semantic summaries
and exact accessible tooltip text accompany the canvas. Export rendering has
no actions or transient selection. View visibility persists; hover and point
selection do not. C15 adds the shared paginated data alternative.

Three confirmed library behaviors require small local adaptations:

- BarChart spaces groups evenly. Numeric bars instead use the library's
  ScatterChart axis with one custom rectangular glyph per real data point;
  the same geometry draws and hit-tests each positive/negative/zero bar.
- Scatter hit testing includes `show: false` entries in 1.3.0. Hidden and
  missing spots are removed, with an explicit source-row/series mapping.
- Above/below cutoffs and BetweenBars allocate full-plot saveLayers for each
  null-delimited area segment. A small painter fills each straight contour to
  zero directly, without saveLayer; fl_chart still renders the lines, markers,
  axes and hits. Independent contours are painted separately so reversing X
  direction cannot cancel overlapping fills through path winding.

Production uses only public fl_chart APIs. Tests inspect pinned native renderer
boxes to send actual pointer gestures; they do not replace the chart with mocks.
No BackdropFilter, Opacity/AnimatedOpacity or RepaintBoundary was added to the
production message path. State feedback is immediate; existing node-arrival
motion remains responsible for short fades and reduced-motion behavior.

## Verification scope

The native standalone gallery and the real MessageListView fixture target both
include the five charts, domain gaps, empty data and node errors. The web-safe
`@Preview` graph contains canvas-only fixtures. The fixed function catalog does
not include `ln`, so the interactive domain example uses
`k * sqrt(x*x-a)` and retains nineteen undefined sample points at its defaults.

Behavior tests cover native point/zero-bar/body hits, keyboard selection,
scroll gesture coexistence, semantic legend actions, read-only/stream completion,
state restore/reset, dynamic kinds, units in exports and signed/null area fill.
Goldens cover light/dark, RTL, 1.3 text, wallpaper and desktop, reusing the real
Markdown backdrop harness. Explicit print-only `genui_chart_bench.dart` exercises
2,000 slots, alternating missing area segments, parameter updates and hover.
Debug widget timings are not device frame-time acceptance.

Native platform commands and actual outcomes are recorded in
[the implementation record](implementation.md). Linux acceptance was explicitly
deferred by the user; builds do not establish GUI or physical-device behavior.
