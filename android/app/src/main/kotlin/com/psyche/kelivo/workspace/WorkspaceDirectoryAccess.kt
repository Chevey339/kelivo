package com.psyche.kelivo.workspace

import android.Manifest
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.storage.StorageManager
import android.provider.DocumentsContract
import android.provider.Settings
import io.flutter.plugin.common.MethodChannel
import java.io.File

/** SAF chooses the folder; direct filesystem access is required by Dart and PRoot. */
class WorkspaceDirectoryAccess(private val context: Context) {
    private var attachedActivity: Activity? = context as? Activity
    fun attachActivity(activity: Activity) { attachedActivity = activity }
    fun detachActivity(activity: Activity) {
        if (attachedActivity !== activity) return
        attachedActivity = null
        dispose()
    }
    companion object {
        private const val PICK_DIRECTORY = 4110
        private const val STORAGE_ACCESS = 4111
        private const val LEGACY_STORAGE_ACCESS = 4112
    }

    private var pendingPicker: MethodChannel.Result? = null
    private var pendingAccess: MethodChannel.Result? = null

    fun hasStorageAccess(): Boolean = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
        Environment.isExternalStorageManager()
    } else {
        context.checkSelfPermission(Manifest.permission.READ_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED &&
            context.checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
    }

    fun requestStorageAccess(result: MethodChannel.Result) {
        val activity = attachedActivity ?: run {
            result.error("foreground_activity_required", "Open Kelivo to grant storage access.", null)
            return
        }
        if (hasStorageAccess()) {
            result.success(true)
            return
        }
        if (pendingAccess != null) {
            result.error("busy", "A storage access request is already open", null)
            return
        }
        pendingAccess = result
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                    Uri.parse("package:${context.packageName}"))
                try {
                    activity.startActivityForResult(intent, STORAGE_ACCESS)
                } catch (_: ActivityNotFoundException) {
                    activity.startActivityForResult(Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION), STORAGE_ACCESS)
                }
            } else {
                activity.requestPermissions(arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE,
                    Manifest.permission.WRITE_EXTERNAL_STORAGE), LEGACY_STORAGE_ACCESS)
            }
        } catch (error: Exception) {
            pendingAccess = null
            result.error("external_storage_permission", error.message, null)
        }
    }

    fun pick(result: MethodChannel.Result) {
        val activity = attachedActivity ?: run {
            result.error("foreground_activity_required", "Open Kelivo to choose a folder.", null)
            return
        }
        if (!hasStorageAccess()) {
            result.error("external_storage_permission", "Storage access is required for mounting", null)
            return
        }
        if (pendingPicker != null) {
            result.error("busy", "A folder picker is already open", null)
            return
        }
        pendingPicker = result
        try {
            activity.startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
            }, PICK_DIRECTORY)
        } catch (error: Exception) {
            pendingPicker = null
            result.error("external_folder_unavailable", error.message, null)
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == STORAGE_ACCESS) {
            val result = pendingAccess
            pendingAccess = null
            result?.success(hasStorageAccess())
            return true
        }
        if (requestCode != PICK_DIRECTORY) return false
        val result = pendingPicker ?: return true
        pendingPicker = null
        val uri = if (resultCode == Activity.RESULT_OK) data?.data else null
        if (uri == null) {
            result.success(null)
            return true
        }
        try {
            if (uri.authority != WorkspaceDirectoryPaths.AUTHORITY) {
                result.error("external_folder_provider", "Only on-device folders can be mounted", null)
                return true
            }
            val path = resolvePath(uri)
            val flags = (data?.flags ?: 0) and (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            require(flags and Intent.FLAG_GRANT_READ_URI_PERMISSION != 0) { "Read access was not granted" }
            context.contentResolver.takePersistableUriPermission(uri, flags)
            result.success(mapOf("path" to path, "token" to uri.toString()))
        } catch (error: Exception) {
            result.error("external_folder_unavailable", error.message, null)
        }
        return true
    }

    fun onRequestPermissionsResult(requestCode: Int): Boolean {
        if (requestCode != LEGACY_STORAGE_ACCESS) return false
        val result = pendingAccess
        pendingAccess = null
        result?.success(hasStorageAccess())
        return true
    }

    fun resolve(token: String): Map<String, String> {
        check(hasStorageAccess()) { "Storage access was revoked" }
        val uri = Uri.parse(token)
        check(context.contentResolver.persistedUriPermissions.any { it.uri == uri && it.isReadPermission }) {
            "Folder access was revoked; select the folder again"
        }
        return mapOf("path" to resolvePath(uri), "token" to token)
    }

    fun release(token: String) {
        val uri = Uri.parse(token)
        val permission = context.contentResolver.persistedUriPermissions.firstOrNull { it.uri == uri } ?: return
        val flags = (if (permission.isReadPermission) Intent.FLAG_GRANT_READ_URI_PERMISSION else 0) or
            (if (permission.isWritePermission) Intent.FLAG_GRANT_WRITE_URI_PERMISSION else 0)
        context.contentResolver.releasePersistableUriPermission(uri, flags)
    }

    private fun resolvePath(uri: Uri): String {
        require(uri.authority == WorkspaceDirectoryPaths.AUTHORITY) { "Unsupported document provider" }
        val documentId = DocumentsContract.getTreeDocumentId(uri)
        val volume = documentId.substringBefore(':')
        val root = if (volume.equals("primary", ignoreCase = true)) {
            Environment.getExternalStorageDirectory()
        } else {
            val manager = context.getSystemService(Context.STORAGE_SERVICE) as StorageManager
            val storage = manager.storageVolumes.firstOrNull { it.uuid?.equals(volume, ignoreCase = true) == true }
                ?: throw IllegalArgumentException("Storage volume is unavailable")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) storage.directory
            else File("/storage/${storage.uuid}")
        } ?: throw IllegalArgumentException("Storage volume is unavailable")
        val folder = WorkspaceDirectoryPaths.resolve(root, documentId)
        check(folder.isDirectory && folder.list() != null) { "Folder is unavailable or unreadable" }
        return folder.path
    }

    fun dispose() {
        pendingPicker?.error("cancelled", "Activity closed", null)
        pendingAccess?.error("cancelled", "Activity closed", null)
        pendingPicker = null
        pendingAccess = null
    }
}

internal object WorkspaceDirectoryPaths {
    const val AUTHORITY = "com.android.externalstorage.documents"

    fun resolve(volumeRoot: File, documentId: String): File {
        require(documentId.contains(':')) { "Invalid tree document ID" }
        val relative = documentId.substringAfter(':')
        require(!relative.startsWith('/') && !relative.contains('\u0000') && !relative.contains(':')) {
            "Folder path cannot be represented as a PRoot bind"
        }
        require(relative.split('/').none { it == ".." }) { "Folder escapes its storage volume" }
        val root = volumeRoot.canonicalFile
        val folder = File(root, relative).canonicalFile
        require(!folder.path.contains(':')) { "Folder path cannot be represented as a PRoot bind" }
        require(folder == root || folder.path.startsWith(root.path + File.separator)) {
            "Folder escapes its storage volume"
        }
        return folder
    }
}
