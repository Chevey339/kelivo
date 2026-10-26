import Flutter
import UIKit
import WebKit

/// Applies browser-owned viewport insets without changing the WKWebView frame
/// or the plugin's scroll-view content-inset policy.
final class BrowserViewportInsetsBridge {
  private weak var window: UIWindow?
  private final class Lease {
    weak var view: WKWebView?
    var owner: String
    let originalInsets: UIEdgeInsets

    init(view: WKWebView, owner: String, originalInsets: UIEdgeInsets) {
      self.view = view
      self.owner = owner
      self.originalInsets = originalInsets
    }
  }
  private var leases: [ObjectIdentifier: Lease] = [:]
  private var channel: FlutterMethodChannel?
  private var identify: ((WKWebView) -> String?)?
  private var transparencyObserver: NSObjectProtocol?

  func register(messenger: FlutterBinaryMessenger, window: UIWindow?,
                identify: @escaping (WKWebView) -> String?) {
    release()
    channel?.setMethodCallHandler(nil)
    if let transparencyObserver {
      NotificationCenter.default.removeObserver(transparencyObserver)
      self.transparencyObserver = nil
    }
    self.window = window
    self.identify = identify
    let next = FlutterMethodChannel(name: "app.browser_window", binaryMessenger: messenger)
    channel = next
    next.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(false); return }
      switch call.method {
      case "supportsBrowserViewportInsets":
        if #available(iOS 26.0, *) { result(true) } else { result(false) }
      case "getBrowserReduceTransparency":
        result(UIAccessibility.isReduceTransparencyEnabled)
      case "browserSnapshotRect":
        result(self.snapshotRect(viewId: call.arguments as? String))
      case "setBrowserViewportInsets":
        result(self.apply(call.arguments as? [String: Any] ?? [:]))
      case "releaseBrowserViewportInsets":
        if let owner = call.arguments as? String { self.release(owner: owner) }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    if #available(iOS 26.0, *) {
      transparencyObserver = NotificationCenter.default.addObserver(
        forName: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        self?.channel?.invokeMethod(
          "browserReduceTransparencyChanged",
          arguments: UIAccessibility.isReduceTransparencyEnabled
        )
      }
    }
  }

  /// A thumbnail contains webpage pixels only. On iOS 18 the WK frame already
  /// begins below the status bar; iOS 26 extends it and owns the obscured inset.
  private func snapshotRect(viewId: String?) -> [String: Double]? {
    guard let window, let identify, let viewId, !viewId.isEmpty else { return nil }
    var targets: [WKWebView] = []
    func visit(_ view: UIView) {
      if let webView = view as? WKWebView, identify(webView) == viewId {
        targets.append(webView)
      }
      for child in view.subviews { visit(child) }
    }
    visit(window)
    guard targets.count == 1, let view = targets.first,
          !view.bounds.isEmpty else { return nil }
    let bounds = view.bounds
    var top: CGFloat = 0
    if #available(iOS 26.0, *) {
      top = min(max(0, view.obscuredContentInsets.top), bounds.height)
    }
    guard top < bounds.height else { return nil }
    return ["x": Double(bounds.minX), "y": Double(bounds.minY + top),
            "width": Double(bounds.width), "height": Double(bounds.height - top),
            "scale": Double(view.window?.screen.scale ?? window.screen.scale)]
  }

  private func apply(_ values: [String: Any]) -> Bool {
    guard #available(iOS 26.0, *),
          let window, !window.isHidden,
          let owner = values["owner"] as? String, !owner.isEmpty,
          let marker = values["marker"] as? String,
          marker.hasPrefix("/* kelivo-browser-tab:"), marker.hasSuffix(" */"),
          let top = values["top"] as? Double, top.isFinite, top >= 0 else { return false }
    var candidates: [WKWebView] = []
    func visit(_ view: UIView) {
      // The plugin attaches a headless host to the window at alpha 0.01.
      // Wait for its transfer to the visible platform-view host before inset
      // acknowledgement lets Flutter extend the page under the status bar.
      guard !view.isHidden, view.alpha > 0.01, !view.bounds.isEmpty else { return }
      if let webView = view as? WKWebView,
         webView.window === window,
         webView.configuration.userContentController.userScripts.contains(where: { $0.source == marker }) {
        candidates.append(webView)
      }
      for child in view.subviews { visit(child) }
    }
    visit(window)
    guard candidates.count == 1, let target = candidates.first else { return false }
    leases = leases.filter { $0.value.view != nil }
    let identity = ObjectIdentifier(target)
    if let lease = leases[identity] {
      // A presentation handoff adopts the original inset, not the browser's
      // currently applied value. A late release from the old owner is harmless.
      lease.owner = owner
    } else {
      leases[identity] = Lease(
        view: target, owner: owner, originalInsets: target.obscuredContentInsets)
    }
    // Retained tabs share this presentation's chrome. Keep their insets stable
    // while hidden, including when the same header changes height.
    for lease in leases.values where lease.owner == owner {
      guard let view = lease.view else { continue }
      let original = lease.originalInsets
      view.obscuredContentInsets = UIEdgeInsets(
        top: CGFloat(top), left: original.left,
        bottom: original.bottom, right: original.right)
    }
    return true
  }

  private func release(owner requestedOwner: String? = nil) {
    let released = leases.keys.filter {
      requestedOwner == nil || leases[$0]?.owner == requestedOwner || leases[$0]?.view == nil
    }
    for identity in released {
      guard let lease = leases.removeValue(forKey: identity) else { continue }
      if #available(iOS 26.0, *), let view = lease.view {
        view.obscuredContentInsets = lease.originalInsets
      }
    }
  }

  func dispose() {
    release()
    if let transparencyObserver {
      NotificationCenter.default.removeObserver(transparencyObserver)
      self.transparencyObserver = nil
    }
    channel?.setMethodCallHandler(nil)
    channel = nil
  }

  deinit { dispose() }
}

