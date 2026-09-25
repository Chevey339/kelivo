#!/bin/bash
set -euo pipefail

# ============================================================================
# Alpine Linux aarch64 rootfs for the Kelivo iOS Workspace (iSH fakefs)
# ============================================================================
# Downloads Alpine minirootfs (aarch64), installs packages with apk inside
# the host iSH CLI (including its database and install scripts),
# configures repositories / resolv.conf / profile, strips PEP 668
# EXTERNALLY-MANAGED, converts with fakefsify, and zips the result.
#
# Usage:
#   ios/sandbox/prepare_alpine_rootfs.sh [version|clean]
#
# Output (gitignored):
#   ios/sandbox/resources/alpine-rootfs.zip
#   ios/sandbox/resources/VERSION
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISH_DIR="$SCRIPT_DIR/ish"
OUTPUT_DIR="$SCRIPT_DIR/resources"
CACHE_DIR="$SCRIPT_DIR/.cache"
BUILD_DIR="$SCRIPT_DIR/build"

ALPINE_SERIES="${ALPINE_SERIES:-3.21}"
ALPINE_PATCH="${ALPINE_PATCH:-3}"
ALPINE_ARCH="aarch64"
# Official CDN SSL is flaky from some networks; try regional mirrors first
# for the tarball. The .sha256 sidecar is fetched from the official host
# first and only falls back to the tarball's mirror if that host is down.
ALPINE_OFFICIAL="${ALPINE_OFFICIAL:-https://dl-cdn.alpinelinux.org/alpine}"
ALPINE_MIRROR="${ALPINE_MIRROR:-https://mirrors.aliyun.com/alpine}"
ALPINE_MIRRORS=(
    "$ALPINE_MIRROR"
    "https://mirrors.aliyun.com/alpine"
    "https://mirrors.tuna.tsinghua.edu.cn/alpine"
    "https://mirrors.ustc.edu.cn/alpine"
    "https://mirror.sjtu.edu.cn/alpine"
    "$ALPINE_OFFICIAL"
)
ROOTFS_REVISION="r5"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info()    { echo -e "${BLUE}[rootfs]${NC} $1"; }
log_success() { echo -e "${GREEN}[rootfs]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[rootfs]${NC} $1"; }
log_error()   { echo -e "${RED}[rootfs]${NC} $1"; exit 1; }

check_prerequisites() {
    command -v curl >/dev/null 2>&1 || log_error "curl is required"
    command -v python3 >/dev/null 2>&1 || log_error "python3 is required"
    command -v tar >/dev/null 2>&1 || log_error "tar is required"
    command -v zip >/dev/null 2>&1 || log_error "zip is required"
}

curl_ok() {
    # HEAD is unreliable on some mirrors; a 1-byte ranged GET is enough.
    curl -fsL --connect-timeout 15 --max-time 30 -r 0-0 -o /dev/null "$1" >/dev/null 2>&1
}

curl_get() {
    local dest="$1" url="$2"
    local attempt
    for attempt in 1 2 3; do
        if curl -L --fail --retry 2 --retry-delay 1 --connect-timeout 20 --max-time 180 \
            --progress-bar -o "$dest" "$url"; then
            return 0
        fi
        sleep 1
    done
    return 1
}

# Sidecar files are tiny; fail over quickly when a host's TLS is broken.
curl_get_sidecar() {
    local dest="$1" url="$2"
    local attempt
    for attempt in 1 2 3; do
        if curl -L --fail --connect-timeout 10 --max-time 25 --retry 0 \
            --progress-bar -o "$dest" "$url"; then
            return 0
        fi
        sleep 1
    done
    return 1
}

