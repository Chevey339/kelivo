# Native Web acceptance

These fixtures are manual integration acceptance, outside G and paid model
evaluation. They never load the production app entry point, chat database or
credentials. `integration_test/genui_web_sandbox_test.dart` uses production
controller/policy code, a trusted test-only parent observer, synthetic HTTP/TLS
listeners and one temporary executable file canary. The observer is absent from
the product wrapper. No application JS channel or runtime switch is installed.

Run on a supported, unlocked device with the same pinned Flutter SDK:

```sh
flutter drive --no-pub --driver=test_driver/integration_test.dart \
  --target=integration_test/genui_web_sandbox_test.dart -d DEVICE
```

The ordinary WebView must first execute the same file canary through both a
local path and its `file://localhost` URI, reach the HTTP endpoint and connect
to the TLS listener. Only then can zero preview requests count as
evidence. Every probe records `GENUI_WEB_CASE`; the final report contains the
requests, native navigation decisions and CSP enforcement events. The platform
decorators inherit the actual plugin classes and return the production policy's
decision unchanged. They do not grant capabilities or simulate native requests.

Five cases additionally require native input: `gesture-link`, `gesture-popup`,
`gesture-download`, `gesture-file` and `gesture-protocol`. If Flutter's pointer
injection cannot reach the embedded native view, the test prints
`GENUI_WEB_NATIVE_TAP` and waits for the matching `Run gesture-…` button to be
clicked. Use native UI automation or an operator. The test requires both
`event.isTrusted` and `navigator.userActivation.isActive`; a JavaScript click
cannot pass. macOS CUA can click the visible button. Android's dedicated test
device may use adb input. Keep the device awake for this run and restore its
previous setting afterwards.

For a personal iPhone, build and sign an **isolated** acceptance bundle with ID
`psyche.kelivo.genuiacceptance`, isolated extension IDs and URL scheme
`kelivo-genui-test`, without the production App Group entitlement. Do not replace
the user's installed app. Restore any temporary project/plist changes before
staging or running G. The test UI runner below targets only that isolated ID.

Using the Ruby environment already installed with CocoaPods (which includes
`xcodeproj`), generate a separate ignored UI-test project:

```sh
ruby tool/genui_native_ui/create_ios_project.rb \
  build/genui/ios-ui-project SIGNING_TEAM
xcodebuild -project build/genui/ios-ui-project/GenUiGestures.xcodeproj \
  -scheme GenUiGestures -configuration Debug -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build/genui/ios-ui-derived \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration build-for-testing
```

While Flutter's isolated test app is running, use the generated `.xctestrun`
with `xcodebuild test-without-building -xctestrun PATH -destination id=DEVICE`.
Flutter 3.47.6's `TestPlatformDispatcher` does not forward `onHitTest`. The
integration executable connects the real dispatcher to the same render-tree
hit-test algorithm used by `GestureBinding`, then restores the original
callback. This makes native platform-view input available without granting any
Web capability or changing product code. Device pointer propagation is enabled
for native taps; macOS semantics are enabled before the leak-check baseline.

The XCTest runner supplies real native taps; the Dart fixture judges the
security result independently. The runner does not read any other app's data.

WebKit reports opaque custom-scheme CSP targets as `null`; Chromium reports an
empty URI. A fresh preview
containing exactly that one attempted navigation, with exactly one enforcing `frame-src`
event, is recorded separately from a native delegate rejection. HTTP/TLS counters
alone do not establish protocol or local-file rejection. The localhost file
authority check is not a remote Windows SMB/UNC test; that acceptance remains
deferred with Windows. File checks use the
positive canary plus continued original-document heartbeat where the engine
retains the blocked child document. A blocked Chromium navigation may replace
that child with an error document, so heartbeat absence alone is not success.

No test here proves absolute offline operation or covers WebRTC; that residual
risk is explicitly accepted by the proposal. Windows work is paused by the
user, and Linux GUI acceptance is deferred. Do not run these tools against the
paused Windows machine or describe those platforms as accepted.
