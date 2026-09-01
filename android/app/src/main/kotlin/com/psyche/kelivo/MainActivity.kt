package com.psyche.kelivo

import android.app.Activity
import android.content.ActivityNotFoundException
import android.net.Uri
import android.content.Intent
import android.os.Build
import android.os.ParcelFileDescriptor
import android.os.StatFs
import android.provider.DocumentsContract
import android.util.Log
import android.view.Surface
import android.view.SurfaceHolder
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterSurfaceView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.OutputStream
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private companion object {
        const val CREATE_DOCUMENT_REQUEST_CODE = 4107
        const val TAG = "MainActivity"
    }

    private enum class WritableFileState {
        IDLE,
        OPEN,
        COMMITTED,
        DISCARDED,
    }

    private val processTextChannelName = "app.process_text"
    private val fileSaveChannelName = "app.file_save"
    private val deviceStorageChannelName = "app.device_storage"
    private val displayModeChannelName = "app.display_mode"
    private var processTextChannel: MethodChannel? = null
    private var fileSaveChannel: MethodChannel? = null
    private var deviceStorageChannel: MethodChannel? = null
    private var displayModeChannel: MethodChannel? = null
    private var flutterSurfaceView: FlutterSurfaceView? = null
    private var pendingProcessText: String? = null
     private var pendingSaveResult: MethodChannel.Result? = null
     private var pendingSaveSourcePath: String? = null
     private var pendingDirectWrite = false
     private var pendingWritableStream: OutputStream? = null
     private var pendingWritableUri: Uri? = null
     @Volatile private var writableFileState = WritableFileState.IDLE
     private val writableFileExecutor = Executors.newSingleThreadExecutor()
     private var deviceLocalToolsHandler: DeviceLocalToolsHandler? = null

    override fun onFlutterSurfaceViewCreated(flutterSurfaceView: FlutterSurfaceView) {
        super.onFlutterSurfaceViewCreated(flutterSurfaceView)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM) {
            this.flutterSurfaceView = flutterSurfaceView
            flutterSurfaceView.holder.addCallback(object : SurfaceHolder.Callback {
                override fun surfaceCreated(holder: SurfaceHolder) {
                    requestNativeHighRefreshRate()
                }

                override fun surfaceChanged(
                    holder: SurfaceHolder,
                    format: Int,
                    width: Int,
                    height: Int,
                ) {
                    requestNativeHighRefreshRate()
                }

                override fun surfaceDestroyed(holder: SurfaceHolder) = Unit
            })
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
         super.configureFlutterEngine(flutterEngine)
         McpOAuthHandler.configure(this, flutterEngine.dartExecutor.binaryMessenger)
         deviceLocalToolsHandler = DeviceLocalToolsHandler(this).also {
             it.configure(flutterEngine.dartExecutor.binaryMessenger)
         }
        processTextChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, processTextChannelName)
        processTextChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialText" -> {
                    val text = pendingProcessText ?: extractProcessText(intent)
                    pendingProcessText = null
                    result.success(text)
                }
                else -> result.notImplemented()
            }
        }
        fileSaveChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, fileSaveChannelName)
        fileSaveChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "saveFileFromPath" -> handleSaveFileFromPath(call.arguments, result)
                "createWritableFile" -> handleCreateWritableFile(call.arguments, result)
                "writeWritableFileChunk" -> handleWriteWritableFileChunk(call.arguments, result)
                "completeWritableFile" -> handleCompleteWritableFile(result)
                "abortWritableFile" -> handleAbortWritableFile(result)
                else -> result.notImplemented()
            }
        }
        deviceStorageChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, deviceStorageChannelName)
        deviceStorageChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "freeBytes" -> result.success(usableBytesForAppData())
                else -> result.notImplemented()
            }
        }
        displayModeChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, displayModeChannelName)
        displayModeChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "requestHighRefreshRate" -> result.success(requestNativeHighRefreshRate())
                else -> result.notImplemented()
            }
        }
        pendingProcessText = extractProcessText(intent)
    }

    private fun requestNativeHighRefreshRate(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.VANILLA_ICE_CREAM) return false

        try {
            val surface = flutterSurfaceView?.holder?.surface
            if (surface?.isValid == true) {
                val currentDisplay = display ?: return true
                val activeMode = currentDisplay.mode
                val targetRefreshRate = currentDisplay.supportedModes
                    .asSequence()
                    .filter {
                        it.physicalWidth == activeMode.physicalWidth &&
                            it.physicalHeight == activeMode.physicalHeight
                    }
                    .maxOfOrNull { it.refreshRate }
                if (targetRefreshRate != null) {
                    // Hint the actual Flutter rendering surface while leaving
                    // mode selection, ARR, and system limits to Android.
                    surface.setFrameRate(
                        targetRefreshRate,
                        Surface.FRAME_RATE_COMPATIBILITY_DEFAULT,
                        Surface.CHANGE_FRAME_RATE_ONLY_IF_SEAMLESS,
                    )
                }
            }
        } catch (error: RuntimeException) {
            Log.w(TAG, "Unable to request a high refresh rate", error)
        }
        return true
    }

    /**
     * Space the app may still use on the volume holding its data, or null when
     * it cannot be determined. Callers treat null as "unknown" and carry on.
     */
    private fun usableBytesForAppData(): Long? = try {
        val target = filesDir ?: dataDir
        StatFs(target.absolutePath).availableBytes.takeIf { it > 0 }
    } catch (_: Exception) {
        null
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val text = extractProcessText(intent) ?: return
        val ch = processTextChannel
        if (ch != null) {
            ch.invokeMethod("onProcessText", text)
        } else {
            pendingProcessText = text
        }
    }

    override fun onDestroy() {
        val stream = pendingWritableStream
        val uri = pendingWritableUri
        if (stream != null && uri != null) {
            writableFileExecutor.execute {
                // Serialized after all queued writes/completion. A successful
                // completion marks COMMITTED before posting its UI callback,
                // so an intact backup is never deleted in this race window.
                if (writableFileState == WritableFileState.OPEN) {
                    discardWritableDestination(stream, uri)
                }
            }
        }
        writableFileExecutor.shutdown()
        super.onDestroy()
    }
 
     override fun onRequestPermissionsResult(
         requestCode: Int,
         permissions: Array<out String>,
         grantResults: IntArray,
     ) {
         if (deviceLocalToolsHandler?.onRequestPermissionsResult(requestCode, grantResults) == true) {
             return
         }
         super.onRequestPermissionsResult(requestCode, permissions, grantResults)
     }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != CREATE_DOCUMENT_REQUEST_CODE) {
            return
        }

        val destUri = if (resultCode == Activity.RESULT_OK) data?.data else null
        handleSaveDestination(destUri)
    }

    private fun extractProcessText(intent: Intent?): String? {
        if (intent?.action != Intent.ACTION_PROCESS_TEXT) return null
        val text = intent.getCharSequenceExtra(Intent.EXTRA_PROCESS_TEXT)?.toString()
        return text?.trim()?.takeIf { it.isNotEmpty() }
    }

    private fun handleSaveFileFromPath(arguments: Any?, result: MethodChannel.Result) {
        if (pendingSaveResult != null || pendingWritableStream != null) {
            result.error("busy", "Another save operation is already in progress.", null)
            return
        }

        val args = arguments as? Map<*, *>
        val rawSourcePath = args?.get("sourcePath")?.toString()?.trim().orEmpty()
        if (rawSourcePath.isEmpty()) {
            result.error("invalid_args", "Missing sourcePath.", null)
            return
        }

        val sourceFile = File(rawSourcePath)
        if (!sourceFile.exists() || !sourceFile.isFile) {
            result.error("not_found", "Source file does not exist.", null)
            return
        }

        val suggestedFileName = args?.get("fileName")?.toString()?.trim().takeUnless { it.isNullOrEmpty() }
            ?: sourceFile.name

        pendingSaveResult = result
        pendingSaveSourcePath = sourceFile.absolutePath

        try {
            val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "application/zip"
                putExtra(Intent.EXTRA_TITLE, suggestedFileName)
            }
            startActivityForResult(intent, CREATE_DOCUMENT_REQUEST_CODE)
        } catch (e: ActivityNotFoundException) {
            pendingSaveResult = null
            pendingSaveSourcePath = null
            result.error("launch_failed", e.message, null)
        }
    }

    private fun handleCreateWritableFile(arguments: Any?, result: MethodChannel.Result) {
        if (pendingSaveResult != null || pendingWritableStream != null) {
            result.error("busy", "Another save operation is already in progress.", null)
            return
        }

        val args = arguments as? Map<*, *>
        val fileName = args?.get("fileName")?.toString()?.trim().orEmpty()
        if (fileName.isEmpty()) {
            result.error("invalid_args", "Missing fileName.", null)
            return
        }

        pendingSaveResult = result
        pendingDirectWrite = true
        try {
            val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "application/zip"
                putExtra(Intent.EXTRA_TITLE, fileName)
            }
            startActivityForResult(intent, CREATE_DOCUMENT_REQUEST_CODE)
        } catch (e: ActivityNotFoundException) {
            pendingSaveResult = null
            pendingDirectWrite = false
            result.error("launch_failed", e.message, null)
        }
    }

    private fun handleCompleteWritableFile(result: MethodChannel.Result) {
        val stream = pendingWritableStream
        if (stream == null) {
            result.error("not_open", "No writable file destination is open.", null)
            return
        }

        writableFileExecutor.execute {
            try {
                stream.flush()
                stream.close()
                writableFileState = WritableFileState.COMMITTED
                runOnUiThread {
                    if (pendingWritableStream === stream) {
                        pendingWritableStream = null
                        pendingWritableUri = null
                    }
                    result.success(true)
                }
            } catch (e: Exception) {
                runOnUiThread {
                    result.error("close_failed", e.message, null)
                }
            }
        }
    }

    private fun handleWriteWritableFileChunk(arguments: Any?, result: MethodChannel.Result) {
        val stream = pendingWritableStream
        if (stream == null) {
            result.error("not_open", "No writable file destination is open.", null)
            return
        }
        val bytes = arguments as? ByteArray
        if (bytes == null) {
            result.error("invalid_args", "Missing writable file bytes.", null)
            return
        }
        if (bytes.isEmpty()) {
            result.success(true)
            return
        }

        writableFileExecutor.execute {
            try {
                stream.write(bytes)
                runOnUiThread { result.success(true) }
            } catch (e: Exception) {
                runOnUiThread {
                    result.error("write_failed", e.message, null)
                }
            }
        }
    }

    private fun handleAbortWritableFile(result: MethodChannel.Result) {
        val stream = pendingWritableStream
        val uri = pendingWritableUri
        if (stream == null || uri == null) {
            result.error("not_open", "No writable file destination is open.", null)
            return
        }

        writableFileExecutor.execute {
            val cleanupError = discardWritableDestination(stream, uri)

            runOnUiThread {
                if (pendingWritableStream === stream) {
                    pendingWritableStream = null
                    pendingWritableUri = null
                }
                if (cleanupError == null) {
                    result.success(true)
                } else {
                    result.error("discard_failed", cleanupError.message, null)
                }
            }
        }
    }

    private fun discardWritableDestination(stream: OutputStream, uri: Uri): Exception? {
        var cleanupError: Exception? = null
        try {
            stream.close()
        } catch (e: Exception) {
            cleanupError = e
        }

        var deleted = false
        try {
            deleted = DocumentsContract.deleteDocument(contentResolver, uri)
            if (!deleted) {
                cleanupError = cleanupError
                    ?: IllegalStateException("Unable to delete incomplete destination file.")
            }
        } catch (e: Exception) {
            cleanupError = cleanupError ?: e
        }
        if (deleted) {
            writableFileState = WritableFileState.DISCARDED
        }
        return cleanupError
    }

    private fun handleSaveDestination(destUri: Uri?) {
        val result = pendingSaveResult ?: return
        if (pendingDirectWrite) {
            pendingSaveResult = null
            pendingDirectWrite = false
            if (destUri == null) {
                result.success(null)
                return
            }
            try {
                pendingWritableUri = destUri
                val descriptor = contentResolver.openFileDescriptor(destUri, "rwt")
                    ?: throw IllegalStateException("Unable to open destination file.")
                pendingWritableStream = ParcelFileDescriptor.AutoCloseOutputStream(descriptor)
                writableFileState = WritableFileState.OPEN
                result.success(true)
            } catch (e: Exception) {
                try {
                    DocumentsContract.deleteDocument(contentResolver, destUri)
                } catch (_: Exception) {
                    // Preserve the error that prevented the destination from opening.
                }
                pendingWritableUri = null
                result.error("open_failed", e.message, null)
            }
            return
        }
        val sourcePath = pendingSaveSourcePath

        if (destUri == null || sourcePath.isNullOrBlank()) {
            pendingSaveResult = null
            pendingSaveSourcePath = null
            result.success(false)
            return
        }

        Thread {
            try {
                contentResolver.openOutputStream(destUri)?.use { outputStream ->
                    FileInputStream(File(sourcePath)).use { inputStream ->
                        inputStream.copyTo(outputStream, DEFAULT_BUFFER_SIZE)
                    }
                } ?: throw IllegalStateException("Unable to open destination stream.")

                runOnUiThread {
                    pendingSaveResult = null
                    pendingSaveSourcePath = null
                    result.success(true)
                }
            } catch (e: Exception) {
                runOnUiThread {
                    pendingSaveResult = null
                    pendingSaveSourcePath = null
                    result.error("save_failed", e.message, null)
                }
            }
        }.start()
    }
}
