package com.psyche.kelivo.background

import android.Manifest
import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.drawable.Icon
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.psyche.kelivo.MainActivity
import com.psyche.kelivo.R
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference

data class BackgroundTask(
    val id: String,
    val conversationId: String,
    val title: String,
    val detail: String,
    val startedAt: Long,
    val tokens: Int,
    val outcome: String = "",
    val finishedAt: Long = 0,
) {
    companion object {
        fun fromMap(map: Map<*, *>): BackgroundTask = BackgroundTask(
            map["id"] as? String ?: "",
            map["conversationId"] as? String ?: "",
            map["title"] as? String ?: "Kelivo",
            map["detail"] as? String ?: "",
            (map["startedAt"] as? Number)?.toLong() ?: System.currentTimeMillis(),
            (map["tokens"] as? Number)?.toInt() ?: 0,
            map["outcome"] as? String ?: "",
            (map["finishedAt"] as? Number)?.toLong() ?: 0,
        )
    }
}

class BackgroundRuntime(private val context: Context) {
    companion object {
        const val CHANNEL_ID = "kelivo_generation_status"
        const val NOTIFICATION_ID = 7
        const val NOTIFICATION_PERMISSION_REQUEST = 4301
        const val CONVERSATION_EXTRA = "kelivo.background.conversation"
        private const val PENDING_CONVERSATION = "pending_conversation"
    }

    private val prefs = context.getSharedPreferences("kelivo_background", Context.MODE_PRIVATE)
    private val main = Handler(Looper.getMainLooper())
    private var channel: MethodChannel? = null
    private var activity = WeakReference<Activity>(null)
    private var dartReady = false
    private var revision = -1L
    private var serviceStarting = false
    private var blocked = false
    private var settings: Map<*, *> = emptyMap<String, Any>()
    private var labels: Map<*, *> = emptyMap<String, Any>()
    var tasks: List<BackgroundTask> = emptyList()
        private set
    var foreground = true
        private set
    var service: GenerationForegroundService? = null
        private set
    private val overlay by lazy { BackgroundOverlay(context, this, prefs) }

    fun enabled(key: String) = settings[key] == true
    fun label(key: String, default: String) = labels[key] as? String ?: default
    fun setting(key: String) = settings[key]
    fun shouldRunService() = enabled("androidEnabled") && tasks.isNotEmpty() && !blocked

