package com.psyche.kelivo.workspace

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import java.util.ArrayDeque

/**
 * Broadcast sink for `app.workspace/events`. Events are always posted to the
 * main looper. Until a listener attaches, payloads are queued so a late
 * Dart subscription does not drop the first extract/exec chunks.
 */
class WorkspaceEvents : EventChannel.StreamHandler {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val lock = Any()
    private var sink: EventChannel.EventSink? = null
    private val pending = ArrayDeque<Map<String, Any?>>()

    fun emit(event: Map<String, Any?>) {
        mainHandler.post {
            synchronized(lock) {
                val current = sink
                if (current != null) {
                    current.success(event)
                } else {
                    pending.addLast(event)
                }
            }
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        synchronized(lock) {
            sink = events
            while (pending.isNotEmpty()) {
                events?.success(pending.removeFirst())
            }
        }
    }

    override fun onCancel(arguments: Any?) {
        synchronized(lock) {
            sink = null
        }
    }
}
