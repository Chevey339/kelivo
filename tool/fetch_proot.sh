#!/usr/bin/env bash
# Restore the pinned Termux PRoot runtime from the checked-in archive.
# Usage: ./tool/fetch_proot.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CHECKSUMS_FILE="$SCRIPT_DIR/proot_checksums.txt"
ARCHIVE="$REPO_ROOT/dependencies/termux/proot-5.1.107.92.tar.xz"
JNI_LIBS="$REPO_ROOT/android/app/src/main/jniLibs"

if [[ ! -f "$CHECKSUMS_FILE" ]]; then
  echo "error: checksum file missing: $CHECKSUMS_FILE" >&2
  exit 1
fi

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

TMPDIR_FETCH="$(mktemp -d "${TMPDIR:-/tmp}/kelivo-proot.XXXXXX")"
trap 'rm -rf "$TMPDIR_FETCH"' EXIT

echo "Extracting pinned Termux PRoot runtime from $ARCHIVE"
tar -xJf "$ARCHIVE" -C "$TMPDIR_FETCH"

# Verify every library before replacing any existing local runtime files.
while read -r hash path; do
  [[ -z "${hash:-}" || "$hash" == \#* ]] && continue
  relative_path="${path#android/app/src/main/jniLibs/}"
  actual="$(sha256_of "$TMPDIR_FETCH/$relative_path")"
  if [[ "$actual" != "$hash" ]]; then
    echo "error: checksum mismatch for $path" >&2
    echo "  expected: $hash" >&2
    echo "  actual:   $actual" >&2
    exit 1
  fi
done < "$CHECKSUMS_FILE"

while read -r hash path; do
  [[ -z "${hash:-}" || "$hash" == \#* ]] && continue
  relative_path="${path#android/app/src/main/jniLibs/}"
  mkdir -p "$(dirname "$JNI_LIBS/$relative_path")"
  cp "$TMPDIR_FETCH/$relative_path" "$JNI_LIBS/$relative_path"
  chmod 755 "$JNI_LIBS/$relative_path"
done < "$CHECKSUMS_FILE"

echo "Restored PRoot runtime; all checksums match $CHECKSUMS_FILE"
