#pragma once

#include <array>
#include <functional>
#include <string_view>

// Fixed policy for one generated-content preview, not a configurable browser
// interception API. All decisions run synchronously on the WebView STA thread.
class RestrictedPreviewPolicy {
 public:
  enum class Step { Settings, Navigation, Resources, Capabilities };
  enum class Resource { Document, Image, Font, Other };

  bool Initialize(const std::function<bool(Step)>& install,
                  const std::function<void()>& close) {
    if (started_ || closed_) return false;
    started_ = true;
    for (const auto step : {Step::Settings, Step::Navigation, Step::Resources,
                            Step::Capabilities}) {
      if (!install(step)) {
        Close(close);
        return false;
      }
    }
    ready_ = true;
    return true;
  }

  bool LoadDocument(const std::function<bool()>& navigate,
                    const std::function<void()>& close) {
    if (!ready_ || loaded_ || closed_) return false;
    loaded_ = true;
    awaiting_main_ = true;
    if (navigate()) return true;
    Close(close);
    return false;
  }

  bool AllowMainNavigation(std::wstring_view uri) {
    if (!ready_ || closed_ || !awaiting_main_ || uri != L"about:blank") {
      return false;
    }
    awaiting_main_ = false;
    return true;
  }

  bool AllowFrameNavigation(std::wstring_view uri) const {
    // Local blank/srcdoc documents inherit the parent's CSP and sandbox. This
    // does not grant about:* or data:* top-level navigation permission.
    return ready_ && loaded_ && !closed_ &&
           (uri == L"about:srcdoc" || uri == L"about:blank");
  }

  bool AllowResource(std::wstring_view uri, Resource kind) const {
    if (!ready_ || !loaded_ || closed_) return false;
    if (kind == Resource::Document) return AllowFrameNavigation(uri);
    return (kind == Resource::Image || kind == Resource::Font) &&
           uri.starts_with(L"data:");
  }

  static bool AllowMethod(std::string_view method) {
    constexpr std::array allowed = {
        "loadStringContent", "setSize", "setCursorPos", "setPointerUpdate",
        "setPointerButton", "setScrollDelta", "setBackgroundColor",
        "setZoomFactor", "setFpsLimit", "suspend", "resume"};
    for (const auto item : allowed) {
      if (method == item) return true;
    }
    return false;
  }

  void Close(const std::function<void()>& close) {
    if (closed_) return;
    closed_ = true;
    ready_ = false;
    awaiting_main_ = false;
    close();
  }
  bool closed() const { return closed_; }

 private:
  bool started_ = false;
  bool ready_ = false;
  bool loaded_ = false;
  bool awaiting_main_ = false;
  bool closed_ = false;
};
