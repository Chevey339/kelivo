#!/usr/bin/env bash
set -euo pipefail

repo_root="$(python3 -c 'import pathlib,sys; print(pathlib.Path(sys.argv[1]).resolve().parents[2])' "${BASH_SOURCE[0]}")"
legacy_sha=58d9badfb0912bb01739a71d2dc26ed7deded90b
flutter_bin="$(command -v "${GENUI_FLUTTER:-flutter}")"
new_commit="$(git -C "$repo_root" rev-parse HEAD)"
if [[ -n "$(git -C "$repo_root" status --porcelain)" ]]; then
  printf '%s\n' 'Run this manual check after committing the candidate source tree.' >&2
  exit 1
fi
git -C "$repo_root" cat-file -e "${legacy_sha}^{commit}"
log_dir="$repo_root/build/genui/legacy-restore/$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$log_dir"
"$flutter_bin" --version --machine > "$log_dir/flutter.json"
python3 - "$log_dir/flutter.json" <<'PY'
import json,sys
sdk=json.load(open(sys.argv[1]))
assert sdk['frameworkVersion']=='3.47.6', 'Use the Flutter SDK locked in C01'
assert sdk['frameworkRevision']=='5fc346839b5d0eef006ed8404392afb4dfae428d', 'Flutter revision differs from C01'
assert sdk['dartSdkVersion'].startswith('3.13.5'), 'Dart SDK differs from C01'
PY

task_temp="$(mktemp -d "${TMPDIR:-/tmp}/kelivo-legacy-restore.XXXXXX")"
trap 'rm -rf -- "$task_temp"' EXIT
legacy_dir="$task_temp/v3"
fixture="$task_temp/genui-v5.zip"
mkdir -p "$legacy_dir"
printf '%s\n' "Current source: $new_commit" "Frozen reader: $legacy_sha" "Logs: $log_dir"
(
  cd "$repo_root"
  "$flutter_bin" test --no-pub tool/legacy_restore/create_v5_fixture_test.dart \
    "--dart-define=GENUI_LEGACY_FIXTURE_OUT=$fixture" --reporter expanded
) > "$log_dir/create-fixture.log" 2>&1
test -s "$fixture"
git -C "$repo_root" archive "$legacy_sha" | tar -x -C "$legacy_dir"
cp "$repo_root/tool/legacy_restore/legacy_restore_v5_test.dart" "$legacy_dir/test/legacy_restore_v5_test.dart"
mkdir -p "$legacy_dir/test/fixtures"
cp "$fixture" "$legacy_dir/test/fixtures/genui-v5.zip"
printf '%s\n' 'Resolving dependencies in the frozen source archive.'
(
  cd "$legacy_dir"
  "$flutter_bin" pub get
) > "$log_dir/legacy-pub-get.log" 2>&1
printf '%s\n' 'Running the real frozen v3 overwrite and startup restore.'
(
  cd "$legacy_dir"
  "$flutter_bin" test test/legacy_restore_v5_test.dart \
    "--dart-define=GENUI_LEGACY_SOURCE_ROOT=$legacy_dir" --reporter expanded
) > "$log_dir/legacy-restore.log" 2>&1
python3 - "$log_dir" "$new_commit" "$legacy_sha" "$flutter_bin" <<'PY'
from pathlib import Path
import datetime,json,sys
logs=Path(sys.argv[1])
for name in ('create-fixture.log','legacy-restore.log'):
    assert 'All tests passed!' in (logs/name).read_text()[-2000:], f'{name} did not finish successfully'
report={'tested_commit':sys.argv[2], 'legacy_reader':sys.argv[3],
        'date':datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'command':'bash tool/legacy_restore/run.sh', 'flutter':sys.argv[4],
        'result':'passed', 'boundary':'Frozen v3 business source with freshly resolved dependencies; not a historical release binary.'}
(logs/'result.json').write_text(json.dumps(report,indent=2)+'\n')
PY
printf '%s\n' "Legacy full restore passed. Evidence: $log_dir/result.json"
