#include "flutter_window.h"

#include <optional>
#include <chrono>
#include <cmath>
#include <fstream>
#include <limits>
#include <vector>
#include <string>
#include <wincodec.h>
#include <objbase.h>  // CoInitializeEx / CoUninitialize
#include <shellapi.h>  // CF_HDROP / DragQueryFile

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <flutter_windows.h>

#include "flutter/generated_plugin_registrant.h"

namespace {

flutter::EncodableMap EncodeWindowRect(const RECT& rect) {
  return {
      {flutter::EncodableValue("left"),
       flutter::EncodableValue(static_cast<double>(rect.left))},
      {flutter::EncodableValue("top"),
       flutter::EncodableValue(static_cast<double>(rect.top))},
      {flutter::EncodableValue("right"),
       flutter::EncodableValue(static_cast<double>(rect.right))},
      {flutter::EncodableValue("bottom"),
       flutter::EncodableValue(static_cast<double>(rect.bottom))},
  };
}

BOOL CALLBACK CollectWindowDisplay(HMONITOR monitor, HDC, LPRECT, LPARAM data) {
  MONITORINFO info{};
  info.cbSize = sizeof(info);
  if (!GetMonitorInfo(monitor, &info)) return FALSE;
  auto* displays = reinterpret_cast<flutter::EncodableList*>(data);
  displays->emplace_back(flutter::EncodableMap{
      {flutter::EncodableValue("bounds"),
       flutter::EncodableValue(EncodeWindowRect(info.rcMonitor))},
      {flutter::EncodableValue("workArea"),
       flutter::EncodableValue(EncodeWindowRect(info.rcWork))},
      {flutter::EncodableValue("scale"),
       flutter::EncodableValue(FlutterDesktopGetDpiForMonitor(monitor) / 96.0)},
      {flutter::EncodableValue("isPrimary"),
       flutter::EncodableValue((info.dwFlags & MONITORINFOF_PRIMARY) != 0)},
  });
  return TRUE;
}

std::optional<RECT> DecodeWindowRect(const flutter::EncodableValue* value) {
  const auto* args = value ? std::get_if<flutter::EncodableMap>(value) : nullptr;
  if (!args) return std::nullopt;
  double coordinates[4];
  size_t index = 0;
  for (const char* key : {"left", "top", "right", "bottom"}) {
    auto entry = args->find(flutter::EncodableValue(key));
    if (entry == args->end()) return std::nullopt;
    const auto* coordinate = std::get_if<double>(&entry->second);
    if (!coordinate || !std::isfinite(*coordinate) ||
        *coordinate < std::numeric_limits<LONG>::min() ||
        *coordinate > std::numeric_limits<LONG>::max()) {
      return std::nullopt;
    }
    coordinates[index++] = *coordinate;
  }
  const double width = coordinates[2] - coordinates[0];
  const double height = coordinates[3] - coordinates[1];
  if (width < 1 || height < 1 ||
      width > std::numeric_limits<LONG>::max() ||
      height > std::numeric_limits<LONG>::max()) {
    return std::nullopt;
  }
  return RECT{static_cast<LONG>(coordinates[0]),
              static_cast<LONG>(coordinates[1]),
              static_cast<LONG>(coordinates[2]),
              static_cast<LONG>(coordinates[3])};
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  auto window_channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "app.desktop_window",
          &flutter::StandardMethodCodec::GetInstance());
  window_channel->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "getDisplays") {
          flutter::EncodableList displays;
          if (!EnumDisplayMonitors(nullptr, nullptr, CollectWindowDisplay,
                                   reinterpret_cast<LPARAM>(&displays))) {
            result->Error("display_query_failed", "EnumDisplayMonitors failed");
            return;
          }
          result->Success(flutter::EncodableValue(displays));
        } else if (call.method_name() == "restoreBounds") {
          const auto bounds = DecodeWindowRect(call.arguments());
          if (!bounds) {
            result->Error("invalid_bounds", "Expected a physical window rectangle");
            return;
          }
          // This synchronous call runs on the window thread. The bounds already
          // use the target DPI; do not rescale them during WM_DPICHANGED or
          // constrain them using the previous monitor's WM_GETMINMAXINFO.
          restoring_bounds_ = bounds;
          const BOOL restored = SetWindowPos(
              GetHandle(), nullptr, bounds->left, bounds->top,
              bounds->right - bounds->left, bounds->bottom - bounds->top,
              SWP_NOZORDER | SWP_NOACTIVATE | SWP_NOSENDCHANGING);
          restoring_bounds_.reset();
          if (restored) {
            result->Success();
          } else {
            result->Error("restore_bounds_failed", "SetWindowPos failed");
          }
        } else {
          result->NotImplemented();
        }
      });

  auto power_channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "app.desktop_power",
      &flutter::StandardMethodCodec::GetInstance());
  power_channel->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() != "state") {
          result->NotImplemented();
          return;
        }
        result->Success(flutter::EncodableMap{
            {flutter::EncodableValue("sleeping"), flutter::EncodableValue(system_sleeping_)},
            {flutter::EncodableValue("lastWakeAt"), flutter::EncodableValue(last_system_wake_at_)},
        });
      });


  // Method channel for clipboard images.
  auto channel = std::make_shared<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(),
      "app.clipboard",
      &flutter::StandardMethodCodec::GetInstance());

  // Use exact signature to satisfy SetMethodCallHandler type.
  channel->SetMethodCallHandler(
      [this](
          const flutter::MethodCall<flutter::EncodableValue>& call,
          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "getClipboardImages") {
          std::vector<std::string> paths;

          // Initialize COM for WIC on this thread.
          const HRESULT co_hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

          // Read CF_DIB / CF_DIBV5 from clipboard and save as PNG via WIC.
          if (OpenClipboard(nullptr)) {
            UINT fmt = 0;
            if (IsClipboardFormatAvailable(CF_DIB)) fmt = CF_DIB;
            else if (IsClipboardFormatAvailable(CF_DIBV5)) fmt = CF_DIBV5;

            if (fmt != 0) {
              HANDLE hData = GetClipboardData(fmt);
              if (hData) {
                void* data = GlobalLock(hData);
                if (data) {
                  BITMAPINFO* bmi = reinterpret_cast<BITMAPINFO*>(data);
                  // Point to pixel bits after BITMAPINFOHEADER (+ palette/masks if present).
                  BYTE* bits = reinterpret_cast<BYTE*>(data) + bmi->bmiHeader.biSize;
                  if (bmi->bmiHeader.biBitCount <= 8) {
                    // FIX (C4334): use 64-bit 1ULL to avoid 32-bit shift warning.
                    const size_t palette_entries = static_cast<size_t>(1ULL << bmi->bmiHeader.biBitCount);
                    bits += static_cast<size_t>(sizeof(RGBQUAD)) * palette_entries;
                  } else if (bmi->bmiHeader.biCompression == BI_BITFIELDS) {
                    bits += 12; // three DWORD masks
                  }

                  HDC hdc = GetDC(nullptr);
                  HBITMAP hbmp = CreateDIBitmap(
                      hdc, &bmi->bmiHeader, CBM_INIT, bits, bmi, DIB_RGB_COLORS);
                  ReleaseDC(nullptr, hdc);

                  if (hbmp) {
                    IWICImagingFactory* factory = nullptr;
                    if (SUCCEEDED(CoCreateInstance(
                            CLSID_WICImagingFactory, nullptr, CLSCTX_INPROC_SERVER,
                            IID_PPV_ARGS(&factory)))) {

                      IWICBitmap* wicBitmap = nullptr;
                      // Valid alpha options: WICBitmapUseAlpha / WICBitmapUsePremultipliedAlpha / WICBitmapIgnoreAlpha
                      if (SUCCEEDED(factory->CreateBitmapFromHBITMAP(
                              hbmp, 0, WICBitmapUseAlpha, &wicBitmap))) {

                        wchar_t tempPath[MAX_PATH];
                        GetTempPathW(MAX_PATH, tempPath);
                        wchar_t filename[MAX_PATH];
                        swprintf_s(filename, L"pasted_%llu.png",
                                   static_cast<unsigned long long>(GetTickCount64()));
                        std::wstring fullPath = std::wstring(tempPath) + filename;

                        IWICStream* stream = nullptr;
                        if (SUCCEEDED(factory->CreateStream(&stream)) &&
                            SUCCEEDED(stream->InitializeFromFilename(fullPath.c_str(), GENERIC_WRITE))) {

                          IWICBitmapEncoder* encoder = nullptr;
                          if (SUCCEEDED(factory->CreateEncoder(GUID_ContainerFormatPng, nullptr, &encoder)) &&
                              SUCCEEDED(encoder->Initialize(stream, WICBitmapEncoderNoCache))) {

                            IWICBitmapFrameEncode* frame = nullptr;
                            if (SUCCEEDED(encoder->CreateNewFrame(&frame, nullptr)) &&
                                SUCCEEDED(frame->Initialize(nullptr)) &&
                                // Optional: SetSize / SetPixelFormat. WriteSource often suffices.
                                SUCCEEDED(frame->WriteSource(wicBitmap, nullptr)) &&
                                SUCCEEDED(frame->Commit()) &&
                                SUCCEEDED(encoder->Commit())) {

                              // Convert wide path to UTF-8 for Flutter side.
                              int len = WideCharToMultiByte(
                                  CP_UTF8, 0, fullPath.c_str(), -1, nullptr, 0, nullptr, nullptr);
                              std::string utf8(len - 1, '\0');
                              WideCharToMultiByte(
                                  CP_UTF8, 0, fullPath.c_str(), -1, utf8.data(), len, nullptr, nullptr);
                              paths.push_back(utf8);
                            }
                            if (frame) frame->Release();
                            if (encoder) encoder->Release();
                          }
                          if (stream) stream->Release();
                        }
                        if (wicBitmap) wicBitmap->Release();
                      }
                      if (factory) factory->Release();
                    }
                    DeleteObject(hbmp);
                  }
                  GlobalUnlock(hData);
                }
              }
            }
            CloseClipboard();
          }

          // Return UTF-8 paths as EncodableList.
          flutter::EncodableList list;
          for (auto& p : paths) list.emplace_back(p);
          result->Success(list);

          if (SUCCEEDED(co_hr)) {
            CoUninitialize();
          }
          return;
        } else if (call.method_name() == "getClipboardFiles") {
          std::vector<std::string> paths;
          if (OpenClipboard(nullptr)) {
            if (IsClipboardFormatAvailable(CF_HDROP)) {
              HANDLE hData = GetClipboardData(CF_HDROP);
              if (hData) {
                HDROP hDrop = static_cast<HDROP>(hData);
                UINT count = DragQueryFileW(hDrop, 0xFFFFFFFF, nullptr, 0);
                for (UINT i = 0; i < count; ++i) {
                  UINT len = DragQueryFileW(hDrop, i, nullptr, 0);
                  std::wstring wpath;
                  wpath.resize(static_cast<size_t>(len) + 1); // include space for NUL
                  DragQueryFileW(hDrop, i, wpath.data(), len + 1);
                  // Trim trailing NUL
                  if (!wpath.empty() && wpath.back() == L'\0') {
                    wpath.pop_back();
                  }
                  int u8len = WideCharToMultiByte(CP_UTF8, 0, wpath.c_str(), -1, nullptr, 0, nullptr, nullptr);
                  if (u8len > 0) {
                    std::string utf8(static_cast<size_t>(u8len - 1), '\0');
                    WideCharToMultiByte(CP_UTF8, 0, wpath.c_str(), -1, utf8.data(), u8len, nullptr, nullptr);
                    paths.push_back(utf8);
                  }
                }
              }
            }
            CloseClipboard();
          }
          flutter::EncodableList list;
          for (auto& p : paths) list.emplace_back(p);
          result->Success(list);
          return;
        } else if (call.method_name() == "setClipboardImage") {
          // Decode image from file and place as CF_DIB on clipboard
          std::string path;
          if (call.arguments()) {
            if (std::holds_alternative<std::string>(*call.arguments())) {
              path = std::get<std::string>(*call.arguments());
            } else if (std::holds_alternative<flutter::EncodableMap>(*call.arguments())) {
              const auto& m = std::get<flutter::EncodableMap>(*call.arguments());
              auto it = m.find(flutter::EncodableValue("path"));
              if (it != m.end() && std::holds_alternative<std::string>(it->second)) {
                path = std::get<std::string>(it->second);
              }
            }
          }

          auto Utf8ToWide = [](const std::string& s) -> std::wstring {
            int len = MultiByteToWideChar(CP_UTF8, 0, s.c_str(), -1, nullptr, 0);
            if (len <= 0) return std::wstring();
            std::wstring w(static_cast<size_t>(len - 1), L'\0');
            MultiByteToWideChar(CP_UTF8, 0, s.c_str(), -1, w.data(), len);
            return w;
          };

          bool ok = false;
          if (!path.empty()) {
            const HRESULT co_hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
            IWICImagingFactory* factory = nullptr;
            if (SUCCEEDED(CoCreateInstance(
                    CLSID_WICImagingFactory, nullptr, CLSCTX_INPROC_SERVER,
                    IID_PPV_ARGS(&factory)))) {
              IWICBitmapDecoder* decoder = nullptr;
              std::wstring wpath = Utf8ToWide(path);
              if (!wpath.empty() && SUCCEEDED(factory->CreateDecoderFromFilename(
                                   wpath.c_str(), nullptr, GENERIC_READ,
                                   WICDecodeMetadataCacheOnLoad, &decoder))) {
                IWICBitmapFrameDecode* frame = nullptr;
                if (SUCCEEDED(decoder->GetFrame(0, &frame))) {
                  IWICFormatConverter* converter = nullptr;
                  if (SUCCEEDED(factory->CreateFormatConverter(&converter)) &&
                      SUCCEEDED(converter->Initialize(frame, GUID_WICPixelFormat32bppBGRA,
                                                     WICBitmapDitherTypeNone, nullptr, 0.0, WICBitmapPaletteTypeCustom))) {
                    UINT w = 0, h = 0;
                    if (SUCCEEDED(converter->GetSize(&w, &h)) && w > 0 && h > 0) {
                      UINT stride = w * 4;
                      size_t imageSize = static_cast<size_t>(stride) * static_cast<size_t>(h);
                      SIZE_T totalSize = sizeof(BITMAPINFOHEADER) + imageSize;
                      HGLOBAL hMem = GlobalAlloc(GHND | GMEM_SHARE, totalSize);
                      if (hMem) {
                        void* p = GlobalLock(hMem);
                        if (p) {
                          BITMAPINFOHEADER* bmi = reinterpret_cast<BITMAPINFOHEADER*>(p);
                          ZeroMemory(bmi, sizeof(BITMAPINFOHEADER));
                          bmi->biSize = sizeof(BITMAPINFOHEADER);
                          bmi->biWidth = static_cast<LONG>(w);
                          bmi->biHeight = -static_cast<LONG>(h); // top-down
                          bmi->biPlanes = 1;
                          bmi->biBitCount = 32;
                          bmi->biCompression = BI_RGB;
                          bmi->biSizeImage = static_cast<DWORD>(imageSize);
                          BYTE* bits = reinterpret_cast<BYTE*>(bmi) + sizeof(BITMAPINFOHEADER);
                          if (SUCCEEDED(converter->CopyPixels(nullptr, stride, static_cast<UINT>(imageSize), bits))) {
                            if (OpenClipboard(nullptr)) {
                              EmptyClipboard();
                              SetClipboardData(CF_DIB, hMem);
                              CloseClipboard();
                              ok = true;
                              // Clipboard owns the memory now; don't free.
                              hMem = nullptr;
                            }
                          }
                          GlobalUnlock(hMem);
                        }
                        if (hMem) GlobalFree(hMem);
                      }
                    }
                  }
                  if (converter) converter->Release();
                }
                if (frame) frame->Release();
              }
              if (decoder) decoder->Release();
            }
            if (factory) factory->Release();
            if (SUCCEEDED(co_hr)) CoUninitialize();
          }

          result->Success(flutter::EncodableValue(ok));
          return;
        }

        result->NotImplemented();
      });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Ensure a frame is pending so the window shows.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }
  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (message == WM_GETDPISCALEDSIZE && restoring_bounds_) {
    auto* size = reinterpret_cast<SIZE*>(lparam);
    size->cx = restoring_bounds_->right - restoring_bounds_->left;
    size->cy = restoring_bounds_->bottom - restoring_bounds_->top;
    return TRUE;
  }
  // Record power changes before a plugin can consume the window message.
  if (message == WM_POWERBROADCAST) {
    if (wparam == PBT_APMSUSPEND) {
      system_sleeping_ = true;
    } else if (wparam == PBT_APMRESUMEAUTOMATIC) {
      system_sleeping_ = false;
      last_system_wake_at_ = std::chrono::duration_cast<std::chrono::milliseconds>(
          std::chrono::system_clock::now().time_since_epoch()).count();
    }
  }
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam, lparam);
    if (result) {
      return *result;
    }
  }

  // Plugins still receive the new DPI, but the runner must not replace the
  // explicitly restored physical bounds with Windows' suggested rectangle.
  if (message == WM_DPICHANGED && restoring_bounds_) return 0;

  switch (message) {
    case WM_POWERBROADCAST:
      return TRUE;
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
