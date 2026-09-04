package com.psyche.kelivo.workspace

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
)

class ExecRunner(
    private val events: WorkspaceEvents,
) {
    private val runs = ConcurrentHashMap<String, Running>()

    fun start(request: ExecRequest) {
        cancel(request.runId)
        request.tmpDir.mkdirs()
        ProotCommand.stageTalloc(request.nativeLibDir, request.tmpDir)
        val launch = ProotCommand.build(
            nativeLibDir = request.nativeLibDir,
            rootfsDir = request.rootfsDir,
            tmpDir = request.tmpDir,
            binds = request.binds,
            cwd = request.cwd,
            command = request.command,
            env = request.env,
        )
        val builder = ProcessBuilder(launch.argv)
            .directory(launch.workingDirectory)
            .redirectErrorStream(false)
        builder.environment().putAll(launch.processEnv)
        val process = builder.start()
        try {
            process.outputStream.close()
        } catch (_: Exception) {
        }

        val running = Running(process)
        runs[request.runId] = running
        val startedAt = System.nanoTime()

        Thread({ drain(process.inputStream, request.runId, "stdout") }, "ws-out-${request.runId}")
            .apply { isDaemon = true; start() }
        Thread({ drain(process.errorStream, request.runId, "stderr") }, "ws-err-${request.runId}")
            .apply { isDaemon = true; start() }

        Thread({
            val finished = try {
                process.waitFor(request.timeoutMs.coerceAtLeast(1L), TimeUnit.MILLISECONDS)
            } catch (_: InterruptedException) {
                Thread.currentThread().interrupt()
                false
            }
            val cancelled = running.cancelled.get()
            val timedOut = !finished && !cancelled
            if (!finished || cancelled) {
                killProcessTree(process)
            }
            val exitCode = when {
                cancelled || timedOut -> -1
                else -> try {
                    process.exitValue()
                } catch (_: IllegalThreadStateException) {
                    killProcessTree(process)
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
            events.emit(payload)
            runs.remove(request.runId, running)
        }, "ws-wait-${request.runId}").apply { isDaemon = true; start() }
    }

    fun cancel(runId: String): Boolean {
        val running = runs[runId] ?: return false
        running.cancelled.set(true)
        killProcessTree(running.process)
        return true
    }

    fun cancelAll() {
        runs.keys.toList().forEach { cancel(it) }
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

internal fun killProcessTree(process: Process) {
    val pid = processPid(process)
    if (pid != null) {
        killDescendants(pid)
    }
    try {
        process.destroyForcibly()
    } catch (_: Exception) {
    }
}

private fun killDescendants(pid: Long) {
    val children = mutableListOf<Long>()
    val proc = File("/proc")
    if (!proc.isDirectory) return
    proc.listFiles()?.forEach { dir ->
        val child = dir.name.toLongOrNull() ?: return@forEach
        try {
            val stat = File(dir, "stat")
            if (!stat.isFile) return@forEach
            val text = stat.readText()
            val close = text.lastIndexOf(')')
            if (close < 0) return@forEach
            val fields = text.substring(close + 1).trim().split(Regex("\\s+"))
            // /proc/pid/stat: after comm, field 2 is state, field 3 is ppid
            val ppid = fields.getOrNull(1)?.toLongOrNull() ?: return@forEach
            if (ppid == pid) children += child
        } catch (_: Exception) {
        }
    }
    children.forEach { child ->
        killDescendants(child)
        try {
            android.os.Process.sendSignal(child.toInt(), 9)
        } catch (_: Exception) {
        }
    }
    try {
        android.os.Process.sendSignal(pid.toInt(), 9)
    } catch (_: Exception) {
    }
}
