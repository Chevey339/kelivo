package com.psyche.kelivo.workspace

import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicReference

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28], manifest = Config.NONE)
class PtyShutdownTest {
    @Test fun closedTerminalIsStillAwaitedBeforeEnvironmentCleanup() {
        val events = WorkspaceEvents()
        val sessions = PtySessions(events)
        val stopped = CountDownLatch(1)
        val allowExit = CountDownLatch(1)
        val shutdownDone = CountDownLatch(1)
        val signals = AtomicInteger()
        val failure = AtomicReference<Throwable>()
        val session = PtySession(
            "terminal", events,
            signalExit = { signals.incrementAndGet(); stopped.countDown() },
            waitForProcess = {
                assertTrue("termination must precede reaping", stopped.await(1, TimeUnit.SECONDS))
                check(allowExit.await(5, TimeUnit.SECONDS))
                137
            },
        )
        field(session, "pid").setInt(session, 123)
        @Suppress("UNCHECKED_CAST")
        val current = field(sessions, "sessions").get(sessions) as ConcurrentHashMap<String, PtySession>
        @Suppress("UNCHECKED_CAST")
        val live = field(sessions, "liveSessions").get(sessions) as MutableSet<PtySession>
        current["terminal"] = session
        live.add(session)

        // A terminal tab can be closed before reset starts. It must remain
        // tracked until the guest actually exits, not just until its FD closes.
        sessions.close("terminal")
        assertEquals(1, signals.get())
        assertTrue(current.isEmpty())
        val reader = reader(session)
        val shutdown = Thread {
            try {
                sessions.closeAll(waitForExit = true)
            } catch (error: Throwable) {
                failure.set(error)
            } finally {
                shutdownDone.countDown()
            }
        }.apply { start() }
        try {
            assertFalse("cleanup must wait for waitpid", shutdownDone.await(100, TimeUnit.MILLISECONDS))
            assertThrows(IllegalStateException::class.java) { session.awaitExit(System.nanoTime()) }
        } finally {
            allowExit.countDown()
            reader.join(5_000)
            shutdown.join(5_000)
        }
        assertFalse(reader.isAlive)
        assertFalse(shutdown.isAlive)
        assertNull(failure.get())
        session.awaitExit(System.nanoTime())
        session.close()
        assertEquals("never signal a PID after reaping", 1, signals.get())
    }

    @Test fun unsuccessfulWaitDoesNotAuthorizeCleanupOrDropTheSession() {
        val removed = AtomicInteger()
        val session = PtySession(
            "terminal", WorkspaceEvents(),
            onExit = { removed.incrementAndGet() },
            signalExit = {},
            waitForProcess = { -1 },
        )
        field(session, "pid").setInt(session, 123)
        val reader = reader(session)
        reader.join(5_000)
        assertFalse(reader.isAlive)
        assertEquals(0, removed.get())
        assertThrows(IllegalStateException::class.java) { session.awaitExit(System.nanoTime()) }
    }

    private fun reader(session: PtySession) = Thread {
        // No master FD: exercise the EOF/close path with a controlled native wait.
        PtySession::class.java.getDeclaredMethod("readLoop")
            .also { it.isAccessible = true }.invoke(session)
    }.apply { start() }

    private fun field(target: Any, name: String) = target.javaClass.getDeclaredField(name)
        .also { it.isAccessible = true }
}
