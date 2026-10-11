package com.psyche.kelivo.workspace

import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File
import java.nio.file.Files
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

class ProotShutdownTest {
    @get:Rule val temporary = TemporaryFolder()

    @Test fun waitsForTheProotHandlerBeforeAuthorizingTheSignal() {
        val proc = process(ProotCommand.EXEC_LIB, "0000000000000000")
        val done = CountDownLatch(1)
        val failure = AtomicReference<Throwable>()
        val waiter = Thread {
            try {
                assertTrue(awaitProotSignalHandler(proc))
            } catch (error: Throwable) {
                failure.set(error)
            } finally {
                done.countDown()
            }
        }.apply { start() }
        try {
            assertFalse(done.await(100, TimeUnit.MILLISECONDS))
        } finally {
            File(proc, "status").writeText("SigCgt:\t0000000000000004\n")
            waiter.join(5_000)
        }
        assertFalse(waiter.isAlive)
        assertNull(failure.get())
    }

    @Test fun inheritedAppHandlerDoesNotCountAsProotReadiness() {
        val proc = process("app_process64", "0000000000000004")
        assertThrows(IllegalStateException::class.java) { awaitProotSignalHandler(proc, 0) }
    }

    @Test fun missingHandlerFailsClosedRatherThanKillingOnlyTheTracer() {
        val proc = process(ProotCommand.EXEC_LIB, "0000000000000000")
        assertThrows(IllegalStateException::class.java) { awaitProotSignalHandler(proc, 0) }
    }

    @Test fun alreadyExitedProcessNeedsNoSignal() {
        assertFalse(awaitProotSignalHandler(File(temporary.root, "gone"), 0))
    }

    private fun process(executable: String, caught: String): File {
        val proc = temporary.newFolder("123")
        Files.createSymbolicLink(File(proc, "exe").toPath(), File("/native/$executable").toPath())
        File(proc, "status").writeText("SigCgt:\t$caught\n")
        return proc
    }
}
