#!/usr/bin/env bash
# Bundle GTK3 input methods against the same libraries as the AppImage.
# Run before linuxdeploy so it also copies and patches the modules' dependencies.
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <AppDir>" >&2
  exit 1
fi

app_dir="$(realpath "$1")"
gtk_libdir="$(pkg-config --variable=libdir gtk+-3.0)"
gtk_version="$(pkg-config --variable=gtk_binary_version gtk+-3.0)"
modules_dir="$gtk_libdir/gtk-3.0/$gtk_version/immodules"
modules_relative="usr/lib/gtk-3.0/$gtk_version/immodules"
target_dir="$app_dir/$modules_relative"
query="$(command -v gtk-query-immodules-3.0 || true)"
if [[ -z "$query" ]]; then
  query="$gtk_libdir/libgtk-3-0/gtk-query-immodules-3.0"
fi

# These frontends are separate packages; GTK development files alone are not
# sufficient. Fail the build instead of publishing an ASCII-only AppImage.
for module in im-fcitx5.so im-ibus.so im-xim.so; do
  if [[ ! -f "$modules_dir/$module" ]]; then
    echo "Missing GTK input module: $modules_dir/$module (install fcitx5-frontend-gtk3 and ibus-gtk3)" >&2
    exit 1
  fi
done

mkdir -p "$target_dir" "$app_dir/apprun-hooks"
# Include GTK's other contexts too, including the native Wayland context.
cp -L "$modules_dir/"*.so "$target_dir/"
"$query" "$target_dir/"*.so > "$target_dir/../immodules.cache"
# GTK passes these names to dlopen. Resolve them through the hook's module
# search path, rather than retaining absolute paths into the build directory.
sed -E 's@^".*/([^/"]+\.so)"[[:space:]]*$@"\1"@' "$target_dir/../immodules.cache" > "$target_dir/../immodules.cache.tmp"
mv "$target_dir/../immodules.cache.tmp" "$target_dir/../immodules.cache"
for context in fcitx ibus xim; do
  if ! grep -q "^\"$context\" " "$target_dir/../immodules.cache"; then
    echo "GTK input context was not registered: $context" >&2
    exit 1
  fi
done

cat > "$app_dir/apprun-hooks/kelivo-gtk-immodules.sh" <<EOF
#!/usr/bin/env bash
export GTK_IM_MODULE_FILE="\$APPDIR/$modules_relative/../immodules.cache"
export LD_LIBRARY_PATH="\$APPDIR/usr/lib:\$APPDIR/$modules_relative\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
EOF
# Leave GTK_IM_MODULE and GDK_BACKEND to the user's desktop/session.
