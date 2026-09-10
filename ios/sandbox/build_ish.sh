#!/bin/bash
set -euo pipefail

# ============================================================================
# iSH-ARM64 static library build for the Kelivo iOS Workspace sandbox
# ============================================================================
# Builds libish.a / libish_emu.a / libfakefs.a (arm64) from the Chevey339
# ish-arm64 fork, which emulates an aarch64 Linux userland inside the app
# process (asbestos engine = threaded interpreter, no JIT, App Store safe).
#
# Per-SDK outputs (Strategy A):
#   ios/sandbox/build/iphoneos/         device slice (xcrun --sdk iphoneos)
#   ios/sandbox/build/iphonesimulator/  simulator slice
#                                       (xcrun --sdk iphonesimulator,
#                                        -target arm64-apple-ios<min>-simulator)
# Host / guest artifacts built once:
#   ios/sandbox/build/fakefsify         host tool (prepare_alpine_rootfs.sh)
#   ios/sandbox/resources/libvdso.so.elf  guest ELF (platform-independent)
#   ios/sandbox/build/include/          shared headers (+ generated cpu-offsets.h)
#
# Simulator notes:
#   OpenMinis never shipped a simulator iSH slice (libish_emu.a was treated as
#   device-only). This script builds an arm64-ios-simulator slice. Asbestos
#   only has guest-arm64 gadgets for an aarch64 host (no gadgets-x86_64), so
#   x86_64 simulator is excluded in Flutter/Workspace.xcconfig.
#
# Kelivo patches (ios/sandbox/patches/*.patch) are applied after fetch_ish
# pins the clone to ISH_SHA. apply_ish_patches is idempotent: git apply
# --check then apply, or skip if git apply --reverse --check succeeds
# (already applied). Re-running on an existing checkout is safe. See
# patches/README.md. Put SDK-specific compile workarounds in extra
# numbered patches (they apply to the shared source tree) or extend
# apply_ish_patches — do not keep an empty per-SDK stub.
#
# Adapted from Cuplivo ios/sandbox/build_ish.sh and OpenMinis/deps/build_ish.sh.
#
# Requirements (macOS only):
#   - Xcode command line tools (iphoneos + iphonesimulator SDKs)
#   - meson and ninja (brew install meson ninja)
#   - LLVM/Clang (brew install llvm) — required for the guest VDSO
#   - lld (brew install lld; llvm 22+ ships it as a separate formula)
#
# Usage:
#   ios/sandbox/build_ish.sh [clean]
#   ios/sandbox/build_ish.sh [iphoneos|iphonesimulator|all]
#   TARGET_SDK=iphonesimulator ios/sandbox/build_ish.sh
#   PLATFORM_NAME is honoured when TARGET_SDK is unset (Xcode script phases).
#
# Output (gitignored):
#   ios/sandbox/build/<sdk>/    libish.a libish_emu.a libfakefs.a
#   ios/sandbox/build/          fakefsify
#   ios/sandbox/build/include/  ish/* headers (+ generated cpu-offsets.h)
#   ios/sandbox/resources/      libvdso.so.elf
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISH_DIR="$SCRIPT_DIR/ish"
OUTPUT_DIR="$SCRIPT_DIR/build"
OUTPUT_INCLUDE="$OUTPUT_DIR/include"
OUTPUT_RESOURCES="$SCRIPT_DIR/resources"

# Follow the deps/ish gitlink in OpenMinis/OpenMinis main, using our fork.
# Update this fixed SHA when their main project adopts a new iSH revision.
ISH_REPO="https://github.com/Chevey339/ish-arm64.git"
ISH_SHA="3f6384c70eefd1a370f121d3492a5f21f7767df9"

ARCHS="arm64"
IOS_DEPLOYMENT_TARGET="15.0"
BUILD_TYPE="${BUILD_TYPE:-release}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info()    { echo -e "${BLUE}[ish-build]${NC} $1"; }
log_success() { echo -e "${GREEN}[ish-build]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[ish-build]${NC} $1"; }
log_error()   { echo -e "${RED}[ish-build]${NC} $1"; exit 1; }

