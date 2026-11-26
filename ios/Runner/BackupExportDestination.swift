import Foundation
import Darwin

enum BackupExportDestination {
  enum ExportError: Error {
    case insideAppContainer
  }

  static func isInsideAppContainer(
    _ url: URL,
    container: URL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
  ) -> Bool {
    let root = container.resolvingSymlinksInPath().standardizedFileURL.pathComponents
    let destination = url.resolvingSymlinksInPath().standardizedFileURL.pathComponents
    return destination.starts(with: root)
  }

  /// Call off the main thread while holding the selected folder's security scope.
  static func copy(
    source: URL,
    to directory: URL,
    container: URL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true),
    cancellation: Progress? = nil,
    onProgress: ((Int64, Int64) -> Void)? = nil
  ) throws {
    let destination = directory.appendingPathComponent(source.lastPathComponent)
    func validate(_ url: URL) throws {
      // Resolve the existing parent too when the final child doesn't yet exist.
      guard !isInsideAppContainer(url.deletingLastPathComponent(), container: container),
            !isInsideAppContainer(url, container: container) else { throw ExportError.insideAppContainer }
    }
    try validate(destination)
    guard let size = try FileManager.default.attributesOfItem(atPath: source.path)[.size] as? NSNumber else {
      throw CocoaError(.fileReadUnknown)
    }
    let total = size.int64Value
    let coordinator = NSFileCoordinator()
    cancellation?.cancellationHandler = { coordinator.cancel() }
    defer { cancellation?.cancellationHandler = nil }
    onProgress?(0, total)
    if cancellation?.isCancelled == true { throw CocoaError(.userCancelled) }
    var coordinationError: NSError?
    var copyError: Error?
    coordinator.coordinate(writingItemAt: destination, options: [], error: &coordinationError) { url in
      do {
        try validate(url)
        try publish(source, to: url, total: total, cancellation: cancellation, onProgress: onProgress)
      } catch {
        copyError = error
      }
    }
    if let error = copyError ?? coordinationError { throw error }
  }

  private static func publish(_ source: URL, to destination: URL, total: Int64, cancellation: Progress?,
                              onProgress: ((Int64, Int64) -> Void)?) throws {
    let files = FileManager.default
    guard !files.fileExists(atPath: destination.path) else { throw CocoaError(.fileWriteFileExists) }
    func checkCancelled() throws {
      if cancellation?.isCancelled == true { throw CocoaError(.userCancelled) }
    }
    try checkCancelled()
    let partial = destination.deletingLastPathComponent().appendingPathComponent(".kelivo-\(UUID().uuidString).partial")
    var output: FileHandle?
    // APFS can clone even a multi-GB archive without copying its bytes.
    if clonefile(source.path, partial.path, 0) != 0 {
      let fd = open(partial.path, O_WRONLY | O_CREAT | O_EXCL, S_IRUSR | S_IWUSR)
      guard fd >= 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
      output = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
    }
    defer {
      try? output?.close()
      try? files.removeItem(at: partial)
    }
    if let handle = output {
      try writeContents(of: source, to: handle, total: total, checkCancelled: checkCancelled, onProgress: onProgress)
    }
    try checkCancelled()
    onProgress?(total, total)
    try output?.synchronize()
    try output?.close()
    output = nil
    try files.moveItem(at: partial, to: destination)
  }

  static func writeContents(of source: URL, to output: FileHandle, total: Int64,
                            checkCancelled: () throws -> Void, onProgress: ((Int64, Int64) -> Void)?) throws {
    let input = try FileHandle(forReadingFrom: source)
    defer { try? input.close() }
    var written: Int64 = 0
    var last = ProcessInfo.processInfo.systemUptime
    while true {
      try checkCancelled()
      guard let data = try input.read(upToCount: 1024 * 1024), !data.isEmpty else { break }
      try output.write(contentsOf: data)
      written += Int64(data.count)
      let now = ProcessInfo.processInfo.systemUptime
      if written < total && (written == Int64(data.count) || now - last >= 0.1) {
        onProgress?(written, total)
        last = now
      }
    }
    guard written == total else { throw CocoaError(.fileReadCorruptFile) }
  }
}
