#include "../utils/flutter.h"
#include "webview_environment_settings.h"

namespace flutter_inappwebview_plugin
{
  WebViewEnvironmentSettings::WebViewEnvironmentSettings(const flutter::EncodableMap& map)
    : browserExecutableFolder(get_optional_fl_map_value<std::string>(map, "browserExecutableFolder")),
    userDataFolder(get_optional_fl_map_value<std::string>(map, "userDataFolder")),
    additionalBrowserArguments(get_optional_fl_map_value<std::string>(map, "additionalBrowserArguments")),
    allowSingleSignOnUsingOSPrimaryAccount(get_optional_fl_map_value<bool>(map, "allowSingleSignOnUsingOSPrimaryAccount")),
    language(get_optional_fl_map_value<std::string>(map, "language")),
    targetCompatibleBrowserVersion(get_optional_fl_map_value<std::string>(map, "targetCompatibleBrowserVersion")),
    // Absent settings must not become an engaged empty vector: create() would
    // then replace the built-in kelivo registration with zero schemes.
    customSchemeRegistrations(fl_map_contains_not_null(map, "customSchemeRegistrations")
      ? std::make_optional(functional_map(get_fl_map_value<flutter::EncodableList>(map, "customSchemeRegistrations"),
        [](const flutter::EncodableValue& m) { return std::make_shared<CustomSchemeRegistration>(std::get<flutter::EncodableMap>(m)); }))
      : std::nullopt)
  {}

  flutter::EncodableMap WebViewEnvironmentSettings::toEncodableMap() const
  {
    return flutter::EncodableMap{
      {"browserExecutableFolder", make_fl_value(browserExecutableFolder)},
      {"userDataFolder", make_fl_value(userDataFolder)},
      {"additionalBrowserArguments", make_fl_value(additionalBrowserArguments)},
      {"allowSingleSignOnUsingOSPrimaryAccount", make_fl_value(allowSingleSignOnUsingOSPrimaryAccount)},
      {"language", make_fl_value(language)},
      {"targetCompatibleBrowserVersion", make_fl_value(targetCompatibleBrowserVersion)},
      {"customSchemeRegistrations", customSchemeRegistrations.has_value()
        ? make_fl_value(functional_map(customSchemeRegistrations.value(), [](const std::shared_ptr<CustomSchemeRegistration>& item) { return item->toEncodableMap(); }))
        : make_fl_value()}
    };
  }

}
