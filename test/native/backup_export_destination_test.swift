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

    try BackupExportDestination.copy(source: source, to: external, container: container)
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
}
