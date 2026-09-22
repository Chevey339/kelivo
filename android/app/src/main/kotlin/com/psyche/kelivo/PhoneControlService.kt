package com.psyche.kelivo

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.accessibilityservice.GestureDescription
import android.app.KeyguardManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Path
import android.graphics.Point
import android.graphics.Rect
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityManager
import android.view.accessibility.AccessibilityNodeInfo
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID
import java.util.concurrent.Executors
import java.util.concurrent.CancellationException
import java.util.concurrent.atomic.AtomicLong

/** On-demand phone control. Screen content is never collected from events or persisted. */
@Suppress("DEPRECATION")
class PhoneControlService : AccessibilityService() {
    companion object {
        @Volatile private var connected: PhoneControlService? = null

        fun status(context: Context): Map<String, Boolean> {
            val manager = context.getSystemService(AccessibilityManager::class.java)
            val component = ComponentName(context, PhoneControlService::class.java)
            val enabled = manager.getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_ALL_MASK)
                .any { ComponentName(it.resolveInfo.serviceInfo.packageName, it.resolveInfo.serviceInfo.name) == component }
            return mapOf("enabled" to enabled, "connected" to (enabled && connected != null))
        }

        fun execute(json: String, complete: (String) -> Unit) {
            val service = connected
            if (service == null) {
                complete(error("SERVICE_UNAVAILABLE", "Enable Kelivo phone control in Android Accessibility settings. If already enabled, turn the service off and on again.").toString())
                return
            }
            service.execute(json) { complete(it.toString()) }
        }