resolve_alpine_tarball() {
    local series="$ALPINE_SERIES"
    local patch="$ALPINE_PATCH"
    local name="alpine-minirootfs-${series}.${patch}-${ALPINE_ARCH}.tar.gz"
    local mirror url listing found
    for mirror in "${ALPINE_MIRRORS[@]}"; do
        url="${mirror}/v${series}/releases/${ALPINE_ARCH}/${name}"
        if curl_ok "$url"; then
            ALPINE_MIRROR="$mirror"
            ALPINE_TARBALL_NAME="$name"
            ALPINE_TARBALL_URL="$url"
            ALPINE_FULL_VERSION="${series}.${patch}"
            return
        fi
    done
    log_warning "${series}.${patch} not on mirrors; probing releases listing"
    for mirror in "${ALPINE_MIRRORS[@]}"; do
        listing="$(curl -fsL --connect-timeout 15 --max-time 30 "${mirror}/v${series}/releases/${ALPINE_ARCH}/" 2>/dev/null)" || continue
        found="$(printf '%s\n' "$listing" | python3 -c "
import re, sys
text = sys.stdin.read()
vers = sorted(set(re.findall(r'alpine-minirootfs-(${series}\.[0-9]+)-${ALPINE_ARCH}\.tar\.gz', text)),
              key=lambda v: [int(x) for x in v.split('.')])
print(vers[-1] if vers else '')
")"
        if [ -n "$found" ]; then
            ALPINE_MIRROR="$mirror"
            ALPINE_FULL_VERSION="$found"
            ALPINE_TARBALL_NAME="alpine-minirootfs-${found}-${ALPINE_ARCH}.tar.gz"
            ALPINE_TARBALL_URL="${mirror}/v${series}/releases/${ALPINE_ARCH}/${ALPINE_TARBALL_NAME}"
            log_info "using Alpine ${ALPINE_FULL_VERSION} from ${mirror}"
            return
        fi
    done
    log_error "no Alpine ${series}.x minirootfs found on any mirror"
}

download_alpine() {
    resolve_alpine_tarball
    mkdir -p "$CACHE_DIR"
    ALPINE_TARBALL_PATH="$CACHE_DIR/$ALPINE_TARBALL_NAME"
    if [ -f "$ALPINE_TARBALL_PATH" ] && [ "$(stat -f%z "$ALPINE_TARBALL_PATH" 2>/dev/null || stat -c%s "$ALPINE_TARBALL_PATH")" -gt 100000 ]; then
        log_info "using cached $ALPINE_TARBALL_NAME"
    else
        log_info "downloading $ALPINE_TARBALL_URL"
        if ! curl_get "$ALPINE_TARBALL_PATH" "$ALPINE_TARBALL_URL"; then
            log_warning "download failed; trying remaining mirrors"
            local mirror name="$ALPINE_TARBALL_NAME" ok=0
            for mirror in "${ALPINE_MIRRORS[@]}"; do
                [ "$mirror" = "$ALPINE_MIRROR" ] && continue
                if curl_get "$ALPINE_TARBALL_PATH" "${mirror}/v${ALPINE_SERIES}/releases/${ALPINE_ARCH}/${name}"; then
                    ALPINE_MIRROR="$mirror"
                    ALPINE_TARBALL_URL="${mirror}/v${ALPINE_SERIES}/releases/${ALPINE_ARCH}/${name}"
                    ok=1
                    break
                fi
            done
            [ "$ok" = 1 ] || log_error "failed to download minirootfs from all mirrors"
        fi
    fi
    verify_alpine_tarball
    log_success "Alpine minirootfs ready: $(du -h "$ALPINE_TARBALL_PATH" | cut -f1)"
}

# Official .sha256 sidecar first; same tarball mirror if official is down;
# remaining mirrors only after that. Never skip verification.
verify_alpine_tarball() {
    local sidecar="$CACHE_DIR/${ALPINE_TARBALL_NAME}.sha256"
    local rel="v${ALPINE_SERIES}/releases/${ALPINE_ARCH}/${ALPINE_TARBALL_NAME}.sha256"
    local official_url="${ALPINE_OFFICIAL}/${rel}"
    local expected actual mirror fetched=0
    log_info "fetching sha256 sidecar from ${official_url}"
    if curl_get_sidecar "$sidecar" "$official_url"; then
        fetched=1
    else
        log_warning "official sha256 host unreachable; trying tarball mirror ${ALPINE_MIRROR}"
        if curl_get_sidecar "$sidecar" "${ALPINE_MIRROR}/${rel}"; then
            fetched=1
        else
            for mirror in "${ALPINE_MIRRORS[@]}"; do
                [ "$mirror" = "$ALPINE_OFFICIAL" ] && continue
                [ "$mirror" = "$ALPINE_MIRROR" ] && continue
                log_warning "trying sha256 sidecar on ${mirror}"
                if curl_get_sidecar "$sidecar" "${mirror}/${rel}"; then
                    fetched=1
                    break
                fi
            done
        fi
    fi
    [ "$fetched" = 1 ] \
        || log_error "failed to download ${ALPINE_TARBALL_NAME}.sha256 from official host and all mirrors"
    expected="$(awk 'NF { print $1; exit }' "$sidecar")"
    [[ "$expected" =~ ^[0-9a-fA-F]{64}$ ]] \
        || log_error "invalid sha256 sidecar (expected 64 hex chars): $sidecar"
    if command -v shasum >/dev/null 2>&1; then
        actual="$(shasum -a 256 "$ALPINE_TARBALL_PATH" | awk '{ print $1 }')"
    else
        actual="$(sha256sum "$ALPINE_TARBALL_PATH" | awk '{ print $1 }')"
    fi
    if [ "${actual}" != "${expected}" ]; then
        rm -f "$ALPINE_TARBALL_PATH"
        log_error "minirootfs sha256 mismatch (got ${actual}, expected ${expected})"
    fi
    log_success "minirootfs sha256 verified"
}

