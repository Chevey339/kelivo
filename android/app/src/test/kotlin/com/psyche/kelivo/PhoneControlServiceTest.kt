package com.psyche.kelivo

import android.app.Application
import android.accessibilityservice.AccessibilityService
import android.app.KeyguardManager
import android.graphics.Rect
import android.os.Looper
import android.os.SystemClock
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import org.json.JSONObject
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import java.time.Duration
import java.util.concurrent.ExecutorService
import java.util.concurrent.TimeUnit
import org.robolectric.util.ReflectionHelpers
import org.robolectric.annotation.Implementation
import org.robolectric.annotation.Implements
import org.robolectric.shadows.ShadowAccessibilityService
import java.util.concurrent.CountDownLatch
import java.util.concurrent.atomic.AtomicInteger

@Suppress("DEPRECATION")
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28, 35], manifest = Config.NONE, application = Application::class,
    shadows = [PhoneControlServiceTest.QueryServiceShadow::class])
class PhoneControlServiceTest {
    @Implements(AccessibilityService::class)
    class QueryServiceShadow : ShadowAccessibilityService() {
        companion object { @Volatile var query: (() -> Unit)? = null }
        @Implementation override fun getRootInActiveWindow(): AccessibilityNodeInfo? {
            query?.invoke()
            return super.getRootInActiveWindow()
        }
    }
    private lateinit var service: PhoneControlService
    private lateinit var root: AccessibilityNodeInfo

    @Before fun setup() {
        QueryServiceShadow.query = null
        service = Robolectric.buildService(PhoneControlService::class.java).create().get()
        root = node("Screen")
        shadowOf(service).setRootInActiveWindow(root)
    }

    private val executor get() = ReflectionHelpers.getField<ExecutorService>(service, "executor")

    private fun flush() {
        repeat(3) {
            executor.submit {}.get(3, TimeUnit.SECONDS)
            shadowOf(Looper.getMainLooper()).idle()
        }
    }

    @After fun teardown() {
        QueryServiceShadow.query = null
        service.onDestroy()
        assertTrue(executor.awaitTermination(3, TimeUnit.SECONDS))
        shadowOf(Looper.getMainLooper()).idle()
    }

    private fun node(text: String) = AccessibilityNodeInfo.obtain().apply {
        this.text = text
        packageName = "example.app"
        className = "android.widget.TextView"
        isVisibleToUser = true
        isEnabled = true
        setBoundsInScreen(Rect(0, 0, 100, 100))
    }

    private fun call(args: JSONObject): JSONObject {
        var result: JSONObject? = null
        service.execute(args.toString()) { result = it }
        flush()
        return requireNotNull(result)
    }

    private fun call(action: String) = call(JSONObject().put("action", action))

    private fun action(name: String, snapshot: JSONObject) = JSONObject()
        .put("action", name).put("snapshot_id", snapshot.getString("snapshot_id"))

    @Test fun missingServiceDoesNotExecute() {
        var result = ""
        PhoneControlService.execute( "{\"action\":\"home\"}") { result = it }
        assertEquals("SERVICE_UNAVAILABLE", JSONObject(result).getString("error"))
        assertTrue(shadowOf(service).globalActionsPerformed.isEmpty())
    }

    @Test fun passwordTextAndDescendantsAreNotExposed() {
        val password = node("secret-value").apply {
            isPassword = true
            isEditable = true
            contentDescription = "secret-description"
        }
        shadowOf(password).addChild(node("secret-descendant"))
        shadowOf(root).addChild(password)
        val result = call("read_screen")
        assertEquals(2, result.getJSONArray("nodes").length())
        assertFalse(result.toString().contains("secret"))
        assertTrue(result.getJSONArray("nodes").getJSONObject(1).getBoolean("password"))
    }

    @Test fun snapshotIsBounded() {
        repeat(400) { shadowOf(root).addChild(node("item $it")) }
        val result = call("read_screen")
        assertEquals(350, result.getJSONArray("nodes").length())
        assertTrue(result.getBoolean("truncated"))
    }

    @Test fun noActiveWindowReturnsRecoverableError() {
        shadowOf(service).setRootInActiveWindow(null)
        assertEquals("NO_WINDOW", call("read_screen").getString("error"))
    }

    @Test fun lockedPhoneCannotReadOrAct() {
        shadowOf(service.getSystemService(KeyguardManager::class.java)).setKeyguardLocked(true)
        assertEquals("DEVICE_LOCKED", call("read_screen").getString("error"))
        assertEquals("DEVICE_LOCKED", call("home").getString("error"))
        assertTrue(shadowOf(service).globalActionsPerformed.isEmpty())
    }

