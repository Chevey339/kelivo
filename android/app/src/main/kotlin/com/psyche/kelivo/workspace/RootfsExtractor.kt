package com.psyche.kelivo.workspace

import java.io.BufferedInputStream
import java.io.EOFException
import java.io.File
import java.io.InputStream
import java.io.OutputStream
import java.nio.file.Files
import java.util.Locale
import java.util.zip.GZIPInputStream
import org.tukaani.xz.XZInputStream

object RootfsExtractor {
    private const val BLOCK = 512
    private const val BUFFER = 64 * 1024
    private const val PROGRESS_MS = 200L

    fun extract(
        archive: File,
        destDir: File,
        format: String,
        onProgress: (entries: Int, bytes: Long, currentEntry: String) -> Unit = { _, _, _ -> },
    ) {
        require(archive.isFile && archive.length() > 0L) {
            "archive is missing or empty: ${archive.absolutePath}"
        }
        destDir.mkdirs()
        val raw = BufferedInputStream(archive.inputStream(), BUFFER)
        val input = when (format.lowercase(Locale.US)) {
            "tar.gz", "tgz" -> GZIPInputStream(raw)
            "tar.xz", "txz" -> XZInputStream(raw)
            else -> {
                raw.close()
                throw IllegalArgumentException("unsupported rootfs format: $format")
            }
        }
        input.use { stream ->
            unpack(stream, destDir, onProgress)
        }
    }

    internal fun sanitizeTarPath(path: String): String {
        val normalized = path.replace('\\', '/').trim()
        require(!normalized.startsWith("/")) { "absolute tar path rejected: $path" }
        require(!normalized.contains('\u0000')) { "tar path contains a NUL byte" }
        val cleaned = normalized.removePrefix("./")
        if (cleaned.isEmpty() || cleaned == ".") return ""
        require(cleaned.split('/').none { it == ".." }) {
            "tar path escapes destination: $path"
        }
        return cleaned
    }

    internal fun resolveInside(root: File, path: String): File {
        val sanitized = sanitizeTarPath(path)
        require(sanitized.isNotEmpty()) { "tar path is blank" }
        val base = root.canonicalFile
        val target = File(base, sanitized).canonicalFile
        require(target.path == base.path || target.path.startsWith(base.path + File.separator)) {
            "tar path escapes destination: $path"
        }
        return target
    }

    private fun unpack(
        input: InputStream,
        destDir: File,
        onProgress: (entries: Int, bytes: Long, currentEntry: String) -> Unit,
    ) {
        val reader = TarStream(input)
        var entries = 0
        var bytes = 0L
        var lastEmit = 0L
        fun emit(name: String, force: Boolean = false) {
            val now = System.currentTimeMillis()
            if (!force && now - lastEmit < PROGRESS_MS) return
            lastEmit = now
            onProgress(entries, bytes, name)
        }

        while (true) {
            val entry = reader.nextEntry() ?: break
            val written = writeEntry(reader, destDir, entry)
            bytes += written
            entries++
            emit(entry.name)
        }
        emit("", force = true)
    }

    private fun writeEntry(reader: TarStream, root: File, entry: TarEntry): Long {
        if (entry.name.isEmpty()) {
            if (entry.kind != TarKind.FILE) {
                reader.skipCount(entry.size)
            } else {
                reader.skipCount(entry.size)
            }
            reader.align(entry.size)
            return 0L
        }
        val target = resolveInside(root, entry.name)
        target.parentFile?.mkdirs()
        var written = 0L
        when (entry.kind) {
            TarKind.DIRECTORY -> {
                target.mkdirs()
                applyMode(target, entry.mode)
            }
            TarKind.SYMLINK -> writeSymlink(root, target, entry.link)
            TarKind.HARDLINK -> writeHardlink(root, target, entry.link)
            TarKind.FILE -> {
                target.outputStream().use { out -> reader.drainInto(out, entry.size) }
                applyMode(target, entry.mode)
                written = entry.size
            }
            TarKind.OTHER -> reader.skipCount(entry.size)
        }
        if (entry.kind != TarKind.FILE && entry.kind != TarKind.OTHER) {
            reader.skipCount(entry.size)
        }
        reader.align(entry.size)
        if (entry.mtime > 0 && entry.kind != TarKind.SYMLINK) {
            try {
                target.setLastModified(entry.mtime * 1000)
            } catch (_: Exception) {
            }
        }
        return written
    }

