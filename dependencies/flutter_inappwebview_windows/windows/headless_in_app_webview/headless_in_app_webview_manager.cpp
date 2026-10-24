#include <DispatcherQueue.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <shlobj.h>
#include <windows.graphics.capture.h>

#include "../in_app_webview/in_app_webview_settings.h"
#include "../in_app_webview/in_app_webview_manager.h"
#include "../types/size_2d.h"
#include "../types/url_request.h"
#include "../types/user_script.h"
#include "../utils/flutter.h"
#include "../utils/log.h"
#include "../utils/map.h"
#include "../utils/string.h"
#include "../utils/vector.h"
#include "../webview_environment/webview_environment_manager.h"
#include "headless_in_app_webview_manager.h"

namespace flutter_inappwebview_plugin
{
  HeadlessInAppWebViewManager::HeadlessInAppWebViewManager(const FlutterInappwebviewWindowsPlugin* plugin)
    : plugin(plugin),
    ChannelDelegate(plugin->registrar->messenger(), HeadlessInAppWebViewManager::METHOD_CHANNEL_NAME)
  {
    windowClass_.lpszClassName = HeadlessInAppWebView::CLASS_NAME;
    windowClass_.lpfnWndProc = &DefWindowProc;

    RegisterClass(&windowClass_);
  }

  void HeadlessInAppWebViewManager::HandleMethodCall(const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
  {
    auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
    auto& methodName = method_call.method_name();

    if (string_equals(methodName, "run")) {
      run(arguments, std::move(result));
    }
    else {
      result->NotImplemented();
    }
  }

  void HeadlessInAppWebViewManager::run(const flutter::EncodableMap* arguments, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
  {
    auto result_ = std::shared_ptr<flutter::MethodResult<flutter::EncodableValue>>(std::move(result));

    if (!plugin || !plugin->inAppWebViewManager || !plugin->inAppWebViewManager->isSupported()) {
      result_->Error("0", "Cannot create the HeadlessInAppWebView instance!");
      return;
    }

    auto id = get_fl_map_value<std::string>(*arguments, "id");
    auto params = get_fl_map_value<flutter::EncodableMap>(*arguments, "params");

    const auto windowId = get_optional_fl_map_value<int64_t>(params, "windowId");
    auto pendingWindow = plugin->inAppWebViewManager->pendingWindow(windowId);
    if (windowId.has_value() && (!pendingWindow || pendingWindow->completed)) {
      result_->Error("0", "Popup request is no longer available");
      return;
    }

    auto initialSize = std::make_shared<Size2D>(get_fl_map_value<flutter::EncodableMap>(params, "initialSize"));

    auto settingsMap = get_fl_map_value<flutter::EncodableMap>(params, "initialSettings");
    auto urlRequestMap = get_optional_fl_map_value<flutter::EncodableMap>(params, "initialUrlRequest");
    auto initialFile = get_optional_fl_map_value<std::string>(params, "initialFile");
    auto initialDataMap = get_optional_fl_map_value<flutter::EncodableMap>(params, "initialData");
    auto initialUserScriptList = get_optional_fl_map_value<flutter::EncodableList>(params, "initialUserScripts");
    auto webViewEnvironmentId = get_optional_fl_map_value<std::string>(params, "webViewEnvironmentId");

    RECT bounds;
    GetClientRect(plugin->registrar->GetView()->GetNativeWindow(), &bounds);

    auto initialWidth = initialSize->width >= 0 ? initialSize->width : bounds.right - bounds.left;
    auto initialHeight = initialSize->height >= 0 ? initialSize->height : bounds.bottom - bounds.top;

    auto hwnd = CreateWindowEx(0, windowClass_.lpszClassName, L"", 0, 0,
      0, (int)initialWidth, (int)initialHeight,
      plugin->registrar->GetView()->GetNativeWindow(),
      nullptr,
      windowClass_.hInstance, nullptr);

    auto webViewEnvironment = webViewEnvironmentId.has_value() && map_contains(plugin->webViewEnvironmentManager->webViewEnvironments, webViewEnvironmentId.value())
      ? plugin->webViewEnvironmentManager->webViewEnvironments.at(webViewEnvironmentId.value()).get() : nullptr;

    auto initialSettings = std::make_shared<InAppWebViewSettings>(settingsMap);

    InAppWebView::createInAppWebViewEnv(hwnd, true, webViewEnvironment, initialSettings,
      [=](wil::com_ptr<ICoreWebView2Environment> webViewEnv,
        wil::com_ptr<ICoreWebView2Controller> webViewController,
        wil::com_ptr<ICoreWebView2CompositionController> webViewCompositionController)
      {
        if (plugin && webViewEnv && webViewController && webViewCompositionController) {
          std::optional<std::vector<std::shared_ptr<UserScript>>> initialUserScripts = initialUserScriptList.has_value() ?
            functional_map(initialUserScriptList.value(), [](const flutter::EncodableValue& map) { return std::make_shared<UserScript>(std::get<flutter::EncodableMap>(map)); }) :
            std::optional<std::vector<std::shared_ptr<UserScript>>>{};

          InAppWebViewCreationParams params = {
            id,
            std::move(initialSettings),
            initialUserScripts,
            pendingWindow != nullptr
          };

          auto inAppWebView = std::make_unique<InAppWebView>(plugin, params, hwnd,
            std::move(webViewEnv), std::move(webViewController), std::move(webViewCompositionController)
          );

          HeadlessInAppWebViewCreationParams headlessParams = {
            id,
            std::move(initialSize)
          };

          auto retained = std::make_shared<HeadlessInAppWebView>(plugin,
            headlessParams, hwnd, std::move(inAppWebView));
          retained->webView->initChannel(std::nullopt, std::nullopt);
          // Retain the child while bridge bindings and initial scripts finish.
          // NewWindow's first document must see the complete initialization.
          retained->webView->whenReady([=](HRESULT scriptResult) {
            auto handoff = scriptResult;
            if (pendingWindow) {
              if (SUCCEEDED(handoff)) handoff = pendingWindow->complete(retained->webView->webView.get(),
                [retained] { retained->webView->registerPopupEventHandlers(); });
              if (!pendingWindow->completed) pendingWindow->complete();
              plugin->inAppWebViewManager->windowWebViews.erase(windowId.value());
            }
            if (FAILED(handoff)) {
              result_->Error("0", "Cannot initialize or attach the headless WebView");
              return;
            }
            webViews.insert({ id, retained });
            if (retained->channelDelegate) retained->channelDelegate->onWebViewCreated();
            if (!pendingWindow) {
              if (urlRequestMap.has_value()) retained->webView->loadUrl(std::make_shared<URLRequest>(urlRequestMap.value()));
              else if (initialFile.has_value()) retained->webView->loadFile(initialFile.value());
              else if (initialDataMap.has_value()) retained->webView->loadData(get_fl_map_value<std::string>(initialDataMap.value(), "data"));
            }
            result_->Success(true);
          });
        }
        else {
          if (pendingWindow) {
            pendingWindow->complete();
            plugin->inAppWebViewManager->windowWebViews.erase(windowId.value());
          }
          DestroyWindow(hwnd);
          result_->Error("0", "Cannot create the HeadlessInAppWebView instance!");
        }
      }, pendingWindow ? pendingWindow->environment : nullptr
    );
  }

  HeadlessInAppWebViewManager::~HeadlessInAppWebViewManager()
  {
    debugLog("dealloc HeadlessInAppWebViewManager");
    webViews.clear();
    UnregisterClass(windowClass_.lpszClassName, nullptr);
    plugin = nullptr;
  }
}