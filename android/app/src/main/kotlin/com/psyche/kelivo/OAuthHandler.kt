package com.psyche.kelivo

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.browser.auth.AuthTabIntent
import androidx.browser.customtabs.CustomTabsClient
import androidx.browser.customtabs.CustomTabsIntent
import androidx.browser.customtabs.CustomTabsService
import androidx.browser.customtabs.CustomTabsServiceConnection
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference

internal object OAuthHandler {
    private const val CHANNEL_NAME = "app.oauth"
    private const val CALLBACK_SCHEME = "psyche.kelivo"
    private const val CALLBACK_HOST = "mcp-oauth-callback"
    private const val BROWSER_BIND_TIMEOUT_MS = 1000L

    private var authorizationUri: Uri? = null
    private var browserPackage: String? = null
    private var browserConnection: BrowserConnection? = null
    private var authorizationActivity = WeakReference<OAuthAuthorizationActivity>(null)
    private var launched = false
    private var completionOnly = false
    private var pendingResult: MethodChannel.Result? = null
    private var expectedRedirectUri: Uri? = null
    private var expectedState: String? = null
    private var sessionId: String? = null
    private var host = WeakReference<Activity>(null)

    fun configure(activity: Activity, messenger: BinaryMessenger) {
        host = WeakReference(activity)
        MethodChannel(messenger, CHANNEL_NAME).setMethodCallHandler { call, result ->
            when (call.method) {
                "authenticate" -> {
                    val current = host.get()
                    if (current == null) result.error("foreground_required", "Open Kelivo to authorize this connection.", null)
                    else authenticate(current, call, result)
                }
                "cancel" -> cancel(call, result)
                else -> result.notImplemented()
            }
        }
    }

    fun detachActivity(activity: Activity) {
        if (host.get() === activity) {
            host.clear()
            // The application owns the Flutter engine and pending authorization.
            // Recreating its UI is not a user cancellation.
        }
    }

    fun handleCallback(uri: Uri): Boolean {
        val expected = expectedRedirectUri ?: return false
        val state = expectedState ?: return false
        val result = pendingResult ?: return false
        if (!sameRedirectTarget(uri, expected) || !sameState(uri, state) || !validCallbackResult(uri)) return false

        clearPending()
        result.success(uri.toString())
        return true
    }

    internal fun findBrowserPackage(context: Context): String? {
        val candidates = context.packageManager.queryIntentServices(
            Intent(CustomTabsService.ACTION_CUSTOM_TABS_CONNECTION),
            0,
        ).map { it.serviceInfo.packageName }.distinct()
        // AndroidX prefers a supported default browser, then tests our candidates.
        return CustomTabsClient.getPackageName(context, candidates)
    }

    internal fun authenticate(
        activity: Activity,
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        if (pendingResult != null) {
            result.error(
                "authorization_in_progress",
                "An authorization session is already in progress.",
                null,
            )
            return
        }

        val arguments = call.arguments as? Map<*, *>
        val authorizationUri = arguments?.get("url")?.toString()?.let(Uri::parse)
        val redirectUri = arguments?.get("redirectUri")?.toString()?.let(Uri::parse)
        val state = authorizationUri?.getQueryParameters("state")?.singleOrNull()
        val requestId = arguments?.get("sessionId") as? String
        if (
            authorizationUri?.scheme != "https" ||
            !validRedirectUri(redirectUri) ||
            state.isNullOrEmpty() ||
            requestId.isNullOrEmpty()
        ) {
            result.error(
                "invalid_arguments",
                "A valid HTTPS authorization URL, state, and Kelivo callback URI are required.",
                null,
            )
            return
        }

        completionOnly = arguments?.get("completionOnly") == true
        pendingResult = result
        expectedRedirectUri = redirectUri
        expectedState = state
        sessionId = requestId
        this.authorizationUri = authorizationUri
        browserPackage = findBrowserPackage(activity)
        if (browserPackage == null) {
            failPending("authorization_failed", "No browser supporting Custom Tabs is available.")
            return
        }
        try {
            activity.startActivity(Intent(activity, OAuthAuthorizationActivity::class.java)
                .putExtra(OAuthAuthorizationActivity.SESSION_ID, requestId))
        } catch (_: ActivityNotFoundException) {
            failPending("authorization_failed", "Could not open the authorization window.")
        }
    }

    internal fun attachAuthorizationActivity(activity: OAuthAuthorizationActivity, requestId: String): Boolean {
        if (sessionId != requestId || pendingResult == null) return false
        authorizationActivity = WeakReference(activity)
        if (!launched) {
            if (browserConnection == null) {
                val connection = BrowserConnection(activity.applicationContext, requestId)
                browserConnection = connection
                connection.connect(browserPackage ?: return false)
            } else {
                launchBrowser()
            }
        }
        return true
    }

