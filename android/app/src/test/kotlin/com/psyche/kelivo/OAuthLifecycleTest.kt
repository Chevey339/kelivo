package com.psyche.kelivo

import android.app.Activity
import android.app.Application
import android.content.ComponentName
import android.content.Intent
import android.content.IntentFilter
import android.content.ServiceConnection
import android.net.Uri
import android.os.Bundle
import android.os.Looper
import androidx.browser.auth.AuthTabIntent
import androidx.browser.auth.AuthTabSessionToken
import androidx.browser.customtabs.CustomTabsService
import androidx.browser.customtabs.CustomTabsSessionToken
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer
import java.time.Duration
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28, 35], application = OAuthLifecycleTest.TestApplication::class, manifest = Config.NONE)
class OAuthLifecycleTest {
    private val activity = Robolectric.buildActivity(Activity::class.java).setup().get()
    private val redirect = "psyche.kelivo://mcp-oauth-callback/test"
    private val sessions = mutableListOf<String>()
    private val browser = ComponentName("test.browser", "test.browser.CustomTabsService")
    private val application get() = activity.application as TestApplication

    @Before fun setup() {
        val manager = shadowOf(activity.packageManager)
        val browser = ComponentName("test.browser", "test.browser.CustomTabsService")
        manager.addServiceIfNotPresent(browser)
        manager.addIntentFilterForService(browser, IntentFilter(CustomTabsService.ACTION_CUSTOM_TABS_CONNECTION))
        OAuthHandler.configure(activity, object : BinaryMessenger {
            override fun send(channel: String, message: ByteBuffer?) = Unit
            override fun send(channel: String, message: ByteBuffer?, callback: BinaryMessenger.BinaryReply?) = Unit
            override fun setMessageHandler(channel: String, handler: BinaryMessenger.BinaryMessageHandler?) = Unit
        })
    }

    @After fun cleanup() { sessions.forEach(OAuthHandler::cancelAuthorization) }

    private fun start(id: String, completionOnly: Boolean = false): Result {
        sessions.add(id)
        val result = Result()
        OAuthHandler.authenticate(activity, MethodCall("authenticate", mapOf(
            "url" to "https://auth.example.com/authorize?state=$id",
            "redirectUri" to redirect,
            "sessionId" to id,
            "completionOnly" to completionOnly,
        )), result)
        assertNull(result.error)
        assertEquals(OAuthAuthorizationActivity::class.java.name,
            shadowOf(activity).nextStartedActivity.component?.className)
        return result
    }

    @Test fun recreatingFlutterActivityDoesNotCancelBrowserAuthorization() {
        val result = start("recreate")
        OAuthHandler.detachActivity(activity)
        assertNull(result.error)
        assertTrue(OAuthHandler.handleCallback(Uri.parse("$redirect?code=ok&state=recreate")))
        assertEquals(1, result.successes)
    }

    @Test fun customTabStartsWhenBrowserServiceBindingIsRejected() {
        assertBrowserStartsWithoutBinding("no-bind-custom-tab", authTab = false)
    }

    @Test fun authTabStartsWhenBrowserServiceBindingIsRejected() {
        assertBrowserStartsWithoutBinding("no-bind-auth-tab", authTab = true)
    }

    @Test fun customTabUsesRegisteredSessionForKeepAlive() {
        assertBrowserUsesSession("bound-custom-tab", authTab = false)
    }

    @Test fun authTabUsesRegisteredSessionForKeepAlive() {
        assertBrowserUsesSession("bound-auth-tab", authTab = true)
    }

    @Test fun rejectedCustomTabSessionStillOpensTheBrowser() {
        assertRejectedSessionStillOpens("rejected-custom-session", authTab = false)
    }

    @Test fun rejectedAuthTabSessionStillOpensTheBrowser() {
        assertRejectedSessionStillOpens("rejected-auth-session", authTab = true)
    }

    @Test fun sessionSecurityExceptionStillOpensTheBrowser() {
        assertRejectedSessionStillOpens("session-security", authTab = false, denied = true)
    }

