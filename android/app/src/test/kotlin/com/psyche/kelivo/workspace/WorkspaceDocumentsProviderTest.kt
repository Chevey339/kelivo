package com.psyche.kelivo.workspace

import android.content.Context
import android.content.pm.ProviderInfo
import android.database.ContentObserver
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import android.os.CancellationSignal
import android.os.FileObserver
import android.os.Looper
import android.os.OperationCanceledException
import android.os.ParcelFileDescriptor
import android.provider.DocumentsContract.Document
import android.provider.DocumentsContract.Root
import android.system.Os
import org.json.JSONObject
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.Implementation
import org.robolectric.annotation.Implements
import org.robolectric.annotation.RealObject
import org.robolectric.annotation.Resetter
import java.io.File
import java.io.FileNotFoundException
import java.nio.file.Files
import java.time.Duration

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28], manifest = Config.NONE)
class WorkspaceDocumentsProviderTest {
    private lateinit var appData: File
    private lateinit var database: SQLiteDatabase
    private lateinit var provider: WorkspaceDocumentsProvider

    @Before
    fun setUp() {
        val context = RuntimeEnvironment.getApplication()
        appData = context.getDir("flutter", Context.MODE_PRIVATE).canonicalFile
        database = SQLiteDatabase.openOrCreateDatabase(File(appData, "kelivo.db"), null)
        database.execSQL("CREATE TABLE extension_entity_rows (kind TEXT, id TEXT, sort_order INTEGER, payload TEXT, PRIMARY KEY (kind, id))")
        database.enableWriteAheadLogging()
        provider = WorkspaceDocumentsProvider()
        provider.attachInfo(context, ProviderInfo().apply {
            authority = context.packageName + ".workspace.documents"
            exported = true
            grantUriPermissions = true
            readPermission = "android.permission.MANAGE_DOCUMENTS"
            writePermission = "android.permission.MANAGE_DOCUMENTS"
        })
    }

    @After
    fun tearDown() {
        database.close()
        Files.walk(appData.toPath()).use { paths ->
            paths.sorted(Comparator.reverseOrder()).forEach { Files.deleteIfExists(it) }
        }
    }

    private fun workspace(id: String = "one", name: String = "工作区一", kind: String = "managed"): File {
        val payload = JSONObject().put("id", id).put("name", name).put("kind", kind)
            .put("hostPath", appData.path)
        database.execSQL("INSERT OR REPLACE INTO extension_entity_rows VALUES ('workspace', ?, 0, ?)", arrayOf(id, payload.toString()))
        return File(appData, "workspaces/$id/files").also { if (WorkspaceDocumentPaths.validId(id)) it.mkdirs() }
    }

    private fun Cursor.strings(column: String): List<String> = use {
        val values = mutableListOf<String>()
        while (moveToNext()) values += getString(getColumnIndexOrThrow(column))
        values
    }

    private fun children(id: String = WorkspaceDocumentPaths.ROOT): Cursor =
        provider.queryChildDocuments(id, null, null as String?)

    @Test
    fun exposesNamedWorkspacesWithoutFlutterOrDuplicateDatabase() {
        workspace()
        workspace("two", "另一个工作区")
        assertEquals(listOf("Kelivo"), provider.queryRoots(null).strings(Root.COLUMN_TITLE))
        assertEquals(listOf("工作区一", "另一个工作区"), children().strings(Document.COLUMN_DISPLAY_NAME))
        assertTrue(File(appData, "kelivo.db").exists())
    }

    @Test
    fun honorsRequestedProjectionsAndReadOnlyFlags() {
        workspace()
        provider.queryRoots(arrayOf(Root.COLUMN_TITLE)).use {
            assertEquals(1, it.columnCount)
            assertTrue(it.moveToFirst())
            assertEquals("Kelivo", it.getString(0))
        }
        children().use {
            assertTrue(it.moveToFirst())
            assertEquals(0, it.getInt(it.getColumnIndexOrThrow(Document.COLUMN_FLAGS)))
        }
    }

