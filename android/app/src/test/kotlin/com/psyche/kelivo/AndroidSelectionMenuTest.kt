package com.psyche.kelivo

import android.app.Activity
import android.content.Context
import android.graphics.Rect
import android.view.ActionMode
import android.view.Menu
import android.view.MenuInflater
import android.view.View
import android.widget.PopupMenu
import android.window.OnBackInvokedCallback
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.StandardMethodCodec
import java.nio.ByteBuffer
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.android.controller.ActivityController
import org.robolectric.annotation.Config
import org.robolectric.util.ReflectionHelpers

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28, 36], manifest = Config.NONE)
class AndroidSelectionMenuTest {
    private lateinit var activity: ActivityController<Activity>
    private lateinit var view: MenuView
    private lateinit var messenger: Messenger
    private lateinit var handler: AndroidSelectionMenu

    @Before fun setUp() {
        activity = Robolectric.buildActivity(Activity::class.java).setup().visible()
        view = MenuView(activity.get())
        activity.get().setContentView(view)
        view.layout(0, 0, 1080, 1800)
        messenger = Messenger()
        handler = AndroidSelectionMenu(messenger) { view }
    }

    @After fun tearDown() {
        handler.dispose()
        activity.pause().stop().destroy()
    }

    private fun show(session: Int = 1, revision: Int = 1, enabled: Boolean = true, selectAll: Boolean = false): Any? =
        messenger.call("show", mapOf(
            "session" to session, "revision" to revision,
            "rect" to listOf(300.0, 400.0, 600.0, 480.0),
            "items" to listOf(
                mapOf("title" to if (selectAll) "Select all" else "Copy",
                    "enabled" to enabled, "overflow" to false, "keepOpen" to selectAll),
                mapOf("title" to "Quote", "enabled" to true, "overflow" to false),
                mapOf("title" to "Translate", "enabled" to true, "overflow" to false),
                mapOf("title" to "Markdown", "enabled" to true, "overflow" to false),
                mapOf("title" to "Rich text", "enabled" to true, "overflow" to false),
            ) + (0..23).map {
                mapOf("title" to "External $it", "enabled" to true, "overflow" to true)
            },
        ))

    @Test fun selectAllKeepsTheModeForUpdatedActionsAndFollowingCopy() {
        assertEquals(true, show(selectAll = true))
        val mode = view.modes.single()
        val selectAll = mode.menu.getItem(0)
        assertTrue(mode.callback.onActionItemClicked(mode, selectAll))
        assertFalse(mode.finished)
        assertEquals(listOf("action"), messenger.events.map { it.method })

        assertEquals(true, show(revision = 2))
        assertSame(mode, view.modes.single())
        assertEquals("Copy", mode.menu.getItem(0).title)
        assertFalse(mode.callback.onActionItemClicked(mode, selectAll))
        assertTrue(mode.callback.onActionItemClicked(mode, mode.menu.getItem(0)))
        assertTrue(mode.finished)
        assertEquals(listOf(1, 2), messenger.events.map { it.argument<Int>("revision") })
    }

    @Test fun selectAllStillAllowsBackAndOwnerDismissal() {
        show(selectAll = true)
        val first = view.modes.single()
        first.callback.onActionItemClicked(first, first.menu.getItem(0))
        assertTrue(handler.handleBack())
        assertTrue(first.finished)
        assertEquals(listOf("action", "dismissed"), messenger.events.map { it.method })

        show(session = 2, selectAll = true)
        val second = view.modes.last()
        second.callback.onActionItemClicked(second, second.menu.getItem(0))
        messenger.call("hide", mapOf("session" to 2))
        assertTrue(second.finished)
        assertFalse(handler.handleBack())
        assertEquals(listOf("action", "dismissed", "action"), messenger.events.map { it.method })
    }

    @Test fun floatingMenuKeepsPrimaryOrderAndForcesExternalActionsIntoOverflow() {
        assertEquals(true, show())
        val mode = view.modes.single()
        assertEquals(ActionMode.TYPE_FLOATING, view.requestedType)
        assertEquals(29, mode.menu.size())
        assertEquals(listOf("Copy", "Quote", "Translate", "Markdown", "Rich text"),
            (0..4).map { mode.menu.getItem(it).title.toString() })
        for (index in 0 until mode.menu.size()) {
            val item = mode.menu.getItem(index)
            assertEquals(index >= 5, ReflectionHelpers.callInstanceMethod<Boolean>(item, "requiresOverflow"))
        }
        assertFalse(view.hasFocus())
        val bounds = Rect()
        (mode.callback as ActionMode.Callback2).onGetContentRect(mode, view, bounds)
        assertFalse(bounds.isEmpty)
        assertTrue(bounds.left >= 0 && bounds.top >= 0)
        assertTrue(bounds.right <= view.width && bounds.bottom <= view.height)
        assertTrue(mode.callback.onActionItemClicked(mode, mode.menu.getItem(28)))
        assertTrue(mode.finished)
        val event = messenger.events.single()
        assertEquals("action", event.method)
        assertEquals(28, event.argument<Int>("index"))
        assertFalse(mode.callback.onActionItemClicked(mode, mode.menu.getItem(28)))
        assertEquals(1, messenger.events.size)
    }

