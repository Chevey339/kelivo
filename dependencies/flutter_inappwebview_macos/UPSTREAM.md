# flutter_inappwebview_macos

Vendored unchanged from the pub.dev `flutter_inappwebview_macos` **1.1.2**
package, except for the patches below. The original Apache-2.0 `LICENSE` is kept.

- Repository: https://github.com/pichillilorenzo/flutter_inappwebview/tree/master/flutter_inappwebview_macos
- Published archive SHA-256 recorded in Kelivo's lockfile:
  `c1fbb86af1a3738e3541364d7d1866315ffb0468a1a77e34198c9be571287da1`

## Local patch: deterministic WKWebView bounds

`macos/Classes/InAppWebView/FlutterWebViewController.swift` pins its WKWebView
child to all four edges of that immediate host with public `NSLayoutConstraint`
anchors. Mask translation is disabled on the child; there is no manual frame
correction in `layout` or `resizeSubviews`. The plugin already uses these four
anchors in `InAppBrowserWebViewController.swift`.

On a Retina macOS host, Flutter can supply fractional platform-view sizes.
AppKit aligns the plugin host to backing pixels. With the upstream nested
autoresizing masks, repeated fractional changes can accumulate a nonzero
leading margin on the WKWebView, shrinking or shifting the visible webpage.
The observed application had an outer width of `702.8984375`, a plugin-host
width of `703`, and a WKWebView frame of `(9, 0, 693.5, 788)`. Its obscured
insets remained `(84, 0, 0, 0)`; the horizontal error was inside the plugin
host, not an obscured-inset or glass-shadow offset.

Disabling mask translation without adding constraints is insufficient. A
previous frame-only candidate kept the outer WKWebView correctly sized while
AppKit collapsed WebKit's internal content-host view to zero size, clipping out
the loaded webpage. The regression now checks both geometries and reproduces
that failed candidate as a negative control.

The patch uses public AppKit layout APIs and preserves the native web view and
its history. Constraints belong to the immediate host: WebKit's fullscreen
controller saves that superview's explicit constraints before moving the view
and reactivates them on return. The patch does not inspect or modify WebKit's
private subviews. No SDK, Flutter engine, or global pub cache is modified.

Fullscreen lifecycle reference:
https://github.com/WebKit/WebKit/blob/main/Source/WebKit/UIProcess/mac/WKFullScreenWindowController.mm

`test/native/browser_webview_geometry_test.mm` provides a diagnostic regression
using the installed Flutter engine's actual platform-view mutator and a real
WKWebView. It compares upstream autoresizing, the failed frame-only candidate,
and the constrained layout. It covers a preloaded `520 x 788` headless host's
zero-size transfer, restoration to a rendered viewport, 800 fractional resizes,
clipping, full-page resizing, and constraint removal/restoration around a
detached view. It asserts the existing content-host subview's geometry through
public `NSView` properties without modifying it. This diagnostic does not test
HTML-video fullscreen interaction or replace validating the complete app's
rendering and interaction after a native rebuild.

## Local patch: release focus from covered tabs

The macOS controller now implements the existing cross-platform `clearFocus`
method. Its channel delegate releases the window's first responder only when
that responder is the target WKWebView or a descendant of it. Keeping the
bounded native tab pool attached avoids compositor reattachment flashes; this
focus boundary prevents a covered page from continuing to receive typing and
never clears focus belonging to another tab or Flutter control.