# ---------------------------------------------------------------------------
# SDK selection
# ---------------------------------------------------------------------------
# Prefer explicit argv, then TARGET_SDK, then Xcode's PLATFORM_NAME, else all
# when invoked as a full rebuild and iphoneos when a single default is needed.
# `all` builds both slices so a machine can cache device + simulator artifacts.
resolve_sdks() {
    local raw="${1:-}"
    if [ -z "$raw" ]; then
        raw="${TARGET_SDK:-${PLATFORM_NAME:-all}}"
    fi
    case "$raw" in
        clean) echo "clean" ;;
        iphoneos|iphonesimulator) echo "$raw" ;;
        all|both)
            echo "iphoneos iphonesimulator"
            ;;
        *)
            log_error "unknown SDK '$raw' (expected iphoneos, iphonesimulator, all, or clean)"
            ;;
    esac
}

sdk_meson_dir() {
    echo "$ISH_DIR/build-ios-$1"
}

sdk_output_dir() {
    echo "$OUTPUT_DIR/$1"
}

# ---------------------------------------------------------------------------
# Housekeeping
# ---------------------------------------------------------------------------
clean_build() {
    log_info "Cleaning build artifacts..."
    rm -rf "$ISH_DIR/build-ios" \
           "$ISH_DIR/build-ios-iphoneos" \
           "$ISH_DIR/build-ios-iphonesimulator" \
           "$ISH_DIR/build-native" \
           "$OUTPUT_DIR"
    rm -f "$OUTPUT_RESOURCES/libvdso.so.elf"
    log_success "Clean completed (ish checkout kept)"
}

# Pre-Strategy-A layout stored the device .a files at build/*.a. Move them
# into build/iphoneos/ so LIBRARY_SEARCH_PATHS=$(PLATFORM_NAME) is consistent.
migrate_legacy_layout() {
    if [ -f "$OUTPUT_DIR/libish.a" ] && [ ! -f "$OUTPUT_DIR/iphoneos/libish.a" ]; then
        mkdir -p "$OUTPUT_DIR/iphoneos"
        mv "$OUTPUT_DIR/libish.a" "$OUTPUT_DIR/libish_emu.a" "$OUTPUT_DIR/libfakefs.a" \
            "$OUTPUT_DIR/iphoneos/"
        log_info "migrated legacy build/*.a → build/iphoneos/"
    fi
}

check_prerequisites() {
    command -v python3 >/dev/null 2>&1 || log_error "python3 is required"
    command -v meson >/dev/null 2>&1 || log_error "meson is required (brew install meson)"
    command -v ninja >/dev/null 2>&1 || log_error "ninja is required (brew install ninja)"
    xcode-select -p >/dev/null 2>&1 || log_error "Xcode command line tools required"

    LLVM_CLANG=""
    for clang_path in "/opt/homebrew/opt/llvm/bin/clang" "/usr/local/opt/llvm/bin/clang" "/opt/local/bin/clang"; do
        if [ -x "$clang_path" ]; then LLVM_CLANG="$clang_path"; break; fi
    done
    [ -n "$LLVM_CLANG" ] || log_error "LLVM clang not found (brew install llvm) — needed for the guest VDSO"
    log_info "LLVM clang: $LLVM_CLANG"
    export PATH="$(dirname "$LLVM_CLANG"):$PATH"
    command -v ld.lld >/dev/null 2>&1 || log_error "ld.lld not found (brew install lld) — needed for the guest VDSO link (-fuse-ld=lld)"
    log_info "ld.lld: $(command -v ld.lld)"
}

ish_tree_usable() {
    local dir="$1"
    [ -f "$dir/meson.build" ] && [ -d "$dir/kernel" ] && [ -d "$dir/fs" ]
}

