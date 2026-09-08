#!/bin/bash
set -euo pipefail

# ============================================================================
# Ensure iSH static libs + Alpine fakefs zip exist for an iOS build.
# Invoked from the Runner "Ensure Workspace Sandbox Artifacts" script phase
# and from CI. Rebuilds only what is missing or stale. No silent fallbacks.
#
# Xcode sets PLATFORM_NAME=iphoneos | iphonesimulator. The iSH .a files live
# under build/$PLATFORM_NAME/. Host fakefsify, shared headers, the guest VDSO,
# and alpine-rootfs.zip are platform-independent.
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
RESOURCES_DIR="$SCRIPT_DIR/resources"
VERSION_FILE="$RESOURCES_DIR/VERSION"
ZIP_PATH="$RESOURCES_DIR/alpine-rootfs.zip"
BREW_INSTALL="brew install meson ninja llvm lld"

# Slice for the current Xcode SDK. CLI / CI default to iphoneos.
SDK="${TARGET_SDK:-${PLATFORM_NAME:-iphoneos}}"
case "$SDK" in
    iphoneos|iphonesimulator) ;;
    *)
        echo "ensure_artifacts: ignoring PLATFORM_NAME='$SDK'; using iphoneos" >&2
        SDK="iphoneos"
        ;;
esac
SLICE_DIR="$BUILD_DIR/$SDK"

die() {
    echo "error: $1" >&2
    exit 1
}

# Xcode script phases do not inherit Homebrew's PATH. Locate the required
# Homebrew tools explicitly; do not fall back to Xcode's system clang.
export PATH="/opt/homebrew/bin:/usr/local/bin:${PATH}"

missing=()
command -v meson >/dev/null 2>&1 || missing+=(meson)
command -v ninja >/dev/null 2>&1 || missing+=(ninja)

LLVM_CLANG=""
for clang_path in \
    "/opt/homebrew/opt/llvm/bin/clang" \
    "/usr/local/opt/llvm/bin/clang"; do
    if [ -x "$clang_path" ]; then
        LLVM_CLANG="$clang_path"
        break
    fi
done
if [ -z "$LLVM_CLANG" ]; then
    missing+=(llvm)
else
    export PATH="$(dirname "$LLVM_CLANG"):${PATH}"
fi

LLD=""
for lld_path in \
    "/opt/homebrew/opt/lld/bin/ld.lld" \
    "/opt/homebrew/opt/llvm/bin/ld.lld" \
    "/usr/local/opt/lld/bin/ld.lld" \
    "/usr/local/opt/llvm/bin/ld.lld"; do
    if [ -x "$lld_path" ]; then
        LLD="$lld_path"
        break
    fi
done
if [ -z "$LLD" ]; then
    if command -v ld.lld >/dev/null 2>&1; then
        LLD="$(command -v ld.lld)"
    elif command -v lld >/dev/null 2>&1; then
        LLD="$(command -v lld)"
    fi
fi
if [ -z "$LLD" ]; then
    missing+=(lld)
else
    export PATH="$(dirname "$LLD"):${PATH}"
fi

if [ "${#missing[@]}" -gt 0 ]; then
    die "missing ${missing[*]}; install with: ${BREW_INSTALL}"
fi

# Pre-Strategy-A layout stored device libs at build/*.a.
if [ -f "$BUILD_DIR/libish.a" ] && [ ! -f "$BUILD_DIR/iphoneos/libish.a" ]; then
    mkdir -p "$BUILD_DIR/iphoneos"
    mv "$BUILD_DIR/libish.a" "$BUILD_DIR/libish_emu.a" "$BUILD_DIR/libfakefs.a" \
        "$BUILD_DIR/iphoneos/"
    echo "ensure_artifacts: migrated legacy build/*.a → build/iphoneos/"
fi

