package com.psyche.kelivo.workspace

import java.io.File
import java.security.MessageDigest

object Sha256 {
    fun file(path: String): String {
        val file = File(path)
        require(file.isFile) { "not a file: $path" }
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer = ByteArray(64 * 1024)
            while (true) {
                val read = input.read(buffer)
                if (read < 0) break
                digest.update(buffer, 0, read)
            }
        }
        return digest.digest().joinToString("") { byte -> "%02x".format(byte) }
    }
}
