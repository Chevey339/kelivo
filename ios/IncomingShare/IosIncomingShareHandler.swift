import Flutter
import Foundation

final class IosIncomingShareHandler {
  private let queue = DispatchQueue(label: "psyche.kelivo.incoming-share")
  private var channel: FlutterMethodChannel?
  private let lock = NSLock()
  private var progress: [String: Any]?
  private var controls: [String: ShareCopyControl] = [:]

  func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "app.incoming_share", binaryMessenger: messenger)
    self.channel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return }
      switch call.method {
      case "getImportProgress":
        self.lock.lock(); let progress = self.progress; self.lock.unlock()
        result(progress)
      case "cancelImport":
        self.lock.lock(); let control = self.controls[call.arguments as? String ?? ""]; self.lock.unlock()
        control?.cancel()
        result(nil)
      case "getPendingShares":
        self.perform(result) { try IncomingShareInbox.pending() }
      case "acknowledgeShares":
        self.perform(result) {
          try IncomingShareInbox.acknowledge(call.arguments as? [String] ?? [])
          return nil
        }
      default: result(FlutterMethodNotImplemented)
      }
    }
  }

  func receive(_ url: URL) -> Bool {
    if url == IncomingShareInbox.activationURL {
      // The extension already committed its App Group inbox. This also wakes an
      // active Flutter view; cold starts read the same inbox during initialization.
      channel?.invokeMethod("changed", arguments: nil)
      return true
    }
    guard IncomingShareInbox.acceptsApplicationURL(url) else { return false }
    // Hold the grant before returning from the application open-URL callback.
    let scoped = url.startAccessingSecurityScopedResource()
    let id = UUID().uuidString
    let control = ShareCopyControl()
    lock.lock(); controls[id] = control; lock.unlock()
    queue.async {
      defer {
        self.lock.lock(); self.controls.removeValue(forKey: id); self.progress = nil; self.lock.unlock()
        DispatchQueue.main.async { self.channel?.invokeMethod("progress", arguments: nil) }
      }
      defer { if scoped { url.stopAccessingSecurityScopedResource() } }
      var directory: URL?
      do {
        let delivery = try IncomingShareInbox.createDelivery()
        directory = delivery
        var files = [[String: Any]]()
        var failed = 0
        do {
          files.append(try IncomingShareInbox.copyFile(url, to: delivery, index: 0,
            isCancelled: { control.isCancelled }, onProgress: { bytes, total in
              var value: [String: Any] = ["id": id, "name": url.lastPathComponent,
                "index": 1, "count": 1, "bytes": bytes]
              if let total { value["total"] = total }
              self.lock.lock(); self.progress = value; self.lock.unlock()
              DispatchQueue.main.async { self.channel?.invokeMethod("progress", arguments: value) }
            }))
        }
        catch { failed = 1 }
        if control.isCancelled { throw IncomingShareInbox.InboxError.cancelled }
        try IncomingShareInbox.save(directory: delivery, text: "", files: files, failedFiles: failed)
        DispatchQueue.main.async { self.channel?.invokeMethod("changed", arguments: nil) }
      } catch {
        if let directory { try? FileManager.default.removeItem(at: directory) }
        if !control.isCancelled { DispatchQueue.main.async { self.channel?.invokeMethod("failed", arguments: nil) } }
      }
    }
    return true
  }

  private func perform(_ result: @escaping FlutterResult, work: @escaping () throws -> Any?) {
    queue.async {
      do {
        let value = try work()
        DispatchQueue.main.async { result(value) }
      } catch {
        DispatchQueue.main.async { result(FlutterError(code: "share_failed", message: "Unable to read shared content", details: nil)) }
      }
    }
  }
}
