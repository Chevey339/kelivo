#include "include/flutter_inappwebview_windows/flutter_inappwebview_windows_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "flutter_inappwebview_windows_plugin.h"

void FlutterInappwebviewWindowsPluginCApiRegisterWithRegistrar(
  FlutterDesktopPluginRegistrarRef registrar)
{
  flutter_inappwebview_plugin::FlutterInappwebviewWindowsPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarManager::GetInstance()
    ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar),
    FlutterDesktopPluginRegistrarGetMessenger(registrar));
}

void FlutterInappwebviewWindowsPluginCApiPrepareForShutdown(
  FlutterDesktopPluginRegistrarRef registrar)
{
  if (!registrar) return;
  flutter_inappwebview_plugin::FlutterInappwebviewWindowsPlugin::PrepareForShutdown(
    FlutterDesktopPluginRegistrarGetMessenger(registrar));
}
