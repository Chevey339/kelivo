## 0.4.0

* Enable MSVC coroutine support ([#278](https://github.com/jnschulze/flutter-webview-windows/pull/278))
* Enable scrolling with trackpad ([#274](https://github.com/jnschulze/flutter-webview-windows/pull/274))

## 0.3.0

* Add full-screen support ([#189](https://github.com/jnschulze/flutter-webview-windows/pull/189))
* Make `loadingState` a broadcast stream ([#193](https://github.com/jnschulze/flutter-webview-windows/pull/193))
* Add `getWebViewVersion()` method ([#197](https://github.com/jnschulze/flutter-webview-windows/pull/197))
* Fix string casting of paths that may contain Unicode characters ([#199](https://github.com/jnschulze/flutter-webview-windows/pull/199))
* Add high-DPI screen support ([#203](https://github.com/jnschulze/flutter-webview-windows/pull/203))
* Add `setZoomFactor` ([#214](https://github.com/jnschulze/flutter-webview-windows/pull/214))
* Fix example ([#215](https://github.com/jnschulze/flutter-webview-windows/pull/215))
* Fix Visual Studio 17.6 builds ([#252](https://github.com/jnschulze/flutter-webview-windows/pull/252))

## 0.2.2

* Remove `libfmt` dependency in favor of C++20 `std::format`
* Enable D3D texture bridge by default
* Make `executeScript` return the script's result

## 0.2.1

* Add `WebviewController.addScriptToExecuteOnDocumentCreated` and `WebviewController.removeScriptToExecuteOnDocumentCreated`
* Add `WebviewController.onLoadError` stream
* Change `WebviewController.webMessage` stream type from `Map<dynamic, dynamic>` to `dynamic`
* Add virtual hostname mapping support 
* Add multi-touch support

## 0.2.0

* Fix Flutter 3.0 null safety warning in example
* Bump WebView2 SDK version to `1.0.1210.3`
* Add an option for limiting the FPS
* Change data directory base path from `RoamingAppData` to `LocalAppData`

## 0.1.9

* Fix Flutter 3.0 compatibility

## 0.1.8

* Prefix CMake build target names to prevent collisions with other plugins

## 0.1.7

* Add method for opening DevTools
* Update `TextureBridgeGpu`
* Update `libfmt` dependency

## 0.1.7-dev.2

* Ensure Flutter apps referencing `webview_windows` still work on Windows 8.

## 0.1.7-dev.1

* Remove windowsapp.lib dependency

## 0.1.6

* Improve WebView creation error handling

## 0.1.5

* Fix a potential crash during WebView creation

## 0.1.4

* Improve error handling for Webview environment creation

## 0.1.3

* Stability fixes

## 0.1.2

* Unregister method channel handlers upon WebView destruction

## 0.1.1

* Fix unicode string conversion in ExecuteScript and LoadStringContent
* Load CoreMessaging.dll on demand

## 0.1.0

* Fix a string conversion issue
* Add an option for controlling popup window behavior
* Update Microsoft.Web.WebView2 and Microsoft.Windows.ImplementationLibrary

## 0.0.9

* Fix resizing issues
* Add preliminary GpuSurfaceTexture support

## 0.0.8

* Don't rely on AVX2 support
* Add history controls
* Add suspend/resume support
* Add support for disabling cache, clearing cookies etc.

## 0.0.7

* Add support for handling permission requests
* Allow setting the background color
* Automatically download nuget

## 0.0.6

* Fix mousewheel event handling
* Make text selection work
* Add method for setting the user agent
* Add support for JavaScript injection
* Add support for JSON message passing between Dart and JS
* Fix WebView disposal

## 0.0.5

* Fix input field focus issue

## 0.0.4

* Minor cleanup

## 0.0.3

* Add support for additional cursor types

## 0.0.2

* Add support for loading string content

## 0.0.1

* Initial release
