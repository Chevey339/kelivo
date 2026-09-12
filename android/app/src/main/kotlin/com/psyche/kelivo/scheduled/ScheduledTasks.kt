package com.psyche.kelivo.scheduled

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import com.psyche.kelivo.KelivoApplication
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalDate
import java.util.UUID

/** Native storage is the single owner: alarms also work without a Dart isolate. */
class ScheduledTasks(private val app: KelivoApplication) {
    companion object {
        const val FIRE = "com.psyche.kelivo.scheduled.FIRE"
        private const val LIMIT_MS = 10 * 60 * 1000L
    }
    private val prefs = app.getSharedPreferences("kelivo_scheduled_tasks", Context.MODE_PRIVATE)
    private val alarms = app.getSystemService(AlarmManager::class.java)
    private val main = Handler(Looper.getMainLooper())
    private var channel: MethodChannel? = null
    private var ready = false
    private val active = linkedMapOf<String, JSONObject>()
    private val dispatched = mutableSetOf<String>()
    private val deadlines = mutableMapOf<String, Runnable>()

    init {
        // A terminated HTTP stream cannot be resumed or safely replayed.
        tasks().forEach { task ->
            val runs = task.optJSONArray("runs") ?: JSONArray()
            var changed = false
            for (i in 0 until runs.length()) {
                val run = runs.getJSONObject(i)
                if (run.optString("status") == "running") {
                    run.put("status", "interrupted").put("error", "process_terminated")
                    changed = true
                }
            }
            if (changed) persist(task)
        }
    }

