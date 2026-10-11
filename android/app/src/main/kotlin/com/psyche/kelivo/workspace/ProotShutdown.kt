package com.psyche.kelivo.workspace

import java.io.File
import java.nio.file.Files
import java.nio.file.NoSuchFileException
import java.util.concurrent.TimeUnit

/** PRoot forks its first tracee before installing its SIGQUIT handler. Sending
 * SIGQUIT in that startup window would kill only the tracer and orphan the guest. */
internal fun awaitProotSignalHandler(procDir: File, timeoutMillis: Long = 5_000): Boolean {
    val deadline = System.nanoTime() + TimeUnit.MILLISECONDS.toNanos(timeoutMillis)
    while (true) {
        try {
            // The PTY child initially inherits the app's handlers until exec.
            // Its caught-signal mask alone is therefore not a readiness signal.
            val executable = Files.readSymbolicLink(File(procDir, "exe").toPath())
            if (executable.fileName.toString() == ProotCommand.EXEC_LIB) {
                val caught = File(procDir, "status").readLines()
                    .firstOrNull { it.startsWith("SigCgt:") }
                    ?.substringAfter(':')?.trim()?.toULongOrNull(16)
                if (caught != null && caught and 4uL != 0uL) return true
            }
        } catch (_: NoSuchFileException) {
            // Gone or a zombie: the caller still has to confirm process exit.
            return false
        } catch (error: java.io.FileNotFoundException) {
            if (!procDir.exists()) return false
            throw error
        }
        check(System.nanoTime() < deadline) { "workspace process did not become ready to stop" }
        Thread.sleep(10)
    }
}
