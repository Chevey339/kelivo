package com.psyche.kelivo.background

import android.app.Activity
import android.app.AppOpsManager
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Looper
import android.os.PowerManager
import android.view.View
import android.widget.LinearLayout
import com.psyche.kelivo.KelivoApplication
import com.psyche.kelivo.DeviceLocalToolsHandler
import org.json.JSONObject
import com.psyche.kelivo.workspace.WorkspacePlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.StandardMethodCodec
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowPowerManager
import org.robolectric.shadows.ShadowSettings
import org.robolectric.util.ReflectionHelpers
import java.io.File
import java.nio.ByteBuffer
import java.time.Duration

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28], application = KelivoApplication::class)
class BackgroundRuntimeTest {
    private class Messenger : BinaryMessenger {
        val handlers = mutableMapOf<String, BinaryMessenger.BinaryMessageHandler>()
        val events = mutableListOf<MethodCall>()
        override fun setMessageHandler(channel: String, handler: BinaryMessenger.BinaryMessageHandler?) {
            if (handler == null) handlers.remove(channel) else handlers[channel] = handler
        }
        override fun send(channel: String, message: ByteBuffer?) = send(channel, message, null)
        override fun send(channel: String, message: ByteBuffer?, callback: BinaryMessenger.BinaryReply?) {
            message?.flip()
            if (message != null) events += StandardMethodCodec.INSTANCE.decodeMethodCall(message)
            val reply = StandardMethodCodec.INSTANCE.encodeSuccessEnvelope(null)
            reply.flip()
            callback?.reply(reply)
        }
        fun call(method: String, args: Any? = null, channel: String = "app.mobile_background", reply: (Any?) -> Unit = {}) {
            val data = StandardMethodCodec.INSTANCE.encodeMethodCall(MethodCall(method, args))
            data.flip()
            handlers.getValue(channel).onMessage(data) { response ->
                response?.flip()
                reply(response?.let { StandardMethodCodec.INSTANCE.decodeEnvelope(it) })
            }
        }
    }

    private val app get() = RuntimeEnvironment.getApplication() as KelivoApplication

    @Test fun grantedScreenTimeToolRunsAfterItsActivityIsDestroyed() {
        val messenger = Messenger()
        val handler = DeviceLocalToolsHandler(app)
        handler.configure(messenger)
        val activity = Robolectric.buildActivity(Activity::class.java).setup()
        handler.attachActivity(activity.get())
        shadowOf(app.getSystemService(AppOpsManager::class.java)).setMode(
            AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(),
            app.packageName, AppOpsManager.MODE_ALLOWED)
        handler.detachActivity(activity.get())
        activity.pause().stop().destroy()
        var payload: Any? = null
        messenger.call("getScreenTime", "{\"range\":\"week\"}", DeviceLocalToolsHandler.CHANNEL_NAME) { payload = it }
        repeat(100) {
            if (payload == null) { Thread.sleep(10); shadowOf(Looper.getMainLooper()).idle() }
        }
        assertNotNull(payload)
        val result = JSONObject(payload as String)
        assertFalse(result.toString(), result.has("error"))
        assertTrue(result.has("total_ms"))
        assertTrue(result.has("apps"))
        handler.dispose()
    }
    private fun setup(): Pair<BackgroundRuntime, Messenger> {
        val messenger = Messenger()
        return app.backgroundRuntime.also { it.configure(messenger) } to messenger
    }
    private fun task(id: String) = mapOf("id" to id, "conversationId" to "chat-$id", "title" to id,
        "detail" to "Generating", "startedAt" to System.currentTimeMillis(), "tokens" to 7)
    private fun sync(m: Messenger, revision: Int, ids: List<String>, settings: Map<String, Any> = emptyMap(), terminal: Map<String, Any>? = null) {
        m.call("sync", mapOf("revision" to revision, "settings" to settings,
            "tasks" to ids.map(::task), "terminal" to terminal))
    }

    @Test fun defaultsDoNotStartAServiceAndStaleSnapshotsCannotReplaceTasks() {
        val (runtime, m) = setup()
        sync(m, 2, listOf("a", "b"))
        sync(m, 1, listOf("old"), mapOf("androidEnabled" to true))
        assertEquals(listOf("a", "b"), runtime.tasks.map { it.id })
        assertFalse(runtime.shouldRunService())
        assertNull(shadowOf(app).nextStartedService)
        assertFalse(runtime.status()["foregroundServiceActive"] as Boolean)
    }

