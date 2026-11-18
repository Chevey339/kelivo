#include "../webview_platform.h"

#include <DispatcherQueue.h>
#include <windows.h>
#include <windows.system.h>
#include <wrl.h>

#include <cstdlib>
#include <iostream>
#include <thread>

namespace {

void Require(bool condition, const char* expr, int line) {
  if (!condition) {
    std::cerr << "Test check failed at line " << line << ": " << expr << "\n";
    std::exit(EXIT_FAILURE);
  }
}

#define CHECK(condition) Require((condition), #condition, __LINE__)

using AgileDispatcherQueueHandler = Microsoft::WRL::Implements<
    Microsoft::WRL::RuntimeClassFlags<Microsoft::WRL::ClassicCom>,
    ABI::Windows::System::IDispatcherQueueHandler, Microsoft::WRL::FtmBase>;

using AgileAsyncActionCompletedHandler = Microsoft::WRL::Implements<
    Microsoft::WRL::RuntimeClassFlags<Microsoft::WRL::ClassicCom>,
    ABI::Windows::Foundation::IAsyncActionCompletedHandler,
    Microsoft::WRL::FtmBase>;

winrt::com_ptr<ABI::Windows::System::IDispatcherQueue> GetCurrentDispatcherQueue(
    rx::RoHelper* rohelper) {
  HSTRING class_name;
  HSTRING_HEADER class_name_header;
  CHECK(SUCCEEDED(rohelper->GetStringReference(
      RuntimeClass_Windows_System_DispatcherQueue, &class_name,
      &class_name_header)));
  winrt::com_ptr<ABI::Windows::System::IDispatcherQueueStatics> statics;
  CHECK(SUCCEEDED(rohelper->GetActivationFactory(
      class_name, __uuidof(ABI::Windows::System::IDispatcherQueueStatics),
      statics.put_void())));
  winrt::com_ptr<ABI::Windows::System::IDispatcherQueue> queue;
  CHECK(SUCCEEDED(statics->GetForCurrentThread(queue.put())));
  return queue;
}

void ShutdownDispatcherQueue(
    ABI::Windows::System::IDispatcherQueueController* controller) {
  HANDLE raw_event = CreateEvent(nullptr, TRUE, FALSE, nullptr);
  CHECK(raw_event != nullptr);
  struct EventGuard {
    HANDLE handle;
    ~EventGuard() {
      if (handle != nullptr) {
        CloseHandle(handle);
      }
    }
  } event{raw_event};

  winrt::com_ptr<ABI::Windows::Foundation::IAsyncAction> action;
  CHECK(SUCCEEDED(controller->ShutdownQueueAsync(action.put())));
  CHECK(SUCCEEDED(action->put_Completed(
      Microsoft::WRL::Callback<AgileAsyncActionCompletedHandler>(
          [raw_event](ABI::Windows::Foundation::IAsyncAction*,
                      ABI::Windows::Foundation::AsyncStatus) -> HRESULT {
            SetEvent(raw_event);
            return S_OK;
          })
          .Get())));

  while (WaitForSingleObject(raw_event, 0) == WAIT_TIMEOUT) {
    const DWORD wait = MsgWaitForMultipleObjectsEx(
        1, &raw_event, 5000, QS_ALLINPUT, MWMO_INPUTAVAILABLE);
    CHECK(wait != WAIT_FAILED && wait != WAIT_TIMEOUT);
    MSG message;
    while (PeekMessage(&message, nullptr, 0, 0, PM_REMOVE)) {
      TranslateMessage(&message);
      DispatchMessage(&message);
    }
  }
  CHECK(SUCCEEDED(action->GetResults()));
}

void VerifyPlatformGraphics(WebviewPlatform* platform) {
  if (platform->IsGraphicsCaptureSessionSupported()) {
    CHECK(platform->IsSupported());
    CHECK(platform->graphics_context() != nullptr);
    CHECK(platform->graphics_context()->CreateCompositor() != nullptr);
  }
}

void TestBorrowsExistingDispatcherQueue() {
  std::thread([] {
    CHECK(SUCCEEDED(CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED)));
    {
      rx::RoHelper helper(RO_INIT_SINGLETHREADED);
      CHECK(helper.WinRtAvailable());
      DispatcherQueueOptions options{sizeof(DispatcherQueueOptions),
                                     DQTYPE_THREAD_CURRENT, DQTAT_COM_STA};
      winrt::com_ptr<ABI::Windows::System::IDispatcherQueueController>
          existing_controller;
      CHECK(SUCCEEDED(helper.CreateDispatcherQueueController(
          options, existing_controller.put())));
      CHECK(GetCurrentDispatcherQueue(&helper) != nullptr);

      {
        WebviewPlatform platform;
        CHECK(!platform.HasOwnedDispatcherQueueController());
        VerifyPlatformGraphics(&platform);
      }

      winrt::com_ptr<ABI::Windows::System::IDispatcherQueue> queue =
          GetCurrentDispatcherQueue(&helper);
      CHECK(queue != nullptr);

      bool ran = false;
      boolean enqueued = FALSE;
      CHECK(SUCCEEDED(queue->TryEnqueue(
          Microsoft::WRL::Callback<AgileDispatcherQueueHandler>(
              [&ran]() -> HRESULT {
                ran = true;
                return S_OK;
              })
              .Get(),
          &enqueued)));
      CHECK(enqueued == TRUE);

      ShutdownDispatcherQueue(existing_controller.get());
      CHECK(ran);
    }
    CoUninitialize();
  }).join();
}

void TestCreatesAndReusesDispatcherQueueWhenMissing() {
  std::thread([] {
    CHECK(SUCCEEDED(CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED)));
    {
      rx::RoHelper helper(RO_INIT_SINGLETHREADED);
      CHECK(helper.WinRtAvailable());
      CHECK(GetCurrentDispatcherQueue(&helper) == nullptr);

      WebviewPlatform first;
      CHECK(first.HasOwnedDispatcherQueueController());
      CHECK(GetCurrentDispatcherQueue(&helper) != nullptr);
      VerifyPlatformGraphics(&first);

      WebviewPlatform second;
      CHECK(!second.HasOwnedDispatcherQueueController());
      VerifyPlatformGraphics(&second);
    }
    CoUninitialize();
  }).join();
}

}  // namespace

int main() {
  TestBorrowsExistingDispatcherQueue();
  TestCreatesAndReusesDispatcherQueueWhenMissing();
  std::cout << "WebviewPlatform: borrows existing DispatcherQueue without "
               "taking ownership, and creates/reuses one when absent.\n";
  return 0;
}
