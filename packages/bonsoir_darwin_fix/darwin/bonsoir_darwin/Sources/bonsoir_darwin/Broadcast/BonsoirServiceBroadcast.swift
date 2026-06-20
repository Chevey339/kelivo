#if canImport(Flutter)
    import Flutter
#endif
#if canImport(FlutterMacOS)
    import FlutterMacOS
#endif
import Network

/// Allows to broadcast a given service to the local network.
@available(iOS 13.0, macOS 10.15, *)
class BonsoirServiceBroadcast: BonsoirAction {
    /// The advertised service.
    private let service: BonsoirService

    /// The reference to the registering..
    private var sdRef: DNSServiceRef?

    /// Initializes this class.
    public init(id: Int, printLogs: Bool, onDispose: @escaping () -> Void, messenger: FlutterBinaryMessenger, service: BonsoirService) {
        self.service = service
        super.init(id: id, action: "broadcast", logMessages: Generated.broadcastMessages, printLogs: printLogs, onDispose: onDispose, messenger: messenger)
    }

    /// Starts the broadcast.
    public func start() {
        var txtRecord = TXTRecordRef()
        TXTRecordCreate(&txtRecord, 0, nil)
        for (key, value) in service.attributes {
            guard let valueData = value.data(using: .utf8) else { continue }
            TXTRecordSetValue(&txtRecord, key, UInt8(valueData.count), [UInt8](valueData))
        }
        let error = DNSServiceRegister(&sdRef, 0, 0, service.name, service.type, "local.", service.host, CFSwapInt16HostToBig(UInt16(service.port)), TXTRecordGetLength(&txtRecord), TXTRecordGetBytesPtr(&txtRecord), BonsoirServiceBroadcast.registerCallback as DNSServiceRegisterReply, Unmanaged.passUnretained(self).toOpaque())
        if error == kDNSServiceErr_NoError {
            log(logMessages[Generated.broadcastInitialized]!, [service])
            DNSServiceProcessResult(sdRef)
        } else {
            onError(parameters: [service, error], details: error)
            dispose()
        }
    }

    override public func dispose() {
        DNSServiceRefDeallocate(sdRef)
        onSuccess(eventId: Generated.broadcastStopped, service: service)
        super.dispose()
    }

    /// Callback triggered by`DNSServiceRegister`.
    private static let registerCallback: DNSServiceRegisterReply = { _, _, errorCode, name, _, _, context in
        let broadcast = Unmanaged<BonsoirServiceBroadcast>.fromOpaque(context!).takeUnretainedValue()
        if errorCode == kDNSServiceErr_NoError {
            let newName = name == nil ? nil : String(cString: name!)
            if newName != nil && broadcast.service.name != newName {
                let oldName = broadcast.service.name
                broadcast.service.name = newName!
                broadcast.onSuccess(eventId: Generated.broadcastNameAlreadyExists, service: broadcast.service, parameters: [oldName])
            }
            broadcast.onSuccess(eventId: Generated.broadcastStarted, service: broadcast.service)
        } else {
            broadcast.onError(parameters: [broadcast.service, errorCode], details: errorCode)
            broadcast.dispose()
        }
    }
}
