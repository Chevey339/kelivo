#!/usr/bin/env bash
# Download Termux PRoot (and its shared-library deps) for Android jniLibs.
#
# OpenMinis pinned Termux proot 5.1.107-70. That build has rolled off
# https://packages.termux.dev/apt/termux-main/pool/main/p/proot/ — the
# current package is 5.1.107.92, which is dynamically linked against
# libtalloc and libandroid-shmem.
#
# Layout written:
#   android/app/src/main/jniLibs/<abi>/libproot_exec.so
#   android/app/src/main/jniLibs/<abi>/libproot_loader.so
#   android/app/src/main/jniLibs/<abi>/libtalloc.so
#   android/app/src/main/jniLibs/<abi>/libandroid-shmem.so
#
# Usage: ./tool/fetch_proot.sh

set -euo pipefail

for need in python3 curl tar; do
  if ! command -v "$need" >/dev/null 2>&1; then
    echo "error: required tool missing: $need" >&2
    exit 1
  fi
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CHECKSUMS_FILE="$SCRIPT_DIR/proot_checksums.txt"
JNI_LIBS="$REPO_ROOT/android/app/src/main/jniLibs"

TERMUX_POOL="${TERMUX_POOL:-https://packages.termux.dev/apt/termux-main/pool/main}"

# Rolling Termux versions. Override with env vars if the pool moves again.
PROOT_VERSION="${PROOT_VERSION:-5.1.107.92}"
TALLOC_VERSION="${TALLOC_VERSION:-2.4.3}"
SHMEM_VERSION="${SHMEM_VERSION:-0.7}"

# termux-arch:android-abi
ABIS=(
  "arm:armeabi-v7a"
  "aarch64:arm64-v8a"
  "x86_64:x86_64"
)

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

# macOS / BSD `ar` rejects Debian members named `data.tar.xz/` (trailing
# slash). Parse the SysV archive in Python instead.
extract_ar() {
  local deb="$1"
  local dest="$2"
  python3 - "$deb" "$dest" <<'PY'
import sys
from pathlib import Path

deb = Path(sys.argv[1])
dest = Path(sys.argv[2])
dest.mkdir(parents=True, exist_ok=True)
data = deb.read_bytes()
if data[:8] != b"!<arch>\n":
    raise SystemExit(f"not an ar archive: {deb}")
offset = 8
while offset + 60 <= len(data):
    header = data[offset : offset + 60]
    offset += 60
    raw_name = header[0:16].decode("ascii", "replace").strip()
    size = int(header[48:58].decode("ascii").strip())
    payload = data[offset : offset + size]
    offset += size + (size % 2)
    if raw_name.startswith("#1/"):
        name_len = int(raw_name[3:])
        raw_name = payload[:name_len].decode("ascii", "replace").rstrip("\x00")
        payload = payload[name_len:]
    name = raw_name.rstrip("/").split("/")[-1]
    if not name:
        continue
    (dest / name).write_bytes(payload)
PY
}

extract_deb() {
  local deb="$1"
  local dest="$2"
  mkdir -p "$dest"
  extract_ar "$deb" "$dest"
  (
    cd "$dest"
    local data=""
    if [[ -f data.tar.xz ]]; then
      data=data.tar.xz
    elif [[ -f data.tar.gz ]]; then
      data=data.tar.gz
    elif [[ -f data.tar.zst ]]; then
      if ! command -v zstd >/dev/null 2>&1; then
        echo "error: $deb contains data.tar.zst but zstd is not installed" >&2
        exit 1
      fi
      zstd -d data.tar.zst -o data.tar
      data=data.tar
    elif [[ -f data.tar ]]; then
      data=data.tar
    else
      echo "error: no data.tar* in $deb" >&2
      ls -la
      exit 1
    fi
    tar xf "$data"
  )
}

find_regular_file() {
  local root="$1"
  shift
  local name
  for name in "$@"; do
    local found
    found="$(find "$root" -type f -name "$name" ! -name '*32' | head -n 1 || true)"
    if [[ -n "$found" ]]; then
      echo "$found"
      return 0
    fi
  done
  return 1
}

copy_elf() {
  local src="$1"
  local dest="$2"
  mkdir -p "$(dirname "$dest")"
  # Follow a symlink to the real ELF so AGP packages a file, not a link.
  cp -f "$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$src")" "$dest"
  chmod 755 "$dest"
}

