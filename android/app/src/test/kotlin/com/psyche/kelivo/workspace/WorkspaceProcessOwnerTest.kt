package com.psyche.kelivo.workspace

import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.io.File
import java.nio.file.Files

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28], manifest = Config.NONE)
class WorkspaceProcessOwnerTest {
    @get:Rule val temporary = TemporaryFolder()
    private val signalled = mutableListOf<Long>()

    @Test fun recoversOldExecAndPtyProcessesAndKeepsCurrentInstance() {
        val owner = owner()
        candidate(201, run = "mcp-old")
        candidate(202, run = "pty-old")
        candidate(203, environment = owner.environment("mcp-current"))
        owner.recoverOrphans()
        assertEquals(setOf(201L, 202L), signalled.toSet())
        owner.recoverOrphans()
        assertEquals(2, signalled.size)
        assertEquals("S", state(203))
    }

    @Test fun neverSignalsUnmarkedForeignOrLiveOwnerProcesses() {
        val owner = owner()
        candidate(201, environment = emptyMap())
        candidate(202, processUid = 10001)
        candidate(203, executable = "unrelated")
        candidate(204, environment = markers() + ("KELIVO_WORKSPACE_APP" to "other.app"))
        candidate(205, environment = markers() + ("KELIVO_WORKSPACE_OWNER" to "invalid"))
        candidate(206)
        stat(10, 10) // The other owning app instance is still alive.
        owner.recoverOrphans()
        assertTrue(signalled.isEmpty())
    }

    @Test fun ownerPidReuseDoesNotPreventRecovery() {
        val owner = owner()
        candidate(201)
        stat(10, 999) // Same PID as the dead owner, different process start time.
        owner.recoverOrphans()
        assertEquals(listOf(201L), signalled)
    }

    @Test fun revalidatesIdentityImmediatelyBeforeSignalling() {
        val owner = owner { pid, valid ->
            stat(pid.toInt(), 999)
            assertFalse(valid())
        }
        candidate(201)
        owner.recoverOrphans()
        assertEquals("S", state(201))
    }

    @Test fun refusesToLaunchWhileAnOldTracerHasNotExitedAndAllowsRetry() {
        var allowExit = false
        val owner = owner { pid, valid ->
            assertTrue(valid())
            if (allowExit) stat(pid.toInt(), pid, "Z")
        }
        candidate(201)
        assertThrows(IllegalStateException::class.java) { owner.recoverOrphans() }
        allowExit = true
        owner.recoverOrphans()
    }

    @Test fun unreadableOwnershipAndAlreadyExitedProcessesArePreserved() {
        val owner = owner()
        val unreadable = candidate(201)
        check(File(unreadable, "environ").delete())
        check(File(unreadable, "environ").mkdir())
        candidate(202)
        stat(202, 202, "Z")
        owner.recoverOrphans()
        assertTrue(signalled.isEmpty())
    }

    @Test fun recoversAnExecutableDeletedByAnAppUpgrade() {
        val owner = owner()
        candidate(201, executable = "${ProotCommand.EXEC_LIB} (deleted)")
        owner.recoverOrphans()
        assertEquals(listOf(201L), signalled)
    }

    private fun owner(
        signal: (Long, () -> Boolean) -> Unit = { pid, valid ->
            assertTrue(valid())
            signalled.add(pid)
            stat(pid.toInt(), pid, "Z")
        },
    ): WorkspaceProcessOwner {
        stat(100, 100)
        return WorkspaceProcessOwner(
            "com.psyche.kelivo", temporary.root, 10000, 100,
            signalExit = signal, exitTimeoutMillis = 0,
        )
    }

    private fun markers(run: String = "mcp-old") = mapOf(
        "KELIVO_WORKSPACE_APP" to "com.psyche.kelivo",
        "KELIVO_WORKSPACE_OWNER" to "10:10:old-instance",
        "KELIVO_WORKSPACE_RUN" to run,
    )

    private fun candidate(
        pid: Int,
        run: String = "mcp-old",
        environment: Map<String, String> = markers(run),
        processUid: Int = 10000,
        executable: String = ProotCommand.EXEC_LIB,
    ): File {
        stat(pid, pid.toLong())
        val directory = File(temporary.root, "$pid")
        File(directory, "status").writeText("Uid:\t$processUid\t$processUid\t$processUid\t$processUid\n")
        File(directory, "environ").writeText(environment.entries.joinToString("\u0000", postfix = "\u0000") { "${it.key}=${it.value}" })
        Files.createSymbolicLink(File(directory, "exe").toPath(), File("/native/$executable").toPath())
        return directory
    }

    private fun stat(pid: Int, startTime: Long, state: String = "S") {
        val directory = File(temporary.root, "$pid").apply { mkdirs() }
        val fields = MutableList(20) { "0" }
        fields[0] = state
        fields[19] = startTime.toString()
        File(directory, "stat").writeText("$pid (process with ) spaces) ${fields.joinToString(" ")}")
    }

    private fun state(pid: Int) = File(temporary.root, "$pid/stat").readText()
        .substringAfterLast(')').trim().substringBefore(' ')
}
