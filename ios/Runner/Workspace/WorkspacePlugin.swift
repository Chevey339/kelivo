//
//  WorkspacePlugin.swift
//  Runner
//
//  MethodChannel `app.workspace` + EventChannel `app.workspace/events`.
//

import Flutter
import UIKit

final class WorkspacePlugin: NSObject, FlutterStreamHandler {
  static let methodChannelName = "app.workspace"
  static let eventChannelName = "app.workspace/events"

  private let queue = DispatchQueue(label: "psyche.kelivo.workspace", qos: .userInitiated)
  private let eventLock = NSLock()
  private var eventSink: FlutterEventSink?
  private var pendingEvents: [[String: Any]] = []
  private var lastInstallProgressAt: CFAbsoluteTime = 0
  private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
  private var backgroundTaskLock = NSLock()
  private let directories: WorkspaceDirectoryAccess
  private var externalMounts: [[String: Any]] = []

  private init(presenter: UIViewController) {
    directories = WorkspaceDirectoryAccess(presenter: presenter)
    super.init()
  }

  @discardableResult
  static func register(messenger: FlutterBinaryMessenger, presenter: UIViewController) -> WorkspacePlugin {
    let plugin = WorkspacePlugin(presenter: presenter)
    let methods = FlutterMethodChannel(name: methodChannelName, binaryMessenger: messenger)
    methods.setMethodCallHandler { [weak plugin] call, result in
      plugin?.handle(call, result: result)
    }
    let events = FlutterEventChannel(name: eventChannelName, binaryMessenger: messenger)
    events.setStreamHandler(plugin)

    let kernel = KelivoISHKernel.shared()
    kernel.ptyDataHandler = { [weak plugin] sessionId, data in
      plugin?.emit([
        "type": "pty",
        "sessionId": sessionId,
        "data": FlutterStandardTypedData(bytes: data),
      ])
    }
    kernel.ptyExitHandler = { [weak plugin] sessionId, code in
      plugin?.emit([
        "type": "ptyExit",
        "sessionId": sessionId,
        "exitCode": code,
      ])
    }
    return plugin
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    eventLock.lock()
    eventSink = events
    let buffered = pendingEvents
    pendingEvents.removeAll()
    eventLock.unlock()
    for event in buffered {
      events(event)
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventLock.lock()
    eventSink = nil
    eventLock.unlock()
    return nil
  }

  private func emit(_ event: [String: Any]) {
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.eventLock.lock()
      if let sink = self.eventSink {
        self.eventLock.unlock()
        sink(event)
      } else {
        self.pendingEvents.append(event)
        self.eventLock.unlock()
      }
    }
  }

