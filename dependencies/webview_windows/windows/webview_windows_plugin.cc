#include "include/webview_windows/webview_windows_plugin.h"

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>

#include <memory>
#include <string>
#include <unordered_map>
#include <vector>

#include "util/string_converter.h"
#include "webview_bridge.h"
#include "webview_host.h"
#include "webview_platform.h"

#pragma comment(lib, "dxgi.lib")
#pragma comment(lib, "d3d11.lib")

namespace {

constexpr auto kMethodInitialize = "initialize";
constexpr auto kMethodInitializeRestricted = "initializeRestrictedPreview";
constexpr auto kMethodDispose = "dispose";
constexpr auto kMethodInitializeEnvironment = "initializeEnvironment";
constexpr auto kMethodGetWebViewVersion = "getWebViewVersion";

constexpr auto kErrorCodeInvalidId = "invalid_id";
constexpr auto kErrorCodeEnvironmentCreationFailed =
    "environment_creation_failed";
constexpr auto kErrorCodeEnvironmentAlreadyInitialized =
    "environment_already_initialized";
constexpr auto kErrorCodeWebviewCreationFailed = "webview_creation_failed";
constexpr auto kErrorUnsupportedPlatform = "unsupported_platform";

using MethodResult = flutter::MethodResult<flutter::EncodableValue>;

enum class InitializationKind { kEnvironment, kWebview, kRestrictedWebview };

struct PendingInitialization {
  InitializationKind kind;
  std::unique_ptr<MethodResult> result;
};

template <typename T>
std::optional<T> GetOptionalValue(const flutter::EncodableMap& map,
                                  const std::string& key) {
  const auto it = map.find(flutter::EncodableValue(key));
  if (it != map.end()) {
    const auto val = std::get_if<T>(&it->second);
    if (val) {
      return *val;
    }
  }
  return std::nullopt;
}

class WebviewWindowsPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(FlutterDesktopPluginRegistrarRef registrar);
  static void PrepareForShutdown(FlutterDesktopPluginRegistrarRef registrar);

  WebviewWindowsPlugin(FlutterDesktopPluginRegistrarRef registrar,
                       flutter::TextureRegistrar* textures,
                       flutter::BinaryMessenger* messenger);

  virtual ~WebviewWindowsPlugin();

 private:
  std::unique_ptr<WebviewPlatform> platform_;
  std::shared_ptr<WebviewHost> webview_host_;
  std::shared_ptr<bool> alive_ = std::make_shared<bool>(true);
  std::vector<PendingInitialization> pending_initializations_;
  std::unordered_map<int64_t, std::unique_ptr<WebviewBridge>> instances_;

  FlutterDesktopPluginRegistrarRef registrar_;
  WNDCLASS window_class_ = {};
  flutter::TextureRegistrar* textures_;
  flutter::BinaryMessenger* messenger_;

  bool InitPlatform();
  void Dispose();

  void Initialize(
      PendingInitialization request,
      std::optional<std::wstring> user_data_path = std::nullopt,
      const std::optional<std::wstring>& browser_exe_path = std::nullopt,
      const std::optional<std::string>& additional_args = std::nullopt);
  void CompleteInitialization(PendingInitialization request);
  void CreateWebviewInstance(std::unique_ptr<MethodResult> result, bool restricted);
  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

// Instances are registered and torn down on their Windows platform thread.
thread_local std::unordered_map<FlutterDesktopPluginRegistrarRef,
                                WebviewWindowsPlugin*> registered_plugins;

// static
void WebviewWindowsPlugin::RegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef native_registrar) {
  auto* registrar = flutter::PluginRegistrarManager::GetInstance()
                        ->GetRegistrar<flutter::PluginRegistrarWindows>(
                            native_registrar);
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "io.jns.webview.win",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<WebviewWindowsPlugin>(
      native_registrar, registrar->texture_registrar(), registrar->messenger());

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registered_plugins.emplace(native_registrar, plugin.get());
  registrar->AddPlugin(std::move(plugin));
}