    @Test fun updatesReuseTheModeButRejectOldRevisionAndDisabledItems() {
        show()
        val mode = view.modes.single()
        val old = mode.menu.getItem(0)
        assertEquals(true, show(revision = 2, enabled = false))
        assertEquals(1, view.modes.size)
        assertFalse(mode.callback.onActionItemClicked(mode, old))
        assertFalse(mode.callback.onActionItemClicked(mode, mode.menu.getItem(0)))
        assertFalse(mode.menu.getItem(0).isEnabled)
        assertTrue(messenger.events.isEmpty())
        assertEquals(false, show(revision = 1))
        assertTrue(mode.callback.onActionItemClicked(mode, mode.menu.getItem(1)))
        assertEquals(2, messenger.events.single().argument<Int>("revision"))
    }

    @Test fun oldHideAndDestructionCannotCloseTheNewSession() {
        show()
        val old = view.modes.single()
        show(session = 2)
        val next = view.modes.last()
        assertTrue(old.finished)
        assertEquals("dismissed", messenger.events.single().method)
        messenger.call("hide", mapOf("session" to 1))
        old.callback.onDestroyActionMode(old)
        assertFalse(next.finished)
        assertEquals(1, messenger.events.size)
        assertTrue(next.callback.onActionItemClicked(next, next.menu.getItem(1)))
        assertEquals(2L, messenger.events.last().argument<Long>("session"))
    }

    @Test fun disposalRetiresTheModeAndAnyAlreadyQueuedChannelCall() {
        show()
        val queued = messenger.handler!!
        handler.dispose()
        assertTrue(view.modes.single().finished)
        assertNull(messenger.handler)
        assertEquals("dismissed", messenger.events.single().method)
        assertEquals(false, messenger.call("show", emptyMap<String, Any>(), queued))
        assertEquals(1, view.modes.size)
    }

    @Test fun nativeDismissalNotifiesDartExactlyOnce() {
        show()
        val mode = view.modes.single()
        mode.finish()
        handler.dismiss()
        assertEquals(listOf("dismissed"), messenger.events.map { it.method })
    }

    @Test fun legacyBackClosesTheMenuBeforeActivityNavigation() {
        assertFalse(handler.handleBack())
        show()
        assertTrue(handler.handleBack())
        assertTrue(view.modes.single().finished)
        assertFalse(handler.handleBack())
        assertEquals(listOf("dismissed"), messenger.events.map { it.method })
    }

    @Test @Config(sdk = [36])
    fun predictiveBackClosesTheMenuAndUnregistersItsCallback() {
        // Config.NONE has no parsed application flag; exercise the opted-in
        // predictive-back path as well as the legacy path above.
        ReflectionHelpers.callInstanceMethod<Unit>(activity.get().applicationInfo,
            "setEnableOnBackInvokedCallback",
            ReflectionHelpers.ClassParameter.from(Boolean::class.javaPrimitiveType, true))
        val dispatcher = view.findOnBackInvokedDispatcher()!!
        val previous = ReflectionHelpers.callInstanceMethod<OnBackInvokedCallback?>(dispatcher, "getTopCallback")
        show()
        val callback = ReflectionHelpers.callInstanceMethod<OnBackInvokedCallback>(dispatcher, "getTopCallback")
        assertNotNull(callback)
        assertNotSame(previous, callback)
        callback.onBackInvoked()
        assertTrue(view.modes.single().finished)
        assertSame(previous, ReflectionHelpers.callInstanceMethod<OnBackInvokedCallback?>(dispatcher, "getTopCallback"))
        assertEquals(listOf("dismissed"), messenger.events.map { it.method })
    }

    private class MenuView(context: Context) : View(context) {
        val modes = mutableListOf<RecordingMode>()
        var requestedType = -1
        override fun startActionMode(callback: ActionMode.Callback, type: Int): ActionMode {
            requestedType = type
            val mode = RecordingMode(context, this, callback)
            modes += mode
            callback.onCreateActionMode(mode, mode.menu)
            return mode
        }
    }

    private class RecordingMode(context: Context, view: View, val callback: ActionMode.Callback) : ActionMode() {
        private val items = PopupMenu(context, view).menu
        private val inflater = MenuInflater(context)
        var finished = false
        override fun finish() { finished = true; callback.onDestroyActionMode(this) }
        override fun invalidate() { callback.onPrepareActionMode(this, items) }
        override fun getMenu(): Menu = items
        override fun getMenuInflater() = inflater
        override fun setTitle(title: CharSequence?) {}
        override fun setTitle(resId: Int) {}
        override fun setSubtitle(subtitle: CharSequence?) {}
        override fun setSubtitle(resId: Int) {}
        override fun setCustomView(view: View?) {}
        override fun getTitle(): CharSequence = ""
        override fun getSubtitle(): CharSequence = ""
        override fun getCustomView(): View? = null
    }

    private class Messenger : BinaryMessenger {
        var handler: BinaryMessenger.BinaryMessageHandler? = null
        val events = mutableListOf<MethodCall>()
        override fun send(channel: String, message: ByteBuffer?) {
            events += StandardMethodCodec.INSTANCE.decodeMethodCall(message!!.apply { flip() })
        }
        override fun send(channel: String, message: ByteBuffer?, callback: BinaryMessenger.BinaryReply?) {
            send(channel, message)
            callback?.reply(null)
        }
        override fun setMessageHandler(channel: String, handler: BinaryMessenger.BinaryMessageHandler?) {
            this.handler = handler
        }
        fun call(method: String, args: Any?, target: BinaryMessenger.BinaryMessageHandler = handler!!): Any? {
            var result: Any? = null
            val bytes = StandardMethodCodec.INSTANCE.encodeMethodCall(MethodCall(method, args)).apply { flip() }
            target.onMessage(bytes) { result = StandardMethodCodec.INSTANCE.decodeEnvelope(it!!.apply { flip() }) }
            return result
        }
    }
}
