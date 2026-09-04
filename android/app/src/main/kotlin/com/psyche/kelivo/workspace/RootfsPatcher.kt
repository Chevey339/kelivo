package com.psyche.kelivo.workspace

import java.io.File
import java.nio.file.Files

object RootfsPatcher {
    private val WHITESPACE = Regex("\\s+")
    private val LOCAL_RESOLVERS = setOf("127.0.0.1", "127.0.0.53", "::1")

    fun patch(
        rootfsDir: File,
        dnsServers: List<String>,
        hostname: String,
        aptMirrorBaseUrl: String?,
        ubuntuCodename: String,
        arch: String,
        groupIds: List<Long> = readSupplementaryGids(),
    ) {
        val etc = File(rootfsDir, "etc")
        etc.mkdirs()
        writeResolvConf(etc, dnsServers)
        writeHosts(etc, hostname)
        File(etc, "hostname").writeText("${hostname.ifBlank { "localhost" }}\n")
        writeLocale(etc)
        ensureDirs(rootfsDir)
        injectAndroidGids(File(etc, "group"), groupIds)
        if (!aptMirrorBaseUrl.isNullOrBlank()) {
            rewriteAptSources(etc, aptMirrorBaseUrl, ubuntuCodename, arch)
        }
    }

    internal fun writeResolvConf(etc: File, dnsServers: List<String>) {
        val resolv = File(etc, "resolv.conf")
        val shouldWrite = when {
            Files.isSymbolicLink(resolv.toPath()) -> true
            !resolv.exists() -> true
            !resolv.isFile -> true
            else -> resolv.readText()
                .lineSequence()
                .filter { it.trimStart().startsWith("nameserver ") }
                .none { line ->
                    val server = line.trim().removePrefix("nameserver").trim()
                    server.isNotBlank() && server !in LOCAL_RESOLVERS
                }
        }
        if (!shouldWrite && dnsServers.isEmpty()) return
        if (resolv.exists() || Files.isSymbolicLink(resolv.toPath())) {
            resolv.delete()
        }
        val servers = dnsServers.map { it.trim() }.filter { it.isNotEmpty() }.distinct()
            .ifEmpty { listOf("1.1.1.1", "8.8.8.8") }
        resolv.writeText(
            buildString {
                servers.forEach { appendLine("nameserver $it") }
                appendLine("options edns0 trust-ad")
            },
        )
    }

    internal fun writeHosts(etc: File, hostname: String) {
        val hosts = File(etc, "hosts")
        val lines = if (hosts.isFile) hosts.readLines() else emptyList()
        val hasIpv4 = lines.any { line ->
            val parts = line.substringBefore('#').trim().split(WHITESPACE)
            parts.firstOrNull() == "127.0.0.1" && "localhost" in parts.drop(1)
        }
        val hasIpv6 = lines.any { line ->
            val parts = line.substringBefore('#').trim().split(WHITESPACE)
            parts.firstOrNull() == "::1" && "localhost" in parts.drop(1)
        }
        if (hasIpv4 && hasIpv6) return
        hosts.parentFile?.mkdirs()
        hosts.appendText(
            buildString {
                if (hosts.exists() && hosts.length() > 0 && !hosts.readText().endsWith('\n')) {
                    appendLine()
                }
                if (!hasIpv4) {
                    append("127.0.0.1 localhost")
                    if (hostname.isNotBlank() && hostname != "localhost") {
                        append(' ')
                        append(hostname)
                    }
                    appendLine()
                }
                if (!hasIpv6) {
                    appendLine("::1 localhost ip6-localhost ip6-loopback")
                }
            },
        )
    }

    internal fun writeLocale(etc: File) {
        val target = File(File(etc, "default").apply { mkdirs() }, "locale")
        val lines = if (target.isFile) target.readLines().toMutableList() else mutableListOf()
        if (lines.any { it.trim().startsWith("LANG=") }) return
        lines += "LANG=C.UTF-8"
        target.writeText(lines.joinToString(separator = "\n", postfix = "\n"))
    }

