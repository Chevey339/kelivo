//
//  RootfsInstaller.swift
//  Runner
//
//  Extracts the bundled Alpine fakefs rootfs zip into Application Support.
//  ZIP reader adapted from Cuplivo/OpenMinis RootfsManager (GPL-3.0, see
//  ios/sandbox/NOTICE).
//

import Compression
import Foundation

enum RootfsInstallerError: Error, LocalizedError {
  case bundleResourceMissing
  case archiveOpenFailed
  case cancelled
  case unsafeEntryPath(String)
  case extractionFailed(String)
  case needsRestart

  var errorDescription: String? {
    switch self {
    case .bundleResourceMissing: return "alpine-rootfs.zip not found in bundle"
    case .archiveOpenFailed: return "Failed to open rootfs zip archive"
    case .cancelled: return "Rootfs installation cancelled"
    case .unsafeEntryPath(let p): return "Unsafe zip entry path: \(p)"
    case .extractionFailed(let m): return m
    case .needsRestart: return "Rootfs was reset or replaced while the kernel was booted; restart the app"
    }
  }
}

enum RootfsInstallPhase: String {
  case extracting
  case finalizing
}

final class RootfsInstaller {
  static let shared = RootfsInstaller()
  static let resourceName = "alpine-rootfs"
  static let bundledVersionKey = "KelivoBundledRootfsVersion"
  static let fallbackBundledVersion = "alpine-3.21.3-r4"

  /// Set when reset/replace happens after `become_first_process`. Never cleared
  /// in-process — the kernel cannot remount a new fakefs tree.
  private(set) var needsRestart = false

  private init() {}

  var rootfsDir: URL {
    let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    return support.appendingPathComponent("environment/alpine-rootfs", isDirectory: true)
  }

  var versionFile: URL {
    rootfsDir.appendingPathComponent(".version")
  }

