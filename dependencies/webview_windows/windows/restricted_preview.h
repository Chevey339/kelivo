#pragma once

#include <WebView2.h>
#include <wil/com.h>

#include <functional>
#include <string>

#include "restricted_preview_policy.h"

// An immutable, controller-local policy. The caller supplies a trusted CSP
// wrapper through LoadDocument; generated markup belongs only in sandbox srcdoc.
class RestrictedPreview {
 public:
  using Observer = std::function<void(const std::string&)>;
  RestrictedPreview(ICoreWebView2* view, ICoreWebView2Controller* controller);
  ~RestrictedPreview();
  HRESULT Initialize();
  HRESULT LoadDocument(const std::wstring& content);
  void Close();
  void SetObserver(Observer observer) { observer_ = std::move(observer); }
  void SetClosedCallback(std::function<void()> callback) {
    closed_callback_ = std::move(callback);
  }

 private:
  HRESULT ConfigureSettings();
  HRESULT RegisterNavigation();
  HRESULT RegisterResources();
  HRESULT RegisterCapabilities();
  void CloseNative();
  HRESULT CheckDecision(HRESULT result, const char* reason);
  void Observe(const char* reason);

  wil::com_ptr<ICoreWebView2_22> view_;
  wil::com_ptr<ICoreWebView2Controller> controller_;
  wil::com_ptr<ICoreWebView2Environment> environment_;
  RestrictedPreviewPolicy policy_;
  HRESULT last_error_ = E_NOINTERFACE;
  Observer observer_;
  std::function<void()> closed_callback_;
  bool filter_installed_ = false;
  bool native_closed_ = false;
  EventRegistrationToken navigation_{}, frame_navigation_{}, resource_{};
  EventRegistrationToken popup_{}, permission_{}, download_{}, external_scheme_{};
};
