package com.psyche.kelivo.workspace

import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteException
import android.util.Log
import org.json.JSONException
import org.json.JSONObject
import java.io.File
import java.io.IOException

/** Read the same workspace registry as ExtensionEntityStore, without a Flutter engine. */
internal class WorkspaceDocumentsStore(private val appData: File) {
    fun list(): List<WorkspaceDocumentRoot> {
        val database = File(appData, "kelivo.db")
        if (!database.isFile) return emptyList()
        try {
            // Never create, migrate, or repair the live database from this provider.
            // In particular, Android's default corruption handler deletes files.
            SQLiteDatabase.openDatabase(
                database.path,
                null,
                SQLiteDatabase.OPEN_READONLY or SQLiteDatabase.NO_LOCALIZED_COLLATORS,
            ) { throw SQLiteException("Workspace database unavailable") }.use { db ->
                db.rawQuery(
                    "SELECT id, payload FROM extension_entity_rows WHERE kind = ? ORDER BY sort_order, id",
                    arrayOf("workspace"),
                ).use { cursor ->
                    val result = mutableListOf<WorkspaceDocumentRoot>()
                    while (cursor.moveToNext()) {
                        val id = cursor.getString(0)
                        if (!WorkspaceDocumentPaths.validId(id)) continue
                        try {
                            val payload = JSONObject(cursor.getString(1))
                            // Linked folders are a desktop feature. Their restored
                            // host paths must not become Android file grants.
                            if (payload.optString("kind", "managed") != "managed") continue
                            if (payload.optString("id") != id) continue
                            result += WorkspaceDocumentRoot(
                                id,
                                payload.optString("name").ifBlank { id },
                                WorkspaceDocumentPaths.managedDirectory(appData, id),
                            )
                        } catch (_: JSONException) {
                            // A malformed row must not hide unrelated workspaces.
                        } catch (_: IOException) {
                            // An unavailable or redirected workspace is not shared.
                        }
                    }
                    return result
                }
            }
        } catch (error: SQLiteException) {
            Log.w("WorkspaceDocuments", "Workspace registry unavailable", error)
            return emptyList()
        }
    }
}
