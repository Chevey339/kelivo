package com.psyche.kelivo.workspace

import android.content.ContentResolver
import android.content.Context
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.Build
import android.os.CancellationSignal
import android.os.FileObserver
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.provider.DocumentsContract
import android.provider.DocumentsContract.Document
import android.provider.DocumentsContract.Root
import android.provider.DocumentsProvider
import android.system.Os
import android.webkit.MimeTypeMap
import com.psyche.kelivo.R
import java.io.File
import java.io.FileNotFoundException
import java.io.IOException
import java.nio.file.FileAlreadyExistsException
import java.nio.file.FileVisitResult
import java.nio.file.Files
import java.nio.file.Path
import java.nio.file.SimpleFileVisitor
import java.nio.file.attribute.BasicFileAttributes

/** Workspace files in the Android system document picker. */
class WorkspaceDocumentsProvider : DocumentsProvider() {
    private lateinit var appData: File
    private lateinit var store: WorkspaceDocumentsStore
    private val directoryObservers = DirectoryObservers()
    private val authority: String get() = requireNotNull(context).packageName + ".workspace.documents"

    override fun onCreate(): Boolean {
        // path_provider_android's getApplicationDocumentsDirectory uses this directory.
        appData = requireNotNull(context).getDir("flutter", Context.MODE_PRIVATE).canonicalFile
        store = WorkspaceDocumentsStore(appData)
        return true
    }

    override fun queryRoots(projection: Array<out String>?): Cursor =
        MatrixCursor(projection ?: ROOT_COLUMNS).apply {
            addValues(mapOf(
                Root.COLUMN_ROOT_ID to WorkspaceDocumentPaths.ROOT,
                Root.COLUMN_DOCUMENT_ID to WorkspaceDocumentPaths.ROOT,
                Root.COLUMN_TITLE to "Kelivo",
                Root.COLUMN_ICON to R.mipmap.ic_launcher,
                Root.COLUMN_FLAGS to (Root.FLAG_LOCAL_ONLY or Root.FLAG_SUPPORTS_IS_CHILD or
                    Root.FLAG_SUPPORTS_CREATE),
                Root.COLUMN_MIME_TYPES to "*/*",
            ))
        }

    override fun queryDocument(documentId: String, projection: Array<out String>?): Cursor =
        MatrixCursor(projection ?: DOCUMENT_COLUMNS).apply {
            if (documentId == WorkspaceDocumentPaths.ROOT) {
                addValues(mapOf(
                    Document.COLUMN_DOCUMENT_ID to documentId,
                    Document.COLUMN_DISPLAY_NAME to "Kelivo",
                    Document.COLUMN_MIME_TYPE to Document.MIME_TYPE_DIR,
                    Document.COLUMN_FLAGS to if (Build.VERSION.SDK_INT >= 30) Document.FLAG_DIR_BLOCKS_OPEN_DOCUMENT_TREE else 0,
                ))
            } else {
                val (root, relative, file) = resolve(documentId)
                addDocument(root, relative, file)
            }
        }

    override fun queryChildDocuments(
        parentDocumentId: String,
        projection: Array<out String>?,
        sortOrder: String?,
    ): Cursor {
        val uri = DocumentsContract.buildChildDocumentsUri(authority, parentDocumentId)
        val cursor = ObservedCursor(projection ?: DOCUMENT_COLUMNS, requireNotNull(context).contentResolver, uri, directoryObservers)
        try {
            // A rename/delete in Flutter is committed to the same WAL. Watching
            // it keeps the picker current without publishing a second registry.
            cursor.watch(appData) { it == "kelivo.db" || it == "kelivo.db-wal" }
            if (parentDocumentId == WorkspaceDocumentPaths.ROOT) {
                for (root in store.list()) cursor.addDocument(root, "", root.directory)
            } else {
                val (root, relative, directory) = resolve(parentDocumentId)
                if (relative.isNotEmpty() && !directory.isDirectory) throw FileNotFoundException("Not a directory")
                cursor.watch(directory) { true }
                val files = directory.listFiles().orEmpty().filterNot { it.name.startsWith(".l2s.") }.sortedWith(
                    compareBy<File> { !it.isDirectory }.thenBy { it.name.lowercase() },
                )
                for (child in files) {
                    val path = if (relative.isEmpty()) child.name else "$relative/${child.name}"
                    try {
                        val file = WorkspaceDocumentPaths.resolve(root, path)
                        cursor.addDocument(root, path, file)
                    } catch (_: IOException) {
                        // Files may disappear while enumerating. Escaping links
                        // and non-regular files are intentionally not exposed.
                    }
                }
            }
            return cursor
        } catch (error: Exception) {
            cursor.close()
            throw error
        }
    }