verify_checksums() {
  if [[ ! -f "$CHECKSUMS_FILE" ]]; then
    echo "error: checksum file missing: $CHECKSUMS_FILE" >&2
    echo "  Refusing to accept unverified binaries. Commit tool/proot_checksums.txt." >&2
    exit 1
  fi
  echo "Verifying $CHECKSUMS_FILE"
  local hash path actual
  while read -r hash path; do
    [[ -z "${hash:-}" || "$hash" == \#* ]] && continue
    if [[ ! -f "$REPO_ROOT/$path" ]]; then
      echo "error: checksum path missing: $path" >&2
      exit 1
    fi
    actual="$(sha256_of "$REPO_ROOT/$path")"
    if [[ "$actual" != "$hash" ]]; then
      echo "error: checksum mismatch for $path" >&2
      echo "  expected: $hash" >&2
      echo "  actual:   $actual" >&2
      exit 1
    fi
  done < "$CHECKSUMS_FILE"
}

TMPDIR_FETCH="$(mktemp -d "${TMPDIR:-/tmp}/kelivo-proot.XXXXXX")"
cleanup() { rm -rf "$TMPDIR_FETCH"; }
trap cleanup EXIT

echo "Fetching Termux proot ${PROOT_VERSION} (+ libtalloc ${TALLOC_VERSION}, libandroid-shmem ${SHMEM_VERSION})"
echo "Pool: $TERMUX_POOL"

# The historical OpenMinis pin is documented; fail clearly if someone overrides
# to a version the pool no longer serves.
if ! curl -fsI --retry 5 --retry-delay 2 --retry-all-errors \
    "${TERMUX_POOL}/p/proot/proot_${PROOT_VERSION}_aarch64.deb" >/dev/null; then
  echo "error: proot_${PROOT_VERSION} is not on the Termux pool." >&2
  echo "  Tried: ${TERMUX_POOL}/p/proot/proot_${PROOT_VERSION}_aarch64.deb" >&2
  echo "  OpenMinis used 5.1.107-70; that package has rolled off." >&2
  echo "  Set PROOT_VERSION to a version listed at ${TERMUX_POOL}/p/proot/" >&2
  exit 1
fi

for pair in "${ABIS[@]}"; do
  termux_arch="${pair%%:*}"
  android_abi="${pair##*:}"
  dest_dir="$JNI_LIBS/$android_abi"
  mkdir -p "$dest_dir"

  work="$TMPDIR_FETCH/$termux_arch"
  mkdir -p "$work"

  echo ""
  echo "== ${termux_arch} → ${android_abi} =="

  curl -fSL --retry 5 --retry-delay 2 --retry-all-errors -o "$work/proot.deb" \
    "${TERMUX_POOL}/p/proot/proot_${PROOT_VERSION}_${termux_arch}.deb"
  curl -fSL --retry 5 --retry-delay 2 --retry-all-errors -o "$work/talloc.deb" \
    "${TERMUX_POOL}/libt/libtalloc/libtalloc_${TALLOC_VERSION}_${termux_arch}.deb"
  curl -fSL --retry 5 --retry-delay 2 --retry-all-errors -o "$work/shmem.deb" \
    "${TERMUX_POOL}/liba/libandroid-shmem/libandroid-shmem_${SHMEM_VERSION}_${termux_arch}.deb"

  extract_deb "$work/proot.deb" "$work/proot"
  extract_deb "$work/talloc.deb" "$work/talloc"
  extract_deb "$work/shmem.deb" "$work/shmem"

  proot_bin="$(find_regular_file "$work/proot" proot)" \
    || { echo "error: proot binary missing from deb" >&2; find "$work/proot" -type f; exit 1; }
  loader_bin="$(find_regular_file "$work/proot" loader)" \
    || { echo "error: proot loader missing from deb" >&2; find "$work/proot" -type f; exit 1; }
  talloc_bin="$(find_regular_file "$work/talloc" 'libtalloc.so.2.*' 'libtalloc.so.2' 'libtalloc.so')" \
    || { echo "error: libtalloc missing from deb" >&2; find "$work/talloc" -type f; exit 1; }
  shmem_bin="$(find_regular_file "$work/shmem" 'libandroid-shmem.so')" \
    || { echo "error: libandroid-shmem missing from deb" >&2; find "$work/shmem" -type f; exit 1; }

  copy_elf "$proot_bin" "$dest_dir/libproot_exec.so"
  copy_elf "$loader_bin" "$dest_dir/libproot_loader.so"
  copy_elf "$talloc_bin" "$dest_dir/libtalloc.so"
  copy_elf "$shmem_bin" "$dest_dir/libandroid-shmem.so"

  for so in libproot_exec.so libproot_loader.so libtalloc.so libandroid-shmem.so; do
    path="$dest_dir/$so"
    if [[ ! -f "$path" || ! -s "$path" ]]; then
      echo "error: missing or empty $path after extract" >&2
      exit 1
    fi
    if command -v file >/dev/null 2>&1; then
      echo "  $(file "$path")"
    fi
    echo "  sha256 $(sha256_of "$path")  ${android_abi}/${so}"
  done
done

echo ""
echo "Checking required binaries exist"
for pair in "${ABIS[@]}"; do
  android_abi="${pair##*:}"
  for so in libproot_exec.so libproot_loader.so libtalloc.so libandroid-shmem.so; do
    path="$JNI_LIBS/$android_abi/$so"
    if [[ ! -f "$path" || ! -s "$path" ]]; then
      echo "error: required binary missing: $path" >&2
      exit 1
    fi
  done
done

echo ""
verify_checksums
echo "Checksums match $CHECKSUMS_FILE"

echo ""
echo "Done. Binaries are local-only (gitignored). NOTICE lives at:"
echo "  $JNI_LIBS/NOTICE"
