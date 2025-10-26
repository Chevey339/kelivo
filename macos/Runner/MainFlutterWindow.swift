import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  // Layout helper: re-position the traffic light buttons
  private func layoutTrafficLightButton(titlebarView: NSView, button: NSButton, offsetTop: CGFloat, offsetLeft: CGFloat) {
    button.translatesAutoresizingMaskIntoConstraints = false
    titlebarView.addConstraint(NSLayoutConstraint(
      item: button,
      attribute: .top,
      relatedBy: .equal,
      toItem: titlebarView,
      attribute: .top,
      multiplier: 1,
      constant: offsetTop
    ))
    titlebarView.addConstraint(NSLayoutConstraint(
      item: button,
      attribute: .left,
      relatedBy: .equal,
      toItem: titlebarView,
      attribute: .left,
      multiplier: 1,
      constant: offsetLeft
    ))
  }

  private func layoutTrafficLights() {
    guard let closeButton = self.standardWindowButton(.closeButton),
          let minButton = self.standardWindowButton(.miniaturizeButton),
          let zoomButton = self.standardWindowButton(.zoomButton),
          let titlebarView = closeButton.superview else { return }

    self.layoutTrafficLightButton(titlebarView: titlebarView, button: closeButton, offsetTop: 14, offsetLeft: 12)
    self.layoutTrafficLightButton(titlebarView: titlebarView, button: minButton,  offsetTop: 14, offsetLeft: 30)
    self.layoutTrafficLightButton(titlebarView: titlebarView, button: zoomButton, offsetTop: 14, offsetLeft: 48)

    // Add a transparent accessory view to reserve 40pt height in the title bar
    let customToolbar = NSTitlebarAccessoryViewController()
    let newView = NSView()
    newView.frame = NSRect(origin: CGPoint(), size: CGSize(width: 0, height: 40))
    customToolbar.view = newView
    self.addTitlebarAccessoryViewController(customToolbar)
  }

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Customize title bar appearance for a clean, full-size content view
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden
    self.styleMask.insert(.fullSizeContentView)
    self.isMovableByWindowBackground = true

    // Place system traffic light buttons
    self.layoutTrafficLights()

    RegisterGeneratedPlugins(registry: flutterViewController)

    let channel = FlutterMethodChannel(name: "app.clipboard", binaryMessenger: flutterViewController.engine.binaryMessenger)
    channel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      if call.method == "getClipboardImages" {
        var paths: [String] = []
        let pb = NSPasteboard.general
        if let items = pb.pasteboardItems {
          for item in items {
            if let data = item.data(forType: .png) ?? item.data(forType: .tiff) {
              var outData: Data? = data
              if item.data(forType: .png) == nil {
                if let rep = NSBitmapImageRep(data: data) {
                  outData = rep.representation(using: .png, properties: [:])
                }
              }
              if let out = outData {
                let tmp = NSTemporaryDirectory()
                let filename = "pasted_\(Int(Date().timeIntervalSince1970 * 1000)).png"
                let url = URL(fileURLWithPath: tmp).appendingPathComponent(filename)
                do {
                  try out.write(to: url)
                  paths.append(url.path)
                } catch {
                  // ignore
                }
              }
            }
          }
        }
        result(paths)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }
}
