package com.psyche.kelivo.workspace

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class GroupGidInjectionTest {
    @get:Rule
    val tmp = TemporaryFolder()

    @Test
    fun injectsMissingGidsAndIsIdempotent() {
        val group = tmp.newFile("group")
        group.writeText("root:x:0:\n")
        RootfsPatcher.injectAndroidGids(group, listOf(1000, 3003, 1000))
        val once = group.readText()
        assertTrue(once.contains("android_gid_1000:x:1000:"))
        assertTrue(once.contains("android_gid_3003:x:3003:"))
        assertEquals(1, Regex("android_gid_1000").findAll(once).count())

        RootfsPatcher.injectAndroidGids(group, listOf(1000, 3003))
        assertEquals(once, group.readText())
    }

    @Test
    fun skipsIdsAlreadyPresentUnderAnotherName() {
        val group = tmp.newFile("group")
        group.writeText("root:x:0:\nextaid:x:3003:\n")
        RootfsPatcher.injectAndroidGids(group, listOf(3003))
        assertEquals("root:x:0:\nextaid:x:3003:\n", group.readText())
    }
}
