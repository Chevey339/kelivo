package com.psyche.kelivo.workspace

import java.io.File

data class BindMount(
    val host: String,
    val guest: String,
    val readOnly: Boolean = false,
)

data class ProotLaunch(
    val argv: List<String>,
    val processEnv: Map<String, String>,
    val workingDirectory: File,
)

object ProotCommand {
    const val EXEC_LIB = "libproot_exec.so"
    const val LOADER_LIB = "libproot_loader.so"
    const val TALLOC_LIB = "libtalloc.so"
    const val TALLOC_SONAME = "libtalloc.so.2"
    const val BASH_EVAL = "cd -- \"\$1\" && eval \"\$2\""

    fun validateGuestCwd(cwd: String): String {
        val trimmed = cwd.trim()
        require(trimmed.startsWith("/")) { "guest cwd must be an absolute path" }
        require(!trimmed.contains('\u0000')) { "guest cwd contains a NUL byte" }
        require(trimmed.split('/').none { it == ".." }) {
            "guest cwd must not contain .. segments"
        }
        return trimmed
    }

    fun build(
        nativeLibDir: File,
        rootfsDir: File,
        tmpDir: File,
        binds: List<BindMount>,
        cwd: String,
        command: String?,
        env: Map<String, String>,
        extraArgs: List<String> = emptyList(),
        shell: String? = null,
        includeLibraryPath: Boolean = File(nativeLibDir, TALLOC_LIB).isFile,
    ): ProotLaunch {
        val guestCwd = validateGuestCwd(cwd)
        require(extraArgs.none { it.contains('\u0000') }) { "PRoot argument contains a NUL byte" }
        val guestShell = shell?.takeIf { it.isNotBlank() } ?: if (
            RootfsInfo.guestFile(rootfsDir, "/bin/bash").let { it.isFile && it.canExecute() }
        ) "/bin/bash" else "/bin/sh"
        validateGuestCwd(guestShell)
        val argv = mutableListOf(
            File(nativeLibDir, EXEC_LIB).absolutePath,
            "--root-id",
            "--link2symlink",
            "--kill-on-exit",
            *extraArgs.toTypedArray(),
            "-r",
            rootfsDir.absolutePath,
            "-w",
            guestCwd,
        )
        for (bind in binds) {
            if (bind.host.isBlank() || bind.guest.isBlank()) continue
            argv += "-b"
            argv += "${bind.host}:${bind.guest}"
        }
        // PRoot bindings are writable. The app and file tools enforce the
        // user's read-only preference; arbitrary shell programs are not isolated.
        argv += listOf("-b", "/dev", "-b", "/proc", "-b", "/sys")
        argv += listOf("/usr/bin/env", "-i")

        val guestEnv = LinkedHashMap(env)
        // env -i discards the host environment. Export guest defaults so child
        // processes (including dpkg) receive PATH, not only bash's shell default.
        guestEnv.putIfAbsent("HOME", "/root")
        guestEnv.putIfAbsent("PATH", "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin")
        guestEnv.putIfAbsent("LANG", "C.UTF-8")
        if (command == null) {
            guestEnv.putIfAbsent("TERM", "xterm-256color")
        }
        for ((key, value) in guestEnv) {
            argv += "$key=$value"
        }

        if (command == null) {
            argv += listOf(guestShell, "-l")
        } else {
            argv += listOf(guestShell, "-lc", BASH_EVAL, "kelivo", guestCwd, command)
        }

        val processEnv = linkedMapOf(
            "PROOT_LOADER" to File(nativeLibDir, LOADER_LIB).absolutePath,
            "PROOT_TMP_DIR" to tmpDir.absolutePath,
            "TMPDIR" to tmpDir.absolutePath,
        )
        if (includeLibraryPath) {
            processEnv["LD_LIBRARY_PATH"] =
                tmpDir.absolutePath + File.pathSeparator + nativeLibDir.absolutePath
        }

        return ProotLaunch(
            argv = argv,
            processEnv = processEnv,
            workingDirectory = rootfsDir.parentFile ?: rootfsDir,
        )
    }

    /** Copy libtalloc.so to the SONAME proot actually DT_NEEDs. */
    fun stageTalloc(nativeLibDir: File, tmpDir: File) {
        val source = File(nativeLibDir, TALLOC_LIB)
        if (!source.isFile) return
        tmpDir.mkdirs()
        val staged = File(tmpDir, TALLOC_SONAME)
        if (staged.isFile && staged.length() == source.length()) return
        source.copyTo(staged, overwrite = true)
    }
}


internal fun validateExternalMounts(mounts: List<BindMount>) {
    val prefix = "/mounts/"
    require(mounts.size <= 10 && mounts.map { it.guest.lowercase() }.distinct().size == mounts.size)
    for (mount in mounts) {
        require(mount.guest.startsWith(prefix))
        val name = mount.guest.removePrefix(prefix)
        require(name.isNotEmpty() && name == name.trim() && name != "." && name != "..")
        require(name.none { it == '/' || it == '\\' || it == ':' || it.code < 32 || it.code == 127 })
        require(File(mount.host).isAbsolute && mount.host.none { it == ':' || it == '\u0000' })
    }
}
