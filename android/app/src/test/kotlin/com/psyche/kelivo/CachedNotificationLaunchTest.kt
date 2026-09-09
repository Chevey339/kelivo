package com.psyche.kelivo

import android.content.Intent
import android.os.Bundle
import com.dexterous.flutterlocalnotifications.FlutterLocalNotificationsPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.util.ReflectionHelpers
import java.nio.ByteBuffer

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28], manifest = Config.NONE)
class CachedNotificationLaunchTest {
    private class Messenger : BinaryMessenger {
        val calls = mutableListOf<MethodCall>()
        override fun setMessageHandler(channel: String, handler: BinaryMessenger.BinaryMessageHandler?) = Unit
        override fun send(channel: String, message: ByteBuffer?) = send(channel, message, null)
        override fun send(channel: String, message: ByteBuffer?, callback: BinaryMessenger.BinaryReply?) {
            message?.flip()
            if (message != null) calls += StandardMethodCodec.INSTANCE.decodeMethodCall(message)
        }
    }

    private fun notification() = Intent("SELECT_NOTIFICATION")
        .putExtra("notificationId", 10001).putExtra("payload", "chat-complete:cached-chat")

    private fun setup(): Pair<FlutterLocalNotificationsPlugin, Messenger> {
        val messenger = Messenger()
        val plugin = FlutterLocalNotificationsPlugin()
        ReflectionHelpers.setField(plugin, "channel", MethodChannel(messenger, "notifications"))
        return plugin to messenger
    }

    @Test fun tapOnNewActivityReachesTheExistingDartNotificationCallback() {
        val (plugin, messenger) = setup()
        forwardCachedNotificationLaunch(true, null, notification(), plugin)
        val call = messenger.calls.single()
        assertEquals("didReceiveNotificationResponse", call.method)
        assertEquals("chat-complete:cached-chat", (call.arguments as Map<*, *>)["payload"])
    }

    @Test fun coldLaunchIsLeftToThePluginsLaunchDetailsQuery() {
        val (plugin, messenger) = setup()
        forwardCachedNotificationLaunch(false, null, notification(), plugin)
        assertTrue(messenger.calls.isEmpty())
    }

    @Test fun recreationAndHistoryDoNotReplayAnOldTap() {
        val (plugin, messenger) = setup()
        forwardCachedNotificationLaunch(true, Bundle(), notification(), plugin)
        forwardCachedNotificationLaunch(true, null,
            notification().addFlags(Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY), plugin)
        assertTrue(messenger.calls.isEmpty())
    }
}
