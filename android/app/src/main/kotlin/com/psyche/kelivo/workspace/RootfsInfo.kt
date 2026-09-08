package com.psyche.kelivo.workspace

import java.io.File
import java.nio.file.Files
import java.util.ArrayDeque

/** Resolve guest-absolute symlinks inside a rootfs, never against Android's /. */
object RootfsInfo {
    fun guestFile(root: File, path: String): File {
        require(path.startsWith('/') && !path.contains('\u0000')) { "invalid guest path" }
        val base = root.canonicalFile
        val pending = ArrayDeque(path.split('/'))
        var current = base
        var links = 0
        while (pending.isNotEmpty()) {
            when (val part = pending.removeFirst()) {
                "", "." -> continue
                ".." -> {
                    require(current != base) { "guest path escapes rootfs" }
                    current = current.parentFile!!
                }
                else -> {
                    val next = File(current, part)
                    if (Files.isSymbolicLink(next.toPath())) {
                        require(++links <= 40) { "too many rootfs symlinks" }
                        val target = Files.readSymbolicLink(next.toPath()).toString()
                        if (target.startsWith('/')) current = base
                        target.split('/').asReversed().forEach { pending.addFirst(it) }
                    } else {
                        current = next
                    }
                }
            }
        }
        return current
    }

    fun inspect(root: File, arch: String): Map<String, String> {
        val shell = guestFile(root, "/bin/sh")
        require(shell.isFile && shell.canExecute()) { "rootfs must contain an executable /bin/sh" }
        val header = ByteArray(20)
        shell.inputStream().use { require(it.read(header) == header.size) { "invalid rootfs shell" } }
        require(header[0] == 0x7f.toByte() && String(header, 1, 3) == "ELF" &&
            header[5] == 1.toByte()) { "rootfs shell must be a little-endian ELF" }
        val machine = (header[18].toInt() and 255) or ((header[19].toInt() and 255) shl 8)
        val matches = when (arch) {
            "armhf" -> header[4] == 1.toByte() && machine == 40
            "arm64" -> header[4] == 2.toByte() && machine == 183
            "amd64" -> header[4] == 2.toByte() && machine == 62
            else -> false
        }
        require(matches) {
            "rootfs architecture does not match $arch"
        }
        val release = guestFile(root, "/etc/os-release")
        val fields = if (release.isFile) release.readLines().mapNotNull { line ->
            val at = line.indexOf('=')
            if (at <= 0) null else line.substring(0, at).trim() to line.substring(at + 1).trim().trim('"', '\'')
        }.toMap() else emptyMap()
        val distro = fields["ID"]?.takeIf { it.matches(Regex("[a-zA-Z0-9._-]+")) } ?: "custom"
        val version = fields["VERSION_ID"]?.takeIf { it.matches(Regex("[a-zA-Z0-9._-]+")) } ?: "local"
        val codename = if (distro == "alpine") "v" + version.split('.').take(2).joinToString(".")
            else fields["VERSION_CODENAME"].orEmpty()
        return mapOf("distro" to distro, "version" to version, "codename" to codename, "arch" to arch)
    }
}
