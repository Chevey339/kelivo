#!/bin/bash
set -euo pipefail

# ============================================================================
# Alpine Linux aarch64 rootfs for the Kelivo iOS Workspace (iSH fakefs)
# ============================================================================
# Downloads Alpine minirootfs (aarch64), pre-installs bash + coreutils by
# extracting official APK packages (chroot-free — no qemu, no apk --root),
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
ROOTFS_REVISION="r4"
# Extra packages extracted into the minirootfs before fakefsify.
# musl is included so GNU coreutils matches the same branch libc (r3 skipped
# it and left minirootfs musl 1.2.5-r9 against APKINDEX musl 1.2.5-r11).
APK_PACKAGES=(musl bash coreutils)

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

fetch_apkindex() {
    local repo="$1" dest_tar="$2" dest_dir="$3"
    local url="${ALPINE_MIRROR}/v${ALPINE_SERIES}/${repo}/${ALPINE_ARCH}/APKINDEX.tar.gz"
    log_info "fetching APKINDEX from $url"
    if ! curl_get "$dest_tar" "$url"; then
        local mirror ok=0
        for mirror in "${ALPINE_MIRRORS[@]}"; do
            [ "$mirror" = "$ALPINE_MIRROR" ] && continue
            if curl_get "$dest_tar" "${mirror}/v${ALPINE_SERIES}/${repo}/${ALPINE_ARCH}/APKINDEX.tar.gz"; then
                ok=1
                break
            fi
        done
        [ "$ok" = 1 ] || log_error "failed to download ${repo} APKINDEX from all mirrors"
    fi
    rm -rf "$dest_dir"
    mkdir -p "$dest_dir"
    tar -xzf "$dest_tar" -C "$dest_dir"
    [ -f "$dest_dir/APKINDEX" ] || log_error "${repo} APKINDEX missing after extract"
}

