import Flutter
import UIKit
import WebKit

private final class ScrollTestMessenger: NSObject, FlutterBinaryMessenger {
  private let codec = FlutterStandardMethodCodec.sharedInstance()
  private var handlers: [String: FlutterBinaryMessageHandler] = [:]
  var events: [(String, [String: Any])] = []

  func send(onChannel channel: String, message: Data?) {
    guard let message else { return }
    let call = codec.decodeMethodCall(message)
    if let values = call.arguments as? [String: Any] { events.append((channel, values)) }
  }
  func send(onChannel channel: String, message: Data?, binaryReply callback: FlutterBinaryReply?) {
    send(onChannel: channel, message: message)
    callback?(codec.encodeSuccessEnvelope(nil))
  }
  func setMessageHandlerOnChannel(_ channel: String,
                                 binaryMessageHandler handler: FlutterBinaryMessageHandler?) -> FlutterBinaryMessengerConnection {
    handlers[channel] = handler
    return 1
  }
  func cleanUpConnection(_ connection: FlutterBinaryMessengerConnection) {}

  func call(_ method: String, owner: String, viewId: String? = nil, visible: Bool = true) -> Any? {
    var arguments: [String: Any] = ["owner": owner, "visible": visible]
    arguments["viewId"] = viewId
    var result: Any?
    var replied = false
    handlers["app.browser_scroll"]?(
      codec.encode(FlutterMethodCall(methodName: method, arguments: arguments))
    ) { response in
      if let response { result = self.codec.decodeEnvelope(response) }
      replied = true
    }
    assert(replied)
    return result
  }
}

@main
private struct BrowserScrollBridgeTest {
  static let marker = "/* kelivo-browser-tab:dGVzdA== */"
  static func makeView(controller: WKUserContentController) -> WKWebView {
    let config = WKWebViewConfiguration()
    config.userContentController = controller
    return WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844), configuration: config)
  }
  static func flush() { RunLoop.main.run(until: Date().addingTimeInterval(0.02)) }
  static func main() {
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    // Popups share their opener's script controller and initial URL. The
    // concrete per-instance ID supplied by the plugin must distinguish them.
    let scripts = WKUserContentController()
    scripts.addUserScript(WKUserScript(source: marker, injectionTime: .atDocumentStart, forMainFrameOnly: true))
    let first = makeView(controller: scripts)
    let popup = makeView(controller: scripts)
    window.addSubview(first)
    window.addSubview(popup)
    var identities = [ObjectIdentifier(first): "native-one", ObjectIdentifier(popup): "native-popup"]
    flush()
    let messenger = ScrollTestMessenger()
    let bridge = BrowserScrollBridge()
    bridge.register(messenger: messenger, window: window) { identities[ObjectIdentifier($0)] }
    assert(first.url == popup.url)
    assert(first.configuration.userContentController === popup.configuration.userContentController)
    assert(messenger.call("attach", owner: "one", viewId: "missing") as? Bool == false)
    assert(messenger.call("attach", owner: "one", viewId: "native-one") as? Bool == true)
    let firstSequence = messenger.events.last!.1["sequence"] as! Int
    // Reattaching the same physical host does not create a second observer.
    assert(messenger.call("attach", owner: "one", viewId: "native-one") as? Bool == true)
    let before = messenger.events.count
    first.scrollView.contentOffset.y += 20
    flush()
    assert(messenger.events.count == before + 1)

    assert(messenger.call("attach", owner: "popup", viewId: "native-popup") as? Bool == true)
    let popupAttached = messenger.events.count
    popup.scrollView.contentOffset.y += 20
    flush()
    assert(messenger.events.count == popupAttached + 1)
    assert(messenger.events.last!.0 == "app.browser_scroll/popup")
    assert(messenger.events.last!.1["viewId"] as? String == "native-popup")

    first.removeFromSuperview()
    let second = makeView(controller: scripts)
    identities[ObjectIdentifier(second)] = "native-one"
    window.addSubview(second)
    flush()
    assert(messenger.call("attach", owner: "one", viewId: "native-one") as? Bool == true)
    assert(messenger.events.last!.1["sequence"] as! Int > firstSequence)
    let swapped = messenger.events.count
    first.scrollView.contentOffset.y += 20
    flush()
    assert(messenger.events.count == swapped, "The replaced host must be detached")
    second.scrollView.contentOffset.y += 20
    flush()
    assert(messenger.events.count == swapped + 1)

    // A replacement owner takes the host; late old-owner release is harmless.
    assert(messenger.call("attach", owner: "two", viewId: "native-one") as? Bool == true)
    _ = messenger.call("detach", owner: "one")
    let adopted = messenger.events.count
    second.scrollView.contentOffset.y += 20
    flush()
    assert(messenger.events.count == adopted + 1)
    assert(messenger.events.last!.0 == "app.browser_scroll/two")
    _ = messenger.call("visibility", owner: "two", visible: false)
    let hidden = messenger.events.count
    second.scrollView.contentOffset.y += 20
    flush()
    assert(messenger.events.count == hidden)
    _ = messenger.call("visibility", owner: "two", visible: true)
    assert(messenger.events.last!.1["phase"] as? String == "reset")
    bridge.dispose()
    let disposed = messenger.events.count
    second.scrollView.contentOffset.y += 20
    flush()
    assert(messenger.events.count == disposed)
    print("Browser scroll bridge: exact host identity with shared popup scripts/same URLs, idempotent attach, view/owner handoff, visibility and disposal passed")
  }
}
