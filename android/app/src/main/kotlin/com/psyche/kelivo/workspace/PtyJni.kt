package com.psyche.kelivo.workspace

internal object PtyJni {
    init {
        System.loadLibrary("termux_pty")
    }

    @JvmStatic
    external fun createSubprocess(
        cmd: String,
        cwd: String,
        args: Array<String>,
        env: Array<String>,
        processId: IntArray,
        rows: Int,
        cols: Int,
    ): Int

    @JvmStatic
    external fun setPtyWindowSize(fd: Int, rows: Int, cols: Int)

    @JvmStatic
    external fun waitFor(pid: Int): Int

    @JvmStatic
    external fun close(fd: Int)
}
