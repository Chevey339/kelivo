#!/usr/bin/env bash
# Verify startup, GStreamer and GTK input methods without host frontend packages.
# Usage: bash tool/test_appimage.sh Kelivo-<version>-<arch>.AppImage
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <AppImage>" >&2
  exit 1
fi

appimage="$(realpath "$1")"
gst_inspect="$(command -v gst-inspect-1.0)"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

docker run --rm -i \
  --mount "type=bind,src=$appimage,dst=/tmp/Kelivo.AppImage,readonly" \
  --mount "type=bind,src=$gst_inspect,dst=/tmp/gst-inspect-1.0,readonly" \
  --mount "type=bind,src=$script_dir/check_appimage_gtk.py,dst=/tmp/check_appimage_gtk.py,readonly" \
  ubuntu:22.04 bash -s <<'CONTAINER'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
# Do not install GStreamer or fcitx/IBus frontends here: host copies would hide
# missing bundled libraries. Python drives the GTK loader through ctypes.
# GTK's libepoxy loads libGLESv2.so.2 dynamically; Mesa/EGL alone do not provide it.
apt-get install -y --no-install-recommends \
  ca-certificates libgtk-3-0 libgl1-mesa-dri libegl1 libgles2 libasound2 \
  dbus-x11 xvfb xauth xdotool python3

cd /tmp
./Kelivo.AppImage --appimage-extract >/dev/null
# A relocated path with spaces catches caches tied to the build or mount path.
mv squashfs-root 'relocated AppDir'
export APPDIR='/tmp/relocated AppDir'
export LIBGL_ALWAYS_SOFTWARE=1

# This helper comes from the build host, but all GStreamer libraries, codecs and
# the plugin scanner must come from the AppImage inside this clean container.
(
  export LD_LIBRARY_PATH="$APPDIR/usr/lib"
  # shellcheck disable=SC1091
  source "$APPDIR/apprun-hooks/linuxdeploy-plugin-gstreamer.sh"
  test -x "$GST_PLUGIN_SCANNER_1_0"
  scanner_dependencies="$(ldd "$GST_PLUGIN_SCANNER_1_0")"
  if grep -q 'not found' <<<"$scanner_dependencies"; then
    echo "$scanner_dependencies" >&2
    exit 1
  fi
  for element in appsrc appsink playbin decodebin audiopanorama autoaudiosink; do
    /tmp/gst-inspect-1.0 "$element" >/dev/null
  done
)

# The hook must preserve both an unset backend and an explicit Wayland choice.
for backend in unset wayland x11; do
  (
    if [[ "$backend" == unset ]]; then
      unset GDK_BACKEND
    else
      export GDK_BACKEND="$backend"
    fi
    export GTK_IM_MODULE=fcitx
    # shellcheck disable=SC1091
    source "$APPDIR/apprun-hooks/kelivo-gtk-immodules.sh"
    test "${GDK_BACKEND-unset}" = "$backend"
    test "$GTK_IM_MODULE" = fcitx
  )
done

# Xvfb supplies a display only for this loader check; the shipped hook never
# selects a display backend. No running input-method daemon is needed to load
# and instantiate its GTK frontend.
xvfb-run -a dbus-run-session -- bash -s <<'GTK_TEST'
set -euo pipefail
# Use only the production hook's paths; injecting usr/lib here would hide
# modules whose dependencies are not reachable during a normal AppRun launch.
# shellcheck disable=SC1091
source "$APPDIR/apprun-hooks/kelivo-gtk-immodules.sh"
for context in fcitx ibus xim; do
  GTK_IM_MODULE="$context" LD_BIND_NOW=1 NO_AT_BRIDGE=1 \
    python3 /tmp/check_appimage_gtk.py
done
GTK_TEST

xvfb-run -a dbus-run-session -- bash -s <<'DISPLAY_TEST'
set -euo pipefail
# Launch the actual artifact without an injected library/plugin search path.
/tmp/Kelivo.AppImage --appimage-extract-and-run >/tmp/kelivo.log 2>&1 &
app_pid=$!
trap 'kill "$app_pid" 2>/dev/null || true' EXIT

# Require an actual window and keep checking for early exits for at least 10s.
for ((attempt = 1; attempt <= 30; attempt++)); do
  sleep 1
  if ! kill -0 "$app_pid" 2>/dev/null; then
    cat /tmp/kelivo.log
    echo "Kelivo exited before the AppImage startup check completed" >&2
    exit 1
  fi
  if ((attempt >= 10)) && xdotool search --onlyvisible --class '[Kk]elivo' >/dev/null; then
    echo "AppImage startup, GStreamer and GTK input-method checks passed"
    exit 0
  fi
done

cat /tmp/kelivo.log
echo "Kelivo did not show a window within 30 seconds" >&2
exit 1
DISPLAY_TEST
CONTAINER