    override fun createDocument(parentDocumentId: String, mimeType: String, displayName: String): String {
        val (root, parentRelative, parent) = resolve(parentDocumentId)
        if (!parent.isDirectory) throw FileNotFoundException("Not a directory")
        val name = displayName.trim()
        if (!WorkspaceDocumentPaths.validFileName(name)) throw IllegalArgumentException("Invalid document name")
        var target = File(parent, name)
        var counter = 2
        while (target.exists()) {
            val dot = name.lastIndexOf('.')
            val candidate = if (dot <= 0) "$name ($counter)"
                else "${name.substring(0, dot)} ($counter)${name.substring(dot)}"
            target = File(parent, candidate)
            counter++
        }
        val created = if (mimeType == Document.MIME_TYPE_DIR) {
            target.mkdir()
        } else {
            target.createNewFile()
        }
        if (!created) throw IOException("Unable to create document")
        val relative = if (parentRelative.isEmpty()) target.name else "$parentRelative/${target.name}"
        requireNotNull(context).contentResolver.notifyChange(
            DocumentsContract.buildChildDocumentsUri(authority, parentDocumentId), null,
        )
        return WorkspaceDocumentPaths.documentId(root.id, relative)
    }

    override fun renameDocument(documentId: String, displayName: String): String? {
        val (root, relative, source) = resolve(documentId)
        if (relative.isEmpty()) throw FileNotFoundException("Cannot rename a workspace")
        val name = displayName.trim()
        if (!WorkspaceDocumentPaths.validFileName(name)) throw IllegalArgumentException("Invalid document name")
        if (name == source.name) return null
        val parent = source.parentFile ?: throw FileNotFoundException("No parent directory")
        val target = File(parent, name)
        if (target.exists()) throw FileAlreadyExistsException(target)
        if (!source.renameTo(target)) throw IOException("Unable to rename document")
        val parentId = WorkspaceDocumentPaths.documentId(root.id, relative.substringBeforeLast('/', ""))
        val targetRelative = if (relative.contains('/')) {
            "${relative.substringBeforeLast('/')}/$name"
        } else {
            name
        }
        val resolver = requireNotNull(context).contentResolver
        resolver.notifyChange(DocumentsContract.buildChildDocumentsUri(authority, parentId), null)
        resolver.notifyChange(DocumentsContract.buildDocumentUri(authority, documentId), null)
        return WorkspaceDocumentPaths.documentId(root.id, targetRelative)
    }

    override fun deleteDocument(documentId: String) {
        val (root, relative, file) = resolve(documentId)
        if (relative.isEmpty()) throw FileNotFoundException("Cannot delete a workspace")
        deleteTree(file.toPath())
        val parentId = WorkspaceDocumentPaths.documentId(root.id, relative.substringBeforeLast('/', ""))
        val resolver = requireNotNull(context).contentResolver
        resolver.notifyChange(DocumentsContract.buildChildDocumentsUri(authority, parentId), null)
        resolver.notifyChange(DocumentsContract.buildDocumentUri(authority, documentId), null)
    }