    @Test fun removingTheActivityKeepsTasksAndWakeLockUntilLastCompletion() {
        val (runtime, m) = setup()
        val enabled = mapOf<String, Any>("androidEnabled" to true)
        sync(m, 1, listOf("a", "b"), enabled)
        val controller = Robolectric.buildService(GenerationForegroundService::class.java).create()
        val service = controller.get()
        service.onStartCommand(Intent(), 0, 1)
        val lock = ShadowPowerManager.getLatestWakeLock()
        assertTrue(lock.isHeld)
        runtime.setForeground(false)
        service.onTaskRemoved(Intent())
        assertTrue(runtime.shouldRunService())
        assertTrue(lock.isHeld)
        sync(m, 2, listOf("b"), enabled)
        assertTrue(lock.isHeld)
        sync(m, 3, emptyList(), enabled)
        assertFalse(lock.isHeld)
        assertNull(runtime.service)
        val notifications = app.getSystemService(NotificationManager::class.java).activeNotifications
        assertFalse(notifications.any { it.id == BackgroundRuntime.NOTIFICATION_ID })
        // Android may reuse the same Service if a new start races its teardown.
        sync(m, 4, listOf("retry"), enabled)
        service.onStartCommand(Intent(), 0, 2)
        val retryLock = ShadowPowerManager.getLatestWakeLock()
        assertTrue(retryLock.isHeld)
        sync(m, 5, emptyList(), enabled)
        assertFalse(retryLock.isHeld)
        controller.destroy()
    }

    @Test fun timeoutInterruptsActualRunsAndCannotRestartFromAQueuedUpdate() {
        val (runtime, m) = setup()
        val enabled = mapOf<String, Any>("androidEnabled" to true)
        sync(m, 1, listOf("a", "b"), enabled)
        val controller = Robolectric.buildService(GenerationForegroundService::class.java).create()
        controller.get().onStartCommand(Intent(), 0, 1)
        runtime.setForeground(false)
        controller.get().onTimeout(1, 1)
        val interruption = m.events.single { it.method == "interrupted" }
        assertEquals(listOf("a", "b"), (interruption.arguments as Map<*, *>)["ids"])
        assertFalse(ShadowPowerManager.getLatestWakeLock().isHeld)
        sync(m, 2, listOf("a", "b"), enabled)
        assertFalse(runtime.shouldRunService())
        assertEquals("foreground_service_timeout", runtime.status()["lastError"])
        controller.destroy()
    }

    @Test fun failedStartIsObservableAndDoesNotLoop() {
        val (runtime, m) = setup()
        val enabled = mapOf<String, Any>("androidEnabled" to true)
        sync(m, 1, listOf("a"), enabled)
        runtime.serviceFailed("foreground_service_failed")
        sync(m, 2, listOf("a"), enabled)
        assertFalse(runtime.shouldRunService())
        assertEquals("foreground_service_failed", runtime.status()["lastError"])
        runtime.setForeground(true)
        assertTrue(runtime.shouldRunService())
    }

