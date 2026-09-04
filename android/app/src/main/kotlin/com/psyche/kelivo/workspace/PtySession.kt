package com.psyche.kelivo.workspace

import android.os.ParcelFileDescriptor
import android.system.Os
import android.util.Log
import java.io.File
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicBoolean

class PtySessions(
    private val events: WorkspaceEvents,
) {
    private val sessions = ConcurrentHashMap<String, PtySession>()

    fun open(
        sessionId: String,
        nativeLibDir: File,
        rootfsDir: File,
        tmpDir: File,
        binds: List<BindMount>,
        cwd: String,
        env: Map<String, String>,
        cols: Int,
        rows: Int,
    ): Int {
        close(sessionId)
        tmpDir.mkdirs()
        ProotCommand.stageTalloc(nativeLibDir, tmpDir)
        val launch = ProotCommand.build(
            nativeLibDir = nativeLibDir,
            rootfsDir = rootfsDir,
            tmpDir = tmpDir,
            binds = binds,
            cwd = cwd,
            command = null,
            env = env,
        )
        val session = PtySession(sessionId, events)
        val pid = session.start(launch, rows = rows, cols = cols)
        sessions[sessionId] = session
        return pid
    }

    fun write(sessionId: String, data: ByteArray) {
        sessions[sessionId]?.write(data)
    }

    fun resize(sessionId: String, cols: Int, rows: Int) {
        sessions[sessionId]?.resize(rows = rows, cols = cols)
    }

    fun close(sessionId: String) {
        sessions.remove(sessionId)?.close()
    }

    fun closeAll() {
        sessions.keys.toList().forEach { close(it) }
    }
}

class PtySession(
    private val sessionId: String,
    private val events: WorkspaceEvents,
) {
    private var masterFd: Int = -1
    private var masterPfd: ParcelFileDescriptor? = null
    private var pid: Int = -1
    private val closed = AtomicBoolean(false)

    fun start(launch: ProotLaunch, rows: Int, cols: Int): Int {
        val pidOut = IntArray(1)
        val hostEnv = launch.processEnv.map { "${it.key}=${it.value}" }.toTypedArray()
        val args = launch.argv.drop(1).toTypedArray()
        val fd = PtyJni.createSubprocess(
            launch.argv.first(),
            launch.workingDirectory.absolutePath,
            args,
            hostEnv,
            pidOut,
            rows,
            cols,
        )
        if (fd < 0) {
            throw IllegalStateException("failed to open workspace PTY")
        }
        masterFd = fd
        masterPfd = ParcelFileDescriptor.fromFd(fd)
        pid = pidOut[0]
        Thread({ readLoop() }, "ws-pty-$sessionId").apply { isDaemon = true; start() }
        return pid
    }

    fun write(data: ByteArray) {
        val descriptor = masterPfd?.fileDescriptor ?: return
        if (data.isEmpty()) return
        var offset = 0
        while (offset < data.size) {
            val written = Os.write(descriptor, data, offset, data.size - offset)
            if (written <= 0) break
            offset += written
        }
    }

    fun resize(rows: Int, cols: Int) {
        val fd = masterFd
        if (fd < 0) return
        PtyJni.setPtyWindowSize(fd, rows, cols)
    }

    fun close() {
        if (!closed.compareAndSet(false, true)) return
        val fd = masterFd
        masterFd = -1
        try {
            masterPfd?.close()
        } catch (_: Exception) {
        }
        masterPfd = null
        if (fd >= 0) {
            try {
                PtyJni.close(fd)
            } catch (_: Exception) {
            }
        }
    }

    private fun readLoop() {
        val buffer = ByteArray(4096)
        try {
            while (!closed.get()) {
                val descriptor = masterPfd?.fileDescriptor ?: break
                val read = try {
                    Os.read(descriptor, buffer, 0, buffer.size)
                } catch (error: Exception) {
                    Log.d(TAG, "pty read ended: ${error.message}")
                    break
                }
                if (read <= 0) break
                events.emit(
                    mapOf(
                        "type" to "pty",
                        "sessionId" to sessionId,
                        "data" to buffer.copyOf(read),
                    ),
                )
            }
        } finally {
            val exitCode = try {
                if (pid > 0) PtyJni.waitFor(pid) else -1
            } catch (_: Exception) {
                -1
            }
            close()
            events.emit(
                mapOf(
                    "type" to "ptyExit",
                    "sessionId" to sessionId,
                    "exitCode" to exitCode,
                ),
            )
        }
    }

    private companion object {
        const val TAG = "WorkspacePty"
    }
}
