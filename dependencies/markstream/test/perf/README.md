# Parser benchmark

Run from `dependencies/markstream` in the Kelivo checkout:

```sh
dart run test/perf/parse_bench.dart
```

This pure Dart benchmark uses the exact C03 fixtures from
`test/fixtures/markdown/markstream_documents.dart` at the repository root.
It imports the literals directly, so there is no separate generated corpus to
drift from the Flutter render benchmarks. The fixture test at the repository
root validates their size and structure.

Each invocation performs five rounds in the same Dart process. Each full parse
measurement follows 12 warmups and records 31 samples. Incremental measurements
start with the 30,000-character document, append 150 six-character tokens, and
record the last 120 updates after 30 warmups. Every round creates a fresh
incremental document. Output includes original samples, median and nearest-rank
p95 in microseconds, runtime metadata and fixture revision.

`full_parse` measures a complete parse after runtime warmup. It does not mean a
cold Flutter frame. `incremental_append` measures only `IncrementalDocument`
updates. Neither measurement includes build, layout, paint or raster work, and
neither establishes the plan's end-to-end frame targets. Use the root render
benchmarks and later `streaming_append_bench.dart` for those measurements.

Timings are diagnostics, not assertions. The default `flutter test` file glob
skips this benchmark. Run repeated processes on an awake, otherwise quiet
machine for comparisons, and retain all `MARKSTREAM_PARSE` JSON output.
