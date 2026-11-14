#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <algorithm>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  std::vector<std::string> command_line_arguments = GetCommandLineArguments();
  const bool autostart = std::find(command_line_arguments.begin(),
                                  command_line_arguments.end(), "--autostart") !=
                         command_line_arguments.end();

  // Enforce a single running instance on Windows using a named mutex.
  HANDLE instance_mutex =
      ::CreateMutexW(nullptr, TRUE, L"KelivoMutex");
  if (instance_mutex != nullptr && ::GetLastError() == ERROR_ALREADY_EXISTS) {
    // Another instance is already running; try to bring its window to front
    // instead of creating a new one.
    if (!autostart) Win32Window::SendAppLinkToInstance(L"kelivo");
    return 0;
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  // https://github.com/flutter/flutter/issues/175135
  project.set_ui_thread_policy(flutter::UIThreadPolicy::RunOnSeparateThread);

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  int exit_code = EXIT_FAILURE;
  {
    // Destroy the window, WebViews and engine while the owning STA is alive,
    // including startup failure and WM_QUIT without a window-close message.
    FlutterWindow window(project, autostart);
    Win32Window::Point origin(10, 10);
    Win32Window::Size size(1280, 720);
    if (window.Create(L"kelivo", origin, size)) {
      window.SetQuitOnClose(true);

      ::MSG msg;
      while (::GetMessage(&msg, nullptr, 0, 0)) {
        ::TranslateMessage(&msg);
        ::DispatchMessage(&msg);
      }
      exit_code = EXIT_SUCCESS;
    }
  }

  ::CoUninitialize();
  return exit_code;
}
