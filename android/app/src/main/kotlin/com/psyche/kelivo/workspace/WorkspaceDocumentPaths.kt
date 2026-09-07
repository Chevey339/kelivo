package com.psyche.kelivo.workspace

import java.io.File
import java.io.FileNotFoundException

internal data class WorkspaceDocumentRoot(val id: String, val name: String, val directory: File)

/** Document IDs contain logical paths, never arbitrary host paths. */
internal object WorkspaceDocumentPaths {
    const val ROOT = "workspaces"
    private const val PREFIX = "workspace/"

    fun validId(id: String): Boolean = id.isNotEmpty() && id != "." && id != ".." &&
        id.none { it == '/' || it == '\\' || it == '\u0000' }

    fun documentId(workspaceId: String, relativePath: String = ""): String =
        "$PREFIX$workspaceId" + if (relativePath.isEmpty()) "" else "/$relativePath"

    fun parse(documentId: String): Pair<String, String> {
        if (!documentId.startsWith(PREFIX)) throw FileNotFoundException("Unknown document")
        val parts = documentId.removePrefix(PREFIX).split('/', limit = 2)
        if (!validId(parts[0])) throw FileNotFoundException("Invalid workspace ID")
        return parts[0] to parts.getOrElse(1) { "" }
    }

    fun managedDirectory(appData: File, id: String): File {
        if (!validId(id)) throw FileNotFoundException("Invalid workspace ID")
        val expected = File(appData.canonicalFile, "workspaces/$id/files")
        // Neither the workspace root nor an ancestor may redirect to app data
        // or another workspace, including when restored from another device.
        if (expected.canonicalFile != expected || (expected.exists() && !expected.isDirectory)) {
            throw FileNotFoundException("Invalid workspace root")
        }
        return expected
    }

    fun resolve(root: WorkspaceDocumentRoot, relativePath: String): File {
        if (relativePath.isNotEmpty() && relativePath.split('/').any {
                it.isEmpty() || it == "." || it == ".." || '\u0000' in it || '\\' in it
            }) throw FileNotFoundException("Invalid document path")
        val base = root.directory
        if (base.canonicalFile != base) throw FileNotFoundException("Invalid workspace root")
        val file = if (relativePath.isEmpty()) base else File(base, relativePath).canonicalFile
        if (file != base && !isWithin(base, file)) throw FileNotFoundException("Path outside workspace")
        if (relativePath.isNotEmpty() && !file.exists()) throw FileNotFoundException("Document no longer exists")
        if (file.exists() && !file.isFile && !file.isDirectory) throw FileNotFoundException("Not a regular document")
        return file
    }

    fun isWithin(parent: File, child: File): Boolean =
        child.path.startsWith(parent.path + File.separator)
}