fetch_ish() {
    if ish_tree_usable "$ISH_DIR"; then
        local have
        have="$(git -C "$ISH_DIR" rev-parse HEAD 2>/dev/null || true)"
        if [ "$have" = "$ISH_SHA" ]; then
            if [ "$(git -C "$ISH_DIR" remote get-url origin 2>/dev/null || true)" != "$ISH_REPO" ]; then
                log_info "Switching existing checkout to $ISH_REPO"
                git -C "$ISH_DIR" fetch -q --depth 1 "$ISH_REPO" "$ISH_SHA"
                if git -C "$ISH_DIR" remote get-url origin >/dev/null 2>&1; then
                    git -C "$ISH_DIR" remote set-url origin "$ISH_REPO"
                else
                    git -C "$ISH_DIR" remote add origin "$ISH_REPO"
                fi
            fi
            log_info "ish-arm64 checkout matches $ISH_REPO @ ${ISH_SHA:0:12}"
            return
        fi
    fi

    log_info "Fetching $ISH_REPO @ ${ISH_SHA:0:12}..."
    rm -rf "$ISH_DIR"
    mkdir -p "$ISH_DIR"
    git init -q "$ISH_DIR"
    git -C "$ISH_DIR" remote add origin "$ISH_REPO"
    git -C "$ISH_DIR" fetch -q --depth 1 origin "$ISH_SHA"
    git -C "$ISH_DIR" checkout -q FETCH_HEAD
    log_success "ish-arm64 checked out"
}

