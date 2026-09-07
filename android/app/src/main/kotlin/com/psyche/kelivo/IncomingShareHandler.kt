package com.psyche.kelivo

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import com.psyche.kelivo.workspace.WorkspaceDocumentsProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.IOException
import java.util.UUID
import java.util.concurrent.Executors
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.CancellationException

/** Keeps granted content URIs out of Flutter and copies their bytes while the
 * sending activity's grant is still valid. Pending deliveries survive startup. */
class IncomingShareHandler(context: Context, messenger: BinaryMessenger) {
    private val context = context.applicationContext
    private val root = File(context.filesDir, "incoming_shares")
    private val main = Handler(Looper.getMainLooper())
    private val channel = MethodChannel(messenger, "app.incoming_share")
    @Volatile private var disposed = false

    init {
        activeHandler = this
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getImportProgress" -> result.success(currentProgress)
                "cancelImport" -> {
                    (call.arguments as? String)?.let { id ->
                        if (currentProgress?.get("id") == id) cancelled.add(id)
                    }
                    result.success(null)
                }
                "getPendingShares" -> execute(result) {
                    root.listFiles().orEmpty().sortedBy { it.name }.mapNotNull { directory ->
                        val manifest = File(directory, "share.json")
                        if (!manifest.isFile) null else toMap(JSONObject(manifest.readText()))
                    }
                }
                "acknowledgeShares" -> execute(result) {
                    val ids = call.arguments as? List<*> ?: emptyList<Any>()
                    for (id in ids.filterIsInstance<String>()) {
                        if (id.matches(Regex("[0-9]+-[a-f0-9-]+"))) {
                            File(root, id).deleteRecursively()
                        }
                    }
                    null
                }
                else -> result.notImplemented()
            }
        }
    }

    fun receive(intent: Intent?): Boolean {
        if (intent == null || intent.action !in supportedActions) return false
        // VIEW is only a local document opening action, never a web/OAuth link.
        if (intent.action == Intent.ACTION_VIEW && intent.data?.scheme !in setOf("content", "file")) return false
        val copy = Intent(intent)
        executor.execute {
            val id = "${System.currentTimeMillis()}-${UUID.randomUUID()}"
            val directory = File(root, id)
            try {
                directory.mkdirs()
                val payload = copyShare(context, copy, directory, id,
                    isCancelled = { cancelled.contains(id) },
                    onProgress = { progress ->
                        currentProgress = progress
                        emit("progress", progress)
                    })
                if (cancelled.contains(id)) throw CancellationException()
                val temporary = File(directory, "share.json.tmp")
                temporary.writeText(payload.toString())
                if (!temporary.renameTo(File(directory, "share.json"))) {
                    throw IOException("Unable to save shared content")
                }
                emit("changed", null)
            } catch (_: CancellationException) {
                directory.deleteRecursively()
            } catch (_: Exception) {
                directory.deleteRecursively()
                emit("failed", null)
            } finally {
                cancelled.remove(id)
                currentProgress = null
                emit("progress", null)
            }
        }
        return true
    }

    private fun emit(method: String, value: Any?) {
        main.post { activeHandler?.takeUnless { it.disposed }?.channel?.invokeMethod(method, value) }
    }

    private fun execute(result: MethodChannel.Result, block: () -> Any?) {
        executor.execute {
            try {
                val value = block()
                main.post { if (!disposed) result.success(value) }
            } catch (_: Exception) {
                main.post { if (!disposed) result.error("share_failed", "Unable to read shared content", null) }
            }
        }
    }

    fun dispose() {
        disposed = true
        if (activeHandler === this) activeHandler = null
        channel.setMethodCallHandler(null)
    }

    companion object {
        // Shared across activity recreation: reads wait for in-flight copies.
        private val executor = Executors.newSingleThreadExecutor()
        private val supportedActions = setOf(Intent.ACTION_SEND, Intent.ACTION_SEND_MULTIPLE, Intent.ACTION_VIEW)
        const val MAX_FILES = 32
        @Volatile private var activeHandler: IncomingShareHandler? = null
        private val cancelled = ConcurrentHashMap.newKeySet<String>()
        @Volatile private var currentProgress: Map<String, Any?>? = null

        @Suppress("DEPRECATION")
        internal fun collectUris(intent: Intent): List<Uri> {
            val uris = linkedSetOf<Uri>()
            when (intent.action) {
                Intent.ACTION_VIEW -> intent.data?.let(uris::add)
                Intent.ACTION_SEND -> intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)?.let(uris::add)
                Intent.ACTION_SEND_MULTIPLE -> intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)?.let(uris::addAll)
            }
            intent.clipData?.let { clip ->
                for (index in 0 until clip.itemCount) clip.getItemAt(index).uri?.let(uris::add)
            }
            return uris.toList()
        }

        internal fun copyShare(
            context: Context, intent: Intent, directory: File, id: String,
            isCancelled: () -> Boolean = { false },
            onProgress: (Map<String, Any?>) -> Unit = {},
        ): JSONObject {
            val resolver = context.contentResolver
            val text = intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()
                ?: intent.clipData?.takeIf { it.itemCount > 0 }?.getItemAt(0)?.text?.toString()
                ?: ""
            val files = JSONArray()
            val uris = collectUris(intent)
            var failed = (uris.size - MAX_FILES).coerceAtLeast(0)
            for ((index, uri) in uris.take(MAX_FILES).withIndex()) {
                var destination: File? = null
                try {
                    if (isCancelled()) throw CancellationException()
                    val local = if (uri.scheme == "file") File(uri.path ?: "").canonicalFile else null
                    if (local != null) {
                        val privateRoot = context.dataDir.canonicalFile.path
                        if (!local.isFile || local.path == privateRoot || local.path.startsWith("$privateRoot/")) {
                            throw IOException("Private or unavailable file")
                        }
                    } else if (uri.scheme != "content") throw IOException("Unsupported URI")
                    if (local == null) {
                        // Opening our own FileProvider URI would use Kelivo's
                        // privileges, even when the sender had no read grant.
                        // Only the deliberately scoped workspace provider may
                        // hand our own files back through the share receiver.
                        val authority = uri.authority?.substringAfterLast('@')
                            ?: throw IOException("Missing content authority")
                        val provider = context.packageManager.resolveContentProvider(authority, 0)
                        if (provider?.applicationInfo?.uid == context.applicationInfo.uid &&
                            provider.name != WorkspaceDocumentsProvider::class.java.name) {
                            throw IOException("Private content provider")
                        }
                    }
                    val mime = (if (local == null) runCatching { resolver.getType(uri) }.getOrNull() else null)
                        ?: intent.type ?: "application/octet-stream"
                    var name: String? = local?.name
                    var size: Long? = local?.length()
                    if (local == null) runCatching { resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE), null, null, null)?.use { cursor ->
                        if (cursor.moveToFirst()) {
                            val nameColumn = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                            if (nameColumn >= 0) name = cursor.getString(nameColumn)
                            val sizeColumn = cursor.getColumnIndex(OpenableColumns.SIZE)
                            if (sizeColumn >= 0 && !cursor.isNull(sizeColumn)) size = cursor.getLong(sizeColumn).takeIf { it >= 0 }
                        }
                    } }
                    var safeName = name.orEmpty().substringAfterLast('/').substringAfterLast('\\')
                        .replace(Regex("[\\p{Cntrl}]"), "_")
                    while (safeName.toByteArray(Charsets.UTF_8).size > 180) {
                        safeName = safeName.substring(0, safeName.offsetByCodePoints(safeName.length, -1))
                    }
                    if (safeName.isBlank() || safeName == "." || safeName == "..") safeName = "shared-${index + 1}"
                    if (!safeName.contains('.')) {
                        MimeTypeMap.getSingleton().getExtensionFromMimeType(mime)?.let { safeName += ".$it" }
                    }
                    // Separate slots preserve duplicate display names in one share.
                    val slot = File(directory, index.toString()).apply { mkdirs() }
                    val target = File(slot, safeName)
                    destination = target
                    var lastProgress = 0L
                    fun report(bytes: Long, force: Boolean = false) {
                        val now = System.nanoTime()
                        if (force || now - lastProgress >= 100_000_000L) {
                            lastProgress = now
                            onProgress(mapOf("id" to id, "name" to safeName, "index" to index + 1,
                                "count" to minOf(uris.size, MAX_FILES), "bytes" to bytes, "total" to size))
                        }
                    }
                    report(0, true)
                    (local?.inputStream() ?: resolver.openInputStream(uri))?.use { input ->
                        target.outputStream().use { output ->
                            val buffer = ByteArray(64 * 1024)
                            var fileBytes = 0L
                            while (true) {
                                if (isCancelled()) throw CancellationException()
                                val read = input.read(buffer)
                                if (read < 0) break
                                fileBytes += read
                                output.write(buffer, 0, read)
                                report(fileBytes)
                            }
                            report(fileBytes, true)
                        }
                    } ?: throw IOException("Unable to open shared file")
                    files.put(JSONObject().put("path", target.absolutePath).put("name", safeName).put("mime", mime))
                } catch (error: CancellationException) {
                    destination?.delete()
                    throw error
                } catch (_: Exception) {
                    destination?.delete()
                    failed++
                }
            }
            return JSONObject().put("id", id).put("text", text)
                .put("files", files).put("failedFiles", failed)
        }

        private fun toMap(value: JSONObject): Map<String, Any?> = value.keys().asSequence().associateWith { key ->
            when (val item = value.get(key)) {
                JSONObject.NULL -> null
                is JSONObject -> toMap(item)
                is JSONArray -> (0 until item.length()).map { toMap(item.getJSONObject(it)) }
                else -> item
            }
        }
    }
}
