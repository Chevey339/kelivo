#ifndef FLUTTER_INAPPWEBVIEW_PLUGIN_NEW_WINDOW_REQUESTED_ARGS_H_
#define FLUTTER_INAPPWEBVIEW_PLUGIN_NEW_WINDOW_REQUESTED_ARGS_H_

#include <WebView2.h>
#include <functional>
#include <wil/com.h>

namespace flutter_inappwebview_plugin
{
  class NewWindowRequestedArgs
  {
  public:
    wil::com_ptr<ICoreWebView2NewWindowRequestedEventArgs> args;
    wil::com_ptr<ICoreWebView2Deferral> deferral;

    const wil::com_ptr<ICoreWebView2> opener;
    const wil::com_ptr<ICoreWebView2Environment> environment;
    bool completed = false;

    NewWindowRequestedArgs(wil::com_ptr<ICoreWebView2NewWindowRequestedEventArgs> args,
      wil::com_ptr<ICoreWebView2Deferral> deferral, wil::com_ptr<ICoreWebView2> opener,
      wil::com_ptr<ICoreWebView2Environment> environment);
    HRESULT complete(ICoreWebView2* child = nullptr, const std::function<void()>& onAttached = {});
    ~NewWindowRequestedArgs();
  };
}

#endif //FLUTTER_INAPPWEBVIEW_PLUGIN_NEW_WINDOW_REQUESTED_ARGS_H_