    internal fun injectAndroidGids(groupFile: File, groupIds: List<Long>) {
        if (!groupFile.exists()) {
            groupFile.writeText("root:x:0:\n")
        }
        val lines = groupFile.readLines()
        val existingIds = lines.mapNotNull { it.split(':').getOrNull(2)?.toLongOrNull() }.toSet()
        val existingNames = lines.mapNotNull { it.substringBefore(':').takeIf { name -> name.isNotBlank() } }.toSet()
        val additions = groupIds
            .filter { it > 0 && it !in existingIds }
            .distinct()
            .map { id ->
                val base = "android_gid_$id"
                val name = if (base in existingNames) "${base}_workspace" else base
                "$name:x:$id:"
            }
        if (additions.isEmpty()) return
        groupFile.appendText(
            buildString {
                if (groupFile.length() > 0 && !groupFile.readText().endsWith('\n')) {
                    appendLine()
                }
                additions.forEach { appendLine(it) }
            },
        )
    }

    internal fun rewriteUbuntuSources(
        mirrorBaseUrl: String,
        ubuntuCodename: String,
        arch: String,
    ): String {
        val uri = archiveUri(mirrorBaseUrl, arch)
        val suites = "$ubuntuCodename $ubuntuCodename-updates $ubuntuCodename-backports"
        return buildString {
            appendLine("Types: deb")
            appendLine("URIs: $uri")
            appendLine("Suites: $suites")
            appendLine("Components: main restricted universe multiverse")
            appendLine("Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg")
            appendLine()
            appendLine("Types: deb")
            appendLine("URIs: $uri")
            appendLine("Suites: $ubuntuCodename-security")
            appendLine("Components: main restricted universe multiverse")
            appendLine("Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg")
            appendLine()
        }
    }

    internal fun archiveUri(mirrorBaseUrl: String, arch: String): String {
        val base = mirrorBaseUrl.trim().trimEnd('/')
        val suite = if (arch == "amd64") "ubuntu" else "ubuntu-ports"
        return "$base/$suite/"
    }

    internal fun readSupplementaryGids(): List<Long> {
        val status = File("/proc/self/status")
        if (!status.isFile) return emptyList()
        val groups = status.readLines().firstOrNull { it.startsWith("Groups:") } ?: return emptyList()
        return groups.removePrefix("Groups:").trim().split(WHITESPACE).mapNotNull { it.toLongOrNull() }
    }

    private fun rewriteAptSources(
        etc: File,
        mirrorBaseUrl: String,
        ubuntuCodename: String,
        arch: String,
    ) {
        val sources = File(etc, "apt/sources.list.d/ubuntu.sources")
        sources.parentFile?.mkdirs()
        val backup = File(sources.parentFile, "ubuntu.sources.kelivo-bak")
        if (sources.isFile && !backup.exists()) {
            sources.copyTo(backup)
        }
        sources.writeText(rewriteUbuntuSources(mirrorBaseUrl, ubuntuCodename, arch))
    }

    private fun ensureDirs(rootfsDir: File) {
        val tmp = File(rootfsDir, "tmp").apply { mkdirs() }
        val varTmp = File(rootfsDir, "var/tmp").apply { mkdirs() }
        val root = File(rootfsDir, "root").apply { mkdirs() }
        chmod(tmp, 0b1_111_111_111) // 01777
        chmod(varTmp, 0b1_111_111_111)
        chmod(root, 0b111_000_000) // 0700
    }

    private fun chmod(file: File, mode: Int) {
        try {
            val os = Class.forName("android.system.Os")
            val method = os.getMethod("chmod", String::class.java, Int::class.javaPrimitiveType)
            method.invoke(null, file.absolutePath, mode)
            return
        } catch (_: Throwable) {
        }
        val ownerOnly = mode and 0b000_111_111 == 0
        file.setReadable(mode and 0b100_000_000 != 0, ownerOnly)
        file.setWritable(mode and 0b010_000_000 != 0, ownerOnly)
        file.setExecutable(mode and 0b001_000_000 != 0, ownerOnly)
    }
}