    private fun writeSymlink(root: File, target: File, linkName: String) {
        if (linkName.isBlank()) return
        if (File(linkName).isAbsolute) {
            // Guest-absolute target (e.g. /usr/bin/python). Keep as written.
        } else {
            val resolved = File(target.parentFile ?: root, linkName).canonicalFile
            val base = root.canonicalFile
            require(resolved.path == base.path || resolved.path.startsWith(base.path + File.separator)) {
                "symlink escapes destination: ${target.name} -> $linkName"
            }
        }
        if (target.exists() || Files.isSymbolicLink(target.toPath())) {
            target.delete()
        }
        Files.createSymbolicLink(target.toPath(), File(linkName).toPath())
    }

    private fun writeHardlink(root: File, target: File, linkName: String) {
        if (linkName.isBlank()) return
        val source = resolveInside(root, linkName)
        require(source.exists()) { "hardlink source missing: $linkName" }
        if (target.exists()) target.delete()
        source.copyTo(target, overwrite = true)
        target.setReadable(source.canRead(), false)
        target.setWritable(source.canWrite(), true)
        target.setExecutable(source.canExecute(), false)
    }

    private fun applyMode(file: File, mode: Int) {
        try {
            val os = Class.forName("android.system.Os")
            val chmod = os.getMethod("chmod", String::class.java, Int::class.javaPrimitiveType)
            chmod.invoke(null, file.absolutePath, mode)
            return
        } catch (_: Throwable) {
        }
        try {
            file.setReadable(mode and 0b100_000_000 != 0, false)
            file.setWritable(mode and 0b010_000_000 != 0, true)
            file.setExecutable(mode and 0b001_000_000 != 0, false)
        } catch (_: Exception) {
        }
    }

    private enum class TarKind { FILE, DIRECTORY, SYMLINK, HARDLINK, OTHER }

    private class TarEntry(
        val name: String,
        val mode: Int,
        val size: Long,
        val mtime: Long,
        val kind: TarKind,
        val link: String,
    )

    private class TarStream(private val source: InputStream) {
        private val block = ByteArray(BLOCK)
        private val payload = ByteArray(BUFFER)

        fun nextEntry(
            depth: Int = 0,
            nameOverride: String? = null,
            linkOverride: String? = null,
        ): TarEntry? {
            val header = readHeader() ?: return null
            if (header.name.isEmpty() && nameOverride == null && linkOverride == null &&
                header.kind == TarKind.OTHER && header.size == 0L
            ) {
                align(header.size)
                return nextEntry()
            }
            return when (header.typeFlag) {
                'L' -> {
                    require(depth < 8) { "tar long-name nesting too deep" }
                    val name = readPayloadText(header.size)
                    align(header.size)
                    nextEntry(depth + 1, name, linkOverride)
                }
                'K' -> {
                    require(depth < 8) { "tar long-link nesting too deep" }
                    val link = readPayloadText(header.size)
                    align(header.size)
                    nextEntry(depth + 1, nameOverride, link)
                }
                'x', 'g' -> {
                    require(depth < 8) { "tar pax nesting too deep" }
                    val fields = parsePax(readPayloadText(header.size))
                    align(header.size)
                    nextEntry(depth + 1, fields["path"] ?: nameOverride, fields["linkpath"] ?: linkOverride)
                }
                else -> {
                    val name = nameOverride ?: header.name
                    val link = linkOverride ?: header.link
                    if (name.isEmpty()) {
                        skipCount(header.size)
                        align(header.size)
                        return nextEntry()
                    }
                    TarEntry(
                        name = if (name.startsWith("/")) name else sanitizeTarPath(name),
                        mode = header.mode,
                        size = header.size,
                        mtime = header.mtime,
                        kind = header.kind,
                        link = link,
                    )
                }
            }
        }