need_ish=0
fingerprint="$("$SCRIPT_DIR/build_ish.sh" fingerprint)"
stamp="$SLICE_DIR/.kelivo-ish-build"
if [ ! -f "$stamp" ] || [ "$(cat "$stamp")" != "$fingerprint" ]; then
    echo "ensure_artifacts: iSH source or build inputs changed; rebuilding $SDK"
    need_ish=1
fi
for f in "$SLICE_DIR/libish.a" "$SLICE_DIR/libish_emu.a" "$SLICE_DIR/libfakefs.a"; do
    if [ ! -s "$f" ]; then
        need_ish=1
        break
    fi
done
if [ ! -x "$BUILD_DIR/fakefsify" ]; then
    need_ish=1
fi
if [ ! -d "$BUILD_DIR/include" ] || [ -z "$(ls -A "$BUILD_DIR/include" 2>/dev/null)" ]; then
    need_ish=1
fi
if [ ! -s "$RESOURCES_DIR/libvdso.so.elf" ]; then
    need_ish=1
fi

need_rootfs=0
if [ ! -s "$ZIP_PATH" ]; then
    need_rootfs=1
else
    if [ ! -f "$VERSION_FILE" ]; then
        die "resources/VERSION is missing; cannot validate alpine-rootfs.zip"
    fi
    expected="$(tr -d '[:space:]' < "$VERSION_FILE")"
    [ -n "$expected" ] || die "resources/VERSION is empty"
    got="$(unzip -p "$ZIP_PATH" VERSION 2>/dev/null | tr -d '[:space:]' || true)"
    if [ -z "$got" ]; then
        got="$(unzip -p "$ZIP_PATH" .version 2>/dev/null | tr -d '[:space:]' || true)"
    fi
    if [ -z "$got" ] || [ "$got" != "$expected" ]; then
        echo "ensure_artifacts: zip VERSION '${got:-<missing>}' != '${expected}'; rebuilding rootfs"
        need_rootfs=1
    fi
fi

# prepare_alpine_rootfs.sh rewrites resources/VERSION (an Xcode inputPath).
# Keep output mtimes strictly newer so "based on dependency analysis" can skip.
stamp_outputs() {
    local stamp=()
    [ -f "$SLICE_DIR/libish.a" ] && stamp+=("$SLICE_DIR/libish.a")
    [ -f "$SLICE_DIR/libish_emu.a" ] && stamp+=("$SLICE_DIR/libish_emu.a")
    [ -f "$SLICE_DIR/libfakefs.a" ] && stamp+=("$SLICE_DIR/libfakefs.a")
    [ -f "$SLICE_DIR/.kelivo-ish-build" ] && stamp+=("$SLICE_DIR/.kelivo-ish-build")
    [ -s "$RESOURCES_DIR/libvdso.so.elf" ] && stamp+=("$RESOURCES_DIR/libvdso.so.elf")
    [ -x "$BUILD_DIR/fakefsify" ] && stamp+=("$BUILD_DIR/fakefsify")
    [ -f "$BUILD_DIR/include/ish/cpu-offsets.h" ] && stamp+=("$BUILD_DIR/include/ish/cpu-offsets.h")
    [ -s "$ZIP_PATH" ] && stamp+=("$ZIP_PATH")
    if [ "${#stamp[@]}" -gt 0 ]; then
        touch "${stamp[@]}"
    fi
}

if [ "$need_ish" -eq 0 ] && [ "$need_rootfs" -eq 0 ]; then
    echo "ensure_artifacts: $SDK iSH libs and alpine-rootfs.zip are up to date"
    stamp_outputs
    exit 0
fi

if [ "$need_ish" -eq 1 ]; then
    echo "ensure_artifacts: building iSH static libraries for $SDK"
    TARGET_SDK="$SDK" "$SCRIPT_DIR/build_ish.sh" "$SDK"
fi

if [ "$need_rootfs" -eq 1 ]; then
    echo "ensure_artifacts: preparing Alpine fakefs zip"
    "$SCRIPT_DIR/prepare_alpine_rootfs.sh"
fi
stamp_outputs
