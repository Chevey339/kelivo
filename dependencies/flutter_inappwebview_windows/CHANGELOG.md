## 0.6.0

- Updated code to support multiple flutter windows

## 0.5.0+2

- Fixed `InAppWebViewController.callAsyncJavaScript` not working with JSON objects

## 0.5.0+1

- Fixed `onLoadResourceWithCustomScheme` WebView event called every time

## 0.5.0

- Implemented `shouldInterceptRequest`, `onLoadResourceWithCustomScheme` WebView events
- Updated flutter_inappwebview_platform_interface version to ^1.3.0

## 0.4.1

- Implemented `incognito` for `InAppWebViewSettings`

## 0.4.0

- Updated `shouldOverrideUrlLoading` implementation using the Chrome DevTools Protocol API Fetch.requestPaused event
- Updated flutter_inappwebview_platform_interface version to ^1.2.0

## 0.3.0+1

- Removed unwanted debug log

## 0.3.0

- Implemented `pause`, `resume`, `getCertificate` methods for `InAppWebViewController`
- Implemented `onPermissionRequest` WebView event

## 0.2.0+1

- Fixed `InAppWebViewController.evaluateJavascript` not working with JSON objects
- Fixed `InAppWebViewManager::METHOD_CHANNEL_NAME` c++ value
- Fixed `InAppWebViewController.takeScreenshot` to behave consistently with the other platforms

## 0.2.0

- Added support for keeping alive InAppWebView widgets
- Added onProgressChanged, onCreateWindow, onCloseWindow support
- Updated Microsoft.Web.WebView2 SDK version from `1.0.2210.55` to `1.0.2792.45`
- Updated pubspec.yaml
- Fixed `CookieManager.setCookie`

## 0.1.0

- Initial release
