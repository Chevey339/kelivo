import Foundation

/// Keep persistent app data out of system backups. Users transfer data with
/// Kelivo's exported backup files; changing these attributes never moves data.
enum AppBackupPolicy {
  static func apply(in container: URL) throws {
    var firstError: Error?
    // Library includes the private database, installation history, preferences
    // and WebKit data. Documents includes public files and retained old copies.
    // Exclude the roots so replacing a database or restoring a child directory
    // cannot drop the exclusion inherited from its parent.
    for name in ["Documents", "Library"] {
      let directory = container.appendingPathComponent(name, isDirectory: true)
      do {
        let manager = FileManager.default
        // Never recreate a temporarily missing root just to set an attribute:
        // that could race the system restoring the original directory.
        let attributes = try manager.attributesOfItem(atPath: directory.path)
        guard attributes[.type] as? FileAttributeType == .typeDirectory else {
          throw CocoaError(.fileWriteInvalidFileName)
        }
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var target = directory
        try target.setResourceValues(values)
        let applied = try URL(fileURLWithPath: directory.path)
          .resourceValues(forKeys: [.isExcludedFromBackupKey])
        guard applied.isExcludedFromBackup == true else {
          throw CocoaError(.fileWriteUnknown)
        }
      } catch {
        // Still protect the other root if one directory is temporarily blocked.
        if firstError == nil { firstError = error }
      }
    }
    if let firstError { throw firstError }
  }
}
