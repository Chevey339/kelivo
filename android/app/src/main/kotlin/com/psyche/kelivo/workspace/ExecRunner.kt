package com.psyche.kelivo.workspace

import android.system.ErrnoException
import android.system.Os
import android.system.OsConstants
import android.util.Log
import java.io.File
import java.io.InputStream
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

data class ExecRequest(
    val runId: String,
    val nativeLibDir: File,
    val rootfsDir: File,
    val tmpDir: File,
    val binds: List<BindMount>,
    val cwd: String,
    val command: String,
    val env: Map<String, String>,
    val timeoutMs: Long,
    val keepStdinOpen: Boolean = false,
    val prootArguments: List<String> = emptyList(),
    val shell: String? = null,
)

class ExecRunner(
    private val events: WorkspaceEvents,
    private val stopProcess: (Process) -> Unit = ::stopProotProcess,
) {
    private val runs = ConcurrentHashMap<String, Running>()
    private val liveRuns = ConcurrentHashMap.newKeySet<Running>()

    fun start(request: ExecRequest) {
        cancel(request.runId)
        request.tmpDir.mkdirs()
        ProotCommand.stageTalloc(request.nativeLibDir, request.tmpDir)
        RootfsCertificates.ensureInstalled(request.rootfsDir)
        val launch = ProotCommand.build(
            nativeLibDir = request.nativeLibDir,
            rootfsDir = request.rootfsDir,
            tmpDir = request.tmpDir,
            binds = request.binds,
            cwd = request.cwd,
            command = request.command,
            env = request.env,
            extraArgs = request.prootArguments,
            shell = request.shell,
        )
        val builder = ProcessBuilder(launch.argv)
            .directory(launch.workingDirectory)
            .redirectErrorStream(false)
        builder.environment().putAll(launch.processEnv)
        val process = builder.start()
        if (!request.keepStdinOpen) try {
            process.outputStream.close()
        } catch (_: Exception) {
        }

        val running = Running(process)
        runs[request.runId] = running
        liveRuns.add(running)
        val startedAt = System.nanoTime()
        if (request.keepStdinOpen) events.emit(mapOf("type" to "started", "runId" to request.runId))

        val stdoutReader = Thread({ drain(process.inputStream, request.runId, "stdout") }, "ws-out-${request.runId}")
            .apply { isDaemon = true; start() }
        val stderrReader = Thread({ drain(process.errorStream, request.runId, "stderr") }, "ws-err-${request.runId}")
            .apply { isDaemon = true; start() }

        Thread({
            val finished = try {
                if (request.keepStdinOpen && request.timeoutMs == 0L) {
                    process.waitFor()
                    true
                } else {
                    process.waitFor(request.timeoutMs.coerceAtLeast(1L), TimeUnit.MILLISECONDS)
                }
            } catch (_: InterruptedException) {
                Thread.currentThread().interrupt()
                false
            }
            val cancelled = running.cancelled.get()
            val timedOut = !finished && !cancelled
            if (!finished || cancelled) {
                try {
                    stopProcess(process)
                } catch (error: Exception) {
                    // Still report the command's timeout/cancellation. Keep the
                    // live run registered so environment cleanup cannot proceed.
                    Log.w(TAG, "failed to stop workspace command", error)
                }
            }
            val exitCode = when {
                cancelled || timedOut -> -1
                else -> try {
                    process.exitValue()
                } catch (_: IllegalThreadStateException) {
                    try {
                        stopProcess(process)
                    } catch (error: Exception) {
                        Log.w(TAG, "failed to stop workspace command", error)
                    }
                    -1
                }
            }
            val durationMs = TimeUnit.NANOSECONDS.toMillis(System.nanoTime() - startedAt)
            val payload = linkedMapOf<String, Any?>(
                "type" to "exit",
                "runId" to request.runId,
                "exitCode" to exitCode,
                "timedOut" to timedOut,
                "durationMs" to durationMs,
            )
            if (cancelled) {
                payload["cancelled"] = true
            }
            // Deliver the last protocol response before reporting process exit.
            stdoutReader.join(1500)
            stderrReader.join(1500)
            try { process.outputStream.close() } catch (_: Exception) {}
            events.emit(payload)
            runs.remove(request.runId, running)
            if (!process.isAlive) liveRuns.remove(running)
        }, "ws-wait-${request.runId}").apply { isDaemon = true; start() }
    }

    fun writeStdin(runId: String, data: ByteArray) {
        val running = runs[runId] ?: error("process is not running")
        synchronized(running) {
            check(!running.cancelled.get()) { "process was cancelled" }
            running.process.outputStream.write(data)
            running.process.outputStream.flush()
        }
    }

    fun cancel(runId: String): Boolean {
        val running = runs[runId] ?: return false
        running.cancelled.set(true)
        stopProcess(running.process)
        return true
    }

    fun cancelAll(waitForExit: Boolean = false) {
        val pending = liveRuns.toList()
        pending.forEach {
            it.cancelled.set(true)
            stopProcess(it.process)
        }
        if (waitForExit) {
            val deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(5)
            pending.forEach {
                check(it.process.waitFor((deadline - System.nanoTime()).coerceAtLeast(0), TimeUnit.NANOSECONDS)) {
                    "workspace command did not stop"
                }
                liveRuns.remove(it)
            }
        }
    }

    private fun drain(stream: InputStream, runId: String, type: String) {
        val buffer = ByteArray(8192)
        try {
            stream.use { input ->
                while (true) {
                    val read = input.read(buffer)
                    if (read < 0) break
                    if (read == 0) continue
                    events.emit(
                        mapOf(
                            "type" to type,
                            "runId" to runId,
                            "data" to buffer.copyOf(read),
                        ),
                    )
                }
            }
        } catch (error: Exception) {
            Log.d(TAG, "drain $type ended: ${error.message}")
        }
    }

    private class Running(val process: Process) {
        val cancelled = AtomicBoolean(false)
    }

    private companion object {
        const val TAG = "WorkspaceExec"
    }
}

internal fun processPid(process: Process): Long? {
    try {
        val method = process.javaClass.methods.firstOrNull { it.name == "pid" && it.parameterCount == 0 }
        val value = method?.invoke(process) as? Number
        if (value != null && value.toLong() > 0L) return value.toLong()
    } catch (_: Exception) {
    }
    try {
        val field = process.javaClass.getDeclaredField("pid")
        field.isAccessible = true
        val value = (field.get(process) as? Number)?.toLong()
        if (value != null && value > 0L) return value
    } catch (_: Exception) {
    }
    return Regex("pid[= ](\\d+)").find(process.toString())?.groupValues?.get(1)?.toLongOrNull()
}

internal fun stopProotProcess(process: Process) {
    if (!process.isAlive) return
    val pid = processPid(process)
    check(pid != null) { "cannot determine workspace process ID" }
    requestProotExit(pid)
}

internal fun requestProotExit(pid: Long) {
    // SIGKILL on the tracer can orphan tracees (including daemonized guests).
    // SIGQUIT asks PRoot to kill and reap the complete traced process set.
    if (!awaitProotSignalHandler(File("/proc/$pid"))) return
    try {
        Os.kill(pid.toInt(), OsConstants.SIGQUIT)
    } catch (error: ErrnoException) {
        if (error.errno != OsConstants.ESRCH) throw error
    }
}
