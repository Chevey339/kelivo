#include "webview_host.h"

#include <windows.foundation.h>
#include <wrl.h>

using namespace Microsoft::WRL;

// static
void WebviewHost::CreateEnvironment(
    const std::optional<std::wstring>& user_data_directory,
    const std::optional<std::wstring>& browser_exe_path,
    const std::optional<std::string>& arguments,
    EnvironmentCreationCallback callback) {
  wil::com_ptr<CoreWebView2EnvironmentOptions> opts;
  if (arguments.has_value()) {
    opts = Microsoft::WRL::Make<CoreWebView2EnvironmentOptions>();
    std::wstring warguments(arguments.value().begin(), arguments.value().end());
    opts->put_AdditionalBrowserArguments(warguments.c_str());
  }

  // WebView2 dispatches completion on the calling STA's message pump.
  const auto result = CreateCoreWebView2EnvironmentWithOptions(
      browser_exe_path.has_value() ? browser_exe_path->c_str() : nullptr,
      user_data_directory.has_value() ? user_data_directory->c_str() : nullptr,
      opts.get(),
      Callback<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler>(
          [callback](HRESULT hr, ICoreWebView2Environment* environment)
              -> HRESULT {
            wil::com_ptr<ICoreWebView2Environment3> environment3;
            if (SUCCEEDED(hr) && environment) {
              environment3 = wil::com_ptr<ICoreWebView2Environment>(environment)
                                 .try_query<ICoreWebView2Environment3>();
            }
            callback(std::move(environment3));
            return S_OK;
          })
          .Get());

  if (FAILED(result)) callback({});
}

WebviewHost::WebviewHost(WebviewPlatform* platform,
                         wil::com_ptr<ICoreWebView2Environment3> webview_env)
    : webview_env_(std::move(webview_env)) {
  compositor_ = platform->graphics_context()->CreateCompositor();
}

WebviewHost::~WebviewHost() {
  if (auto closable = compositor_.try_as<ABI::Windows::Foundation::IClosable>()) {
    closable->Close();
  }
}

void WebviewHost::CreateWebview(HWND hwnd, bool offscreen_only,
                                bool owns_window, bool restricted,
                                WebviewCreationCallback callback) {
  CreateWebViewCompositionController(
      hwnd, [=, host = weak_from_this()](
                wil::com_ptr<ICoreWebView2CompositionController> controller,
                std::unique_ptr<WebviewCreationError> error) {
        const auto self = host.lock();
        if (controller && self) {
          std::unique_ptr<Webview> webview(new Webview(
              std::move(controller), self.get(), hwnd, owns_window, offscreen_only, restricted));
          if (!webview->IsValid()) {
            callback(nullptr, WebviewCreationError::create(
                webview->InitializationResult(), restricted
                    ? "Restricted preview initialization failed; update WebView2 Runtime if unsupported."
                    : "Webview initialization failed."));
            return;
          }
          callback(std::move(webview), nullptr);
        } else {
          // A late controller must not use the compositor after shutdown.
          if (controller) {
            if (auto view_controller =
                    controller.try_query<ICoreWebView2Controller>()) {
              view_controller->Close();
            }
          }
          if (owns_window) DestroyWindow(hwnd);
          callback(nullptr, std::move(error));
        }
      });
}

void WebviewHost::CreateWebViewPointerInfo(PointerInfoCreationCallback callback) {

  ICoreWebView2PointerInfo *pointer;
  auto hr = webview_env_->CreateCoreWebView2PointerInfo(&pointer);

  if (FAILED(hr)) {
    callback(nullptr, WebviewCreationError::create(hr, "CreateWebViewPointerInfo failed."));
  } else if (SUCCEEDED(hr)) {
    callback(std::move(wil::com_ptr<ICoreWebView2PointerInfo>(pointer)), nullptr);
  }
}

void WebviewHost::CreateWebViewCompositionController(
    HWND hwnd, CompositionControllerCreationCallback callback) {
  auto hr = webview_env_->CreateCoreWebView2CompositionController(
      hwnd,
      Callback<
          ICoreWebView2CreateCoreWebView2CompositionControllerCompletedHandler>(
          [callback](HRESULT hr,
                     ICoreWebView2CompositionController* compositionController)
              -> HRESULT {
            if (SUCCEEDED(hr)) {
              callback(
                  std::move(wil::com_ptr<ICoreWebView2CompositionController>(
                      compositionController)),
                  nullptr);
            } else {
              callback(nullptr, WebviewCreationError::create(
                                    hr,
                                    "CreateCoreWebView2CompositionController "
                                    "completion handler failed."));
            }

            return S_OK;
          })
          .Get());

  if (FAILED(hr)) {
    callback(nullptr,
             WebviewCreationError::create(
                 hr, "CreateCoreWebView2CompositionController failed."));
  }
}
