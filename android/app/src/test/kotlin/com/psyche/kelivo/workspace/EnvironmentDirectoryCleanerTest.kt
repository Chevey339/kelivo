package com.psyche.kelivo.workspace

import org.junit.Assert.*
import org.junit.Assume.assumeFalse
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File
import java.io.IOException
import java.nio.file.Files
import java.nio.file.LinkOption.NOFOLLOW_LINKS
import java.nio.file.attribute.PosixFilePermissions.fromString

class EnvironmentDirectoryCleanerTest {
    @get:Rule val temporary = TemporaryFolder()

    @Test fun repairsNestedDirectoriesBeforeTraversal() {
        val root = temporary.newFolder("previous-rootfs")
        val parent = File(root, "locked").apply { mkdir() }
        val child = File(parent, "unreadable").apply { mkdir() }
        val payload = File(child, "payload").apply { writeText("data") }
        try {
            Files.setPosixFilePermissions(payload.toPath(), fromString("r--r--r--"))
            Files.setPosixFilePermissions(child.toPath(), fromString("---------"))
            Files.setPosixFilePermissions(parent.toPath(), fromString("r-xr-xr-x"))
            Files.setPosixFilePermissions(root.toPath(), fromString("r-x------"))
            assumeFalse("requires an unprivileged process", root.canWrite())
            assertThrows(IOException::class.java) { Files.delete(payload.toPath()) }

            EnvironmentDirectoryCleaner.delete(root)
            assertFalse(Files.exists(root.toPath(), NOFOLLOW_LINKS))
        } finally {
            // Restore top-down so failed assertions cannot leave an undeletable fixture.
            for (directory in listOf(root, parent, child)) {
                if (directory.exists()) {
                    Files.setPosixFilePermissions(directory.toPath(), fromString("rwx------"))
                }
            }
        }
    }

    @Test fun unlinksSymlinksWithoutChangingTheirTargets() {
        val root = temporary.newFolder("rootfs")
        val outside = temporary.newFolder("outside")
        val payload = File(outside, "keep").apply { writeText("keep contents") }
        val outsideMode = fromString("r-x------")
        val fileMode = fromString("r--------")
        Files.setPosixFilePermissions(outside.toPath(), outsideMode)
        Files.setPosixFilePermissions(payload.toPath(), fileMode)
        try {
            Files.createSymbolicLink(File(root, "external-directory").toPath(), outside.toPath())
            Files.createSymbolicLink(File(root, "external-file").toPath(), payload.toPath())
            Files.createSymbolicLink(File(root, "dangling").toPath(), File(outside, "missing").toPath())
            Files.createSymbolicLink(File(root, "cycle").toPath(), root.toPath())

            EnvironmentDirectoryCleaner.delete(root)
            assertFalse(root.exists())
            assertEquals("keep contents", payload.readText())
            assertEquals(outsideMode, Files.getPosixFilePermissions(outside.toPath()))
            assertEquals(fileMode, Files.getPosixFilePermissions(payload.toPath()))
        } finally {
            Files.setPosixFilePermissions(outside.toPath(), fromString("rwx------"))
        }
    }

    @Test fun handlesMissingPathsAndRootSymlinks() {
        val outside = temporary.newFolder("outside")
        val payload = File(outside, "keep").apply { writeText("keep") }
        val root = File(temporary.root, "previous-rootfs")
        Files.createSymbolicLink(root.toPath(), outside.toPath())
        EnvironmentDirectoryCleaner.delete(root)
        assertEquals("keep", payload.readText())
        assertFalse(Files.exists(root.toPath(), NOFOLLOW_LINKS))

        Files.createSymbolicLink(root.toPath(), File(outside, "missing").toPath())
        EnvironmentDirectoryCleaner.delete(root)
        assertFalse(Files.exists(root.toPath(), NOFOLLOW_LINKS))
        EnvironmentDirectoryCleaner.delete(root)
    }

    @Test fun reportsFailureInsteadOfClaimingAnUnremovedDirectoryWasDeleted() {
        val parent = temporary.newFolder("parent")
        val root = File(parent, "rootfs").apply { mkdir() }
        try {
            Files.setPosixFilePermissions(parent.toPath(), fromString("r-x------"))
            assumeFalse("requires an unprivileged process", parent.canWrite())
            assertThrows(IOException::class.java) { EnvironmentDirectoryCleaner.delete(root) }
            assertTrue(root.exists())
        } finally {
            Files.setPosixFilePermissions(parent.toPath(), fromString("rwx------"))
        }
    }
}
