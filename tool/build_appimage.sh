#!/usr/bin/env bash
# Package a Flutter Linux bundle, including its native runtime dependencies.
# Usage: bash tool/build_appimage.sh build/linux/x64/release/bundle "$VERSION"
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <Flutter bundle directory> <version>" >&2
  exit 1
fi

bundle_dir="$(realpath "$1")"
version="$2"
arch="$(uname -m)"
case "$arch" in
  x86_64|aarch64) ;;
  *) echo "Unsupported AppImage architecture: $arch" >&2; exit 1 ;;
esac

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output="$PWD/Kelivo-${version}-${arch}.AppImage"
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT
app_dir="$work_dir/AppDir"

mkdir -p "$app_dir/usr/bin"
cp -a "$bundle_dir/." "$app_dir/usr/bin/"
# linuxdeploy expects libraries in usr/lib; Flutter also resolves lib/libapp.so
# relative to its executable. Keep that path without duplicating the libraries.
mv "$app_dir/usr/bin/lib" "$app_dir/usr/lib"
ln -s ../lib "$app_dir/usr/bin/lib"

cat > "$work_dir/kelivo.desktop" <<'DESKTOP'
[Desktop Entry]
Name=Kelivo
Exec=kelivo
Icon=kelivo
Type=Application
Categories=Utility;
DESKTOP
cp "$repo_root/assets/app_icon.png" "$work_dir/kelivo.png"

curl -fL --retry 3 -o "$work_dir/linuxdeploy.AppImage" \
  "https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-${arch}.AppImage"
curl -fL --retry 3 -o "$work_dir/appimagetool.AppImage" \
  "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-${arch}.AppImage"
# Pin the plugin source so changes to its copy rules require an explicit update.
curl -fL --retry 3 -o "$work_dir/linuxdeploy-plugin-gstreamer.sh" \
  "https://raw.githubusercontent.com/linuxdeploy/linuxdeploy-plugin-gstreamer/2a2e67491c32995a3f279ad0ecbe77abd512b42a/linuxdeploy-plugin-gstreamer.sh"
chmod +x "$work_dir/"*.AppImage "$work_dir/linuxdeploy-plugin-gstreamer.sh"

# Run the packaging tools without requiring a FUSE mount in CI. Preserve the
# release binaries produced by Flutter instead of stripping them a second time.
export APPIMAGE_EXTRACT_AND_RUN=1
export NO_STRIP=1
export ARCH="$arch"
export VERSION="$version"

# This scans every ELF in the AppDir, including Flutter plugins and native
# assets. The plugin also bundles GStreamer's dynamically loaded codecs and
# gst-plugin-scanner, and installs the AppRun hook that selects those copies.
"$work_dir/linuxdeploy.AppImage" --appdir "$app_dir" \
  --desktop-file "$work_dir/kelivo.desktop" \
  --icon-file "$work_dir/kelivo.png" \
  --plugin gstreamer

# The GStreamer plugin copies its helper executables after its own dependency
# scan. Include their dependencies too before producing the final artifact.
"$work_dir/linuxdeploy.AppImage" --appdir "$app_dir"

# The maintained appimagetool uses type2-runtime, which bundles FUSE support.
"$work_dir/appimagetool.AppImage" "$app_dir" "$output"
echo "Created $output"
