# Stream trace fixtures

Each directory has:

- `events.jsonl`: one framed `SseEvent` per line (`id` / `event` / `data` only).
  Recorded after SSE framing and before decoding. Never store Authorization
  headers or API keys.
- `expected.json`: semantic snapshot of decoder output. Image bytes are stored
  as MIME + byte count + SHA-256. Timestamps and bulky vendor metadata are
  omitted.

Offline replay lives in `test/features/api/stream_trace_replay_test.dart`.
Regenerate snapshots after an intentional decoder change:

```bash
UPDATE_STREAM_TRACES=true flutter test test/features/api/stream_trace_replay_test.dart
```

Record a live vendor stream (requires the env var named in `tool/traces.yaml`):

```bash
dart run tool/trace_recorder.dart --list
dart run tool/trace_recorder.dart --case thinking-tools-search --dry-run
dart run tool/trace_recorder.dart --case thinking-tools-search --force
```
