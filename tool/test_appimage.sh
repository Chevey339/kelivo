#!/usr/bin/env bash
# Verify the published artifact on Ubuntu without system GStreamer libraries.
# Usage: bash tool/test_appimage.sh Kelivo-<version>-<arch>.AppImage
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <AppImage>" >&2
  exit 1
fi

appimage="$(realpath "$1")"
gst_inspect="$(command -v gst-inspect-1.0)"

docker run --rm -i \
  --mount "type=bind,src=$appimage,dst=/tmp/Kelivo.AppImage,readonly" \
  --mount "type=bind,src=$gst_inspect,dst=/tmp/gst-inspect-1.0,readonly" \
  ubuntu:22.04 bash -s <<'CONTAINER'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
# Desktop/display dependencies only. Installing GStreamer here would hide the
# missing-library regression this check is intended to catch.
apt-get install -y --no-install-recommends \
  ca-certificates libgtk-3-0 libgl1-mesa-dri libegl1 libasound2 \
  dbus-x11 xvfb xauth xdotool

cd /tmp
./Kelivo.AppImage --appimage-extract >/dev/null
export LIBGL_ALWAYS_SOFTWARE=1

# This helper comes from the build host, but all GStreamer libraries, codecs and
# the plugin scanner must come from the AppImage inside this clean container.
(
  export APPDIR=/tmp/squashfs-root
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
    echo "AppImage startup and GStreamer checks passed"
    exit 0
  fi
done

cat /tmp/kelivo.log
echo "Kelivo did not show a window within 30 seconds" >&2
exit 1
DISPLAY_TEST
CONTAINER
