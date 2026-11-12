#ifndef FLUTTER_INAPPWEBVIEW_SCREENSHOT_H_
#define FLUTTER_INAPPWEBVIEW_SCREENSHOT_H_

#include <WebView2.h>
#include <functional>
#include <wil/com.h>
#include "../types/screenshot_configuration.h"

namespace flutter_inappwebview_plugin
{
  void captureScreenshot(wil::com_ptr<ICoreWebView2> view,
    std::optional<std::shared_ptr<ScreenshotConfiguration>> configuration,
    double rasterScale,
    std::function<void(const std::optional<std::string>)> completion);
}
#endif
