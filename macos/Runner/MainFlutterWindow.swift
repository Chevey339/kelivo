import Cocoa
import FlutterMacOS

private class TitleBarInteractionView: NSView {
  override var mouseDownCanMoveWindow: Bool { true }

  override func mouseDown(with event: NSEvent) {
    if event.clickCount >= 2 {
      window?.performZoom(nil)
      return
    }
    super.mouseDown(with: event)
  }
}

class MainFlutterWindow: NSWindow {
  // Use Cocoa autosave to persist and restore window frame precisely on macOS.
  private let autosaveName = NSWindow.FrameAutosaveName("KelivoMainWindowFrame")

  // Minimum reasonable content size to ensure the window is visible and usable.
  private let minContentSize = NSSize(width: 960, height: 640)

  // Clamp a size within min bounds and the given screen's visible frame
  private func clampedSize(_ size: NSSize, for screen: NSScreen?) -> NSSize {
    let minW = minContentSize.width
    let minH = minContentSize.height
    guard let s = screen?.visibleFrame.size else {
      return NSSize(width: max(size.width, minW), height: max(size.height, minH))
    }
    // Keep a small margin from full screen to avoid edge cases
    let maxW = max(minW, s.width - 20)
    let maxH = max(minH, s.height - 20)
    let w = max(minW, min(size.width, maxW))
    let h = max(minH, min(size.height, maxH))
    return NSSize(width: w, height: h)
  }

  // Returns true if a rect intersects any screen's visible frame meaningfully
  private func isRectOnAnyScreen(_ rect: NSRect) -> Bool {
    for screen in NSScreen.screens {
      if rect.intersects(screen.visibleFrame) { return true }
    }
    return false
  }

  // Some macOS setups can persist frames that are off‑screen or zero‑sized.
  // Normalize the frame so it's visible on the current main screen.
  private func normalizeFrameIfNeeded() {
    let frame = self.frame
    let invalidOrigin = !frame.origin.x.isFinite || !frame.origin.y.isFinite
    let tooSmall = frame.width < 100 || frame.height < 100
    let offScreen = !isRectOnAnyScreen(frame)
    if invalidOrigin || tooSmall || offScreen {
      let targetScreen = NSScreen.main ?? NSScreen.screens.first
      let targetSize = clampedSize(NSSize(width: max(frame.width, minContentSize.width),
                                          height: max(frame.height, minContentSize.height)),
                                   for: targetScreen)
      let vf = targetScreen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
      let newOrigin = NSPoint(
        x: vf.origin.x + (vf.size.width - targetSize.width) / 2,
        y: vf.origin.y + (vf.size.height - targetSize.height) / 2
      )
      let newFrame = NSRect(origin: newOrigin, size: targetSize)
      self.setFrame(newFrame, display: false)
      // Persist the corrected frame immediately so subsequent launches are safe
      self.saveFrame(usingName: autosaveName)
    }
  }
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
    let newView = TitleBarInteractionView()
    newView.frame = NSRect(origin: .zero, size: NSSize(width: 100, height: 40))
    customToolbar.view = newView
    if #available(macOS 11.0, *) {
      customToolbar.layoutAttribute = .right
    }
    self.addTitlebarAccessoryViewController(customToolbar)
  }

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    // Customize title bar appearance for a clean, full-size content view
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden
    self.styleMask.insert(.fullSizeContentView)
    self.isMovableByWindowBackground = true
    if #available(macOS 15.0, *) {
      self.isMovable = true
    }
    // Enforce a minimum content size so users can't shrink below usable bounds
    self.contentMinSize = minContentSize

    // Now enable autosave and restore the last saved frame (post style configuration)
    _ = self.setFrameAutosaveName(autosaveName)
    _ = self.setFrameUsingName(autosaveName, force: false)
    // Guard against saved frames that are off-screen or invalid sizes
    normalizeFrameIfNeeded()

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
      } else if call.method == "getClipboardFiles" {
        var files: [String] = []
        let pb = NSPasteboard.general
        if let items = pb.pasteboardItems {
          for item in items {
            if let urlString = item.string(forType: .fileURL), let url = URL(string: urlString) {
              files.append(url.path)
            }
          }
        }
        result(files)
      } else if call.method == "setClipboardImage" {
        guard let args = call.arguments as? String else {
          result(false)
          return
        }
        let url = URL(fileURLWithPath: args)
        do {
          var data = try Data(contentsOf: url)
          // Ensure PNG data; if not PNG, transcode to PNG
          if data.count < 8 || !(data[0] == 0x89 && data[1] == 0x50 && data[2] == 0x4E && data[3] == 0x47) {
            if let img = NSImage(contentsOf: url) {
              if let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) {
                data = png
              }
            }
          }
          let pb = NSPasteboard.general
          pb.clearContents()
          pb.setData(data, forType: .png)
          result(true)
        } catch {
          result(false)
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }
}
