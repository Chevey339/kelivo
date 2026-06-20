#if canImport(Flutter)
    import Flutter
#endif
#if canImport(FlutterMacOS)
    import FlutterMacOS
#endif
#if canImport(os)
    import os
#endif

/// Represents a Bonsoir action (broadcast or discovery).
@available(iOS 13.0, macOS 10.15, *)
class BonsoirAction: NSObject, FlutterStreamHandler {
    /// The action identifier.
    private let id: Int
    
    /// The action name.
    private let action: String
    
    /// The log messages map.
    let logMessages: [String: String]
    
    /// Whether to print debug logs.
    private let printLogs: Bool
    
    /// Triggered when this instance is being disposed.
    private let onDispose: () -> Void
    
    /// The current event channel.
    private var eventChannel: FlutterEventChannel?
    
    /// The current event sink.
    private var eventSink: FlutterEventSink?
    
    /// Initializes this class.
    public init(id: Int, action: String, logMessages: [String: String], printLogs: Bool, onDispose: @escaping () -> Void, messenger: FlutterBinaryMessenger) {
        self.id = id
        self.action = action
        self.logMessages = logMessages
        self.printLogs = printLogs
        self.onDispose = onDispose
        super.init()
        eventChannel = FlutterEventChannel(name: "\(SwiftBonsoirPlugin.package).\(action).\(id)", binaryMessenger: messenger)
        eventChannel?.setStreamHandler(self)
    }
    
    /// Called by the event channel when ready to list.
    func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = eventSink
        return nil
    }
    
    /// Called by the event channel when cancelled.
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
    
    /// Triggered when a success occurs.
    func onSuccess(eventId: String, message: String? = nil, service: BonsoirService? = nil, parameters: [Any] = []) {
        let logMessage = message ?? logMessages[eventId]!
        var logParameters = parameters
        if service != nil && !logParameters.contains(where: { $0 is BonsoirService && ($0 as! BonsoirService) == service }) {
            logParameters.insert(service!, at: 0)
        }
        log(logMessage, logParameters)
        eventSink?(SuccessObject(id: eventId, service: service).toJson())
    }
    
    /// Triggered when an error occurs.
    func onError(message: String? = nil, parameters: [Any] = [], details: Any? = nil) {
        let logMessage = format(message ?? logMessages["\(action)Error"]!, parameters)
        log(logMessage)
        eventSink?(FlutterError(code: "\(action)Error", message: logMessage, details: details))
    }

    /// Disposes the current class instance.
    public func dispose() {
        onDispose()
    }
    
    /// Logs a given message.
    func log(_ message: String, _ parameters: [Any] = []) {
        if printLogs {
            let string = format(message, parameters)
            #if canImport(os)
                os_log("[%d] %s", log: OSLog(subsystem: SwiftBonsoirPlugin.package, category: action), type: OSLogType.info, id, string)
            #else
                NSLog("\n[\(action)] [\(id)] \(string)")
            #endif
        }
    }
    
    private func format(_ message: String, _ parameters: [Any]) -> String {
        var result = message
        for parameter in parameters {
            if let range = result.range(of: "%s") {
                result = result.replacingCharacters(in: range, with: String(describing: parameter))
            }
        }
        return result
    }
}
