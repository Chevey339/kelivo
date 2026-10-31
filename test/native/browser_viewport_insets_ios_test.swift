// Compile with ios/Runner/BrowserGlassView.swift and the simulator Flutter
// framework, then run the executable with `xcrun simctl spawn <device> <path>`.
// Real WKWebViews exercise the bridge without launching Kelivo or taking images.
import Flutter
import UIKit
import WebKit

private final class InsetsTestMessenger: NSObject, FlutterBinaryMessenger {
  private let codec = FlutterStandardMethodCodec.sharedInstance()
  private var handlers: [String: FlutterBinaryMessageHandler] = [:]

  func send(onChannel channel: String, message: Data?) {}
  func send(onChannel channel: String, message: Data?, binaryReply: FlutterBinaryReply?) {
    binaryReply?(codec.encodeSuccessEnvelope(nil))
  }
  func setMessageHandlerOnChannel(
    _ channel: String, binaryMessageHandler handler: FlutterBinaryMessageHandler?
  ) -> FlutterBinaryMessengerConnection {
    handlers[channel] = handler
    return 1
  }
  func cleanUpConnection(_ connection: FlutterBinaryMessengerConnection) {}

  func call(_ method: String, _ arguments: Any? = nil) -> Any? {
    var result: Any?
    var replied = false
    handlers["app.browser_window"]?(
      codec.encode(FlutterMethodCall(methodName: method, arguments: arguments))
    ) { response in
      if let response { result = self.codec.decodeEnvelope(response) }
      replied = true
    }
    precondition(replied)
    return result
  }
}

private final class InsetsTestNavigation: NSObject, WKNavigationDelegate {
  var loaded = false
  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    loaded = true
  }
}

// Match the frame setter in flutter_inappwebview_ios/InAppWebView.swift. Flutter
// reuses this path when attaching retained views and resizing the platform host.
private final class InsetsTestWebView: WKWebView {
  override var frame: CGRect {
    get { super.frame }
    set {
      super.frame = newValue
      scrollView.contentInset = .zero
      if scrollView.adjustedContentInset != .zero {
        let adjusted = scrollView.adjustedContentInset
        scrollView.contentInset = UIEdgeInsets(
          top: -adjusted.top, left: -adjusted.left,
          bottom: -adjusted.bottom, right: -adjusted.right)
      }
    }
  }
}

@main
private struct BrowserViewportInsetsIOSTest {
  static func waitUntil(_ predicate: () -> Bool) {
    let deadline = Date().addingTimeInterval(10)
    while !predicate() && Date() < deadline {
      RunLoop.main.run(until: Date().addingTimeInterval(0.01))
    }
    precondition(predicate(), "WebKit operation timed out")
  }

  static func evaluate(_ webView: WKWebView, _ source: String) -> Any? {
    var complete = false
    var output: Any?
    webView.evaluateJavaScript(source) { value, error in
      precondition(error == nil, "JavaScript failed: \(String(describing: error))")
      output = value
      complete = true
    }
    waitUntil { complete }
    return output
  }

