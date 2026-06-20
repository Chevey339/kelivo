import Foundation
import Network

/// Sent to the event channel when there is no error.
@available(iOS 13.0, macOS 10.15, *)
class SuccessObject {
    /// The response id.
    let id: String

    /// The response service.
    let service: BonsoirService?

    /// Creates a new instance with any result.
    public convenience init(id: String) {
        self.init(id: id, service: nil)
    }

    /// Creates a new success object instance.
    public init(id: String, service: BonsoirService?) {
        self.id = id
        self.service = service
    }

    /// Converts the current instance into a dictionary.
    public func toJson() -> [String: Any] {
        var json: [String: Any] = [:]
        json["id"] = id
        if service != nil {
            json["service"] = service!.toJson()
        }
        return json
    }
}