/// Browser-scoped native material. Flutter owns the controls and their gestures;
/// UIKit supplies system glass on iOS 26 and blur on earlier versions.
final class BrowserGlassViewFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    BrowserGlassPlatformView(
      frame: frame,
      viewId: viewId,
      arguments: args as? [String: Any] ?? [:],
      messenger: messenger
    )
  }
}

private final class BrowserGlassPlatformView: NSObject, FlutterPlatformView {
  private let surface: BrowserGlassSurface
  private let channel: FlutterMethodChannel

  init(
    frame: CGRect,
    viewId: Int64,
    arguments: [String: Any],
    messenger: FlutterBinaryMessenger
  ) {
    surface = BrowserGlassSurface(frame: frame)
    channel = FlutterMethodChannel(
      name: "app.browser_glass/\(viewId)",
      binaryMessenger: messenger
    )
    super.init()
    surface.update(arguments)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }
      switch call.method {
      case "update":
        self.surface.update(call.arguments as? [String: Any] ?? [:])
        result(nil)
      case "dispose":
        self.surface.dispose()
        self.channel.setMethodCallHandler(nil)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func view() -> UIView { surface }

  deinit {
    channel.setMethodCallHandler(nil)
  }
}

private final class BrowserGlassSurface: UIView {
  private let material = UIVisualEffectView()
  private let legacySheen = CAGradientLayer()
  private let legacyRim = CAGradientLayer()
  private let legacyRimMask = CAShapeLayer()
  private var legacyGeometry: CGRect?
  private var legacyRadius: CGFloat?
  private var radius: Double = 28
  private var style = "liquid"
  private var dark = false
  private var clear = false
  private var elevated = true
  private var intensity: Double = 0
  private var effectKey: String?
  private var configuredGlassRadius: Double?
  private var disposed = false

  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .clear
    isOpaque = false
    isUserInteractionEnabled = false
    accessibilityElementsHidden = true
    clipsToBounds = false
    material.isUserInteractionEnabled = false
    material.isOpaque = false
    addSubview(material)
    // Earlier iOS versions use UIKit blur with stationary edge lighting.
    // No WebView screenshots or animation timer are needed.
    legacySheen.startPoint = CGPoint(x: 0.5, y: 0)
    legacySheen.endPoint = CGPoint(x: 0.5, y: 1)
    legacySheen.locations = [0, 0.24, 0.7, 1]
    legacyRim.startPoint = CGPoint(x: 0, y: 0)
    legacyRim.endPoint = CGPoint(x: 1, y: 1)
    legacyRim.locations = [0, 0.24, 0.76, 1]
    legacyRimMask.fillColor = UIColor.clear.cgColor
    legacyRimMask.strokeColor = UIColor.white.cgColor
    legacyRimMask.lineWidth = 0.7
    legacyRim.mask = legacyRimMask
    layer.addSublayer(legacySheen)
    layer.addSublayer(legacyRim)
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(accessibilityChanged),
      name: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(accessibilityChanged),
      name: UIAccessibility.darkerSystemColorsStatusDidChangeNotification,
      object: nil
    )
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func layoutSubviews() {
    super.layoutSubviews()
    material.frame = bounds
    updateCorners()
  }

  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? { nil }