    override fun openDocument(documentId: String, mode: String, signal: CancellationSignal?): ParcelFileDescriptor {
        signal?.throwIfCanceled()
        val (root, relative, file) = resolve(documentId)
        if (relative.isEmpty() || !file.isFile) throw FileNotFoundException("Not a file")
        val truncate = mode == "w" || mode == "wt" || mode == "rwt"
        val flags = when (mode) {
            "r" -> ParcelFileDescriptor.MODE_READ_ONLY
            "w", "wt" -> ParcelFileDescriptor.MODE_WRITE_ONLY
            "wa" -> ParcelFileDescriptor.MODE_WRITE_ONLY or ParcelFileDescriptor.MODE_APPEND
            "rw", "rwt" -> ParcelFileDescriptor.MODE_READ_WRITE
            else -> throw FileNotFoundException("Unsupported mode")
        }
        val descriptor = ParcelFileDescriptor.open(file, flags)
        try {
            // Validate the opened descriptor as well, in case a running command
            // changed a symlink between path validation and open().
            val openedPath = Os.readlink("/proc/self/fd/${descriptor.fd}")
            if (!WorkspaceDocumentPaths.isWithin(root.directory, File(openedPath))) {
                throw FileNotFoundException("Path outside workspace")
            }
            // Truncate only after the descriptor is known to be inside the
            // workspace, so a swapped symlink cannot erase an outside file.
            if (truncate) Os.ftruncate(descriptor.fileDescriptor, 0)
            signal?.throwIfCanceled()
            return descriptor
        } catch (error: Exception) {
            descriptor.close()
            throw error
        }
    }

    override fun getDocumentType(documentId: String): String {
        if (documentId == WorkspaceDocumentPaths.ROOT) return Document.MIME_TYPE_DIR
        val (_, relative, file) = resolve(documentId)
        return if (relative.isEmpty()) Document.MIME_TYPE_DIR else mimeType(file)
    }

    override fun isChildDocument(parentDocumentId: String, documentId: String): Boolean = try {
        val (childRoot, _, childFile) = resolve(documentId)
        if (parentDocumentId == WorkspaceDocumentPaths.ROOT) {
            true
        } else {
            val (parentRoot, _, parentFile) = resolve(parentDocumentId)
            parentRoot.id == childRoot.id && parentFile.isDirectory &&
                WorkspaceDocumentPaths.isWithin(parentFile, childFile)
        }
    } catch (_: IOException) {
        false
    }

    private fun resolve(documentId: String): Triple<WorkspaceDocumentRoot, String, File> {
        val (id, relative) = WorkspaceDocumentPaths.parse(documentId)
        val root = store.list().firstOrNull { it.id == id } ?: throw FileNotFoundException("Workspace no longer exists")
        return Triple(root, relative, WorkspaceDocumentPaths.resolve(root, relative))
    }

    private fun MatrixCursor.addDocument(root: WorkspaceDocumentRoot, relative: String, file: File) {
        val isDirectory = relative.isEmpty() || file.isDirectory
        var flags = if (isDirectory) Document.FLAG_DIR_SUPPORTS_CREATE else Document.FLAG_SUPPORTS_WRITE
        if (relative.isNotEmpty()) flags = flags or Document.FLAG_SUPPORTS_DELETE or Document.FLAG_SUPPORTS_RENAME
        addValues(mapOf(
            Document.COLUMN_DOCUMENT_ID to WorkspaceDocumentPaths.documentId(root.id, relative),
            Document.COLUMN_DISPLAY_NAME to if (relative.isEmpty()) root.name else relative.substringAfterLast('/'),
            Document.COLUMN_MIME_TYPE to if (isDirectory) Document.MIME_TYPE_DIR else mimeType(file),
            Document.COLUMN_FLAGS to flags,
            Document.COLUMN_SIZE to if (file.isFile) file.length() else null,
            Document.COLUMN_LAST_MODIFIED to file.lastModified().takeIf { it > 0 },
        ))
    }

    /** Delete without following symlinks, so a link inside the workspace cannot
     * erase files outside it. */
    private fun deleteTree(path: Path) {
        Files.walkFileTree(path, object : SimpleFileVisitor<Path>() {
            override fun visitFile(file: Path, attributes: BasicFileAttributes): FileVisitResult {
                Files.delete(file)
                return FileVisitResult.CONTINUE
            }

            override fun postVisitDirectory(dir: Path, error: IOException?): FileVisitResult {
                if (error != null) throw error
                Files.delete(dir)
                return FileVisitResult.CONTINUE
            }
        })
    }

