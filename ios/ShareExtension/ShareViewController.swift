import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
  private var started = false
  private var finished = false
  private var importTask: Task<Void, Never>?
  private let copyControl = ShareCopyControl()
  private let statusLabel = UILabel()
  private let cancelButton = UIButton(type: .system)
  private let spinner = UIActivityIndicatorView(style: .large)

  override func viewDidLoad() {
    super.viewDidLoad()
    isModalInPresentation = true
    view.backgroundColor = .systemBackground

    statusLabel.text = label("importing")
    statusLabel.font = .preferredFont(forTextStyle: .body)
    statusLabel.textAlignment = .center
    statusLabel.numberOfLines = 0
    cancelButton.setTitle(label("cancel"), for: .normal)
    cancelButton.addTarget(self, action: #selector(cancelImport), for: .touchUpInside)
    spinner.startAnimating()
    let stack = UIStackView(arrangedSubviews: [spinner, statusLabel, cancelButton])
    stack.axis = .vertical
    stack.alignment = .center
    stack.spacing = 16
    stack.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(stack)
    NSLayoutConstraint.activate([
      stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
      stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.layoutMarginsGuide.leadingAnchor),
      stack.trailingAnchor.constraint(lessThanOrEqualTo: view.layoutMarginsGuide.trailingAnchor),
    ])
  }

  private func report(_ bytes: Int, total: Int?, index: Int) {
    DispatchQueue.main.async {
      guard !self.finished, self.cancelButton.isEnabled else { return }
      let size = ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
      let percent = total.flatMap { $0 > 0 ? " · \(min(100, bytes * 100 / $0))%" : nil } ?? ""
      self.statusLabel.text = "\(self.label("importing"))\n\(index + 1) · \(size)\(percent)"
    }
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    // Wait until the responder chain is attached before attempting the handoff.
    guard !started else { return }
    started = true
    importAndOpenApp()
  }

  @objc private func cancelImport() {
    guard !finished else { return }
    finished = true
    copyControl.cancel()
    importTask?.cancel()
    extensionContext?.cancelRequest(withError: NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError))
  }

  private func importAndOpenApp() {
    let items = extensionContext?.inputItems.compactMap { $0 as? NSExtensionItem } ?? []
    let providers = items.flatMap { $0.attachments ?? [] }
    importTask = Task {
      var directory: URL?
      do {
        let delivery = try IncomingShareInbox.createDelivery()
        directory = delivery
        var texts = IncomingShareInbox.textContents(in: items)
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
              let value = try await loadItem(provider, type: UTType.plainText.identifier)
              if let text = value as? String, !texts.contains(text) { texts.append(text) }
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
        // Publish the complete delivery before waking Flutter. Do not delete it
        // if opening fails: the next app launch can still consume the inbox.
        cancelButton.isEnabled = false
        statusLabel.text = label("opening")
        openApp(failedFiles: failed)
      } catch {
        if let directory { try? FileManager.default.removeItem(at: directory) }
        if Task.isCancelled || copyControl.isCancelled { return }
        showCompletion(title: "failed", message: "failedMessage")
      }
    }
  }

  private func openApp(failedFiles: Int) {
    // Share extensions have no supported containing-app open API. Like OpenMinis,
    // use the application in the responder chain and the modern open method
    // (the deprecated openURL: selector fails on iOS 18 and later).
    var responder: UIResponder? = self
    while let current = responder {
      if let application = current as? UIApplication {
        application.open(IncomingShareInbox.activationURL, options: [:]) { [weak self] opened in
          guard let self, !self.finished else { return }
          if opened { self.completeRequest() }
          else { self.showSavedMessage(failedFiles: failedFiles) }
        }
        return
      }
      responder = current.next
    }
    showSavedMessage(failedFiles: failedFiles)
  }

  private func showSavedMessage(failedFiles: Int) {
    showCompletion(title: "saved", message: failedFiles == 0 ? "savedMessage" : "partialMessage")
  }

  private func showCompletion(title: String, message: String) {
    spinner.stopAnimating()
    cancelButton.isEnabled = false
    statusLabel.text = label(title)
    let alert = UIAlertController(title: label(title), message: label(message), preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: label("done"), style: .default) { _ in
      self.completeRequest()
    })
    present(alert, animated: true)
  }

  private func completeRequest() {
    guard !finished else { return }
    finished = true
    extensionContext?.completeRequest(returningItems: nil)
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
