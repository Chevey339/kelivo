package com.psyche.kelivo

import android.app.Activity
import android.content.Context
import android.graphics.SurfaceTexture
import android.hardware.display.DisplayManager
import android.os.Build
import android.os.Looper
import android.view.Display
import android.view.Surface
import android.view.SurfaceHolder
import android.view.SurfaceView
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.android.controller.ActivityController
import org.robolectric.annotation.Config
import org.robolectric.annotation.Implementation
import org.robolectric.annotation.Implements
import org.robolectric.shadow.api.Shadow
import org.robolectric.shadows.ShadowDisplay
import org.robolectric.shadows.ShadowDisplayManager
import org.robolectric.shadows.ShadowSurface
import org.robolectric.shadows.ShadowSurfaceView.FakeSurfaceHolder
import org.robolectric.util.ReflectionHelpers
import org.robolectric.util.ReflectionHelpers.ClassParameter.from

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [29, 30, 31, 35, 36], manifest = Config.NONE,
    shadows = [HighRefreshRateControllerTest.RecordingSurface::class, HighRefreshRateControllerTest.SuggestedDisplay::class])
class HighRefreshRateControllerTest {
    data class Vote(val rate: Float, val compatibility: Int, val strategy: Int, val argumentCount: Int)

    @Implements(Surface::class)
    class RecordingSurface : ShadowSurface() {
        val votes = mutableListOf<Vote>()
        var valid = true
        var failNextRequest = false
        @Implementation override fun isValid() = valid
        @Implementation(minSdk = 30)
        fun setFrameRate(rate: Float, compatibility: Int) = record(rate, compatibility, 0, 2)
        @Implementation(minSdk = 31)
        fun setFrameRate(rate: Float, compatibility: Int, strategy: Int) = record(rate, compatibility, strategy, 3)
        private fun record(rate: Float, compatibility: Int, strategy: Int, argumentCount: Int) {
            if (failNextRequest) {
                failNextRequest = false
                throw IllegalStateException("Surface replaced during request")
            }
            votes += Vote(rate, compatibility, strategy, argumentCount)
        }
    }

    @Implements(Display::class)
    class SuggestedDisplay : ShadowDisplay() {
        companion object { var highRate = 90f }
        @Implementation(minSdk = 36)
        fun getSuggestedFrameRate(category: Int): Float {
            assertEquals(Display.FRAME_RATE_CATEGORY_HIGH, category)
            return highRate
        }
    }

    private class TestSurfaceView(context: Context, private val targetDisplay: Display) : SurfaceView(context) {
        val texture = SurfaceTexture(0)
        val testSurface = Surface(texture)
        val testHolder = object : FakeSurfaceHolder() {
            override fun getSurface() = testSurface
        }
        override fun getDisplay() = targetDisplay
        override fun getHolder(): SurfaceHolder = testHolder
    }

    private lateinit var host: ActivityController<Activity>
    private lateinit var view: TestSurfaceView
    private lateinit var controller: HighRefreshRateController
    private val surface get() = Shadow.extract<RecordingSurface>(view.testSurface)
    private val expectedRate get() = if (Build.VERSION.SDK_INT >= 36) 90f else 120f

    @Before fun setup() {
        SuggestedDisplay.highRate = 90f
        host = Robolectric.buildActivity(Activity::class.java).setup()
        val activity = host.get()
        val display = activity.getSystemService(DisplayManager::class.java).getDisplay(Display.DEFAULT_DISPLAY)
        view = TestSurfaceView(activity, display)
        setRates(120f)
        controller = HighRefreshRateController(activity.window)
        controller.attach(view)
    }

    @After fun teardown() {
        controller.dispose()
        view.testSurface.release()
        view.texture.release()
        host.pause().stop().destroy()
    }

    private fun mode(id: Int, width: Int, height: Int, rate: Float): Display.Mode =
        ReflectionHelpers.callConstructor(Display.Mode::class.java,
            from(Int::class.javaPrimitiveType, id), from(Int::class.javaPrimitiveType, width),
            from(Int::class.javaPrimitiveType, height), from(Float::class.javaPrimitiveType, rate))

