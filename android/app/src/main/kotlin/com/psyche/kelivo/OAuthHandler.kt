package com.psyche.kelivo

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
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

    private var pendingResult: MethodChannel.Result? = null
    private var expectedRedirectUri: Uri? = null
    private var expectedState: String? = null
    private var sessionId: String? = null
    private var browserConnection: CustomTabsServiceConnection? = null
    private var browserContext: Context? = null
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
            failPending("authorization_cancelled", "The authorization window was closed.")
        }
    }

    fun handleCallback(uri: Uri): Boolean {
        val expected = expectedRedirectUri ?: return false
        val state = expectedState ?: return false
        val result = pendingResult ?: return false
        if (!sameRedirectTarget(uri, expected) || !sameState(uri, state)) return false

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

    private fun authenticate(
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

        pendingResult = result
        expectedRedirectUri = redirectUri
        expectedState = state
        sessionId = requestId
        val browserPackage = findBrowserPackage(activity)
        if (browserPackage == null) {
            failPending("authorization_failed", "No browser supporting Custom Tabs is available.")
            return
        }
        val context = activity.applicationContext
        val connection = object : CustomTabsServiceConnection() {
            override fun onCustomTabsServiceConnected(name: ComponentName, client: CustomTabsClient) {
                if (sessionId != requestId) return
                val browserSession = client.newSession(null)
                if (browserSession == null) {
                    failPending("authorization_failed", "Could not start the browser session.")
                    return
                }
                try {
                    val customTab = CustomTabsIntent.Builder(browserSession)
                        .setShowTitle(true)
                        .build()
                    // Let the visible browser bind back to us so Android does
                    // not freeze the loopback server while the user logs in.
                    customTab.intent.putExtra(
                        "android.support.customtabs.extra.KEEP_ALIVE",
                        Intent(activity, OAuthBrowserService::class.java),
                    )
                    customTab.launchUrl(activity, authorizationUri)
                } catch (error: ActivityNotFoundException) {
                    failPending("authorization_failed", "Could not open the authorization page.")
                }
            }

            override fun onServiceDisconnected(name: ComponentName) {
                if (sessionId == requestId) {
                    failPending("authorization_failed", "The browser session was closed.")
                }
            }
        }
        browserContext = context
        browserConnection = connection
        if (!CustomTabsClient.bindCustomTabsService(context, browserPackage, connection)) {
            failPending("authorization_failed", "Could not connect to the browser.")
        }
    }

    private fun cancel(call: MethodCall, result: MethodChannel.Result) {
        val requestId = call.argument<String>("sessionId")
        if (requestId != null && requestId == sessionId) {
            failPending(
                "authorization_cancelled",
                "Authorization was cancelled.",
            )
        }
        result.success(null)
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
        val connection = browserConnection
        val context = browserContext
        browserConnection = null
        browserContext = null
        if (connection != null && context != null) {
            try {
                context.unbindService(connection)
            } catch (_: IllegalArgumentException) {
                // Binding can fail before the connection is registered.
            }
        }
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

    private fun sameState(actual: Uri, expected: String): Boolean =
        actual.getQueryParameters("state").let { states ->
            states.size == 1 && states.first() == expected
        }
}
