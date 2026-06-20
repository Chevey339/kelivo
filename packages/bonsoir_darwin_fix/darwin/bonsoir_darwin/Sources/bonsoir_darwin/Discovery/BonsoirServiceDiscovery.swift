#if canImport(Flutter)
    import Flutter
#endif
#if canImport(FlutterMacOS)
    import FlutterMacOS
#endif
import Network

/// Allows to find net services on local network.
@available(iOS 13.0, macOS 10.15, *)
class BonsoirServiceDiscovery: BonsoirAction {
    /// The type we're listening to.
    private let type: String
    
    /// The current browser instance.
    private let browser: NWBrowser
    
    /// Contains all found services.
    private var services: [BonsoirService] = []
    
    /// Contains all services we're currently resolving.
    private var pendingResolution: [DNSServiceRef] = []

    /// Contains all dispatch sources.
    private var pendingDispatchSources: [DispatchSourceRead] = []

    /// Initializes this class.
    public init(id: Int, printLogs: Bool, onDispose: @escaping () -> Void, messenger: FlutterBinaryMessenger, type: String) {
        self.type = type
        browser = NWBrowser(for: .bonjourWithTXTRecord(type: type, domain: "local."), using: .tcp)
        super.init(id: id, action: "discovery", logMessages: Generated.discoveryMessages, printLogs: printLogs, onDispose: onDispose, messenger: messenger)
        browser.stateUpdateHandler = stateHandler
        browser.browseResultsChangedHandler = browseHandler
    }
    
    /// Finds a service amongst discovered services.
    private func findService(_ name: String, _ type: String? = nil) -> BonsoirService? {
        return services.first(where: { $0.name == name && (type == nil || $0.type == type) })
    }
    