  var installedVersion: String? {
    guard let raw = try? String(contentsOf: versionFile, encoding: .utf8) else { return nil }
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  var bundledVersion: String {
    // Prefer the VERSION resource written by prepare_alpine_rootfs.sh so a
    // revision bump re-installs even if Info.plist is stale.
    if let url = Bundle.main.url(forResource: "VERSION", withExtension: nil),
      let raw = try? String(contentsOf: url, encoding: .utf8)
    {
      let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
      if !trimmed.isEmpty { return trimmed }
    }
    if let zipURL = Bundle.main.url(forResource: Self.resourceName, withExtension: "zip"),
      let archive = WorkspaceZipArchive(url: zipURL)
    {
      for name in ["VERSION", ".version", "alpine-rootfs/VERSION", "alpine-rootfs/.version"] {
        if let entry = archive.entries.first(where: { $0.path == name || $0.path.hasSuffix("/\(name)") }),
          let data = try? archive.extractData(for: entry),
          let text = String(data: data, encoding: .utf8)
        {
          let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
          if !trimmed.isEmpty { return trimmed }
        }
      }
    }
    if let plist = Bundle.main.object(forInfoDictionaryKey: Self.bundledVersionKey) as? String {
      let trimmed = plist.trimmingCharacters(in: .whitespacesAndNewlines)
      if !trimmed.isEmpty { return trimmed }
    }
    return Self.fallbackBundledVersion
  }

  var isInstalled: Bool {
    do {
      try verifyRootfs(at: rootfsDir)
      return true
    } catch {
      return false
    }
  }

  /// Extract the bundled zip. `progress` is called on the caller's thread.
  func install(
    isCancelled: () -> Bool = { false },
    progress: ((RootfsInstallPhase, Double) -> Void)? = nil
  ) throws {
    if KelivoISHKernel.shared().isBooted {
      if let existing = installedVersion, existing != bundledVersion {
        needsRestart = true
        throw RootfsInstallerError.needsRestart
      }
      if isInstalled { return }
      needsRestart = true
      throw RootfsInstallerError.needsRestart
    }

    guard let zipURL = Bundle.main.url(forResource: Self.resourceName, withExtension: "zip") else {
      throw RootfsInstallerError.bundleResourceMissing
    }
    guard let archive = WorkspaceZipArchive(url: zipURL) else {
      throw RootfsInstallerError.archiveOpenFailed
    }

    let fm = FileManager.default
    let destDir = rootfsDir
    let parent = destDir.deletingLastPathComponent()
    try fm.createDirectory(at: parent, withIntermediateDirectories: true)
    try recoverInterruptedInstall(to: destDir, fileManager: fm)

    let staging = parent.appendingPathComponent(
      "\(destDir.lastPathComponent).staging-\(UUID().uuidString)"
    )
    do {
      if isCancelled() { throw RootfsInstallerError.cancelled }
      try fm.createDirectory(at: staging, withIntermediateDirectories: true)
      try extract(archive: archive, into: staging, isCancelled: isCancelled, progress: progress)
      progress?(.finalizing, 0)
      try Self.writeVersion(bundledVersion, to: staging)
      try commitStagedRootfs(staging, to: destDir, isCancelled: isCancelled, fileManager: fm)
      cleanupArtifactsIfDestinationUsable(at: destDir, fileManager: fm)
      progress?(.finalizing, 1)
    } catch {
      removeArtifact(staging, fileManager: fm)
      throw error
    }
  }

  func reset() throws -> Bool {
    let booted = KelivoISHKernel.shared().isBooted
    try discardRootfs(at: rootfsDir)
    if booted {
      needsRestart = true
    }
    return booted
  }

  // MARK: - Extract / verify

  private func extract(
    archive: WorkspaceZipArchive,
    into destDir: URL,
    isCancelled: () -> Bool,
    progress: ((RootfsInstallPhase, Double) -> Void)?
  ) throws {
    let fm = FileManager.default
    let destBase = destDir.standardizedFileURL.path
    let total = max(archive.entries.count, 1)
    for (index, entry) in archive.entries.enumerated() {
      if isCancelled() { throw RootfsInstallerError.cancelled }
      var relative = entry.path
      if relative.hasPrefix("alpine-rootfs/") {
        relative = String(relative.dropFirst("alpine-rootfs/".count))
      }
      if relative.hasPrefix("/") { relative = String(relative.dropFirst()) }
      guard !relative.isEmpty else { continue }

      let entryURL = destDir.appendingPathComponent(relative).standardizedFileURL
      guard entryURL.path == destBase || entryURL.path.hasPrefix(destBase + "/") else {
        throw RootfsInstallerError.unsafeEntryPath(entry.path)
      }
      if entry.isDirectory {
        try fm.createDirectory(at: entryURL, withIntermediateDirectories: true)
      } else {
        let parent = entryURL.deletingLastPathComponent()
        if !fm.fileExists(atPath: parent.path) {
          try fm.createDirectory(at: parent, withIntermediateDirectories: true)
        }
        guard let data = try archive.extractData(for: entry) else {
          throw RootfsInstallerError.extractionFailed("Failed to extract \(entry.path)")
        }
        try data.write(to: entryURL)
      }
      progress?(.extracting, Double(index + 1) / Double(total))
    }
  }

  static func writeVersion(_ version: String, to dir: URL) throws {
    try version.write(to: dir.appendingPathComponent(".version"), atomically: true, encoding: .utf8)
  }

  static func verifyRootfs(at dir: URL) throws {
    for probe in ["meta.db", "data/bin/sh"] {
      let url = dir.appendingPathComponent(probe)
      let values = try? url.resourceValues(forKeys: [.isRegularFileKey])
      guard values?.isRegularFile == true else {
        throw RootfsInstallerError.extractionFailed("rootfs missing regular file \(probe)")
      }
    }
  }

  private func verifyRootfs(at dir: URL) throws {
    try Self.verifyRootfs(at: dir)
  }

  private static func isUsableRootfs(at url: URL) -> Bool {
    do {
      try verifyRootfs(at: url)
      return true
    } catch {
      return false
    }
  }

  static func commitStagedRootfs(
    _ staging: URL,
    to destDir: URL,
    isCancelled: () -> Bool = { false },
    fileManager fm: FileManager = .default
  ) throws {
    try verifyRootfs(at: staging)
    if isCancelled() { throw RootfsInstallerError.cancelled }
    guard fm.fileExists(atPath: destDir.path) else {
      try fm.moveItem(at: staging, to: destDir)
      return
    }
    let backupName = "\(destDir.lastPathComponent).backup-\(UUID().uuidString)"
    let backup = destDir.deletingLastPathComponent().appendingPathComponent(backupName)
    do {
      _ = try fm.replaceItemAt(
        destDir,
        withItemAt: staging,
        backupItemName: backupName,
        options: [.usingNewMetadataOnly, .withoutDeletingBackupItem]
      )
    } catch {
      throw error
    }
    removeArtifact(backup, fileManager: fm)
  }

  static func recoverInterruptedInstall(
    to destDir: URL,
    fileManager fm: FileManager = .default
  ) throws {
    let parent = destDir.deletingLastPathComponent()
    let candidates: [URL]
    do {
      candidates = try fm.contentsOfDirectory(at: parent, includingPropertiesForKeys: [.isRegularFileKey])
    } catch {
      throw RootfsInstallerError.extractionFailed(
        "Failed to inspect interrupted rootfs installs: \(error.localizedDescription)"
      )
    }
    if isUsableRootfs(at: destDir) {
      cleanupArtifacts(candidates, for: destDir, fileManager: fm)
      return
    }
    let backupPrefix = "\(destDir.lastPathComponent).backup-"
    let usableBackups = candidates.filter {
      $0.lastPathComponent.hasPrefix(backupPrefix) && isUsableRootfs(at: $0)
    }
    guard usableBackups.count <= 1 else {
      throw RootfsInstallerError.extractionFailed("Multiple usable rootfs backups found")
    }
    guard let backup = usableBackups.first else { return }
    let displaced = parent.appendingPathComponent(
      "\(destDir.lastPathComponent).staging-recovery-\(UUID().uuidString)"
    )
    let hadDestination = fm.fileExists(atPath: destDir.path)
    if hadDestination { try fm.moveItem(at: destDir, to: displaced) }
    do {
      try fm.moveItem(at: backup, to: destDir)
    } catch {
      if hadDestination { try? fm.moveItem(at: displaced, to: destDir) }
      throw RootfsInstallerError.extractionFailed(
        "Failed to restore rootfs backup: \(error.localizedDescription)"
      )
    }
    cleanupArtifactsIfDestinationUsable(at: destDir, fileManager: fm)
  }

  private func discardRootfs(at url: URL) throws {
    let fm = FileManager.default
    guard fm.fileExists(atPath: url.path) else { return }
    do {
      try fm.removeItem(at: url)
      return
    } catch {
      NSLog("RootfsInstaller: delete failed (\(error)); moving aside")
    }
    let parent = url.deletingLastPathComponent()
    let aside = parent.appendingPathComponent(".alpine-rootfs-broken-\(Int(Date().timeIntervalSince1970))")
    try fm.moveItem(at: url, to: aside)
    for name in (try? fm.contentsOfDirectory(atPath: parent.path)) ?? [] where name.hasPrefix(".alpine-rootfs-broken-") {
      try? fm.removeItem(at: parent.appendingPathComponent(name))
    }
  }

  private func recoverInterruptedInstall(to destDir: URL, fileManager fm: FileManager) throws {
    try Self.recoverInterruptedInstall(to: destDir, fileManager: fm)
  }

  private func commitStagedRootfs(
    _ staging: URL,
    to destDir: URL,
    isCancelled: () -> Bool,
    fileManager fm: FileManager
  ) throws {
    try Self.commitStagedRootfs(staging, to: destDir, isCancelled: isCancelled, fileManager: fm)
  }

  private func cleanupArtifactsIfDestinationUsable(at destDir: URL, fileManager fm: FileManager) {
    Self.cleanupArtifactsIfDestinationUsable(at: destDir, fileManager: fm)
  }

  private static func cleanupArtifactsIfDestinationUsable(at destDir: URL, fileManager fm: FileManager) {
    guard isUsableRootfs(at: destDir) else { return }
    do {
      let candidates = try fm.contentsOfDirectory(
        at: destDir.deletingLastPathComponent(),
        includingPropertiesForKeys: nil
      )
      cleanupArtifacts(candidates, for: destDir, fileManager: fm)
    } catch {
      NSLog("RootfsInstaller: artifact scan failed: \(error)")
    }
  }

  private static func cleanupArtifacts(_ candidates: [URL], for destDir: URL, fileManager fm: FileManager) {
    let stagingPrefix = "\(destDir.lastPathComponent).staging-"
    let backupPrefix = "\(destDir.lastPathComponent).backup-"
    for url in candidates where url.standardizedFileURL != destDir.standardizedFileURL {
      let name = url.lastPathComponent
      if name.hasPrefix(stagingPrefix) || name.hasPrefix(backupPrefix) {
        removeArtifact(url, fileManager: fm)
      }
    }
  }

  private static func removeArtifact(_ url: URL, fileManager fm: FileManager) {
    guard fm.fileExists(atPath: url.path) else { return }
    try? fm.removeItem(at: url)
  }

  private func removeArtifact(_ url: URL, fileManager fm: FileManager) {
    Self.removeArtifact(url, fileManager: fm)
  }
}

// MARK: - Minimal ZIP reader

final class WorkspaceZipArchive {
  struct Entry {
    let path: String
    let isDirectory: Bool
    let compressedSize: Int
    let uncompressedSize: Int
    let compressionMethod: UInt16
    let localHeaderOffset: UInt64
  }

