package com.psyche.kelivo

import android.app.Activity
import android.content.Intent
import android.content.pm.ProviderInfo
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.CancellationSignal
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.provider.DocumentsContract
import android.provider.DocumentsProvider
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterJNI
import io.flutter.embedding.engine.dart.PlatformMessageHandler
import io.flutter.embedding.engine.loader.FlutterLoader
import io.flutter.plugin.common.FlutterException
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.StandardMethodCodec
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.android.controller.ActivityController
import org.robolectric.annotation.Config
import org.robolectric.annotation.Implementation
import org.robolectric.annotation.Implements
import org.robolectric.shadow.api.Shadow
import org.robolectric.shadows.ShadowContentResolver
import java.io.File
import java.nio.ByteBuffer
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

@RunWith(RobolectricTestRunner::class)
@Config(
    sdk = [35],
    manifest = Config.NONE,
    application = KelivoApplication::class,
    shadows = [FileSaveEngineHandoffTest.NativeBoundary::class, FileSaveEngineHandoffTest.Loader::class],
)
class FileSaveEngineHandoffTest {
    // Keep the real FlutterEngine, Activity handoff, DartMessenger, and channel
    // handlers. Only replace the unavailable native Dart VM boundary.
    @Implements(value = FlutterJNI::class, callThroughByDefault = false)
    class NativeBoundary {
        lateinit var messages: PlatformMessageHandler
        val replies = mutableMapOf<Int, Any?>()

        @Implementation fun isAttached() = true
        @Implementation fun setPlatformMessageHandler(handler: PlatformMessageHandler?) {
            if (handler != null) messages = handler
        }
        @Implementation fun invokePlatformMessageEmptyResponseCallback(id: Int) {
            // An empty native reply becomes MissingPluginException in Dart.
            replies[id] = "MissingPluginException"
        }
        @Implementation fun invokePlatformMessageResponseCallback(id: Int, message: ByteBuffer, position: Int) {
            message.limit(position)
            message.position(0)
            replies[id] = try {
                StandardMethodCodec.INSTANCE.decodeEnvelope(message)
            } catch (error: FlutterException) {
                error
            }
        }
    }

    @Implements(value = FlutterLoader::class, callThroughByDefault = false)
    class Loader {
        @Implementation fun initialized() = true
        @Implementation fun findAppBundlePath() = "flutter_assets"
        @Implementation fun automaticallyRegisterPlugins() = false
    }

    private class DestinationProvider(private val file: File) : DocumentsProvider() {
        val deleted = CountDownLatch(1)

        override fun onCreate() = true
        override fun queryRoots(projection: Array<out String>?): Cursor = MatrixCursor(projection ?: emptyArray())
        override fun queryDocument(documentId: String, projection: Array<out String>?): Cursor =
            MatrixCursor(projection ?: emptyArray())
        override fun queryChildDocuments(parentDocumentId: String, projection: Array<out String>?, sortOrder: String?): Cursor =
            MatrixCursor(projection ?: emptyArray())
        override fun openDocument(documentId: String, mode: String, signal: CancellationSignal?): ParcelFileDescriptor =
            ParcelFileDescriptor.open(file, ParcelFileDescriptor.parseMode(mode))
        override fun deleteDocument(documentId: String) {
            check(file.delete())
            deleted.countDown()
        }
    }

    private lateinit var native: NativeBoundary
    private val activities = mutableListOf<ActivityController<MainActivity>>()
    private var nextReplyId = 1

    @Before fun setUp() {
        FlutterInjector.reset()
        val jni = FlutterJNI()
        native = Shadow.extract(jni)
        val injector = FlutterInjector.Builder()
            .setFlutterLoader(FlutterLoader())
            .setFlutterJNIFactory(object : FlutterJNI.Factory() {
                override fun provideFlutterJNI() = jni
            })
            .build()
        FlutterInjector.reset()
        FlutterInjector.setInstance(injector)
    }

    @After fun tearDown() {
        val application = activities.firstOrNull()?.get()?.application as? KelivoApplication
        activities.reversed().forEach { it.destroy() }
        if (application?.hasEngine == true) application.engine.destroy()
        FlutterInjector.reset()
    }

    private fun createActivity() = Robolectric.buildActivity(MainActivity::class.java)
        .also { activities += it }
        .create()

    private fun queueFileCall(method: String, arguments: Any? = null): Int {
        val id = nextReplyId++
        val message = StandardMethodCodec.INSTANCE.encodeMethodCall(
            MethodCall(method, arguments),
        )
        message.flip()
        native.messages.handleMessageFromDart("app.file_save", message, id, 0)
        return id
    }

    private fun callFile(method: String, arguments: Any? = null): Int {
        val id = queueFileCall(method, arguments)
        shadowOf(Looper.getMainLooper()).idle()
        return id
    }

    private fun awaitReply(id: Int): Any? {
        val deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(5)
        while (System.nanoTime() < deadline) {
            shadowOf(Looper.getMainLooper()).idle()
            if (native.replies.containsKey(id)) return native.replies[id]
            Thread.sleep(1)
        }
        throw AssertionError("No native reply for request $id")
    }

    @Test fun replacementActivityCanSaveAfterPreviousActivityIsDestroyed() {
        val previous = createActivity()
        assertSavePickerWorks(previous.get())
        val engine = (previous.get().application as KelivoApplication).engine
        val replacement = createActivity()
        assertSame(engine, (replacement.get().application as KelivoApplication).engine)
        assertSavePickerWorks(replacement.get())

        previous.destroy()
        activities.remove(previous)
        assertSavePickerWorks(replacement.get())
    }