    private fun setRates(maximum: Float) {
        val active = view.display.mode
        ShadowDisplayManager.setSupportedModes(view.display.displayId,
            mode(active.modeId, active.physicalWidth, active.physicalHeight, 60f),
            mode(100, active.physicalWidth, active.physicalHeight, maximum),
            mode(101, active.physicalWidth * 2, active.physicalHeight * 2, 165f))
        shadowOf(Looper.getMainLooper()).idle()
    }

    private fun assertRequested(rate: Float) {
        val attributes = host.get().window.attributes
        assertEquals(0f, attributes.preferredRefreshRate, 0f)
        if (Build.VERSION.SDK_INT < 30) {
            val requestedMode = view.display.supportedModes.first { it.modeId == attributes.preferredDisplayModeId }
            assertEquals(view.display.mode.physicalWidth, requestedMode.physicalWidth)
            assertEquals(view.display.mode.physicalHeight, requestedMode.physicalHeight)
            assertEquals(rate, requestedMode.refreshRate, 0f)
            assertTrue(surface.votes.isEmpty())
        } else {
            assertEquals(0, attributes.preferredDisplayModeId)
            val vote = surface.votes.last()
            assertEquals(rate, vote.rate, 0f)
            assertEquals(if (Build.VERSION.SDK_INT >= 36) 2 else 0, vote.compatibility)
            assertEquals(0, vote.strategy)
            assertEquals(if (Build.VERSION.SDK_INT >= 31) 3 else 2, vote.argumentCount)
        }
    }

    @Test fun requestsAnAppropriateRateAtTheCurrentResolution() {
        host.get().window.attributes = host.get().window.attributes.also {
            it.preferredDisplayModeId = 101
            it.preferredRefreshRate = 165f
        }
        controller.resume()
        assertRequested(expectedRate)
    }

    @Test @Config(sdk = [24])
    fun minimumSupportedAndroidUsesAWindowModeWithoutCallingSurfaceApis() {
        controller.resume()
        assertRequested(120f)
    }

    private fun setLegacyModesWithDifferentDefaultResolution(defaultHighRate: Float): Any {
        val global = ReflectionHelpers.getField<Any>(view.display, "mGlobal")
        val info = ReflectionHelpers.callInstanceMethod<Any>(global, "getDisplayInfo",
            from(Int::class.javaPrimitiveType, view.display.displayId))
        ReflectionHelpers.setField(info, "modeId", 201)
        ReflectionHelpers.setField(info, "defaultModeId", 203)
        ReflectionHelpers.setField(info, "supportedModes", arrayOf(
            mode(201, 1080, 2400, 60f),
            mode(202, 1080, 2400, 120f),
            mode(203, 1440, 3200, 60f),
            mode(204, 1440, 3200, defaultHighRate)))
        ReflectionHelpers.callInstanceMethod<Unit>(Shadow.extract<Any>(global), "changeDisplay",
            from(Int::class.javaPrimitiveType, view.display.displayId), from(info.javaClass, info))
        shadowOf(Looper.getMainLooper()).idle()
        assertEquals(201, view.display.mode.modeId)
        return info
    }

    @Test @Config(sdk = [29])
    fun legacyRequestPreservesResolutionWhenDefaultResolutionSupportsTheSameRate() {
        val info = setLegacyModesWithDifferentDefaultResolution(120f)
        // Android resolves a rate-only request to the default resolution's 120 Hz mode.
        assertEquals(204, ReflectionHelpers.callInstanceMethod<Int>(info, "findDefaultModeByRefreshRate",
            from(Float::class.javaPrimitiveType, 120f)))

        controller.resume()

        assertEquals(202, host.get().window.attributes.preferredDisplayModeId)
        assertEquals(0f, host.get().window.attributes.preferredRefreshRate, 0f)
        assertTrue(surface.votes.isEmpty())
    }

    @Test @Config(sdk = [29])
    fun legacyRequestWorksWhenDefaultResolutionDoesNotSupportTheTargetRate() {
        val info = setLegacyModesWithDifferentDefaultResolution(90f)
        // Android cannot resolve a rate-only 120 Hz request at the default resolution.
        assertEquals(0, ReflectionHelpers.callInstanceMethod<Int>(info, "findDefaultModeByRefreshRate",
            from(Float::class.javaPrimitiveType, 120f)))

        controller.resume()

        assertEquals(202, host.get().window.attributes.preferredDisplayModeId)
        assertEquals(0f, host.get().window.attributes.preferredRefreshRate, 0f)
        assertTrue(surface.votes.isEmpty())
    }

