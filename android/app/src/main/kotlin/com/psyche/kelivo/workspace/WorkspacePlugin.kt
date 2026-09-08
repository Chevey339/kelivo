package com.psyche.kelivo.workspace

import android.app.Activity
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.StatFs
import android.view.WindowManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

class WorkspacePlugin(private val activity: Activity) {
    companion object {
        const val CHANNEL_NAME = "app.workspace"
        const val EVENT_CHANNEL_NAME = "app.workspace/events"
    }

    private val executor = Executors.newCachedThreadPool()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val events = WorkspaceEvents()
    private val execRunner = ExecRunner(events)
    private val ptySessions = PtySessions(events)
    private val directories = WorkspaceDirectoryAccess(activity)
    private var externalMounts = emptyList<BindMount>()
    private var environmentBusy = false

    fun configure(messenger: BinaryMessenger) {
        EventChannel(messenger, EVENT_CHANNEL_NAME).setStreamHandler(events)
        MethodChannel(messenger, CHANNEL_NAME).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "probe" -> result.success(probe())
                    "setEnvironmentBusy" -> {
                        environmentBusy = asMap(call.arguments)["busy"] == true
                        if (environmentBusy) {
                            execRunner.cancelAll()
                            ptySessions.closeAll()
                        }
                        result.success(null)
                    }
                    "inspectRootfs" -> runAsync(result, "invalid_rootfs") {
                        val args = asMap(call.arguments)
                        RootfsInfo.inspect(File(requiredString(args, "rootfsDir")), requiredString(args, "arch"))
                    }
                    "setExternalMounts" -> {
                        val next = parseBinds(asMap(call.arguments)["mounts"])
                        validateExternalMounts(next)
                        if (next != externalMounts) {
                            execRunner.cancelAll()
                            ptySessions.closeAll()
                            externalMounts = next
                        }
                        result.success(null)
                    }
                    "hasDirectoryStorageAccess" -> result.success(directories.hasStorageAccess())
                    "requestDirectoryStorageAccess" -> directories.requestStorageAccess(result)
                    "pickDirectory" -> directories.pick(result)
                    "resolveDirectory" -> runAsync(result, "external_folder_unavailable") {
                        directories.resolve(requiredString(asMap(call.arguments), "token"))
                    }
                    "releaseDirectory" -> runAsync(result) {
                        directories.release(requiredString(asMap(call.arguments), "token"))
                        null
                    }
                    "exec" -> {
                        require(!environmentBusy) { "environment is being replaced" }
                        exec(asMap(call.arguments))
                        result.success(mapOf("started" to true))
                    }
                    "cancel" -> {
                        val runId = asMap(call.arguments)["runId"]?.toString().orEmpty()
                        result.success(runId.isNotEmpty() && execRunner.cancel(runId))
                    }
                    "ptyOpen" -> {
                        require(!environmentBusy) { "environment is being replaced" }
                        result.success(mapOf("pid" to ptyOpen(asMap(call.arguments))))
                    }
                    "ptyWrite" -> {
                        ptyWrite(asMap(call.arguments))
                        result.success(null)
                    }
                    "ptyResize" -> {
                        ptyResize(asMap(call.arguments))
                        result.success(null)
                    }
                    "ptyClose" -> {
                        val sessionId = asMap(call.arguments)["sessionId"]?.toString().orEmpty()
                        if (sessionId.isNotEmpty()) ptySessions.close(sessionId)
                        result.success(null)
                    }
                    "extractRootfs" -> runAsync(result) { extractRootfs(asMap(call.arguments)) }
                    "patchRootfs" -> runAsync(result) { patchRootfs(asMap(call.arguments)) }
                    "sha256File" -> runAsync(result) {
                        Sha256.file(asMap(call.arguments)["path"]?.toString().orEmpty())
                    }
                    "keepScreenOn" -> {
                        keepScreenOn(asMap(call.arguments)["enabled"] == true)
                        result.success(null)
                    }
                    "freeSpace" -> result.success(freeSpace(asMap(call.arguments)))
                    else -> result.notImplemented()
                }
            } catch (error: IllegalArgumentException) {
                result.error("invalid_args", error.message, null)
            } catch (error: Exception) {
                result.error("workspace", error.message, null)
            }
        }
    }

    fun dispose() {
        directories.dispose()
        execRunner.cancelAll()
        ptySessions.closeAll()
        executor.shutdownNow()
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean =
        directories.onActivityResult(requestCode, resultCode, data)

    fun onRequestPermissionsResult(requestCode: Int): Boolean =
        directories.onRequestPermissionsResult(requestCode)

    private fun probe(): Map<String, Any?> {
        val nativeLibDir = File(activity.applicationInfo.nativeLibraryDir)
        val proot = File(nativeLibDir, ProotCommand.EXEC_LIB)
        val loader = File(nativeLibDir, ProotCommand.LOADER_LIB)
        if (proot.isFile) proot.setExecutable(true, false)
        if (loader.isFile) loader.setExecutable(true, false)
        val supported = proot.isFile && proot.canExecute() && loader.isFile && loader.canExecute()
        val reason = when {
            supported -> null
            !proot.isFile -> "proot missing: ${proot.absolutePath}"
            !proot.canExecute() -> "proot not executable: ${proot.absolutePath}"
            !loader.isFile -> "loader missing: ${loader.absolutePath}"
            else -> "loader not executable: ${loader.absolutePath}"
        }
        return hashMapOf(
            "supported" to supported,
            "abi" to (Build.SUPPORTED_ABIS.firstOrNull() ?: ""),
            "prootPath" to proot.takeIf { it.isFile }?.absolutePath,
            "loaderPath" to loader.takeIf { it.isFile }?.absolutePath,
            "nativeLibDir" to nativeLibDir.absolutePath,
            "reason" to reason,
        )
    }

    private fun exec(args: Map<*, *>) {
        val runId = requiredString(args, "runId")
        execRunner.start(
            ExecRequest(
                runId = runId,
                nativeLibDir = File(activity.applicationInfo.nativeLibraryDir),
                rootfsDir = File(requiredString(args, "rootfsDir")),
                tmpDir = File(requiredString(args, "tmpDir")),
                binds = commandBinds(args),
                cwd = ProotCommand.validateGuestCwd(requiredString(args, "cwd")),
                command = requiredString(args, "command"),
                env = parseEnv(args["env"]),
                timeoutMs = number(args["timeoutMs"], 60_000L),
                prootArguments = parseStringList(args["prootArguments"]),
                shell = args["shell"]?.toString(),
            ),
        )
    }

    private fun ptyOpen(args: Map<*, *>): Int {
        return ptySessions.open(
            sessionId = requiredString(args, "sessionId"),
            nativeLibDir = File(activity.applicationInfo.nativeLibraryDir),
            rootfsDir = File(requiredString(args, "rootfsDir")),
            tmpDir = File(requiredString(args, "tmpDir")),
            binds = commandBinds(args),
            cwd = ProotCommand.validateGuestCwd(requiredString(args, "cwd")),
            env = parseEnv(args["env"]),
            cols = number(args["cols"], 80L).toInt(),
            rows = number(args["rows"], 24L).toInt(),
            prootArguments = parseStringList(args["prootArguments"]),
            shell = args["shell"]?.toString(),
        )
    }

    private fun ptyWrite(args: Map<*, *>) {
        val sessionId = requiredString(args, "sessionId")
        val data = args["data"] as? ByteArray ?: ByteArray(0)
        ptySessions.write(sessionId, data)
    }

    private fun ptyResize(args: Map<*, *>) {
        ptySessions.resize(
            sessionId = requiredString(args, "sessionId"),
            cols = number(args["cols"], 80L).toInt(),
            rows = number(args["rows"], 24L).toInt(),
        )
    }

    private fun extractRootfs(args: Map<*, *>): Map<String, Any> {
        val destDir = requiredString(args, "destDir")
        val format = requiredString(args, "format")
        var lastEmit = 0L
        RootfsExtractor.extract(
            archive = File(requiredString(args, "archivePath")),
            destDir = File(destDir),
            format = format,
        ) { entries, bytes, currentEntry ->
            val now = System.currentTimeMillis()
            if (now - lastEmit < 200L && currentEntry.isNotEmpty()) return@extract
            lastEmit = now
            events.emit(
                hashMapOf(
                    "type" to "extract",
                    "destDir" to destDir,
                    "entries" to entries,
                    "bytes" to bytes,
                    "currentEntry" to currentEntry,
                ),
            )
        }
        return mapOf("ok" to true)
    }

    private fun patchRootfs(args: Map<*, *>): Map<String, Any> {
        RootfsPatcher.patch(
            rootfsDir = File(requiredString(args, "rootfsDir")),
            dnsServers = parseStringList(args["dnsServers"]),
            hostname = args["hostname"]?.toString()?.trim().orEmpty().ifBlank { "localhost" },
            aptMirrorBaseUrl = args["aptMirrorBaseUrl"]?.toString()?.trim()?.takeIf { it.isNotEmpty() },
            ubuntuCodename = args["ubuntuCodename"]?.toString().orEmpty(),
            arch = requiredString(args, "arch"),
        )
        return mapOf("ok" to true)
    }

    /**
     * Disk pre-check for the Dart rootfs installer. Walks to the nearest
     * existing ancestor of [path] and reports space the app can still use.
     */
    private fun freeSpace(args: Map<*, *>): Map<String, Long> {
        val raw = requiredString(args, "path")
        var target = File(raw)
        while (!target.exists()) {
            target = target.parentFile
                ?: throw IllegalArgumentException("no existing ancestor for $raw")
        }
        val stat = StatFs(target.absolutePath)
        return mapOf(
            "freeBytes" to stat.availableBytes,
            "totalBytes" to stat.totalBytes,
        )
    }

    private fun keepScreenOn(enabled: Boolean) {
        val window = activity.window ?: return
        if (enabled) {
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
    }

    private fun runAsync(result: MethodChannel.Result, errorCode: String = "workspace", block: () -> Any?) {
        executor.execute {
            try {
                val value = block()
                mainHandler.post { result.success(value) }
            } catch (error: Exception) {
                mainHandler.post { result.error(errorCode, error.message, null) }
            }
        }
    }

    private fun asMap(value: Any?): Map<*, *> = value as? Map<*, *> ?: emptyMap<Any, Any>()

    private fun requiredString(args: Map<*, *>, key: String): String {
        val text = args[key]?.toString()?.trim().orEmpty()
        require(text.isNotEmpty()) { "missing $key" }
        return text
    }

    private fun number(value: Any?, fallback: Long): Long = when (value) {
        is Number -> value.toLong()
        is String -> value.toLongOrNull() ?: fallback
        else -> fallback
    }

    private fun parseEnv(raw: Any?): Map<String, String> {
        val map = raw as? Map<*, *> ?: return emptyMap()
        val out = LinkedHashMap<String, String>()
        for ((key, value) in map) {
            if (key == null || value == null) continue
            out[key.toString()] = value.toString()
        }
        return out
    }

    private fun parseStringList(raw: Any?): List<String> {
        val list = raw as? List<*> ?: return emptyList()
        return list.mapNotNull { it?.toString()?.trim()?.takeIf { item -> item.isNotEmpty() } }
    }

    private fun parseBinds(raw: Any?): List<BindMount> {
        val list = raw as? List<*> ?: return emptyList()
        return list.mapNotNull { item ->
            val map = item as? Map<*, *> ?: return@mapNotNull null
            val host = map["host"]?.toString().orEmpty()
            val guest = map["guest"]?.toString().orEmpty()
            if (host.isBlank() || guest.isBlank()) return@mapNotNull null
            BindMount(host, guest, map["readOnly"] == true)
        }
    }

    private fun commandBinds(args: Map<*, *>): List<BindMount> {
        val rootfs = File(requiredString(args, "rootfsDir"))
        val mountRoot = File(rootfs, "mounts")
        require(mountRoot.canonicalPath.startsWith(rootfs.canonicalPath + "/"))
        mountRoot.mkdirs()
        val names = externalMounts.map { it.guest.substringAfterLast('/') }.toSet()
        // Only remove empty placeholders left by renamed or detached mounts.
        mountRoot.listFiles()?.filter { it.name !in names && it.isDirectory && it.list()?.isEmpty() == true }?.forEach { it.delete() }
        for (mount in externalMounts) {
            val target = File(mountRoot, mount.guest.substringAfterLast('/'))
            require(target.canonicalFile.parentFile == mountRoot.canonicalFile)
            target.mkdirs()
        }
        MountWriteGuards.install(rootfs, externalMounts)
        return parseBinds(args["binds"]).filterNot {
            it.guest.startsWith("/mounts/")
        } + externalMounts
    }
}