    @Test fun overlayExpiresAndForegroundDoesNotResurrectItsFinishedCard() {
        val (runtime, m) = setup()
        ShadowSettings.setCanDrawOverlays(true)
        val settings = mapOf<String, Any>("overlayEnabled" to true, "completionSeconds" to 60)
        runtime.setForeground(false)
        sync(m, 1, listOf("a"), settings)
        assertEquals(true, runtime.status()["overlayVisible"])
        val terminal = task("a") + mapOf("finishedAt" to System.currentTimeMillis(), "outcome" to "completed")
        sync(m, 2, emptyList(), settings, terminal)
        assertEquals(true, runtime.status()["overlayVisible"])
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(61))
        assertEquals(false, runtime.status()["overlayVisible"])
        runtime.setForeground(true)
        runtime.setForeground(false)
        assertEquals(false, runtime.status()["overlayVisible"])
    }

    @Test fun overlayUsesSavedDimensionsAndIndependentContentVisibility() {
        val (runtime, m) = setup()
        ShadowSettings.setCanDrawOverlays(true)
        runtime.setForeground(false)
        val appearance = mapOf("width" to 240, "height" to 96, "iconSize" to 48,
            "progressSize" to 60, "progressStrokeWidth" to 5,
            "showTitle" to false, "showSubtitle" to false, "showTime" to true,
            "showClose" to false, "showBackground" to false, "showBorder" to false)
        val settings = mapOf("overlayEnabled" to true, "overlayAppearance" to appearance)
        sync(m, 1, listOf("a"), settings)
        val overlay = ReflectionHelpers.callInstanceMethod<BackgroundOverlay>(runtime, "getOverlay")
        val root = ReflectionHelpers.getField<LinearLayout>(overlay, "view")
        val density = app.resources.displayMetrics.density
        assertEquals((240 * density).toInt(), root.layoutParams.width)
        assertEquals((96 * density).toInt(), root.layoutParams.height)
        assertNull(root.background)
        assertNull(root.findViewWithTag<View>("title"))
        assertNull(root.findViewWithTag<View>("subtitle"))
        assertNull(root.findViewWithTag<View>("close"))
        assertNotNull(root.findViewWithTag<View>("time"))
        assertEquals((60 * density).toInt(), root.findViewWithTag<View>("progress").layoutParams.width)
        val terminal = task("a") + mapOf("finishedAt" to System.currentTimeMillis(), "outcome" to "completed")
        sync(m, 2, emptyList(), settings, terminal)
        assertEquals(View.GONE, root.findViewWithTag<View>("progress").visibility)
        root.performLongClick()
        assertEquals(false, runtime.status()["overlayVisible"])
    }

    @Test fun circularOverlayContainsOnlyArtworkAndProgressAndCanStillBeDismissed() {
        val (runtime, m) = setup()
        ShadowSettings.setCanDrawOverlays(true)
        runtime.setForeground(false)
        val settings = mapOf("overlayEnabled" to true, "overlayAppearance" to mapOf(
            "width" to 64, "height" to 64, "iconSize" to 48, "progressSize" to 60,
            "showTitle" to false, "showSubtitle" to false, "showTime" to false,
            "showClose" to false, "showBackground" to false))
        sync(m, 1, listOf("a"), settings)
        val overlay = ReflectionHelpers.callInstanceMethod<BackgroundOverlay>(runtime, "getOverlay")
        val root = ReflectionHelpers.getField<LinearLayout>(overlay, "view")
        assertEquals(1, root.childCount)
        assertNull(root.background)
        assertEquals(root.layoutParams.width, root.layoutParams.height)
        assertNotNull(root.findViewWithTag<View>("progress"))
        root.performLongClick()
        sync(m, 2, listOf("a"), settings)
        assertEquals(false, runtime.status()["overlayVisible"])
        sync(m, 3, listOf("new"), settings)
        assertEquals(true, runtime.status()["overlayVisible"])
    }

    @Test fun nativeConversationTapIsBufferedUntilDartIsReadyAndThenDeliveredOnce() {
        val (runtime, m) = setup()
        runtime.receiveConversation(Intent().putExtra(BackgroundRuntime.CONVERSATION_EXTRA, "cold"))
        var pending: Any? = null
        m.call("takePendingConversation") { pending = it }
        assertEquals("cold", pending)
        m.call("takePendingConversation") { pending = it }
        assertNull(pending)
        val intent = Intent().putExtra(BackgroundRuntime.CONVERSATION_EXTRA, "warm")
        runtime.receiveConversation(intent)
        runtime.receiveConversation(intent)
        assertEquals("warm", m.events.single { it.method == "openConversation" }.arguments)
    }

    @Test fun workspaceWorkCompletesAfterDetachAndAllowsANewActivityToBind() {
        val m = Messenger()
        val plugin = WorkspacePlugin(app)
        plugin.configure(m)
        val first = Robolectric.buildActivity(Activity::class.java).setup()
        plugin.attachActivity(first.get())
        val file = File(app.filesDir, "hash.txt").apply { writeText("abc") }
        var hash: Any? = null
        m.call("sha256File", mapOf("path" to file.path), "app.workspace") { hash = it }
        plugin.detachActivity(first.get())
        first.pause().stop().destroy()
        val second = Robolectric.buildActivity(Activity::class.java).setup()
        plugin.attachActivity(second.get())
        // Worker posts its result back to the same engine messenger after UI destruction.
        repeat(100) {
            if (hash == null) { Thread.sleep(10); shadowOf(Looper.getMainLooper()).idle() }
        }
        assertEquals("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", hash)
        plugin.detachActivity(second.get())
        plugin.dispose()
        second.pause().stop().destroy()
    }
}
