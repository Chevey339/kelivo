package com.psyche.kelivo

import android.content.Intent
import android.net.Uri
import android.os.Looper
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleRegistry
import io.flutter.plugin.common.MethodChannel
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import java.io.File
import java.io.IOException
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], manifest = Config.NONE, application = KelivoApplication::class)
class FileSaveLifecycleTest {
    private class Result : MethodChannel.Result {
        val replies = mutableListOf<String>()
        override fun success(result: Any?) { replies += "success:$result" }
        override fun error(code: String, message: String?, details: Any?) { replies += "error:$code" }
        override fun notImplemented() { replies += "notImplemented" }
    }

    private lateinit var activity: MainActivity
    private lateinit var directory: File
    private var destroyed = false

    @Before fun setUp() {
        activity = Robolectric.buildActivity(MainActivity::class.java).get()
        // Exercise onDestroy without starting a Flutter engine in this native test.
        (activity.lifecycle as LifecycleRegistry).handleLifecycleEvent(Lifecycle.Event.ON_CREATE)
        directory = File(activity.cacheDir, "export-test").apply { mkdirs() }
    }

    @After fun tearDown() {
        if (!destroyed) destroy()
        directory.deleteRecursively()
    }

    private fun destroy() {
        destroyed = true
        MainActivity::class.java.getDeclaredMethod("onDestroy")
            .also { it.isAccessible = true }.invoke(activity)
    }

    private fun begin(source: File, result: Result) {
        MainActivity::class.java.getDeclaredMethod(
            "handleSaveFileFromPath", Any::class.java, MethodChannel.Result::class.java,
        ).also { it.isAccessible = true }.invoke(
            activity, mapOf("sourcePath" to source.path, "fileName" to source.name), result,
        )
    }

    private fun choose(uri: Uri?) {
        MainActivity::class.java.getDeclaredMethod("handleSaveDestination", Uri::class.java)
            .also { it.isAccessible = true }.invoke(activity, uri)
    }

    private fun finishWorker(thread: Thread) {
        thread.join(5_000)
        assertFalse("Copy worker did not finish", thread.isAlive)
        shadowOf(Looper.getMainLooper()).idle()
    }

    private fun copyAcrossDestroy(fail: Boolean, destroyBeforeReply: Boolean) {
        val source = File(directory, "source.bin").apply { writeText("source bytes") }
        val destination = File(directory, "saved.bin")
        val uri = Uri.parse("content://export.test/destination")
        val entered = CountDownLatch(1)
        val proceed = CountDownLatch(1)
        val worker = AtomicReference<Thread>()
        shadowOf(activity.contentResolver).registerOutputStreamSupplier(uri) {
            worker.set(Thread.currentThread())
            entered.countDown()
            check(proceed.await(5, TimeUnit.SECONDS))
            if (fail) throw IOException("Destination no longer available")
            destination.outputStream()
        }
        val result = Result()
        begin(source, result)
        assertTrue(result.replies.toString(), result.replies.isEmpty())
        choose(uri)
        try {
            assertTrue(entered.await(5, TimeUnit.SECONDS))
            if (destroyBeforeReply) destroy()
        } finally {
            proceed.countDown()
            worker.get()?.let { finishWorker(it) }
        }
        if (!destroyBeforeReply) destroy()
        assertEquals(
            listOf(if (destroyBeforeReply) "error:cancelled" else if (fail) "error:save_failed" else "success:true"),
            result.replies,
        )
        assertEquals("source bytes", source.readText())
    }

    @Test fun destroyBeforeCopySuccessRepliesOnlyOnce() = copyAcrossDestroy(false, true)

    @Test fun destroyBeforeCopyFailureRepliesOnlyOnce() = copyAcrossDestroy(true, true)

    @Test fun successBeforeDestroyIsNotCancelledAgain() = copyAcrossDestroy(false, false)

    @Test fun failureBeforeDestroyIsNotCancelledAgain() = copyAcrossDestroy(true, false)

    @Test fun cancelledPickerDoesNotReplyAgainOnDestroy() {
        val source = File(directory, "source").apply { writeText("keep") }
        val result = Result()
        begin(source, result)
        choose(null)
        destroy()
        assertEquals(listOf("success:false"), result.replies)
        assertEquals("keep", source.readText())
    }

    @Test fun trailingSpacePathOpensEvenWhenTrimmedFileDoesNotExist() {
        val source = File(directory, "report.txt ").apply { writeText("chosen file") }
        val result = Result()
        begin(source, result)
        assertTrue(result.replies.toString(), result.replies.isEmpty())
        val intent = shadowOf(activity).nextStartedActivity
        assertEquals("report.txt ", intent.getStringExtra(Intent.EXTRA_TITLE))
        choose(null)
    }

    @Test fun trailingSpacePathCopiesTheSelectedFileInsteadOfItsNeighbour() {
        File(directory, "report.txt").writeText("wrong file")
        val source = File(directory, "report.txt ").apply { writeText("chosen file") }
        val result = Result()
        begin(source, result)
        val destination = File(directory, "saved")
        val entered = CountDownLatch(1)
        val worker = AtomicReference<Thread>()
        val uri = Uri.parse("content://export.test/spaces")
        shadowOf(activity.contentResolver).registerOutputStreamSupplier(uri) {
            worker.set(Thread.currentThread())
            entered.countDown()
            destination.outputStream()
        }
        choose(uri)
        assertTrue(entered.await(5, TimeUnit.SECONDS))
        finishWorker(worker.get())
        assertEquals(listOf("success:true"), result.replies)
        assertEquals("chosen file", destination.readText())
    }
}