void WebviewWindowsPlugin::PrepareForShutdown(
    FlutterDesktopPluginRegistrarRef registrar) {
  const auto plugin = registered_plugins.find(registrar);
  if (plugin != registered_plugins.end()) plugin->second->Dispose();
}

WebviewWindowsPlugin::WebviewWindowsPlugin(
    FlutterDesktopPluginRegistrarRef registrar, flutter::TextureRegistrar* textures,
    flutter::BinaryMessenger* messenger)
    : registrar_(registrar), textures_(textures), messenger_(messenger) {
  window_class_.lpszClassName = L"FlutterWebviewMessage";
  window_class_.lpfnWndProc = &DefWindowProc;
  RegisterClass(&window_class_);
}

WebviewWindowsPlugin::~WebviewWindowsPlugin() {
  Dispose();
  registered_plugins.erase(registrar_);
  UnregisterClass(window_class_.lpszClassName, nullptr);
}

void WebviewWindowsPlugin::Dispose() {
  if (!alive_) return;
  alive_.reset();
  pending_initializations_.clear();
  instances_.clear();
  webview_host_.reset();
}

void WebviewWindowsPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!alive_) {
    return result->Error("webview_closed", "The WebView plugin is shutting down");
  }

  if (method_call.method_name().compare(kMethodInitializeEnvironment) == 0) {
    if (webview_host_ || !pending_initializations_.empty()) {
      return result->Error(kErrorCodeEnvironmentAlreadyInitialized,
                           "The webview environment is already initialized");
    }

    const auto& map = std::get<flutter::EncodableMap>(*method_call.arguments());

    std::optional<std::wstring> browser_exe_wpath = std::nullopt;
    std::optional<std::string> browser_exe_path =
        GetOptionalValue<std::string>(map, "browserExePath");
    if (browser_exe_path) {
      browser_exe_wpath = util::Utf16FromUtf8(*browser_exe_path);
    }

    std::optional<std::wstring> user_data_wpath = std::nullopt;
    std::optional<std::string> user_data_path =
        GetOptionalValue<std::string>(map, "userDataPath");
    if (user_data_path) {
      user_data_wpath = util::Utf16FromUtf8(*user_data_path);
    }

    std::optional<std::string> additional_args =
        GetOptionalValue<std::string>(map, "additionalArguments");

    return Initialize({InitializationKind::kEnvironment, std::move(result)},
                      std::move(user_data_wpath), browser_exe_wpath,
                      additional_args);
  }

  if (method_call.method_name().compare(kMethodGetWebViewVersion) == 0) {
    LPWSTR version_info = nullptr;
    auto hr =
        GetAvailableCoreWebView2BrowserVersionString(nullptr, &version_info);
    if (SUCCEEDED(hr) && version_info != nullptr) {
      return result->Success(
          flutter::EncodableValue(util::Utf8FromUtf16(version_info)));
    } else {
      return result->Success();
    }
  }

  if (method_call.method_name() == kMethodInitialize ||
      method_call.method_name() == kMethodInitializeRestricted) {
    const auto kind = method_call.method_name() == kMethodInitializeRestricted
                          ? InitializationKind::kRestrictedWebview
                          : InitializationKind::kWebview;
    return Initialize({kind, std::move(result)});
  }

  if (method_call.method_name().compare(kMethodDispose) == 0) {
    if (const auto texture_id = std::get_if<int64_t>(method_call.arguments())) {
      const auto it = instances_.find(*texture_id);
      if (it != instances_.end()) {
        instances_.erase(it);
        return result->Success();
      }
    }
    return result->Error(kErrorCodeInvalidId);
  } else {
    result->NotImplemented();
  }
}