    @Test fun oldSnapshotCannotBeReusedAfterReadNavigationOrWindowChange() {
        var snapshot = call("read_screen")
        call("read_screen")
        assertEquals("STALE_SCREEN", call(action("tap", snapshot).put("node_id", "n0")).getString("error"))
        snapshot = call("read_screen")
        call("back")
        assertEquals("STALE_SCREEN", call(action("tap", snapshot).put("node_id", "n0")).getString("error"))
        snapshot = call("read_screen")
        shadowOf(service).setRootInActiveWindow(node("Changed window"))
        service.onAccessibilityEvent(AccessibilityEvent.obtain(AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED).apply {
            eventTime = SystemClock.uptimeMillis()
        })
        assertEquals("STALE_SCREEN", call(action("tap", snapshot).put("node_id", "n0")).getString("error"))
        snapshot = call("read_screen")
        shadowOf(service).setRootInActiveWindow(node("Changed layout"))
        service.onAccessibilityEvent(AccessibilityEvent.obtain(AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED).apply {
            contentChangeTypes = AccessibilityEvent.CONTENT_CHANGE_TYPE_SUBTREE
            eventTime = SystemClock.uptimeMillis()
        })
        assertEquals("STALE_SCREEN", call(action("tap", snapshot).put("x", 10).put("y", 10)).getString("error"))
    }

    @Test fun noisyLayoutEventsRevalidateTheTreeWithoutRejectingUnchangedContent() {
        shadowOf(service).setCanDispatchGestures(false)
        val snapshot = call("read_screen")
        service.onAccessibilityEvent(AccessibilityEvent.obtain(AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED).apply {
            contentChangeTypes = AccessibilityEvent.CONTENT_CHANGE_TYPE_SUBTREE
            eventTime = SystemClock.uptimeMillis()
        })
        val result = call(action("tap", snapshot).put("x", 10).put("y", 10))
        assertEquals("GESTURE_REJECTED", result.getString("error"))
    }

    @Test fun aDelayedOldEventCannotInvalidateANewerRead() {
        shadowOf(service).setCanDispatchGestures(false)
        val snapshot = call("read_screen")
        service.onAccessibilityEvent(AccessibilityEvent.obtain(AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED).apply {
            eventTime = SystemClock.uptimeMillis() - 1
        })
        val result = call(action("tap", snapshot).put("x", 10).put("y", 10))
        assertEquals("GESTURE_REJECTED", result.getString("error"))
    }

