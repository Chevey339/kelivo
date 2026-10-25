#include "screenshot.h"

#include <algorithm>
#include <cmath>
#include <limits>
#include <Shlwapi.h>
#include <wincodec.h>
#include <wil/wrl.h>
#include <winrt/Windows.System.h>
#include "base64.h"

namespace flutter_inappwebview_plugin
{
  namespace
  {
    std::optional<std::string> streamBytes(IStream* stream)
    {
      STATSTG stat = {};
      if (FAILED(stream->Stat(&stat, STATFLAG_NONAME)) || stat.cbSize.HighPart != 0) return std::nullopt;
      std::string bytes(stat.cbSize.LowPart, '\0');
      ULONG read = 0;
      if (FAILED(stream->Seek({}, STREAM_SEEK_SET, nullptr)) ||
        FAILED(stream->Read(bytes.data(), static_cast<ULONG>(bytes.size()), &read)) || read != bytes.size()) return std::nullopt;
      return bytes;
    }

    // All decoding, cropping, scaling, encoding and base64 work runs off the
    // platform thread. Only the final bounded result crosses the Dart channel.
    std::optional<std::string> resizeScreenshot(const std::string& bytes,
      const std::optional<std::shared_ptr<ScreenshotConfiguration>>& configuration, double rasterScale)
    {
      if (!configuration.has_value()) return base64_encode(bytes);
      const auto& config = configuration.value();
      if (!config->rect.has_value() && !config->snapshotWidth.has_value() && config->compressFormat == CompressFormat::png) {
        return base64_encode(bytes);
      }
      wil::com_ptr<IWICImagingFactory> factory;
      if (FAILED(CoCreateInstance(CLSID_WICImagingFactory, nullptr, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&factory)))) return std::nullopt;
      wil::com_ptr<IStream> input;
      input.attach(SHCreateMemStream(reinterpret_cast<const BYTE*>(bytes.data()), static_cast<UINT>(bytes.size())));
      wil::com_ptr<IWICBitmapDecoder> decoder;
      wil::com_ptr<IWICBitmapFrameDecode> frame;
      if (!input || FAILED(factory->CreateDecoderFromStream(input.get(), nullptr, WICDecodeMetadataCacheOnDemand, &decoder)) ||
        FAILED(decoder->GetFrame(0, &frame))) return std::nullopt;
      UINT width = 0, height = 0;
      if (FAILED(frame->GetSize(&width, &height)) || width == 0 || height == 0) return std::nullopt;
      wil::com_ptr<IWICBitmapSource> source = frame;
      if (config->rect.has_value()) {
        const auto& rect = config->rect.value();
        // Rect is relative to the visible viewport, in logical pixels.
        const double left = rect->x * rasterScale, top = rect->y * rasterScale;
        const double right = (rect->x + rect->width) * rasterScale, bottom = (rect->y + rect->height) * rasterScale;
        if (!std::isfinite(left) || !std::isfinite(top) || !std::isfinite(right) || !std::isfinite(bottom) ||
          rect->width <= 0 || rect->height <= 0) return std::nullopt;
        const int x = static_cast<int>(std::clamp(left, 0.0, static_cast<double>(width)));
        const int y = static_cast<int>(std::clamp(top, 0.0, static_cast<double>(height)));
        const int w = static_cast<int>(std::clamp(right, 0.0, static_cast<double>(width))) - x;
        const int h = static_cast<int>(std::clamp(bottom, 0.0, static_cast<double>(height))) - y;
        if (w <= 0 || h <= 0) return std::nullopt;
        WICRect crop = { x, y, w, h };
        wil::com_ptr<IWICBitmapClipper> clipper;
        if (FAILED(factory->CreateBitmapClipper(&clipper)) || FAILED(clipper->Initialize(source.get(), &crop))) return std::nullopt;
        source = clipper;
        width = w;
        height = h;
      }
      if (config->snapshotWidth.has_value()) {
        const double targetWidth = config->snapshotWidth.value();
        const double targetHeight = std::round(height * targetWidth / width);
        if (!std::isfinite(targetWidth) || targetWidth < 1 || targetWidth > (std::numeric_limits<int>::max)() ||
          !std::isfinite(targetHeight) || targetHeight < 1 || targetHeight > (std::numeric_limits<int>::max)()) return std::nullopt;
        width = static_cast<UINT>(targetWidth);
        height = static_cast<UINT>(targetHeight);
        wil::com_ptr<IWICBitmapScaler> scaler;
        if (FAILED(factory->CreateBitmapScaler(&scaler)) ||
          FAILED(scaler->Initialize(source.get(), width, height, WICBitmapInterpolationModeFant))) return std::nullopt;
        source = scaler;
      }
      wil::com_ptr<IStream> output;
      wil::com_ptr<IWICBitmapEncoder> encoder;
      wil::com_ptr<IWICBitmapFrameEncode> encodedFrame;
      wil::com_ptr<IPropertyBag2> properties;
      const bool jpeg = config->compressFormat == CompressFormat::jpeg;
      if (FAILED(CreateStreamOnHGlobal(nullptr, TRUE, &output)) ||
        FAILED(factory->CreateEncoder(jpeg ? GUID_ContainerFormatJpeg : GUID_ContainerFormatPng, nullptr, &encoder)) ||
        FAILED(encoder->Initialize(output.get(), WICBitmapEncoderNoCache)) ||
        FAILED(encoder->CreateNewFrame(&encodedFrame, &properties))) return std::nullopt;
      if (jpeg) {
        PROPBAG2 option = {};
        option.pstrName = const_cast<LPOLESTR>(L"ImageQuality");
        VARIANT value = {};
        value.vt = VT_R4;
        value.fltVal = static_cast<float>(std::clamp<int64_t>(config->quality, 0, 100)) / 100;
        if (FAILED(properties->Write(1, &option, &value))) return std::nullopt;
      }
      WICPixelFormatGUID pixelFormat = jpeg ? GUID_WICPixelFormat24bppBGR : GUID_WICPixelFormat32bppBGRA;
      if (FAILED(encodedFrame->Initialize(properties.get())) || FAILED(encodedFrame->SetSize(width, height)) ||
        FAILED(encodedFrame->SetPixelFormat(&pixelFormat))) return std::nullopt;
      wil::com_ptr<IWICBitmapSource> converted;
      if (FAILED(WICConvertBitmapSource(pixelFormat, source.get(), &converted)) ||
        FAILED(encodedFrame->WriteSource(converted.get(), nullptr)) || FAILED(encodedFrame->Commit()) || FAILED(encoder->Commit())) return std::nullopt;
      const auto result = streamBytes(output.get());
      return result ? std::optional<std::string>(base64_encode(result.value())) : std::nullopt;
    }