  func update(_ values: [String: Any]) {
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
      // Fade within UIKit; a Flutter opacity ancestor isolates the live
      // backdrop into an offscreen layer before this material can sample it.
      alpha = CGFloat(min(1, max(0, value)))
    }
    overrideUserInterfaceStyle = dark ? .dark : .light
    updateMaterial()
    updateCorners()
  }

  @objc private func accessibilityChanged() {
    guard !disposed else { return }
    updateMaterial()
    updateCorners()
  }

  private func updateMaterial() {
    let highContrast = UIAccessibility.isDarkerSystemColorsEnabled
    let opaque = style == "solid" || UIAccessibility.isReduceTransparencyEnabled || highContrast
    let key = "\(style)|\(dark)|\(clear)|\(opaque)|\(elevated)"
    if effectKey != key {
      effectKey = key
      configuredGlassRadius = nil
      if opaque {
        material.effect = nil
        material.backgroundColor = .systemBackground
      } else {
        material.backgroundColor = .clear
        if #available(iOS 26.0, *), style == "liquid" {
          let glass = UIGlassEffect(style: clear ? .clear : .regular)
          // Keep dark chrome consistently dark over bright webpages. Flutter
          // foregrounds do not participate in UIKit's automatic vibrancy.
          glass.tintColor = dark
            ? UIColor(white: 0.08, alpha: 1)
            : UIColor.white.withAlphaComponent(0.12)
          // Flutter handles pressure/drag feedback; this passive native view
          // never receives or synthesizes UITouch events.
          glass.isInteractive = false
          material.effect = glass
        } else {
          material.effect = UIBlurEffect(
            style: style == "frosted" ? .systemMaterial : .systemUltraThinMaterial)
        }
      }
      var legacyLiquid = style == "liquid" && !opaque
      if #available(iOS 26.0, *) { legacyLiquid = false }
      CATransaction.begin()
      CATransaction.setDisableActions(true)
      legacySheen.isHidden = !legacyLiquid
      legacyRim.isHidden = !legacyLiquid
      legacySheen.colors = [
        UIColor.white.withAlphaComponent(dark ? 0.05 : 0.09).cgColor,
        UIColor.white.withAlphaComponent(0.015).cgColor,
        UIColor.clear.cgColor,
        UIColor.clear.cgColor,
      ]
      // Keep the edge light subtle around the blurred material.
      legacyRim.colors = [
        UIColor.white.withAlphaComponent(dark ? 0.22 : 0.44).cgColor,
        UIColor.clear.cgColor,
        UIColor.clear.cgColor,
        UIColor.white.withAlphaComponent(dark ? 0.10 : 0.22).cgColor,
      ]
      layer.shadowColor = UIColor.black.cgColor
      layer.shadowOpacity = legacyLiquid && elevated ? (dark ? 0.06 : 0.04) : 0
      layer.shadowRadius = 20
      layer.shadowOffset = CGSize(width: 0, height: 2)
      CATransaction.commit()
    }
    // Pressure only changes a faint light wash. Do not reconstruct the native
    // backdrop effect on every animation frame or fade its parent hierarchy.
    material.contentView.backgroundColor = opaque
      ? .clear
      : UIColor.white.withAlphaComponent(CGFloat(intensity * (dark ? 0.08 : 0.045)))
    material.layer.borderWidth = highContrast ? 1 : 0
    material.layer.borderColor = highContrast
      ? UIColor.label.resolvedColor(with: traitCollection).cgColor
      : nil
  }

  private func updateCorners() {
    if #available(iOS 26.0, *), material.effect is UIGlassEffect {
      guard configuredGlassRadius != radius else { return }
      configuredGlassRadius = radius
      // Glass supplies its own optical edge. Clipping the view would trim the
      // lens/shadow when returning here from the frosted or solid style.
      material.clipsToBounds = false
      // UIKit resolves the capsule against changing bounds. Do not allocate
      // another configuration for every Flutter platform-view layout.
      material.cornerConfiguration = .capsule(maximumRadius: radius)
    } else {
      configuredGlassRadius = nil
      // UIBlurEffect does not use the glass corner configuration. Clip this
      // effect view itself (never its platform-view ancestor) to the shape.
      let effectiveRadius = min(radius, Double(min(bounds.width, bounds.height) / 2))
      material.layer.cornerRadius = CGFloat(effectiveRadius)
      material.layer.cornerCurve = .continuous
      material.clipsToBounds = true
      let corner = CGFloat(effectiveRadius)
      if legacyGeometry != bounds || legacyRadius != corner {
        legacyGeometry = bounds
        legacyRadius = corner
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        legacySheen.frame = bounds
        legacySheen.cornerRadius = corner
        legacySheen.cornerCurve = .continuous
        legacySheen.masksToBounds = true
        legacyRim.frame = bounds
        legacyRimMask.frame = bounds
        legacyRimMask.path = UIBezierPath(
          roundedRect: bounds.insetBy(dx: 0.35, dy: 0.35),
          cornerRadius: max(0, corner - 0.35)).cgPath
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: corner).cgPath
        CATransaction.commit()
      }
    }
  }

  func dispose() {
    guard !disposed else { return }
    disposed = true
    NotificationCenter.default.removeObserver(self)
    material.effect = nil
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }
}
