package com.psyche.kelivo

import android.content.ClipData
import android.content.ContentProvider
import android.content.ContentValues
import android.content.Intent
import android.content.pm.ProviderInfo
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.provider.OpenableColumns
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.StandardMethodCodec
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowContentResolver
import java.io.File
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.util.concurrent.CompletableFuture

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28], manifest = Config.NONE)
class IncomingShareHandlerTest {
    private val context get() = RuntimeEnvironment.getApplication()
    private lateinit var source: File
    private lateinit var output: File
    private lateinit var provider: SourceProvider

    @Before fun setUp() {
        source = File(context.cacheDir, "shared-source").apply { writeText("original bytes") }
        output = File(context.cacheDir, "incoming-test").apply { mkdirs() }
        provider = SourceProvider(source)
        provider.attachInfo(context, ProviderInfo().apply { authority = "share.test" })
        ShadowContentResolver.registerProviderInternal("share.test", provider)
    }

    @After fun tearDown() {
        output.deleteRecursively()
        source.delete()
        File(context.filesDir, "incoming_shares").deleteRecursively()
    }

    private fun uri(name: String) = Uri.parse("content://share.test/$name")
    private fun share(vararg uris: Uri) = Intent(Intent.ACTION_SEND_MULTIPLE).apply {
        type = "image/png"
        putParcelableArrayListExtra(Intent.EXTRA_STREAM, arrayListOf(*uris))
    }

    @Test fun clipDataDoesNotDuplicateExtraStreams() {
        val intent = share(uri("one"))
        intent.clipData = ClipData.newRawUri("photo", uri("one")).apply {
            addItem(ClipData.Item(uri("two")))
        }
        assertEquals(listOf(uri("one"), uri("two")), IncomingShareHandler.collectUris(intent))
    }

    @Test fun singleShareAndOpenWithBothCopyTheDocument() {
        val intents = listOf(
            Intent(Intent.ACTION_SEND).putExtra(Intent.EXTRA_STREAM, uri("one")),
            Intent(Intent.ACTION_VIEW).setDataAndType(uri("one"), "image/png"),
        )
        for ((index, intent) in intents.withIndex()) {
            val payload = IncomingShareHandler.copyShare(context, intent, File(output, index.toString()), "test")
            assertEquals(0, payload.getInt("failedFiles"))
            val file = payload.getJSONArray("files").getJSONObject(0)
            assertEquals("original bytes", File(file.getString("path")).readText())
        }
    }

    @Test fun copiesFilesWithSafeNamesAndKeepsDuplicateNamesDistinct() {
        provider.name = "../图片.png"
        val payload = IncomingShareHandler.copyShare(context, share(uri("one"), uri("two")), output, "test")
        val files = payload.getJSONArray("files")
        assertEquals(2, files.length())
        assertEquals("图片.png", files.getJSONObject(0).getString("name"))
        val first = File(files.getJSONObject(0).getString("path"))
        val second = File(files.getJSONObject(1).getString("path"))
        assertNotEquals(first, second)
        source.delete()
        assertEquals("original bytes", first.readText())
        assertEquals("original bytes", second.readText())
    }

    @Test fun rejectsFileUrisAndStillReceivesOtherAttachments() {
        val payload = IncomingShareHandler.copyShare(context, share(Uri.fromFile(source), uri("one")), output, "test")
        assertEquals(1, payload.getInt("failedFiles"))
        assertEquals(1, payload.getJSONArray("files").length())
        assertTrue(source.exists())
    }

    @Test fun rejectsOwnPrivateContentProvidersBeforeOpeningTheirFiles() {
        val authority = context.packageName + ".fileProvider.com.crazecoder.openfile"
        val info = ProviderInfo().apply {
            this.authority = authority
            packageName = context.packageName
            applicationInfo = context.applicationInfo
            name = "com.crazecoder.openfile.FileProvider"
        }
        shadowOf(context.packageManager).addOrUpdateProvider(info)
        ShadowContentResolver.registerProviderInternal(authority, provider)
        for (prefix in listOf("", "0@")) {
            val ownUri = Uri.parse("content://$prefix$authority/private/database.db")
            val payload = IncomingShareHandler.copyShare(context, share(ownUri, uri("public")), output, "test")
            assertEquals(1, payload.getInt("failedFiles"))
            assertEquals(1, payload.getJSONArray("files").length())
        }
        // Only the two external-provider attachments were opened.
        assertEquals(2, provider.openCount)
    }

    @Test fun acceptsLargeMetadataAndCopiesTheActualStream() {
        provider.reportedSize = 2L * 1024 * 1024 * 1024
        val payload = IncomingShareHandler.copyShare(context, share(uri("one")), output, "test")
        assertEquals(0, payload.getInt("failedFiles"))
        assertEquals(1, provider.openCount)
        assertEquals("original bytes", File(payload.getJSONArray("files").getJSONObject(0).getString("path")).readText())
    }

