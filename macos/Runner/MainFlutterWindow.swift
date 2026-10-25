import Cocoa
import FlutterMacOS
import WebKit

class MainFlutterWindow: NSWindow {
  private let systemPower = DesktopSystemPowerState()
  private var powerChannel: FlutterMethodChannel?
  private var browserChromeChannel: FlutterMethodChannel?
  private var browserShortcutMonitor: Any?
  private var sidebarResizeChannel: FlutterMethodChannel?
  private var sidebarResizeMonitor: Any?
  private var sidebarResizeFocusObserver: Any?
  private var sidebarResizeSession: Int?
  private weak var sidebarResizeController: FlutterViewController?
  private var sidebarResizeLastEvent: NSEvent?
  private var sidebarResizePress = SidebarResizePress()
  private var sidebarResizePressTimestamp: Int64?
  private var sidebarCursorOwner: Int?
  private var sidebarCursorBounds: NSRect?
  private weak var sidebarCursorController: FlutterViewController?
  private var sidebarCursorMonitor: Any?
  private var sidebarCursorFocusObserver: Any?
  private var sidebarCursorPoint: NSPoint?
  private let browserInsetLeases = BrowserViewportInsetLeases()
  private var trafficLightConstraints: [(top: NSLayoutConstraint, left: NSLayoutConstraint)] = []