extract_minirootfs() {
    ALPINE_TREE="$CACHE_DIR/alpine-tree"
    rm -rf "$ALPINE_TREE"
    mkdir -p "$ALPINE_TREE"
    tar -xzf "$ALPINE_TARBALL_PATH" -C "$ALPINE_TREE"
    log_success "extracted minirootfs to $ALPINE_TREE"
}

install_apks() {
    # Use the same package transaction for fresh images and in-place repairs.
    # The minirootfs world is left intact; apk adds our explicit packages.
    local mirror installed=0
    for mirror in "${ALPINE_MIRRORS[@]}"; do
        "$ISH" -f "$FAKEFS_OUT" /bin/sh -c '
            printf "%s/v%s/main\n%s/v%s/community\n" "$1" "$2" "$1" "$2" > /etc/apk/repositories
        ' sh "$mirror" "$ALPINE_SERIES"
        if "$ISH" -f "$FAKEFS_OUT" /bin/sh -c "$(cat "$SCRIPT_DIR/overlay/usr/local/bin/kelivo-repair-rootfs")"; then
            installed=1
            break
        fi
        log_warning "apk installation failed with $mirror"
    done
    [ "$installed" = 1 ] || log_error "apk installation failed on all mirrors"
    "$ISH" -f "$FAKEFS_OUT" /bin/sh -c '
        set -eu
        printf "%s/v%s/main\n%s/v%s/community\n" "$1" "$2" "$1" "$2" > /etc/apk/repositories
        plan=$(apk --no-network add --simulate musl)
        printf "%s\n" "$plan"
        ! printf "%s\n" "$plan" | grep -q Purging
    ' sh "$ALPINE_OFFICIAL" "$ALPINE_SERIES"
    log_success "apk packages installed and verified"
}

configure_tree() {
    local root="$ALPINE_TREE"
    mkdir -p "$root"/{dev,proc,sys,tmp,run,root,home,workspace,chat,skills}

    cat > "$root/etc/resolv.conf" << 'EOF'
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF

    cat > "$root/etc/apk/repositories" << EOF
https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_SERIES}/main
https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_SERIES}/community
EOF

    if [ -f "$root/etc/passwd" ]; then
        # apk installs bash before the image is published.
        local shell="/bin/bash"
        python3 - "$root/etc/passwd" "$shell" << 'PY'
import sys
path, shell = sys.argv[1], sys.argv[2]
lines = open(path).read().splitlines()
out = []
for line in lines:
    if line.startswith("root:"):
        parts = line.split(":")
        parts[-1] = shell
        line = ":".join(parts)
    out.append(line)
open(path, "w").write("\n".join(out) + "\n")
PY
    fi

    # Shell defaults live in overlay/etc/profile and profile.d/kelivo.sh.
    # The kernel applies them at every boot, including to installed rootfses.

    # PEP 668: allow pip in this embedded rootfs (also mirrored by overlay pip.conf).
    find "$root/usr/lib" -name EXTERNALLY-MANAGED -delete 2>/dev/null || true

    # Keep the official /etc/apk/world, including alpine-release. apk will
    # extend it when it installs the additional packages in the fakefs.

    log_success "rootfs tree configured"
}

