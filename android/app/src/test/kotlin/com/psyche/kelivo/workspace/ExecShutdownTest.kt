package com.psyche.kelivo.workspace

import android.os.Looper
import io.flutter.plugin.common.EventChannel
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import java.io.File
import java.io.IOException
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28], manifest = Config.NONE)
class ExecShutdownTest {
    @get:Rule val temporary = TemporaryFolder()

    @Test fun failedStopStillReportsTimeoutAndRemainsTrackedForCleanup() {
        val events = WorkspaceEvents()
        val exit = AtomicReference<Map<*, *>>()
        events.onListen(null, object : EventChannel.EventSink {
            override fun success(event: Any?) {
                if (event is Map<*, *> && event["type"] == "exit") exit.set(event)
            }
            override fun error(code: String, message: String?, details: Any?) = fail(message)
            override fun endOfStream() {}
        })
        val stopRequested = CountDownLatch(1)
        val process = AtomicReference<Process>()
        val rejectStop = AtomicBoolean(true)
        val runner = ExecRunner(events, stopProcess = {
            process.set(it)
            stopRequested.countDown()
            if (rejectStop.get()) throw IOException("cannot inspect PRoot readiness")
            it.destroyForcibly()
        })
        val native = temporary.newFolder("native")
        File(native, ProotCommand.EXEC_LIB).apply {
            writeText("#!/bin/sh\nexec /bin/sleep 30\n")
            check(setExecutable(true))
        }
        val rootfs = temporary.newFolder("rootfs")
        File(rootfs, "etc/ssl/certs/ca-certificates.crt").apply {
            parentFile!!.mkdirs()
            writeText("test certificate bundle")
        }
        try {
            runner.start(ExecRequest(
                runId = "timeout", nativeLibDir = native, rootfsDir = rootfs,
                tmpDir = temporary.newFolder("tmp"), binds = emptyList(), cwd = "/",
                command = "ignored by host fixture", env = emptyMap(), timeoutMs = 1,
            ))
            assertTrue(stopRequested.await(5, TimeUnit.SECONDS))
            val deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(5)
            while (exit.get() == null && System.nanoTime() < deadline) {
                shadowOf(Looper.getMainLooper()).idle()
                Thread.sleep(10)
            }
            assertNotNull("stop failure must not lose the exit event", exit.get())
            assertEquals(true, exit.get()["timedOut"])
            assertTrue(process.get().isAlive)
            assertThrows(IOException::class.java) { runner.cancelAll(waitForExit = true) }

            rejectStop.set(false)
            runner.cancelAll(waitForExit = true)
            assertFalse("cleanup only proceeds after actual exit", process.get().isAlive)
        } finally {
            process.get()?.let { it.destroyForcibly(); it.waitFor(5, TimeUnit.SECONDS) }
        }
    }
}
