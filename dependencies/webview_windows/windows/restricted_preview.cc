#include "restricted_preview.h"

#include <wrl.h>

using Microsoft::WRL::Callback;
using Step = RestrictedPreviewPolicy::Step;
using Resource = RestrictedPreviewPolicy::Resource;

RestrictedPreview::RestrictedPreview(ICoreWebView2* view,
                                     ICoreWebView2Controller* controller)
    : controller_(controller) {
  if (view) view->QueryInterface(IID_PPV_ARGS(view_.put()));
}

RestrictedPreview::~RestrictedPreview() { Close(); }

HRESULT RestrictedPreview::Initialize() {
  const bool ready = policy_.Initialize(
      [this](Step step) {
        if (!view_ || !controller_) {
          last_error_ = E_NOINTERFACE;
          return false;
        }
        switch (step) {
          case Step::Settings: last_error_ = ConfigureSettings(); break;
          case Step::Navigation: last_error_ = RegisterNavigation(); break;
          case Step::Resources: last_error_ = RegisterResources(); break;
          case Step::Capabilities: last_error_ = RegisterCapabilities(); break;
        }
        return SUCCEEDED(last_error_);
      },
      [this] { CloseNative(); });
  return ready ? S_OK : last_error_;
}

HRESULT RestrictedPreview::LoadDocument(const std::wstring& content) {
  HRESULT result = E_UNEXPECTED;
  const bool loaded = policy_.LoadDocument(
      [&] { result = view_->NavigateToString(content.c_str()); return SUCCEEDED(result); },
      [this] { CloseNative(); });
  return loaded ? S_OK : result;
}

void RestrictedPreview::Observe(const char* reason) {
  if (observer_) observer_(reason);
}

HRESULT RestrictedPreview::CheckDecision(HRESULT result, const char* reason) {
  // Failure to enforce a native decision closes this controller immediately.
  if (FAILED(result)) Close();
  Observe(reason);
  return result;
}

HRESULT RestrictedPreview::ConfigureSettings() {
  wil::com_ptr<ICoreWebView2Settings> settings;
  HRESULT result = view_->get_Settings(settings.put());
  if (FAILED(result)) return result;
  auto settings3 = settings.try_query<ICoreWebView2Settings3>();
  if (!settings3) return E_NOINTERFACE;
  // Settings4 autofill/password switches mutate the shared profile, so they
  // are intentionally untouched (approved 2026-10-24). The host's opaque-origin
  // sandbox must be validated against synthetic saved data before acceptance.
  const std::function<HRESULT()> required[] = {
      [&] { return settings->put_IsScriptEnabled(TRUE); },
      [&] { return settings->put_IsWebMessageEnabled(FALSE); },
      [&] { return settings->put_AreHostObjectsAllowed(FALSE); },
      [&] { return settings->put_AreDefaultScriptDialogsEnabled(FALSE); },
      [&] { return settings->put_AreDevToolsEnabled(FALSE); },
      [&] { return settings->put_AreDefaultContextMenusEnabled(FALSE); },
      [&] { return settings->put_IsStatusBarEnabled(FALSE); },
      [&] { return settings->put_IsBuiltInErrorPageEnabled(FALSE); },
      [&] { return settings3->put_AreBrowserAcceleratorKeysEnabled(FALSE); },
  };
  for (const auto& apply : required) {
    result = apply();
    if (FAILED(result)) return result;
  }
  return S_OK;
}

HRESULT RestrictedPreview::RegisterNavigation() {
  HRESULT result = view_->add_NavigationStarting(
      Callback<ICoreWebView2NavigationStartingEventHandler>(
          [this](ICoreWebView2*, ICoreWebView2NavigationStartingEventArgs* args) -> HRESULT {
            wil::unique_cotaskmem_string uri;
            const bool allowed = SUCCEEDED(args->get_Uri(uri.put())) && uri &&
                policy_.AllowMainNavigation(uri.get());
            return allowed ? S_OK : CheckDecision(args->put_Cancel(TRUE), "navigation");
          }).Get(), &navigation_);
  if (FAILED(result)) return result;
  return view_->add_FrameNavigationStarting(
      Callback<ICoreWebView2NavigationStartingEventHandler>(
          [this](ICoreWebView2*, ICoreWebView2NavigationStartingEventArgs* args) -> HRESULT {
            wil::unique_cotaskmem_string uri;
            const bool allowed = SUCCEEDED(args->get_Uri(uri.put())) && uri &&
                policy_.AllowFrameNavigation(uri.get());
            return allowed ? S_OK : CheckDecision(args->put_Cancel(TRUE), "frame_navigation");
          }).Get(), &frame_navigation_);
}

