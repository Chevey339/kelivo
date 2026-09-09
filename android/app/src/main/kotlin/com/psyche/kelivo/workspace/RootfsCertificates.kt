package com.psyche.kelivo.workspace

import java.io.File
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.security.KeyStore
import java.util.Base64
import javax.net.ssl.TrustManagerFactory
import javax.net.ssl.X509TrustManager

/** Bootstrap HTTPS in Ubuntu Base before ca-certificates can be installed. */
object RootfsCertificates {
    @Synchronized
    fun ensureInstalled(rootfsDir: File) {
        val root = rootfsDir.canonicalFile.toPath()
        val bundle = File(rootfsDir, "etc/ssl/certs/ca-certificates.crt").canonicalFile
        require(bundle.toPath().startsWith(root)) { "certificate bundle escapes rootfs" }
        if (bundle.isFile && bundle.length() > 0L) return

        val factory = TrustManagerFactory.getInstance(TrustManagerFactory.getDefaultAlgorithm())
        factory.init(null as KeyStore?)
        val certificates = factory.trustManagers.filterIsInstance<X509TrustManager>()
            .flatMap { it.acceptedIssuers.toList() }
        check(certificates.isNotEmpty()) { "system trust store has no CA certificates" }
        val encoder = Base64.getMimeEncoder(64, byteArrayOf(10))
        val pem = certificates.joinToString("") {
            "-----BEGIN CERTIFICATE-----\n" + encoder.encodeToString(it.encoded) +
                "\n-----END CERTIFICATE-----\n"
        }
        bundle.parentFile!!.mkdirs()
        val temporary = Files.createTempFile(bundle.parentFile!!.toPath(), ".kelivo-ca-", ".tmp")
        try {
            temporary.toFile().writeText(pem, Charsets.US_ASCII)
            check(temporary.toFile().setReadable(true, false)) { "cannot make CA bundle readable" }
            Files.move(temporary, bundle.toPath(), StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING)
        } finally {
            Files.deleteIfExists(temporary)
        }
    }
}