    /** Owns one optional service binding across authorization-window recreation. */
    private class BrowserConnection(
        private val context: Context,
        private val requestId: String,
    ) : CustomTabsServiceConnection() {
        private val handler = Handler(Looper.getMainLooper())
        private val timeout = Runnable { finishConnecting(null) }
        private var bound = false
        var connecting = true
            private set
        var client: CustomTabsClient? = null
            private set

        fun connect(packageName: String) {
            handler.postDelayed(timeout, BROWSER_BIND_TIMEOUT_MS)
            // Even a rejected bind can register a connection that needs unbinding.
            bound = true
            try {
                if (!CustomTabsClient.bindCustomTabsService(context, packageName, this)) {
                    finishConnecting(null)
                }
            } catch (_: SecurityException) {
                finishConnecting(null)
            }
        }

        override fun onCustomTabsServiceConnected(name: ComponentName, client: CustomTabsClient) {
            finishConnecting(client)
        }

        override fun onServiceDisconnected(name: ComponentName) = unavailable()
        override fun onNullBinding(name: ComponentName) = unavailable()
        override fun onBindingDied(name: ComponentName) = unavailable()

        private fun isCurrent() = browserConnection === this && sessionId == requestId

        private fun finishConnecting(client: CustomTabsClient?) {
            if (!isCurrent() || !connecting) return
            connecting = false
            this.client = client
            handler.removeCallbacks(timeout)
            if (client == null) close()
            // Resolve against the current owner, not the Activity that started binding.
            launchBrowser()
        }

        private fun unavailable() {
            if (!isCurrent()) return
            if (connecting) finishConnecting(null)
            else close() // Losing an optional binding must not cancel an open browser.
        }

        fun close() {
            handler.removeCallbacks(timeout)
            connecting = false
            client = null
            if (bound) {
                bound = false
                try {
                    context.unbindService(this)
                } catch (_: IllegalArgumentException) {
                    // Binding was rejected before Android registered the connection.
                }
            }
        }
    }

    private fun launchBrowser() {
        val connection = browserConnection ?: return
        if (launched || connection.connecting) return
        val activity = authorizationActivity.get() ?: return
        if (activity.isFinishing || activity.isDestroyed) return
        val uri = authorizationUri ?: return
        val packageName = browserPackage ?: return
        // A registered session lets the browser bind back to keep our loopback
        // listener running. Browsers that reject binding can still open the page.
        val keepAlive = Intent(activity, OAuthBrowserService::class.java)
        try {
            if (CustomTabsClient.isAuthTabSupported(activity, packageName)) {
                val session = try { connection.client?.newAuthTabSession(null, null) }
                    catch (_: SecurityException) { null }
                if (session == null) connection.close()
                val tab = AuthTabIntent.Builder().apply {
                    if (session != null) setSession(session)
                }.build()
                tab.intent.setPackage(packageName)
                if (session != null) tab.intent.putExtra("android.support.customtabs.extra.KEEP_ALIVE", keepAlive)
                launched = true
                activity.launchAuthTab(tab, uri, CALLBACK_SCHEME)
            } else {
                val session = try { connection.client?.newSession(null) }
                    catch (_: SecurityException) { null }
                if (session == null) connection.close()
                val tab = CustomTabsIntent.Builder(session).setShowTitle(true).build()
                tab.intent.setPackage(packageName)
                tab.intent.data = uri
                if (session != null) tab.intent.putExtra("android.support.customtabs.extra.KEEP_ALIVE", keepAlive)
                launched = true
                activity.launchCustomTab(tab.intent)
            }
        } catch (_: ActivityNotFoundException) {
            failPending("authorization_failed", "Could not open the authorization page.")
        }
    }

    private fun cancel(call: MethodCall, result: MethodChannel.Result) {
        val requestId = call.argument<String>("sessionId")
        if (requestId != null) cancelAuthorization(requestId)
        result.success(null)
    }

    internal fun cancelAuthorization(requestId: String) {
        if (sessionId == requestId) {
            failPending("authorization_cancelled", "Authorization was cancelled.")
        }
    }

    internal fun completeAuthTab(requestId: String, uri: Uri?) {
        if (sessionId != requestId) return
        if (uri == null || !handleCallback(uri)) {
            failPending("authorization_failed", "The browser returned an invalid authorization callback.")
        }
    }

    private fun failPending(code: String, message: String) {
        val result = pendingResult ?: return
        clearPending()
        result.error(code, message, null)
    }

    private fun clearPending() {
        pendingResult = null
        expectedRedirectUri = null
        expectedState = null
        sessionId = null
        authorizationUri = null
        browserPackage = null
        val connection = browserConnection
        browserConnection = null
        connection?.close()
        launched = false
        completionOnly = false
        val owner = authorizationActivity.get()
        authorizationActivity.clear()
        owner?.finish()
    }

    private fun validRedirectUri(uri: Uri?): Boolean =
        uri != null &&
            uri.scheme.equals(CALLBACK_SCHEME, ignoreCase = true) &&
            uri.host.equals(CALLBACK_HOST, ignoreCase = true) &&
            uri.pathSegments.size == 1 &&
            uri.pathSegments.first().isNotEmpty() &&
            uri.query == null &&
            uri.fragment == null

    private fun sameRedirectTarget(actual: Uri, expected: Uri): Boolean =
        actual.scheme.equals(expected.scheme, ignoreCase = true) &&
            actual.host.equals(expected.host, ignoreCase = true) &&
            actual.port == expected.port &&
            actual.path == expected.path &&
            actual.fragment == null

    private fun validCallbackResult(uri: Uri): Boolean {
        if (uri.getQueryParameters("iss").size > 1) return false
        val codes = uri.getQueryParameters("code")
        val errors = uri.getQueryParameters("error")
        if (completionOnly) return codes.isEmpty() && errors.isEmpty()
        return (codes.size == 1 && codes.first().isNotEmpty() && errors.isEmpty()) ||
            (errors.size == 1 && errors.first().isNotEmpty() && codes.isEmpty())
    }

    private fun sameState(actual: Uri, expected: String): Boolean =
        actual.getQueryParameters("state").let { states ->
            states.size == 1 && states.first() == expected
        }
}