    @Test fun authSessionSecurityExceptionStillOpensTheBrowser() {
        assertRejectedSessionStillOpens("auth-session-security", authTab = true, denied = true)
    }

    private fun assertRejectedSessionStillOpens(id: String, authTab: Boolean, denied: Boolean = false) {
        if (authTab) enableAuthTab()
        browserService().apply {
            acceptSession = false
            denySession = denied
        }
        val result = start(id)
        val window = openWindow(id)
        shadowOf(Looper.getMainLooper()).idle()
        val launched = shadowOf(window.get()).nextStartedActivity
        assertNotNull(launched)
        assertEquals(authTab, launched.getBooleanExtra(AuthTabIntent.EXTRA_LAUNCH_AUTH_TAB, false))
        assertNull(CustomTabsSessionToken.getSessionTokenFromIntent(launched))
        assertFalse(launched.hasExtra("android.support.customtabs.extra.KEEP_ALIVE"))
        assertTrue(shadowOf(application).boundServiceConnections.isEmpty())
        assertNull(result.error)
        assertTrue(OAuthHandler.handleCallback(Uri.parse("$redirect?code=ok&state=$id")))
        assertEquals(1, result.successes)
        window.pause().stop().destroy()
    }

    @Test fun bindingSecurityExceptionStillOpensTheBrowser() {
        shadowOf(application).setThrowInBindService(SecurityException("Browser rejects binding"))
        val result = start("bind-security")
        val window = openWindow("bind-security")
        assertNotNull(shadowOf(window.get()).nextStartedActivity)
        assertTrue(shadowOf(application).boundServiceConnections.isEmpty())
        assertNull(result.error)
        OAuthHandler.cancelAuthorization("bind-security")
        window.pause().stop().destroy()
    }