        private class Header(
            val name: String,
            val mode: Int,
            val size: Long,
            val mtime: Long,
            val kind: TarKind,
            val link: String,
            val typeFlag: Char,
        )

        private fun readHeader(): Header? {
            val got = readInto(block)
            if (got == 0) return null
            if (got < BLOCK) throw EOFException("tar ended mid-header")
            if (block.all { it == 0.toByte() }) return null
            val name = text(0, 100)
            val prefix = text(345, 155)
            val full = listOf(prefix, name).filter { it.isNotBlank() }.joinToString("/")
            val flag = block[156].toInt().toChar()
            val kind = when (flag) {
                '0', '\u0000' -> TarKind.FILE
                '5' -> TarKind.DIRECTORY
                '2' -> TarKind.SYMLINK
                '1' -> TarKind.HARDLINK
                else -> TarKind.OTHER
            }
            return Header(
                name = full,
                mode = octal(100, 8).toInt(),
                size = octal(124, 12),
                mtime = octal(136, 12),
                kind = kind,
                link = text(157, 100),
                typeFlag = flag,
            )
        }

        fun drainInto(out: OutputStream, size: Long) {
            var remaining = size
            while (remaining > 0) {
                checkAlive()
                val want = minOf(payload.size.toLong(), remaining).toInt()
                val read = source.read(payload, 0, want)
                if (read < 0) throw EOFException("tar payload ended early")
                out.write(payload, 0, read)
                remaining -= read
            }
        }

        fun skipCount(size: Long) {
            var remaining = size
            while (remaining > 0) {
                checkAlive()
                val skipped = source.skip(remaining)
                if (skipped > 0) {
                    remaining -= skipped
                } else if (source.read() >= 0) {
                    remaining--
                } else {
                    throw EOFException("tar payload ended early")
                }
            }
        }

        fun align(size: Long) {
            val pad = size % BLOCK
            if (pad != 0L) skipCount(BLOCK - pad)
        }

        private fun readPayloadText(size: Long): String {
            require(size <= Int.MAX_VALUE) { "tar record too large: $size" }
            val bytes = ByteArray(size.toInt())
            val read = readInto(bytes)
            if (read != bytes.size) throw EOFException("tar payload ended early")
            return String(bytes, Charsets.UTF_8).trimEnd('\u0000', '\n')
        }

        private fun readInto(buffer: ByteArray): Int {
            var offset = 0
            while (offset < buffer.size) {
                val read = source.read(buffer, offset, buffer.size - offset)
                if (read < 0) break
                offset += read
            }
            return offset
        }

        private fun text(offset: Int, width: Int): String {
            var end = offset + width
            for (i in offset until offset + width) {
                if (block[i] == 0.toByte()) {
                    end = i
                    break
                }
            }
            return String(block, offset, end - offset, Charsets.UTF_8).trim()
        }

        private fun octal(offset: Int, width: Int): Long {
            val first = block[offset].toInt() and 0xFF
            if (first and 0x80 != 0) {
                var value = 0L
                for (i in 1 until width) {
                    value = (value shl 8) or (block[offset + i].toLong() and 0xFF)
                }
                return value
            }
            val digits = text(offset, width).filter { it in '0'..'7' }
            return digits.toLongOrNull(8) ?: 0L
        }

        private fun parsePax(text: String): Map<String, String> {
            val fields = mutableMapOf<String, String>()
            var cursor = 0
            while (cursor < text.length) {
                val space = text.indexOf(' ', cursor)
                if (space < 0) break
                val length = text.substring(cursor, space).toIntOrNull() ?: break
                val end = (cursor + length).coerceAtMost(text.length)
                val record = text.substring(space + 1, end).trimEnd('\n')
                val equals = record.indexOf('=')
                if (equals > 0) {
                    fields[record.substring(0, equals)] = record.substring(equals + 1)
                }
                cursor += length
            }
            return fields
        }

        private fun checkAlive() {
            if (Thread.currentThread().isInterrupted) {
                throw InterruptedException("rootfs extract cancelled")
            }
        }
    }
}
