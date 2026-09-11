package com.psyche.kelivo.scheduled

import android.app.AlarmManager
import android.content.Context
import com.psyche.kelivo.KelivoApplication
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.StandardMethodCodec
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import java.nio.ByteBuffer

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28], application = KelivoApplication::class)
class ScheduledTasksTest {
    private class Messenger : BinaryMessenger {
        var handler: BinaryMessenger.BinaryMessageHandler? = null
        override fun setMessageHandler(channel: String, value: BinaryMessenger.BinaryMessageHandler?) { handler = value }
        override fun send(channel: String, message: ByteBuffer?) {}
        override fun send(channel: String, message: ByteBuffer?, callback: BinaryMessenger.BinaryReply?) {}
        fun call(method: String, args: Any? = null): Any? {
            val data = StandardMethodCodec.INSTANCE.encodeMethodCall(MethodCall(method, args))
            data.flip()
            var result: Any? = null
            handler!!.onMessage(data) { reply ->
                reply?.flip()
                result = reply?.let { StandardMethodCodec.INSTANCE.decodeEnvelope(it) }
            }
            return result
        }
    }
    private val app get() = RuntimeEnvironment.getApplication() as KelivoApplication
    private val prefs get() = app.getSharedPreferences("kelivo_scheduled_tasks", Context.MODE_PRIVATE)
    private fun task(id: String = "a", enabled: Boolean = true) = mapOf(
        "id" to id, "name" to "Morning", "prompt" to "Hello", "assistantId" to "assistant",
        "hour" to 8, "minute" to 0, "weekdays" to (1..7).toList(), "enabled" to enabled,
    )
    private fun setup(): Messenger = Messenger().also { app.scheduledTasks.configure(it) }
    private fun stored(id: String = "a") = JSONObject(prefs.getString("task:$id", "")!!)

    @Test fun pauseAndDeleteRemoveTheAlarmAndKeepHistory() {
        val m = setup()
        m.call("save", task())
        val alarms = shadowOf(app.getSystemService(AlarmManager::class.java))
        assertEquals(1, alarms.scheduledAlarms.size)
        m.call("save", task(enabled = false))
        assertEquals(0, alarms.scheduledAlarms.size)
        m.call("save", task())
        m.call("delete", mapOf("id" to "a"))
        assertEquals(0, alarms.scheduledAlarms.size)
        assertFalse(prefs.contains("task:a"))
    }
    @Test fun idsWithTheSameHashHaveIndependentAlarms() {
        val m = setup()
        assertEquals("Aa".hashCode(), "BB".hashCode())
        m.call("save", task("Aa")); m.call("save", task("BB"))
        assertEquals(2, shadowOf(app.getSystemService(AlarmManager::class.java)).scheduledAlarms.size)
    }
    @Test fun duplicateDeliveryDoesNotRunTwiceAndRearmsBeforeFlutterStarts() {
        val m = setup()
        m.call("save", task())
        val due = System.currentTimeMillis() - 1000
        prefs.edit().putString("task:a", stored().put("nextRunAt", due).toString()).commit()
        app.scheduledTasks.fire("a", due)
        app.scheduledTasks.fire("a", due)
        assertEquals(1, stored().getJSONArray("runs").length())
        assertTrue(stored().getLong("nextRunAt") > due)
        assertTrue(app.backgroundRuntime.shouldRunService())
        assertFalse(app.hasEngine)
        val run = stored().getJSONArray("runs").getJSONObject(0)
        m.call("finish", mapOf("runId" to run.getString("id"), "status" to "completed"))
        assertFalse(app.backgroundRuntime.shouldRunService())
        assertEquals("completed", stored().getJSONArray("runs").getJSONObject(0).getString("status"))
    }
    @Test fun restartedProcessMarksRunningRecordsInterruptedWithoutReplaying() {
        val m = setup(); m.call("save", task())
        val runs = JSONArray().put(JSONObject().put("id", "old").put("status", "running"))
        prefs.edit().putString("task:a", stored().put("runs", runs).toString()).commit()
        ScheduledTasks(app).rescheduleAll()
        assertEquals("interrupted", stored().getJSONArray("runs").getJSONObject(0).getString("status"))
        assertFalse(app.backgroundRuntime.shouldRunService())
    }
    @Test fun staleFinishedCallbackCannotFinishAnotherRun() {
        val m = setup(); m.call("save", task()); m.call("runNow", mapOf("id" to "a"))
        m.call("finish", mapOf("runId" to "stale", "status" to "completed"))
        assertTrue(app.backgroundRuntime.shouldRunService())
        assertEquals("running", stored().getJSONArray("runs").getJSONObject(0).getString("status"))
    }
}
