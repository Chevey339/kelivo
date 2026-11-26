import Foundation

@main
struct BackupExportDestinationTest {
  static func main() throws {
    let files = FileManager.default
    let root = files.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? files.removeItem(at: root) }
    let container = root.appendingPathComponent("Kelivo")
    let documents = container.appendingPathComponent("Documents")
    let external = root.appendingPathComponent("Kelivo-backups")
    try files.createDirectory(at: documents, withIntermediateDirectories: true)
    try files.createDirectory(at: external, withIntermediateDirectories: true)
    let source = root.appendingPathComponent("backup.zip")
    let payload = Data("backup contents".utf8)
    try payload.write(to: source)

    let alias = external.appendingPathComponent("app-alias")
    try files.createSymbolicLink(at: alias, withDestinationURL: documents)
    for unsafe in [container, documents, alias] {
      do {
        try BackupExportDestination.copy(source: source, to: unsafe, container: container)
        fatalError("An app-owned destination must be rejected")
      } catch BackupExportDestination.ExportError.insideAppContainer {
        precondition(!files.fileExists(atPath: unsafe.appendingPathComponent("backup.zip").path))
      }
    }

    var written: [Int64] = []
    try BackupExportDestination.copy(source: source, to: external, container: container) { done, total in
      precondition(total == Int64(payload.count))
      written.append(done)
    }
    precondition(written.first == 0 && written.last == Int64(payload.count))
    // Exercise the streaming path even on an APFS test host where cloning succeeds.
    let large = root.appendingPathComponent("photos.zip")
    let bytes = Data(repeating: 0x5a, count: 2 * 1024 * 1024 + 11)
    try bytes.write(to: large)
    let copied = root.appendingPathComponent("streamed.zip")
    try Data().write(to: copied)
    let output = try FileHandle(forWritingTo: copied)
    var intermediate: [Int64] = []
    try BackupExportDestination.writeContents(of: large, to: output, total: Int64(bytes.count),
                                              checkCancelled: {}) { count, _ in intermediate.append(count) }
    try output.close()
    let streamed = try Data(contentsOf: copied)
    precondition(streamed == bytes && intermediate.contains(1024 * 1024))
    let cancelledFolder = root.appendingPathComponent("cancelled")
    try files.createDirectory(at: cancelledFolder, withIntermediateDirectories: false)
    let cancellation = Progress(totalUnitCount: 1)
    do {
      try BackupExportDestination.copy(source: source, to: cancelledFolder, container: container,
                                       cancellation: cancellation) { _, _ in cancellation.cancel() }
      fatalError("Cancelled copies must not publish")
    } catch let error as CocoaError {
      precondition(error.code == .userCancelled)
    }
    let leftovers = try files.contentsOfDirectory(atPath: cancelledFolder.path)
    precondition(leftovers.isEmpty)
    try cancelWhileWaitingForProvider(source: source, folder: cancelledFolder, container: container)
    let saved = external.appendingPathComponent("backup.zip")
    let savedContents = try Data(contentsOf: saved)
    precondition(savedContents == payload)
    // Never overwrite a previous backup, and keep the staged source intact.
    try Data("changed backup".utf8).write(to: source)
    do {
      try BackupExportDestination.copy(source: source, to: external, container: container)
      fatalError("An existing backup must not be replaced")
    } catch is CocoaError {}
    let preservedContents = try Data(contentsOf: saved)
    precondition(preservedContents == payload)
    precondition(files.fileExists(atPath: source.path))
    print("Backup export rejects app containers and symlinks, preserves existing backups, and copies to external folders")
  }

  static func cancelWhileWaitingForProvider(source: URL, folder: URL, container: URL) throws {
    let destination = folder.appendingPathComponent(source.lastPathComponent)
    let holding = DispatchSemaphore(value: 0)
    let release = DispatchSemaphore(value: 0)
    let released = DispatchSemaphore(value: 0)
    DispatchQueue.global().async {
      var error: NSError?
      NSFileCoordinator().coordinate(writingItemAt: destination, options: [], error: &error) { _ in
        holding.signal()
        release.wait()
      }
      precondition(error == nil)
      released.signal()
    }
    precondition(holding.wait(timeout: .now() + 5) == .success)
    defer {
      release.signal()
      precondition(released.wait(timeout: .now() + 5) == .success)
    }
    let started = DispatchSemaphore(value: 0)
    let finished = DispatchSemaphore(value: 0)
    let cancellation = Progress(totalUnitCount: 1)
    DispatchQueue.global().async {
      do {
        try BackupExportDestination.copy(source: source, to: folder, container: container,
                                         cancellation: cancellation) { _, _ in started.signal() }
        fatalError("A cancelled coordination must not publish")
      } catch {
        precondition((error as? CocoaError)?.code == .userCancelled)
      }
      finished.signal()
    }
    precondition(started.wait(timeout: .now() + 5) == .success)
    precondition(finished.wait(timeout: .now() + 0.2) == .timedOut)
    cancellation.cancel()
    precondition(finished.wait(timeout: .now() + 5) == .success)
    precondition(!FileManager.default.fileExists(atPath: destination.path))
  }
}
