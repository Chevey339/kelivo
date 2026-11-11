# Manual frozen v3 restore check

Run from a clean, committed implementation tree with the C01 SDK:

```sh
GENUI_FLUTTER=/Users/psyche/development/flutter/bin/flutter bash tool/legacy_restore/run.sh
```

This is a development acceptance check, run after C13 and again for C26. It is
outside the default tests, CI and commit gate. It makes no model API calls and
does not use the installed application's data.

The script creates a new synthetic v5 archive through the current real backup
export path, with ordinary messages, assistant revisions, non-default native UI
inputs and views, and semantic search text. It archives the full frozen v3
source at `58d9badfb0912bb01739a71d2dc26ed7deded90b` into its own temporary
directory. Only the standalone test and archive fixture are added. Dependencies
are resolved in that old directory, without copying current package resolution,
dependency overrides or production source.

The old test verifies its source/package identity and runs real overwrite
preparation, service/connection shutdown, startup cutover and strict database
reopening. It checks message bodies, selected revisions, removal of GenUI
tables/FTS/shadow tables/triggers, foreign keys, old CRUD and an unchanged source
archive. Preparation alone does not establish successful restoration.

Logs and the successful result record remain in
`build/genui/legacy-restore/<UTC timestamp>/`; the script removes only its own
temporary directory on exit. A nonzero exit or missing final success is failure,
not a skipped acceptance. The record identifies the actual current commit, old
reader, date, command and SDK. This proves frozen business-source compatibility
with newly resolved dependencies, not reproduction of a historical binary.