    struct ScreenshotWork {
      std::string bytes;
      std::optional<std::shared_ptr<ScreenshotConfiguration>> configuration;
      double rasterScale;
      winrt::Windows::System::DispatcherQueue dispatcher;
      std::function<void(const std::optional<std::string>)> completion;
    };
  }

  void captureScreenshot(wil::com_ptr<ICoreWebView2> view,
    std::optional<std::shared_ptr<ScreenshotConfiguration>> configuration, double rasterScale,
    std::function<void(const std::optional<std::string>)> completion)
  {
    // The Windows system encoder supports PNG/JPEG. Never return mislabeled
    // PNG data for WEBP (the app only requests PNG screenshots/JPEG previews).
    if (configuration.has_value() && configuration.value()->compressFormat == CompressFormat::webp) {
      completion(std::nullopt);
      return;
    }
    auto dispatcher = winrt::Windows::System::DispatcherQueue::GetForCurrentThread();
    wil::com_ptr<IStream> stream;
    if (!dispatcher || FAILED(CreateStreamOnHGlobal(nullptr, TRUE, &stream))) {
      completion(std::nullopt);
      return;
    }
    const auto hr = view->CapturePreview(COREWEBVIEW2_CAPTURE_PREVIEW_IMAGE_FORMAT_PNG, stream.get(),
      Microsoft::WRL::Callback<ICoreWebView2CapturePreviewCompletedHandler>(
        [view, stream, configuration, rasterScale, dispatcher, completion](HRESULT error)
        {
          auto bytes = SUCCEEDED(error) ? streamBytes(stream.get()) : std::nullopt;
          if (!bytes) {
            completion(std::nullopt);
            return S_OK;
          }
          auto work = std::make_unique<ScreenshotWork>(ScreenshotWork{ std::move(bytes.value()), configuration, rasterScale, dispatcher, completion });
          if (TrySubmitThreadpoolCallback([](PTP_CALLBACK_INSTANCE, void* context)
            {
              std::unique_ptr<ScreenshotWork> work(static_cast<ScreenshotWork*>(context));
              const auto init = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
              auto result = SUCCEEDED(init) ? resizeScreenshot(work->bytes, work->configuration, work->rasterScale) : std::nullopt;
              if (SUCCEEDED(init)) CoUninitialize();
              work->dispatcher.TryEnqueue([completion = std::move(work->completion), result = std::move(result)] { completion(result); });
            }, work.get(), nullptr)) {
            work.release();
          }
          else {
            completion(std::nullopt);
          }
          return S_OK;
        }).Get());
    if (FAILED(hr)) completion(std::nullopt);
  }
}