HRESULT RestrictedPreview::RegisterResources() {
  HRESULT result = view_->get_Environment(environment_.put());
  if (FAILED(result)) return result;
  result = view_->add_WebResourceRequested(
      Callback<ICoreWebView2WebResourceRequestedEventHandler>(
          [this](ICoreWebView2*, ICoreWebView2WebResourceRequestedEventArgs* args) -> HRESULT {
            wil::com_ptr<ICoreWebView2WebResourceRequest> request;
            wil::unique_cotaskmem_string uri;
            COREWEBVIEW2_WEB_RESOURCE_CONTEXT context = COREWEBVIEW2_WEB_RESOURCE_CONTEXT_ALL;
            Resource kind = Resource::Other;
            if (SUCCEEDED(args->get_ResourceContext(&context))) {
              if (context == COREWEBVIEW2_WEB_RESOURCE_CONTEXT_DOCUMENT) kind = Resource::Document;
              if (context == COREWEBVIEW2_WEB_RESOURCE_CONTEXT_IMAGE) kind = Resource::Image;
              if (context == COREWEBVIEW2_WEB_RESOURCE_CONTEXT_FONT) kind = Resource::Font;
            }
            if (SUCCEEDED(args->get_Request(request.put())) && request &&
                SUCCEEDED(request->get_Uri(uri.put())) && uri &&
                policy_.AllowResource(uri.get(), kind)) return S_OK;
            wil::com_ptr<ICoreWebView2WebResourceResponse> response;
            HRESULT denied = environment_->CreateWebResourceResponse(
                nullptr, 403, L"Blocked preview resource", L"Content-Type: text/plain", response.put());
            if (SUCCEEDED(denied)) denied = args->put_Response(response.get());
            return CheckDecision(denied, "resource");
          }).Get(), &resource_);
  if (FAILED(result)) return result;
  // DOCUMENT covers frames and dedicated workers without intercepting ordinary
  // pages' shared/service workers in the same shared environment.
  result = view_->AddWebResourceRequestedFilterWithRequestSourceKinds(
      L"*", COREWEBVIEW2_WEB_RESOURCE_CONTEXT_ALL,
      COREWEBVIEW2_WEB_RESOURCE_REQUEST_SOURCE_KINDS_DOCUMENT);
  filter_installed_ = SUCCEEDED(result);
  return result;
}

HRESULT RestrictedPreview::RegisterCapabilities() {
  HRESULT result = view_->add_NewWindowRequested(
      Callback<ICoreWebView2NewWindowRequestedEventHandler>(
          [this](ICoreWebView2*, ICoreWebView2NewWindowRequestedEventArgs* args) -> HRESULT {
            return CheckDecision(args->put_Handled(TRUE), "popup");
          }).Get(), &popup_);
  if (FAILED(result)) return result;
  result = view_->add_PermissionRequested(
      Callback<ICoreWebView2PermissionRequestedEventHandler>(
          [this](ICoreWebView2*, ICoreWebView2PermissionRequestedEventArgs* args) -> HRESULT {
            // Denial is synchronous and must not alter the shared profile.
            wil::com_ptr<ICoreWebView2PermissionRequestedEventArgs3> scoped;
            HRESULT denied = args->QueryInterface(IID_PPV_ARGS(scoped.put()));
            if (SUCCEEDED(denied)) denied = scoped->put_SavesInProfile(FALSE);
            if (SUCCEEDED(denied)) denied = scoped->put_Handled(TRUE);
            if (SUCCEEDED(denied)) denied = args->put_State(COREWEBVIEW2_PERMISSION_STATE_DENY);
            return CheckDecision(denied, "permission");
          }).Get(), &permission_);
  if (FAILED(result)) return result;
  result = view_->add_DownloadStarting(
      Callback<ICoreWebView2DownloadStartingEventHandler>(
          [this](ICoreWebView2*, ICoreWebView2DownloadStartingEventArgs* args) -> HRESULT {
            HRESULT denied = args->put_Cancel(TRUE);
            if (SUCCEEDED(denied)) denied = args->put_Handled(TRUE);
            return CheckDecision(denied, "download");
          }).Get(), &download_);
  if (FAILED(result)) return result;
  return view_->add_LaunchingExternalUriScheme(
      Callback<ICoreWebView2LaunchingExternalUriSchemeEventHandler>(
          [this](ICoreWebView2*, ICoreWebView2LaunchingExternalUriSchemeEventArgs* args) -> HRESULT {
            return CheckDecision(args->put_Cancel(TRUE), "external_scheme");
          }).Get(), &external_scheme_);
}

void RestrictedPreview::Close() { policy_.Close([this] { CloseNative(); }); }

void RestrictedPreview::CloseNative() {
  if (native_closed_) return;
  native_closed_ = true;
  if (view_) {
    view_->remove_NavigationStarting(navigation_);
    view_->remove_FrameNavigationStarting(frame_navigation_);
    view_->remove_WebResourceRequested(resource_);
    view_->remove_NewWindowRequested(popup_);
    view_->remove_PermissionRequested(permission_);
    view_->remove_DownloadStarting(download_);
    view_->remove_LaunchingExternalUriScheme(external_scheme_);
    if (filter_installed_) {
      view_->RemoveWebResourceRequestedFilterWithRequestSourceKinds(
          L"*", COREWEBVIEW2_WEB_RESOURCE_CONTEXT_ALL,
          COREWEBVIEW2_WEB_RESOURCE_REQUEST_SOURCE_KINDS_DOCUMENT);
      filter_installed_ = false;
    }
  }
  if (controller_) controller_->Close();
  if (closed_callback_) closed_callback_();
  observer_ = nullptr;
  closed_callback_ = nullptr;
  environment_.reset();
  view_.reset();
  controller_.reset();
}
