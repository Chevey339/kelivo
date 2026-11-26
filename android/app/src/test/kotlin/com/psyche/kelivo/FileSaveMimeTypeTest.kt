package com.psyche.kelivo

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.util.concurrent.CancellationException
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], manifest = Config.NONE)
class FileSaveMimeTypeTest {
    @Test fun preservesFileTypesInsteadOfExportingEverythingAsZip() {
        assertEquals("application/pdf", fileSaveMimeType("报告.PDF"))
        assertEquals("text/plain", fileSaveMimeType("notes.txt"))
        assertEquals("image/png", fileSaveMimeType("image.png"))
        assertEquals("application/zip", fileSaveMimeType("backup.zip"))
    }

    @Test fun backupCopyReportsWrittenBytesAndCanCancelBetweenChunks() {
        val bytes = ByteArray(2 * 1024 * 1024 + 5) { it.toByte() }
        val out = ByteArrayOutputStream()
        val counts = mutableListOf<Long>()
        copyBackupWithProgress(ByteArrayInputStream(bytes), out, bytes.size.toLong(), { false }) { n, total ->
            assertEquals(bytes.size.toLong(), total)
            counts.add(n)
        }
        assertArrayEquals(bytes, out.toByteArray())
        assertEquals(0L, counts.first())
        assertEquals(bytes.size.toLong(), counts.last())
        assertTrue(counts.any { it > 0 && it < bytes.size })
        out.reset()
        var cancel = false
        try {
            copyBackupWithProgress(ByteArrayInputStream(bytes), out, bytes.size.toLong(), { cancel }) { n, _ ->
                cancel = n > 0
            }
            throw AssertionError("Expected cancellation")
        } catch (_: CancellationException) {
            assertTrue(out.size() in 1 until bytes.size)
        }
    }

    @Test fun unknownAndExtensionlessFilesUseBinaryType() {
        assertEquals("application/octet-stream", fileSaveMimeType("model.unknown1117"))
        assertEquals("application/octet-stream", fileSaveMimeType("Dockerfile"))
    }
}
