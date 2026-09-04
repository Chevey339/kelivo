package com.psyche.kelivo.workspace

import org.junit.Assert.assertTrue
import org.junit.Assert.assertFalse
import org.junit.Test

class AptSourcesTest {
    @Test
    fun rewritesArm64ToUbuntuPorts() {
        val text = RootfsPatcher.rewriteUbuntuSources(
            "https://mirrors.example.com/ubuntu-mirror/",
            "noble",
            "arm64",
        )
        assertTrue(text.contains("URIs: https://mirrors.example.com/ubuntu-mirror/ubuntu-ports/"))
        assertTrue(text.contains("Suites: noble noble-updates noble-backports"))
        assertTrue(text.contains("Suites: noble-security"))
        assertFalse(text.contains("/ubuntu/"))
    }

    @Test
    fun rewritesAmd64ToUbuntuArchive() {
        val text = RootfsPatcher.rewriteUbuntuSources(
            "https://mirrors.example.com/ubuntu-mirror",
            "noble",
            "amd64",
        )
        assertTrue(text.contains("URIs: https://mirrors.example.com/ubuntu-mirror/ubuntu/"))
        assertTrue(text.contains("Suites: noble noble-updates noble-backports"))
        assertTrue(text.contains("Suites: noble-security"))
        assertFalse(text.contains("ubuntu-ports"))
    }
}
