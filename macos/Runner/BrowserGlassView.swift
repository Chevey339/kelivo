import Cocoa
import FlutterMacOS

final class BrowserGlassViewFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func createArgsCodec() -> (FlutterMessageCodec & NSObjectProtocol)? {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(withViewIdentifier viewId: Int64, arguments args: Any?) -> NSView {
    BrowserGlassSurface(
      viewId: viewId,
      arguments: args as? [String: Any] ?? [:],
      messenger: messenger
    )
  }
}

/// A passive, within-window material. No bitmap capture or desktop-wide blur.
private final class BrowserGlassSurface: NSView {
  private let channel: FlutterMethodChannel
  private let wash = NSView()
  private var material: NSView?
  private var radius: Double = 28
  private var style = "liquid"
  private var dark = false
  private var clear = false
  private var elevated = true
  private var intensity: Double = 0
  private var outset: Double = 0
  private var effectKey: String?
  private var disposed = false

  init(viewId: Int64, arguments: [String: Any], messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "app.browser_glass/\(viewId)",
      binaryMessenger: messenger
    )
    super.init(frame: .zero)
    wantsLayer = true
    layer?.backgroundColor = NSColor.clear.cgColor
    layer?.masksToBounds = false
    clipsToBounds = false
    wash.wantsLayer = true
    wash.autoresizingMask = [.width, .height]
    setAccessibilityElement(false)
    NSWorkspace.shared.notificationCenter.addObserver(
      self,
      selector: #selector(accessibilityChanged),
      name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
      object: nil
    )
    for name in [NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification,
                 NSApplication.didBecomeActiveNotification, NSApplication.didResignActiveNotification] {
      NotificationCenter.default.addObserver(
        self, selector: #selector(activityChanged(_:)), name: name, object: nil
      )
    }
    update(arguments)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }
      switch call.method {
      case "update":
        self.update(call.arguments as? [String: Any] ?? [:])
        result(nil)
      case "dispose":
        self.dispose()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override var isOpaque: Bool { false }
  override func hitTest(_ point: NSPoint) -> NSView? { nil }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    guard !disposed else { return }
    updateMaterial()
  }

  @objc private func activityChanged(_ notification: Notification) {
    guard !disposed else { return }
    if let changedWindow = notification.object as? NSWindow, changedWindow !== window { return }
    updateMaterial()
  }

  override func layout() {
    super.layout()
    material?.frame = materialFrame
    // NSGlassEffectView owns its contentView layout. A manual full-host frame
    // would include the shadow margin in the optical surface.
    if #available(macOS 26.0, *), material is NSGlassEffectView {
      // AppKit maintains the contentView constraints.
    } else {
      wash.frame = material?.bounds ?? .zero
    }
    updateCorners()
  }

  private var materialFrame: NSRect {
    NSRect(
      x: outset,
      y: outset,
      width: max(0, bounds.width - outset * 2),
      height: max(0, bounds.height - outset * 2)
    )
  }

  private func update(_ values: [String: Any]) {
    guard !disposed else { return }
    if let value = values["radius"] as? Double, value.isFinite {
      radius = min(4096, max(0, value))
    }
    if let value = values["style"] as? String,
       ["liquid", "frosted", "solid"].contains(value) {
      style = value
    }
    dark = values["dark"] as? Bool ?? dark
    clear = values["clear"] as? Bool ?? clear
    elevated = values["elevated"] as? Bool ?? elevated
    if let value = values["intensity"] as? Double, value.isFinite {
      intensity = min(1, max(0, value))
    }
    if let value = values["opacity"] as? Double, value.isFinite {
      // The native material and its shadow fade together, without a Flutter
      // offscreen opacity layer between this surface and the live webpage.
      alphaValue = CGFloat(min(1, max(0, value)))
    }
    if let value = values["outset"] as? Double, value.isFinite {
      // Match the Flutter host's shadow allowance (zero for an attached
      // header). The material stays at the original control size.
      outset = min(64, max(0, value))
    }
    appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
    updateMaterial()
    updateCorners()
  }

  @objc private func accessibilityChanged() {
    guard !disposed else { return }
    updateMaterial()
    updateCorners()
  }

  private func updateMaterial() {
    let workspace = NSWorkspace.shared
    let highContrast = workspace.accessibilityDisplayShouldIncreaseContrast
    let opaque = style == "solid" || workspace.accessibilityDisplayShouldReduceTransparency || highContrast
    let key = "\(style)|\(dark)|\(clear)|\(opaque)"
    if effectKey != key {
      effectKey = key
      wash.removeFromSuperview()
      material?.removeFromSuperview()
      let next: NSView
      if opaque {
        next = NSView()
        next.wantsLayer = true
        next.layer?.backgroundColor = NSColor(white: dark ? 0.11 : 0.98, alpha: 1).cgColor
      } else if #available(macOS 26.0, *), style == "liquid" {
        let glass = NSGlassEffectView()
        glass.style = clear ? .clear : .regular
        // Match the Flutter foreground theme through the system material's
        // tint; keep native backdrop refraction rather than painting a cover.
        glass.tintColor = dark ? NSColor(white: 0.08, alpha: 1) : .white
        glass.contentView = wash
        next = glass
      } else {
        // Earlier macOS versions expose native blur, but not refractive glass.
        let blur = NSVisualEffectView()
        blur.blendingMode = .withinWindow
        blur.material = .popover
        blur.state = .active
        blur.addSubview(wash)
        next = blur
      }
      next.frame = materialFrame
      next.autoresizingMask = [.width, .height]
      addSubview(next)
      material = next
    }
    let inactive = !NSApp.isActive || window?.isKeyWindow != true
    if #available(macOS 26.0, *), material is NSGlassEffectView, dark && inactive {
      // AppKit de-emphasizes tinted glass when its window loses focus, but
      // Flutter's light foreground stays unchanged. Keep its contrast using
      // the existing content layer; retain the live glass and its compositor.
      wash.layer?.backgroundColor = NSColor(white: 0.08, alpha: 0.88).cgColor
    } else {
      wash.layer?.backgroundColor = NSColor.white.withAlphaComponent(
        CGFloat(opaque ? 0 : intensity * (dark ? 0.08 : 0.045))
      ).cgColor
    }
    if highContrast {
      material?.layer?.borderWidth = 1
      material?.layer?.borderColor = (dark ? NSColor.white : NSColor.black).cgColor
    } else {
      material?.layer?.borderWidth = 0
    }
  }

  private func updateCorners() {
    let frame = materialFrame
    let value = CGFloat(min(radius, Double(min(frame.width, frame.height) / 2)))
    if #available(macOS 26.0, *), let glass = material as? NSGlassEffectView {
      glass.cornerRadius = value
      // Attached headers must end at their layout bounds. Only floating
      // controls let AppKit's own shadow extend into the transparent margin.
      glass.clipsToBounds = !elevated
      glass.layer?.masksToBounds = !elevated
    } else {
      material?.wantsLayer = true
      material?.layer?.cornerRadius = value
      material?.layer?.cornerCurve = .continuous
      material?.layer?.masksToBounds = true
    }
    // Keep the press light within the silhouette even when a floating native
    // material lets its shadow extend beyond the control bounds.
    wash.layer?.cornerRadius = value
    wash.layer?.cornerCurve = .continuous
    wash.layer?.masksToBounds = true
  }

  private func dispose() {
    guard !disposed else { return }
    disposed = true
    NotificationCenter.default.removeObserver(self)
    NSWorkspace.shared.notificationCenter.removeObserver(self)
    channel.setMethodCallHandler(nil)
    material?.removeFromSuperview()
    material = nil
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
    NSWorkspace.shared.notificationCenter.removeObserver(self)
    channel.setMethodCallHandler(nil)
  }
}
