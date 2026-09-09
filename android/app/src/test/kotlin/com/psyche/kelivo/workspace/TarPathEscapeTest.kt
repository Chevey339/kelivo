package com.psyche.kelivo.workspace

import java.io.ByteArrayOutputStream
import java.io.File
import java.nio.file.Files
import java.util.zip.GZIPOutputStream
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
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

    @Test
    fun rootAliasSymlinkCannotRedirectFollowingEntriesOutsideDestination() {
        val outside = tmp.newFolder("outside")
        val victim = File(outside, "victim").apply { writeText("keep original contents") }
        val archive = tmp.newFile("root-link.tar").apply {
            writeBytes(ustarFile("./././", "", '2', outside.absolutePath) +
                ustarFile("victim", "overwritten") + ByteArray(1024))
        }
        val dest = tmp.newFolder("dest")
        assertThrows(IllegalArgumentException::class.java) {
            RootfsExtractor.extract(archive, dest, "tar")
        }
        assertFalse(Files.isSymbolicLink(dest.toPath()))
        assertEquals("keep original contents", victim.readText())
    }

    @Test
    fun rootAliasesRejectEveryNonDirectoryEntry() {
        for (name in listOf(".", "./", "././", "./././", ".//./")) {
            for (kind in listOf('0', '1', '2', '6')) {
                val archive = tmp.newFile().apply {
                    writeBytes(ustarFile(name, "", kind, "/outside") + ByteArray(1024))
                }
                val dest = tmp.newFolder()
                assertThrows("$name, type=$kind", IllegalArgumentException::class.java) {
                    RootfsExtractor.extract(archive, dest, "tar")
                }
                assertFalse(Files.isSymbolicLink(dest.toPath()))
            }
        }
    }

    @Test
    fun ordinaryRootDirectoryEntriesAndGuestSymlinksStillExtract() {
        val archive = tmp.newFile("ordinary.tar").apply {
            writeBytes(listOf(".", "./", "././", "./././", ".//./")
                .fold(ByteArray(0)) { bytes, name -> bytes + ustarFile(name, "", '5') } +
                ustarFile("./etc/./message", "hello") +
                ustarFile("bin", "", '2', "/usr/bin") + ByteArray(1024))
        }
        val dest = tmp.newFolder("ordinary")
        RootfsExtractor.extract(archive, dest, "tar")
        assertEquals("hello", File(dest, "etc/message").readText())
        assertEquals("/usr/bin", Files.readSymbolicLink(File(dest, "bin").toPath()).toString())
    }

    @Test
    fun extractionBoundaryDoesNotFollowAReplacedDestination() {
        val outside = tmp.newFolder("outside")
        val victim = File(outside, "victim").apply { writeText("keep original contents") }
        val archive = tmp.newFile("fixed-root.tar").apply {
            writeBytes(ustarFile("ready", "", '5') +
                ustarFile("victim", "overwritten") + ByteArray(1024))
        }
        val dest = tmp.newFolder("dest")
        val moved = File(tmp.root, "moved")
        try {
            assertThrows(IllegalArgumentException::class.java) {
                RootfsExtractor.extract(archive, dest, "tar") { entries, _, _ ->
                    if (entries == 1) {
                        assertTrue(dest.renameTo(moved))
                        Files.createSymbolicLink(dest.toPath(), outside.toPath())
                    }
                }
            }
            assertEquals("keep original contents", victim.readText())
        } finally {
            if (Files.isSymbolicLink(dest.toPath())) Files.delete(dest.toPath())
        }
    }

    private fun ustarFile(name: String, content: String, kind: Char = '0', link: String = ""): ByteArray {
        val header = ByteArray(512)
        val nameBytes = name.toByteArray(Charsets.UTF_8)
        System.arraycopy(nameBytes, 0, header, 0, nameBytes.size)
        writeOctal(header, 100, 8, (if (kind == '5') "755" else "644").toLong(8))
        writeOctal(header, 104, 8, 0)
        writeOctal(header, 112, 8, 0)
        val payload = content.toByteArray(Charsets.UTF_8)
        writeOctal(header, 124, 12, payload.size.toLong())
        writeOctal(header, 136, 12, 0)
        header[156] = kind.code.toByte()
        val linkBytes = link.toByteArray(Charsets.UTF_8)
        require(linkBytes.size <= 100)
        System.arraycopy(linkBytes, 0, header, 157, linkBytes.size)
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
