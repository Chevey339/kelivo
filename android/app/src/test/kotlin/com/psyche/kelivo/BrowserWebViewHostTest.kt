package com.psyche.kelivo

import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.os.Looper
import android.view.View
import com.pichillilorenzo.flutter_inappwebview_android.webview.WebViewScreenshot
import org.robolectric.Shadows.shadowOf
import com.pichillilorenzo.flutter_inappwebview_android.webview.WebViewChannelDelegate
import com.pichillilorenzo.flutter_inappwebview_android.webview.in_app_webview.InAppWebView
import com.pichillilorenzo.flutter_inappwebview_android.webview.in_app_webview.InputAwareWebView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
import java.nio.ByteBuffer
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30], manifest = Config.NONE)
class BrowserWebViewHostTest {
    private class Messenger : BinaryMessenger {
        val calls = mutableListOf<MethodCall>()
        override fun setMessageHandler(channel: String, handler: BinaryMessenger.BinaryMessageHandler?) = Unit
        override fun send(channel: String, message: ByteBuffer?) = send(channel, message, null)
        override fun send(channel: String, message: ByteBuffer?, callback: BinaryMessenger.BinaryReply?) {
            message?.flip()
            if (message != null) calls += StandardMethodCodec.INSTANCE.decodeMethodCall(message)
        }
    }

    @Test fun unsubscribedScrollDoesNotCrossTheChannelButOtherEventsStillDo() {
        val messenger = Messenger()
        val webView = InAppWebView(RuntimeEnvironment.getApplication())
        val delegate = WebViewChannelDelegate(webView, MethodChannel(messenger, "test.browser"))
        delegate.scrollChangedEnabled = false
        delegate.overScrolledEnabled = false
        repeat(120) {
            delegate.onScrollChanged(0, it)
            delegate.onOverScrolled(0, it, false, false)
        }
        assertTrue(messenger.calls.isEmpty())
        delegate.onProgressChanged(50)
        assertEquals(listOf("onProgressChanged"), messenger.calls.map { it.method })
        delegate.scrollChangedEnabled = true
        delegate.overScrolledEnabled = true
        delegate.onScrollChanged(0, 100)
        delegate.onOverScrolled(0, 100, false, true)
        assertEquals(listOf("onProgressChanged", "onScrollChanged", "onOverScrolled"), messenger.calls.map { it.method })
        assertEquals(100, (messenger.calls[1].arguments as Map<*, *>)["y"])
        delegate.dispose()
        webView.destroy()
    }

    @Test
    @GraphicsMode(GraphicsMode.Mode.NATIVE)
    fun previewDrawsAtTheRequestedResolutionAndRepliesOnTheMainThread() {
        val context = RuntimeEnvironment.getApplication()
        val view = object : View(context) {
            override fun onDraw(canvas: Canvas) {
                canvas.drawColor(Color.RED)
                canvas.drawRect(100f, 0f, 200f, 100f, Paint().apply { color = Color.BLUE })
            }
        }
        view.measure(View.MeasureSpec.makeMeasureSpec(200, View.MeasureSpec.EXACTLY), View.MeasureSpec.makeMeasureSpec(100, View.MeasureSpec.EXACTLY))
        view.layout(0, 0, 200, 100)
        var completed = false
        var bytes: ByteArray? = null
        WebViewScreenshot.capture(view, mapOf(
            "snapshotWidth" to 25.0, "compressFormat" to "PNG", "quality" to 100,
            "rect" to mapOf("x" to 50.0, "y" to 0.0, "width" to 50.0, "height" to 25.0)
        ), 2f, object : MethodChannel.Result {
            override fun success(result: Any?) {
                assertSame(Looper.getMainLooper(), Looper.myLooper())
                bytes = result as ByteArray
                completed = true
            }
            override fun error(code: String, message: String?, details: Any?) = fail(message)
            override fun notImplemented() = fail("Screenshot unsupported")
        })
        val deadline = System.nanoTime() + 3_000_000_000L
        while (!completed && System.nanoTime() < deadline) {
            Thread.sleep(5)
            shadowOf(Looper.getMainLooper()).idle()
        }
        assertTrue("Background encoder must complete", completed)
        val image = BitmapFactory.decodeByteArray(bytes!!, 0, bytes!!.size)
        assertEquals(50, image.width)
        assertEquals(25, image.height)
        assertEquals(Color.BLUE, image.getPixel(25, 12))
        image.recycle()
    }

    @Test fun solidCreatedWebViewRetainsSelectionCleanupWhenCompositionChanges() {
        val context = RuntimeEnvironment.getApplication()
        val webView = InAppWebView(context)
        webView.plugin = com.pichillilorenzo.flutter_inappwebview_android.InAppWebViewFlutterPlugin()
        webView.customSettings.useHybridComposition = true
        webView.prepare()
        assertNotNull(webView.checkContextMenuShouldBeClosedTask)
        assertTrue(webView.userContentController.getPluginScriptsAt(
            com.pichillilorenzo.flutter_inappwebview_android.types.UserScriptInjectionTime.AT_DOCUMENT_START
        ).any { it.groupName == com.pichillilorenzo.flutter_inappwebview_android.plugin_scripts_js.PluginScriptsUtil.CHECK_GLOBAL_KEY_DOWN_EVENT_TO_HIDE_CONTEXT_MENU_JS_PLUGIN_SCRIPT_GROUP_NAME })
        webView.setUseHybridComposition(false)
        webView.customSettings.useHybridComposition = false
        val selectionMenu = android.widget.LinearLayout(context)
        webView.floatingContextMenu = selectionMenu
        webView.addView(selectionMenu)
        webView.checkContextMenuShouldBeClosedTask.run()
        shadowOf(webView).lastEvaluatedJavascriptCallback.onReceiveValue("true")
        assertNull(webView.floatingContextMenu)
        assertNull(selectionMenu.parent)
        webView.destroy()
    }

    @Test fun switchingCompositionDropsTheOldInputProxyAndCanCreateANewOne() {
        val context = RuntimeEnvironment.getApplication()
        val container = View(context)
        val webView = InputAwareWebView(context, container, false)
        val proxy = InputAwareWebView::class.java.getDeclaredField("proxyAdapterView").apply { isAccessible = true }
        webView.checkInputConnectionProxy(View(context))
        assertNotNull(proxy.get(webView))
        webView.setUseHybridComposition(true)
        webView.setContainerView(null)
        assertNull(proxy.get(webView))
        webView.checkInputConnectionProxy(View(context))
        assertNull(proxy.get(webView))
        webView.setUseHybridComposition(false)
        webView.setContainerView(container)
        webView.checkInputConnectionProxy(View(context))
        assertNotNull(proxy.get(webView))
        webView.destroy()
    }
}
