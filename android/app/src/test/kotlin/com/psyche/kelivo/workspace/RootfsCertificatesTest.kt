package com.psyche.kelivo.workspace

import java.io.File
import java.nio.file.Files
import java.security.cert.CertificateFactory
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class RootfsCertificatesTest {
    @get:Rule
    val tmp = TemporaryFolder()

    @Test
    fun missingBundleIsBootstrappedWithParseableSystemCertificates() {
        val root = tmp.newFolder("rootfs")
        RootfsCertificates.ensureInstalled(root)
        val bundle = File(root, "etc/ssl/certs/ca-certificates.crt")
        val certificates = bundle.inputStream().use {
            CertificateFactory.getInstance("X.509").generateCertificates(it)
        }
        assertTrue(certificates.isNotEmpty())
        assertTrue(bundle.canRead())
        assertEquals(listOf("ca-certificates.crt"), bundle.parentFile!!.list()!!.toList())
    }

    @Test
    fun existingGuestBundleIsPreserved() {
        val root = tmp.newFolder("rootfs")
        val bundle = File(root, "etc/ssl/certs/ca-certificates.crt")
        bundle.parentFile!!.mkdirs()
        bundle.writeText("guest-managed certificate bundle")
        RootfsCertificates.ensureInstalled(root)
        assertEquals("guest-managed certificate bundle", bundle.readText())
    }

    @Test(expected = IllegalArgumentException::class)
    fun symlinkCannotWriteOutsideRootfs() {
        val root = tmp.newFolder("rootfs")
        val outside = tmp.newFolder("outside")
        Files.createSymbolicLink(File(root, "etc").toPath(), outside.toPath())
        RootfsCertificates.ensureInstalled(root)
    }
}
