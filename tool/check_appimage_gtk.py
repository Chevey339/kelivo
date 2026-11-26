#!/usr/bin/env python3
"""Exercise GTK's real input-context loader in the clean AppImage container."""

import ctypes
import os
from pathlib import Path
import sys


def main():
    app_dir = Path(os.environ["APPDIR"]).resolve()
    context_id = os.environ["GTK_IM_MODULE"]
    module, client_library = {
        "fcitx": ("im-fcitx5.so", "libFcitx5GClient.so"),
        "ibus": ("im-ibus.so", "libibus-1.0.so"),
        "xim": ("im-xim.so", None),
    }[context_id]

    # The process starts with the packaged library paths and LD_BIND_NOW=1.
    # Use GTK's public API, so this tests the cache and loader as well as ELF
    # dependencies; merely dlopening a module would miss a broken cache.
    gtk = ctypes.CDLL("libgtk-3.so.0")
    glib = ctypes.CDLL("libglib-2.0.so.0")
    glib.g_log_set_fatal_mask.argtypes = [ctypes.c_char_p, ctypes.c_int]
    glib.g_log_set_fatal_mask(b"Gtk", (1 << 2) | (1 << 3) | (1 << 4))
    gtk.gtk_init_check.argtypes = [ctypes.c_void_p, ctypes.c_void_p]
    gtk.gtk_init_check.restype = ctypes.c_int
    if not gtk.gtk_init_check(None, None):
        raise RuntimeError("GTK could not connect to the test display")

    gtk.gtk_im_multicontext_new.restype = ctypes.c_void_p
    context = gtk.gtk_im_multicontext_new()
    gtk.gtk_im_context_get_preedit_string.argtypes = [
        ctypes.c_void_p,
        ctypes.POINTER(ctypes.c_void_p),
        ctypes.c_void_p,
        ctypes.c_void_p,
    ]
    preedit = ctypes.c_void_p()
    gtk.gtk_im_context_get_preedit_string(context, ctypes.byref(preedit), None, None)
    glib.g_free.argtypes = [ctypes.c_void_p]
    glib.g_free(preedit)

    # A simple-context fallback must not pass. Also reject modules or their
    # GTK/GLib/client libraries accidentally supplied by the host distribution.
    mapped_files = set()
    for line in Path("/proc/self/maps").read_text().splitlines():
        fields = line.split(maxsplit=5)
        if len(fields) == 6 and fields[5].startswith("/"):
            mapped_files.add(Path(fields[5]).resolve())
    required = [
        module,
        "libgtk-3.so",
        "libgdk-3.so",
        "libglib-2.0.so",
        "libgobject-2.0.so",
        "libgio-2.0.so",
        "libgmodule-2.0.so",
    ]
    if client_library:
        required.append(client_library)
    for name in required:
        matches = [path for path in mapped_files if path.name.startswith(name)]
        if not matches or any(app_dir not in path.parents for path in matches):
            raise RuntimeError(f"{context_id}: {name} not loaded from AppImage: {matches}")
    print(f"GTK {context_id} context and bundled dependencies loaded successfully")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        sys.exit(str(error))
