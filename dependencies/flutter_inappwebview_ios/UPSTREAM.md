# Local iOS host identity extension

Source: the already resolved `flutter_inappwebview_ios` 1.1.2 package from
pub.dev, copied without repository metadata. The upstream license is retained
in `LICENSE`. No upstream behavior is changed.

`InAppWebView.swift` exposes one read-only `browserNativeViewId` property. Its
value is the existing concrete `id`, the same identity returned by Dart's
`InAppWebViewController.getViewId()`. Kelivo's scroll bridge uses it to attach
to exactly one existing native WebView. It survives the plugin's headless and
keep-alive transfers and distinguishes popup views, which share their opener's
WKUserContentController and do not install separate initial user scripts.

Upstream package: https://pub.dev/packages/flutter_inappwebview_ios/versions/1.1.2
Source repository: https://github.com/pichillilorenzo/flutter_inappwebview
