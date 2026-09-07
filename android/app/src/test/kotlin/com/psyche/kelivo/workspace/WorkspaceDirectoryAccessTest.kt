package com.psyche.kelivo.workspace

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.provider.DocumentsContract
import io.flutter.plugin.common.MethodChannel
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.rules.TemporaryFolder
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowEnvironment
import java.io.File

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28], manifest = Config.NONE)
class WorkspaceDirectoryAccessTest {
    @get:Rule val temporary = TemporaryFolder()

    private class Result : MethodChannel.Result {
        var value: Any? = null
        var error: String? = null
        var completed = false
        override fun success(result: Any?) { value = result; completed = true }
        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
            error = errorCode; completed = true
        }
        override fun notImplemented() = error("not_implemented", null, null)
    }

    private fun activity(): Activity = Robolectric.buildActivity(Activity::class.java).setup().get().also {
        shadowOf(it.application).grantPermissions(Manifest.permission.READ_EXTERNAL_STORAGE,
            Manifest.permission.WRITE_EXTERNAL_STORAGE)
    }

    @Test fun cancelledPickerCompletesAndCanBeReopened() {
        val activity = activity()
        val access = WorkspaceDirectoryAccess(activity)
        val first = Result()
        access.pick(first)
        val started = shadowOf(activity).nextStartedActivityForResult
        assertEquals(Intent.ACTION_OPEN_DOCUMENT_TREE, started.intent.action)
        val second = Result()
        access.pick(second)
        assertEquals("busy", second.error)
        assertTrue(access.onActivityResult(started.requestCode, Activity.RESULT_CANCELED, null))
        assertTrue(first.completed)
        assertNull(first.value)
        val third = Result()
        access.pick(third)
        assertNotNull(shadowOf(activity).nextStartedActivityForResult)
        access.dispose()
        assertEquals("cancelled", third.error)
    }

    @Test fun persistedGrantRestoresOriginalFolderAndRevocationFailsClosed() {
        val root = temporary.newFolder("shared")
        ShadowEnvironment.setExternalStorageDirectory(root.toPath())
        val folder = File(root, "Documents/My Vault").apply { mkdirs() }
        File(folder, "note.txt").writeText("original")
        val activity = activity()
        val access = WorkspaceDirectoryAccess(activity)
        val result = Result()
        access.pick(result)
        val request = shadowOf(activity).nextStartedActivityForResult
        val uri = DocumentsContract.buildTreeDocumentUri(WorkspaceDirectoryPaths.AUTHORITY, "primary:Documents/My Vault")
        access.onActivityResult(request.requestCode, Activity.RESULT_OK, Intent().setData(uri).addFlags(
            Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION))
        assertNull(result.error)
        assertEquals(folder.canonicalPath, (result.value as Map<*, *>)["path"])
        val restored = WorkspaceDirectoryAccess(activity)
        assertEquals(folder.canonicalPath, restored.resolve(uri.toString())["path"])
        restored.release(uri.toString())
        assertThrows(IllegalStateException::class.java) { restored.resolve(uri.toString()) }
        assertEquals("original", File(folder, "note.txt").readText())
    }

    @Test fun rejectsCloudProvidersWithoutPersistingAGrant() {
        val activity = activity()
        val access = WorkspaceDirectoryAccess(activity)
        val result = Result()
        access.pick(result)
        val request = shadowOf(activity).nextStartedActivityForResult
        val uri = DocumentsContract.buildTreeDocumentUri("example.cloud.documents", "folder")
        access.onActivityResult(request.requestCode, Activity.RESULT_OK, Intent().setData(uri))
        assertEquals("external_folder_provider", result.error)
        assertTrue(activity.contentResolver.persistedUriPermissions.isEmpty())
    }

    @Test fun missingStoragePermissionDoesNotOpenAPicker() {
        val activity = activity()
        shadowOf(activity.application).denyPermissions(Manifest.permission.WRITE_EXTERNAL_STORAGE)
        val result = Result()
        WorkspaceDirectoryAccess(activity).pick(result)
        assertEquals("external_storage_permission", result.error)
        assertNull(shadowOf(activity).nextStartedActivityForResult)
    }
}
