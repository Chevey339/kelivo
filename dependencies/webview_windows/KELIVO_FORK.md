# Kelivo Windows preview fork

Upstream: [jnschulze/flutter-webview-windows](https://github.com/jnschulze/flutter-webview-windows/tree/ed81bbe985c12759a44b9cca8170e19c73b961c0),
commit `ed81bbe985c12759a44b9cca8170e19c73b961c0` (version 0.4.0).
The original BSD 3-Clause LICENSE and third-party utility licenses are retained.
The source subset contains lib, windows, tests, package metadata and documentation;
upstream examples, editor files and CI configuration are omitted.

The fixed WebView2 SDK is 1.0.2365.46. Each plugin downloads its NuGet packages into
its own CMake binary directory, avoiding collisions with other WebView plugins.
The environment/profile remains shared with ordinary webview_windows controllers.
No separate profile, InPrivate session, process-termination hook or global data
clearing is introduced.

`initializeRestrictedPreview` fixes the mode at creation. Its controller requires
ICoreWebView2_22, configures capabilities, installs synchronous main/frame
navigation cancellation and a DOCUMENT-only resource filter before any document
is loaded, and denies popups, downloads, external schemes and permissions.
Permission denial is not saved in the shared profile. Native enforcement failure
closes the controller. Blocked events only report bounded reasons after the native
decision; no Dart callback can approve a request. Script/CDP, host mapping, web
messaging, cache/cookie clearing and normal navigation APIs are unavailable in
restricted mode. Exactly one host document can be loaded by NavigateToString.

The host must supply a trusted outer CSP and an opaque-origin iframe using only
`sandbox="allow-scripts"`. This plugin does not accept arbitrary generated HTML
as a trusted top-level document. The C21 host owns wrapping and actual browser
acceptance. WebRTC network traffic is an explicitly accepted limitation of this
CSP/resource-filter design; this is not an OS network sandbox.

## Approved profile-setting clarification (2026-10-24)

The user approved retaining the shared profile and validating autofill/password
isolation with synthetic saved data. Settings4 IsGeneralAutofillEnabled and
IsPasswordAutosaveEnabled affect every WebView sharing a profile, so this fork
intentionally leaves them unchanged. It disables controller-local web messaging,
host objects, default script dialogs, DevTools and browser accelerators. C21 must
prove the opaque sandbox cannot obtain the synthetic autofill/password data;
a failure blocks acceptance. It must also show ordinary same-environment workers
continue to work. The approval does not waive those actual runtime checks.

Reference: [Microsoft Settings4 documentation](https://learn.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/icorewebview2settings4)
and [WebView2_22 source-kind filtering](https://learn.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/icorewebview2_22).

## Lifetime and validation

Dart initialization/disposal handles failures and late creation results, closes
streams and keeps modes immutable. Native Close unregisters handlers, explicitly
closes this controller and stops capture. Texture objects survive until Flutter's
asynchronous texture-unregister completion. Ordinary pages retain their existing
entry point, shared environment and capability policy.

Run `flutter pub get`, `dart analyze --fatal-infos` and `flutter test` here.
Native policy tests use the production policy header with failing installers,
loaders and close callbacks. Build/run them on Windows with:

```
cmake -S windows/test -B build/policy
cmake --build build/policy --config Debug
ctest --test-dir build/policy -C Debug --output-on-failure
```

These unit tests verify order, synchronous decisions and lifetime boundaries;
they do not replace COM integration, GUI, network or storage-isolation tests.
The containing Kelivo candidate must also build on Windows before the C20 commit.
