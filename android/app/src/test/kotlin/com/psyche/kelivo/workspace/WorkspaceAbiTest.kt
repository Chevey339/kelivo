package com.psyche.kelivo.workspace

import org.junit.Assert.assertEquals
import org.junit.Test

class WorkspaceAbiTest {
    @Test fun arm64DeviceRunning32BitApkSelectsArmv7() {
        val deviceAbis = arrayOf("arm64-v8a", "armeabi-v7a", "armeabi")
        assertEquals("armeabi-v7a", WorkspacePlugin.runtimeAbi(false, deviceAbis))
        assertEquals("arm64-v8a", WorkspacePlugin.runtimeAbi(true, deviceAbis))
    }

    @Test fun native32BitDeviceAndX86EmulatorKeepTheirAbi() {
        assertEquals("armeabi-v7a", WorkspacePlugin.runtimeAbi(false, arrayOf("armeabi-v7a", "armeabi")))
        assertEquals("x86_64", WorkspacePlugin.runtimeAbi(true, arrayOf("x86_64", "x86")))
    }

    @Test fun unsupportedRuntimeDoesNotSelectAnIncompatibleRootfs() {
        assertEquals("", WorkspacePlugin.runtimeAbi(false, arrayOf("x86_64", "x86")))
        assertEquals("", WorkspacePlugin.runtimeAbi(false, arrayOf("arm64-v8a")))
        assertEquals("", WorkspacePlugin.runtimeAbi(true, emptyArray()))
    }
}
