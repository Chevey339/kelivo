package com.psyche.kelivo

import android.app.Activity
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
        if (delivered) {
            // Let Android resolve the existing singleTask activity. AppTask's
            // explicit task insertion rejects a singleTask target and crashes.
            startActivity(
                Intent(this, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                },
            )
        }
        finish()
    }
}