  static func makeView(marker: String) -> WKWebView {
    let config = WKWebViewConfiguration()
    config.userContentController.addUserScript(WKUserScript(
      source: marker, injectionTime: .atDocumentStart, forMainFrameOnly: true))
    return InsetsTestWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844), configuration: config)
  }

  static func main() {
    guard #available(iOS 26.0, *) else {
      fatalError("Requires iOS 26 obscured-content-inset API")
    }
    let firstMarker = "/* kelivo-browser-tab:Zmlyc3Q= */"
    let secondMarker = "/* kelivo-browser-tab:c2Vjb25k */"
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    window.isHidden = false
    let first = makeView(marker: firstMarker)
    let second = makeView(marker: secondMarker)
    window.addSubview(first)
    window.addSubview(second)
    let original = UIEdgeInsets(top: 3, left: 2, bottom: 4, right: 5)
    first.obscuredContentInsets = original
    second.scrollView.contentInset.bottom = 7
    let messenger = InsetsTestMessenger()
    let bridge = BrowserViewportInsetsBridge()
    bridge.register(messenger: messenger, window: window) {
      $0 === first ? "first" : "second"
    }
    func apply(_ marker: String, owner: String = "host", top: Double = 59,
               bottom: Double = 98) -> Bool {
      messenger.call("setBrowserViewportInsets", [
        "owner": owner, "marker": marker, "top": top, "bottom": bottom
      ]) as? Bool == true
    }
    precondition(messenger.call("supportsBrowserViewportInsets") as? Bool == true)
    precondition(apply(firstMarker))
    precondition(first.obscuredContentInsets == UIEdgeInsets(top: 59, left: 2, bottom: 98, right: 5))
    precondition(first.scrollView.contentInset.bottom == 98)
    let rect = messenger.call("browserSnapshotRect", "first") as! [String: Double]
    precondition(rect["y"] == 59 && rect["height"] == 687,
                 "Thumbnails must exclude both browser controls and the status bar")

    let navigation = InsetsTestNavigation()
    first.navigationDelegate = navigation
    first.scrollView.contentInsetAdjustmentBehavior = .never
    first.loadHTMLString("""
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <body style="margin:0">
        <div style="height:2000px"></div>
        <button id="footer" style="display:block;height:44px">Footer</button>
        <button id="fixed" style="position:fixed;bottom:0;right:0;height:44px">Fixed</button>
      </body>
      """, baseURL: nil)
    waitUntil { navigation.loaded }
    _ = evaluate(first, "window.scrollTo(0, document.documentElement.scrollHeight - innerHeight)")
    RunLoop.main.run(until: Date().addingTimeInterval(0.3))
    let metrics = evaluate(first, """
      ({height:innerHeight,
        footer:document.getElementById('footer').getBoundingClientRect().bottom,
        fixed:document.getElementById('fixed').getBoundingClientRect().bottom})
      """) as! [String: Double]
    precondition(metrics["height"] == 687)
    precondition(metrics["footer"] == 687, "Ordinary footers must scroll above the toolbar")
    precondition(metrics["fixed"] == 687, "Fixed website controls must avoid the toolbar")
    precondition(evaluate(first, """
      ['footer', 'fixed'].every(id => {
        const element = document.getElementById(id);
        const rect = element.getBoundingClientRect();
        const hit = document.elementFromPoint(rect.left + rect.width / 2, rect.top + rect.height / 2);
        return hit === element;
      })
      """) as? Bool == true, "Both footer buttons must remain hit-testable")

    // Restoring the inset alone is insufficient: UIKit can move contentOffset
    // during each reset, pushing an already reached footer below the controls.
    let bottomOffset = first.scrollView.contentOffset
    for _ in 0..<3 {
      first.frame = first.frame
      precondition(first.scrollView.contentInset.bottom == 98)
      precondition(first.scrollView.contentOffset == bottomOffset,
                   "Plugin frame updates must preserve the reached document footer")
    }
    RunLoop.main.run(until: Date().addingTimeInterval(0.3))
    precondition(evaluate(first, "document.getElementById('footer').getBoundingClientRect().bottom") as? Double == 687,
                 "The footer must stay visible after native frame updates")

    // Keyboard changes update inactive retained views as well as the active tab.
    precondition(apply(secondMarker, bottom: 64))
    precondition(first.obscuredContentInsets.bottom == 64)
    precondition(second.obscuredContentInsets.bottom == 64)
    precondition(first.scrollView.contentInset.bottom == 64)
    precondition(second.scrollView.contentInset.bottom == 71)
    precondition(apply(secondMarker, top: 20, bottom: 85))
    precondition(first.obscuredContentInsets.top == 20)
    precondition(first.obscuredContentInsets.bottom == 85)
    precondition(first.scrollView.contentInset.bottom == 85)
    precondition(!apply(firstMarker, bottom: -.infinity))
    precondition(!apply(firstMarker, bottom: -1))
    precondition(!apply(firstMarker, bottom: .nan))
    precondition(first.obscuredContentInsets.bottom == 85)

    // Transferring a tab preserves its original insets for eventual disposal.
    precondition(apply(firstMarker, owner: "replacement", top: 59, bottom: 98))
    _ = messenger.call("releaseBrowserViewportInsets", "host")
    precondition(first.obscuredContentInsets.bottom == 98)
    precondition(second.obscuredContentInsets == .zero)
    precondition(first.scrollView.contentInset.bottom == 98)
    precondition(second.scrollView.contentInset.bottom == 7)
    _ = messenger.call("releaseBrowserViewportInsets", "replacement")
    precondition(first.obscuredContentInsets == original)
    precondition(first.scrollView.contentInset.bottom == 0)
    // Releasing a lease must also remove its content-inset observer.
    first.scrollView.contentInset.bottom = 6
    precondition(first.scrollView.contentInset.bottom == 6)
    precondition(apply(firstMarker))
    precondition(first.scrollView.contentInset.bottom == 104)
    bridge.dispose()
    precondition(first.obscuredContentInsets == original)
    precondition(first.scrollView.contentInset.bottom == 6)
    print("iOS viewport insets: normal/fixed footers, plugin frame resets, keyboard updates, tab transfer, crop and restoration passed")
  }
}
