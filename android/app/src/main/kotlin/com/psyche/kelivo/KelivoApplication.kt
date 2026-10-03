package com.psyche.kelivo

import android.app.Application
import android.os.Build
import com.psyche.kelivo.background.BackgroundRuntime
import com.psyche.kelivo.workspace.WorkspacePlugin
import com.psyche.kelivo.scheduled.ScheduledTasks
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor

/** One Dart isolate and database owner per process, independent of its UI. */
class KelivoApplication : Application() {
    val backgroundRuntime by lazy { BackgroundRuntime(this) }
    val scheduledTasks by lazy { ScheduledTasks(this) }
    val workspace by lazy { WorkspacePlugin(this) }
    val deviceTools by lazy { DeviceLocalToolsHandler(this) }

    private val engineHolder = lazy {
        // Android 11's OpenGL Impeller path exceeds a 120 Hz frame with live
        // glass on the tested device; Skia keeps the same blur below that budget.
        // Configure the shared engine here, since Activity launch flags do not
        // reach an engine supplied by provideFlutterEngine.
        val engineArgs = if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.R) {
            arrayOf("--enable-impeller=false")
        } else {
            null
        }
        FlutterEngine(this, engineArgs).also { engine ->
            val messenger = engine.dartExecutor.binaryMessenger
            backgroundRuntime.configure(messenger)
            scheduledTasks.configure(messenger)
            workspace.configure(messenger)
            deviceTools.configure(messenger)
            engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        }
    }

    val hasEngine get() = engineHolder.isInitialized()
    val engine: FlutterEngine get() = engineHolder.value
}
