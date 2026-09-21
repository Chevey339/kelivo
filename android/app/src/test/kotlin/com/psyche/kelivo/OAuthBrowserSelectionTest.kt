package com.psyche.kelivo

import android.content.ComponentName
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ActivityInfo
import android.content.pm.ResolveInfo
import android.net.Uri
import androidx.browser.customtabs.CustomTabsService
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28, 35], manifest = Config.NONE)
class OAuthBrowserSelectionTest {
    private val context get() = RuntimeEnvironment.getApplication()

    private fun installCustomTabsBrowser(packageName: String) {
        val manager = shadowOf(context.packageManager)
        val component = ComponentName(packageName, "$packageName.CustomTabsService")
        manager.addServiceIfNotPresent(component)
        manager.addIntentFilterForService(
            component,
            IntentFilter(CustomTabsService.ACTION_CUSTOM_TABS_CONNECTION),
        )
    }

    @Suppress("DEPRECATION")
    private fun setDefaultBrowser(packageName: String) {
        shadowOf(context.packageManager).addResolveInfoForIntent(
            Intent(Intent.ACTION_VIEW, Uri.parse("http://")),
            ResolveInfo().apply {
                activityInfo = ActivityInfo().apply {
                    this.packageName = packageName
                    name = "$packageName.BrowserActivity"
                }
            },
        )
    }

    @Test fun findsInstalledBrowserWhenNoDefaultIsSet() {
        installCustomTabsBrowser("test.available.browser")

        assertEquals("test.available.browser", OAuthHandler.findBrowserPackage(context))
    }

    @Test fun findsInstalledBrowserWhenDefaultDoesNotSupportCustomTabs() {
        installCustomTabsBrowser("test.available.browser")
        setDefaultBrowser("test.unsupported.browser")

        assertEquals("test.available.browser", OAuthHandler.findBrowserPackage(context))
    }

    @Test fun prefersSupportedDefaultOverOtherInstalledBrowsers() {
        installCustomTabsBrowser("test.alternative.browser")
        installCustomTabsBrowser("test.preferred.browser")
        setDefaultBrowser("test.preferred.browser")

        assertEquals("test.preferred.browser", OAuthHandler.findBrowserPackage(context))
    }

    @Test fun returnsUnavailableWhenNoCustomTabsBrowserIsInstalled() {
        setDefaultBrowser("test.unsupported.browser")

        assertNull(OAuthHandler.findBrowserPackage(context))
    }
}
