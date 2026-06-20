import Foundation
import Network

/// Represents a Bonsoir service.
@available(iOS 13.0, macOS 10.15, *)
class BonsoirService: NSObject {
    /// The response service name.
    var name: String
    
    /// The response service type.
    var type: String
    
    /// The response service port.
    var port: Int
    
    /// The response service name.
    var host: String?
    
    /// The response service name.
    var attributes: [String: String]
    
    /// Creates a new service instance.
    public init(name: String, type: String, port: Int, host: String?, attributes: [String: String]) {
        self.name = name
        self.type = type
        self.port = port
        self.host = host
        self.attributes = attributes
    }

    /// Converts a given service to a dictionary.
    public func toJson(prefix: String = "service.") -> [String: Any?] {
        return [
            "\(prefix)name": name,
            "\(prefix)type": type,
            "\(prefix)port": port,
            "\(prefix)host": host,
            "\(prefix)attributes": attributes
        ]
    }

    override public var description: String {
        let json = toJson(prefix: "")
        do {
            let data = try JSONSerialization.data(withJSONObject: json)
            return String(data: data, encoding: .utf8)!
        } catch {}
        return "\(json)"
    }
}