    @Test
    fun listsNestedUnicodeFilesWithStableIdsAndMimeTypes() {
        val root = workspace()
        File(root, "文件夹").mkdir()
        File(root, "新技能.md").writeText("# 示例")
        assertEquals(listOf("文件夹", "新技能.md"), children("workspace/one").strings(Document.COLUMN_DISPLAY_NAME))
        assertEquals("text/markdown", provider.getDocumentType("workspace/one/新技能.md"))
        assertEquals(listOf("workspace/one/新技能.md"), provider.queryDocument("workspace/one/新技能.md", arrayOf(Document.COLUMN_DOCUMENT_ID)).strings(Document.COLUMN_DOCUMENT_ID))
        assertTrue(provider.isChildDocument("workspace/one", "workspace/one/新技能.md"))
    }

    @Test
    @Config(shadows = [DocumentDescriptorOsShadow::class])
    fun readsSelectedFileAndRejectsEveryWriteMode() {
        val root = workspace()
        File(root, "hello.txt").writeText("工作区内容")
        for (mode in listOf("w", "wa", "rw", "rwt")) {
            assertThrows(FileNotFoundException::class.java) { provider.openDocument("workspace/one/hello.txt", mode, null) }
        }
        DocumentDescriptorOsShadow.openedPath = File(root, "hello.txt").path
        val descriptor = provider.openDocument("workspace/one/hello.txt", "r", null)
        val content = ParcelFileDescriptor.AutoCloseInputStream(descriptor).bufferedReader().use { it.readText() }
        assertEquals("工作区内容", content)
        assertEquals("工作区内容", File(root, "hello.txt").readText())
    }

    @Test
    @Config(shadows = [DocumentDescriptorOsShadow::class])
    fun rejectsAnOpenedDescriptorThatMovedOutsideTheWorkspace() {
        val root = workspace()
        File(root, "hello.txt").writeText("hello")
        DocumentDescriptorOsShadow.openedPath = File(appData, "kelivo.db").path
        assertThrows(FileNotFoundException::class.java) {
            provider.openDocument("workspace/one/hello.txt", "r", null)
        }
    }

    @Test
    fun observesRegistryChangesOnTheNextQueryAndRevokesDeletedWorkspaceIds() {
        val root = workspace()
        File(root, "hello.txt").writeText("hello")
        assertEquals(listOf("工作区一"), children().strings(Document.COLUMN_DISPLAY_NAME))
        workspace(name = "改名后")
        assertEquals(listOf("改名后"), children().strings(Document.COLUMN_DISPLAY_NAME))
        database.execSQL("DELETE FROM extension_entity_rows WHERE id = 'one'")
        assertTrue(children().strings(Document.COLUMN_DOCUMENT_ID).isEmpty())
        assertThrows(FileNotFoundException::class.java) { provider.openDocument("workspace/one/hello.txt", "r", null) }
        assertTrue(File(root, "hello.txt").exists())
    }

