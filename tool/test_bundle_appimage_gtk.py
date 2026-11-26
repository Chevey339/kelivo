"""Portable packaging regressions; real GTK loading is checked by test_appimage.sh."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("bundle_appimage_gtk.sh")


class BundleGtkTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="kelivo gtk test ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.app_dir = self.root / "build AppDir"
        self.app_dir.mkdir()
        self.libdir = self.root / "host" / "lib" / "test-linux-gnu"
        self.modules = self.libdir / "gtk-3.0" / "3.0.0" / "immodules"
        self.modules.mkdir(parents=True)
        self.contexts = {
            "im-fcitx5.so": "fcitx",
            "im-ibus.so": "ibus",
            "im-xim.so": "xim",
            "im-wayland.so": "wayland",
        }
        for module, context in self.contexts.items():
            (self.modules / module).write_text(context)
        self.bin_dir = self.root / "bin"
        self.bin_dir.mkdir()
        self.write_executable(
            self.bin_dir / "pkg-config",
            "import os, sys\n"
            "print({'--variable=libdir': os.environ['TEST_GTK_LIBDIR'], "
            "'--variable=gtk_binary_version': '3.0.0'}[sys.argv[1]])\n",
        )
        self.write_executable(
            self.bin_dir / "gtk-query-immodules-3.0",
            "from pathlib import Path\nimport sys\n"
            "for module in sys.argv[1:]:\n"
            "    context = Path(module).read_text()\n"
            "    if not context:\n        continue\n"
            # GTK's print_escaped appends a space after every quoted value.
            "    print(f'\"{module}\" ')\n"
            "    print(f'\"{context}\" \"Test context\" \"test\" \"/usr/share/locale\" \"*\" ')\n"
            "    print()\n",
        )
        self.env = {
            **os.environ,
            "PATH": f"{self.bin_dir}{os.pathsep}{os.environ['PATH']}",
            "TEST_GTK_LIBDIR": str(self.libdir),
        }

    def write_executable(self, path, body):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("#!/usr/bin/env python3\n" + body)
        path.chmod(0o755)

    def bundle(self):
        return subprocess.run(
            ["bash", str(SCRIPT), str(self.app_dir)],
            env=self.env,
            capture_output=True,
            text=True,
        )

    def test_bundles_modules_and_relocatable_cache(self):
        result = self.bundle()
        self.assertEqual(result.returncode, 0, result.stderr)
        destination = self.app_dir / "usr/lib/gtk-3.0/3.0.0"
        cache = (destination / "immodules.cache").read_text()
        for module, context in self.contexts.items():
            self.assertEqual((destination / "immodules" / module).read_text(), context)
            self.assertIn(f'"{module}"\n', cache)
            self.assertIn(f'"{context}" "Test context"', cache)
        self.assertNotIn(str(self.root), cache)

        relocated = self.root / "relocated mounted AppDir"
        shutil.move(self.app_dir, relocated)
        hook = relocated / "apprun-hooks/kelivo-gtk-immodules.sh"
        for backend in (None, "wayland", "x11"):
            with self.subTest(backend=backend):
                env = {**self.env, "APPDIR": str(relocated), "GTK_IM_MODULE": "ibus"}
                env.pop("GDK_BACKEND", None)
                env.pop("LD_LIBRARY_PATH", None)
                if backend is not None:
                    env["GDK_BACKEND"] = backend
                    env["LD_LIBRARY_PATH"] = "/existing/libs"
                result = subprocess.run(
                    [
                        "bash", "-eu", "-c",
                        'source "$1"; python3 -c "import json, os; print(json.dumps(dict(os.environ)))"',
                        "check-hook", str(hook),
                    ],
                    env=env, capture_output=True, text=True, check=True,
                )
                actual = json.loads(result.stdout)
                self.assertEqual(actual.get("GDK_BACKEND"), backend)
                self.assertEqual(actual["GTK_IM_MODULE"], "ibus")
                self.assertTrue(Path(actual["GTK_IM_MODULE_FILE"]).is_file())
                expected = (
                    f"{relocated / 'usr/lib'}:"
                    f"{relocated / 'usr/lib/gtk-3.0/3.0.0/immodules'}"
                )
                if backend is not None:
                    expected += ":/existing/libs"
                self.assertEqual(actual["LD_LIBRARY_PATH"], expected)

    def test_rejects_missing_frontends(self):
        for module, context in self.contexts.items():
            if module == "im-wayland.so":
                continue
            with self.subTest(module=module):
                (self.modules / module).unlink()
                result = self.bundle()
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(f"Missing GTK input module: {self.modules / module}", result.stderr)
                (self.modules / module).write_text(context)

    def test_rejects_missing_context_registration(self):
        (self.modules / "im-fcitx5.so").write_text("")
        result = self.bundle()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("GTK input context was not registered: fcitx", result.stderr)

    def test_rejects_query_load_failure(self):
        self.write_executable(
            self.bin_dir / "gtk-query-immodules-3.0", "import sys\nsys.exit(1)\n"
        )
        result = self.bundle()
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.app_dir / "apprun-hooks/kelivo-gtk-immodules.sh").exists())

    def test_finds_ubuntu_query_tool_outside_path(self):
        tool = self.bin_dir / "gtk-query-immodules-3.0"
        destination = self.libdir / "libgtk-3-0" / tool.name
        destination.parent.mkdir()
        tool.rename(destination)
        result = self.bundle()
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