    @Test fun streamsFilesAboveTheOldLimitWithoutAReportedSize() {
        val bytes = 129L * 1024 * 1024
        RandomAccessFile(source, "rw").use { it.setLength(bytes) }
        provider.reportedSize = null
        var lastProgress = 0L
        val payload = IncomingShareHandler.copyShare(context, share(uri("one")), output, "test",
            onProgress = { lastProgress = it["bytes"] as Long })
        assertEquals(0, payload.getInt("failedFiles"))
        assertEquals(bytes, File(payload.getJSONArray("files").getJSONObject(0).getString("path")).length())
        assertEquals(bytes, lastProgress)
    }

    @Test fun cancellationRemovesThePartialFile() {
        var cancelled = false
        try {
            IncomingShareHandler.copyShare(context, share(uri("one")), output, "test",
                isCancelled = { cancelled }, onProgress = { cancelled = true })
            fail("Expected cancellation")
        } catch (_: java.util.concurrent.CancellationException) { }
        assertFalse(output.walk().any { it.isFile })
        assertTrue(source.exists())
    }

    @Test fun acceptsPublicFileUrisButNotAppPrivateFiles() {
        val external = File.createTempFile("kelivo-share", ".zip")
        try {
            external.writeText("public bytes")
            val payload = IncomingShareHandler.copyShare(context, share(Uri.fromFile(external)), output, "test")
            assertEquals(0, payload.getInt("failedFiles"))
            assertEquals("public bytes", File(payload.getJSONArray("files").getJSONObject(0).getString("path")).readText())
        } finally { external.delete() }
    }

    @Test fun limitsTheAttachmentCountAndPreservesSharedText() {
        val intent = share(*(0..32).map { uri("file$it") }.toTypedArray())
        intent.putExtra(Intent.EXTRA_TEXT, "说明 https://example.com/")
        val payload = IncomingShareHandler.copyShare(context, intent, output, "test")
        assertEquals(32, payload.getJSONArray("files").length())
        assertEquals(1, payload.getInt("failedFiles"))
        assertEquals("说明 https://example.com/", payload.getString("text"))
    }

    @Test fun coldInboxSurvivesHandlerRecreationUntilExplicitlyAcknowledged() {
        val firstMessenger = Messenger()
        val first = IncomingShareHandler(context, firstMessenger)
        assertFalse(first.receive(Intent(Intent.ACTION_VIEW, Uri.parse("https://example.com"))))
        assertTrue(first.receive(Intent(Intent.ACTION_SEND).putExtra(Intent.EXTRA_TEXT, "draft")))
        val pending = firstMessenger.call("getPendingShares") as List<*>
        assertEquals(1, pending.size)
        first.dispose()
        val secondMessenger = Messenger()
        val second = IncomingShareHandler(context, secondMessenger)
        assertEquals(pending, secondMessenger.call("getPendingShares"))
        val id = (pending.single() as Map<*, *>)["id"] as String
        secondMessenger.call("acknowledgeShares", listOf(id))
        assertEquals(emptyList<Any>(), secondMessenger.call("getPendingShares"))
        second.dispose()
    }

    private class SourceProvider(private val source: File) : ContentProvider() {
        var name = "photo.png"
        var reportedSize: Long? = source.length()
        var openCount = 0
        override fun onCreate() = true
        override fun getType(uri: Uri) = "image/png"
        override fun query(uri: Uri, projection: Array<out String>?, selection: String?, selectionArgs: Array<out String>?, sortOrder: String?): Cursor =
            MatrixCursor(arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE)).apply { addRow(arrayOf(name, reportedSize)) }
        override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor {
            openCount++
            return ParcelFileDescriptor.open(source, ParcelFileDescriptor.MODE_READ_ONLY)
        }
        override fun insert(uri: Uri, values: ContentValues?): Uri? = null
        override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?) = 0
        override fun update(uri: Uri, values: ContentValues?, selection: String?, selectionArgs: Array<out String>?) = 0
    }

    private class Messenger : BinaryMessenger {
        private var handler: BinaryMessenger.BinaryMessageHandler? = null
        override fun send(channel: String, message: ByteBuffer?) = Unit
        override fun send(channel: String, message: ByteBuffer?, callback: BinaryMessenger.BinaryReply?) { callback?.reply(null) }
        override fun setMessageHandler(channel: String, handler: BinaryMessenger.BinaryMessageHandler?) { this.handler = handler }
        fun call(method: String, arguments: Any? = null): Any? {
            val result = CompletableFuture<Any?>()
            val bytes = StandardMethodCodec.INSTANCE.encodeMethodCall(MethodCall(method, arguments)).apply { flip() }
            handler!!.onMessage(bytes) { reply ->
                try { result.complete(StandardMethodCodec.INSTANCE.decodeEnvelope(reply!!.apply { flip() })) }
                catch (error: Exception) { result.completeExceptionally(error) }
            }
            val deadline = System.nanoTime() + 5_000_000_000L
            while (!result.isDone && System.nanoTime() < deadline) {
                shadowOf(Looper.getMainLooper()).idle()
                Thread.sleep(5)
            }
            check(result.isDone) { "Incoming share channel did not reply" }
            return result.get()
        }
    }
}