    @Test
    @Config(shadows = [SharedPathFileObserverShadow::class])
    fun cursorReplacementKeepsFileAndRegistryNotificationsWorking() {
        val root = workspace()
        var current = children("workspace/one")
        try {
            repeat(3) {
                val previous = current
                current = children("workspace/one")
                var notifications = 0
                current.registerContentObserver(object : ContentObserver(null) {
                    override fun onChange(selfChange: Boolean) { notifications++ }
                })
                previous.close()
                SharedPathFileObserverShadow.emit(root, FileObserver.CREATE, "new.txt")
                shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(200))
                assertEquals("File notifications must survive cursor replacement", 1, notifications)
                SharedPathFileObserverShadow.emit(appData, FileObserver.MODIFY, "kelivo.db-wal")
                shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(200))
                assertEquals("Registry notifications must survive cursor replacement", 2, notifications)
            }
        } finally {
            current.close()
        }
        assertTrue(SharedPathFileObserverShadow.activePaths().isEmpty())
    }

    @Test
    @Config(shadows = [SharedPathFileObserverShadow::class])
    fun multipleDirectoriesShareRegistryWatchUntilTheLastCursorCloses() {
        workspace()
        workspace("two")
        val first = children("workspace/one")
        val second = children("workspace/two")
        val list = children()
        var secondChanges = 0
        var listChanges = 0
        second.registerContentObserver(object : ContentObserver(null) {
            override fun onChange(selfChange: Boolean) { secondChanges++ }
        })
        list.registerContentObserver(object : ContentObserver(null) {
            override fun onChange(selfChange: Boolean) { listChanges++ }
        })
        try {
            first.close()
            first.close()
            SharedPathFileObserverShadow.emit(appData, FileObserver.MODIFY, "kelivo.db-shm")
            shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(200))
            assertEquals(0, secondChanges)
            assertEquals(0, listChanges)
            SharedPathFileObserverShadow.emit(appData, FileObserver.MODIFY, "kelivo.db-wal")
            shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(200))
            assertEquals(1, secondChanges)
            assertEquals(1, listChanges)
            second.close()
            assertEquals(setOf(appData.path), SharedPathFileObserverShadow.activePaths())
            SharedPathFileObserverShadow.emit(appData, FileObserver.MODIFY, "kelivo.db-wal")
            shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(200))
            assertEquals(2, listChanges)
        } finally {
            first.close()
            second.close()
            list.close()
        }
        assertTrue(SharedPathFileObserverShadow.activePaths().isEmpty())
    }

    @Test
    @Config(shadows = [SharedPathFileObserverShadow::class])
    fun closingCursorCancelsQueuedNotificationsAndAllowsReopening() {
        val root = workspace()
        val resolver = RuntimeEnvironment.getApplication().contentResolver
        val old = children("workspace/one")
        SharedPathFileObserverShadow.emit(root, FileObserver.CREATE, "new.txt")
        old.close()
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(200))
        assertTrue(shadowOf(resolver).notifiedUris.isEmpty())
        children("workspace/one").use { reopened ->
            var notifications = 0
            reopened.registerContentObserver(object : ContentObserver(null) {
                override fun onChange(selfChange: Boolean) { notifications++ }
            })
            old.close()
            SharedPathFileObserverShadow.emit(root, FileObserver.CREATE, "another.txt")
            shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(200))
            assertEquals(1, notifications)
        }
        assertTrue(SharedPathFileObserverShadow.activePaths().isEmpty())
    }

    @Test
    @Config(shadows = [SharedPathFileObserverShadow::class])
    fun replacingADirectoryRearmsItsWatchWithoutOldCursorInterference() {
        val root = workspace()
        val old = children("workspace/one")
        try {
            assertTrue(root.renameTo(File(root.parentFile, "previous-files")))
            assertTrue(root.mkdir())
            SharedPathFileObserverShadow.emit(root, FileObserver.MOVE_SELF, null)
            children("workspace/one").use { replacement ->
                var notifications = 0
                replacement.registerContentObserver(object : ContentObserver(null) {
                    override fun onChange(selfChange: Boolean) { notifications++ }
                })
                old.close()
                SharedPathFileObserverShadow.emit(root, FileObserver.CREATE, "new.txt")
                shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(200))
                assertEquals(1, notifications)
            }
        } finally {
            old.close()
        }
        assertTrue(SharedPathFileObserverShadow.activePaths().isEmpty())
    }

    @Test
    fun excludesLinkedFoldersAndInvalidWorkspaceIds() {
        workspace()
        workspace("linked", kind = "linked")
        workspace("../bad")
        assertEquals(listOf("workspace/one"), children().strings(Document.COLUMN_DOCUMENT_ID))
        assertThrows(FileNotFoundException::class.java) { provider.queryDocument("workspace/linked/kelivo.db", null) }
    }

    @Test
    fun rejectsTraversalUnknownWorkspacesAndCrossWorkspaceTrees() {
        val root = workspace()
        val other = workspace("two")
        File(root, "ok.txt").writeText("one")
        File(other, "ok.txt").writeText("two")
        for (id in listOf("workspace/one/../../../kelivo.db", "workspace/one/./ok.txt", "workspace/one//ok.txt", "workspace/one/a\u0000b", "workspace/unknown", "/etc/passwd")) {
            assertThrows(FileNotFoundException::class.java) { provider.queryDocument(id, null) }
        }
        assertFalse(provider.isChildDocument("workspace/one", "workspace/two/ok.txt"))
        assertFalse(provider.isChildDocument("workspace/one/ok.txt", "workspace/one/ok.txt"))
        assertFalse(provider.isChildDocument("workspaces", "workspace/unknown"))
    }

    @Test
    fun hidesEscapingSymlinksWhileAllowingInternalLinks() {
        val root = workspace()
        File(root, "ok.txt").writeText("ok")
        Files.createSymbolicLink(File(root, "private").toPath(), appData.toPath())
        Files.createSymbolicLink(File(root, "alias.txt").toPath(), File(root, "ok.txt").toPath())
        assertEquals(listOf("alias.txt", "ok.txt"), children("workspace/one").strings(Document.COLUMN_DISPLAY_NAME))
        assertThrows(FileNotFoundException::class.java) { provider.openDocument("workspace/one/private/kelivo.db", "r", null) }
    }

    @Test
    fun refusesRedirectedWorkspaceRoots() {
        val root = workspace()
        root.delete()
        Files.createSymbolicLink(root.toPath(), appData.toPath())
        assertTrue(children().strings(Document.COLUMN_DOCUMENT_ID).isEmpty())
        assertThrows(FileNotFoundException::class.java) { provider.queryDocument("workspace/one/kelivo.db", null) }
    }

    @Test
    fun aWorkspaceWithoutRestoredFilesRemainsAnEmptyFolder() {
        workspace().delete()
        assertEquals(listOf("工作区一"), children().strings(Document.COLUMN_DISPLAY_NAME))
        assertTrue(children("workspace/one").strings(Document.COLUMN_DOCUMENT_ID).isEmpty())
        assertEquals(Document.MIME_TYPE_DIR, provider.getDocumentType("workspace/one"))
    }

    @Test
    fun missingOrUnsupportedDatabaseIsNotCreatedOrChanged() {
        database.close()
        val file = File(appData, "kelivo.db")
        file.delete()
        assertTrue(children().strings(Document.COLUMN_DOCUMENT_ID).isEmpty())
        assertFalse(file.exists())
        file.writeText("not a sqlite database")
        val before = file.readBytes()
        assertTrue(children().strings(Document.COLUMN_DOCUMENT_ID).isEmpty())
        assertArrayEquals(before, file.readBytes())
    }

    @Test
    fun honorsCancellationBeforeOpening() {
        workspace()
        val signal = CancellationSignal().also { it.cancel() }
        assertThrows(OperationCanceledException::class.java) { provider.openDocument("workspace/one/file.txt", "r", signal) }
    }
}

