// Compile with ios/Runner/BrowserGlassView.swift and the simulator Flutter
// framework, then run the executable with `xcrun simctl spawn <device> <path>`.
// Pass browser_viewport_anchor.dart, then 2000px or 200dvh; optionally add overflow.
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

  static func installAnchor(_ configuration: WKWebViewConfiguration) {
    let source = try! String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8)
    let script = source.components(separatedBy: "r'''")
    precondition(script.count == 2)
    let javascript = script[1].components(separatedBy: "'''")[0]
    configuration.userContentController.addUserScript(WKUserScript(
      source: javascript, injectionTime: .atDocumentStart, forMainFrameOnly: true))
  }

  static func makeView(marker: String) -> WKWebView {
    let config = WKWebViewConfiguration()
    config.userContentController.addUserScript(WKUserScript(
      source: marker, injectionTime: .atDocumentStart, forMainFrameOnly: true))
    installAnchor(config)
    return InsetsTestWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844), configuration: config)
  }

  @available(iOS 26.0, *)
  static func testTopInsets(window: UIWindow) {
    let marker = "/* kelivo-browser-tab:dG9w */"
    let view = makeView(marker: marker)
    view.scrollView.contentInsetAdjustmentBehavior = .never
    window.addSubview(view)
    let messenger = InsetsTestMessenger()
    let bridge = BrowserViewportInsetsBridge()
    bridge.register(messenger: messenger, window: window) { _ in "top" }
    defer {
      bridge.dispose()
      view.removeFromSuperview()
    }
    let navigation = InsetsTestNavigation()
    view.navigationDelegate = navigation
    func load(height: String) {
      navigation.loaded = false
      view.loadHTMLString("""
        <!doctype html><meta name="viewport" content="width=device-width,initial-scale=1">
        <body style="margin:0"><div id="header" style="height:44px">Header</div>
        <div style="height:\(height)">Document</div></body>
        """, baseURL: nil)
      waitUntil { navigation.loaded }
      RunLoop.main.run(until: Date().addingTimeInterval(0.1))
    }
    func apply(top: Double) {
      precondition(messenger.call("setBrowserViewportInsets", [
        "owner": "top-host", "marker": marker, "top": top, "bottom": 98.0
      ]) as? Bool == true)
    }
    func resize(top: Double, size: CGSize, insetFirst: Bool) {
      if insetFirst { apply(top: top) }
      view.frame.size = size
      if !insetFirst { apply(top: top) }
    }
    func checkPosition(_ expected: Double, _ message: String) {
      RunLoop.main.run(until: Date().addingTimeInterval(0.1))
      let actual = evaluate(view, "window.scrollY") as! Double
      precondition(abs(actual - expected) < 0.5, "\(message): expected \(expected), got \(actual)")
      let header = evaluate(view, "document.getElementById('header').getBoundingClientRect().top") as! Double
      precondition(abs(header + expected) < 0.5, "The document header must retain its viewport position")
    }

    // A retained/headless page can finish loading before its visible host
    // receives the inset. Attaching it must not scroll past the page header.
    load(height: "2000px")
    checkPosition(0, "Initial document position")
    apply(top: 59)
    checkPosition(0, "Attaching a loaded page must retain its header")

    for height in ["2000px", "100px"] {
      load(height: height)
      checkPosition(0, "Navigation must start below the status bar")
      for insetFirst in [true, false] {
        resize(top: 0, size: CGSize(width: 844, height: 390), insetFirst: insetFirst)
        checkPosition(0, "Landscape must retain the page top")
        resize(top: 59, size: CGSize(width: 390, height: 844), insetFirst: insetFirst)
        checkPosition(0, "Portrait must retain the page top")
      }
    }

    load(height: "2000px")
    _ = evaluate(view, "window.scrollTo(0, 500)")
    checkPosition(500, "Reading position before inset changes")
    for top in [0.0, 59.0, 20.0, 59.0] {
      apply(top: top)
      view.frame = view.frame
      checkPosition(500, "Inset changes must preserve the reading position")
    }
    _ = messenger.call("releaseBrowserViewportInsets", "top-host")
    checkPosition(500, "Releasing the host must preserve the reading position")
    apply(top: 59)
    checkPosition(500, "Reattaching the host must preserve the reading position")

    _ = evaluate(view, "window.scrollTo(0, document.documentElement.scrollHeight - innerHeight - 20)")
    RunLoop.main.run(until: Date().addingTimeInterval(0.1))
    apply(top: 0)
    RunLoop.main.run(until: Date().addingTimeInterval(0.1))
    var end = evaluate(view, "document.documentElement.scrollHeight - innerHeight") as! Double
    checkPosition(end, "An expanded viewport must clamp a near-bottom position to the new end")
    apply(top: 59)
    RunLoop.main.run(until: Date().addingTimeInterval(0.1))
    end = evaluate(view, "document.documentElement.scrollHeight - innerHeight") as! Double
    checkPosition(end, "A reached footer must remain visible when the viewport shrinks again")

    load(height: "200dvh")
    _ = evaluate(view, "window.scrollTo(0, document.documentElement.scrollHeight - innerHeight - 20)")
    RunLoop.main.run(until: Date().addingTimeInterval(0.1))
    let readingPosition = evaluate(view, "window.scrollY") as! Double
    for top in [0.0, 59.0] {
      apply(top: top)
      checkPosition(readingPosition, "Reflowing dvh content must retain a legal reading position")
    }
    _ = messenger.call("releaseBrowserViewportInsets", "top-host")
    checkPosition(readingPosition, "Releasing a dvh page must use its expanded document bounds")
    apply(top: 59)
    checkPosition(readingPosition, "Reattaching a dvh page must retain its reading position")
  }

  static func main() {
    guard #available(iOS 26.0, *) else {
      fatalError("Requires iOS 26 obscured-content-inset API")
    }
    let firstMarker = "/* kelivo-browser-tab:Zmlyc3Q= */"
    let secondMarker = "/* kelivo-browser-tab:c2Vjb25k */"
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    window.isHidden = false
    testTopInsets(window: window)
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
    let documentHeight = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "2000px"
    let overflow = CommandLine.arguments.count > 3 && CommandLine.arguments[3] == "overflow"
    let html = """
      \(overflow ? "<!doctype html>" : "")
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <body style="margin:0;\(overflow ? "height:100vh" : "")">
        \(overflow ? "<div style='position:absolute;top:0;left:0;width:100%'>" : "")
        <div style="height:\(documentHeight)"></div>
        <button id="footer" style="display:block;height:44px">Footer</button>
        \(overflow ? "</div>" : "")
        <button id="fixed" style="position:fixed;bottom:0;right:0;height:44px">Fixed</button>
      </body>
      """
    first.loadHTMLString(html, baseURL: nil)
    waitUntil { navigation.loaded && first.scrollView.contentSize.height > first.bounds.height }
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

    for top in [0.0, 59.0, 20.0, 59.0] {
      precondition(apply(firstMarker, top: top))
      first.frame = first.frame
      // The WebKit process must finish viewport-relative CSS reflow and its
      // resize handler before the ordinary footer reaches the new boundary.
      waitUntil {
        let footer = evaluate(first, "document.getElementById('footer').getBoundingClientRect().bottom") as! Double
        return abs(footer - (844 - top - 98)) < 0.5
      }
    }

    // Both directions of the chrome animation must keep a reached footer
    // visible, including the compact 64-point reservation on this device.
    for bottom in [94.0, 86.0, 74.0, 64.0, 74.0, 86.0, 94.0, 98.0] {
      precondition(apply(firstMarker, bottom: bottom))
      first.frame = first.frame
      RunLoop.main.run(until: Date().addingTimeInterval(0.1))
      let geometry = evaluate(first, """
        ({height:innerHeight,
          footer:document.getElementById('footer').getBoundingClientRect().bottom,
          fixed:document.getElementById('fixed').getBoundingClientRect().bottom})
        """) as! [String: Double]
      let expected = 844 - 59 - bottom
      precondition(geometry["height"] == expected, "Viewport must follow toolbar height")
      precondition(geometry["footer"] == expected, "Reached footer must follow inset \(bottom): \(geometry)")
      precondition(geometry["fixed"] == expected, "Fixed footer must follow inset \(bottom)")
    }

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

    // A finger can already be rubber-banding beyond the old end when the dock
    // expands. That still needs a bottom anchor, with its overscroll retained.
    precondition(apply(firstMarker, bottom: 64))
    RunLoop.main.run(until: Date().addingTimeInterval(0.1))
    first.scrollView.contentOffset.y += 10
    for bottom in [70.0, 80.0, 90.0, 98.0] {
      precondition(apply(firstMarker, bottom: bottom))
      RunLoop.main.run(until: Date().addingTimeInterval(0.1))
      let footer = evaluate(first, "document.getElementById('footer').getBoundingClientRect().bottom") as! Double
      precondition(footer <= 844 - 59 - bottom,
                   "Rubber-band recovery must keep the footer above expanding chrome")
    }

    _ = evaluate(first, "window.scrollTo(0, 500)")
    RunLoop.main.run(until: Date().addingTimeInterval(0.1))
    let readingOffset = first.scrollView.contentOffset
    for bottom in [64.0, 98.0] {
      precondition(apply(firstMarker, bottom: bottom))
      first.frame = first.frame
      RunLoop.main.run(until: Date().addingTimeInterval(0.1))
      precondition(first.scrollView.contentOffset == readingOffset,
                   "Chrome changes must not move a page that is not at its end")
    }

    _ = evaluate(first, "window.scrollTo(0, document.documentElement.scrollHeight - innerHeight)")
    RunLoop.main.run(until: Date().addingTimeInterval(0.1))
    let beforeAppend = first.scrollView.contentOffset
    let previousContentHeight = first.scrollView.contentSize.height
    _ = evaluate(first, """
      const extra = document.createElement('div');
      extra.style.height = '240px';
      \(overflow ? "extra.style.position = 'absolute'; extra.style.width = '100%'; extra.style.top = document.documentElement.scrollHeight + 'px';" : "")
      void document.body.appendChild(extra);
      """)
    waitUntil { first.scrollView.contentSize.height >= previousContentHeight + 239 }
    precondition(first.scrollView.contentOffset == beforeAppend,
                 "Appending content must not stick the browser to the new end")
    for bottom in [64.0, 98.0] {
      precondition(apply(firstMarker, bottom: bottom))
      RunLoop.main.run(until: Date().addingTimeInterval(0.1))
      precondition(first.scrollView.contentOffset == beforeAppend,
                   "A later chrome resize must not resurrect an old bottom anchor")
    }

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

    // Exercise the pre-iOS-26 path without native obscured insets: Flutter
    // changes the frame height while the same WKWebView stays mounted.
    let legacyConfig = WKWebViewConfiguration()
    installAnchor(legacyConfig)
    let legacy = InsetsTestWebView(frame: CGRect(x: 0, y: 59, width: 390, height: 687), configuration: legacyConfig)
    legacy.scrollView.contentInsetAdjustmentBehavior = .never
    window.addSubview(legacy)
    let legacyNavigation = InsetsTestNavigation()
    legacy.navigationDelegate = legacyNavigation
    legacy.loadHTMLString(html, baseURL: nil)
    waitUntil { legacyNavigation.loaded && legacy.scrollView.contentSize.height > legacy.bounds.height }
    _ = evaluate(legacy, "window.scrollTo(0, document.documentElement.scrollHeight - innerHeight)")
    RunLoop.main.run(until: Date().addingTimeInterval(0.1))
    for height in [695.0, 710.0, 721.0, 710.0, 695.0, 687.0] {
      legacy.frame.size.height = height
      RunLoop.main.run(until: Date().addingTimeInterval(0.1))
      let geometry = evaluate(legacy, """
        ({height:innerHeight,
          footer:document.getElementById('footer').getBoundingClientRect().bottom,
          fixed:document.getElementById('fixed').getBoundingClientRect().bottom})
        """) as! [String: Double]
      precondition(geometry["height"] == height)
      precondition(geometry["footer"] == height, "Physical viewport must retain its footer: \(geometry)")
      precondition(geometry["fixed"] == height)
    }
    _ = evaluate(legacy, "window.scrollTo(0, 500)")
    RunLoop.main.run(until: Date().addingTimeInterval(0.1))
    for height in [721.0, 687.0] {
      legacy.frame.size.height = height
      RunLoop.main.run(until: Date().addingTimeInterval(0.1))
      precondition(legacy.scrollView.contentOffset.y == 500,
                   "Physical viewport changes must preserve mid-document reading position")
    }
    print("iOS viewport insets: loaded-page attachment, rotation, top/reading anchors, dynamic native/physical viewports, normal/fixed footers, plugin frame resets, keyboard updates, tab transfer, crop and restoration passed")
  }
}