  private func emitInstallProgress(phase: RootfsInstallPhase, progress: Double) {
    let now = CFAbsoluteTimeGetCurrent()
    let isTerminal = progress >= 1.0 || progress <= 0.0
    if !isTerminal && now - lastInstallProgressAt < 0.2 { return }
    lastInstallProgressAt = now
    emit([
      "type": "install",
      "phase": phase.rawValue,
      "progress": progress,
    ])
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "setExternalMounts":
      let args = call.arguments as? [String: Any] ?? [:]
      let mounts = Self.parseBinds(args["mounts"])
      guard mounts.count <= 10, mounts.allSatisfy(Self.validExternalMount), Set(mounts.compactMap { ($0["guest"] as? String)?.lowercased() }).count == mounts.count else {
        result(FlutterError(code: "bad_args", message: "Invalid external mounts", details: nil))
        return
      }
      queue.async {
        if !NSArray(array: mounts).isEqual(to: self.externalMounts) {
          KelivoISHExecutor.cancelAllInterrupted(true)
          KelivoISHKernel.shared().ptyCloseAll()
          let error = KelivoISHKernel.shared().reconcileExternalBinds(mounts)
          if error < 0 {
            _ = KelivoISHKernel.shared().reconcileExternalBinds(self.externalMounts)
            self.complete(result, Self.mountError(error))
            return
          }
          self.externalMounts = mounts
        }
        self.complete(result, nil)
      }
    case "hasDirectoryStorageAccess", "requestDirectoryStorageAccess":
      result(true)
    case "pickDirectory":
      directories.pick(result: result)
    case "resolveDirectory", "releaseDirectory":
      guard let args = call.arguments as? [String: Any],
        let token = args["token"] as? String, !token.isEmpty
      else {
        result(FlutterError(code: "bad_args", message: "token required", details: nil))
        return
      }
      if call.method == "resolveDirectory" {
        directories.resolve(token: token, result: result)
      } else {
        directories.release(token: token, result: result)
      }
    case "probe":
      probe(result: result)
    case "installRootfs":
      installRootfs(result: result)
    case "resetRootfs":
      resetRootfs(result: result)
    case "boot":
      boot(result: result)
    case "exec":
      exec(call: call, result: result)
    case "cancel":
      cancel(call: call, result: result)
    case "ptyOpen":
      ptyOpen(call: call, result: result)
    case "ptyWrite":
      ptyWrite(call: call, result: result)
    case "ptyResize":
      ptyResize(call: call, result: result)
    case "ptyClose":
      ptyClose(call: call, result: result)
    case "keepScreenOn":
      keepScreenOn(call: call, result: result)
    case "beginBackgroundTask":
      beginBackgroundTask(result: result)
    case "endBackgroundTask":
      endBackgroundTask(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func probe(result: @escaping FlutterResult) {
    let installer = RootfsInstaller.shared
    let kernel = KelivoISHKernel.shared()
    var reason: String?
    if !installer.isInstalled {
      reason = "rootfs not installed"
    } else if installer.needsRestart {
      reason = "rootfs was reset or upgraded; restart the app"
    }
    result([
      "supported": true,
      "engine": "ish",
      "installed": installer.isInstalled,
      "booted": kernel.isBooted,
      "needsRestart": installer.needsRestart,
      "rootfsVersion": installer.installedVersion as Any,
      "bundledVersion": installer.bundledVersion,
      "rootfsDir": installer.rootfsDir.path,
      "reason": reason as Any,
    ])
  }

  private func installRootfs(result: @escaping FlutterResult) {
    queue.async { [weak self] in
      guard let self else { return }
      do {
        try RootfsInstaller.shared.install(
          progress: { phase, progress in
            self.emitInstallProgress(phase: phase, progress: progress)
          }
        )
        self.complete(result, ["ok": true])
      } catch RootfsInstallerError.needsRestart {
        self.complete(result, ["ok": false, "needsRestart": true])
      } catch {
        self.complete(
          result,
          FlutterError(code: "install_failed", message: error.localizedDescription, details: nil)
        )
      }
    }
  }

  private func resetRootfs(result: @escaping FlutterResult) {
    queue.async { [weak self] in
      guard let self else { return }
      do {
        let needsRestart = try RootfsInstaller.shared.reset()
        self.complete(result, ["ok": true, "needsRestart": needsRestart])
      } catch {
        self.complete(
          result,
          FlutterError(code: "reset_failed", message: error.localizedDescription, details: nil)
        )
      }
    }
  }

  private func boot(result: @escaping FlutterResult) {
    queue.async { [weak self] in
      guard let self else { return }
      let installer = RootfsInstaller.shared
      if installer.needsRestart {
        self.complete(
          result,
          FlutterError(
            code: "needs_restart",
            message: RootfsInstallerError.needsRestart.localizedDescription,
            details: nil
          )
        )
        return
      }
      if !installer.isInstalled {
        self.complete(
          result,
          FlutterError(code: "rootfs_missing", message: "rootfs not installed", details: nil)
        )
        return
      }
      let err = KelivoISHKernel.shared().boot(withRootPath: installer.rootfsDir.path)
      if err < 0 {
        self.complete(
          result,
          FlutterError(code: "boot_failed", message: "iSH kernel boot failed: \(err)", details: nil)
        )
        return
      }
      self.complete(result, ["ok": true])
    }
  }

  private func exec(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    guard let runId = args["runId"] as? String, !runId.isEmpty,
      let command = args["command"] as? String, !command.isEmpty
    else {
      result(FlutterError(code: "bad_args", message: "runId and command required", details: nil))
      return
    }
    let cwd = (args["cwd"] as? String) ?? "/"
    let timeoutMs = (args["timeoutMs"] as? NSNumber)?.intValue ?? 30_000
    let binds = Self.parseBinds(args["binds"])
    let env = args["env"] as? [String: String] ?? [:]

    queue.async { [weak self] in
      guard let self else { return }
      if let error = self.ensureBooted() {
        self.complete(result, error)
        return
      }
      let mountErr = KelivoISHKernel.shared().reconcileBinds(self.commandBinds(binds))
      if mountErr < 0 {
        self.complete(
          result,
          Self.mountError(mountErr)
        )
        return
      }
      let started = KelivoISHExecutor.startCommand(
        command,
        runId: runId,
        cwd: cwd,
        env: env,
        timeoutMs: timeoutMs,
        chunk: { [weak self] id, isStderr, data in
          self?.emit([
            "type": isStderr ? "stderr" : "stdout",
            "runId": id,
            "data": FlutterStandardTypedData(bytes: data),
          ])
        },
        done: { [weak self] info in
          // Coerce NSNumber flags to Swift Bool so the standard codec
          // encodes true/false, not 1/0 (`event['timedOut'] == true` is
          // false for the integer 1 on the Dart side).
          self?.emit([
            "type": "exit",
            "runId": runId,
            "exitCode": info["exitCode"] ?? -1,
            "timedOut": Self.boxedFlag(info["timedOut"]),
            "cancelled": Self.boxedFlag(info["cancelled"]),
            "interrupted": Self.boxedFlag(info["interrupted"]),
            "durationMs": info["durationMs"] ?? 0,
          ])
        }
      )
      if !started {
        self.complete(
          result,
          FlutterError(code: "exec_failed", message: "could not start command", details: nil)
        )
        return
      }
      self.complete(result, ["started": true])
    }
  }

  private func cancel(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    guard let runId = args["runId"] as? String, !runId.isEmpty else {
      result(false)
      return
    }
    result(KelivoISHExecutor.cancelRunId(runId))
  }

  private func ptyOpen(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    guard let sessionId = args["sessionId"] as? String, !sessionId.isEmpty else {
      result(FlutterError(code: "bad_args", message: "sessionId required", details: nil))
      return
    }
    let binds = Self.parseBinds(args["binds"])
    let cwd = args["cwd"] as? String
    let env = args["env"] as? [String: String]
    let cols = (args["cols"] as? NSNumber)?.int32Value ?? 80
    let rows = (args["rows"] as? NSNumber)?.int32Value ?? 24

    queue.async { [weak self] in
      guard let self else { return }
      if let error = self.ensureBooted() {
        self.complete(result, error)
        return
      }
      let mountErr = KelivoISHKernel.shared().reconcileBinds(self.commandBinds(binds))
      if mountErr < 0 {
        self.complete(
          result,
          Self.mountError(mountErr)
        )
        return
      }
      let pid = KelivoISHKernel.shared().ptyOpenSession(
        sessionId,
        cwd: cwd,
        env: env,
        cols: cols,
        rows: rows
      )
      if pid < 0 {
        self.complete(result, Self.ptyOpenError(pid))
        return
      }
      self.complete(result, ["pid": pid])
    }
  }

  /// Names the wrapper's own refusals; anything else is a guest errno, which
  /// overlaps them numerically only if the enum drifts into that range.
  private static func ptyOpenError(_ code: Int32) -> FlutterError {
    let reason: String
    switch code {
    case KelivoISHPtyOpenError.notBooted.rawValue:
      reason = "kernel not booted"
    case KelivoISHPtyOpenError.badSessionId.rawValue:
      reason = "empty sessionId"
    case KelivoISHPtyOpenError.sessionExists.rawValue:
      reason = "sessionId already open"
    case KelivoISHPtyOpenError.environmentTooLarge.rawValue:
      reason = "environment variables exceed the iOS sandbox limit of 128 KiB (UTF-8); reduce their total size"
    case KelivoISHPtyOpenError.invalidEnvironment.rawValue:
      reason = "invalid environment variable name or value"
    default:
      reason = "guest error"
    }
    return FlutterError(
      code: "pty_failed",
      message: "ptyOpen failed: \(reason) (\(code))",
      details: nil
    )
  }

  private func ptyWrite(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    guard let sessionId = args["sessionId"] as? String else {
      result(nil)
      return
    }
    let data: Data
    if let typed = args["data"] as? FlutterStandardTypedData {
      data = typed.data
    } else if let string = args["data"] as? String {
      data = Data(string.utf8)
    } else {
      result(nil)
      return
    }
    KelivoISHKernel.shared().ptyWriteSession(sessionId, data: data)
    result(nil)
  }

  private func ptyResize(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    guard let sessionId = args["sessionId"] as? String else {
      result(nil)
      return
    }
    let cols = (args["cols"] as? NSNumber)?.int32Value ?? 80
    let rows = (args["rows"] as? NSNumber)?.int32Value ?? 24
    KelivoISHKernel.shared().ptyResizeSession(sessionId, cols: cols, rows: rows)
    result(nil)
  }

  private func ptyClose(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    if let sessionId = args["sessionId"] as? String {
      KelivoISHKernel.shared().ptyCloseSession(sessionId)
    }
    result(nil)
  }

  private func keepScreenOn(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    let enabled = args["enabled"] as? Bool ?? false
    DispatchQueue.main.async {
      UIApplication.shared.isIdleTimerDisabled = enabled
      result(nil)
    }
  }

  private func beginBackgroundTask(result: @escaping FlutterResult) {
    #if targetEnvironment(simulator)
    // Simulator expiration handlers fire almost immediately and would cancel
    // in-flight execs (timeout/cancel tests, long apk, etc.).
    result(nil)
    #else
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.backgroundTaskLock.lock()
      if self.backgroundTask == .invalid {
        self.backgroundTask = UIApplication.shared.beginBackgroundTask(
          withName: "KelivoWorkspace"
        ) { [weak self] in
          self?.expireBackgroundTask()
        }
      }
      self.backgroundTaskLock.unlock()
      result(nil)
    }
    #endif
  }

  private func endBackgroundTask(result: @escaping FlutterResult) {
    #if targetEnvironment(simulator)
    result(nil)
    #else
    DispatchQueue.main.async { [weak self] in
      self?.finishBackgroundTask()
      result(nil)
    }
    #endif
  }

  private func expireBackgroundTask() {
    KelivoISHExecutor.cancelAllInterrupted(true)
    finishBackgroundTask()
  }

  private func finishBackgroundTask() {
    backgroundTaskLock.lock()
    let task = backgroundTask
    backgroundTask = .invalid
    backgroundTaskLock.unlock()
    if task != .invalid {
      UIApplication.shared.endBackgroundTask(task)
    }
  }

  private func ensureBooted() -> FlutterError? {
    let installer = RootfsInstaller.shared
    if installer.needsRestart {
      return FlutterError(
        code: "needs_restart",
        message: RootfsInstallerError.needsRestart.localizedDescription,
        details: nil
      )
    }
    if !installer.isInstalled {
      return FlutterError(code: "rootfs_missing", message: "rootfs not installed", details: nil)
    }
    let kernel = KelivoISHKernel.shared()
    if !kernel.isBooted {
      let err = kernel.boot(withRootPath: installer.rootfsDir.path)
      if err < 0 {
        return FlutterError(code: "boot_failed", message: "iSH kernel boot failed: \(err)", details: nil)
      }
    }
    return nil
  }

  /// Flutter's StandardMessageCodec encodes generic `NSNumber` as int.
  /// `kCFBoolean*` is the only NSNumber that arrives in Dart as `true`/`false`.
  private static func flag(_ value: Any?) -> Bool {
    if let b = value as? Bool { return b }
    if let n = value as? NSNumber { return n.boolValue }
    return false
  }

  private static func boxedFlag(_ value: Any?) -> CFBoolean {
    flag(value) ? kCFBooleanTrue : kCFBooleanFalse
  }

  private static func validExternalMount(_ mount: [String: Any]) -> Bool {
    guard let guest = mount["guest"] as? String, let host = mount["host"] as? String,
      guest.hasPrefix("/mounts/"), host.hasPrefix("/"), !host.contains("\0") else { return false }
    let name = String(guest.dropFirst("/mounts/".count))
    return !name.isEmpty && name != "." && name != ".." &&
      name == name.trimmingCharacters(in: .whitespacesAndNewlines) &&
      name.rangeOfCharacter(from: CharacterSet(charactersIn: "/\\:").union(.controlCharacters)) == nil
  }

  private func commandBinds(_ binds: [[String: Any]]) -> [[String: Any]] {
    binds.filter { !(($0["guest"] as? String)?.hasPrefix("/mounts/") ?? false) } + externalMounts
  }

  private static func mountError(_ code: Int32) -> FlutterError {
    if code == KelivoISHMountTargetOccupied {
      return FlutterError(
        code: "external_mount_target_occupied",
        message: "A mount target under /mounts already contains local files. Choose a different mount name or move those files first. No files were removed.",
        details: nil
      )
    }
    return FlutterError(code: "mount_failed", message: "bind mount failed: \(code)", details: nil)
  }

  private static func parseBinds(_ raw: Any?) -> [[String: Any]] {
    guard let list = raw as? [[String: Any]] else { return [] }
    return list.compactMap { item in
      guard let host = item["host"] as? String, !host.isEmpty,
        let guest = item["guest"] as? String, !guest.isEmpty
      else { return nil }
      return ["host": host, "guest": guest, "readOnly": item["readOnly"] as? Bool ?? false]
    }
  }

  private func complete(_ result: @escaping FlutterResult, _ value: Any?) {
    DispatchQueue.main.async { result(value) }
  }
}