# Includes the repository, pinned revision, build flags, and local patches.
# Each SDK records its own fingerprint only after all outputs are ready.
build_fingerprint() {
    {
        cat "$SCRIPT_DIR/build_ish.sh"
        local patch
        for patch in "$SCRIPT_DIR"/patches/*.patch; do
            [ -f "$patch" ] && cat "$patch"
        done
        printf '%s\n' "$BUILD_TYPE"
    } | shasum -a 256 | awk '{print $1}'
}

init_submodules() {
    # libapps / libarchive / linux are only needed by the standalone iSH app.
    # The static libs + host fakefsify build from the in-tree sources; skip the
    # multi-gigabyte linux submodule (and flaky submodule clones) like Cuplivo.
    if [ -d "$ISH_DIR/deps/libapps" ] && [ ! -f "$ISH_DIR/deps/libapps/package.json" ]; then
        log_info "libapps submodule not required for static libs — skipping"
    fi
}

# Apply ios/sandbox/patches/*.patch in name order. Already-applied patches
# (typical on a second run of an existing clone) are skipped.
apply_ish_patches() {
    local patches_dir="$SCRIPT_DIR/patches"
    [ -d "$patches_dir" ] || return 0
    local p name
    for p in "$patches_dir"/*.patch; do
        [ -f "$p" ] || continue
        name="$(basename "$p")"
        if git -C "$ISH_DIR" apply --check "$p" >/dev/null 2>&1; then
            git -C "$ISH_DIR" apply "$p" \
                || log_error "failed to apply $name"
            log_info "applied $name"
        elif git -C "$ISH_DIR" apply --reverse --check "$p" >/dev/null 2>&1; then
            log_info "already applied $name"
        else
            log_error "cannot apply $name (not clean and not already applied)"
        fi
    done
}

# ---------------------------------------------------------------------------
# Cross file + meson
# ---------------------------------------------------------------------------
write_cross_file() {
    local sdk="$1"
    local build_dir
    build_dir="$(sdk_meson_dir "$sdk")"
    mkdir -p "$build_dir"

    local ios_sdk clang_args
    ios_sdk="$(xcrun --sdk "$sdk" --show-sdk-path)"
    [ -n "$ios_sdk" ] && [ -d "$ios_sdk" ] || log_error "SDK path missing for $sdk"

    case "$sdk" in
        iphoneos)
            # Keep the device flags that already ship (miphoneos-version-min).
            clang_args="'-arch', '$ARCHS', '-isysroot', '$ios_sdk', '-miphoneos-version-min=$IOS_DEPLOYMENT_TARGET'"
            ;;
        iphonesimulator)
            # Simulator must not use -miphoneos-version-min (that marks the
            # object as iphoneos and Xcode refuses to link it into a sim app).
            clang_args="'-arch', '$ARCHS', '-isysroot', '$ios_sdk', '-target', 'arm64-apple-ios${IOS_DEPLOYMENT_TARGET}-simulator'"
            ;;
        *)
            log_error "write_cross_file: unsupported sdk $sdk"
            ;;
    esac

    local cross_file="$build_dir/ios-cross.txt"
    cat > "$cross_file" << EOF
[binaries]
c = ['clang', $clang_args]
ar = 'ar'
strip = 'strip'
pkg-config = 'false'

[host_machine]
system = 'darwin'
cpu_family = 'aarch64'
cpu = 'aarch64'
endian = 'little'

[built-in options]
c_args = []
c_link_args = ['-L$ios_sdk/usr/lib']

[properties]
needs_exe_wrapper = true
sys_root = '$ios_sdk'
library_dirs = ['$ios_sdk/usr/lib']
EOF
    log_success "Cross-compilation file for $sdk (SDK: $ios_sdk)"
}

build_ish_sdk() {
    local sdk="$1"
    local build_dir
    build_dir="$(sdk_meson_dir "$sdk")"
    local cross_file="$build_dir/ios-cross.txt"
    write_cross_file "$sdk"

    cd "$ISH_DIR"

    local MESON_BUILDTYPE="release"
    local MESON_NDEBUG="true"
    if [ "$BUILD_TYPE" = "debug" ]; then
        MESON_BUILDTYPE="debug"
        MESON_NDEBUG="false"
    fi

    if [ ! -f "$build_dir/build.ninja" ]; then
        log_info "Configuring meson $sdk build ($MESON_BUILDTYPE)..."
        meson setup "$build_dir" \
            --cross-file "$cross_file" \
            --buildtype="$MESON_BUILDTYPE" \
            -Db_ndebug="$MESON_NDEBUG" \
            -Dlog="" \
            -Dlog_handler=nslog \
            -Dkernel=ish \
            -Dengine=asbestos \
            -Dguest_arch=arm64
    else
        meson configure "$build_dir" \
            --buildtype="$MESON_BUILDTYPE" \
            -Db_ndebug="$MESON_NDEBUG"
    fi

    log_info "Building static libraries ($sdk)..."
    ninja -C "$build_dir" libish.a libish_emu.a libfakefs.a
    log_success "$sdk libraries built"
    cd "$SCRIPT_DIR"
}

# Guest VDSO is an aarch64 Linux ELF compiled with Homebrew LLVM + lld; it is
# not an iOS object. Build it once from whichever meson dir is available.
build_vdso_once() {
    if [ -s "$OUTPUT_RESOURCES/libvdso.so.elf" ]; then
        log_info "guest VDSO already in $OUTPUT_RESOURCES"
        return
    fi

    local build_dir=""
    local sdk
    for sdk in iphoneos iphonesimulator; do
        if [ -f "$(sdk_meson_dir "$sdk")/build.ninja" ]; then
            build_dir="$(sdk_meson_dir "$sdk")"
            break
        fi
    done
    [ -n "$build_dir" ] || log_error "no meson iOS build dir to compile the guest VDSO"

    log_info "Building guest VDSO..."
    ninja -C "$build_dir" vdso/arm64/libvdso.so.elf
    if [ ! -s "$build_dir/vdso/arm64/libvdso.so.elf" ]; then
        log_error "VDSO is empty — LLVM/clang with lld is required (brew install llvm lld)"
    fi
    mkdir -p "$OUTPUT_RESOURCES" "$OUTPUT_DIR"
    cp "$build_dir/vdso/arm64/libvdso.so.elf" "$OUTPUT_RESOURCES/"
    cp "$build_dir/vdso/arm64/libvdso.so.elf" "$OUTPUT_DIR/"
    log_success "guest VDSO copied"
}

build_fakefsify() {
    local BUILD_DIR="$ISH_DIR/build-native"
    if [ -x "$OUTPUT_DIR/fakefsify" ]; then
        log_info "host fakefsify already in $OUTPUT_DIR"
        return
    fi
    if [ -x "$BUILD_DIR/tools/fakefsify" ]; then
        mkdir -p "$OUTPUT_DIR"
        cp "$BUILD_DIR/tools/fakefsify" "$OUTPUT_DIR/fakefsify"
        log_info "host fakefsify copied from existing native build"
        return
    fi

    mkdir -p "$BUILD_DIR"
    cd "$ISH_DIR"
    # Xcode exports the iOS SDK into script phases. This executable runs on
    # the Mac, so both Meson's compiler probe and ninja must use the host SDK.
    local host_sdk
    host_sdk="$(xcrun --sdk macosx --show-sdk-path)"
    if [ ! -f "$BUILD_DIR/build.ninja" ]; then
        log_info "Configuring native meson build (host fakefsify)..."
        env -u IPHONEOS_DEPLOYMENT_TARGET SDKROOT="$host_sdk" meson setup "$BUILD_DIR" \
            --buildtype=release \
            -Dlog="" \
            -Dkernel=ish \
            -Dengine=asbestos \
            -Dguest_arch=arm64
    fi
    log_info "Building host fakefsify..."
    env -u IPHONEOS_DEPLOYMENT_TARGET SDKROOT="$host_sdk" ninja -C "$BUILD_DIR" tools/fakefsify
    mkdir -p "$OUTPUT_DIR"
    cp "$BUILD_DIR/tools/fakefsify" "$OUTPUT_DIR/fakefsify"
    cd "$SCRIPT_DIR"
    log_success "host fakefsify built"
}

copy_sdk_libs() {
    local sdk="$1"
    local build_dir
    build_dir="$(sdk_meson_dir "$sdk")"
    local slice
    slice="$(sdk_output_dir "$sdk")"
    mkdir -p "$slice"
    cp "$build_dir/libish.a" "$build_dir/libish_emu.a" "$build_dir/libfakefs.a" "$slice/"
    log_success "copied $sdk libs → $slice"
}

copy_headers() {
    local sdk="$1"
    local BUILD_DIR
    BUILD_DIR="$(sdk_meson_dir "$sdk")"
    mkdir -p "$OUTPUT_INCLUDE/ish/emu" "$OUTPUT_INCLUDE/ish/kernel" "$OUTPUT_INCLUDE/ish/fs" \
             "$OUTPUT_INCLUDE/ish/fs/proc" "$OUTPUT_INCLUDE/ish/util" "$OUTPUT_INCLUDE/ish/platform" \
             "$OUTPUT_INCLUDE/ish/asbestos"

    cp "$ISH_DIR/debug.h" "$ISH_DIR/misc.h" "$ISH_DIR/xX_main_Xx.h" "$OUTPUT_INCLUDE/ish/"
    cp "$ISH_DIR"/emu/*.h "$OUTPUT_INCLUDE/ish/emu/"
    cp "$ISH_DIR"/kernel/*.h "$OUTPUT_INCLUDE/ish/kernel/"
    cp "$ISH_DIR"/fs/*.h "$OUTPUT_INCLUDE/ish/fs/"
    [ -d "$ISH_DIR/fs/proc" ] && cp "$ISH_DIR"/fs/proc/*.h "$OUTPUT_INCLUDE/ish/fs/proc/" 2>/dev/null || true
    cp "$ISH_DIR"/util/*.h "$OUTPUT_INCLUDE/ish/util/" 2>/dev/null || true
    cp "$ISH_DIR"/platform/*.h "$OUTPUT_INCLUDE/ish/platform/"
    cp "$ISH_DIR"/asbestos/*.h "$OUTPUT_INCLUDE/ish/asbestos/"
    mkdir -p "$OUTPUT_INCLUDE/ish/asbestos/guest-arm64/gadgets-aarch64"
    cp "$ISH_DIR"/asbestos/guest-arm64/gadgets-aarch64/*.h \
       "$OUTPUT_INCLUDE/ish/asbestos/guest-arm64/gadgets-aarch64/" 2>/dev/null || true
    cp "$ISH_DIR"/asbestos/gadgets-generic.h "$OUTPUT_INCLUDE/ish/asbestos/" 2>/dev/null || true
    mkdir -p "$OUTPUT_INCLUDE/ish/emu/arch/arm64" "$OUTPUT_INCLUDE/ish/kernel/arch/arm64"
    cp "$ISH_DIR"/emu/arch/arm64/*.h "$OUTPUT_INCLUDE/ish/emu/arch/arm64/" 2>/dev/null || true
    cp "$ISH_DIR"/kernel/arch/arm64/*.h "$OUTPUT_INCLUDE/ish/kernel/arch/arm64/" 2>/dev/null || true
    [ -f "$BUILD_DIR/cpu-offsets.h" ] && cp "$BUILD_DIR/cpu-offsets.h" "$OUTPUT_INCLUDE/ish/"
    if [ -f "$ISH_DIR/deps/config.h" ]; then
        mkdir -p "$OUTPUT_INCLUDE/ish/deps"
        cp "$ISH_DIR/deps/config.h" "$OUTPUT_INCLUDE/ish/deps/"
    fi

    cat > "$OUTPUT_INCLUDE/ish/ish.h" << 'EOF'
#ifndef ISH_H
#define ISH_H

#include "misc.h"
#include "debug.h"

#include "kernel/init.h"
#include "kernel/task.h"
#include "kernel/calls.h"
#include "kernel/fs.h"
#include "kernel/memory.h"
#include "kernel/signal.h"
#include "kernel/errno.h"

#include "fs/fd.h"
#include "fs/stat.h"
#include "fs/tty.h"
#include "fs/fake.h"
#include "fs/real.h"
#include "fs/poll.h"
#include "fs/dev.h"

#include "emu/cpu.h"
#include "emu/tlb.h"
#include "emu/mmu.h"
#if defined(GUEST_X86)
#include "emu/float80.h"
#endif

#include "platform/platform.h"

#endif /* ISH_H */
EOF

    log_success "Outputs copied to $OUTPUT_DIR and $OUTPUT_INCLUDE"
}

print_summary() {
    echo ""
    echo "============================================================"
    log_success "iSH-ARM64 build complete"
    echo "============================================================"
    local sdk
    for sdk in iphoneos iphonesimulator; do
        if [ -d "$(sdk_output_dir "$sdk")" ]; then
            echo "  $sdk:"
            ls -lh "$(sdk_output_dir "$sdk")"/*.a 2>/dev/null || echo "    (none)"
        fi
    done
    echo ""
    ls -lh "$OUTPUT_DIR/fakefsify" 2>/dev/null || echo "  fakefsify: (missing)"
    echo ""
    echo "Xcode links via Flutter/Workspace.xcconfig:"
    echo "  LIBRARY_SEARCH_PATHS = \$(SRCROOT)/sandbox/build/\$(PLATFORM_NAME)"
    echo "============================================================"
}

main() {
    if [ "${1:-}" = "fingerprint" ]; then build_fingerprint; return; fi
    echo ""
    echo "============================================================"
    echo "  Kelivo iOS Workspace: iSH-ARM64 static library builder"
    echo "  Guest arch: arm64 (aarch64 Linux userland emulation)"
    echo "============================================================"
    echo ""
    if [ "${1:-}" = "clean" ]; then clean_build; exit 0; fi

    local sdks
    sdks="$(resolve_sdks "${1:-}")"
    migrate_legacy_layout
    check_prerequisites
    fetch_ish
    apply_ish_patches
    init_submodules

    local fingerprint
    fingerprint="$(build_fingerprint)"
    if [ ! -f "$OUTPUT_DIR/.kelivo-ish-build" ] || [ "$(cat "$OUTPUT_DIR/.kelivo-ish-build")" != "$fingerprint" ]; then
        # Host tools and the guest VDSO must change with the source too.
        # Retain the checkout and bundled rootfs; discard only build outputs.
        clean_build
    fi

    local sdk headers_from=""
    for sdk in $sdks; do
        build_ish_sdk "$sdk"
        copy_sdk_libs "$sdk"
        headers_from="$sdk"
    done
    [ -n "$headers_from" ] || log_error "no SDK built"
    copy_headers "$headers_from"
    build_vdso_once
    build_fakefsify
    # Keep the compatibility scripts exactly aligned with the pinned iSH.
    local patch_bundle="$ISH_DIR/app/RootfsPatch.bundle"
    [ -s "$patch_bundle/manifest.plist" ] || log_error "RootfsPatch manifest missing"
    mkdir -p "$OUTPUT_RESOURCES/RootfsPatch.bundle"
    rsync -a --delete "$patch_bundle/" "$OUTPUT_RESOURCES/RootfsPatch.bundle/"
    for sdk in $sdks; do
        printf '%s\n' "$fingerprint" > "$(sdk_output_dir "$sdk")/.kelivo-ish-build"
    done
    printf '%s\n' "$fingerprint" > "$OUTPUT_DIR/.kelivo-ish-build"
    print_summary
}

main "$@"
