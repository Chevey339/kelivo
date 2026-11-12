// Uses real WKWebViews but never creates, shows or activates a window.
// xcrun swiftc macos/Runner/BrowserViewportInsetLeases.swift \
//   test/native/browser_viewport_inset_leases_test.swift \
//   -framework Cocoa -framework WebKit -o /tmp/browser-viewport-inset-leases-test
// /tmp/browser-viewport-inset-leases-test
import Cocoa
import WebKit

@main
struct BrowserViewportInsetLeasesTest {
  static func main() {
    guard #available(macOS 26.0, *) else {
      print("Requires macOS 26 obscured-content-inset API")
      return
    }
    _ = NSApplication.shared
    let leases = BrowserViewportInsetLeases()
    let first = WKWebView(frame: .zero)
    let second = WKWebView(frame: .zero)
    first.obscuredContentInsets = NSEdgeInsets(top: 3, left: 2, bottom: 4, right: 5)
    second.obscuredContentInsets = NSEdgeInsets(top: 10, left: 11, bottom: 12, right: 13)
    precondition(leases.apply(to: first, owner: "old", top: 84))
    precondition(leases.apply(to: second, owner: "old", top: 84))
    precondition(first.obscuredContentInsets.top == 84)
    precondition(second.obscuredContentInsets.top == 84)
    precondition(first.obscuredContentInsets.left == 2)
    precondition(second.obscuredContentInsets.bottom == 12)

    // Resize the header while another retained tab is inactive: both keep the
    // same native viewport geometry before the old tab becomes visible again.
    precondition(leases.apply(to: second, owner: "old", top: 96))
    precondition(first.obscuredContentInsets.top == 96)
    precondition(second.obscuredContentInsets.top == 96)

    // Route replacement transfers one renderer without capturing its already
    // modified inset as the original. Releasing the old owner touches only B.
    precondition(leases.apply(to: first, owner: "new", top: 44))
    leases.release(owner: "old")
    precondition(first.obscuredContentInsets.top == 44)
    precondition(second.obscuredContentInsets.top == 10)
    leases.release(owner: "old")
    precondition(first.obscuredContentInsets.top == 44)
    leases.release(owner: "new")
    precondition(first.obscuredContentInsets.top == 3)
    precondition(first.obscuredContentInsets.right == 5)

    precondition(!leases.apply(to: first, owner: "", top: 84))
    precondition(!leases.apply(to: first, owner: "bad", top: -.infinity))
    precondition(first.obscuredContentInsets.top == 3)
    precondition(leases.apply(to: first, owner: "one", top: 84))
    precondition(leases.apply(to: second, owner: "two", top: 84))
    leases.release()
    precondition(first.obscuredContentInsets.top == 3)
    precondition(second.obscuredContentInsets.top == 10)
    weak var closedView: WKWebView?
    autoreleasepool {
      let transient = WKWebView(frame: .zero)
      closedView = transient
      precondition(leases.apply(to: transient, owner: "closed", top: 84))
    }
    precondition(closedView == nil, "inset leases must not retain a closed renderer")
    precondition(leases.apply(to: first, owner: "after-close", top: 84))
    leases.release()
    precondition(first.obscuredContentInsets.top == 3)
    print("Native viewport leases: retained tabs, header changes, owner transfer and restoration passed")
  }
}
