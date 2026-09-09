package com.psyche.kelivo.background

import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import com.psyche.kelivo.KelivoApplication

class GenerationForegroundService : Service() {
    companion object { const val STOP = "kelivo.background.STOP" }
    private val runtime get() = (application as KelivoApplication).backgroundRuntime
    private var wakeLock: PowerManager.WakeLock? = null
    private var stopping = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // A new run can arrive before Android destroys a just-stopped service.
        stopping = false
        // Even if completion raced service creation, satisfy the platform's
        // startForeground deadline before stopping the now-unneeded service.
        try {
            if (Build.VERSION.SDK_INT >= 29) startForeground(
                BackgroundRuntime.NOTIFICATION_ID, runtime.buildNotification(), ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
            else startForeground(BackgroundRuntime.NOTIFICATION_ID, runtime.buildNotification())
            runtime.serviceStarted(this)
            if (intent?.action == STOP) runtime.stopTasks()
            else if (!runtime.shouldRunService()) stopGenerationService()
            else acquireWakeLock()
        } catch (error: RuntimeException) {
            runtime.serviceFailed("foreground_service_failed: ${error.message}")
            stopGenerationService()
        }
        return START_NOT_STICKY
    }

    fun refresh() {
        if (stopping) return
        val manager = getSystemService(android.app.NotificationManager::class.java)
        manager.notify(BackgroundRuntime.NOTIFICATION_ID, runtime.buildNotification())
    }

    @android.annotation.SuppressLint("WakelockTimeout")
    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        wakeLock = getSystemService(PowerManager::class.java).newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK, "Kelivo:Generation").apply {
            setReferenceCounted(false)
            acquire()
        }
    }

    override fun onTaskRemoved(rootIntent: Intent?) { runtime.onTaskRemoved() }

    override fun onTimeout(startId: Int, fgsType: Int) {
        runtime.stopTasks("foreground_service_timeout")
        stopGenerationService()
    }

    fun stopGenerationService() {
        if (stopping) return
        stopping = true
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        runtime.serviceStopped(this)
        stopSelf()
    }

    override fun onDestroy() {
        if (!stopping && runtime.shouldRunService()) runtime.stopTasks("foreground_service_stopped")
        stopGenerationService()
        super.onDestroy()
    }
}
