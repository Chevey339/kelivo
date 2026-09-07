package com.psyche.kelivo.workspace

import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File
import java.nio.file.Files

class WorkspaceDirectoryPathsTest {
    @get:Rule val temporary = TemporaryFolder()

    @Test fun resolvesUnicodeSpacesAndVolumeRoot() {
        val root = temporary.newFolder("volume")
        assertEquals(File(root, "Documents/我的笔记 Vault").canonicalFile,
            WorkspaceDirectoryPaths.resolve(root, "primary:Documents/我的笔记 Vault"))
        assertEquals(root.canonicalFile, WorkspaceDirectoryPaths.resolve(root, "1234-ABCD:"))
    }

    @Test fun rejectsEscapesAndProotDelimiters() {
        val root = temporary.newFolder("volume")
        for (id in listOf("primary:../outside", "primary:/absolute", "primary:dir/../../outside",
            "primary:folder:with:colons", "primary:bad\u0000path", "primary")) {
            assertThrows(id, IllegalArgumentException::class.java) { WorkspaceDirectoryPaths.resolve(root, id) }
        }
    }

    @Test fun rejectsSymlinksOutsideTheSelectedVolume() {
        val root = temporary.newFolder("volume")
        val outside = temporary.newFolder("outside")
        Files.createSymbolicLink(File(root, "escape").toPath(), outside.toPath())
        assertThrows(IllegalArgumentException::class.java) {
            WorkspaceDirectoryPaths.resolve(root, "primary:escape")
        }
    }
}
