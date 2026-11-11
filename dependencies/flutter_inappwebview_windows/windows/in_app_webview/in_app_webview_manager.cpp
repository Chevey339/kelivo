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
#include "../utils/initialization_error.h"
#include "../custom_platform_view/util/dispatcher_queue.h"
#include "../utils/string.h"
#include "../utils/vector.h"
#include "../webview_environment/webview_environment_manager.h"
#include "in_app_webview_manager.h"

namespace flutter_inappwebview_plugin
{
  InAppWebViewManager::InAppWebViewManager(const FlutterInappwebviewWindowsPlugin* plugin)
    : plugin(plugin),
    ChannelDelegate(plugin->messenger(), InAppWebViewManager::METHOD_CHANNEL_NAME)
  {
    rohelper_ = std::make_unique<rx::RoHelper>(RO_INIT_SINGLETHREADED);
    initializationResult_ = rohelper_->initializationResult();
    if (FAILED(initializationResult_)) return;

    // A thread can only have one queue. Borrow an existing queue without
    // shutting it down when this plugin is destroyed.
    initializationStage_ = "GetForCurrentThread(DispatcherQueue)";
    HSTRING className;
    HSTRING_HEADER classNameHeader;
    initializationResult_ = rohelper_->GetStringReference(
      RuntimeClass_Windows_System_DispatcherQueue, &className, &classNameHeader);
    if (FAILED(initializationResult_)) return;
    winrt::com_ptr<ABI::Windows::System::IDispatcherQueueStatics> queueStatics;
    initializationResult_ = rohelper_->GetActivationFactory(className,
      __uuidof(ABI::Windows::System::IDispatcherQueueStatics), queueStatics.put_void());
    if (FAILED(initializationResult_)) return;
    winrt::com_ptr<ABI::Windows::System::IDispatcherQueue> queue;
    initializationResult_ = queueStatics->GetForCurrentThread(queue.put());
    if (FAILED(initializationResult_)) return;
    if (!queue) {
      initializationStage_ = "CreateDispatcherQueueController";
      DispatcherQueueOptions options{ sizeof(DispatcherQueueOptions),
        DQTYPE_THREAD_CURRENT, DQTAT_COM_STA };
      initializationResult_ = rohelper_->CreateDispatcherQueueController(
        options, dispatcher_queue_controller_.put());
      if (FAILED(initializationResult_)) return;
    }

    initializationStage_ = "GraphicsCaptureSession.IsSupported";
    initializationResult_ = checkGraphicsCaptureSupport();
    if (FAILED(initializationResult_)) return;
    initializationStage_ = "CreateD3DDevice";
    graphics_context_ = std::make_unique<GraphicsContext>(rohelper_.get());
    initializationResult_ = graphics_context_->initializationResult();
    if (FAILED(initializationResult_)) return;
    initializationStage_ = "CreateCompositor";
    initializationResult_ = graphics_context_->CreateCompositor(compositor_);
    if (FAILED(initializationResult_)) return;

    windowClass_.lpszClassName = CustomPlatformView::CLASS_NAME;
    windowClass_.lpfnWndProc = &DefWindowProc;

    initializationStage_ = "RegisterClass(CustomPlatformView)";
    if (!RegisterClass(&windowClass_) && GetLastError() != ERROR_CLASS_ALREADY_EXISTS) {
      initializationResult_ = HRESULT_FROM_WIN32(GetLastError());
      return;
    }
    initializationResult_ = S_OK;
    valid_ = true;
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
        reportInitializationError(result.get(), initializationResult_, initializationStage_);
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
      auto platformView = std::make_unique<CustomPlatformView>(plugin->messenger(),
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
    if (!hwnd) {
      reportInitializationError(result_.get(), HRESULT_FROM_WIN32(GetLastError()), "CreateWindowEx(InAppWebView)");
      return;
    }

    auto webViewEnvironment = webViewEnvironmentId.has_value() && map_contains(plugin->webViewEnvironmentManager->webViewEnvironments, webViewEnvironmentId.value())
      ? plugin->webViewEnvironmentManager->webViewEnvironments.at(webViewEnvironmentId.value()).get() : nullptr;

    auto initialSettings = std::make_shared<InAppWebViewSettings>(settingsMap);

    InAppWebView::createInAppWebViewEnv(plugin, hwnd, true, webViewEnvironment, initialSettings,
      [=](HRESULT creationResult, const std::string& creationStage, wil::com_ptr<ICoreWebView2Environment> webViewEnv,
        wil::com_ptr<ICoreWebView2Controller> webViewController,
        wil::com_ptr<ICoreWebView2CompositionController> webViewCompositionController)
      {
        if (SUCCEEDED(creationResult)) {
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
          pendingWebViews_.insert({ hwnd, inAppWebView });
          auto finish = [=, lifetime = plugin->alive,
            weak = std::weak_ptr<InAppWebView>(inAppWebView)](HRESULT scriptResult) {
            if (!*lifetime) return;
            auto inAppWebView = weak.lock();
            if (!inAppWebView) return;
            pendingWebViews_.erase(hwnd);
            if (FAILED(scriptResult)) {
              if (pending) {
                pending->complete();
                windowWebViews.erase(windowId.value());
              }
              reportInitializationError(result_.get(), scriptResult, "Initialize WebView scripts");
              return;
            }
            if (pending) {
              const auto handoff = SUCCEEDED(scriptResult) ? pending->complete(inAppWebView->webView.get(), [inAppWebView] { inAppWebView->registerPopupEventHandlers(); }) : scriptResult;
              if (!pending->completed) pending->complete();
              windowWebViews.erase(windowId.value());
              if (FAILED(handoff)) {
                reportInitializationError(result_.get(), handoff, "Attach popup WebView");
                return;
              }
            }
            else {
              std::optional<std::shared_ptr<URLRequest>> urlRequest = urlRequestMap.has_value() ? std::make_shared<URLRequest>(urlRequestMap.value()) : std::optional<std::shared_ptr<URLRequest>>{};
              if (urlRequest.has_value()) inAppWebView->loadUrl(urlRequest.value());
              else if (initialFile.has_value()) inAppWebView->loadFile(initialFile.value());
              else if (initialDataMap.has_value()) inAppWebView->loadData(get_fl_map_value<std::string>(initialDataMap.value(), "data"));
            }
            auto customPlatformView = std::make_unique<CustomPlatformView>(plugin->messenger(),
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
          reportInitializationError(result_.get(), creationResult, creationStage);
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

  HRESULT InAppWebViewManager::checkGraphicsCaptureSupport()
  {
    HSTRING className;
    HSTRING_HEADER classNameHeader;
    auto hr = rohelper_->GetStringReference(
      RuntimeClass_Windows_Graphics_Capture_GraphicsCaptureSession,
      &className, &classNameHeader);
    if (FAILED(hr)) return hr;
    winrt::com_ptr<ABI::Windows::Graphics::Capture::IGraphicsCaptureSessionStatics> statics;
    hr = rohelper_->GetActivationFactory(className,
      __uuidof(ABI::Windows::Graphics::Capture::IGraphicsCaptureSessionStatics),
      statics.put_void());
    if (FAILED(hr)) return hr;
    boolean supported = false;
    hr = statics->IsSupported(&supported);
    return FAILED(hr) ? hr : supported ? S_OK : HRESULT_FROM_WIN32(ERROR_NOT_SUPPORTED);
  }

  void InAppWebViewManager::disposeWebViews()
  {
    *alive = false;
    UnregisterMethodCallHandler();
    pendingWebViews_.clear();
    webViews.clear();
    keepAliveWebViews.clear();
    windowWebViews.clear();
  }

  InAppWebViewManager::~InAppWebViewManager()
  {
    debugLog("dealloc InAppWebViewManager");
    disposeWebViews();
    if (windowClass_.lpszClassName) UnregisterClass(windowClass_.lpszClassName, nullptr);
    plugin = nullptr;
    if (auto closable = compositor_.try_as<ABI::Windows::Foundation::IClosable>()) {
      failedLog(closable->Close());
    }
    compositor_ = nullptr;
    graphics_context_.reset();
    failedLog(shutdownDispatcherQueue(dispatcher_queue_controller_.get()));
    dispatcher_queue_controller_ = nullptr;
    rohelper_.reset();
  }
}
