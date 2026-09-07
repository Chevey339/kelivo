package com.psyche.kelivo.workspace

import java.io.File

/** Best-effort guards for common shell commands, like Minis. Not a sandbox. */
internal object MountWriteGuards {
    private const val MARKER = "# kelivo-mount-readonly-guard"
    private const val CONFIG = "/run/kelivo/mount-readonly-prefixes"
    private val commands = listOf("touch", "tee", "cp", "mv", "mkdir", "rm", "rmdir", "ln", "dd")

    fun install(rootfs: File, mounts: List<BindMount>) {
        val prefixes = mounts.filter { it.readOnly }.map { it.guest }
        val config = File(rootfs, CONFIG.removePrefix("/"))
        val bin = File(rootfs, "usr/local/bin").canonicalFile
        if (prefixes.isEmpty()) {
            if (!config.exists()) return
            for (name in commands) {
                val wrapper = File(bin, name)
                if (isOurWrapper(wrapper)) wrapper.delete()
            }
            config.delete()
            return
        }
        config.parentFile!!.mkdirs()
        config.writeText(prefixes.joinToString("\n", postfix = "\n"))
        bin.mkdirs()
        for (name in commands) {
            val wrapper = File(bin, name)
            // Do not replace user-installed commands or symlinks.
            if (wrapper.canonicalFile != wrapper.absoluteFile) continue
            if (wrapper.exists() && !isOurWrapper(wrapper)) continue
            val script = commandScript(name)
            if (!wrapper.exists() || wrapper.readText() != script) wrapper.writeText(script)
            check(wrapper.setExecutable(true, false)) { "Cannot install mount write guard" }
        }
    }

    private fun isOurWrapper(file: File): Boolean {
        if (!file.isFile || file.canonicalFile != file.absoluteFile) return false
        return file.inputStream().use { input ->
            val prefix = ByteArray(80)
            val size = input.read(prefix)
            size > 0 && String(prefix, 0, size, Charsets.UTF_8).startsWith("#!/bin/sh\n$MARKER\n")
        }
    }

    internal fun commandScript(name: String, config: String = CONFIG): String {
        require(name in commands)
        val quotedConfig = "'" + config.replace("'", "'\"'\"'") + "'"
        return """#!/bin/sh
            |$MARKER
            |cfg=$quotedConfig
            |check_target() {
            |    [ -f "${'$'}cfg" ] || return 0
            |    # Ubuntu coreutils resolves relative paths, .. and symlink parents,
            |    # including targets which have not been created yet.
            |    resolved=${'$'}(PATH=/usr/bin:/bin realpath -m -- "${'$'}1" 2>/dev/null) || resolved="${'$'}1"
            |    case "${'$'}resolved" in /*) ;; *) resolved="${'$'}PWD/${'$'}resolved";; esac
            |    while IFS= read -r prefix; do
            |        [ -n "${'$'}prefix" ] || continue
            |        case "${'$'}resolved" in
            |            "${'$'}prefix"|"${'$'}prefix"/*)
            |                printf '%s\n' "$name: ${'$'}1: read-only mounted folder; enable writes in Environment settings" >&2
            |                exit 1;;
            |        esac
            |    done < "${'$'}cfg"
            |}
            |# Match Minis' common-command coverage. Redirection, interpreters,
            |# absolute executable paths and other programs can bypass wrappers.
            |for arg do
            |    case "${'$'}arg" in
            |        -*) continue;;
            |    esac
            |    if [ "$name" = dd ]; then
            |        case "${'$'}arg" in of=*) check_target "${'$'}{arg#of=}";; esac
            |    else
            |        check_target "${'$'}arg"
            |    fi
            |done
            |PATH=/usr/bin:/bin exec $name "${'$'}@"
            |""".trimMargin()
    }
}
