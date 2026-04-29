#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ish_dir="$repo_root/dependencies/ish-arm64"

fail() {
  echo "error: $*" >&2
  exit 1
}

note() {
  echo "info: $*"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    fail "missing required command '$1'"
  fi
}

[[ -d "$ish_dir/.git" || -f "$ish_dir/.git" ]] ||
  fail "OpenMinis iSH ARM64 submodule is missing at dependencies/ish-arm64. Run: git submodule update --init --recursive dependencies/ish-arm64"

[[ -f "$ish_dir/iSH.xcodeproj/project.pbxproj" ]] ||
  fail "OpenMinis iSH Xcode project is missing"

[[ -f "$ish_dir/kernel/init.h" ]] ||
  fail "OpenMinis kernel/init.h is missing; Kelivo uses the libish init boundary"

[[ -f "$ish_dir/fs/fake.h" ]] ||
  fail "OpenMinis fs/fake.h is missing; Kelivo needs fakefs for the ARM64 rootfs"

[[ -d "$ish_dir/deps/libarchive/.git" || -f "$ish_dir/deps/libarchive/.git" ]] ||
  fail "OpenMinis libarchive submodule is missing. Run: git submodule update --init --recursive dependencies/ish-arm64"

[[ -d "$ish_dir/deps/libapps/.git" || -f "$ish_dir/deps/libapps/.git" ]] ||
  fail "OpenMinis libapps submodule is missing. Run: git submodule update --init --recursive dependencies/ish-arm64"

require_cmd xcrun
require_cmd xcodebuild
require_cmd python3
require_cmd meson
require_cmd ninja

if [[ -n "${KELIVO_LLD_BIN:-}" ]]; then
  export PATH="$KELIVO_LLD_BIN:$PATH"
fi

if [[ -d /opt/homebrew/opt/lld/bin ]]; then
  export PATH="/opt/homebrew/opt/lld/bin:$PATH"
fi

if [[ -d /opt/homebrew/opt/llvm/bin ]]; then
  export PATH="/opt/homebrew/opt/llvm/bin:$PATH"
fi

require_cmd ld.lld

if [[ ! -f "$ish_dir/app/ISHShellExecutor.h" ]]; then
  note "OpenMinis README mentions ISHShellExecutor, but this checkout does not contain it; Kelivo uses libish directly."
fi

if [[ ! -f "$ish_dir/app/DebugServer.c" ]]; then
  note "OpenMinis README mentions DebugServer.c, but this checkout does not contain it; Kelivo will keep diagnostics in its own bridge for now."
fi

note "OpenMinis iSH ARM64 checkout is ready for an Xcode/Meson build."