    @Test fun saveCopiesBackupAfterPreviousActivityIsDestroyed() {
        val previous = createActivity()
        val replacement = createActivity()
        previous.destroy()
        activities.remove(previous)

        val activity = replacement.get()
        val (id, picker) = openSavePicker(activity)
        val destination = File(activity.cacheDir, "saved-backup.zip")
        val uri = Uri.parse("content://export.test/backup")
        val entered = CountDownLatch(1)
        val worker = AtomicReference<Thread>()
        shadowOf(activity.contentResolver).registerOutputStreamSupplier(uri) {
            worker.set(Thread.currentThread())
            entered.countDown()
            destination.outputStream()
        }

        shadowOf(activity).receiveResult(picker, Activity.RESULT_OK, Intent().setData(uri))
        assertTrue("The backup copy must start", entered.await(5, TimeUnit.SECONDS))
        worker.get().join(5_000)
        assertFalse("The backup copy must finish", worker.get().isAlive)
        shadowOf(Looper.getMainLooper()).idle()
        assertEquals(true, native.replies[id])
        assertEquals("backup bytes", destination.readText())
    }

    @Test fun engineHandoffCancelsOldPickerWithoutBreakingTheNewOne() {
        val previous = createActivity()
        val (id, picker) = openSavePicker(previous.get())
        val replacement = createActivity()

        val cancellation = native.replies[id]
        assertTrue("The detached Activity must cancel its pending save", cancellation is FlutterException)
        assertEquals("cancelled", (cancellation as FlutterException).code)
        shadowOf(previous.get()).receiveResult(picker, Activity.RESULT_CANCELED, Intent())
        previous.destroy()
        activities.remove(previous)
        assertSame(cancellation, native.replies[id])
        assertSavePickerWorks(replacement.get())
    }

    @Test fun activityCanSaveWhenReopenedOnTheRetainedEngine() {
        val previous = createActivity()
        val engine = (previous.get().application as KelivoApplication).engine
        previous.destroy()
        activities.remove(previous)

        val replacement = createActivity()
        assertSame(engine, (replacement.get().application as KelivoApplication).engine)
        assertSavePickerWorks(replacement.get())
    }

    @Test fun queuedCompletionCannotSucceedAfterHandoffDiscardsTheDestination() {
        val previous = createActivity()
        val activity = previous.get()
        val destination = File(activity.cacheDir, "pending-backup.zip")
        val provider = DestinationProvider(destination)
        val authority = "export.test"
        provider.attachInfo(activity, ProviderInfo().apply {
            this.authority = authority
            exported = true
            grantUriPermissions = true
            readPermission = "android.permission.MANAGE_DOCUMENTS"
            writePermission = "android.permission.MANAGE_DOCUMENTS"
        })
        ShadowContentResolver.registerProviderInternal(authority, provider)
        val uri = DocumentsContract.buildDocumentUri(authority, "backup")
        val opened = callFile("createWritableFile", mapOf("fileName" to "pending-backup.zip"))
        val picker = shadowOf(activity).nextStartedActivityForResult
        shadowOf(activity).receiveResult(picker.intent, Activity.RESULT_OK, Intent().setData(uri))
        assertEquals(true, native.replies[opened])
        assertTrue(destination.exists())

        // Capture the old handler without dispatching it until after detach.
        val completion = queueFileCall("completeWritableFile")
        createActivity()
        assertTrue("Detach must discard the unfinished backup", provider.deleted.await(5, TimeUnit.SECONDS))
        assertFalse(destination.exists())
        shadowOf(Looper.getMainLooper()).idle()

        val reply = awaitReply(completion)
        assertTrue("An obsolete completion must be cancelled, got $reply", reply is FlutterException)
        assertEquals("cancelled", (reply as FlutterException).code)
    }

    @Test fun queuedSaveCannotOpenAPickerOnTheDetachedActivity() {
        val previous = createActivity()
        val source = File(previous.get().cacheDir, "backup.zip").apply { writeText("backup bytes") }
        val save = queueFileCall("saveFileFromPath", mapOf("sourcePath" to source.path))
        val replacement = createActivity()
        shadowOf(Looper.getMainLooper()).idle()

        val reply = native.replies[save]
        assertTrue("An obsolete save must be cancelled, got $reply", reply is FlutterException)
        assertEquals("cancelled", (reply as FlutterException).code)
        assertNull(shadowOf(previous.get()).nextStartedActivityForResult)
        assertSavePickerWorks(replacement.get())
    }

    private fun openSavePicker(activity: MainActivity): Pair<Int, Intent> {
        val source = File(activity.cacheDir, "backup.zip").apply { writeText("backup bytes") }
        val id = callFile("saveFileFromPath", mapOf("sourcePath" to source.path, "fileName" to source.name))
        assertFalse(
            "saveFileFromPath lost its native handler: ${native.replies[id]}",
            native.replies.containsKey(id),
        )
        val picker = shadowOf(activity).nextStartedActivityForResult
        assertNotNull("The replacement Activity must open the save picker", picker)
        assertEquals(Intent.ACTION_CREATE_DOCUMENT, picker.intent.action)
        assertEquals("backup.zip", picker.intent.getStringExtra(Intent.EXTRA_TITLE))
        return id to picker.intent
    }

    private fun assertSavePickerWorks(activity: MainActivity) {
        val (id, picker) = openSavePicker(activity)
        shadowOf(activity).receiveResult(picker, Activity.RESULT_CANCELED, Intent())
        assertEquals(false, native.replies[id])
    }
}
