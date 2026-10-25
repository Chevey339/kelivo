#pragma once
#include <WebView2EnvironmentOptions.h>
#include <wrl.h>

namespace flutter_inappwebview_plugin {
// Both default environment creation paths must use identical options. Keep the
// existing profile/login state; only browser views install a resource handler.
inline void registerKelivoScheme(ICoreWebView2EnvironmentOptions* options) {
  Microsoft::WRL::ComPtr<ICoreWebView2EnvironmentOptions4> options4;
  if (FAILED(options->QueryInterface(IID_PPV_ARGS(&options4)))) return;
  auto scheme = Microsoft::WRL::Make<CoreWebView2CustomSchemeRegistration>(L"kelivo");
  scheme->put_HasAuthorityComponent(TRUE);
  scheme->put_TreatAsSecure(TRUE);
  // No cross-origin callers. Same-origin workspace requests remain available.
  ICoreWebView2CustomSchemeRegistration* registrations[] = {scheme.Get()};
  options4->SetCustomSchemeRegistrations(1, registrations);
}
}
