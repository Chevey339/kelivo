package com.psyche.kelivo.workspace

import java.io.ByteArrayOutputStream
import java.io.File
import java.util.zip.GZIPOutputStream
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class TarPathEscapeTest {
    @get:Rule
    val tmp = TemporaryFolder()

    @Test
    fun sanitizeRejectsAbsoluteAndDotDot() {
        assertEquals("etc/passwd", RootfsExtractor.sanitizeTarPath("etc/passwd"))
        assertEquals("etc/passwd", RootfsExtractor.sanitizeTarPath("./etc/passwd"))
        assertThrows(IllegalArgumentException::class.java) {
            RootfsExtractor.sanitizeTarPath("/etc/passwd")
        }
        assertThrows(IllegalArgumentException::class.java) {
            RootfsExtractor.sanitizeTarPath("foo/../../etc/passwd")
        }
        assertThrows(IllegalArgumentException::class.java) {
            RootfsExtractor.sanitizeTarPath("foo\u0000/bar")
        }
    }

    @Test
    fun extractRejectsEscapingEntry() {
        val archive = tmp.newFile("evil.tar.gz")
        archive.outputStream().use { raw ->
            GZIPOutputStream(raw).use { gzip ->
                gzip.write(ustarFile("../evil", "pwned"))
                gzip.write(ByteArray(1024))
            }
        }
        val dest = tmp.newFolder("dest")
        val error = assertThrows(IllegalArgumentException::class.java) {
            RootfsExtractor.extract(archive, dest, "tar.gz")
        }
        assertTrue(error.message!!.contains("escapes"))
        assertTrue(dest.listFiles().isNullOrEmpty() || dest.walk().none { it.name == "evil" && it.isFile })
    }

    private fun ustarFile(name: String, content: String): ByteArray {
        val header = ByteArray(512)
        val nameBytes = name.toByteArray(Charsets.UTF_8)
        System.arraycopy(nameBytes, 0, header, 0, nameBytes.size)
        writeOctal(header, 100, 8, "644".toLong(8))
        writeOctal(header, 104, 8, 0)
        writeOctal(header, 112, 8, 0)
        val payload = content.toByteArray(Charsets.UTF_8)
        writeOctal(header, 124, 12, payload.size.toLong())
        writeOctal(header, 136, 12, 0)
        header[156] = '0'.code.toByte()
        val magic = "ustar".toByteArray(Charsets.US_ASCII)
        System.arraycopy(magic, 0, header, 257, magic.size)
        header[262] = '0'.code.toByte()
        header[263] = '0'.code.toByte()
        for (i in 148 until 156) header[i] = ' '.code.toByte()
        var sum = 0
        for (b in header) sum += b.toInt() and 0xFF
        val checksum = sum.toString(8).padStart(6, '0').toByteArray(Charsets.US_ASCII)
        System.arraycopy(checksum, 0, header, 148, checksum.size)
        header[154] = 0
        header[155] = ' '.code.toByte()

        val out = ByteArrayOutputStream()
        out.write(header)
        out.write(payload)
        val pad = (512 - (payload.size % 512)) % 512
        if (pad > 0) out.write(ByteArray(pad))
        return out.toByteArray()
    }

    private fun writeOctal(header: ByteArray, offset: Int, width: Int, value: Long) {
        val digits = value.toString(8).padStart(width - 1, '0')
        val bytes = (digits + "\u0000").toByteArray(Charsets.US_ASCII)
        System.arraycopy(bytes, 0, header, offset, width.coerceAtMost(bytes.size))
    }
}
