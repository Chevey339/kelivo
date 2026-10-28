#ifndef FLUTTER_PLUGIN_FLUTTER_INAPPWEBVIEW_PLUGIN_PLUGIN_H_
#define FLUTTER_PLUGIN_FLUTTER_INAPPWEBVIEW_PLUGIN_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <memory>
#include <set>
#include "types/plugin_messenger.h"

namespace flutter_inappwebview_plugin
{
  class WebViewEnvironmentManager;
  class InAppWebViewManager;
  class InAppBrowserManager;
  class HeadlessInAppWebViewManager;
  class CookieManager;

  class FlutterInappwebviewWindowsPlugin : public flutter::Plugin {
  public:
    flutter::PluginRegistrarWindows* registrar;
    const std::shared_ptr<std::atomic_bool> alive = std::make_shared<std::atomic_bool>(true);
    std::unique_ptr<PluginMessenger> pluginMessenger;
    flutter::BinaryMessenger* messenger() const { return pluginMessenger.get(); }
    std::unique_ptr<WebViewEnvironmentManager> webViewEnvironmentManager;
    std::unique_ptr<InAppWebViewManager> inAppWebViewManager;
    std::unique_ptr<InAppBrowserManager> inAppBrowserManager;
    std::unique_ptr<HeadlessInAppWebViewManager> headlessInAppWebViewManager;
    std::unique_ptr<CookieManager> cookieManager;
    std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> browserWindowChannel;
    bool browserShortcutsEnabled = false;
    std::set<std::string> browserShortcutCommands;


    static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar,
      FlutterDesktopMessengerRef messenger);

    FlutterInappwebviewWindowsPlugin(flutter::PluginRegistrarWindows* registrar,
      FlutterDesktopMessengerRef messenger);

    virtual ~FlutterInappwebviewWindowsPlugin();

    // Disallow copy and assign.
    FlutterInappwebviewWindowsPlugin(const FlutterInappwebviewWindowsPlugin&) = delete;
    FlutterInappwebviewWindowsPlugin& operator=(const FlutterInappwebviewWindowsPlugin&) = delete;
  };
}
#endif  // FLUTTER_PLUGIN_FLUTTER_INAPPWEBVIEW_PLUGIN_PLUGIN_H_