  deinit {
    endSidebarResize(notify: false)
    if let monitor = sidebarCursorMonitor { NSEvent.removeMonitor(monitor) }
    if let observer = sidebarCursorFocusObserver { NotificationCenter.default.removeObserver(observer) }
    sidebarResizeChannel?.setMethodCallHandler(nil)
    releaseBrowserInsets()
    powerChannel?.setMethodCallHandler(nil)
    browserChromeChannel?.setMethodCallHandler(nil)
    if let monitor = browserShortcutMonitor { NSEvent.removeMonitor(monitor) }
  }

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
    let top = NSLayoutConstraint(
      item: button,
      attribute: .top,
      relatedBy: .equal,
      toItem: titlebarView,
      attribute: .top,
      multiplier: 1,
      constant: offsetTop
    )
    let left = NSLayoutConstraint(
      item: button,
      attribute: .left,
      relatedBy: .equal,
      toItem: titlebarView,
      attribute: .left,
      multiplier: 1,
      constant: offsetLeft
    )
    NSLayoutConstraint.activate([top, left])
    trafficLightConstraints.append((top: top, left: left))
  }

  // The pane's moving native overlays may replace the view that received
  // mouseDown. Own only this resize gesture at window level so its release
  // cannot disappear into a WKWebView or a newly-created Flutter overlay.
  override func sendEvent(_ event: NSEvent) {
    if event.type == .leftMouseDown {
      // Match FlutterViewController's timestamp conversion exactly.
      sidebarResizePress.begin(timestampMicros: Int64(event.timestamp * 1_000_000))
      sidebarResizeLastEvent = event
    } else if event.type == .leftMouseUp,
              let timestamp = sidebarResizePress.timestampMicros {
      sidebarResizePress.end(ifMatches: timestamp)
      sidebarResizeLastEvent = event
    }
    super.sendEvent(event)
  }

  private func setSidebarCursor(_ args: [String: Any], controller: FlutterViewController) {
    guard let owner = args["owner"] as? Int else { return }
    guard let rect = args["bounds"] as? [Double], rect.count == 4,
          rect.allSatisfy({ $0.isFinite }), rect[2] > 0, rect[3] > 0 else {
      if sidebarCursorOwner == owner {
        sidebarCursorOwner = nil
        sidebarCursorBounds = nil
        sidebarCursorPoint = nil
        if let observer = sidebarCursorFocusObserver { NotificationCenter.default.removeObserver(observer) }
        sidebarCursorFocusObserver = nil
        if let monitor = sidebarCursorMonitor { NSEvent.removeMonitor(monitor) }
        sidebarCursorMonitor = nil
        if sidebarResizeSession == nil, isKeyWindow {
          NSCursor.arrow.set()
          invalidateCursorRects(for: controller.view)
        }
      }
      return
    }
    sidebarCursorOwner = owner
    sidebarCursorBounds = NSRect(x: rect[0], y: rect[1], width: rect[2], height: rect[3])
    sidebarCursorController = controller
    if sidebarCursorMonitor == nil {
      sidebarCursorFocusObserver = NotificationCenter.default.addObserver(
        forName: NSWindow.didResignKeyNotification, object: self, queue: .main
      ) { [weak self] _ in self?.sidebarCursorPoint = nil }
      sidebarCursorMonitor = NSEvent.addLocalMonitorForEvents(
        matching: [.mouseMoved, .leftMouseDragged, .leftMouseUp, .cursorUpdate]
      ) { [weak self] event in
        guard let self = self, event.window === self else { return event }
        self.updateSidebarCursor(pointInWindow: event.locationInWindow)
        return event.type == .cursorUpdate && self.ownsSidebarCursor ? nil : event
      }
    }
    updateSidebarCursor(pointInWindow: mouseLocationOutsideOfEventStream)
  }

  private var ownsSidebarCursor: Bool {
    guard isKeyWindow else { return false }
    if sidebarResizeSession != nil { return true }
    guard let point = sidebarCursorPoint, let bounds = sidebarCursorBounds else { return false }
    return bounds.contains(point)
  }

  private func updateSidebarCursor(pointInWindow: NSPoint) {
    guard isKeyWindow else { sidebarCursorPoint = nil; return }
    if let view = (sidebarCursorController ?? sidebarResizeController)?.view {
      let point = view.convert(pointInWindow, from: nil)
      sidebarCursorPoint = NSPoint(
        x: point.x, y: view.isFlipped ? point.y : view.bounds.height - point.y)
    }
    guard ownsSidebarCursor else { return }
    NSCursor.resizeLeftRight.set()
    // AppKit/WebKit cursorUpdate can run after the Flutter pointer dispatch.
    // Match FlutterView's next-runloop cursor restoration without an idle timer.
    RunLoop.main.perform { [weak self] in
      guard self?.ownsSidebarCursor == true else { return }
      NSCursor.resizeLeftRight.set()
    }
  }

  private func beginSidebarResize(
    _ session: Int, timestampMicros: Int64, controller: FlutterViewController
  ) -> Bool {
    guard isKeyWindow, sidebarResizePress.matches(timestampMicros) else { return false }
    guard sidebarResizePress.canCapture(timestampMicros) else {
      // The platform call arrived after this very press ended. If its old
      // overlay missed up, repair only this sequence, never a subsequent down.
      if let event = sidebarResizeLastEvent, event.type == .leftMouseUp {
        controller.mouseUp(with: event)
      }
      return false
    }
    endSidebarResize(notify: true, resetPointer: false)
    sidebarResizeSession = session
    sidebarResizePressTimestamp = timestampMicros
    sidebarResizeController = controller
    updateSidebarCursor(pointInWindow: sidebarResizeLastEvent?.locationInWindow ?? mouseLocationOutsideOfEventStream)
    sidebarResizeMonitor = NSEvent.addLocalMonitorForEvents(
      matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp, .mouseMoved, .cursorUpdate]
    ) { [weak self] event in
      guard let self = self, self.sidebarResizeSession != nil else { return event }
      guard self.isKeyWindow, event.window === self else {
        self.endSidebarResize(notify: true)
        return event
      }
      switch event.type {
      case .cursorUpdate:
        self.updateSidebarCursor(pointInWindow: event.locationInWindow)
        return nil
      case .leftMouseDragged:
        self.sidebarResizeLastEvent = event
        // Flutter's controller owns both button state and coordinate decoding.
        // Keep a single pointer stream even when its overlay view is replaced.
        self.sidebarResizeController?.mouseDragged(with: event)
        self.updateSidebarCursor(pointInWindow: event.locationInWindow)
        return nil
      case .leftMouseUp:
        self.endSidebarResize(notify: false, mouseUp: event)
        return nil
      default:
        // Hover or another down proves the old sequence has ended. Reset the
        // controller before normal AppKit dispatch; otherwise a lost up turns
        // that new down into a move belonging to the old Flutter pointer.
        self.endSidebarResize(notify: true)
        return event
      }
    }
    sidebarResizeFocusObserver = NotificationCenter.default.addObserver(
      forName: NSWindow.didResignKeyNotification, object: self, queue: .main
    ) { [weak self] _ in self?.endSidebarResize(notify: true) }
    return true
  }

  private func endSidebarResize(
    notify: Bool, mouseUp: NSEvent? = nil, resetPointer: Bool = true
  ) {
    let session = sidebarResizeSession
    let controller = sidebarResizeController
    let lastEvent = sidebarResizeLastEvent
    let timestamp = sidebarResizePressTimestamp
    let shouldRelease = resetPointer && timestamp.map { sidebarResizePress.end(ifMatches: $0) } == true
    sidebarResizeSession = nil
    sidebarResizeController = nil
    sidebarResizePressTimestamp = nil
    if let monitor = sidebarResizeMonitor { NSEvent.removeMonitor(monitor) }
    sidebarResizeMonitor = nil
    if let observer = sidebarResizeFocusObserver { NotificationCenter.default.removeObserver(observer) }
    sidebarResizeFocusObserver = nil
    if notify, let session = session {
      sidebarResizeChannel?.invokeMethod("end", arguments: ["session": session])
    }
    if let event = mouseUp { sidebarResizeLastEvent = event }
    if session != nil, isKeyWindow, !ownsSidebarCursor {
      NSCursor.arrow.set()
      if let view = controller?.view { invalidateCursorRects(for: view) }
    }
    guard shouldRelease, let controller = controller else { return }
    // NSResponder's view forwarding depends on the current responder chain.
    // Target the same controller that decoded down, including cancellation.
    let release = mouseUp ?? NSEvent.mouseEvent(
      with: .leftMouseUp,
      location: lastEvent?.locationInWindow ?? mouseLocationOutsideOfEventStream,
      modifierFlags: lastEvent?.modifierFlags ?? [],
      timestamp: lastEvent?.timestamp ?? ProcessInfo.processInfo.systemUptime,
      windowNumber: windowNumber, context: nil,
      eventNumber: lastEvent?.eventNumber ?? 0, clickCount: 1, pressure: 0)
    if let release = release {
      controller.mouseUp(with: release)
      updateSidebarCursor(pointInWindow: release.locationInWindow)
    }
  }

  private func setBrowserChrome(_ enabled: Bool) {
    // Center the 14-point system buttons within the browser's 44-point tab row.
    // Restore the existing app layout when its route closes.
    for (index, constraints) in trafficLightConstraints.enumerated() {
      constraints.top.constant = enabled ? 15 : 14
      constraints.left.constant = enabled ? 20 + CGFloat(index) * 24 : 12 + CGFloat(index) * 18
    }
    standardWindowButton(.closeButton)?.superview?.layoutSubtreeIfNeeded()
  }

  private func setBrowserShortcuts(_ enabled: Bool) {
    if let monitor = browserShortcutMonitor {
      NSEvent.removeMonitor(monitor)
      browserShortcutMonitor = nil
    }
    guard enabled else { return }
    // WKWebView and AppKit menu key equivalents can consume these before
    // Flutter sees them. Scope interception to this window's current browser
    // route; the Dart host disables it while another route covers the browser.
    browserShortcutMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
      [weak self] event in
      guard let self = self, event.window === self, self.isKeyWindow,
            event.modifierFlags.intersection(.deviceIndependentFlagsMask)
              .subtracting(.capsLock) == .command,
            let key = event.charactersIgnoringModifiers?.lowercased(),
            ["f", "l", "t", "w", "r"].contains(key) else { return event }
      if !event.isARepeat {
        self.browserChromeChannel?.invokeMethod("shortcut", arguments: key)
      }
      // Consume the original event, including autorepeat, so neither the
      // native main menu nor Flutter's fallback shortcuts execute it twice.
      return nil
    }
  }

  private func releaseBrowserInsets(owner: String? = nil) {
    browserInsetLeases.release(owner: owner)
  }

  private func setBrowserInsets(_ values: [String: Any]) -> Bool {
    guard #available(macOS 26.0, *),
          let owner = values["owner"] as? String,
          let marker = values["marker"] as? String,
          marker.hasPrefix("/* kelivo-browser-tab:"),
          let top = values["top"] as? Double, top.isFinite, top >= 0,
          let contentView = contentView else { return false }
    var candidates: [WKWebView] = []
    func visit(_ view: NSView) {
      guard !view.isHiddenOrHasHiddenAncestor else { return }
      if let webView = view as? WKWebView,
         webView.window === self,
         webView.configuration.userContentController.userScripts.contains(where: { $0.source == marker }) {
        candidates.append(webView)
      }
      for child in view.subviews { visit(child) }
    }
    visit(contentView)
    // Never guess among unrelated/temporarily duplicated platform views.
    guard candidates.count == 1, let target = candidates.first else { return false }
    return browserInsetLeases.apply(to: target, owner: owner, top: CGFloat(top))
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
    let glassRegistrar = flutterViewController.registrar(forPlugin: "BrowserGlass")
    glassRegistrar.register(
      BrowserGlassViewFactory(messenger: glassRegistrar.messenger),
      withId: "app.browser_glass"
    )

    browserChromeChannel = FlutterMethodChannel(
      name: "app.browser_window", binaryMessenger: flutterViewController.engine.binaryMessenger)
    browserChromeChannel?.setMethodCallHandler { [weak self] call, result in
      if call.method == "supportsBrowserViewportInsets" {
        if #available(macOS 26.0, *) { result(true) } else { result(false) }
        return
      }
      if call.method == "setBrowserViewportInsets" {
        result(self?.setBrowserInsets(call.arguments as? [String: Any] ?? [:]) ?? false)
        return
      }
      if call.method == "releaseBrowserViewportInsets" {
        if let owner = call.arguments as? String { self?.releaseBrowserInsets(owner: owner) }
        result(nil)
        return
      }
      guard let enabled = call.arguments as? Bool else {
        result(FlutterMethodNotImplemented)
        return
      }
      switch call.method {
      case "setBrowserChrome": self?.setBrowserChrome(enabled)
      case "setBrowserShortcuts": self?.setBrowserShortcuts(enabled)
      default:
        result(FlutterMethodNotImplemented)
        return
      }
      result(nil)
    }

    sidebarResizeChannel = FlutterMethodChannel(
      name: "app.sidebar_resize", binaryMessenger: flutterViewController.engine.binaryMessenger)
    sidebarResizeChannel?.setMethodCallHandler { [weak self, weak flutterViewController] call, result in
      guard let self = self, let controller = flutterViewController else {
        result(false)
        return
      }
      if call.method == "begin", let args = call.arguments as? [String: Any],
         let session = args["session"] as? Int,
         let timestamp = args["timestampMicros"] as? Int64 {
        result(self.beginSidebarResize(session, timestampMicros: timestamp, controller: controller))
      } else if call.method == "end", let session = call.arguments as? Int {
        if self.sidebarResizeSession == session { self.endSidebarResize(notify: false) }
        result(nil)
      } else if call.method == "cursor", let args = call.arguments as? [String: Any] {
        self.setSidebarCursor(args, controller: controller)
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    powerChannel = FlutterMethodChannel(name: "app.desktop_power",
                                       binaryMessenger: flutterViewController.engine.binaryMessenger)
    powerChannel?.setMethodCallHandler { [weak self] call, result in
      guard call.method == "state", let self = self else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(self.systemPower.snapshot)
    }


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