void WebviewWindowsPlugin::Initialize(
    PendingInitialization request, std::optional<std::wstring> user_data_path,
    const std::optional<std::wstring>& browser_exe_path,
    const std::optional<std::string>& additional_args) {
  if (!InitPlatform()) {
    return request.result->Error(kErrorUnsupportedPlatform,
                                 "The platform is not supported");
  }

  if (webview_host_) {
    return CompleteInitialization(std::move(request));
  }

  // All first-use requests share the same in-flight environment creation.
  pending_initializations_.push_back(std::move(request));
  if (pending_initializations_.size() != 1) return;
  if (!user_data_path) user_data_path = platform_->GetDefaultDataDirectory();
  WebviewHost::CreateEnvironment(
      user_data_path, browser_exe_path, additional_args,
      [this, alive = std::weak_ptr<bool>(alive_)](
          wil::com_ptr<ICoreWebView2Environment3> environment) {
        if (alive.expired()) return;
        if (environment) {
          auto host = std::make_shared<WebviewHost>(platform_.get(),
                                                    std::move(environment));
          if (host->compositor()) webview_host_ = std::move(host);
        }
        std::vector<PendingInitialization> requests;
        requests.swap(pending_initializations_);
        for (auto& pending : requests) {
          if (alive.expired()) return;
          CompleteInitialization(std::move(pending));
        }
      });
}

void WebviewWindowsPlugin::CompleteInitialization(PendingInitialization request) {
  if (!webview_host_) {
    return request.result->Error(kErrorCodeEnvironmentCreationFailed);
  }
  if (request.kind == InitializationKind::kEnvironment) {
    return request.result->Success();
  }
  CreateWebviewInstance(std::move(request.result),
                        request.kind == InitializationKind::kRestrictedWebview);
}

void WebviewWindowsPlugin::CreateWebviewInstance(
    std::unique_ptr<MethodResult> result, bool restricted) {
  auto hwnd =
      CreateWindowEx(0, window_class_.lpszClassName, L"", 0, 0, 0, 0, 0,
                     HWND_MESSAGE, nullptr, window_class_.hInstance, nullptr);

  if (!hwnd) return result->Error(kErrorCodeWebviewCreationFailed, "Creating preview window failed.");
  std::shared_ptr<MethodResult> shared_result = std::move(result);
  const auto host = webview_host_;
  host->CreateWebview(
      hwnd, true, true, restricted,
      [shared_result, this, alive = std::weak_ptr<bool>(alive_)](std::unique_ptr<Webview> webview,
                            std::unique_ptr<WebviewCreationError> error) {
        if (alive.expired()) return;
        if (!webview) {
          if (error) {
            return shared_result->Error(
                kErrorCodeWebviewCreationFailed,
                std::format(
                    "Creating the webview failed: {} (HRESULT: {:#010x})",
                    error->message, error->hr));
          }
          return shared_result->Error(kErrorCodeWebviewCreationFailed,
                                      "Creating the webview failed.");
        }

        auto bridge = std::make_unique<WebviewBridge>(
            messenger_, textures_, platform_->graphics_context(),
            std::move(webview));
        auto texture_id = bridge->texture_id();
        instances_[texture_id] = std::move(bridge);

        auto response = flutter::EncodableValue(flutter::EncodableMap{
            {flutter::EncodableValue("textureId"),
             flutter::EncodableValue(texture_id)},
        });

        shared_result->Success(response);
      });
}

bool WebviewWindowsPlugin::InitPlatform() {
  if (!platform_) {
    platform_ = std::make_unique<WebviewPlatform>();
  }
  return platform_->IsSupported();
}

}  // namespace

void WebviewWindowsPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  WebviewWindowsPlugin::RegisterWithRegistrar(registrar);
}

void WebviewWindowsPluginPrepareForShutdown(
    FlutterDesktopPluginRegistrarRef registrar) {
  WebviewWindowsPlugin::PrepareForShutdown(registrar);
}
