package com.psyche.kelivo

import android.graphics.Rect
import android.os.Build
import android.view.ActionMode
import android.view.Menu
import android.view.MenuItem
import android.view.View
import android.window.OnBackInvokedCallback
import android.window.OnBackInvokedDispatcher
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import kotlin.math.ceil
import kotlin.math.floor
import kotlin.math.max

/** A floating system menu anchored to Flutter's selection, without taking input focus. */
internal class AndroidSelectionMenu(
    messenger: BinaryMessenger,
    private val viewProvider: () -> View?,
) {
    private data class Item(
        val title: String,
        val enabled: Boolean,
        val overflow: Boolean,
        val keepOpen: Boolean,
    )
    private class Session(
        val id: Long,
        var revision: Int,
        var rect: Rect,
        var items: List<Item>,
        var mode: ActionMode? = null,
    )

    private val channel = MethodChannel(messenger, "app.android_selection_menu")
    private var current: Session? = null
    private var disposed = false
    private var unregisterBack: (() -> Unit)? = null

    init {
        channel.setMethodCallHandler { call, result ->
            if (disposed) {
                result.success(false)
                return@setMethodCallHandler
            }
            when (call.method) {
                "show" -> result.success(show(call.arguments as? Map<*, *>))
                "hide" -> {
                    val id = (call.argument<Number>("session"))?.toLong()
                    if (id == current?.id) dismiss(notify = false)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun show(args: Map<*, *>?): Boolean {
        val id = (args?.get("session") as? Number)?.toLong() ?: return false
        val revision = (args["revision"] as? Number)?.toInt() ?: return false
        val coordinates = (args["rect"] as? List<*>)?.map {
            (it as? Number)?.toDouble()?.takeIf(Double::isFinite) ?: return false
        } ?: return false
        if (coordinates.size != 4) return false
        val rect = Rect(
            floor(coordinates[0]).toInt(), floor(coordinates[1]).toInt(),
            ceil(coordinates[2]).toInt(), ceil(coordinates[3]).toInt(),
        )
        if (rect.isEmpty) return false
        val items = (args["items"] as? List<*>)?.map {
            val item = it as? Map<*, *> ?: return false
            Item(
                item["title"] as? String ?: return false,
                item["enabled"] == true,
                item["overflow"] == true,
                item["keepOpen"] == true,
            )
        } ?: return false
        if (items.isEmpty()) return false
        val view = viewProvider()?.takeIf { it.isAttachedToWindow } ?: return false
        current?.takeIf { it.id == id }?.let { session ->
            if (revision < session.revision) return false
            val changed = revision != session.revision || items != session.items
            session.revision = revision
            session.rect = rect
            session.items = items
            if (changed) session.mode?.invalidate()
            session.mode?.invalidateContentRect()
            return session.mode != null
        }
        dismiss()
        val session = Session(id, revision, rect, items)
        current = session
        session.mode = view.startActionMode(object : ActionMode.Callback2() {
            override fun onCreateActionMode(mode: ActionMode, menu: Menu): Boolean {
                populate(menu, session)
                return true
            }

            override fun onPrepareActionMode(mode: ActionMode, menu: Menu): Boolean {
                populate(menu, session)
                return true
            }

            override fun onGetContentRect(mode: ActionMode, source: View, outRect: Rect) {
                val visible = Rect()
                source.getLocalVisibleRect(visible)
                val window = Rect()
                source.getWindowVisibleDisplayFrame(window)
                val origin = IntArray(2)
                source.getLocationOnScreen(origin)
                window.offset(-origin[0], -origin[1])
                visible.intersect(window)
                val left = session.rect.left.coerceIn(visible.left, max(visible.left, visible.right - 1))
                val top = session.rect.top.coerceIn(visible.top, max(visible.top, visible.bottom - 1))
                outRect.set(
                    left, top,
                    session.rect.right.coerceIn(left + 1, max(left + 1, visible.right)),
                    session.rect.bottom.coerceIn(top + 1, max(top + 1, visible.bottom)),
                )
            }

            override fun onActionItemClicked(mode: ActionMode, item: MenuItem): Boolean {
                val index = item.itemId - 1
                if (current !== session || item.groupId != session.revision ||
                    session.items.getOrNull(index)?.enabled != true) return false
                val event = mapOf("session" to session.id, "revision" to session.revision, "index" to index)
                // Keep this mode only for actions that update it in place.
                // Otherwise retire it before Dart can open another toolbar.
                if (!session.items[index].keepOpen) dismiss(notify = false)
                channel.invokeMethod("action", event)
                return true
            }

            override fun onDestroyActionMode(mode: ActionMode) {
                if (current !== session) return
                current = null
                clearBackHandler()
                channel.invokeMethod("dismissed", mapOf("session" to session.id))
            }
        }, ActionMode.TYPE_FLOATING)
        if (session.mode == null && current === session) current = null
        if (session.mode != null && Build.VERSION.SDK_INT >= 33) {
            val dispatcher = view.findOnBackInvokedDispatcher()
            val callback = OnBackInvokedCallback { dismiss() }
            dispatcher?.registerOnBackInvokedCallback(OnBackInvokedDispatcher.PRIORITY_OVERLAY, callback)
            unregisterBack = { dispatcher?.unregisterOnBackInvokedCallback(callback) }
        }
        return session.mode != null
    }

    private fun populate(menu: Menu, session: Session) {
        menu.clear()
        session.items.forEachIndexed { index, item ->
            menu.add(session.revision, index + 1, index, item.title).apply {
                isEnabled = item.enabled
                setShowAsAction(if (item.overflow) MenuItem.SHOW_AS_ACTION_NEVER else MenuItem.SHOW_AS_ACTION_IF_ROOM)
            }
        }
    }

    fun dismiss(notify: Boolean = true) {
        val session = current ?: return
        current = null
        clearBackHandler()
        session.mode?.finish()
        if (notify) channel.invokeMethod("dismissed", mapOf("session" to session.id))
    }

    fun handleBack(): Boolean {
        if (current == null) return false
        dismiss()
        return true
    }

    private fun clearBackHandler() {
        unregisterBack?.invoke()
        unregisterBack = null
    }

    fun dispose() {
        if (disposed) return
        disposed = true
        dismiss()
        channel.setMethodCallHandler(null)
    }
}
