package com.psyche.kelivo

import android.graphics.Color
import android.os.Build
import android.view.Window
import androidx.core.view.WindowCompat

@Suppress("DEPRECATION")
internal fun applyEdgeToEdgeSystemBars(window: Window) {
    WindowCompat.setDecorFitsSystemWindows(window, false)
    window.statusBarColor = Color.TRANSPARENT
    window.navigationBarColor = Color.TRANSPARENT
    if (Build.VERSION.SDK_INT >= 28) window.navigationBarDividerColor = Color.TRANSPARENT
    if (Build.VERSION.SDK_INT >= 29) {
        window.isStatusBarContrastEnforced = false
        window.isNavigationBarContrastEnforced = false
    }
}
