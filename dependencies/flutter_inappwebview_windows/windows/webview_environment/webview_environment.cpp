#include <WebView2EnvironmentOptions.h>
#include <wil/wrl.h>

#include "../utils/log.h"
#include "webview_environment.h"
#include "kelivo_scheme.h"

#include "webview_environment_manager.h"

namespace flutter_inappwebview_plugin
{
  using namespace Microsoft::WRL;

  WebViewEnvironment::WebViewEnvironment(const FlutterInappwebviewWindowsPlugin* plugin, const std::string& id)
    : plugin(plugin), id(id),
    channelDelegate(std::make_unique<WebViewEnvironmentChannelDelegate>(this, plugin->messenger()))
  {}

  void WebViewEnvironment::create(const std::unique_ptr<WebViewEnvironmentSettings> settings,
    const std::function<void(HRESULT, const std::string&)> completionHandler)
  {
    if (!plugin) {
      if (completionHandler) {
        completionHandler(E_ABORT, "WebViewEnvironment disposed");
      }
      return;
    }

    auto hwnd = plugin->webViewEnvironmentManager->getHWND();
    if (!hwnd) {
      if (completionHandler) {
        completionHandler(plugin->webViewEnvironmentManager->windowCreationResult(), "CreateWindowEx(WebViewEnvironment)");
      }
      return;
    }

    auto options = Make<CoreWebView2EnvironmentOptions>();
    registerKelivoScheme(options.Get());
    if (settings) {
      if (settings->additionalBrowserArguments.has_value()) {
        options->put_AdditionalBrowserArguments(utf8_to_wide(settings->additionalBrowserArguments.value()).c_str());
      }
      if (settings->allowSingleSignOnUsingOSPrimaryAccount.has_value()) {
        options->put_AllowSingleSignOnUsingOSPrimaryAccount(settings->allowSingleSignOnUsingOSPrimaryAccount.value());
      }
      if (settings->language.has_value()) {
        options->put_Language(utf8_to_wide(settings->language.value()).c_str());
      }
      if (settings->targetCompatibleBrowserVersion.has_value()) {
        options->put_TargetCompatibleBrowserVersion(utf8_to_wide(settings->targetCompatibleBrowserVersion.value()).c_str());
      }
      wil::com_ptr<ICoreWebView2EnvironmentOptions4> options4;
      if (succeededOrLog(options->QueryInterface(IID_PPV_ARGS(&options4))) && settings->customSchemeRegistrations.has_value()) {
        std::vector<ICoreWebView2CustomSchemeRegistration*> registrations = {};
        for (auto& customSchemeRegistration : settings->customSchemeRegistrations.value()) {
          registrations.push_back(std::move(customSchemeRegistration->toWebView2CustomSchemeRegistration()));
        }
        options4->SetCustomSchemeRegistrations(static_cast<UINT32>(registrations.size()), registrations.data());
      }
    }

    auto hr = CreateCoreWebView2EnvironmentWithOptions(
      settings && settings->browserExecutableFolder.has_value() ? utf8_to_wide(settings->browserExecutableFolder.value()).c_str() : nullptr,
      settings && settings->userDataFolder.has_value() ? utf8_to_wide(settings->userDataFolder.value()).c_str() : nullptr,
      options.Get(),
      Callback<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler>(
        [this, alive = alive_, pluginAlive = plugin->alive, hwnd, completionHandler](HRESULT result, wil::com_ptr<ICoreWebView2Environment> environment) -> HRESULT
        {
          if (!*alive || !*pluginAlive) return S_OK;
          if (succeededOrLog(result)) {
            environment_ = std::move(environment);

            auto hr = environment_->CreateCoreWebView2Controller(hwnd, Callback<ICoreWebView2CreateCoreWebView2ControllerCompletedHandler>(
              [this, alive, pluginAlive, completionHandler](HRESULT result, wil::com_ptr<ICoreWebView2Controller> controller) -> HRESULT
              {
                if (!*alive || !*pluginAlive) {
                  if (controller) controller->Close();
                  return S_OK;
                }
                std::string stage = "CreateCoreWebView2Controller";
                if (succeededOrLog(result)) {
                  webViewController_ = std::move(controller);
                  stage = "get_CoreWebView2";
                  result = webViewController_->get_CoreWebView2(&webView_);
                  if (SUCCEEDED(result)) {
                    stage = "put_IsVisible";
                    result = webViewController_->put_IsVisible(false);
                  }
                }
                if (completionHandler) {
                  completionHandler(result, stage);
                }
                return S_OK;
              }).Get());

            if (failedAndLog(hr) && completionHandler) {
              completionHandler(hr, "CreateCoreWebView2Controller");
            }
          }
          else if (completionHandler) {
            completionHandler(result, "CreateCoreWebView2EnvironmentWithOptions");
          }
          return S_OK;
        }).Get());

    if (failedAndLog(hr) && completionHandler) {
      completionHandler(hr, "CreateCoreWebView2EnvironmentWithOptions");
    }
  }

  WebViewEnvironment::~WebViewEnvironment()
  {
    debugLog("dealloc WebViewEnvironment");
    *alive_ = false;
    if (webViewController_) webViewController_->Close();
    webView_ = nullptr;
    webViewController_ = nullptr;
    environment_ = nullptr;
  }
}
