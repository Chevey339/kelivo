import Foundation

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
  /// Validate before copying so a backup inside the app can never count as saved.
  static func copy(
    source: URL,
    to directory: URL,
    container: URL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
  ) throws {
    let destination = directory.appendingPathComponent(source.lastPathComponent)
    // Resolve the existing parent too: URL resolution can leave a symlink
    // untouched when its final (not-yet-created) child does not exist.
    guard !isInsideAppContainer(directory, container: container),
          !isInsideAppContainer(destination, container: container) else {
      throw ExportError.insideAppContainer
    }

    var coordinationError: NSError?
    var copyError: Error?
    NSFileCoordinator().coordinate(writingItemAt: destination, options: [], error: &coordinationError) { url in
      do {
        guard !isInsideAppContainer(url.deletingLastPathComponent(), container: container),
              !isInsideAppContainer(url, container: container) else {
          throw ExportError.insideAppContainer
        }
        // copyItem refuses to overwrite an existing backup with the same name.
        try FileManager.default.copyItem(at: source, to: url)
      } catch {
        copyError = error
      }
    }
    if let error = copyError ?? coordinationError { throw error }
  }
}
