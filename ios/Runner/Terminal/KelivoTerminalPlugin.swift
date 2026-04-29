import Flutter
import Foundation

final class KelivoTerminalPlugin: NSObject {
  private static let shared = KelivoTerminalPlugin()
  private let runtime = KelivoOpenMinisRuntimeBridge()

  static func register(binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "kelivo.terminal/ios", binaryMessenger: binaryMessenger)
    channel.setMethodCallHandler { call, result in
      shared.handle(call: call, result: result)
    }
    shared.runtime.appendDiagnostic(withArguments: ["message": "KelivoTerminalPlugin registered method-channel-only"])
  }

  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let arguments = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "getRuntimeStatus":
      result(runtime.runtimeStatus())
    case "getDiagnosticLog":
      result(runtime.diagnosticLog())
    case "appendDiagnostic":
      runtime.appendDiagnostic(withArguments: arguments)
      result(nil)
    case "drainEvents":
      result(runtime.drainEvents())
    case "installRuntime":
      DispatchQueue.global(qos: .userInitiated).async {
        let error = self.runtime.installRuntime(withArguments: arguments)
        DispatchQueue.main.async {
          if let error {
            result(error)
          } else {
            result(["installed": true])
          }
        }
      }
    case "startSession":
      result(runtime.startSession(withArguments: arguments))
    case "writeSession":
      result(runtime.writeSession(withArguments: arguments))
    case "resizeSession":
      result(runtime.resizeSession(withArguments: arguments))
    case "stopSession":
      result(runtime.stopSession(withArguments: arguments))
    case "runCommand":
      DispatchQueue.global(qos: .userInitiated).async {
        let payload = self.runtime.runCommand(withArguments: arguments)
        DispatchQueue.main.async {
          result(payload)
        }
      }
    case "cancelInstall", "listFiles", "resetRuntime":
      result(KelivoTerminalPlugin.unavailable(method: call.method))
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static func unavailable(method: String) -> FlutterError {
    FlutterError(
      code: "terminal_action_not_implemented",
      message: "Terminal native action is not implemented yet.",
      details: ["method": method]
    )
  }
}