/** Robolectric does not implement Linux /proc fd links on the host JVM. Only
 * that OS response is simulated; openDocument still opens and reads a real fd. */
@Implements(Os::class)
class DocumentDescriptorOsShadow {
    companion object {
        var openedPath: String? = null

        @JvmStatic
        @Implementation
        fun readlink(path: String): String {
            require(path.startsWith("/proc/self/fd/"))
            return checkNotNull(openedPath)
        }

        @JvmStatic
        @Resetter
        fun reset() { openedPath = null }
    }
}

/** Models Android's process-wide inotify instance: observers of the same path
 * share one watch, and stopping either observer removes that shared watch. */
@Implements(FileObserver::class)
class SharedPathFileObserverShadow {
    @RealObject
    private lateinit var observer: FileObserver
    private lateinit var path: String
    private var mask = 0
    private var watching = false

    @Implementation
    fun __constructor__(path: String, mask: Int) {
        this.path = path
        this.mask = mask
    }

    @Implementation
    fun startWatching() {
        if (!watching) {
            watches[path] = observer to mask
            watching = true
        }
    }

    @Implementation
    fun stopWatching() {
        if (watching) {
            watches.remove(path)
            watching = false
        }
    }

    companion object {
        private val watches = mutableMapOf<String, Pair<FileObserver, Int>>()

        fun activePaths(): Set<String> = watches.keys.toSet()

        fun emit(directory: File, event: Int, name: String?) {
            val (observer, mask) = watches[directory.path] ?: return
            if (event and mask != 0) observer.onEvent(event, name)
        }

        @JvmStatic
        @Resetter
        fun reset() { watches.clear() }
    }
}
