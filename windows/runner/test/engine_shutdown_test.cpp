// Uses Flutter's real BinaryMessengerImpl with a controlled C engine boundary.
// The queued callback retains exactly the raw handler pointer used on Windows.
#include "../engine_shutdown.h"
#include "binary_messenger_impl.h"
#include "types/plugin_messenger.h"
#include <flutter_texture_registrar.h>

#include <cstdlib>
#include <iostream>
#include <map>
#include <memory>
#include <mutex>
#include <string>

struct FlutterDesktopMessenger {
  bool available = true;
  int references = 1;
  int replies = 0;
  std::mutex mutex;
  std::map<std::string, std::pair<FlutterDesktopMessageCallback, void*>> callbacks;
};

struct _FlutterPlatformMessageResponseHandle {};

void Check(bool value, const char* message) {
  if (!value) {
    std::cerr << message << std::endl;
    std::exit(EXIT_FAILURE);
  }
}

FlutterDesktopMessengerRef FlutterDesktopMessengerAddRef(
    FlutterDesktopMessengerRef messenger) {
  ++messenger->references;
  return messenger;
}
void FlutterDesktopMessengerRelease(FlutterDesktopMessengerRef messenger) {
  --messenger->references;
}
bool FlutterDesktopMessengerIsAvailable(FlutterDesktopMessengerRef messenger) {
  return messenger->available;
}
FlutterDesktopMessengerRef FlutterDesktopMessengerLock(
    FlutterDesktopMessengerRef messenger) {
  messenger->mutex.lock();
  return messenger;
}
void FlutterDesktopMessengerUnlock(FlutterDesktopMessengerRef messenger) {
  messenger->mutex.unlock();
}
void FlutterDesktopMessengerSendResponse(FlutterDesktopMessengerRef messenger,
    const FlutterDesktopMessageResponseHandle*, const uint8_t*, size_t) {
  ++messenger->replies;
}
bool FlutterDesktopMessengerSend(FlutterDesktopMessengerRef, const char*,
    const uint8_t*, size_t) {
  return true;
}
bool FlutterDesktopMessengerSendWithReply(FlutterDesktopMessengerRef, const char*,
    const uint8_t*, size_t, FlutterDesktopBinaryReply, void*) {
  return true;
}
void FlutterDesktopMessengerSetCallback(FlutterDesktopMessengerRef messenger,
    const char* channel, FlutterDesktopMessageCallback callback, void* user_data) {
  Check(messenger->available, "registered a callback after engine destruction");
  if (callback) messenger->callbacks[channel] = {callback, user_data};
  else messenger->callbacks.erase(channel);
}
int64_t FlutterDesktopTextureRegistrarRegisterExternalTexture(
    FlutterDesktopTextureRegistrarRef, const FlutterDesktopTextureInfo*) {
  std::abort();
}
bool FlutterDesktopTextureRegistrarMarkExternalTextureFrameAvailable(
    FlutterDesktopTextureRegistrarRef, int64_t) {
  std::abort();
}
void FlutterDesktopTextureRegistrarUnregisterExternalTexture(
    FlutterDesktopTextureRegistrarRef, int64_t, void (*)(void*), void*) {
  std::abort();
}

void Dispatch(FlutterDesktopMessenger& messenger, const char* channel) {
  const auto callback = messenger.callbacks.at(channel);
  FlutterDesktopMessageResponseHandle response;
  FlutterDesktopMessage message{
      sizeof(FlutterDesktopMessage), channel, nullptr, 0, &response};
  callback.first(&messenger, &message, callback.second);
}

void TestCrossPluginShutdown(bool window_plugin_destroyed_first) {
  FlutterDesktopMessenger core;
  EngineShutdown shutdown;
  auto window_messenger = std::make_unique<flutter::BinaryMessengerImpl>(&core);
  auto browser_messenger = std::make_unique<flutter::BinaryMessengerImpl>(&core);
  auto browser_alive = std::make_shared<std::atomic_bool>(true);
  auto browser = std::make_unique<flutter_inappwebview_plugin::PluginMessenger>(
      browser_messenger.get(), &core, browser_alive);
  auto browser_resource = std::make_unique<int>(42);
  int window_calls = 0;
  int browser_calls = 0;
  int drains = 0;
  int engine_destroys = 0;
  window_messenger->SetMessageHandler("window_manager",
      [&](const uint8_t*, size_t, flutter::BinaryReply) {
        Check(core.available, "window callback ran after engine teardown began");
        ++window_calls;
        // Native message dispatch can re-enter OnDestroy/WM_CLOSE.
        if (shutdown.started()) {
          shutdown.Run([] { Check(false, "nested preparation"); },
              [] { Check(false, "nested engine destruction"); });
        }
      });
  browser->SetMessageHandler("browser",
      [&, resource = browser_resource.get()](const uint8_t*, size_t, flutter::BinaryReply) {
        Check(*resource == 42, "browser callback used a disposed resource");
        ++browser_calls;
      });
  Dispatch(core, "window_manager");
  Dispatch(core, "browser");

  shutdown.Run(
      [&] {
        *browser_alive = false;
        browser_resource.reset();
        ++drains;
        // Model the queued calls serviced by ShutdownQueueAsync's message pump.
        // Destroying registrars first reproduces ForwardToHandler's UAF in ASan.
        Dispatch(core, "window_manager");
        Dispatch(core, "browser");
        Check(window_calls == 2, "queued window call was not drained");
        Check(browser_calls == 1, "late browser callback was not suppressed");
        Check(core.replies == 1, "late browser call was not completed");
        Check(engine_destroys == 0, "engine destroyed during preparation");
      },
      [&] {
        Check(drains == 1, "engine destroyed before dispatcher drain");
        ++engine_destroys;
        core.available = false;
        // DLL/registrar ordering must not affect safety. Neither destructor
        // may pump Flutter work now; all native draining already completed.
        if (window_plugin_destroyed_first) window_messenger.reset();
        browser.reset();
        browser_messenger.reset();
        window_messenger.reset();
        core.callbacks.clear();
      });
  shutdown.Run([] { Check(false, "preparation repeated"); },
      [] { Check(false, "engine destruction repeated"); });
  Check(drains == 1 && engine_destroys == 1, "shutdown was not once-only");
  Check(core.references == 1, "messenger reference leaked");
}

int main() {
  TestCrossPluginShutdown(true);
  TestCrossPluginShutdown(false);
  std::cout << "Cross-plugin shutdown and late callback tests passed.\n";
}
