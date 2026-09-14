package com.psyche.kelivo

import android.app.Activity
import android.app.ActivityManager
import android.content.Intent
import android.os.Bundle

class OAuthCallbackActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleCallback(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleCallback(intent)
    }

    private fun handleCallback(intent: Intent?) {
        val delivered = intent?.data?.let(OAuthHandler::handleCallback) == true
        val mainTask = if (delivered) findMainTask() else null
        if (mainTask != null) {
            mainTask.startActivity(
                this,
                Intent(this, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                },
                null,
            )
        }
        finish()
    }

    private fun findMainTask(): ActivityManager.AppTask? {
        val activityManager = getSystemService(ACTIVITY_SERVICE) as ActivityManager
        return activityManager.appTasks.firstOrNull { task ->
            val taskInfo = task.taskInfo
            taskInfo.baseActivity?.className == MainActivity::class.java.name ||
                taskInfo.baseIntent.component?.className == MainActivity::class.java.name
        }
    }
}
