import Flutter
import UIKit
import UniformTypeIdentifiers

/// Owns security scopes for linked workspaces. All filesystem/bookmark work is
/// serialized off the main thread; only the document picker runs on the UI thread.
final class WorkspaceDirectoryAccess: NSObject, UIDocumentPickerDelegate {
  private let queue = DispatchQueue(label: "psyche.kelivo.workspace.directories", qos: .userInitiated)
  private var activeURLs: [String: URL] = [:]
  private var pickerResult: FlutterResult?
  private weak var presenter: UIViewController?

  init(presenter: UIViewController) {
    self.presenter = presenter
    super.init()
  }

  func pick(result: @escaping FlutterResult) {
    guard pickerResult == nil else {
      result(FlutterError(code: "busy", message: "A folder picker is already open", details: nil))
      return
    }
    guard var presenter = presenter, presenter.viewIfLoaded?.window != nil else {
      result(FlutterError(code: "external_folder_unavailable", message: "No active window", details: nil))
      return
    }
    while let presented = presenter.presentedViewController { presenter = presented }
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
    picker.allowsMultipleSelection = false
    picker.delegate = self
    pickerResult = result
    presenter.present(picker, animated: true)
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    let result = pickerResult
    pickerResult = nil
    result?(nil)
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let result = pickerResult else { return }
    pickerResult = nil
    guard let url = urls.first else {
      result(nil)
      return
    }
    perform(result) {
      guard url.startAccessingSecurityScopedResource() else { throw self.unavailable() }
      var retained = false
      defer { if !retained { url.stopAccessingSecurityScopedResource() } }
      let path = try self.directoryPath(url)
      let token = try self.bookmark(url)
      if self.activeURLs[token] == nil {
        self.activeURLs[token] = url
        retained = true
      }
      return ["path": path, "token": token]
    }
  }

  func resolve(token: String, result: @escaping FlutterResult) {
    perform(result) {
      guard let data = Data(base64Encoded: token) else { throw self.unavailable() }
      var stale = false
      let url = try URL(resolvingBookmarkData: data, options: [.withoutUI],
                        relativeTo: nil, bookmarkDataIsStale: &stale)
      guard url.startAccessingSecurityScopedResource() else { throw self.unavailable() }
      var retained = false
      defer { if !retained { url.stopAccessingSecurityScopedResource() } }
      let path = try self.directoryPath(url)
      let refreshedToken = stale ? try self.bookmark(url) : token
      // Start the renewed scope before dropping the old one. Re-resolving also
      // follows moves performed in Files while Kelivo remains running.
      self.activeURLs.updateValue(url, forKey: refreshedToken)?.stopAccessingSecurityScopedResource()
      retained = true
      return ["path": path, "token": refreshedToken]
    }
  }

  func release(token: String, result: @escaping FlutterResult) {
    perform(result) {
      self.activeURLs.removeValue(forKey: token)?.stopAccessingSecurityScopedResource()
      return nil
    }
  }

  private func bookmark(_ url: URL) throws -> String {
    try url.bookmarkData(options: [.minimalBookmark], includingResourceValuesForKeys: nil,
                         relativeTo: nil).base64EncodedString()
  }

  private func directoryPath(_ url: URL) throws -> String {
    var coordinationError: NSError?
    var accessError: Error?
    var path: String?
    NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { coordinated in
      do {
        let values = try coordinated.resourceValues(forKeys: [.isDirectoryKey])
        guard values.isDirectory == true else { throw self.unavailable() }
        // Verify directory enumeration, including File Provider availability,
        // before passing a host path to Dart or the iSH realfs bind.
        _ = try FileManager.default.contentsOfDirectory(atPath: coordinated.path)
        path = coordinated.resolvingSymlinksInPath().path
      } catch { accessError = error }
    }
    if let error = coordinationError { throw error }
    if let error = accessError { throw error }
    guard let path else { throw unavailable() }
    return path
  }

  private func unavailable() -> NSError {
    NSError(domain: "KelivoWorkspaceDirectory", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Folder access is unavailable; select the folder again"])
  }

  private func perform(_ result: @escaping FlutterResult, operation: @escaping () throws -> Any?) {
    queue.async {
      do {
        let value = try operation()
        DispatchQueue.main.async { result(value) }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "external_folder_unavailable", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  deinit {
    for url in activeURLs.values { url.stopAccessingSecurityScopedResource() }
  }
}
