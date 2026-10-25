# Kelivo Windows WebView2 patches

Vendored from `flutter_inappwebview_windows` 0.6.0 (pub.dev), with its upstream
license. The root `pubspec.yaml` selects this package for Windows only.

- Headless views use a composition controller and their existing document and
  HWND transfer into the visible texture host. Native history, forms, scripts
  and scroll position survive. Reattaching a keep-alive view also reuses that
  window; callbacks belonging to the retired texture wrapper are cleared.
- `getTitle` reads the document title instead of its URL.
- `snapshotWidth` bounds encoded physical pixels on Windows. CDP captures the
  current visual viewport with a scale adjusted for monitor DPI and page zoom,
  before encoding; it does not resize or reload the webpage. The asynchronous
  screenshot callbacks retain COM references rather than a raw view pointer.
  Captures are serialized per native view so simultaneous preview and agent
  screenshots cannot overlap CDP's temporary capture viewport.

The focused real-platform regression is
`integration_test/browser_windows_runtime_test.dart`. Run it in a separately
named runner with a process-local `WEBVIEW2_USER_DATA_FOLDER`; it uses an in-memory
database and a temporary browser store, never normal Kelivo conversations.

References:
- https://learn.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/icorewebview2controller3
- https://chromedevtools.github.io/devtools-protocol/tot/Page/#method-captureScreenshot
