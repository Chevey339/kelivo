#include <DispatcherQueue.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <shlobj.h>
#include <windows.graphics.capture.h>

#include "../headless_in_app_webview/headless_in_app_webview_manager.h"
#include "../in_app_webview/in_app_webview_settings.h"
#include "../types/url_request.h"
#include "../types/user_script.h"
#include "../utils/flutter.h"
#include "../utils/log.h"
#include "../utils/string.h"
#include "../utils/vector.h"
#include "../webview_environment/webview_environment_manager.h"
#include "in_app_webview_manager.h"

namespace flutter_inappwebview_plugin
{
  InAppWebViewManager::InAppWebViewManager(const FlutterInappwebviewWindowsPlugin* plugin)
    : plugin(plugin),
    ChannelDelegate(plugin->registrar->messenger(), InAppWebViewManager::METHOD_CHANNEL_NAME)
  {
    if (!rohelper_) {
      rohelper_ = std::make_unique<rx::RoHelper>(RO_INIT_SINGLETHREADED);

      if (rohelper_->WinRtAvailable()) {
        DispatcherQueueOptions options{ sizeof(DispatcherQueueOptions),
                                       DQTYPE_THREAD_CURRENT, DQTAT_COM_STA };

        if (FAILED(rohelper_->CreateDispatcherQueueController(
          options, dispatcher_queue_controller_.put()))) {
          std::cerr << "Creating DispatcherQueueController failed." << std::endl;
          return;
        }

        if (!isGraphicsCaptureSessionSupported()) {
          std::cerr << "Windows::Graphics::Capture::GraphicsCaptureSession is not "
            "supported."
            << std::endl;
          return;
        }

        graphics_context_ = std::make_unique<GraphicsContext>(rohelper_.get());
        compositor_ = graphics_context_->CreateCompositor();
        valid_ = graphics_context_->IsValid();
      }
    }

    windowClass_.lpszClassName = CustomPlatformView::CLASS_NAME;
    windowClass_.lpfnWndProc = &DefWindowProc;

    RegisterClass(&windowClass_);
  }

