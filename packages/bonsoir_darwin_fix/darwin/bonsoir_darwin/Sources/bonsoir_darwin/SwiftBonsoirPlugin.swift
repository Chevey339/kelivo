#if canImport(Flutter)
    import Flutter
#elseif canImport(FlutterMacOS)
    import FlutterMacOS
#endif
import Network

/// The main plugin Swift class.
@available(iOS 13.0, macOS 10.15, *)
public class SwiftBonsoirPlugin: NSObject, FlutterPlugin {
    /// The package name.
    static let package: String = "fr.skyost.bonsoir"

    /// Contains all created broadcasts).
    var broadcasts: [Int: BonsoirServiceBroadcast] = [:]

    /// Contains all created browsers.
    var discoveries: [Int: BonsoirServiceDiscovery] = [:]

    /// The binary messenger instance.
    let messenger: FlutterBinaryMessenger

    /// The class constructor.
    private init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        #if canImport(Flutter)
            let messenger = registrar.messenger()
        #elseif canImport(FlutterMacOS)
            let messenger = registrar.messenger
        #endif
        let channel = FlutterMethodChannel(name: package, binaryMessenger: messenger)
        let instance = SwiftBonsoirPlugin(messenger: messenger)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments: [String: Any?] = call.arguments as! [String: Any?]
        let id = arguments["id"] as! Int
        switch call.method {
        case "broadcast.initialize":
            let service = BonsoirService(name: arguments["service.name"] as! String, type: arguments["service.type"] as! String, port: arguments["service.port"] as! Int, host: nil, attributes: arguments["service.attributes"] as! [String: String])
            if let host = arguments["service.host"] as? String? {
                service.host = host
            }
            broadcasts[id] = BonsoirServiceBroadcast(id: id, printLogs: arguments["printLogs"] as! Bool, onDispose: {
                self.broadcasts.removeValue(forKey: id)
            }, messenger: messenger, service: service)
            result(true)
        case "broadcast.start":
            broadcasts[id]?.start()
            result(broadcasts[id] != nil)
        case "broadcast.stop":
            broadcasts[id]?.dispose()
            result(broadcasts[id] != nil)
        case "discovery.initialize":
            discoveries[id] = BonsoirServiceDiscovery(id: id, printLogs: arguments["printLogs"] as! Bool, onDispose: {
                self.discoveries.removeValue(forKey: id)
            }, messenger: messenger, type: arguments["type"] as! String)
            result(true)
        case "discovery.start":
            discoveries[id]?.start()
            result(discoveries[id] != nil)
        case "discovery.resolveService":
            let resolveStarted: Bool = discoveries[id]?.resolveService(name: arguments["name"] as! String, type: arguments["type"] as! String) ?? false
            result(resolveStarted)
        case "discovery.stop":
            discoveries[id]?.dispose()
            result(discoveries[id] != nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    public func detachFromEngineForRegistrar(registrar: FlutterPluginRegistrar) {
        for broadcast in broadcasts.values {
            broadcast.dispose()
        }
        for discovery in discoveries.values {
            discovery.dispose()
        }
    }
}
