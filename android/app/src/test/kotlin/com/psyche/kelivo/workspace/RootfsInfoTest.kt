package com.psyche.kelivo.workspace

import java.io.File
import java.nio.file.Files
import org.junit.Assert.*
import org.junit.Test

class RootfsInfoTest {
    private fun image(root: File, machine: Int = 183, elfClass: Int = 2) {
        val header = ByteArray(20)
        header[0] = 0x7f; header[1] = 'E'.code.toByte(); header[2] = 'L'.code.toByte(); header[3] = 'F'.code.toByte()
        header[4] = elfClass.toByte(); header[5] = 1; header[18] = machine.toByte(); header[19] = (machine shr 8).toByte()
        File(root, "bin").mkdirs()
        File(root, "bin/busybox").apply { writeBytes(header); setExecutable(true) }
        Files.createSymbolicLink(File(root, "bin/sh").toPath(), File("/bin/busybox").toPath())
        File(root, "etc").mkdirs()
        File(root, "etc/os-release").writeText("ID=alpine\nVERSION_ID=3.24.1\n")
    }

    @Test fun detectsAbsoluteGuestSymlinksAndDistro() {
        val root = Files.createTempDirectory("rootfs-info-").toFile()
        try {
            image(root)
            val info = RootfsInfo.inspect(root, "arm64")
            assertEquals("alpine", info["distro"])
            assertEquals("3.24.1", info["version"])
            assertEquals("v3.24", info["codename"])
            assertEquals(File(root, "bin/busybox").canonicalFile, RootfsInfo.guestFile(root, "/bin/sh"))
        } finally { root.deleteRecursively() }
    }

    @Test fun rejectsWrongCpuAndMissingShell() {
        val root = Files.createTempDirectory("rootfs-arch-").toFile()
        try {
            image(root, 62)
            assertThrows(IllegalArgumentException::class.java) { RootfsInfo.inspect(root, "arm64") }
            assertEquals("amd64", RootfsInfo.inspect(root, "amd64")["arch"])
            File(root, "bin/busybox").delete()
            assertThrows(IllegalArgumentException::class.java) { RootfsInfo.inspect(root, "arm64") }
        } finally { root.deleteRecursively() }
    }

    @Test fun rejectsSymlinkCyclesAndTraversal() {
        val root = Files.createTempDirectory("rootfs-links-").toFile()
        try {
            Files.createSymbolicLink(File(root, "cycle").toPath(), File("cycle").toPath())
            assertThrows(IllegalArgumentException::class.java) { RootfsInfo.guestFile(root, "/cycle") }
            assertThrows(IllegalArgumentException::class.java) { RootfsInfo.guestFile(root, "/../../outside") }
        } finally { root.deleteRecursively() }
    }

    @Test fun acceptsArm32RootfsAndRejectsMismatchedElfClass() {
        val root = Files.createTempDirectory("rootfs-armhf-").toFile()
        try {
            image(root, machine = 40, elfClass = 1)
            assertEquals("armhf", RootfsInfo.inspect(root, "armhf")["arch"])
            assertThrows(IllegalArgumentException::class.java) { RootfsInfo.inspect(root, "arm64") }
            assertThrows(IllegalArgumentException::class.java) { RootfsInfo.inspect(root, "amd64") }
            val shell = File(root, "bin/busybox")
            val header = shell.readBytes()
            header[4] = 2
            shell.writeBytes(header)
            assertThrows(IllegalArgumentException::class.java) { RootfsInfo.inspect(root, "armhf") }
            header[4] = 1
            header[18] = 183.toByte()
            shell.writeBytes(header)
            assertThrows(IllegalArgumentException::class.java) { RootfsInfo.inspect(root, "arm64") }
        } finally { root.deleteRecursively() }
    }

    @Test fun shellSelectionAndOptionsApplyToExecAndPty() {
        val root = Files.createTempDirectory("rootfs-proot-").toFile()
        try {
            image(root)
            for (command in listOf("echo ok", null)) {
                val base = ProotCommand.build(root, root, root, emptyList(), "/", command, emptyMap(), extraArgs = listOf("-k", "5.10.0"))
                assertTrue(base.argv.contains("/bin/sh"))
                assertEquals(listOf("-k", "5.10.0"), base.argv.subList(4, 6))
                File(root, "bin/bash").apply { writeText("shell fixture"); setExecutable(true) }
                val bash = ProotCommand.build(root, root, root, emptyList(), "/", command, emptyMap())
                assertTrue(bash.argv.contains("/bin/bash"))
                val custom = ProotCommand.build(root, root, root, emptyList(), "/", command, emptyMap(), shell = "/usr/bin/zsh")
                assertTrue(custom.argv.contains("/usr/bin/zsh"))
                File(root, "bin/bash").delete()
            }
        } finally { root.deleteRecursively() }
    }
}