    private fun mimeType(file: File): String {
        if (file.isDirectory) return Document.MIME_TYPE_DIR
        return when (file.extension.lowercase()) {
            "md", "markdown" -> "text/markdown"
            else -> MimeTypeMap.getSingleton().getMimeTypeFromExtension(file.extension.lowercase()) ?: "application/octet-stream"
        }
    }

    private fun MatrixCursor.addValues(values: Map<String, Any?>) {
        addRow(columnNames.map { values[it] }.toTypedArray())
    }

    /** Android reuses one inotify watch per path within the process. Share it
     * across overlapping queries so closing an old cursor cannot stop a new one. */
    private class DirectoryObservers {
        private class Entry(val observer: FileObserver, val listeners: MutableSet<(String?) -> Unit>)
        private val entries = mutableMapOf<String, Entry>()

        @Suppress("DEPRECATION")
        @Synchronized
        fun subscribe(directory: File, listener: (String?) -> Unit): () -> Unit {
            val key = directory.path
            val entry = entries.getOrPut(key) {
                val listeners = mutableSetOf<(String?) -> Unit>()
                val mask = FileObserver.MODIFY or FileObserver.CLOSE_WRITE or FileObserver.CREATE or
                    FileObserver.DELETE or FileObserver.MOVED_FROM or FileObserver.MOVED_TO or
                    FileObserver.DELETE_SELF or FileObserver.MOVE_SELF
                val observer = object : FileObserver(key, mask) {
                    override fun onEvent(event: Int, path: String?) {
                        val snapshot = synchronized(this@DirectoryObservers) {
                            if (event and (FileObserver.DELETE_SELF or FileObserver.MOVE_SELF) != 0 &&
                                entries[key]?.observer === this) {
                                // This watch follows the old inode. The next
                                // query must watch the directory now at this path.
                                entries.remove(key)
                                stopWatching()
                            }
                            listeners.toList()
                        }
                        // Call outside the registry lock: cursor cleanup also
                        // acquires this lock when it releases a subscription.
                        snapshot.forEach { it(path) }
                    }
                }
                Entry(observer, listeners)
            }
            entry.listeners.add(listener)
            if (entry.listeners.size == 1) entry.observer.startWatching()
            return {
                synchronized(this) {
                    if (entry.listeners.remove(listener) && entry.listeners.isEmpty()) {
                        if (entries[key] === entry) entries.remove(key)
                        entry.observer.stopWatching()
                    }
                }
            }
        }
    }

    /** Release only this cursor's subscriptions when the picker closes it. */
    private class ObservedCursor(
        columns: Array<out String>,
        private val resolver: ContentResolver,
        private val uri: Uri,
        private val directoryObservers: DirectoryObservers,
    ) : MatrixCursor(columns) {
        private val handler = Handler(Looper.getMainLooper())
        private val subscriptions = mutableListOf<() -> Unit>()
        private val changed = Runnable { if (!isClosed) resolver.notifyChange(uri, null) }

        init { setNotificationUri(resolver, uri) }

        @Synchronized
        fun watch(directory: File, matches: (String?) -> Boolean) {
            subscriptions += directoryObservers.subscribe(directory) { path ->
                synchronized(this) {
                    if (!isClosed && matches(path)) {
                        handler.removeCallbacks(changed)
                        handler.postDelayed(changed, 150)
                    }
                }
            }
        }

        @Synchronized
        override fun close() {
            if (isClosed) return
            super.close()
            subscriptions.forEach { it() }
            subscriptions.clear()
            handler.removeCallbacks(changed)
        }
    }

    companion object {
        private val ROOT_COLUMNS = arrayOf(Root.COLUMN_ROOT_ID, Root.COLUMN_DOCUMENT_ID, Root.COLUMN_TITLE, Root.COLUMN_ICON, Root.COLUMN_FLAGS, Root.COLUMN_MIME_TYPES)
        private val DOCUMENT_COLUMNS = arrayOf(Document.COLUMN_DOCUMENT_ID, Document.COLUMN_DISPLAY_NAME, Document.COLUMN_MIME_TYPE, Document.COLUMN_FLAGS, Document.COLUMN_SIZE, Document.COLUMN_LAST_MODIFIED)
    }
}