ensure_host_tools() {
    if [ ! -x "$BUILD_DIR/fakefsify" ] || [ ! -x "$BUILD_DIR/ish" ]; then
        "$SCRIPT_DIR/build_ish.sh"
    fi
    FAKEFSIFY="$BUILD_DIR/fakefsify"
    ISH="$BUILD_DIR/ish"
    [ -x "$FAKEFSIFY" ] && [ -x "$ISH" ] || log_error "iSH host tools missing"
}

create_fakefs() {
    local configured_tar="$CACHE_DIR/alpine-configured.tar.gz"
    local out="$CACHE_DIR/alpine-fakefs"
    log_info "re-packing configured tree for fakefsify..."
    rm -f "$configured_tar"
    tar -czf "$configured_tar" -C "$ALPINE_TREE" .
    rm -rf "$out"
    mkdir -p "$CACHE_DIR"
    log_info "converting to fakefs (data/ + meta.db)..."
    "$FAKEFSIFY" "$configured_tar" "$out"
    [ -d "$out/data" ] && [ -f "$out/meta.db" ] || log_error "fakefsify did not produce data/ + meta.db"
    [ -e "$out/data/bin/sh" ] || log_error "fakefs missing data/bin/sh"
    FAKEFS_OUT="$out"
    log_success "fakefs created"
}

write_version_and_zip() {
    local version="alpine-${ALPINE_FULL_VERSION}-${ROOTFS_REVISION}"
    printf '%s\n' "$version" > "$FAKEFS_OUT/.version"
    printf '%s\n' "$version" > "$FAKEFS_OUT/VERSION"
    printf '%s\n' "aarch64" > "$FAKEFS_OUT/.arch"
    mkdir -p "$OUTPUT_DIR"
    printf '%s\n' "$version" > "$OUTPUT_DIR/VERSION"

    local zip_path="$OUTPUT_DIR/alpine-rootfs.zip"
    rm -f "$zip_path"
    # Zip contents at the archive root (data/, meta.db, .version, .arch, VERSION).
    (
        cd "$FAKEFS_OUT"
        zip -r "$zip_path" . \
            -x "*.db-shm" \
            -x "*.db-wal" \
            > /dev/null
    )
    [ -f "$zip_path" ] || log_error "failed to create $zip_path"
    log_success "VERSION=$version"
    log_success "ZIP $(du -h "$zip_path" | cut -f1) → $zip_path"
}

print_summary() {
    echo ""
    echo "============================================================"
    echo -e "${GREEN}Alpine fakefs rootfs ready${NC}"
    echo "============================================================"
    echo "  Alpine:  ${ALPINE_FULL_VERSION} ${ALPINE_ARCH}"
    echo "  VERSION: $(cat "$OUTPUT_DIR/VERSION")"
    echo "  ZIP:     $(du -h "$OUTPUT_DIR/alpine-rootfs.zip" | cut -f1)"
    echo "  data:    $(du -sh "$FAKEFS_OUT/data" | cut -f1)"
    echo "  meta.db: $(du -h "$FAKEFS_OUT/meta.db" | cut -f1)"
    echo "============================================================"
}

clean() {
    rm -rf "$CACHE_DIR" "$OUTPUT_DIR/alpine-rootfs" "$OUTPUT_DIR/alpine-rootfs.zip"
    log_success "clean completed"
}

main() {
    echo ""
    echo "============================================================"
    echo "  Kelivo Alpine aarch64 fakefs rootfs"
    echo "  Series: ${ALPINE_SERIES}.x (${ALPINE_ARCH})"
    echo "============================================================"
    echo ""
    check_prerequisites
    download_alpine
    extract_minirootfs
    configure_tree
    ensure_host_tools
    create_fakefs
    install_apks
    write_version_and_zip
    print_summary
}

case "${1:-}" in
    clean) clean; exit 0 ;;
    --help|-h)
        echo "Usage: $0 [version|clean]"
        echo "  version   Alpine series (default: 3.21) — patch defaults to 3"
        echo "  clean     Remove cache and generated zip"
        exit 0
        ;;
    3.*)
        ALPINE_SERIES="$1"
        main
        ;;
    *)
        main
        ;;
esac
