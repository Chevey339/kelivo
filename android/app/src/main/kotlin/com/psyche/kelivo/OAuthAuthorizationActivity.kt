package com.psyche.kelivo

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.result.contract.ActivityResultContracts
import androidx.browser.auth.AuthTabIntent

/** Owns browser results across recreation of the Flutter activity. */
class OAuthAuthorizationActivity : ComponentActivity() {
    private val requestId: String get() = intent.getStringExtra(SESSION_ID).orEmpty()
    private val authLauncher = AuthTabIntent.registerActivityResultLauncher(this) { result ->
        if (result.resultCode == AuthTabIntent.RESULT_CANCELED) {
            OAuthHandler.cancelAuthorization(requestId)
        } else {
            OAuthHandler.completeAuthTab(requestId,
                if (result.resultCode == AuthTabIntent.RESULT_OK) result.resultUri else null)
        }
        finish()
    }
    private val customTabLauncher = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult(),
    ) {
        // A successful custom-scheme callback completes the session first.
        // Closing the browser without one is an explicit cancellation.
        OAuthHandler.cancelAuthorization(requestId)
        finish()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (!OAuthHandler.attachAuthorizationActivity(this, requestId)) {
            // Process death invalidates the in-memory PKCE request. A cold app
            // starts a fresh sign-in instead of accepting an orphaned callback.
            finish()
        }
    }

    override fun onDestroy() {
        // The window can finish before a browser activity result is delivered.
        // Configuration recreation keeps the request alive.
        if (isFinishing && !isChangingConfigurations) {
            OAuthHandler.cancelAuthorization(requestId)
        }
        super.onDestroy()
    }

    fun launchAuthTab(tab: AuthTabIntent, uri: Uri, scheme: String) {
        tab.launch(authLauncher, uri, scheme)
    }

    fun launchCustomTab(intent: Intent) {
        customTabLauncher.launch(intent)
    }

    companion object {
        const val SESSION_ID = "oauth.sessionId"
    }
}
