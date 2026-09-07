package com.psyche.kelivo.workspace

import java.io.File
import java.util.concurrent.TimeUnit
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class MountWriteGuardsTest {
    @get:Rule val temporary = TemporaryFolder()

    private fun run(script: File, vararg args: String): Pair<Int, String> {
        val process = ProcessBuilder(listOf("/bin/sh", script.path) + args)
            .redirectErrorStream(true).start()
        process.outputStream.close()
        assertTrue(process.waitFor(10, TimeUnit.SECONDS))
        return process.exitValue() to process.inputStream.bufferedReader().readText()
    }

    @Test fun commonCommandsRejectReadonlyPathsAndWritableCommandsStillRun() {
        val locked = temporary.newFolder("My Notes").canonicalFile
        val writable = temporary.newFolder("writable").canonicalFile
        val original = File(locked, "original").apply { writeText("hello") }
        val config = temporary.newFile("prefixes").apply { writeText(locked.path + "\n") }
        val cases = mapOf(
            "touch" to listOf(original.path),
            "tee" to listOf(original.path),
            "cp" to listOf(original.path, File(writable, "copy").path),
            "mv" to listOf(original.path, File(writable, "moved").path),
            "mkdir" to listOf(File(locked, "new").path),
            "rm" to listOf(original.path),
            "rmdir" to listOf(locked.path),
            "ln" to listOf(original.path, File(writable, "link").path),
            "dd" to listOf("if=/dev/null", "of=${original.path}"),
        )
        for ((name, args) in cases) {
            val script = temporary.newFile(name).apply {
                writeText(MountWriteGuards.commandScript(name, config.path))
            }
            val (code, output) = run(script, *args.toTypedArray())
            assertEquals("$name: $output", 1, code)
            assertTrue(output, output.contains("read-only mounted folder"))
        }
        assertEquals("hello", original.readText())
        val outputFile = File(writable, "new")
        assertEquals(0, run(File(temporary.root, "touch"), outputFile.path).first)
        assertTrue(outputFile.exists())
        // dd's input may be readonly; only of= is a write target.
        val copy = File(writable, "dd-copy")
        assertEquals(0, run(File(temporary.root, "dd"), "if=${original.path}", "of=${copy.path}").first)
        assertEquals("hello", copy.readText())
    }

    @Test fun removalKeepsUserCommandsAndOnlyDeletesOwnedWrappers() {
        val rootfs = temporary.newFolder("rootfs")
        val bin = File(rootfs, "usr/local/bin").apply { mkdirs() }
        val userCommand = File(bin, "cp").apply { writeText("user command") }
        MountWriteGuards.install(rootfs, listOf(BindMount("/host/notes", "/mounts/Notes", true)))
        assertEquals("user command", userCommand.readText())
        assertTrue(File(bin, "touch").canExecute())
        assertEquals("/mounts/Notes\n", File(rootfs, "run/kelivo/mount-readonly-prefixes").readText())
        MountWriteGuards.install(rootfs, emptyList())
        assertEquals("user command", userCommand.readText())
        assertFalse(File(bin, "touch").exists())
        assertFalse(File(rootfs, "run/kelivo/mount-readonly-prefixes").exists())
    }
}