    fun configure(messenger: BinaryMessenger) {
        channel = MethodChannel(messenger, "app.mobile_background").also { channel ->
            channel.setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "sync" -> {
                            sync(call.arguments as? Map<*, *> ?: emptyMap<String, Any>())
                            result.success(status())
                        }
                        "getStatus" -> result.success(status())
                        "takePendingConversation" -> {
                            dartReady = true
                            val id = prefs.getString(PENDING_CONVERSATION, null)
                            prefs.edit().remove(PENDING_CONVERSATION).apply()
                            result.success(id)
                        }
                        "requestPermission" -> {
                            requestPermission(call.arguments as? String ?: "")
                            result.success(null)
                        }
                        "openSettings" -> {
                            openSettings(call.arguments as? String ?: "app")
                            result.success(null)
                        }
                        "audioOwner" -> result.success(null) // iOS audio-session arbitration
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    recordError(error.message ?: error.javaClass.simpleName)
                    result.error("background", error.message, null)
                }
            }
        }
        // A new process cannot resume an old HTTP stream. Never restore an
        // ongoing notification or overlay from persisted task metadata.
        context.getSystemService(NotificationManager::class.java)?.cancel(NOTIFICATION_ID)
        if (prefs.getBoolean("service_was_active", false)) {
            recordError("previous_process_terminated")
            prefs.edit().putBoolean("service_was_active", false).apply()
        }
    }

    fun attachActivity(value: Activity) { activity = WeakReference(value) }

    fun detachActivity(value: Activity) {
        if (activity.get() === value) activity.clear()
    }

    fun setForeground(value: Boolean) {
        foreground = value
        if (value) blocked = false
        overlay.onForegroundChanged(value)
        reconcileService()
        channel?.invokeMethod("statusChanged", null)
    }

    private fun sync(args: Map<*, *>) {
        val nextRevision = (args["revision"] as? Number)?.toLong() ?: return
        if (nextRevision <= revision) return
        revision = nextRevision
        val previousIds = tasks.map { it.id }.toSet()
        val wasEnabled = enabled("androidEnabled")
        val wasPrivate = enabled("privacyMode")
        settings = args["settings"] as? Map<*, *> ?: emptyMap<String, Any>()
        labels = args["labels"] as? Map<*, *> ?: emptyMap<String, Any>()
        tasks = (args["tasks"] as? List<*>)?.mapNotNull {
            (it as? Map<*, *>)?.let(BackgroundTask::fromMap)?.takeIf { task -> task.id.isNotEmpty() }
        } ?: emptyList()
        if ((!wasEnabled && enabled("androidEnabled")) ||
            (foreground && tasks.any { it.id !in previousIds })) blocked = false
        if (!wasPrivate && enabled("privacyMode")) {
            clearCompletionNotifications()
            overlay.clearCompleted()
        }
        val terminal = (args["terminal"] as? Map<*, *>)?.let(BackgroundTask::fromMap)
        overlay.sync(tasks, terminal)
        reconcileService()
    }

    private fun reconcileService() {
        if (shouldRunService()) {
            val running = service
            if (running != null) {
                running.refresh()
            } else if (!serviceStarting) {
                try {
                    serviceStarting = true
                    ContextCompat.startForegroundService(context,
                        Intent(context, GenerationForegroundService::class.java))
                } catch (error: RuntimeException) {
                    serviceStarting = false
                    blocked = true
                    recordError("foreground_service_start_failed: ${error.message}")
                }
            }
        } else {
            service?.stopGenerationService()
        }
        overlay.refresh()
    }

    fun serviceStarted(value: GenerationForegroundService) {
        serviceStarting = false
        service = value
        prefs.edit().putBoolean("service_was_active", true).apply()
        channel?.invokeMethod("statusChanged", null)
        // The system sets FLAG_PROMOTED_ONGOING after notify/startForeground.
        main.postDelayed({ overlay.refresh() }, 300)
    }

    fun serviceStopped(value: GenerationForegroundService) {
        if (service === value) service = null
        serviceStarting = false
        prefs.edit().putBoolean("service_was_active", false).apply()
        channel?.invokeMethod("statusChanged", null)
    }

    fun stopTasks(reason: String? = null) {
        val ids = tasks.map { it.id }
        blocked = true
        if (reason != null) recordError(reason)
        channel?.invokeMethod(if (reason == null) "cancelTasks" else "interrupted",
            mapOf("ids" to ids, "reason" to reason))
        overlay.dismissAll()
        service?.stopGenerationService()
    }

    fun onTaskRemoved() {
        // Keep the same engine and tool executors. A system force stop still
        // terminates the process; START_NOT_STICKY avoids reviving a fake run.
        if (!shouldRunService()) stopTasks()
    }

    fun receiveConversation(intent: Intent?) {
        val id = intent?.getStringExtra(CONVERSATION_EXTRA)?.takeIf { it.isNotBlank() } ?: return
        intent.removeExtra(CONVERSATION_EXTRA)
        if (!dartReady) prefs.edit().putString(PENDING_CONVERSATION, id).apply()
        else channel?.invokeMethod("openConversation", id)
    }

    fun openConversation(id: String) {
        context.startActivity(openIntent(id))
    }

    fun openIntent(id: String) = Intent(context, MainActivity::class.java)
        .putExtra(CONVERSATION_EXTRA, id)
        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)

    fun buildNotification(): Notification {
        ensureChannel()
        val task = tasks.firstOrNull()
        val title = if (tasks.size > 1) "${tasks.size} ${label("tasks", "Tasks")}" else task?.title ?: "Kelivo"
        val content = task?.detail ?: label("working", "Working")
        val open = PendingIntent.getActivity(context, 7, openIntent(task?.conversationId ?: ""),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val stop = PendingIntent.getService(context, 8,
            Intent(context, GenerationForegroundService::class.java).setAction(GenerationForegroundService.STOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        if (Build.VERSION.SDK_INT >= 36 && enabled("liveUpdatesEnabled") && canPromote()) {
            val style = Notification.ProgressStyle()
                .addProgressSegment(Notification.ProgressStyle.Segment(100))
                .setStyledByProgress(false)
                .setProgressIndeterminate(true)
            return Notification.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_background_generation)
                .setContentTitle(title).setContentText(content)
                .setStyle(style).setOngoing(true).setOnlyAlertOnce(true)
                .setWhen(task?.startedAt ?: System.currentTimeMillis()).setUsesChronometer(true)
                .setContentIntent(open).setColorized(false)
                .addExtras(Bundle().apply { putBoolean("android.requestPromotedOngoing", true) })
                .addAction(Notification.Action.Builder(
                    Icon.createWithResource(context, R.drawable.ic_background_stop),
                    label("stop", "Stop tasks"), stop).build())
                .build()
        }
        return NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_background_generation)
            .setContentTitle(title).setContentText(content)
            .setStyle(NotificationCompat.BigTextStyle().bigText(content))
            .setOngoing(true).setOnlyAlertOnce(true).setSilent(true)
            .setWhen(task?.startedAt ?: System.currentTimeMillis()).setUsesChronometer(true)
            .setContentIntent(open).setCategory(NotificationCompat.CATEGORY_SERVICE)
            .addAction(R.drawable.ic_background_stop, label("stop", "Stop tasks"), stop)
            .build()
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT >= 26) {
            context.getSystemService(NotificationManager::class.java)?.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, label("tasks", "Tasks"), NotificationManager.IMPORTANCE_LOW).apply {
                    setShowBadge(false)
                    setSound(null, null)
                })
        }
    }

    fun isPromoted(): Boolean {
        if (Build.VERSION.SDK_INT < 36 || service == null) return false
        return context.getSystemService(NotificationManager::class.java)?.activeNotifications?.any {
            it.id == NOTIFICATION_ID && it.notification.flags and Notification.FLAG_PROMOTED_ONGOING != 0
        } == true
    }

    private fun canPromote() = Build.VERSION.SDK_INT >= 36 &&
        context.getSystemService(NotificationManager::class.java)?.canPostPromotedNotifications() == true

    fun status(): Map<String, Any> {
        val manager = context.getSystemService(NotificationManager::class.java)
        fun channelEnabled(id: String) = Build.VERSION.SDK_INT < 26 ||
            manager?.getNotificationChannel(id)?.importance != NotificationManager.IMPORTANCE_NONE
        return mapOf(
            "foregroundServiceActive" to (service != null && shouldRunService()),
            "activeTasks" to tasks.size,
            "notificationsAuthorized" to NotificationManagerCompat.from(context).areNotificationsEnabled(),
            "ongoingChannelEnabled" to channelEnabled(CHANNEL_ID),
            "completionChannelEnabled" to channelEnabled("kelivo_bg_chat_v2"),
            "batteryExempt" to context.getSystemService(PowerManager::class.java).isIgnoringBatteryOptimizations(context.packageName),
            "overlayAuthorized" to Settings.canDrawOverlays(context),
            "overlayVisible" to overlay.isVisible,
            "liveUpdatesSupported" to (Build.VERSION.SDK_INT >= 36),
            "liveUpdatesAuthorized" to canPromote(),
            "liveUpdatePromoted" to isPromoted(),
            "manufacturer" to Build.MANUFACTURER,
            "lastError" to (prefs.getString("last_error", "") ?: ""),
        )
    }

    fun serviceFailed(message: String) {
        blocked = true
        serviceStarting = false
        recordError(message)
        channel?.invokeMethod("statusChanged", null)
    }

    fun recordError(message: String) {
        prefs.edit().putString("last_error", message).apply()
        android.util.Log.w("KelivoBackground", message)
    }

    fun requestPermission(permission: String) {
        val host = activity.get() ?: throw IllegalStateException("foreground_activity_required")
        when (permission) {
            "notifications" -> if (Build.VERSION.SDK_INT >= 33 &&
                ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                ActivityCompat.requestPermissions(host, arrayOf(Manifest.permission.POST_NOTIFICATIONS), NOTIFICATION_PERMISSION_REQUEST)
            } else openSettings("notifications")
            "battery" -> openSettings("battery")
            "overlay" -> openSettings("overlay")
        }
    }

    fun permissionResult(requestCode: Int): Boolean {
        if (requestCode != NOTIFICATION_PERMISSION_REQUEST) return false
        channel?.invokeMethod("statusChanged", null)
        return true
    }

    fun openSettings(destination: String) {
        val host = activity.get() ?: throw IllegalStateException("foreground_activity_required")
        val packageUri = Uri.parse("package:${context.packageName}")
        val intents = mutableListOf<Intent>()
        when (destination) {
            "notifications" -> if (Build.VERSION.SDK_INT >= 26) intents +=
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
            "channels", "ongoingChannel" -> if (Build.VERSION.SDK_INT >= 26) {
                ensureChannel()
                intents += Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
                    .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                    .putExtra(Settings.EXTRA_CHANNEL_ID,
                        if (destination == "ongoingChannel") CHANNEL_ID else "kelivo_bg_chat_v2")
            }
            "battery" -> {
                intents += Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, packageUri)
                intents += Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
            }
            "overlay" -> intents += Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, packageUri)
            "liveUpdates" -> if (Build.VERSION.SDK_INT >= 36) intents +=
                Intent("android.settings.MANAGE_APP_PROMOTED_NOTIFICATIONS").putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
            "autostart" -> intents += vendorSettings().map { (pkg, name) -> Intent().setComponent(ComponentName(pkg, name)) }
        }
        intents += Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, packageUri)
        for (intent in intents) {
            try { host.startActivity(intent); return }
            catch (_: android.content.ActivityNotFoundException) { /* try next device setting */ }
            catch (_: SecurityException) { /* some OEM activities are not exported */ }
        }
        throw IllegalStateException("settings_unavailable")
    }

    private fun vendorSettings(): List<Pair<String, String>> {
        val vendor = "${Build.MANUFACTURER} ${Build.BRAND}".lowercase()
        return when {
            "xiaomi" in vendor || "redmi" in vendor -> listOf("com.miui.securitycenter" to "com.miui.permcenter.autostart.AutoStartManagementActivity")
            "huawei" in vendor || "honor" in vendor -> listOf("com.huawei.systemmanager" to "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity")
            "oppo" in vendor || "oneplus" in vendor || "realme" in vendor -> listOf(
                "com.coloros.safecenter" to "com.coloros.safecenter.permission.startup.StartupAppListActivity",
                "com.oppo.safe" to "com.oppo.safe.permission.startup.StartupAppListActivity")
            "vivo" in vendor || "iqoo" in vendor -> listOf("com.vivo.permissionmanager" to "com.vivo.permissionmanager.activity.BgStartUpManagerActivity")
            "samsung" in vendor -> listOf("com.samsung.android.lool" to "com.samsung.android.sm.battery.ui.BatteryActivity")
            else -> emptyList()
        }
    }

    private fun clearCompletionNotifications() {
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        for (entry in manager.activeNotifications) {
            if (Build.VERSION.SDK_INT >= 26 && entry.notification.channelId == "kelivo_bg_chat_v2") {
                manager.cancel(entry.tag, entry.id)
            }
        }
    }
}