  private let fileHandle: FileHandle
  private(set) var entries: [Entry] = []

  init?(url: URL) {
    guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
    self.fileHandle = handle
    do {
      try parseZipFile()
    } catch {
      NSLog("RootfsInstaller: zip parse error: \(error)")
      try? handle.close()
      return nil
    }
  }

  deinit {
    try? fileHandle.close()
  }

  private func readUInt16(_ data: Data, at offset: Int) -> UInt16 {
    UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
  }

  private func readUInt32(_ data: Data, at offset: Int) -> UInt32 {
    UInt32(data[offset])
      | (UInt32(data[offset + 1]) << 8)
      | (UInt32(data[offset + 2]) << 16)
      | (UInt32(data[offset + 3]) << 24)
  }

  private func parseZipFile() throws {
    fileHandle.seekToEndOfFile()
    let fileSize = fileHandle.offsetInFile
    let searchSize: UInt64 = Swift.min(fileSize, 65557)
    fileHandle.seek(toFileOffset: fileSize - searchSize)
    let searchData = fileHandle.readDataToEndOfFile()
    guard let eocdOffset = findEOCD(in: searchData) else {
      throw RootfsInstallerError.extractionFailed("Invalid ZIP (EOCD not found)")
    }
    let eocdStart = Int(fileSize - searchSize) + eocdOffset
    fileHandle.seek(toFileOffset: UInt64(eocdStart))
    let eocdData = fileHandle.readData(ofLength: 22)
    guard eocdData.count == 22 else {
      throw RootfsInstallerError.extractionFailed("Invalid ZIP (EOCD truncated)")
    }
    let centralDirOffset = readUInt32(eocdData, at: 16)
    let entryCount = readUInt16(eocdData, at: 10)
    fileHandle.seek(toFileOffset: UInt64(centralDirOffset))
    for _ in 0..<entryCount {
      guard let entry = readCentralDirectoryEntry() else { break }
      entries.append(entry)
    }
  }