# Download official APKs + runtime deps and extract them into the rootfs tree
# (APK = gzip tarball). Avoids qemu/chroot; matches the "chroot-free" request.
# Every package (including musl) comes from v${ALPINE_SERIES}/main + community.
install_apks() {
    log_info "minirootfs tarball: $ALPINE_TARBALL_URL"
    log_info "apk repos: ${ALPINE_MIRROR}/v${ALPINE_SERIES}/main/${ALPINE_ARCH} + ${ALPINE_MIRROR}/v${ALPINE_SERIES}/community/${ALPINE_ARCH}"
    fetch_apkindex main "$CACHE_DIR/APKINDEX-main.tar.gz" "$CACHE_DIR/apkindex-main"
    fetch_apkindex community "$CACHE_DIR/APKINDEX-community.tar.gz" "$CACHE_DIR/apkindex-community"

    python3 - "$CACHE_DIR/apkindex-main/APKINDEX" "$CACHE_DIR/apkindex-community/APKINDEX" \
        "$CACHE_DIR/apks" "$ALPINE_TREE" \
        "${ALPINE_SERIES}" "${ALPINE_ARCH}" \
        "${APK_PACKAGES[@]}" -- \
        "${ALPINE_MIRRORS[@]}" << 'PY'
import os, subprocess, sys, tarfile

main_index, comm_index = sys.argv[1], sys.argv[2]
dest_dir, rootfs = sys.argv[3], sys.argv[4]
series, arch = sys.argv[5], sys.argv[6]
sep = sys.argv.index("--")
wanted = sys.argv[7:sep]
mirrors = sys.argv[sep + 1:]

# Parse APKINDEX (blank-line separated records, P:/V:/D:/p: fields).
# Main wins when the same name exists in community.
pkgs = {}
provides = {}

def load_index(path, repo):
    cur = {}
    def flush():
        if not cur.get("P"):
            return
        name = cur["P"]
        if name in pkgs and pkgs[name].get("repo") == "main":
            return
        cur["repo"] = repo
        pkgs[name] = dict(cur)
        for prov in cur.get("p") or []:
            token = prov.split("=")[0].split(">")[0].split("<")[0]
            if token not in provides or pkgs.get(provides[token], {}).get("repo") != "main":
                provides[token] = name
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.rstrip("\n")
            if not line:
                flush()
                cur = {}
                continue
            if ":" in line:
                k, v = line[0], line[2:]
                if k == "P":
                    cur["P"] = v
                elif k == "V":
                    cur["V"] = v
                elif k == "D":
                    cur["D"] = v.split()
                elif k == "p":
                    cur["p"] = v.split()
    flush()

load_index(main_index, "main")
load_index(comm_index, "community")

# Keep busybox from minirootfs. Always install musl from this APKINDEX so
# coreutils and libc are a consistent v{series} set (renameat2, etc.).
already = {"busybox", "/bin/sh"}
if os.path.exists(os.path.join(rootfs, "bin", "busybox")):
    already.add("busybox")

for token, pkg in list(provides.items()):
    if pkg in already:
        already.add(token)

def dep_name(token):
    token = token.split("=")[0].split(">")[0].split("<")[0].split("~")[0]
    if token.startswith("pc:") or token.startswith("cmd:"):
        return None
    if token.startswith("so:"):
        if token in already:
            return None
        mapped = provides.get(token)
        if mapped is None:
            print(f"warning: no APKINDEX provider for {token!r}", file=sys.stderr)
        return mapped
    return token

# Resolve package names, including so: runtime libraries (coreutils needs
# libacl/libattr/libutmps; skipping so: left those binaries unusable).
need = []
seen = set()

def add_pkg(name):
    if name in already or name in seen:
        return
    if name not in pkgs:
        print(f"warning: APKINDEX has no package {name!r}", file=sys.stderr)
        return
    seen.add(name)
    for dep in pkgs[name].get("D") or []:
        dn = dep_name(dep)
        if dn:
            add_pkg(dn)
    need.append(name)

for w in wanted:
    add_pkg(w)

os.makedirs(dest_dir, exist_ok=True)

def curl_download(url, dest):
    for _ in range(3):
        r = subprocess.run(
            [
                "curl", "-L", "--fail", "--retry", "2", "--retry-delay", "1",
                "--connect-timeout", "20", "--max-time", "180",
                "-A", "kelivo-rootfs-builder/1.0", "-o", dest, url,
            ],
            check=False,
        )
        if r.returncode == 0 and os.path.isfile(dest) and os.path.getsize(dest) > 32:
            return True
    return False

def apk_member_name(raw):
    name = raw.replace("\\", "/")
    while name.startswith("./"):
        name = name[2:]
    return name.lstrip("/")

def is_apk_control(name):
    base = name.rsplit("/", 1)[-1]
    if base in {".PKGINFO", "PKGINFO", ".trigger", "trigger"}:
        return True
    if base.startswith(".SIGN.") or base.startswith("SIGN."):
        return True
    if base.startswith(".post-") or base.startswith(".pre-"):
        return True
    if base in {
        "post-install", "pre-install", "post-upgrade", "pre-upgrade",
        "post-deinstall", "pre-deinstall",
    }:
        return True
    return False

def extract_apk(apk_path, dest):
    with tarfile.open(apk_path, "r:gz") as tf:
        for m in tf.getmembers():
            name = apk_member_name(m.name)
            if not name or is_apk_control(name):
                continue
            # zip-slip
            target = os.path.normpath(os.path.join(dest, name))
            if not target.startswith(os.path.abspath(dest) + os.sep) and target != os.path.abspath(dest):
                raise SystemExit(f"unsafe apk path {name!r}")
            if m.isdir():
                os.makedirs(target, exist_ok=True)
            elif m.issym():
                os.makedirs(os.path.dirname(target), exist_ok=True)
                if os.path.lexists(target):
                    os.unlink(target)
                os.symlink(m.linkname, target)
            elif m.isreg():
                os.makedirs(os.path.dirname(target), exist_ok=True)
                if os.path.lexists(target):
                    os.unlink(target)
                src = tf.extractfile(m)
                if src is None:
                    continue
                with open(target, "wb") as out:
                    out.write(src.read())
                os.chmod(target, m.mode & 0o7777)

versions = []
for name in need:
    rec = pkgs[name]
    fname = f"{rec['P']}-{rec['V']}.apk"
    dest = os.path.join(dest_dir, fname)
    repo = rec.get("repo") or "main"
    print(f"apk {fname} ({repo})", flush=True)
    if not (os.path.isfile(dest) and os.path.getsize(dest) > 32):
        ok = False
        for mirror in mirrors:
            url = f"{mirror.rstrip('/')}/v{series}/{repo}/{arch}/{fname}"
            if curl_download(url, dest):
                ok = True
                break
        if not ok:
            raise SystemExit(f"failed to download {fname} from v{series}/{repo}")
    extract_apk(dest, rootfs)
    versions.append(f"{rec['P']}-{rec['V']} {repo}")

print(f"installed {len(need)} packages: {', '.join(need)}", flush=True)
print("apk versions:", "; ".join(versions), flush=True)
manifest = os.path.join(dest_dir, "apk-versions.txt")
with open(manifest, "w", encoding="utf-8") as out:
    out.write("\n".join(versions) + "\n")
PY
    log_success "pre-installed ${APK_PACKAGES[*]} (and deps) into minirootfs"
    if [ -f "$CACHE_DIR/apks/apk-versions.txt" ]; then
        log_info "apk versions:"
        cat "$CACHE_DIR/apks/apk-versions.txt"
    fi
    # APK tarballs store control files at the archive root; strip any residue.
    rm -f "$ALPINE_TREE"/.PKGINFO "$ALPINE_TREE"/PKGINFO \
          "$ALPINE_TREE"/.trigger "$ALPINE_TREE"/trigger
    rm -f "$ALPINE_TREE"/.SIGN.* "$ALPINE_TREE"/SIGN.* \
          "$ALPINE_TREE"/.post-* "$ALPINE_TREE"/post-* \
          "$ALPINE_TREE"/.pre-* "$ALPINE_TREE"/pre-*
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
        local shell="/bin/sh"
        [ -e "$root/bin/bash" ] && shell="/bin/bash"
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

    if [ -f "$root/etc/profile" ] && ! grep -q "Kelivo Workspace" "$root/etc/profile"; then
        cat >> "$root/etc/profile" << 'EOF'

# Kelivo Workspace
export PS1='\u@kelivo:\w\$ '
export TERM=xterm-256color
export HOME=/root
export LANG=C.UTF-8
export CHARSET=UTF-8
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
EOF
    fi

    # PEP 668: allow pip in this embedded rootfs (also mirrored by overlay pip.conf).
    find "$root/usr/lib" -name EXTERNALLY-MANAGED -delete 2>/dev/null || true

    # World file so `apk` knows bash/coreutils are installed if the user runs it later.
    if [ -d "$root/etc/apk" ]; then
        {
            echo "busybox"
            echo "alpine-baselayout"
            echo "alpine-keys"
            echo "apk-tools"
            echo "libc-utils"
            printf '%s\n' "${APK_PACKAGES[@]}"
        } | sort -u > "$root/etc/apk/world"
    fi

    log_success "rootfs tree configured"
}

ensure_fakefsify() {
    if [ -x "$BUILD_DIR/fakefsify" ]; then
        FAKEFSIFY="$BUILD_DIR/fakefsify"
        return
    fi
    if [ -x "$ISH_DIR/build-native/tools/fakefsify" ]; then
        mkdir -p "$BUILD_DIR"
        cp "$ISH_DIR/build-native/tools/fakefsify" "$BUILD_DIR/fakefsify"
        FAKEFSIFY="$BUILD_DIR/fakefsify"
        return
    fi
    log_info "fakefsify missing — running build_ish.sh first"
    "$SCRIPT_DIR/build_ish.sh"
    [ -x "$BUILD_DIR/fakefsify" ] || log_error "build_ish.sh did not produce fakefsify"
    FAKEFSIFY="$BUILD_DIR/fakefsify"
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
    install_apks
    configure_tree
    ensure_fakefsify
    create_fakefs
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
