import UIKit
import WebKit

/// Observes WebKit's existing scrolling machinery without replacing its
/// delegate, adding a competing recognizer, or asking the document to run JS.
final class BrowserScrollObservation: NSObject {
  weak var scrollView: UIScrollView?
  private let pan: UIPanGestureRecognizer
  private let emit: ([String: Any]) -> Void
  private var observations: [NSKeyValueObservation] = []
  private var pending = false
  private var valid = true
  private var visible: Bool
  private(set) var sequence: Int
  private var lastTranslation = CGPoint.zero
  private var accumulatedDelta: CGFloat = 0
  private var gestureActive = false

  init(scrollView: UIScrollView, visible: Bool,
       pan: UIPanGestureRecognizer? = nil,
       startingSequence: Int = 0,
       emit: @escaping ([String: Any]) -> Void) {
    self.scrollView = scrollView
    self.pan = pan ?? scrollView.panGestureRecognizer
    self.visible = visible
    self.sequence = startingSequence
    self.emit = emit
    super.init()
    self.pan.addTarget(self, action: #selector(panChanged(_:)))
    observations = [
      scrollView.observe(\.contentOffset) { [weak self] _, _ in self?.schedule() },
      scrollView.observe(\.contentSize) { [weak self] _, _ in self?.schedule() },
      scrollView.observe(\.bounds) { [weak self] _, _ in self?.schedule() },
      scrollView.observe(\.adjustedContentInset) { [weak self] _, _ in self?.schedule() },
    ]
    send(phase: "reset")
  }

  func setVisible(_ value: Bool) {
    guard valid, visible != value else { return }
    visible = value
    gestureActive = false
    accumulatedDelta = 0
    lastTranslation = .zero
    if visible { send(phase: "reset") }
  }

  func reset() {
    gestureActive = false
    accumulatedDelta = 0
    lastTranslation = .zero
    send(phase: "reset")
  }

  @objc func panChanged(_ recognizer: UIPanGestureRecognizer) {
    guard valid, visible, let scrollView else { return }
    switch recognizer.state {
    case .began:
      // Baseline first, then include UIKit's initial movement past its pan
      // recognition slop. Each following change contributes only its delta.
      gestureActive = false
      accumulatedDelta = 0
      lastTranslation = .zero
      send(phase: "metrics")
      fallthrough
    case .changed:
      let translation = recognizer.translation(in: scrollView)
      let dx = translation.x - lastTranslation.x
      let dy = lastTranslation.y - translation.y
      lastTranslation = translation
      gestureActive = recognizer.numberOfTouches == 1 &&
        abs(translation.y) > abs(translation.x)
      if gestureActive && abs(dy) > abs(dx) {
        if dy.sign != accumulatedDelta.sign { accumulatedDelta = 0 }
        accumulatedDelta += dy
      }
      schedule()
    case .ended:
      // Flush a final move before marking release. The later deceleration
      // and rubber-band KVO callbacks must never acquire finger ownership.
      send(phase: "update")
      gestureActive = false
      accumulatedDelta = 0
      send(phase: "metrics")
    case .cancelled, .failed:
      gestureActive = false
      accumulatedDelta = 0
      send(phase: "metrics")
    default:
      break
    }
  }

  private func schedule() {
    guard valid, visible, !pending else { return }
    pending = true
    // KVO for offset, bounds and the pan target can fire in the same event.
    // One queued main-loop flush coalesces them; there is no idle display link.
    DispatchQueue.main.async { [weak self] in
      guard let self, self.pending else { return }
      self.send(phase: "update")
    }
  }

  private func send(phase: String) {
    pending = false
    guard valid, visible, let scrollView else { return }
    let inset = scrollView.adjustedContentInset
    let viewport = scrollView.bounds.height
    let offset = scrollView.contentOffset.y + inset.top
    let content = max(viewport, scrollView.contentSize.height + inset.top + inset.bottom)
    guard viewport.isFinite, viewport > 0, offset.isFinite, content.isFinite else { return }
    sequence += 1
    emit([
      "sequence": sequence, "phase": phase,
      "offset": Double(offset), "viewportExtent": Double(viewport),
      "contentExtent": Double(content),
      "isUserInteracting": gestureActive,
      "gestureDelta": Double(gestureActive ? accumulatedDelta : 0),
    ])
    accumulatedDelta = 0
  }

  func dispose() {
    guard valid else { return }
    valid = false
    pending = false
    pan.removeTarget(self, action: #selector(panChanged(_:)))
    observations.forEach { $0.invalidate() }
    observations.removeAll()
    scrollView = nil
  }

  deinit { dispose() }
}

#if canImport(Flutter)
import Flutter

/// Each engine leases exactly one observer for its existing WKWebView.
/// A native view transfer keeps the same observer; replacement detaches first.
final class BrowserScrollBridge {
  private weak var window: UIWindow?
  private var messenger: FlutterBinaryMessenger?
  private var channel: FlutterMethodChannel?
  private var observers: [String: BrowserScrollObservation] = [:]
  private var identify: ((WKWebView) -> String?)?

  func register(messenger: FlutterBinaryMessenger, window: UIWindow?,
                identify: @escaping (WKWebView) -> String?) {
    dispose()
    self.window = window
    self.messenger = messenger
    self.identify = identify
    let channel = FlutterMethodChannel(name: "app.browser_scroll", binaryMessenger: messenger)
    self.channel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(false); return }
      let values = call.arguments as? [String: Any] ?? [:]
      guard let owner = values["owner"] as? String, !owner.isEmpty else {
        result(false); return
      }
      switch call.method {
      case "attach":
        result(self.attach(owner: owner, values: values))
      case "visibility":
        self.observers[owner]?.setVisible(values["visible"] as? Bool ?? false)
        result(nil)
      case "reset":
        self.observers[owner]?.reset()
        result(nil)
      case "detach":
        self.observers.removeValue(forKey: owner)?.dispose()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func attach(owner: String, values: [String: Any]) -> Bool {
    guard let window, let messenger, let identify,
          let viewId = values["viewId"] as? String, !viewId.isEmpty else { return false }
    var targets: [WKWebView] = []
    func visit(_ view: UIView) {
      if let webView = view as? WKWebView, identify(webView) == viewId {
        targets.append(webView)
      }
      for child in view.subviews { visit(child) }
    }
    visit(window)
    guard targets.count == 1, let target = targets.first else { return false }
    let visible = values["visible"] as? Bool ?? false
    if let existing = observers[owner], existing.scrollView === target.scrollView {
      existing.setVisible(visible)
      return true
    }
    let previous = observers.removeValue(forKey: owner)
    let sequence = previous?.sequence ?? 0
    previous?.dispose()
    // Only one engine owns a physical host. A late old-owner detach cannot
    // remove a replacement because leases are keyed by distinct owner IDs.
    for oldOwner in Array(observers.keys) where observers[oldOwner]?.scrollView === target.scrollView {
      observers.removeValue(forKey: oldOwner)?.dispose()
    }
    let events = FlutterMethodChannel(name: "app.browser_scroll/\(owner)", binaryMessenger: messenger)
    observers[owner] = BrowserScrollObservation(
      scrollView: target.scrollView, visible: visible, startingSequence: sequence
    ) {
      events.invokeMethod("scroll", arguments: $0.merging(["viewId": viewId]) { _, new in new })
    }
    return true
  }

  func dispose() {
    channel?.setMethodCallHandler(nil)
    channel = nil
    observers.values.forEach { $0.dispose() }
    observers.removeAll()
    messenger = nil
    identify = nil
    window = nil
  }

  deinit { dispose() }
}
#endif
