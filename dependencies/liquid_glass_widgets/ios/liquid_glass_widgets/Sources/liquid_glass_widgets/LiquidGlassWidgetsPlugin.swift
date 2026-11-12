import Flutter
import UIKit

/// Reports the regions of the Flutter view that UIKit reserves for system
/// elements: on iPhone Duo, the status cluster and the camera at the ends of
/// the vertical bar strip.
///
/// They are the view's `reservedRegions(kind: .occlusion)`, added in the
/// iOS 27.1 SDK. Flutter does not pass them to Dart yet
/// (flutter/flutter#193025), so the package reads them here.
///
/// It also reports the trait collection's `verticalBarEdge`, the side the
/// system wants the strip on. Where UIKit leaves the strip's space to the
/// app, as for the left-hand app in Split View, that edge is all the app is
/// told: the view gets no inset for it.
public final class LiquidGlassWidgetsPlugin: NSObject, FlutterPlugin {
  private let channel: FlutterMethodChannel
  private weak var registrar: FlutterPluginRegistrar?
  private var observer: OcclusionObserver?

  private init(channel: FlutterMethodChannel, registrar: FlutterPluginRegistrar) {
    self.channel = channel
    self.registrar = registrar
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "liquid_glass_widgets/reserved_regions",
      binaryMessenger: registrar.messenger())
    let instance = LiquidGlassWidgetsPlugin(channel: channel, registrar: registrar)
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "observe":
      result(observe())
    case "verticalBarEdge":
      result(observer?.edge)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Starts reporting the Flutter view's occlusion regions, and returns them.
  private func observe() -> [[Double]] {
    guard let view = registrar?.viewController?.view else { return [] }
    if let observer, observer.superview === view { return observer.regions }
    observer?.removeFromSuperview()
    let observer = OcclusionObserver(
      onChange: { [weak self] regions in
        self?.channel.invokeMethod("didChange", arguments: regions)
      },
      onEdgeChange: { [weak self] edge in
        self?.channel.invokeMethod("didChangeVerticalBarEdge", arguments: edge)
      })
    view.addSubview(observer)
    self.observer = observer
    return observer.regions
  }
}

/// A hidden view that reports its superview's occlusion regions, as
/// `[left, top, right, bottom]` in points, and the vertical bar edge, as
/// `"leading"`, `"trailing"` or nil, whenever they change.
private final class OcclusionObserver: UIView {
  private let onChange: ([[Double]]) -> Void
  private let onEdgeChange: (String?) -> Void
  private(set) var regions: [[Double]] = []
  private(set) var edge: String?

  init(
    onChange: @escaping ([[Double]]) -> Void,
    onEdgeChange: @escaping (String?) -> Void
  ) {
    self.onChange = onChange
    self.onEdgeChange = onEdgeChange
    super.init(frame: .zero)
    // UIKit says nothing when the regions change; they are re-read on layout,
    // when the view joins a window, and whenever the app comes to the front,
    // since a Dynamic Island that appeared while the app was away moves no
    // layout of its own.
    NotificationCenter.default.addObserver(
      self, selector: #selector(refresh),
      name: UIApplication.didBecomeActiveNotification, object: nil)
    isHidden = true
    isUserInteractionEnabled = false
    autoresizingMask = [.flexibleWidth, .flexibleHeight]
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func didMoveToSuperview() {
    super.didMoveToSuperview()
    frame = superview?.bounds ?? .zero
    regions = read()
    edge = readEdge()
    #if canImport(UIKit, _version: 9127.0.85)
    if #available(iOS 27.1, *) {
      registerForTraitChanges(UITraitCollection.systemTraitsAffectingVerticalBarEdge) {
        (self: OcclusionObserver, _: UITraitCollection) in
        let edge = self.readEdge()
        guard edge != self.edge else { return }
        self.edge = edge
        self.onEdgeChange(edge)
      }
    }
    #endif
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    refresh()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    refresh()
  }

  @objc private func refresh() {
    let regions = read()
    guard regions != self.regions else { return }
    self.regions = regions
    onChange(regions)
  }

  private func readEdge() -> String? {
    #if canImport(UIKit, _version: 9127.0.85)
    if #available(iOS 27.1, *) {
      switch traitCollection.verticalBarEdge {
      case .leading: return "leading"
      case .trailing: return "trailing"
      default: return nil
      }
    }
    #endif
    return nil
  }

  private func read() -> [[Double]] {
    // The iOS 27.1 SDK's UIKit, the first with reserved regions; the package
    // still has to build against older SDKs.
    #if canImport(UIKit, _version: 9127.0.85)
    if #available(iOS 27.1, *), let superview {
      return superview.reservedRegions(kind: .occlusion).map { region in
        let frame = region.frame
        return [frame.minX, frame.minY, frame.maxX, frame.maxY].map(Double.init)
      }
    }
    #endif
    return []
  }
}
