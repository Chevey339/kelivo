package com.psyche.kelivo

import android.content.Intent
import android.os.Bundle
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.nio.ByteBuffer

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28], manifest = Config.NONE)
class CachedProcessTextLaunchTest {
    private class Messenger : BinaryMessenger {
        val calls = mutableListOf<MethodCall>()
        override fun setMessageHandler(channel: String, handler: BinaryMessenger.BinaryMessageHandler?) = Unit
        override fun send(channel: String, message: ByteBuffer?) = send(channel, message, null)
        override fun send(channel: String, message: ByteBuffer?, callback: BinaryMessenger.BinaryReply?) {
            message?.flip()
            if (message != null) calls += StandardMethodCodec.INSTANCE.decodeMethodCall(message)
        }
    }

    private fun selection() = Intent(Intent.ACTION_PROCESS_TEXT)
        .putExtra(Intent.EXTRA_PROCESS_TEXT, "  selected words  ")

    @Test fun replacementActivityDeliversSelectionOnceToTheRetainedHomePage() {
        val messenger = Messenger()
        val channel = MethodChannel(messenger, "app.process_text")
        val intent = selection()
        forwardCachedProcessTextLaunch(true, null, intent, channel)
        assertEquals("onProcessText", messenger.calls.single().method)
        assertEquals("selected words", messenger.calls.single().arguments)
        forwardCachedProcessTextLaunch(true, null, intent, channel)
        assertEquals(1, messenger.calls.size)
        assertNull(takeProcessText(intent))
    }

    @Test fun coldLaunchIsReadOnceThroughGetInitialText() {
        val messenger = Messenger()
        val intent = selection()
        forwardCachedProcessTextLaunch(false, null, intent, MethodChannel(messenger, "app.process_text"))
        assertTrue(messenger.calls.isEmpty())
        assertEquals("selected words", takeProcessText(intent))
        assertNull(takeProcessText(intent))
    }

    @Test fun restoringAnActivityAndOrdinaryLaunchesDoNotSendText() {
        val messenger = Messenger()
        val channel = MethodChannel(messenger, "app.process_text")
        forwardCachedProcessTextLaunch(true, Bundle(), selection(), channel)
        forwardCachedProcessTextLaunch(true, null,
            selection().addFlags(Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY), channel)
        forwardCachedProcessTextLaunch(true, null, Intent(Intent.ACTION_MAIN), channel)
        forwardCachedProcessTextLaunch(true, null,
            Intent(Intent.ACTION_PROCESS_TEXT).putExtra(Intent.EXTRA_PROCESS_TEXT, " \n "), channel)
        assertTrue(messenger.calls.isEmpty())
    }
}