        internal fun error(code: String, message: String) = JSONObject()
            .put("error", code).put("message", message)
    }

    private data class SavedNode(val node: AccessibilityNodeInfo, val fingerprint: String)
    private val nodes = mutableMapOf<String, SavedNode>()
    private var snapshotId: String? = null
    private var snapshotTime = 0L
    private var snapshotEventTime = 0L
    private var snapshotNodes = ""
    private data class Change(val time: Long)
    @Volatile private var latestChange = Change(-1)
    private var snapshotChange: Change? = null
    private var snapshotWindow = -1
    private var snapshotPackage: String? = null
    private var snapshotSize = Point()
    private val handler = Handler(Looper.getMainLooper())
    // All nodes, snapshots and gesture state belong to this serial worker.
    // Main-thread callbacks only update atomic invalidation/cancellation markers.
    private val executor = Executors.newSingleThreadExecutor()
    private val generation = AtomicLong()
    @Volatile private var destroyed = false
    private var operationGeneration = 0L
    private val requests = mutableSetOf<(JSONObject) -> Unit>() // main thread only
    private var expireSnapshot: Runnable? = null
    private var pendingGesture: ((JSONObject) -> Unit)? = null

    override fun onServiceConnected() {
        super.onServiceConnected()
        connected = this
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Copy only timing, never retain event objects or text. This remains
        // non-blocking even while the worker waits for another application's IPC.
        if (event == null) return
        when (event.eventType) {
            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED,
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED,
            AccessibilityEvent.TYPE_WINDOWS_CHANGED,
            AccessibilityEvent.TYPE_VIEW_SCROLLED,
            AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED,
            AccessibilityEvent.TYPE_VIEW_TEXT_SELECTION_CHANGED,
            AccessibilityEvent.TYPE_VIEW_SELECTED,
            AccessibilityEvent.TYPE_VIEW_CLICKED -> latestChange = Change(maxOf(latestChange.time, event.eventTime))
        }
    }

    override fun onInterrupt() {
        if (executor.isShutdown) return
        generation.incrementAndGet()
        executor.execute {
            clearSnapshot()
            pendingGesture?.invoke(error("INTERRUPTED", "Phone control was interrupted. Read the screen again."))
        }
        requests.toList().forEach { it(error("INTERRUPTED", "Phone control was interrupted.")) }
    }

    override fun onUnbind(intent: Intent?): Boolean {
        disconnect()
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        if (destroyed) return
        destroyed = true
        disconnect()
        // Cleanup already queued by disconnect runs after any outstanding IPC.
        executor.shutdown()
        super.onDestroy()
    }

    private fun disconnect() {
        if (connected === this) connected = null
        onInterrupt()
    }

    private fun scheduleSnapshotExpiry(delay: Long) {
        expireSnapshot?.let(handler::removeCallbacks)
        val id = snapshotId
        val task = Runnable {
            if (!executor.isShutdown) executor.execute { if (snapshotId == id) clearSnapshot() }
        }
        expireSnapshot = task
        handler.postDelayed(task, delay)
    }

    private fun clearSnapshot() {
        expireSnapshot?.let(handler::removeCallbacks)
        nodes.values.forEach { it.node.recycle() }
        nodes.clear()
        snapshotId = null
        snapshotNodes = ""
        snapshotChange = null
    }

    internal fun execute(json: String, complete: (JSONObject) -> Unit) {
        check(Looper.myLooper() == Looper.getMainLooper())
        if (destroyed) {
            complete(error("SERVICE_UNAVAILABLE", "Phone control has disconnected."))
            return
        }
        val epoch = generation.get()
        var finished = false // accessed only on the main thread
        lateinit var reply: (JSONObject) -> Unit
        reply = { value ->
            val deliver = {
                if (!finished) {
                    finished = true
                    requests.remove(reply)
                    complete(if (epoch == generation.get() && !destroyed) value
                        else error("INTERRUPTED", "Phone control was interrupted."))
                }
            }
            if (Looper.myLooper() == Looper.getMainLooper()) deliver() else handler.post { deliver() }
        }
        requests.add(reply)
        executor.execute {
            operationGeneration = epoch
            if (epoch != generation.get() || destroyed) {
                reply(error("INTERRUPTED", "Phone control was interrupted."))
            } else {
                executeOnWorker(json, reply)
            }
        }
    }

    private fun ensureActive() {
        if (destroyed || operationGeneration != generation.get()) throw CancellationException()
    }

    private fun executeOnWorker(json: String, complete: (JSONObject) -> Unit) {
        if (pendingGesture != null) {
            complete(error("BUSY", "A gesture is still running. Wait for its result before the next call."))
            return
        }
        try {
            ensureActive()
            if (getSystemService(KeyguardManager::class.java).isKeyguardLocked) {
                clearSnapshot()
                complete(error("DEVICE_LOCKED", "Ask the user to unlock the phone before continuing."))
                return
            }
            val args = JSONObject(json)
            val action = args.optString("action")
            when (action) {
                "read_screen" -> complete(readScreen())
                "list_apps" -> complete(listApps())
                "open_app" -> {
                    val name = requiredString(args, "package_name")
                    val intent = packageManager.getLaunchIntentForPackage(name)
                    if (intent == null) {
                        complete(error("APP_NOT_FOUND", "No launchable app for this package. Use list_apps to find a package name."))
                    } else {
                        clearSnapshot()
                        ensureActive()
                        startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                        complete(JSONObject().put("success", true).put("package_name", name))
                    }
                }
                "back", "home", "recents", "notifications", "quick_settings" -> {
                    clearSnapshot()
                    val globalAction = when (action) {
                        "back" -> GLOBAL_ACTION_BACK
                        "home" -> GLOBAL_ACTION_HOME
                        "recents" -> GLOBAL_ACTION_RECENTS
                        "notifications" -> GLOBAL_ACTION_NOTIFICATIONS
                        else -> GLOBAL_ACTION_QUICK_SETTINGS
                    }
                    ensureActive()
                    complete(actionResult(performGlobalAction(globalAction)))
                }
                "tap", "long_press", "set_text", "scroll", "swipe" -> {
                    if (!validateSnapshot(args)) {
                        complete(error("STALE_SCREEN", "The screen changed or this snapshot expired. Call read_screen again before acting."))
                        return
                    }
                    if (action == "swipe" || (action in listOf("tap", "long_press") && !args.has("node_id"))) {
                        gesture(action, args, complete)
                    } else {
                        complete(nodeAction(action, args))
                    }
                }
                else -> complete(error("INVALID_ARGUMENT", "Unknown phone control action: $action"))
            }
        } catch (e: CancellationException) {
            clearSnapshot()
            complete(error("INTERRUPTED", "Phone control was interrupted."))
        } catch (e: IllegalArgumentException) {
            complete(error("INVALID_ARGUMENT", e.message ?: "Invalid arguments."))
        } catch (e: org.json.JSONException) {
            complete(error("INVALID_ARGUMENT", e.message ?: "Invalid JSON."))
        } catch (e: Exception) {
            clearSnapshot()
            complete(error("PHONE_CONTROL_FAILED", e.message ?: "Phone control failed."))
        }
    }

    private fun screenSize(): Point = Point().also {
        getSystemService(WindowManager::class.java).defaultDisplay.getRealSize(it)
    }

    private fun readScreen(): JSONObject {
        clearSnapshot()
        val started = SystemClock.uptimeMillis()
        val change = latestChange
        ensureActive()
        val root = rootInActiveWindow
            ?: return error("NO_WINDOW", "No accessible window is available. Ask the user to open the target app, then retry.")
        val id = UUID.randomUUID().toString()
        val output = JSONArray()
        val size = screenSize()
        var visited = 0
        var textBudget = 32000
        var truncated = false
        fun label(value: CharSequence?): String {
            val text = value?.toString().orEmpty()
            val result = text.take(minOf(1000, textBudget))
            textBudget -= result.length
            if (result.length < text.length) truncated = true
            return result
        }
        fun visit(node: AccessibilityNodeInfo, depth: Int, parentId: String?) {
            try {
                ensureActive()
                if (visited++ >= 2000 || depth > 40 || output.length() >= 350) {
                    truncated = true
                    return
                }
                val bounds = Rect().also(node::getBoundsInScreen)
                val visible = node.isVisibleToUser && Rect.intersects(bounds, Rect(0, 0, size.x, size.y))
                var nextParent = parentId
                if (visible && (depth == 0 || node.isClickable || node.isLongClickable || node.isEditable ||
                        node.isScrollable || node.isCheckable || !node.text.isNullOrEmpty() || !node.contentDescription.isNullOrEmpty())) {
                    val nodeId = "n${output.length()}"
                    val item = JSONObject().put("node_id", nodeId)
                        .put("bounds", JSONArray(listOf(bounds.left, bounds.top, bounds.right, bounds.bottom)))
                        .put("class", node.className?.toString().orEmpty())
                    parentId?.let { item.put("parent_id", it) }
                    if (!node.isPassword) {
                        label(node.text).takeIf { it.isNotEmpty() }?.let { item.put("text", it) }
                        label(node.contentDescription).takeIf { it.isNotEmpty() }?.let { item.put("description", it) }
                        if (Build.VERSION.SDK_INT >= 30) {
                            label(node.stateDescription).takeIf { it.isNotEmpty() }?.let { item.put("state_description", it) }
                        }
                        if (Build.VERSION.SDK_INT >= 26) {
                            label(node.hintText).takeIf { it.isNotEmpty() }?.let { item.put("hint", it) }
                        }
                    } else {
                        item.put("password", true)
                    }
                    node.viewIdResourceName?.let { item.put("resource_id", it) }
                    item.put("enabled", node.isEnabled)
                    if (node.isClickable) item.put("clickable", true)
                    if (node.isLongClickable) item.put("long_clickable", true)
                    if (node.isEditable) {
                        item.put("editable", true)
                        item.put("supports_set_text", node.actionList.any { it.id == AccessibilityNodeInfo.ACTION_SET_TEXT })
                    }
                    if (node.isScrollable) item.put("scrollable", true)
                    if (node.isCheckable) item.put("checked", node.isChecked)
                    if (node.isFocused) item.put("focused", true)
                    if (node.isSelected) item.put("selected", true)
                    output.put(item)
                    nodes[nodeId] = SavedNode(AccessibilityNodeInfo.obtain(node), fingerprint(node))
                    nextParent = nodeId
                }
                // Password descendants may contain unmasked labels on custom widgets.
                if (!node.isPassword) {
                    for (i in 0 until node.childCount) {
                        if (visited >= 2000 || output.length() >= 350) {
                            truncated = true
                            break
                        }
                        ensureActive()
                        node.getChild(i)?.let { visit(it, depth + 1, nextParent) }
                    }
                }
            } finally {
                node.recycle()
            }
        }
        snapshotWindow = root.windowId
        snapshotPackage = root.packageName?.toString()
        visit(root, 0, null)
        ensureActive()
        snapshotId = id
        snapshotTime = SystemClock.elapsedRealtime()
        snapshotEventTime = started
        snapshotChange = change
        snapshotSize = size
        snapshotNodes = output.toString()
        scheduleSnapshotExpiry(30000)
        return JSONObject().put("snapshot_id", id).put("package_name", snapshotPackage)
            .put("width", size.x).put("height", size.y).put("nodes", output)
            .put("truncated", truncated)
    }

    private fun fingerprint(node: AccessibilityNodeInfo): String {
        val bounds = Rect().also(node::getBoundsInScreen)
        return listOf(node.windowId, node.packageName, node.className, node.viewIdResourceName,
            bounds, if (node.isPassword) null else node.text,
            if (node.isPassword) null else node.contentDescription,
            if (node.isPassword || Build.VERSION.SDK_INT < 26) null else node.hintText,
            if (node.isPassword || Build.VERSION.SDK_INT < 30) null else node.stateDescription,
            node.isCheckable, node.isChecked, node.isSelected, node.isEnabled,
            node.isFocused, node.isPassword, node.isEditable, node.isClickable,
            node.isLongClickable, node.isScrollable, node.actionList.map { it.id }.sorted()).joinToString("\u0000")
    }

    private fun validateSnapshot(args: JSONObject): Boolean {
        if (snapshotId == null || args.optString("snapshot_id") != snapshotId ||
            SystemClock.elapsedRealtime() - snapshotTime > 30000 || screenSize() != snapshotSize) return false
        ensureActive()
        val root = rootInActiveWindow ?: return false
        val sameWindow = try {
            root.windowId == snapshotWindow && root.packageName?.toString() == snapshotPackage
        } finally { root.recycle() }
        if (!sameWindow) return false
        if (latestChange.time >= snapshotEventTime && latestChange !== snapshotChange) {
            // Android/Flutter can emit subtree/window events without changing
            // the visible UI (e.g. a keyboard animation finishing). Revalidate
            // the tree before rejecting a still-current snapshot.
            val previousId = snapshotId
            val previousTime = snapshotTime
            val previousNodes = snapshotNodes
            val previousFingerprints = nodes.mapValues { it.value.fingerprint }
            val previousWindow = snapshotWindow
            val previousPackage = snapshotPackage
            val previousSize = snapshotSize
            val refreshed = readScreen()
            if (refreshed.has("error") || snapshotNodes != previousNodes ||
                nodes.mapValues { it.value.fingerprint } != previousFingerprints ||
                snapshotWindow != previousWindow || snapshotPackage != previousPackage ||
                snapshotSize != previousSize || SystemClock.elapsedRealtime() - previousTime > 30000) return false
            snapshotId = previousId
            snapshotTime = previousTime
            expireSnapshot?.let(handler::removeCallbacks)
            scheduleSnapshotExpiry((30000 - (SystemClock.elapsedRealtime() - snapshotTime)).coerceAtLeast(0))
        }
        ensureActive()
        return latestChange.time < snapshotEventTime || latestChange === snapshotChange
    }

    private fun nodeAction(action: String, args: JSONObject): JSONObject {
        val saved = nodes[requiredString(args, "node_id")]
            ?: return error("NODE_NOT_FOUND", "Unknown node. Call read_screen again.")
        val node = saved.node
        ensureActive()
        if (!node.refresh() || !node.isVisibleToUser || !node.isEnabled || fingerprint(node) != saved.fingerprint) {
            clearSnapshot()
            return error("STALE_NODE", "The target node changed. Call read_screen again.")
        }
        var arguments: Bundle? = null
        val actionId = when (action) {
            "tap" -> AccessibilityNodeInfo.ACTION_CLICK
            "long_press" -> AccessibilityNodeInfo.ACTION_LONG_CLICK
            "set_text" -> {
                require(node.isEditable) { "The node must be editable." }
                val text = args.opt("text")
                require(text is String && text.length <= 10000) { "text must be a string of at most 10000 characters; an empty string clears the field." }
                arguments = Bundle().apply {
                    putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text)
                }
                AccessibilityNodeInfo.ACTION_SET_TEXT
            }
            "scroll" -> {
                val direction = requiredString(args, "direction")
                when (direction) {
                    "forward" -> AccessibilityNodeInfo.ACTION_SCROLL_FORWARD
                    "backward" -> AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD
                    "up" -> AccessibilityNodeInfo.AccessibilityAction.ACTION_SCROLL_UP.id
                    "down" -> AccessibilityNodeInfo.AccessibilityAction.ACTION_SCROLL_DOWN.id
                    "left" -> AccessibilityNodeInfo.AccessibilityAction.ACTION_SCROLL_LEFT.id
                    "right" -> AccessibilityNodeInfo.AccessibilityAction.ACTION_SCROLL_RIGHT.id
                    else -> throw IllegalArgumentException("Unknown scroll direction.")
                }
            }
            else -> throw IllegalArgumentException("Unknown node action.")
        }
        // Some frameworks return true even for actions absent from the node.
        // Flutter, for example, exposes SET_TEXT only after the field is focused.
        if (node.actionList.none { it.id == actionId }) {
            return error("ACTION_UNAVAILABLE", if (action == "set_text") {
                "This field does not currently support setting text. Tap it to focus, then read_screen again before set_text."
            } else {
                "The node does not advertise this action. Choose an actionable node, another scroll direction, or a coordinate gesture."
            })
        }
        ensureActive()
        if (latestChange.time >= snapshotEventTime && latestChange !== snapshotChange) {
            return error("STALE_SCREEN", "The screen changed during validation. Call read_screen again.")
        }
        val result = node.performAction(actionId, arguments)
        clearSnapshot()
        return actionResult(result)
    }

    private fun gesture(action: String, args: JSONObject, complete: (JSONObject) -> Unit) {
        if (Build.VERSION.SDK_INT < 24) {
            complete(error("UNSUPPORTED_OS", "Touch gestures require Android 7 or later."))
            return
        }
        fun coordinate(name: String, limit: Int): Float {
            val value = args.opt(name)
            require(value is Number && value.toDouble().isFinite() && value.toDouble() >= 0 && value.toDouble() < limit) {
                "$name must be a screen coordinate from 0 to ${limit - 1}."
            }
            return value.toFloat()
        }
        val x = coordinate("x", snapshotSize.x)
        val y = coordinate("y", snapshotSize.y)
        val path = Path().apply { moveTo(x, y) }
        if (action == "swipe") path.lineTo(coordinate("end_x", snapshotSize.x), coordinate("end_y", snapshotSize.y))
        val duration = if (args.has("duration_ms")) {
            val value = args.opt("duration_ms")
            require(value is Number && value.toDouble().isFinite() && value.toDouble() in 50.0..2000.0) {
                "duration_ms must be between 50 and 2000."
            }
            value.toLong()
        } else when (action) { "long_press" -> 600L; "swipe" -> 350L; else -> 80L }
        require(action != "long_press" || duration >= 500) { "long_press requires at least 500 ms." }
        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, duration)).build()
        val checkedChange = snapshotChange
        val checkedEventTime = snapshotEventTime
        clearSnapshot()
        lateinit var finish: (JSONObject) -> Unit
        val timeout = Runnable {
            if (!executor.isShutdown) executor.execute {
                finish(error("GESTURE_TIMEOUT", "Gesture completion is unknown. Read the screen before retrying."))
            }
        }
        var completed = false
        finish = { value ->
            if (!completed) {
                completed = true
                handler.removeCallbacks(timeout)
                pendingGesture = null
                complete(value)
            }
        }
        pendingGesture = finish
        handler.postDelayed(timeout, duration + 3000)
        try {
            ensureActive()
            if (latestChange.time >= checkedEventTime && latestChange !== checkedChange) {
                finish(error("STALE_SCREEN", "The screen changed during validation. Call read_screen again."))
                return
            }
            val accepted = dispatchGesture(gesture, object : GestureResultCallback() {
                override fun onCompleted(gestureDescription: GestureDescription?) {
                    if (!executor.isShutdown) executor.execute { finish(actionResult(true)) }
                }
                override fun onCancelled(gestureDescription: GestureDescription?) {
                    if (!executor.isShutdown) executor.execute { finish(error("GESTURE_CANCELLED", "The gesture was cancelled. Read the screen before retrying.")) }
                }
            }, handler)
            if (!accepted) finish(error("GESTURE_REJECTED", "Android rejected this gesture."))
        } catch (e: Exception) {
            finish(error("GESTURE_FAILED", e.message ?: "Gesture failed."))
        }
    }

    private fun listApps(): JSONObject {
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val apps = packageManager.queryIntentActivities(intent, 0)
            .distinctBy { it.activityInfo.packageName }.sortedBy { it.loadLabel(packageManager).toString() }
        return JSONObject().put("apps", JSONArray(apps.map {
            JSONObject().put("name", it.loadLabel(packageManager).toString())
                .put("package_name", it.activityInfo.packageName)
        }))
    }

    private fun actionResult(success: Boolean): JSONObject = if (success) {
        JSONObject().put("success", true).put("message", "Action accepted. Call read_screen to verify the result.")
    } else error("ACTION_FAILED", "The target did not accept this action. Read the screen and choose an actionable node or use coordinates.")

    private fun requiredString(args: JSONObject, name: String): String {
        val value = args.opt(name)
        require(value is String && value.isNotBlank()) { "$name is required and must be a non-empty string." }
        return value
    }
}