    @Test fun snapshotExpiresAndCannotBeUsedInAnotherApp() {
        var snapshot = call("read_screen")
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(31))
        assertEquals("STALE_SCREEN", call(action("tap", snapshot).put("node_id", "n0")).getString("error"))
        snapshot = call("read_screen")
        shadowOf(service).setRootInActiveWindow(node("Other").apply { packageName = "other.app" })
        assertEquals("STALE_SCREEN", call(action("tap", snapshot).put("node_id", "n0")).getString("error"))
    }

    @Test fun detachedNodeDoesNotReceiveAnAction() {
        shadowOf(root).setRefreshReturnValue(false)
        val result = call(action("tap", call("read_screen")).put("node_id", "n0"))
        assertEquals("STALE_NODE", result.getString("error"))
    }

    @Test fun setTextAllowsClearingAndReturnsActualActionFailure() {
        root.isEditable = true
        root.addAction(AccessibilityNodeInfo.ACTION_SET_TEXT)
        shadowOf(root).setRefreshReturnValue(true)
        var received: String? = null
        shadowOf(root).setOnPerformActionListener { action, bundle ->
            assertEquals(AccessibilityNodeInfo.ACTION_SET_TEXT, action)
            received = bundle.getCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE)?.toString()
            false
        }
        val args = action("set_text", call("read_screen")).put("node_id", "n0").put("text", "")
        assertEquals("ACTION_FAILED", call(args).getString("error"))
        assertEquals("", received)
        assertEquals("STALE_SCREEN", call(args).getString("error"))
    }

    @Test fun unfocusedEditableCannotFalselyReportSuccessfulInput() {
        root.isEditable = true
        shadowOf(root).setRefreshReturnValue(true)
        shadowOf(root).setOnPerformActionListener { _, _ -> fail("Unsupported action must not be called"); true }
        val snapshot = call("read_screen")
        assertFalse(snapshot.getJSONArray("nodes").getJSONObject(0).getBoolean("supports_set_text"))
        val result = call(action("set_text", snapshot).put("node_id", "n0").put("text", "Hello"))
        assertEquals("ACTION_UNAVAILABLE", result.getString("error"))
    }

    @Test fun invalidCoordinatesAndDurationsDoNotDispatch() {
        val snapshot = call("read_screen")
        for (x in listOf(-1, snapshot.getInt("width"), "50")) {
            assertEquals("INVALID_ARGUMENT", call(action("tap", snapshot).put("x", x).put("y", 10)).getString("error"))
        }
        assertEquals("INVALID_ARGUMENT", call(action("long_press", snapshot)
            .put("x", 10).put("y", 10).put("duration_ms", 80)).getString("error"))
        assertTrue(shadowOf(service).gesturesDispatched.isEmpty())
    }

    @Test fun gestureWaitsForCompletionAndRejectsOverlappingCalls() {
        shadowOf(service).setCanDispatchGestures(true)
        val args = action("tap", call("read_screen")).put("x", 10).put("y", 10)
        val results = mutableListOf<JSONObject>()
        service.execute(args.toString()) { results.add(it) }
        flush()
        assertTrue(results.isEmpty())
        assertEquals("BUSY", call("home").getString("error"))
        val gesture = shadowOf(service).gesturesDispatched.single()
        gesture.callback().onCompleted(gesture.description())
        flush()
        assertTrue(results.single().getBoolean("success"))
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(6))
        assertEquals(1, results.size)
        assertEquals("STALE_SCREEN", call(args).getString("error"))
    }

    @Test fun gestureCancellationTimeoutAndDisconnectResolveExactlyOnce() {
        shadowOf(service).setCanDispatchGestures(true)
        for (failure in listOf("cancel", "timeout", "disconnect")) {
            val args = action("swipe", call("read_screen"))
                .put("x", 10).put("y", 10).put("end_x", 20).put("end_y", 50)
            val results = mutableListOf<JSONObject>()
            service.execute(args.toString()) { results.add(it) }
            flush()
            val gesture = shadowOf(service).gesturesDispatched.last()
            when (failure) {
                "cancel" -> gesture.callback().onCancelled(gesture.description())
                "timeout" -> shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(6))
                else -> service.onInterrupt()
            }
            flush()
            assertEquals(1, results.size)
            assertTrue(results.single().has("error"))
            gesture.callback().onCompleted(gesture.description())
            flush()
            assertEquals(1, results.size)
        }
    }

    @Test fun rejectedGestureCompletesImmediately() {
        shadowOf(service).setCanDispatchGestures(false)
        val args = action("tap", call("read_screen")).put("x", 10).put("y", 10)
        assertEquals("GESTURE_REJECTED", call(args).getString("error"))
        assertFalse(call("read_screen").has("error"))
    }

    @Test fun textOnlyChangesInvalidateCoordinateActions() {
        val snapshot = call("read_screen")
        shadowOf(service).setRootInActiveWindow(node("Different text"))
        service.onAccessibilityEvent(AccessibilityEvent.obtain(AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED).apply {
            eventTime = SystemClock.uptimeMillis()
            contentChangeTypes = AccessibilityEvent.CONTENT_CHANGE_TYPE_TEXT
        })
        val result = call(action("tap", snapshot).put("x", 10).put("y", 10))
        assertEquals("STALE_SCREEN", result.getString("error"))
        assertTrue(shadowOf(service).gesturesDispatched.isEmpty())
    }

    @Test @Config(sdk = [35]) fun stateDescriptionChangesInvalidateCoordinates() {
        root.stateDescription = "Not connected"
        val snapshot = call("read_screen")
        shadowOf(service).setRootInActiveWindow(node("Screen").apply { stateDescription = "Connected" })
        service.onAccessibilityEvent(AccessibilityEvent.obtain(AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED).apply {
            eventTime = SystemClock.uptimeMillis()
            contentChangeTypes = AccessibilityEvent.CONTENT_CHANGE_TYPE_STATE_DESCRIPTION
        })
        assertEquals("STALE_SCREEN", call(action("tap", snapshot).put("x", 10).put("y", 10)).getString("error"))
        assertTrue(shadowOf(service).gesturesDispatched.isEmpty())
    }

    @Test fun aSwitchChangedSinceReadCannotBeClickedEvenWithoutAnEvent() {
        root.isCheckable = true
        root.isChecked = false
        root.addAction(AccessibilityNodeInfo.ACTION_CLICK)
        shadowOf(root).setRefreshReturnValue(true)
        val snapshot = call("read_screen")
        // Simulate refresh returning an updated checked state for the saved node.
        executor.submit {
            val saved = ReflectionHelpers.getField<Map<String, Any>>(service, "nodes").getValue("n0")
            val cached = ReflectionHelpers.getField<AccessibilityNodeInfo>(saved, "node")
            cached.isChecked = true
        }.get(3, TimeUnit.SECONDS)
        assertEquals("STALE_NODE", call(action("tap", snapshot).put("node_id", "n0")).getString("error"))
        assertTrue(shadowOf(root).performedActions.isEmpty())
    }

    @Test fun eventArrivingDuringValidationPreventsAGesture() {
        val snapshot = call("read_screen")
        QueryServiceShadow.query = {
            service.onAccessibilityEvent(AccessibilityEvent.obtain(AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED).apply {
                eventTime = SystemClock.uptimeMillis()
                contentChangeTypes = AccessibilityEvent.CONTENT_CHANGE_TYPE_TEXT
            })
        }
        assertEquals("STALE_SCREEN", call(action("tap", snapshot).put("x", 10).put("y", 10)).getString("error"))
        assertTrue(shadowOf(service).gesturesDispatched.isEmpty())
    }

    @Test fun blockedQueryDoesNotBlockMainAndInterruptCancelsQueuedActions() {
        val entered = CountDownLatch(1)
        val release = CountDownLatch(1)
        val results = mutableListOf<JSONObject>()
        var queryThread: Thread? = null
        QueryServiceShadow.query = {
            queryThread = Thread.currentThread()
            entered.countDown()
            check(release.await(3, TimeUnit.SECONDS))
        }
        try {
            service.execute("{\"action\":\"read_screen\"}") {
                assertSame(Looper.getMainLooper(), Looper.myLooper())
                results.add(it)
            }
            assertTrue(entered.await(2, TimeUnit.SECONDS))
            assertNotSame(Looper.getMainLooper().thread, queryThread)
            service.execute("{\"action\":\"home\"}") { results.add(it) }
            var mainResponsive = false
            android.os.Handler(Looper.getMainLooper()).post { mainResponsive = true }
            shadowOf(Looper.getMainLooper()).idle()
            assertTrue(mainResponsive)
            service.onInterrupt()
            assertEquals(2, results.size)
            assertTrue(results.all { it.getString("error") == "INTERRUPTED" })
        } finally {
            QueryServiceShadow.query = null
            release.countDown()
        }
        flush()
        assertEquals(2, results.size)
        assertTrue(shadowOf(service).globalActionsPerformed.isEmpty())
        assertFalse(call("read_screen").has("error"))
    }

    @Test fun blockingQueriesAreSerializedAndRepliesReturnOnMain() {
        val entered = CountDownLatch(1)
        val release = CountDownLatch(1)
        val calls = AtomicInteger()
        val results = mutableListOf<JSONObject>()
        QueryServiceShadow.query = {
            if (calls.incrementAndGet() == 1) {
                entered.countDown()
                check(release.await(3, TimeUnit.SECONDS))
            }
        }
        val reply: (JSONObject) -> Unit = {
            assertSame(Looper.getMainLooper(), Looper.myLooper())
            results.add(it)
        }
        try {
            service.execute("{\"action\":\"read_screen\"}", reply)
            assertTrue(entered.await(2, TimeUnit.SECONDS))
            service.execute("{\"action\":\"read_screen\"}", reply)
            assertEquals(1, calls.get())
        } finally { release.countDown() }
        flush()
        assertEquals(2, calls.get())
        assertEquals(2, results.size)
        assertNotEquals(results[0].getString("snapshot_id"), results[1].getString("snapshot_id"))
    }

    @Test fun disconnectReturnsImmediatelyWhileQueryIsBlockedAndRejectsNewCalls() {
        val entered = CountDownLatch(1)
        val release = CountDownLatch(1)
        val results = mutableListOf<JSONObject>()
        QueryServiceShadow.query = { entered.countDown(); check(release.await(3, TimeUnit.SECONDS)) }
        try {
            service.execute("{\"action\":\"read_screen\"}") { results.add(it) }
            assertTrue(entered.await(2, TimeUnit.SECONDS))
            service.onDestroy()
            assertEquals("INTERRUPTED", results.single().getString("error"))
            service.execute("{\"action\":\"home\"}") { results.add(it) }
            assertEquals("SERVICE_UNAVAILABLE", results.last().getString("error"))
        } finally { QueryServiceShadow.query = null; release.countDown() }
        assertTrue(executor.awaitTermination(3, TimeUnit.SECONDS))
        shadowOf(Looper.getMainLooper()).idle()
        assertEquals(2, results.size)
        assertTrue(shadowOf(service).globalActionsPerformed.isEmpty())
    }

    @Test fun oldExpiryQueuedBehindABlockedReadCannotClearTheNewSnapshot() {
        call("read_screen")
        val entered = CountDownLatch(1)
        val release = CountDownLatch(1)
        var snapshot: JSONObject? = null
        QueryServiceShadow.query = { entered.countDown(); check(release.await(3, TimeUnit.SECONDS)) }
        try {
            service.execute("{\"action\":\"read_screen\"}") { snapshot = it }
            assertTrue(entered.await(2, TimeUnit.SECONDS))
            shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(31))
        } finally { QueryServiceShadow.query = null; release.countDown() }
        flush()
        shadowOf(service).setCanDispatchGestures(false)
        assertEquals("GESTURE_REJECTED", call(action("tap", requireNotNull(snapshot)).put("x", 10).put("y", 10)).getString("error"))
    }
}
