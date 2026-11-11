# IntelligentUI manual evaluation

This CLI is a development-only OpenAI-compatible text-completion client. It is
never imported by application code, CI, hooks or the default tests. Tests import
only the offline scorer and output-directory claim helper. The scorer and
runtime also run in plain Dart without Flutter or platform plugins.

The user's scope amendment fixes the model to `deepseek-v4.1-flash-1017`. The
tracked configuration contains six scenes with five variants each. Early runs
use `s1-1`, `s2-1` and `s5-1`; final acceptance uses all 30 and requires at least
29 first-round complete valid results. These bounded tasks specify stable IDs
for reproducible probes; this is not a claim about arbitrary user tasks.

Before a paid run, commit the evaluator, catalog/runtime and configuration.
Use the repository entrypoint and a Git-tracked configuration under this folder.
Git guards include the vendored Markstream parser and dependency manifests. The
configuration also freezes the Dart SDK and the pure evaluator's six hosted
package versions; these are checked against both the running package resolution
and the ignored application lockfile before running or summarizing.
Set `GENUI_EVAL_API_KEY` and `GENUI_EVAL_BASE_URL` in the process environment.
The URL is the full HTTPS endpoint ending in `/chat/completions`, without query
parameters or embedded credentials. No CLI key, `--dart-define`, application
account lookup or credential logging is supported. HTTP redirects are refused.

```sh
dart run tool/genui_eval.dart --config tool/genui_eval/config.json --output build/genui_eval/early-run --early
```

Each run requires a new empty output directory. An exclusive retained marker
claims it before any network request, so concurrent runs cannot overwrite each
other. The client makes one request per task, serially, and stops on transport
or provider failure. There are no automatic paid retries. Keep incomplete or
failed runs separate; do not splice the best outputs from different runs.

The deterministic scorer checks closed top-level native fences, parsing/types,
bounded data, actual input changes, numerical results and units, exact Ask
context, table/chart mappings, Form membership, and effective control visibility
and availability. Expected domain gaps remain null. Required-form submission,
focus/IME, rendered appearance, persistence and device performance still need
their separate application tests; CLI timings cannot establish Flutter display
latency. Diagnostics are bounded during collection, not after allocation.

Each result also lists semantic checks that must be inspected separately.
After reviewing the actual response, fill its `semanticReview`, identifying who
performed the review accurately. For example:

```json
{
  "reviewer": "coding-agent",
  "accepted": true,
  "notes": "Labels and units match the task; the explanation accurately describes local updates and an editable Ask draft."
}
```

A deterministic pass alone is insufficient. Do not label agent inspection as a
human inspection. Rejected semantics use `accepted: false` and explain the
specific mismatch. Preserve the original response and finish reason.

```sh
dart run tool/genui_eval.dart --config tool/genui_eval/config.json --output build/genui_eval/early-run --early --summarize
```

For the final run, omit `--early` from both commands. Summarization makes no
network calls; it rescores saved responses, verifies the original configuration
and evaluation tree against `testedCommit`, and requires all semantic reviews.
The formal report has only model ID, UTC date, actual tested commit, and score.
Below 29/30 fails final acceptance. After fixing shared prompt/catalog/scoring
semantics, rerun the full affected set manually rather than reuse an old score.

Real responses are initially saved under ignored `build/`. Review/sanitize them
before copying to `test/fixtures/genui/real/` with provenance and expectations.
The existing `synthetic/eval_outputs.json` is explicitly synthetic and must
never be represented as live-model evidence.