    @Test fun bindingTimeoutLaunchesOnceAndIgnoresALateConnection() {
        val service = browserService()
        application.delayBrowserBinding = true
        val result = start("bind-timeout")
        val window = openWindow("bind-timeout")
        val connection = application.delayedConnections.single()
        assertNull(shadowOf(window.get()).nextStartedActivity)
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(1000))
        val launched = shadowOf(window.get()).nextStartedActivity
        assertNotNull(launched)
        assertNull(CustomTabsSessionToken.getSessionTokenFromIntent(launched))
        assertTrue(application.delayedConnections.isEmpty())
        connection.onServiceConnected(browser, service.onBind(Intent()))
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(5))
        assertNull(shadowOf(window.get()).nextStartedActivity)
        assertNull(service.customSession)
        assertNull(result.error)
        assertTrue(OAuthHandler.handleCallback(Uri.parse("$redirect?code=ok&state=bind-timeout")))
        window.pause().stop().destroy()
    }

    @Test fun nullBindingLaunchesWithoutWaitingForTheTimeout() {
        assertUnavailableBindingStillLaunches("null-binding") { it.onNullBinding(browser) }
    }

    @Test fun bindingDeathLaunchesWithoutWaitingForTheTimeout() {
        assertUnavailableBindingStillLaunches("binding-died") { it.onBindingDied(browser) }
    }

    @Test fun earlyDisconnectionLaunchesWithoutWaitingForTheTimeout() {
        assertUnavailableBindingStillLaunches("early-disconnect") { it.onServiceDisconnected(browser) }
    }

    private fun assertUnavailableBindingStillLaunches(id: String, unavailable: (ServiceConnection) -> Unit) {
        application.delayBrowserBinding = true
        val result = start(id)
        val window = openWindow(id)
        unavailable(application.delayedConnections.single())
        assertNotNull(shadowOf(window.get()).nextStartedActivity)
        assertTrue(application.delayedConnections.isEmpty())
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(5))
        assertNull(shadowOf(window.get()).nextStartedActivity)
        assertNull(result.error)
        OAuthHandler.cancelAuthorization(id)
        window.pause().stop().destroy()
    }

    @Test fun disconnectingAfterLaunchDoesNotCancelAuthorizationOrLaunchAgain() {
        browserService()
        val result = start("disconnect-open")
        val window = openWindow("disconnect-open")
        shadowOf(Looper.getMainLooper()).idle()
        assertNotNull(shadowOf(window.get()).nextStartedActivity)
        shadowOf(application).boundServiceConnections.single().onServiceDisconnected(browser)
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(5))
        assertNull(shadowOf(window.get()).nextStartedActivity)
        assertNull(result.error)
        assertTrue(shadowOf(application).boundServiceConnections.isEmpty())
        assertTrue(OAuthHandler.handleCallback(Uri.parse("$redirect?code=ok&state=disconnect-open")))
        assertEquals(1, result.successes)
        window.pause().stop().destroy()
    }

    @Test fun connectionDuringWindowRecreationLaunchesOnlyTheRestoredWindow() {
        val service = browserService()
        application.delayBrowserBinding = true
        val result = start("recreate-binding")
        val first = openWindow("recreate-binding")
        val connection = application.delayedConnections.single()
        first.pause().stop().destroy()
        connection.onServiceConnected(browser, service.onBind(Intent()))
        assertNull(shadowOf(first.get()).nextStartedActivity)
        val restored = openWindow("recreate-binding")
        val launched = shadowOf(restored.get()).nextStartedActivity
        assertNotNull(launched)
        assertNotNull(CustomTabsSessionToken.getSessionTokenFromIntent(launched))
        assertEquals(listOf(connection), application.delayedConnections)
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(5))
        assertNull(shadowOf(restored.get()).nextStartedActivity)
        assertNull(result.error)
        assertTrue(OAuthHandler.handleCallback(Uri.parse("$redirect?code=ok&state=recreate-binding")))
        assertTrue(application.delayedConnections.isEmpty())
        restored.pause().stop().destroy()
    }

    @Test fun timeoutDuringWindowRecreationLaunchesOnlyTheRestoredWindow() {
        application.delayBrowserBinding = true
        val result = start("recreate-timeout")
        val first = openWindow("recreate-timeout")
        first.pause().stop().destroy()
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(2))
        assertNull(shadowOf(first.get()).nextStartedActivity)
        val restored = openWindow("recreate-timeout")
        assertNotNull(shadowOf(restored.get()).nextStartedActivity)
        assertTrue(application.delayedConnections.isEmpty())
        assertNull(result.error)
        OAuthHandler.cancelAuthorization("recreate-timeout")
        restored.pause().stop().destroy()
    }

    @Test fun cancelledBindingCannotLaunchOrInterfereWithTheNextRequest() {
        val service = browserService()
        application.delayBrowserBinding = true
        val oldResult = start("cancel-bind")
        val oldWindow = openWindow("cancel-bind")
        val oldConnection = application.delayedConnections.single()
        oldWindow.get().onBackPressedDispatcher.onBackPressed()
        oldWindow.pause().stop().destroy()
        assertEquals("authorization_cancelled", oldResult.error)
        assertTrue(application.delayedConnections.isEmpty())

        val current = start("next-bind")
        val window = openWindow("next-bind")
        val connection = application.delayedConnections.single()
        oldConnection.onServiceConnected(browser, service.onBind(Intent()))
        oldConnection.onBindingDied(browser)
        assertNull(shadowOf(oldWindow.get()).nextStartedActivity)
        assertNull(shadowOf(window.get()).nextStartedActivity)
        assertEquals(listOf(connection), application.delayedConnections)
        connection.onServiceConnected(browser, service.onBind(Intent()))
        assertNotNull(shadowOf(window.get()).nextStartedActivity)
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(5))
        assertNull(shadowOf(window.get()).nextStartedActivity)
        assertNull(current.error)
        assertTrue(OAuthHandler.handleCallback(Uri.parse("$redirect?code=ok&state=next-bind")))
        assertEquals(1, current.successes)
        assertTrue(application.delayedConnections.isEmpty())
        window.pause().stop().destroy()
    }

    private fun enableAuthTab() {
        val browser = ComponentName("test.browser", "test.browser.CustomTabsService")
        shadowOf(activity.packageManager).clearIntentFilterForService(browser)
        shadowOf(activity.packageManager).addIntentFilterForService(browser,
            IntentFilter(CustomTabsService.ACTION_CUSTOM_TABS_CONNECTION).apply {
                addCategory(CustomTabsService.CATEGORY_AUTH_TAB)
            },
        )
    }

    private fun browserService(): TestBrowserService {
        val service = Robolectric.buildService(TestBrowserService::class.java).create().get()
        shadowOf(activity.application).setComponentNameAndServiceForBindService(
            ComponentName("test.browser", "test.browser.CustomTabsService"),
            service.onBind(Intent(CustomTabsService.ACTION_CUSTOM_TABS_CONNECTION)),
        )
        return service
    }

    private fun openWindow(id: String) = Robolectric.buildActivity(
        OAuthAuthorizationActivity::class.java,
        Intent(activity, OAuthAuthorizationActivity::class.java)
            .putExtra(OAuthAuthorizationActivity.SESSION_ID, id),
    ).create().start().resume()

    private fun assertBrowserUsesSession(id: String, authTab: Boolean) {
        if (authTab) enableAuthTab()
        val service = browserService()
        val result = start(id)
        val window = openWindow(id)
        shadowOf(Looper.getMainLooper()).idle()
        val launched = shadowOf(window.get()).nextStartedActivity
        assertNotNull(launched)
        if (authTab) {
            val token = AuthTabSessionToken.createSessionTokenFromIntent(launched)
            assertNotNull("Auth Tab needs a registered session for KEEP_ALIVE", token)
            assertEquals(service.authSession, token)
        } else {
            val token = CustomTabsSessionToken.getSessionTokenFromIntent(launched)
            assertNotNull("Custom Tab needs a registered session for KEEP_ALIVE", token)
            assertEquals(service.customSession, token)
        }
        @Suppress("DEPRECATION")
        val keepAlive = launched.getParcelableExtra<Intent>("android.support.customtabs.extra.KEEP_ALIVE")
        assertEquals(OAuthBrowserService::class.java.name, keepAlive?.component?.className)
        assertEquals(1, shadowOf(activity.application).boundServiceConnections.size)
        assertTrue(OAuthHandler.handleCallback(Uri.parse("$redirect?code=ok&state=$id")))
        assertEquals(1, result.successes)
        assertTrue(shadowOf(activity.application).boundServiceConnections.isEmpty())
        window.pause().stop().destroy()
    }

    private fun assertBrowserStartsWithoutBinding(id: String, authTab: Boolean) {
        shadowOf(activity.application).declareActionUnbindable(CustomTabsService.ACTION_CUSTOM_TABS_CONNECTION)
        if (authTab) enableAuthTab()
        val result = start(id)
        val intent = Intent(activity, OAuthAuthorizationActivity::class.java)
            .putExtra(OAuthAuthorizationActivity.SESSION_ID, id)
        val window = Robolectric.buildActivity(OAuthAuthorizationActivity::class.java, intent)
            .create().start().resume()
        assertNull(result.error)
        val launched = shadowOf(window.get()).nextStartedActivity
        assertNotNull(launched)
        assertEquals("test.browser", launched.`package`)
        assertEquals("https://auth.example.com/authorize?state=$id", launched.data.toString())
        assertEquals(authTab, launched.getBooleanExtra(AuthTabIntent.EXTRA_LAUNCH_AUTH_TAB, false))
        if (authTab) {
            assertEquals("psyche.kelivo", launched.getStringExtra(AuthTabIntent.EXTRA_REDIRECT_SCHEME))
            OAuthHandler.completeAuthTab(id, Uri.parse("$redirect?code=ok&state=$id"))
        } else {
            assertTrue(OAuthHandler.handleCallback(Uri.parse("$redirect?code=ok&state=$id")))
        }
        assertEquals(1, result.successes)
        assertTrue(shadowOf(application).boundServiceConnections.isEmpty())
        window.pause().stop().destroy()
    }

    @Test fun invalidCallbacksDoNotConsumeThePendingSession() {
        val result = start("current")
        for (query in listOf("code=bad&state=old", "code=one&code=two&state=current",
            "state=current", "code=one&error=denied&state=current", "code=one&state=current&state=current")) {
            assertFalse(OAuthHandler.handleCallback(Uri.parse("$redirect?$query")))
            assertEquals(0, result.successes)
        }
        assertTrue(OAuthHandler.handleCallback(Uri.parse("$redirect?code=ok&state=current")))
        assertEquals(1, result.successes)
        assertFalse(OAuthHandler.handleCallback(Uri.parse("$redirect?code=ok&state=current")))
    }

    @Test fun oldCleanupCannotCancelANewerSession() {
        val old = start("old")
        OAuthHandler.cancelAuthorization("old")
        assertEquals("authorization_cancelled", old.error)
        val current = start("new")
        OAuthHandler.cancelAuthorization("old")
        OAuthHandler.completeAuthTab("old", null)
        assertNull(current.error)
        assertTrue(OAuthHandler.handleCallback(Uri.parse("$redirect?code=ok&state=new")))
    }

    @Test fun loopbackCompletionAcceptsOnlyTheStateSignal() {
        val result = start("loopback", completionOnly = true)
        assertFalse(OAuthHandler.handleCallback(Uri.parse("$redirect?code=leaked&state=loopback")))
        assertTrue(OAuthHandler.handleCallback(Uri.parse("$redirect?state=loopback")))
        assertEquals(1, result.successes)
    }

    @Test fun validCallbackReturnsToTheMainActivityThroughNormalTaskResolution() {
        val result = start("callback-return")
        val intent = Intent(activity, OAuthCallbackActivity::class.java)
            .setData(Uri.parse("$redirect?code=ok&state=callback-return"))
        val callback = Robolectric.buildActivity(OAuthCallbackActivity::class.java, intent).create()
        assertEquals(1, result.successes)
        val launched = shadowOf(callback.get()).nextStartedActivity
        assertNotNull(launched)
        assertEquals(MainActivity::class.java.name, launched.component?.className)
        assertTrue(launched.flags and Intent.FLAG_ACTIVITY_NEW_TASK != 0)
        assertTrue(launched.flags and Intent.FLAG_ACTIVITY_CLEAR_TOP != 0)
        assertTrue(callback.get().isFinishing)
        callback.destroy()
    }

    @Test fun invalidCallbackDoesNotOpenTheMainActivityOrConsumeTheRequest() {
        val result = start("callback-current")
        val intent = Intent(activity, OAuthCallbackActivity::class.java)
            .setData(Uri.parse("$redirect?code=wrong&state=callback-old"))
        val callback = Robolectric.buildActivity(OAuthCallbackActivity::class.java, intent).create()
        assertNull(shadowOf(callback.get()).nextStartedActivity)
        assertTrue(callback.get().isFinishing)
        assertEquals(0, result.successes)
        assertNull(result.error)
        callback.destroy()
        assertTrue(OAuthHandler.handleCallback(Uri.parse("$redirect?code=ok&state=callback-current")))
        assertEquals(1, result.successes)
    }

    @Test fun authorizationWindowRecreationRetainsThePendingRequest() {
        val result = start("window")
        val intent = Intent(activity, OAuthAuthorizationActivity::class.java)
            .putExtra(OAuthAuthorizationActivity.SESSION_ID, "window")
        val first = Robolectric.buildActivity(OAuthAuthorizationActivity::class.java, intent)
            .create().start().resume()
        first.pause().stop().destroy()
        val restored = Robolectric.buildActivity(OAuthAuthorizationActivity::class.java, intent)
            .create().start().resume()
        assertNull(result.error)
        assertTrue(OAuthHandler.handleCallback(Uri.parse("$redirect?code=ok&state=window")))
        assertEquals(1, result.successes)
        assertTrue(restored.get().isFinishing)
        restored.pause().stop().destroy()
    }

    @Test fun closingAuthorizationWindowReleasesThePendingRequest() {
        val result = start("back-before-binding")
        val intent = Intent(activity, OAuthAuthorizationActivity::class.java)
            .putExtra(OAuthAuthorizationActivity.SESSION_ID, "back-before-binding")
        val window = Robolectric.buildActivity(OAuthAuthorizationActivity::class.java, intent)
            .create().start().resume()
        assertNull(result.error)
        window.get().onBackPressedDispatcher.onBackPressed()
        assertTrue(window.get().isFinishing)
        window.pause().stop().destroy()

        assertEquals("authorization_cancelled", result.error)
        assertEquals(0, result.successes)
        assertFalse(OAuthHandler.handleCallback(Uri.parse("$redirect?code=old&state=back-before-binding")))
        val next = start("after-back")
        assertTrue(OAuthHandler.handleCallback(Uri.parse("$redirect?code=ok&state=after-back")))
        assertEquals(1, next.successes)
    }

    @Test fun finishingOldAuthorizationWindowDoesNotCancelANewerRequest() {
        val old = start("old-window")
        val intent = Intent(activity, OAuthAuthorizationActivity::class.java)
            .putExtra(OAuthAuthorizationActivity.SESSION_ID, "old-window")
        val window = Robolectric.buildActivity(OAuthAuthorizationActivity::class.java, intent)
            .create().start().resume()
        OAuthHandler.cancelAuthorization("old-window")
        assertEquals("authorization_cancelled", old.error)
        assertTrue(window.get().isFinishing)

        val current = start("new-window")
        window.pause().stop().destroy()
        assertNull(current.error)
        assertTrue(OAuthHandler.handleCallback(Uri.parse("$redirect?code=ok&state=new-window")))
        assertEquals(1, current.successes)
    }

    @Test fun orphanedAuthorizationWindowAndCallbackAreRejected() {
        val intent = Intent(activity, OAuthAuthorizationActivity::class.java)
            .putExtra(OAuthAuthorizationActivity.SESSION_ID, "orphan")
        val orphan = Robolectric.buildActivity(OAuthAuthorizationActivity::class.java, intent).create()
        assertTrue(orphan.get().isFinishing)
        assertFalse(OAuthHandler.handleCallback(Uri.parse("$redirect?code=ok&state=orphan")))
        orphan.destroy()
    }

    private class Result : MethodChannel.Result {
        var successes = 0
        var error: String? = null
        override fun success(result: Any?) { successes++ }
        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) { error = errorCode }
        override fun notImplemented() = Unit
    }

    class TestBrowserService : CustomTabsService() {
        var acceptSession = true
        var denySession = false
        var customSession: CustomTabsSessionToken? = null
        var authSession: AuthTabSessionToken? = null
        override fun newSession(sessionToken: CustomTabsSessionToken): Boolean {
            if (denySession) throw SecurityException("Browser rejects session")
            customSession = sessionToken
            return acceptSession
        }
        override fun registerAuthTabSession(sessionToken: AuthTabSessionToken): Boolean {
            if (denySession) throw SecurityException("Browser rejects session")
            authSession = sessionToken
            return acceptSession
        }
        override fun warmup(flags: Long) = true
        override fun mayLaunchUrl(token: CustomTabsSessionToken, uri: Uri?, extras: Bundle?, other: List<Bundle>?) = false
        override fun extraCommand(name: String, args: Bundle?): Bundle? = null
        override fun updateVisuals(token: CustomTabsSessionToken, bundle: Bundle?) = false
        override fun requestPostMessageChannel(token: CustomTabsSessionToken, origin: Uri) = false
        override fun postMessage(token: CustomTabsSessionToken, message: String, extras: Bundle?) = 0
        override fun validateRelationship(token: CustomTabsSessionToken, relation: Int, origin: Uri, extras: Bundle?) = false
        override fun receiveFile(token: CustomTabsSessionToken, uri: Uri, purpose: Int, extras: Bundle?) = false
    }

    class TestApplication : Application() {
        var delayBrowserBinding = false
        val delayedConnections = mutableListOf<ServiceConnection>()
        override fun bindService(intent: Intent, connection: ServiceConnection, flags: Int): Boolean {
            if (delayBrowserBinding && intent.action == CustomTabsService.ACTION_CUSTOM_TABS_CONNECTION) {
                delayedConnections.add(connection)
                return true
            }
            return super.bindService(intent, connection, flags)
        }
        override fun unbindService(connection: ServiceConnection) {
            if (!delayedConnections.remove(connection)) super.unbindService(connection)
        }
    }
}