  void InAppWebViewManager::HandleMethodCall(const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
  {
    auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
    auto& methodName = method_call.method_name();

    if (string_equals(methodName, "createInAppWebView")) {
      if (isSupported()) {
        createInAppWebView(arguments, std::move(result));
      }
      else {
        result->Error("0", "Creating an InAppWebView instance is not supported! Graphics Context is not valid!");
      }
    }
    else if (string_equals(methodName, "dispose")) {
      auto id = get_fl_map_value<int64_t>(*arguments, "id");
      if (map_contains(webViews, (uint64_t)id)) {
        auto platformView = webViews.at(id).get();
        if (platformView) {
          platformView->UnregisterMethodCallHandler();
        }
        webViews.erase(id);
      }
      result->Success();
    }
    else if (string_equals(methodName, "disposeKeepAlive")) {
      auto keepAliveId = get_fl_map_value<std::string>(*arguments, "keepAliveId");
      disposeKeepAlive(keepAliveId);
      result->Success();
    }
    else {
      result->NotImplemented();
    }
  }

  void InAppWebViewManager::createInAppWebView(const flutter::EncodableMap* arguments, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
  {
    auto result_ = std::shared_ptr<flutter::MethodResult<flutter::EncodableValue>>(std::move(result));

    if (!plugin) {
      result_->Error("0", "Cannot create the InAppWebView instance!");
      return;
    }

    auto settingsMap = get_fl_map_value<flutter::EncodableMap>(*arguments, "initialSettings");
    auto urlRequestMap = get_optional_fl_map_value<flutter::EncodableMap>(*arguments, "initialUrlRequest");
    auto initialFile = get_optional_fl_map_value<std::string>(*arguments, "initialFile");
    auto initialDataMap = get_optional_fl_map_value<flutter::EncodableMap>(*arguments, "initialData");
    auto initialUserScriptList = get_optional_fl_map_value<flutter::EncodableList>(*arguments, "initialUserScripts");
    auto webViewEnvironmentId = get_optional_fl_map_value<std::string>(*arguments, "webViewEnvironmentId");
    auto keepAliveId = get_optional_fl_map_value<std::string>(*arguments, "keepAliveId");
    auto windowId = get_optional_fl_map_value<int64_t>(*arguments, "windowId");

    const auto headlessId = get_optional_fl_map_value<std::string>(*arguments, "headlessWebViewId");
    std::shared_ptr<InAppWebView> retainedView;
    if (keepAliveId.has_value() && map_contains(keepAliveWebViews, keepAliveId.value())) {
      retainedView = keepAliveWebViews.at(keepAliveId.value())->view;
      keepAliveWebViews.erase(keepAliveId.value());
    }
    else if (headlessId.has_value() && plugin->headlessInAppWebViewManager) {
      auto& headlessViews = plugin->headlessInAppWebViewManager->webViews;
      const auto found = headlessViews.find(headlessId.value());
      if (found != headlessViews.end()) {
        // Move ownership before destroying the headless wrapper. Its document,
        // scripts, navigation history, channel and composition surface survive.
        retainedView = std::move(found->second->webView);
        found->second->channelDelegate->UnregisterMethodCallHandler();
        headlessViews.erase(found);
      }
    }
    if (retainedView) {
      HWND retainedWindow = nullptr;
      retainedView->webViewController->get_ParentWindow(&retainedWindow);
      auto platformView = std::make_unique<CustomPlatformView>(plugin->registrar->messenger(),
        plugin->registrar->texture_registrar(), graphics_context(), retainedWindow, std::move(retainedView));
      const auto textureId = platformView->texture_id();
      if (keepAliveId.has_value()) {
        keepAliveWebViews.insert({ keepAliveId.value(), std::move(platformView) });
      }
      else {
        webViews.insert({ textureId, std::move(platformView) });
      }
      result_->Success(textureId);
      return;
    }

    auto pending = pendingWindow(windowId);
    if (windowId.has_value() && (!pending || pending->completed)) {
      result_->Error("0", "Popup request is no longer available");
      return;
    }

    RECT bounds;
    GetClientRect(plugin->registrar->GetView()->GetNativeWindow(), &bounds);
    auto hwnd = CreateWindowEx(0, windowClass_.lpszClassName, L"", 0, 0,
      0, bounds.right - bounds.left, bounds.bottom - bounds.top,
      plugin->registrar->GetView()->GetNativeWindow(), nullptr, windowClass_.hInstance, nullptr);

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
            "",
            std::move(initialSettings),
            initialUserScripts,
            pending != nullptr
          };

          auto inAppWebView = std::make_shared<InAppWebView>(plugin, params, hwnd, std::move(webViewEnv), std::move(webViewController), std::move(webViewCompositionController));
          auto finish = [=](HRESULT scriptResult) {
            if (FAILED(scriptResult)) {
              if (pending) {
                pending->complete();
                windowWebViews.erase(windowId.value());
              }
              result_->Error("0", "Cannot initialize the WebView scripts");
              return;
            }
            if (pending) {
              const auto handoff = SUCCEEDED(scriptResult) ? pending->complete(inAppWebView->webView.get(), [inAppWebView] { inAppWebView->registerPopupEventHandlers(); }) : scriptResult;
              if (!pending->completed) pending->complete();
              windowWebViews.erase(windowId.value());
              if (FAILED(handoff)) {
                result_->Error("0", "Cannot attach the popup WebView");
                return;
              }
            }
            else {
              std::optional<std::shared_ptr<URLRequest>> urlRequest = urlRequestMap.has_value() ? std::make_shared<URLRequest>(urlRequestMap.value()) : std::optional<std::shared_ptr<URLRequest>>{};
              if (urlRequest.has_value()) inAppWebView->loadUrl(urlRequest.value());
              else if (initialFile.has_value()) inAppWebView->loadFile(initialFile.value());
              else if (initialDataMap.has_value()) inAppWebView->loadData(get_fl_map_value<std::string>(initialDataMap.value(), "data"));
            }
            auto customPlatformView = std::make_unique<CustomPlatformView>(plugin->registrar->messenger(),
              plugin->registrar->texture_registrar(), graphics_context(), hwnd, inAppWebView);
            auto textureId = customPlatformView->texture_id();
            if (keepAliveId.has_value()) {
              customPlatformView->view->initChannel(keepAliveId.value(), std::nullopt);
              keepAliveWebViews.insert({ keepAliveId.value(), std::move(customPlatformView) });
            }
            else {
              customPlatformView->view->initChannel(textureId, std::nullopt);
              webViews.insert({ textureId, std::move(customPlatformView) });
            }
            result_->Success(textureId);
          };
          inAppWebView->whenReady(finish);
        }
        else {
          if (pending) {
            pending->complete();
            windowWebViews.erase(windowId.value());
          }
          DestroyWindow(hwnd);
          result_->Error("0", "Cannot create the InAppWebView instance!");
        }
      }, pending ? pending->environment : nullptr
    );
  }

  std::shared_ptr<NewWindowRequestedArgs> InAppWebViewManager::pendingWindow(const std::optional<int64_t>& windowId) const
  {
    if (!windowId.has_value()) return nullptr;
    const auto found = windowWebViews.find(windowId.value());
    return found == windowWebViews.end() ? nullptr : found->second;
  }

  void InAppWebViewManager::disposeKeepAlive(const std::string& keepAliveId)
  {
    if (map_contains(keepAliveWebViews, keepAliveId)) {
      auto platformView = keepAliveWebViews.at(keepAliveId).get();
      if (platformView) {
        platformView->UnregisterMethodCallHandler();
      }
      keepAliveWebViews.erase(keepAliveId);
    }
  }

  bool InAppWebViewManager::isGraphicsCaptureSessionSupported()
  {
    HSTRING className;
    HSTRING_HEADER classNameHeader;

    if (FAILED(rohelper_->GetStringReference(
      RuntimeClass_Windows_Graphics_Capture_GraphicsCaptureSession,
      &className, &classNameHeader))) {
      return false;
    }

    ABI::Windows::Graphics::Capture::IGraphicsCaptureSessionStatics*
      capture_session_statics;
    if (FAILED(rohelper_->GetActivationFactory(
      className,
      __uuidof(
        ABI::Windows::Graphics::Capture::IGraphicsCaptureSessionStatics),
      (void**)&capture_session_statics))) {
      return false;
    }

    boolean is_supported = false;
    if (FAILED(capture_session_statics->IsSupported(&is_supported))) {
      return false;
    }

    return !!is_supported;
  }

  InAppWebViewManager::~InAppWebViewManager()
  {
    debugLog("dealloc InAppWebViewManager");
    *alive = false;
    webViews.clear();
    keepAliveWebViews.clear();
    windowWebViews.clear();
    UnregisterClass(windowClass_.lpszClassName, nullptr);
    plugin = nullptr;
  }
}