  private func findEOCD(in data: Data) -> Int? {
    let signature: [UInt8] = [0x50, 0x4B, 0x05, 0x06]
    guard data.count >= 22 else { return nil }
    for i in stride(from: data.count - 22, through: 0, by: -1) {
      if data[i] == signature[0] && data[i + 1] == signature[1]
        && data[i + 2] == signature[2] && data[i + 3] == signature[3]
      {
        return i
      }
    }
    return nil
  }

  private func readCentralDirectoryEntry() -> Entry? {
    let headerData = fileHandle.readData(ofLength: 46)
    guard headerData.count == 46 else { return nil }
    guard readUInt32(headerData, at: 0) == 0x02014B50 else { return nil }
    let compressionMethod = readUInt16(headerData, at: 10)
    let compressedSize = readUInt32(headerData, at: 20)
    let uncompressedSize = readUInt32(headerData, at: 24)
    let fileNameLength = readUInt16(headerData, at: 28)
    let extraLength = readUInt16(headerData, at: 30)
    let commentLength = readUInt16(headerData, at: 32)
    let localHeaderOffset = readUInt32(headerData, at: 42)
    let fileNameData = fileHandle.readData(ofLength: Int(fileNameLength))
    let fileName = String(data: fileNameData, encoding: .utf8) ?? ""
    fileHandle.seek(toFileOffset: fileHandle.offsetInFile + UInt64(extraLength + commentLength))
    return Entry(
      path: fileName,
      isDirectory: fileName.hasSuffix("/"),
      compressedSize: Int(compressedSize),
      uncompressedSize: Int(uncompressedSize),
      compressionMethod: compressionMethod,
      localHeaderOffset: UInt64(localHeaderOffset)
    )
  }

  func extractData(for entry: Entry) throws -> Data? {
    fileHandle.seek(toFileOffset: entry.localHeaderOffset)
    let localHeader = fileHandle.readData(ofLength: 30)
    guard localHeader.count == 30 else { return nil }
    let fileNameLen = readUInt16(localHeader, at: 26)
    let extraLen = readUInt16(localHeader, at: 28)
    fileHandle.seek(toFileOffset: fileHandle.offsetInFile + UInt64(fileNameLen + extraLen))
    let compressedData = fileHandle.readData(ofLength: entry.compressedSize)
    if entry.compressionMethod == 0 {
      return compressedData
    } else if entry.compressionMethod == 8 {
      return decompressDeflate(compressedData, expectedSize: entry.uncompressedSize)
    }
    return nil
  }

  private func decompressDeflate(_ data: Data, expectedSize: Int) -> Data? {
    guard expectedSize > 0 else { return Data() }
    var decompressed = Data(count: expectedSize)
    let result = decompressed.withUnsafeMutableBytes { destPtr -> Int in
      data.withUnsafeBytes { srcPtr -> Int in
        compression_decode_buffer(
          destPtr.baseAddress!.assumingMemoryBound(to: UInt8.self),
          expectedSize,
          srcPtr.baseAddress!.assumingMemoryBound(to: UInt8.self),
          data.count,
          nil,
          COMPRESSION_ZLIB
        )
      }
    }
    if result > 0 {
      decompressed.count = result
      return decompressed
    }
    return nil
  }
}
