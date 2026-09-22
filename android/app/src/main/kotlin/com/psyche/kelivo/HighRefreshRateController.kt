package com.psyche.kelivo

import android.hardware.display.DisplayManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Display
import android.view.Surface
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.Window

/**
 * Window-owned requests also work when a headless Flutter engine gains a new Activity.
 * On API 30+, Surface rate votes leave mode selection to Android for adaptive refresh.
 */
internal class HighRefreshRateController(private val window: Window) : SurfaceHolder.Callback {
    private val displayManager = window.context.getSystemService(DisplayManager::class.java)
    private var view: SurfaceView? = null
    private var started = false
    private var requestedSurface: Surface? = null
    private var requestedRate = 0f
    private val displayListener = object : DisplayManager.DisplayListener {
        override fun onDisplayAdded(displayId: Int) = Unit
        override fun onDisplayRemoved(displayId: Int) = Unit
        override fun onDisplayChanged(displayId: Int) {
            if (view?.display?.displayId == displayId) request()
        }
    }

    fun attach(surfaceView: SurfaceView) {
        if (view === surfaceView) return
        view?.holder?.removeCallback(this)
        clearRequest()
        view = surfaceView
        surfaceView.holder.addCallback(this)
        request()
    }

    fun resume() {
        if (!started) {
            started = true
            displayManager.registerDisplayListener(displayListener, Handler(Looper.getMainLooper()))
        }
        // Some Android variants discard the preference while the app is in the background.
        request(force = true)
    }

    fun stop() {
        if (started) displayManager.unregisterDisplayListener(displayListener)
        started = false
        clearRequest()
    }

    fun dispose() {
        stop()
        view?.holder?.removeCallback(this)
        view = null
    }

    override fun surfaceCreated(holder: SurfaceHolder) = request(force = true)

    override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) = request()

    override fun surfaceDestroyed(holder: SurfaceHolder) {
        // Android removes the vote with the surface; the same holder may later own a new surface.
        requestedSurface = null
    }

    fun request(force: Boolean = false) {
        if (!started) return
        try {
            val display = view?.display ?: return
            val activeMode = display.mode
            val highestMode = display.supportedModes.asSequence()
                .filter { it.physicalWidth == activeMode.physicalWidth && it.physicalHeight == activeMode.physicalHeight }
                .filter { it.refreshRate.isFinite() && it.refreshRate > 0f }
                .maxByOrNull { it.refreshRate } ?: return
            val rate = if (Build.VERSION.SDK_INT >= 36) {
                display.getSuggestedFrameRate(Display.FRAME_RATE_CATEGORY_HIGH)
                    .takeIf { it.isFinite() && it > 0f } ?: highestMode.refreshRate
            } else highestMode.refreshRate

            if (Build.VERSION.SDK_INT >= 30) {
                val surface = view?.holder?.surface?.takeIf { it.isValid } ?: return
                setWindowMode(0)
                if (!force && requestedSurface === surface && requestedRate == rate) return
                val compatibility = if (Build.VERSION.SDK_INT >= 36) {
                    Surface.FRAME_RATE_COMPATIBILITY_AT_LEAST
                } else Surface.FRAME_RATE_COMPATIBILITY_DEFAULT
                if (Build.VERSION.SDK_INT >= 31) {
                    surface.setFrameRate(rate, compatibility, Surface.CHANGE_FRAME_RATE_ONLY_IF_SEAMLESS)
                } else {
                    surface.setFrameRate(rate, compatibility)
                }
                requestedSurface = surface
                requestedRate = rate
            } else {
                // API 24–29 resolves rate-only requests at the default resolution.
                // Keep the selected mode ID to preserve the current resolution.
                setWindowMode(highestMode.modeId)
            }
        } catch (error: RuntimeException) {
            Log.w("HighRefreshRate", "Unable to request a high refresh rate", error)
        }
    }

    private fun setWindowMode(modeId: Int) {
        val attributes = window.attributes
        if (attributes.preferredDisplayModeId == modeId && attributes.preferredRefreshRate == 0f) return
        attributes.preferredDisplayModeId = modeId
        attributes.preferredRefreshRate = 0f
        window.attributes = attributes
    }

    private fun clearRequest() {
        try {
            if (Build.VERSION.SDK_INT >= 30) {
                requestedSurface?.takeIf { it.isValid }
                    ?.setFrameRate(0f, Surface.FRAME_RATE_COMPATIBILITY_DEFAULT)
            }
            setWindowMode(0)
        } catch (error: RuntimeException) {
            Log.w("HighRefreshRate", "Unable to clear the refresh rate request", error)
        } finally {
            requestedSurface = null
            requestedRate = 0f
        }
    }
}
