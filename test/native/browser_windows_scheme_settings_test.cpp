#include <cassert>
#include <iostream>
#include "../../dependencies/flutter_inappwebview_windows/windows/webview_environment/webview_environment_settings.h"

int main() {
  using flutter::EncodableList;
  using flutter::EncodableMap;
  using flutter::EncodableValue;
  using flutter_inappwebview_plugin::WebViewEnvironmentSettings;
  const EncodableValue key("customSchemeRegistrations");
  WebViewEnvironmentSettings absent(EncodableMap{});
  assert(!absent.customSchemeRegistrations.has_value());
  assert(absent.toEncodableMap().at(key).IsNull());
  WebViewEnvironmentSettings unset(EncodableMap{{key, EncodableValue()}});
  assert(!unset.customSchemeRegistrations.has_value());
  assert(unset.toEncodableMap().at(key).IsNull());
  WebViewEnvironmentSettings empty(EncodableMap{{key, EncodableList{}}});
  assert(empty.customSchemeRegistrations.has_value());
  assert(empty.customSchemeRegistrations->empty());
  assert(std::get<EncodableList>(empty.toEncodableMap().at(key)).empty());
  const EncodableMap scheme{
    {EncodableValue("scheme"), EncodableValue("fixture")},
    {EncodableValue("allowedOrigins"), EncodableValue()},
  };
  WebViewEnvironmentSettings configured(EncodableMap{{key, EncodableList{scheme}}});
  assert(configured.customSchemeRegistrations->size() == 1);
  assert(configured.customSchemeRegistrations->front()->scheme == "fixture");
  std::cout << "Windows custom-scheme settings preserve omitted/null/empty values\n";
}
