#include "new_window_requested_args.h"

namespace flutter_inappwebview_plugin
{
  NewWindowRequestedArgs::NewWindowRequestedArgs(wil::com_ptr<ICoreWebView2NewWindowRequestedEventArgs> args,
    wil::com_ptr<ICoreWebView2Deferral> deferral, wil::com_ptr<ICoreWebView2> opener,
    wil::com_ptr<ICoreWebView2Environment> environment)
    : args(std::move(args)), deferral(std::move(deferral)), opener(std::move(opener)), environment(std::move(environment))
  {}

  HRESULT NewWindowRequestedArgs::complete(ICoreWebView2* child, const std::function<void()>& onAttached)
  {
    if (completed) return E_ABORT;
    completed = true;
    // Suppress an unmanaged window on rejection/failure, but always unblock the
    // opener. A successful handoff preserves window.opener, POST and redirects.
    const auto handoff = child ? args->put_NewWindow(child) : S_OK;
    if (SUCCEEDED(handoff) && child && onAttached) onAttached();
    const auto handled = args->put_Handled(TRUE);
    const auto finished = deferral->Complete();
    return FAILED(handoff) ? handoff : FAILED(handled) ? handled : finished;
  }

  NewWindowRequestedArgs::~NewWindowRequestedArgs()
  {
    if (!completed) complete();
  }
}
