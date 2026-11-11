package com.psyche.kelivo.workspace

import android.os.Process
import android.util.Log
import java.io.File
import java.io.IOException
import java.nio.file.Files
import java.nio.file.NoSuchFileException
import java.util.UUID
import java.util.concurrent.TimeUnit

/** Ownership lives in the host PRoot environment, so it survives an app crash
 * even between spawning a process and recording its PID. Guest env -i does not
 * carry these markers into MCP servers or user commands. */
class WorkspaceProcessOwner(
    private val packageName: String,
    private val procRoot: File = File("/proc"),
    private val uid: Int = Process.myUid(),
    private val appPid: Int = Process.myPid(),
    private val signalExit: (Long, () -> Boolean) -> Unit = { pid, stillOwned ->
        requestProotExit(pid, stillOwned)
    },
    private val exitTimeoutMillis: Long = 5_000,
) {
    private val instance = UUID.randomUUID().toString()
    private val owner by lazy {
        val stat = checkNotNull(readStat(appPid)) { "cannot identify workspace owner" }
        "$appPid:${stat.startTime}:$instance"
    }
    private var recovered = false

    fun environment(runId: String): Map<String, String> = mapOf(
        APP to packageName,
        OWNER to owner,
        RUN to runId,
    )

    /** Called on the serialized process executor before launching or replacing
     * an environment. Never kill processes merely because they share our UID. */
    @Synchronized fun recoverOrphans() {
        if (recovered) return
        val directories = procRoot.listFiles() ?: throw IOException("cannot inspect workspace processes")
        val pending = mutableListOf<OwnedProcess>()
        for (directory in directories) {
            val pid = directory.name.toIntOrNull()?.takeIf { it > 0 } ?: continue
            val candidate = inspect(pid) ?: continue
            if (candidate.owner == owner || ownerIsAlive(candidate.owner)) continue
            signalExit(pid.toLong()) { inspect(pid) == candidate }
            pending.add(candidate)
        }
        // Signal every tracer first, then share one deadline for their exit.
        // A zombie has already exited; its new parent is responsible for reaping.
        val deadline = System.nanoTime() + TimeUnit.MILLISECONDS.toNanos(exitTimeoutMillis)
        for (candidate in pending) {
            while (true) {
                val stat = readStat(candidate.pid)
                if (stat == null || stat.startTime != candidate.startTime || stat.exited) break
                check(System.nanoTime() < deadline) { "old workspace process ${candidate.pid} did not stop" }
                Thread.sleep(10)
            }
        }
        recovered = true
    }

    private fun ownerIsAlive(value: String): Boolean {
        val parts = value.split(':')
        if (parts.size != 3 || parts[2].isEmpty()) return true
        val pid = parts[0].toIntOrNull()?.takeIf { it > 0 } ?: return true
        val startTime = parts[1].toLongOrNull()?.takeIf { it > 0 } ?: return true
        return try {
            val stat = readStat(pid)
            stat != null && stat.startTime == startTime && !stat.exited
        } catch (error: IOException) {
            Log.w(TAG, "preserving workspace process: cannot inspect owner $pid", error)
            true
        }
    }

    private fun inspect(pid: Int): OwnedProcess? {
        val directory = File(procRoot, pid.toString())
        // Other Android UIDs may be hidden by /proc. They are never candidates.
        val status = try {
            read(File(directory, "status"))
        } catch (_: IOException) {
            return null
        }
        val uids = status.lineSequence().firstOrNull { it.startsWith("Uid:") }
            ?.substringAfter(':')?.trim()?.split(Regex("\\s+"))
        if (uids == null || uids.size != 4 || uids.any { it.toIntOrNull() != uid }) return null
        try {
            val before = readStat(pid) ?: return null
            if (before.exited) return null
            val executable = Files.readSymbolicLink(File(directory, "exe").toPath()).toString()
                .removeSuffix(" (deleted)")
            if (File(executable).name != ProotCommand.EXEC_LIB) return null
            val environment = read(File(directory, "environ")).split('\u0000').associate {
                it.substringBefore('=') to it.substringAfter('=', "")
            }
            if (environment[APP] != packageName) return null
            val processOwner = environment[OWNER]?.takeIf { it.isNotEmpty() } ?: return null
            val runId = environment[RUN]?.takeIf { it.isNotEmpty() } ?: return null
            // Recheck after reading the other files: a PID can be recycled.
            val after = readStat(pid) ?: return null
            if (after.startTime != before.startTime || after.exited) return null
            return OwnedProcess(pid, before.startTime, executable, processOwner, runId)
        } catch (_: NoSuchFileException) {
            return null
        } catch (error: IOException) {
            Log.w(TAG, "preserving process $pid: cannot verify workspace ownership", error)
            return null
        }
    }

    private fun readStat(pid: Int): ProcessStat? = try {
        val text = read(File(procRoot, "$pid/stat"))
        // comm can contain spaces and ')'; fields after its last ')' start at 3.
        val fields = text.substring(text.lastIndexOf(')') + 1).trim().split(Regex("\\s+"))
        val startTime = fields.getOrNull(19)?.toLongOrNull()
            ?: throw IOException("cannot read process $pid start time")
        ProcessStat(startTime, fields[0] == "Z" || fields[0] == "X")
    } catch (_: NoSuchFileException) {
        null
    } catch (error: IOException) {
        // An open /proc/PID/stat can return ESRCH if reaping wins the read.
        // Only a confirmed disappearance authorizes treating the PID as gone.
        if (Files.notExists(File(procRoot, pid.toString()).toPath())) null else throw error
    }

    private fun read(file: File): String = String(Files.readAllBytes(file.toPath()), Charsets.UTF_8)

    private data class ProcessStat(val startTime: Long, val exited: Boolean)
    private data class OwnedProcess(
        val pid: Int,
        val startTime: Long,
        val executable: String,
        val owner: String,
        val runId: String,
    )

    private companion object {
        const val TAG = "WorkspaceProcesses"
        const val APP = "KELIVO_WORKSPACE_APP"
        const val OWNER = "KELIVO_WORKSPACE_OWNER"
        const val RUN = "KELIVO_WORKSPACE_RUN"
    }
}
