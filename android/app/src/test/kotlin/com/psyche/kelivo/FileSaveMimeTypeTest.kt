package com.psyche.kelivo

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

    @Test fun unknownAndExtensionlessFilesUseBinaryType() {
        assertEquals("application/octet-stream", fileSaveMimeType("model.unknown1117"))
        assertEquals("application/octet-stream", fileSaveMimeType("Dockerfile"))
    }
}
