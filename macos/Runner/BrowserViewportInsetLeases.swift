import Cocoa
import WebKit

/// Keeps the original inset for each live renderer across tab switches and
/// owner transfers. Weak views never extend a closed renderer's lifetime.
final class BrowserViewportInsetLeases {
  private final class Lease {
    weak var view: WKWebView?
    var owner: String
    let original: NSEdgeInsets

    init(view: WKWebView, owner: String, original: NSEdgeInsets) {
      self.view = view
      self.owner = owner
      self.original = original
    }
  }

  private var leases: [ObjectIdentifier: Lease] = [:]

  @discardableResult
  func apply(to view: WKWebView, owner: String, top: CGFloat) -> Bool {
    guard #available(macOS 26.0, *), !owner.isEmpty, top.isFinite, top >= 0 else { return false }
    leases = leases.filter { $0.value.view != nil }
    let key = ObjectIdentifier(view)
    if let lease = leases[key], lease.view === view {
      // A replacement route takes over the existing lease. Its predecessor
      // must not restore this view, and the first original inset is preserved.
      lease.owner = owner
    } else {
      leases[key] = Lease(view: view, owner: owner, original: view.obscuredContentInsets)
    }
    for lease in leases.values where lease.owner == owner {
      guard let target = lease.view else { continue }
      target.obscuredContentInsets = NSEdgeInsets(
        top: top, left: lease.original.left,
        bottom: lease.original.bottom, right: lease.original.right)
    }
    return true
  }

  func release(owner: String? = nil) {
    for (key, lease) in leases {
      guard let view = lease.view else { leases.removeValue(forKey: key); continue }
      guard owner == nil || lease.owner == owner else { continue }
      if #available(macOS 26.0, *) { view.obscuredContentInsets = lease.original }
      leases.removeValue(forKey: key)
    }
  }

  deinit { release() }
}
