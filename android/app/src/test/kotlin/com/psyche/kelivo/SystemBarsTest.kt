package com.psyche.kelivo

import android.app.Activity
import android.graphics.Color
import android.os.Build
import android.view.View
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28, 29, 35], manifest = Config.NONE)
@Suppress("DEPRECATION")
class SystemBarsTest {
    @Test fun aNewWindowAndAResumedWindowBothDrawBehindTransparentBars() {
        val host = Robolectric.buildActivity(Activity::class.java).setup()
        val window = host.get().window
        repeat(2) {
            window.navigationBarColor = Color.WHITE
            window.navigationBarDividerColor = Color.GRAY
            window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR
            if (Build.VERSION.SDK_INT >= 29) window.isNavigationBarContrastEnforced = true

            applyEdgeToEdgeSystemBars(window)

            assertEquals(Color.TRANSPARENT, window.navigationBarColor)
            assertEquals(Color.TRANSPARENT, window.navigationBarDividerColor)
            if (Build.VERSION.SDK_INT >= 29) assertFalse(window.isNavigationBarContrastEnforced)
            if (Build.VERSION.SDK_INT < 35) {
                val flags = window.decorView.systemUiVisibility
                assertTrue(flags and View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION != 0)
                assertTrue(flags and View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR != 0)
            }
            host.pause().stop().start().resume()
        }
        host.pause().stop().destroy()
    }
}
