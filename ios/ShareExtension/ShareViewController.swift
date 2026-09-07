import Social
import UIKit
import UniformTypeIdentifiers

final class ShareViewController: SLComposeServiceViewController {
  private var saving = false
  private var importTask: Task<Void, Never>?
  private var copyControl = ShareCopyControl()
  private var statusDetail = ""

  override func configurationItems() -> [Any]! {
    guard saving else { return [] }
    let item = SLComposeSheetConfigurationItem()!
    item.title = label("importing")
    item.value = statusDetail
    return [item]
  }

  private func report(_ bytes: Int, total: Int?, index: Int) {
    DispatchQueue.main.async {
      let size = ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
      let percent = total.flatMap { $0 > 0 ? " · \(min(100, bytes * 100 / $0))%" : nil } ?? ""
      self.statusDetail = "\(index + 1) · \(size)\(percent)"
      self.reloadConfigurationItems()
    }
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    navigationController?.navigationBar.topItem?.rightBarButtonItem?.title = label("saveDraft")
  }

  override func isContentValid() -> Bool { !saving }

  override func didSelectCancel() {
    copyControl.cancel()
    importTask?.cancel()
    super.didSelectCancel()
  }

  override func didSelectPost() {
    guard !saving else { return }
    saving = true
    copyControl = ShareCopyControl()
    validateContent()
    let composeText = contentText ?? ""
    let items = extensionContext?.inputItems.compactMap { $0 as? NSExtensionItem } ?? []
    let providers = items.flatMap { $0.attachments ?? [] }
    importTask = Task {
      var directory: URL?
      do {
        let delivery = try IncomingShareInbox.createDelivery()
        directory = delivery
        var texts = composeText.isEmpty ? [] : [composeText]
        var files = [[String: Any]]()
        var failed = max(0, providers.count - IncomingShareInbox.maxFiles)
        for (index, provider) in providers.prefix(IncomingShareInbox.maxFiles).enumerated() {
          try Task.checkCancellation()
          do {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
              let file = try await loadFileURL(provider, directory: delivery, index: index)
              files.append(file)
            } else if let type = provider.registeredTypeIdentifiers.first(where: { identifier in
              guard let type = UTType(identifier) else { return false }
              return type.conforms(to: .image) || type.conforms(to: .movie) || type.conforms(to: .audio) || type.conforms(to: .pdf)
            }) {
              let file = try await loadFile(provider, type: type, directory: delivery, index: index)
              files.append(file)
            } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
              let value = try await loadItem(provider, type: UTType.url.identifier)
              let text = (value as? URL)?.absoluteString ?? (value as? String) ?? ""
              if !text.isEmpty && !texts.contains(where: { $0.contains(text) }) { texts.append(text) }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
              if composeText.isEmpty {
                let value = try await loadItem(provider, type: UTType.plainText.identifier)
                if let text = value as? String, !texts.contains(text) { texts.append(text) }
              }
            } else if let type = provider.registeredTypeIdentifiers.first(where: { UTType($0)?.conforms(to: .data) == true }) {
              let file = try await loadFile(provider, type: type, directory: delivery, index: index)
              files.append(file)
            } else {
              failed += 1
            }
          } catch { failed += 1 }
        }
        let text = texts.joined(separator: "\n\n")
        try Task.checkCancellation()
        if copyControl.isCancelled { throw IncomingShareInbox.InboxError.cancelled }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !files.isEmpty else {
          throw IncomingShareInbox.InboxError.empty
        }
        try IncomingShareInbox.save(directory: delivery, text: text, files: files, failedFiles: failed)
        let alert = UIAlertController(title: label("saved"), message: label(failed == 0 ? "savedMessage" : "partialMessage"), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: label("done"), style: .default) { _ in
          self.extensionContext?.completeRequest(returningItems: nil)
        })
        present(alert, animated: true)
      } catch {
        if let directory { try? FileManager.default.removeItem(at: directory) }
        if Task.isCancelled { return }
        saving = false
        validateContent()
        let alert = UIAlertController(title: label("failed"), message: label("failedMessage"), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: label("done"), style: .default))
        present(alert, animated: true)
      }
    }
  }

  private func label(_ key: String) -> String { NSLocalizedString(key, comment: "Incoming share") }

  private func loadItem(_ provider: NSItemProvider, type: String) async throws -> NSSecureCoding? {
    try await withCheckedThrowingContinuation { continuation in
      provider.loadItem(forTypeIdentifier: type, options: nil) { value, error in
        if let error { continuation.resume(throwing: error) }
        else { continuation.resume(returning: value) }
      }
    }
  }

  private func loadFile(_ provider: NSItemProvider, type: String, directory: URL, index: Int) async throws -> [String: Any] {
    let name = provider.suggestedName
    let control = copyControl
    return try await withCheckedThrowingContinuation { continuation in
      provider.loadFileRepresentation(forTypeIdentifier: type) { url, error in
        guard let url else { continuation.resume(throwing: error ?? IncomingShareInbox.InboxError.invalidFile); return }
        // The provider owns this URL only until this callback returns.
        continuation.resume(with: Result {
          try IncomingShareInbox.copyFile(url, to: directory, index: index,
                                          suggestedName: name, typeIdentifier: type,
                                          isCancelled: { control.isCancelled },
                                          onProgress: { bytes, total in self.report(bytes, total: total, index: index) })
        })
      }
    }
  }

  private func loadFileURL(_ provider: NSItemProvider, directory: URL, index: Int) async throws -> [String: Any] {
    let name = provider.suggestedName
    let control = copyControl
    return try await withCheckedThrowingContinuation { continuation in
      provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { value, error in
        guard let url = value as? URL else {
          continuation.resume(throwing: error ?? IncomingShareInbox.InboxError.invalidFile)
          return
        }
        continuation.resume(with: Result {
          try IncomingShareInbox.copyFile(url, to: directory, index: index,
                                          suggestedName: name, isCancelled: { control.isCancelled },
                                          onProgress: { bytes, total in self.report(bytes, total: total, index: index) })
        })
      }
    }
  }
}
