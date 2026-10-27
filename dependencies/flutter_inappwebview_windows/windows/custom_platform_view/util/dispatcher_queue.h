#pragma once

#include <Windows.h>
#include <windows.system.h>
#include <windows.foundation.h>
#include <wil/resource.h>
#include <winrt/base.h>
#include <wrl.h>
#include <memory>

namespace flutter_inappwebview_plugin
{
  // Shutdown must finish on the owning STA while it can still dispatch WinRT
  // work. Preserve WM_QUIT for the runner instead of consuming its exit signal.
  inline HRESULT shutdownDispatcherQueue(
    ABI::Windows::System::IDispatcherQueueController* controller)
  {
    if (!controller) return S_OK;
    auto completed = std::make_shared<wil::unique_handle>(CreateEvent(nullptr, TRUE, FALSE, nullptr));
    if (!*completed) return HRESULT_FROM_WIN32(GetLastError());

    winrt::com_ptr<ABI::Windows::Foundation::IAsyncAction> action;
    auto hr = controller->ShutdownQueueAsync(action.put());
    if (FAILED(hr)) return hr;
    hr = action->put_Completed(Microsoft::WRL::Callback<
      ABI::Windows::Foundation::IAsyncActionCompletedHandler>(
        [completed](ABI::Windows::Foundation::IAsyncAction*,
          ABI::Windows::Foundation::AsyncStatus) -> HRESULT {
          SetEvent(completed->get());
          return S_OK;
        }).Get());
    if (FAILED(hr)) return hr;

    bool quit = false;
    int exitCode = 0;
    const HANDLE event = completed->get();
    while (WaitForSingleObject(event, 0) == WAIT_TIMEOUT) {
      const auto wait = MsgWaitForMultipleObjectsEx(1, &event, INFINITE,
        QS_ALLINPUT, MWMO_INPUTAVAILABLE);
      if (wait == WAIT_FAILED) {
        hr = HRESULT_FROM_WIN32(GetLastError());
        break;
      }
      MSG message;
      while (PeekMessage(&message, nullptr, 0, 0, PM_REMOVE)) {
        if (message.message == WM_QUIT) {
          quit = true;
          exitCode = static_cast<int>(message.wParam);
        }
        else {
          TranslateMessage(&message);
          DispatchMessage(&message);
        }
      }
    }
    if (quit) PostQuitMessage(exitCode);
    return FAILED(hr) ? hr : action->GetResults();
  }
}
