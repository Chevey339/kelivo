#include "flutter_inappwebview_windows_plugin.h"

#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include "cookie_manager.h"
#include "headless_in_app_webview/headless_in_app_webview_manager.h"
#include "in_app_browser/in_app_browser_manager.h"
#include "in_app_webview/in_app_webview_manager.h"
#include "webview_environment/webview_environment_manager.h"

#pragma comment(lib, "Shlwapi.lib")
#pragma comment(lib, "dxgi.lib")
#pragma comment(lib, "d3d11.lib")

namespace flutter_inappwebview_plugin
{
  // static
  void FlutterInappwebviewWindowsPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar, FlutterDesktopMessengerRef messenger)
  {
    auto plugin = std::make_unique<FlutterInappwebviewWindowsPlugin>(registrar, messenger);
    registrar->AddPlugin(std::move(plugin));
  }

  FlutterInappwebviewWindowsPlugin::FlutterInappwebviewWindowsPlugin(
    flutter::PluginRegistrarWindows* registrar, FlutterDesktopMessengerRef messenger)
    : registrar(registrar), pluginMessenger(std::make_unique<PluginMessenger>(registrar->messenger(), messenger, alive))
  {
    webViewEnvironmentManager = std::make_unique<WebViewEnvironmentManager>(this);
    inAppWebViewManager = std::make_unique<InAppWebViewManager>(this);
    inAppBrowserManager = std::make_unique<InAppBrowserManager>(this);
    headlessInAppWebViewManager = std::make_unique<HeadlessInAppWebViewManager>(this);
    cookieManager = std::make_unique<CookieManager>(this);
    browserWindowChannel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      this->messenger(), "app.browser_window", &flutter::StandardMethodCodec::GetInstance());
    browserWindowChannel->SetMethodCallHandler([this](const auto& call, auto result) {
      if (call.method_name() == "setBrowserShortcutCommands") {
        const auto* commands = call.arguments() ? std::get_if<flutter::EncodableList>(call.arguments()) : nullptr;
        browserShortcutCommands.clear();
        if (commands) for (const auto& value : *commands) {
          if (const auto* command = std::get_if<std::string>(&value)) browserShortcutCommands.insert(*command);
        }
        result->Success();
      }
      else if (call.method_name() == "setBrowserShortcuts") {
        const auto* enabled = call.arguments() ? std::get_if<bool>(call.arguments()) : nullptr;
        browserShortcutsEnabled = enabled && *enabled;
        result->Success();
      }
      else if (call.method_name() == "setBrowserChrome" || call.method_name() == "releaseBrowserViewportInsets") result->Success();
      else if (call.method_name() == "supportsBrowserViewportInsets") result->Success(flutter::EncodableValue(false));
      else result->NotImplemented();
    });
  }

  FlutterInappwebviewWindowsPlugin::~FlutterInappwebviewWindowsPlugin()
  {
    // Async creation callbacks may run while the dispatcher queue drains.
    browserWindowChannel->SetMethodCallHandler(nullptr);
    browserShortcutsEnabled = false;
    *alive = false;
    cookieManager = nullptr;
    headlessInAppWebViewManager = nullptr;
    inAppBrowserManager = nullptr;
    inAppWebViewManager->disposeWebViews();
    webViewEnvironmentManager = nullptr;
    // All views/controllers must be closed before the compositor and its STA.
    inAppWebViewManager = nullptr;
  }
}
