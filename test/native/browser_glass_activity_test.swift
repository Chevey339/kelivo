import Cocoa
import FlutterMacOS

private final class ActivityApplication: NSApplication {
  var activeForTest = true
  override var isActive: Bool { activeForTest }
}

private final class ActivityWindow: NSWindow {
  var keyForTest = true
  override var isKeyWindow: Bool { keyForTest }
}

private final class TestMessenger: NSObject, FlutterBinaryMessenger {
  var handlers: [String: FlutterBinaryMessageHandler] = [:]
  func send(onChannel channel: String, message: Data?) {}
  func send(onChannel channel: String, message: Data?, binaryReply: FlutterBinaryReply?) {
    binaryReply?(nil)
  }
  func setMessageHandlerOnChannel(
    _ channel: String, binaryMessageHandler handler: FlutterBinaryMessageHandler?
  ) -> FlutterBinaryMessengerConnection {
    handlers[channel] = handler
    return 1
  }
  func cleanUpConnection(_ connection: FlutterBinaryMessengerConnection) {}

  func call(_ method: String, arguments: [String: Any] = [:]) {
    let codec = FlutterStandardMethodCodec.sharedInstance()
    let message = codec.encode(FlutterMethodCall(methodName: method, arguments: arguments))
    handlers["app.browser_glass/1"]?(message) { _ in }
  }
}

@main
struct BrowserGlassActivityTest {
  static func main() {
    guard #available(macOS 26.0, *) else {
      print("Glass activity test requires macOS 26")
      return
    }
    let application = ActivityApplication.shared as! ActivityApplication
    precondition(NSApp === application)
    let window = ActivityWindow(
      contentRect: NSRect(x: 0, y: 0, width: 400, height: 200),
      styleMask: .borderless, backing: .buffered, defer: false
    )
    let otherWindow = ActivityWindow(
      contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false
    )
    let messenger = TestMessenger()
    let surface = BrowserGlassViewFactory(messenger: messenger).create(
      withViewIdentifier: 1,
      arguments: ["style": "liquid", "dark": true, "intensity": 0.0]
    )
    surface.frame = window.contentView!.bounds
    window.contentView!.addSubview(surface)
    surface.layoutSubtreeIfNeeded()
    let glass = surface.subviews.first as! NSGlassEffectView
    let wash = glass.contentView!
    func color() -> NSColor {
      NSColor(cgColor: wash.layer!.backgroundColor!)!.usingColorSpace(.deviceRGB)!
    }
    precondition(color().alphaComponent == 0)

    window.keyForTest = false
    NotificationCenter.default.post(name: NSWindow.didResignKeyNotification, object: otherWindow)
    precondition(color().alphaComponent == 0, "Another window must not change this material")
    NotificationCenter.default.post(name: NSWindow.didResignKeyNotification, object: window)
    let inactive = color()
    let overWhite = inactive.redComponent * inactive.alphaComponent + 1 - inactive.alphaComponent
    precondition(overWhite < 0.25, "White browser controls must stay legible over a white page")
    precondition(surface.subviews.first === glass, "Focus must not recreate the live glass")

    window.keyForTest = true
    NotificationCenter.default.post(name: NSWindow.didBecomeKeyNotification, object: window)
    precondition(color().alphaComponent == 0, "Foreground glass must regain its original transparency")
    application.activeForTest = false
    NotificationCenter.default.post(name: NSApplication.didResignActiveNotification, object: application)
    precondition(color().alphaComponent > 0.8)
    application.activeForTest = true
    NotificationCenter.default.post(name: NSApplication.didBecomeActiveNotification, object: application)
    precondition(color().alphaComponent == 0)

    application.activeForTest = false
    messenger.call("update", arguments: ["dark": false])
    let lightGlass = surface.subviews.first as! NSGlassEffectView
    precondition(lightGlass.contentView!.layer!.backgroundColor!.alpha == 0)
    messenger.call("update", arguments: ["style": "frosted", "dark": true])
    let blur = surface.subviews.first as! NSVisualEffectView
    precondition(blur.state == .active)
    messenger.call("dispose")
    NotificationCenter.default.post(name: NSApplication.didBecomeActiveNotification, object: application)
    precondition(surface.subviews.isEmpty, "Disposed material must not return on activation")
    precondition(!window.isVisible && !otherWindow.isVisible)
    print("Browser native glass activity checks passed")
  }
}
