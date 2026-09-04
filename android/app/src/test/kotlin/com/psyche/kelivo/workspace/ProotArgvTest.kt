package com.psyche.kelivo.workspace

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Test

class ProotArgvTest {
    @Test
    fun execArgvMatchesGoldenString() {
        val launch = ProotCommand.build(
            nativeLibDir = File("/nativelib"),
            rootfsDir = File("/data/rootfs"),
            tmpDir = File("/data/tmp"),
            binds = listOf(BindMount("/host/files", "/workspace")),
            cwd = "/workspace",
            command = "echo hello",
            env = linkedMapOf(
                "HOME" to "/root",
                "PATH" to "/bin",
            ),
            includeLibraryPath = true,
        )
        val golden =
            "/nativelib/libproot_exec.so --root-id --link2symlink --kill-on-exit " +
                "-r /data/rootfs -w /workspace -b /host/files:/workspace " +
                "-b /dev -b /proc -b /sys /usr/bin/env -i HOME=/root PATH=/bin " +
                "/bin/bash -lc " + ProotCommand.BASH_EVAL + " kelivo /workspace echo hello"
        assertEquals(golden, launch.argv.joinToString(" "))
        assertEquals("/data", launch.workingDirectory.absolutePath)
        assertEquals("/nativelib/libproot_loader.so", launch.processEnv["PROOT_LOADER"])
        assertEquals("/data/tmp", launch.processEnv["PROOT_TMP_DIR"])
        assertEquals("/data/tmp", launch.processEnv["TMPDIR"])
        assertEquals("/data/tmp:/nativelib", launch.processEnv["LD_LIBRARY_PATH"])
    }

    @Test
    fun ptyArgvUsesLoginShellAndTerm() {
        val launch = ProotCommand.build(
            nativeLibDir = File("/nativelib"),
            rootfsDir = File("/data/rootfs"),
            tmpDir = File("/data/tmp"),
            binds = emptyList(),
            cwd = "/root",
            command = null,
            env = linkedMapOf("HOME" to "/root"),
            includeLibraryPath = false,
        )
        assertEquals("/bin/bash", launch.argv[launch.argv.size - 2])
        assertEquals("-l", launch.argv.last())
        assertEquals("HOME=/root", launch.argv[launch.argv.indexOf("-i") + 1])
        assertEquals("TERM=xterm-256color", launch.argv[launch.argv.indexOf("-i") + 2])
    }
}