    fun configure(messenger: BinaryMessenger) {
        channel = MethodChannel(messenger, "app.scheduled_tasks").also { bridge ->
            bridge.setMethodCallHandler { call, result ->
                try {
                    val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                    when (call.method) {
                        "list" -> result.success(snapshot())
                        "ready" -> {
                            ready = true
                            rescheduleAll()
                            result.success(null)
                            dispatchPending()
                        }
                        "save" -> {
                            val task = JSONObject(args)
                            validate(task)
                            val old = get(task.getString("id"))
                            require(active.values.none { it.getString("taskId") == task.getString("id") }) { "task_running" }
                            task.put("runs", old?.optJSONArray("runs") ?: JSONArray())
                            arm(task)
                            persist(task)
                            result.success(snapshot())
                        }
                        "delete" -> {
                            val id = args["id"] as String
                            require(active.values.none { it.getString("taskId") == id }) { "task_running" }
                            alarms.cancel(pendingIntent(id, 0))
                            check(prefs.edit().remove("task:$id").commit())
                            result.success(snapshot())
                        }
                        "runNow" -> {
                            val task = get(args["id"] as String) ?: error("task_missing")
                            start(task)
                            result.success(snapshot())
                        }
                        "permission" -> {
                            if (Build.VERSION.SDK_INT >= 31) app.startActivity(Intent(
                                Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                                Uri.parse("package:${app.packageName}")
                            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                            result.success(null)
                        }
                        "conversation" -> {
                            val runId = args["runId"] as String
                            active[runId]?.put("conversationId", args["conversationId"])
                            updateRun(runId)
                            result.success(null)
                        }
                        "finish" -> {
                            finish(args["runId"] as String, args)
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error("scheduled_task", error.message, null)
                }
            }
        }
    }

    private fun validate(task: JSONObject) {
        require(task.getString("id").length in 1..128)
        require(task.getString("name").trim().length in 1..200)
        val mode = task.optString("mode", "newChat")
        require(mode in setOf("newChat", "followUp", "regenerate"))
        require(task.optString("prompt").trim().length in (if (mode == "regenerate") 0 else 1)..32000)
        require(task.getString("assistantId").isNotBlank())
        if (mode != "newChat") require(!task.isNull("conversationId") && task.getString("conversationId").isNotBlank())
        if (mode == "regenerate") require(!task.isNull("messageId") && task.getString("messageId").isNotBlank())
        require(task.isNull("modelProvider") == task.isNull("modelId"))
        if (!task.isNull("modelId")) {
            require(task.getString("modelProvider").isNotBlank() && task.getString("modelId").isNotBlank())
        }
        val next = next(task, System.currentTimeMillis())
        require(!task.getBoolean("enabled") || next != null) { "schedule_ended" }
    }
    private fun date(task: JSONObject, key: String): LocalDate? =
        if (task.isNull(key)) null else LocalDate.parse(task.getString(key))
    private fun next(task: JSONObject, after: Long): Long? = ScheduleTime.next(
        task.getInt("hour"), task.getInt("minute"), days(task), after,
        onceDate = date(task, "onceDate"), startDate = date(task, "startDate"), endDate = date(task, "endDate"),
    )
    private fun days(task: JSONObject): Set<Int> = task.getJSONArray("weekdays").let { list ->
        (0 until list.length()).map { list.getInt(it) }.toSet()
    }
    private fun tasks() = prefs.all.keys.filter { it.startsWith("task:") }
        .mapNotNull { get(it.removePrefix("task:")) }.sortedBy { it.optString("name") }
    private fun get(id: String) = prefs.getString("task:$id", null)?.let(::JSONObject)
    private fun persist(task: JSONObject) {
        check(prefs.edit().putString("task:${task.getString("id")}", task.toString()).commit())
    }
    private fun permitted() = Build.VERSION.SDK_INT < 31 || alarms.canScheduleExactAlarms()
    private fun snapshot(): Map<String, Any> = mapOf(
        "exactAlarms" to permitted(),
        "tasks" to tasks().map { it.toString() },
    )
    private fun changed() { channel?.invokeMethod("changed", null) }

    private fun pendingIntent(id: String, dueAt: Long): PendingIntent {
        val intent = Intent(app, ScheduledTaskReceiver::class.java).setAction(FIRE)
            .setData(Uri.Builder().scheme("kelivo-schedule").authority("task").appendPath(id).build())
            .putExtra("dueAt", dueAt)
        return PendingIntent.getBroadcast(app, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }
    private fun arm(task: JSONObject, after: Long = System.currentTimeMillis()) {
        val id = task.getString("id")
        alarms.cancel(pendingIntent(id, 0))
        task.put("nextRunAt", JSONObject.NULL)
        val next = next(task, after)
        task.put("exhausted", next == null)
        if (next == null) {
            task.put("enabled", false)
            return
        }
        if (!task.getBoolean("enabled") || !permitted()) return
        alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next, pendingIntent(id, next))
        task.put("nextRunAt", next)
    }
    fun rescheduleAll() {
        tasks().forEach { task ->
            try { arm(task); persist(task) }
            catch (error: RuntimeException) { app.backgroundRuntime.recordError("schedule_failed: ${error.message}") }
        }
        changed()
    }
    fun fire(id: String, dueAt: Long) {
        val task = get(id) ?: return
        if (!task.optBoolean("enabled") || dueAt == 0L || task.optLong("nextRunAt") != dueAt) return
        // Consume this occurrence before execution, including one-time schedules.
        try {
            arm(task, maxOf(System.currentTimeMillis(), dueAt))
            persist(task)
            start(task)
        } catch (error: RuntimeException) {
            app.backgroundRuntime.recordError("scheduled_start_failed: ${error.message}")
        }
    }
    private fun start(task: JSONObject) {
        require(active.values.none { it.getString("taskId") == task.getString("id") }) { "task_running" }
        val id = UUID.randomUUID().toString()
        val run = JSONObject().put("id", id).put("taskId", task.getString("id"))
            .put("startedAt", System.currentTimeMillis()).put("status", "running")
        val old = task.optJSONArray("runs") ?: JSONArray()
        task.put("runs", JSONArray().put(run).also { rows ->
            for (i in 0 until minOf(19, old.length())) rows.put(old.getJSONObject(i))
        })
        persist(task)
        active[id] = run
        val timeout = Runnable {
            channel?.invokeMethod("cancel", id)
            finish(id, mapOf("status" to "failed", "error" to "execution_timeout"))
        }
        deadlines[id] = timeout
        main.postDelayed(timeout, LIMIT_MS)
        // The service posts its foreground notification before warming Flutter.
        if (!app.hasEngine) app.backgroundRuntime.setForeground(false)
        app.backgroundRuntime.beginScheduledRun(id)
        dispatchPending()
        changed()
    }
    fun dispatchPending() {
        if (!ready || app.backgroundRuntime.service == null) return
        active.toMap().forEach { (id, run) ->
            if (!dispatched.add(id)) return@forEach
            val task = get(run.getString("taskId")) ?: return@forEach
            channel?.invokeMethod("run", mapOf("runId" to id, "task" to task.toString()))
        }
    }
    private fun updateRun(id: String) {
        val run = active[id] ?: return
        val task = get(run.getString("taskId")) ?: return
        val rows = task.getJSONArray("runs")
        for (i in 0 until rows.length()) if (rows.getJSONObject(i).getString("id") == id) rows.put(i, run)
        persist(task)
        changed()
    }
    private fun finish(id: String, result: Map<*, *>) {
        val run = active[id] ?: return
        val status = result["status"] as? String ?: "failed"
        run.put("status", status).put("finishedAt", System.currentTimeMillis())
        for (key in listOf("error", "preview", "conversationId")) {
            if (result[key] != null) run.put(key, result[key])
        }
        updateRun(id)
        deadlines.remove(id)?.let(main::removeCallbacks)
        active.remove(id)
        dispatched.remove(id)
        app.backgroundRuntime.endScheduledRun(id)
    }
    fun stopAll(reason: String) {
        active.keys.toList().forEach { id ->
            channel?.invokeMethod("cancel", id)
            finish(id, mapOf("status" to "interrupted", "error" to reason))
        }
    }
}
