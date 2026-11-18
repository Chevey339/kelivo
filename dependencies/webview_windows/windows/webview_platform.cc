#include "webview_platform.h"

#include <DispatcherQueue.h>
#include <shlobj.h>
#include <windows.graphics.capture.h>
#include <windows.system.h>

#include <filesystem>
#include <iostream>

WebviewPlatform::WebviewPlatform()
    : rohelper_(std::make_unique<rx::RoHelper>(RO_INIT_SINGLETHREADED)) {
  if (rohelper_->WinRtAvailable()) {
    if (!EnsureDispatcherQueue()) {
      return;
    }

    if (!IsGraphicsCaptureSessionSupported()) {
      std::cerr << "Windows::Graphics::Capture::GraphicsCaptureSession is not "
                   "supported."
                << std::endl;
      return;
    }

    graphics_context_ = std::make_unique<GraphicsContext>(rohelper_.get());
    valid_ = graphics_context_->IsValid();
  }
}

bool WebviewPlatform::EnsureDispatcherQueue() {
  // A thread can only have one DispatcherQueue. Borrow an existing queue (for
  // example one created by another WebView plugin on the platform thread)
  // without taking ownership or shutting it down.
  HSTRING class_name;
  HSTRING_HEADER class_name_header;
  if (FAILED(rohelper_->GetStringReference(
          RuntimeClass_Windows_System_DispatcherQueue, &class_name,
          &class_name_header))) {
    std::cerr << "Resolving DispatcherQueue runtime class failed."
              << std::endl;
    return false;
  }

  winrt::com_ptr<ABI::Windows::System::IDispatcherQueueStatics> queue_statics;
  if (FAILED(rohelper_->GetActivationFactory(
          class_name, __uuidof(ABI::Windows::System::IDispatcherQueueStatics),
          queue_statics.put_void()))) {
    std::cerr << "Getting DispatcherQueueStatics activation factory failed."
              << std::endl;
    return false;
  }

  winrt::com_ptr<ABI::Windows::System::IDispatcherQueue> queue;
  if (FAILED(queue_statics->GetForCurrentThread(queue.put()))) {
    std::cerr << "Querying DispatcherQueue for current thread failed."
              << std::endl;
    return false;
  }

  if (queue) {
    return true;
  }

  DispatcherQueueOptions options{sizeof(DispatcherQueueOptions),
                                 DQTYPE_THREAD_CURRENT, DQTAT_COM_STA};
  if (FAILED(rohelper_->CreateDispatcherQueueController(
          options, dispatcher_queue_controller_.put()))) {
    std::cerr << "Creating DispatcherQueueController failed." << std::endl;
    return false;
  }

  return true;
}

bool WebviewPlatform::IsGraphicsCaptureSessionSupported() {
  HSTRING className;
  HSTRING_HEADER classNameHeader;

  if (FAILED(rohelper_->GetStringReference(
          RuntimeClass_Windows_Graphics_Capture_GraphicsCaptureSession,
          &className, &classNameHeader))) {
    return false;
  }

  ABI::Windows::Graphics::Capture::IGraphicsCaptureSessionStatics*
      capture_session_statics;
  if (FAILED(rohelper_->GetActivationFactory(
          className,
          __uuidof(
              ABI::Windows::Graphics::Capture::IGraphicsCaptureSessionStatics),
          (void**)&capture_session_statics))) {
    return false;
  }

  boolean is_supported = false;
  if (FAILED(capture_session_statics->IsSupported(&is_supported))) {
    return false;
  }

  return !!is_supported;
}

std::optional<std::wstring> WebviewPlatform::GetDefaultDataDirectory() {
  PWSTR path_tmp;
  if (!SUCCEEDED(
          SHGetKnownFolderPath(FOLDERID_LocalAppData, 0, nullptr, &path_tmp))) {
    return std::nullopt;
  }
  auto path = std::filesystem::path(path_tmp);
  CoTaskMemFree(path_tmp);

  wchar_t filename[MAX_PATH];
  GetModuleFileName(nullptr, filename, MAX_PATH);
  path /= "flutter_webview_windows";
  path /= std::filesystem::path(filename).stem();

  return path.wstring();
}
