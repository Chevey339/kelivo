package com.psyche.kelivo.workspace

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class GuestCwdTest {
    @Test
    fun acceptsAbsolutePath() {
        assertEquals("/workspace", ProotCommand.validateGuestCwd("/workspace"))
        assertEquals("/tmp/work", ProotCommand.validateGuestCwd("  /tmp/work  "))
        assertEquals("/", ProotCommand.validateGuestCwd("/"))
    }

    @Test
    fun rejectsRelativePath() {
        assertThrows(IllegalArgumentException::class.java) {
            ProotCommand.validateGuestCwd("workspace")
        }
        assertThrows(IllegalArgumentException::class.java) {
            ProotCommand.validateGuestCwd("")
        }
    }

    @Test
    fun rejectsDotDotSegments() {
        assertThrows(IllegalArgumentException::class.java) {
            ProotCommand.validateGuestCwd("/workspace/../etc")
        }
        assertThrows(IllegalArgumentException::class.java) {
            ProotCommand.validateGuestCwd("/../tmp")
        }
    }

    @Test
    fun rejectsNul() {
        assertThrows(IllegalArgumentException::class.java) {
            ProotCommand.validateGuestCwd("/workspace\u0000/etc")
        }
    }
}
