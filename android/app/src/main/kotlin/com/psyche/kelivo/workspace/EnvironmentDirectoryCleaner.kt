package com.psyche.kelivo.workspace

import java.io.File
import java.nio.file.Files
import java.nio.file.LinkOption.NOFOLLOW_LINKS
import java.nio.file.NoSuchFileException
import java.nio.file.Path
import java.nio.file.attribute.PosixFileAttributes
import java.nio.file.attribute.PosixFilePermission.OWNER_EXECUTE
import java.nio.file.attribute.PosixFilePermission.OWNER_READ
import java.nio.file.attribute.PosixFilePermission.OWNER_WRITE

/** Deletes app-owned guest data after setEnvironmentBusy has stopped guest processes. */
object EnvironmentDirectoryCleaner {
    fun delete(directory: File) = deleteEntry(directory.toPath())

    private fun deleteEntry(path: Path) {
        val attributes = try {
            Files.readAttributes(path, PosixFileAttributes::class.java, NOFOLLOW_LINKS)
        } catch (_: NoSuchFileException) {
            return
        }
        if (attributes.isDirectory) {
            // Repair before listing children: a guest can remove read/search bits too.
            val permissions = attributes.permissions().toMutableSet()
            if (permissions.addAll(listOf(OWNER_READ, OWNER_WRITE, OWNER_EXECUTE))) {
                // The no-follow attribute view opens the directory for reading before
                // chmod on Android, which fails for mode 000. Only chmod entries that
                // the no-follow stat above identified as directories, never symlinks.
                Files.setPosixFilePermissions(path, permissions)
            }
            Files.newDirectoryStream(path).use { children ->
                for (child in children) deleteEntry(child)
            }
        }
        // Symlinks (including dangling and guest-absolute links) are only unlinked.
        // Do not chmod files: unlink needs write permission on their parent directory.
        Files.deleteIfExists(path)
    }
}
