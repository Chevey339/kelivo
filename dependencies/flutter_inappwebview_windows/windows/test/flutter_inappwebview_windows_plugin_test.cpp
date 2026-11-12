#include <flutter/method_result_functions.h>
#include <gtest/gtest.h>
#include <thread>

#include "custom_platform_view/util/dispatcher_queue.h"
#include "custom_platform_view/util/rohelper.h"
#include "utils/initialization_error.h"

namespace flutter_inappwebview_plugin {
namespace test {

TEST(WebViewInitialization, PreservesHRESULTStageAndProfile) {
  bool replied = false;
  flutter::MethodResultFunctions<flutter::EncodableValue> result(nullptr,
    [&replied](const std::string& code, const std::string& message,
      const flutter::EncodableValue* details) {
      replied = true;
      EXPECT_EQ(code, "0x80070005");
      EXPECT_NE(message.find("CreateCoreWebView2EnvironmentWithOptions"), std::string::npos);
      EXPECT_NE(message.find("0x80070005"), std::string::npos);
      const auto& values = std::get<flutter::EncodableMap>(*details);
      EXPECT_EQ(std::get<int64_t>(values.at(flutter::EncodableValue("hresult"))),
        static_cast<int64_t>(E_ACCESSDENIED));
      EXPECT_EQ(std::get<std::string>(values.at(flutter::EncodableValue("userDataFolder"))), "profile");
    }, nullptr);
  reportInitializationError(&result, E_ACCESSDENIED,
    "CreateCoreWebView2EnvironmentWithOptions", "profile");
  EXPECT_TRUE(replied);
}

TEST(WebViewShutdown, DrainsOwnedDispatcherQueueAndPreservesQuit) {
  std::thread thread([] {
    rx::RoHelper runtime(RO_INIT_SINGLETHREADED);
    ASSERT_TRUE(SUCCEEDED(runtime.initializationResult()));
    DispatcherQueueOptions options{ sizeof(DispatcherQueueOptions),
      DQTYPE_THREAD_CURRENT, DQTAT_COM_STA };
    winrt::com_ptr<ABI::Windows::System::IDispatcherQueueController> controller;
    ASSERT_EQ(runtime.CreateDispatcherQueueController(options, controller.put()), S_OK);
    winrt::com_ptr<ABI::Windows::System::IDispatcherQueue> queue;
    ASSERT_EQ(controller->get_DispatcherQueue(queue.put()), S_OK);
    bool ran = false;
    boolean accepted = false;
    ASSERT_EQ(queue->TryEnqueue(Microsoft::WRL::Callback<
      ABI::Windows::System::IDispatcherQueueHandler>([&ran]() -> HRESULT {
        ran = true;
        return S_OK;
      }).Get(), &accepted), S_OK);
    ASSERT_TRUE(accepted);
    PostQuitMessage(37);
    EXPECT_EQ(shutdownDispatcherQueue(controller.get()), S_OK);
    EXPECT_TRUE(ran);
    MSG message{};
    EXPECT_TRUE(PeekMessage(&message, nullptr, WM_QUIT, WM_QUIT, PM_REMOVE));
    EXPECT_EQ(message.wParam, 37u);
    queue = nullptr;
    controller = nullptr;
  });
  thread.join();
}

TEST(WebViewShutdown, FailedSTAInitializationDoesNotUninitializeCaller) {
  std::thread thread([] {
    ASSERT_EQ(CoInitializeEx(nullptr, COINIT_MULTITHREADED), S_OK);
    {
      rx::RoHelper runtime(RO_INIT_SINGLETHREADED);
      EXPECT_EQ(runtime.initializationResult(), RPC_E_CHANGED_MODE);
      EXPECT_FALSE(runtime.WinRtAvailable());
    }
    APTTYPE apartment;
    APTTYPEQUALIFIER qualifier;
    EXPECT_EQ(CoGetApartmentType(&apartment, &qualifier), S_OK);
    EXPECT_EQ(apartment, APTTYPE_MTA);
    CoUninitialize();
  });
  thread.join();
}

}  // namespace test
}  // namespace flutter_inappwebview_plugin