    /// Handles state changes.
    func stateHandler(_ newState: NWBrowser.State) {
        switch newState {
        case .ready:
            onSuccess(eventId: Generated.discoveryStarted, parameters: [type])
        case .failed(let error):
            let details: Any?
            if #available(iOS 16.4, macOS 13.3, *) {
                details = error.errorCode
            } else {
                details = error.debugDescription
            }
            onError(parameters: [error], details: details)
            dispose()
        case .cancelled:
            onSuccess(eventId: Generated.discoveryStopped, parameters: [type])
            dispose()
        default:
            break
        }
    }
    
    /// Handles the browsing of services.
    func browseHandler(_ newResults: Set<NWBrowser.Result>, _ changes: Set<NWBrowser.Result.Change>) {
        for change in changes {
            switch change {
            case .added(let result):
                if case .service(let name, let type, _, _) = result.endpoint {
                    var service = findService(name, type)
                    if service != nil {
                        break
                    }
                    service = BonsoirService(name: name, type: type, port: 0, host: nil, attributes: [:])
                    if case .bonjour(let records) = result.metadata {
                        service!.attributes = records.dictionary
                    }
                    onSuccess(eventId: Generated.discoveryServiceFound, service: service)
                    services.append(service!)
                }
            case .removed(let result):
                if case .service(let name, let type, _, _) = result.endpoint {
                    guard let service = findService(name, type) else {
                        break
                    }
                    onSuccess(eventId: Generated.discoveryServiceLost, service: service)
                    if let index = services.firstIndex(where: { $0 === service }) {
                        services.remove(at: index)
                    }
                }
            case .changed(let old, let new, _):
                if case .service(let newName, let newType, _, _) = new.endpoint {
                    if case .service(let oldName, let oldType, _, _) = old.endpoint {
                        guard let service = findService(oldName) else {
                            break
                        }
                        var newAttributes: [String: String]
                        if case .bonjour(let newRecords) = new.metadata {
                            newAttributes = newRecords.dictionary
                        } else {
                            newAttributes = service.attributes
                        }
                        if oldName == newName && oldType == newType && newAttributes == service.attributes {
                            break
                        }
                        service.name = newName
                        service.type = newType
                        service.attributes = newAttributes
                        onSuccess(eventId: Generated.discoveryServiceUpdated, service: service)
                    }
                }
            default:
                break
            }
        }
    }
    
    /// Resolves a service.
    public func resolveService(name: String, type: String) -> Bool {
        guard let service = findService(name, type) else {
            onError(message: Generated.discoveryUndiscoveredServiceResolveFailed, parameters: [name, type])
            return false
        }
        var sdRef: DNSServiceRef? = nil
        let error = DNSServiceResolve(&sdRef, 0, 0, name, type, "local.", BonsoirServiceDiscovery.resolveCallback, Unmanaged.passUnretained(self).toOpaque())
        if error != kDNSServiceErr_NoError {
            onSuccess(eventId: Generated.discoveryServiceResolveFailed, service: service, parameters: [error])
            stopResolution(sdRef: sdRef, remove: false)
            return false
        }

        pendingResolution.append(sdRef!)

        let socket = DNSServiceRefSockFD(sdRef)
        if socket == -1 {
            onSuccess(eventId: Generated.discoveryServiceResolveFailed, service: service, parameters: [])
            stopResolution(sdRef: sdRef, remove: false)
            return false
        }

        let dispatchSource = DispatchSource.makeReadSource(fileDescriptor: socket, queue: DispatchQueue.global(qos: .userInitiated))
        dispatchSource.setEventHandler(handler: {
            DNSServiceProcessResult(sdRef)
            
            DispatchQueue.main.async {
                let foundIndex = self.pendingDispatchSources.firstIndex(where: {
                    $0.isEqual(dispatchSource)
                })
                
                if foundIndex != nil {
                    self.pendingDispatchSources.remove(at: foundIndex!)
                }
            }
        })

        dispatchSource.setCancelHandler(handler: {
            DispatchQueue.main.async {
                let foundIndex = self.pendingDispatchSources.firstIndex(where: {
                    $0.isEqual(dispatchSource)
                })
                
                if foundIndex != nil {
                    self.pendingDispatchSources.remove(at: foundIndex!)
                }
                
                self.onSuccess(eventId: Generated.discoveryServiceResolveFailed, service: service, parameters: [])
                self.stopResolution(sdRef: sdRef, remove: false)
            }
        })

        dispatchSource.activate()
        
        pendingDispatchSources.append(dispatchSource)
        return true
    }
    
    /// Stops the resolution of the given service.
    private func stopResolution(sdRef: DNSServiceRef?, remove: Bool = true) {
        if remove, let index = pendingResolution.firstIndex(where: { $0 == sdRef }) {
            pendingResolution.remove(at: index)
        }
        DNSServiceRefDeallocate(sdRef)
    }
    
    /// Starts the discovery.
    public func start() {
        browser.start(queue: .main)
    }
    
    override public func dispose() {
        for sdRef in pendingResolution {
            stopResolution(sdRef: sdRef, remove: false)
        }
        pendingResolution.removeAll()
        services.removeAll()
        if [.setup, .ready].contains(browser.state) {
            browser.cancel()
        }
        super.dispose()
    }
    
    /// Callback triggered by`DNSServiceResolve`.
    private static let resolveCallback: DNSServiceResolveReply = { sdRef, _, _, errorCode, fullName, hosttarget, port, _, _, context in
        let discovery = Unmanaged<BonsoirServiceDiscovery>.fromOpaque(context!).takeUnretainedValue()
        var service: BonsoirService?
        if fullName != nil, let serviceData = parseBonjourFqdn(unescapeAscii(String(cString: fullName!))) {
            service = discovery.findService(serviceData.0, serviceData.1)
        }
        if service != nil && errorCode == kDNSServiceErr_NoError {
            if hosttarget != nil {
                service!.host = String(cString: hosttarget!)
            }
            service!.port = Int(CFSwapInt16BigToHost(port))

            DispatchQueue.main.async {
                discovery.onSuccess(eventId: Generated.discoveryServiceResolved, service: service)
            }
        } else {
            if service == nil {
                DispatchQueue.main.async {
                    discovery.onError(message: Generated.discoveryServiceResolveFailed, parameters: ["nil", errorCode])
                }
            } else {
                DispatchQueue.main.async {
                    discovery.onSuccess(eventId: Generated.discoveryServiceResolveFailed, service: service, parameters: [errorCode])
                }
            }
        }
        
        DispatchQueue.main.async {
            discovery.stopResolution(sdRef: sdRef, remove: sdRef != nil)
        }
    }
    
    /// Allows to unescape services FQDN.
    private static func unescapeAscii(_ inputString: String) -> String {
        let input = inputString.replacingOccurrences(of: "\\.", with: ".")
        var result = ""
        var i = 0
        while i < input.count {
            if input[i] == "\\" && i + 1 < input.count {
                var asciiCode = ""
                var j = 1
                while j < 4 {
                    if i + j >= input.count || !String(input[i + j]).isNumeric {
                        break
                    }
                    asciiCode += String(input[i + j])
                    j += 1
                }
                if let code = Int(asciiCode), let unicodeScalar = UnicodeScalar(code) {
                    result += String(unicodeScalar)
                } else {
                    result += "\\\(asciiCode)"
                }
                i += (j - 1)
            } else {
                result += String(input[i])
            }
            
            i += 1
        }
        return result
    }

    /// Parses a Bonjour FQDN.
    private static func parseBonjourFqdn(_ fqdn: String) -> (String, String)? {
        let regexPattern = "^(.*?)\\._(.*?)\\.?(?:local)?\\.?$"
        let regex = try! NSRegularExpression(pattern: regexPattern, options: [])
        if let match = regex.firstMatch(in: fqdn, options: [], range: NSRange(location: 0, length: fqdn.utf16.count)) {
            let serviceName = (fqdn as NSString).substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            let serviceType = "_\((fqdn as NSString).substring(with: match.range(at: 2)))"
            return (serviceName, serviceType)
        }
        return nil
    }
}

extension String {
    var isNumeric: Bool {
        return !isEmpty && rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil
    }
    
    subscript(i: Int) -> String {
        return self[i ..< i + 1]
    }
    
    func substring(fromIndex: Int) -> String {
        return self[min(fromIndex, count) ..< count]
    }
    
    func substring(toIndex: Int) -> String {
        return self[0 ..< max(0, toIndex)]
    }
    
    subscript(r: Range<Int>) -> String {
        let range = Range(uncheckedBounds: (lower: max(0, min(count, r.lowerBound)),
                                            upper: min(count, max(0, r.upperBound))))
        let start = index(startIndex, offsetBy: range.lowerBound)
        let end = index(start, offsetBy: range.upperBound - range.lowerBound)
        return String(self[start ..< end])
    }
}