    @Test fun displayChangesUpdateTheRequestWithoutRepeatingUnchangedVotes() {
        controller.resume()
        repeat(5) { view.testHolder.emitSurfaceChanged(0, 400, 600) }
        if (Build.VERSION.SDK_INT >= 30) assertEquals(1, surface.votes.size)
        SuggestedDisplay.highRate = 60f
        setRates(60f)
        assertRequested(60f)
        if (Build.VERSION.SDK_INT >= 30) assertEquals(2, surface.votes.size)
    }

    @Test fun stoppingClearsTheVoteAndResumeRestoresItEvenWithTheSameSurface() {
        controller.resume()
        controller.stop()
        assertEquals(0, host.get().window.attributes.preferredDisplayModeId)
        assertEquals(0f, host.get().window.attributes.preferredRefreshRate, 0f)
        if (Build.VERSION.SDK_INT >= 30) assertEquals(0f, surface.votes.last().rate, 0f)
        val count = surface.votes.size
        view.testHolder.emitSurfaceChanged(0, 400, 600)
        controller.request(force = true)
        assertEquals(count, surface.votes.size)
        assertEquals(0, host.get().window.attributes.preferredDisplayModeId)
        controller.resume()
        assertRequested(expectedRate)
    }

    @Test @Config(sdk = [30, 31, 35, 36])
    fun invalidAndRecreatedSurfacesAreHandledWithoutAWindowModeFallback() {
        surface.valid = false
        controller.resume()
        assertTrue(surface.votes.isEmpty())
        assertEquals(0, host.get().window.attributes.preferredDisplayModeId)
        assertEquals(0f, host.get().window.attributes.preferredRefreshRate, 0f)
        surface.valid = true
        view.testHolder.callbacks.toList().forEach { it.surfaceCreated(view.testHolder) }
        assertRequested(expectedRate)
        view.testHolder.callbacks.toList().forEach { it.surfaceDestroyed(view.testHolder) }
        view.testHolder.callbacks.toList().forEach { it.surfaceCreated(view.testHolder) }
        view.testHolder.emitSurfaceChanged(0, 400, 600)
        assertEquals(2, surface.votes.size)
    }

    @Test @Config(sdk = [30, 31, 35, 36])
    fun windowFocusCanReassertAnOtherwiseIdenticalVote() {
        controller.resume()
        controller.request(force = true)
        assertEquals(2, surface.votes.size)
        assertRequested(expectedRate)
    }

    @Test @Config(sdk = [30, 31, 35, 36])
    fun failedRequestsCanBeRetriedByTheNextSurfaceCallback() {
        surface.failNextRequest = true
        controller.resume()
        assertTrue(surface.votes.isEmpty())
        view.testHolder.emitSurfaceChanged(0, 400, 600)
        assertRequested(expectedRate)
    }

    @Test @Config(sdk = [36])
    fun invalidSystemSuggestionUsesTheHighestRateAtTheCurrentResolution() {
        SuggestedDisplay.highRate = Float.NaN
        controller.resume()
        assertRequested(120f)
    }

    @Test fun aReplacementActivityRequestsItsOwnRateWithoutDartRestarting() {
        controller.resume()
        controller.dispose()
        assertTrue(view.testHolder.callbacks.isEmpty())
        val oldVoteCount = surface.votes.size
        val nextHost = Robolectric.buildActivity(Activity::class.java).setup()
        val nextView = TestSurfaceView(nextHost.get(), view.display)
        val next = HighRefreshRateController(nextHost.get().window)
        try {
            next.attach(nextView)
            next.resume()
            if (Build.VERSION.SDK_INT >= 30) {
                assertEquals(expectedRate, Shadow.extract<RecordingSurface>(nextView.testSurface).votes.last().rate, 0f)
            } else {
                assertEquals(100, nextHost.get().window.attributes.preferredDisplayModeId)
                assertEquals(0f, nextHost.get().window.attributes.preferredRefreshRate, 0f)
            }
            view.testHolder.emitSurfaceChanged(0, 400, 600)
            assertEquals(oldVoteCount, surface.votes.size)
        } finally {
            next.dispose()
            nextView.testSurface.release()
            nextView.texture.release()
            nextHost.pause().stop().destroy()
        }
    }
}
