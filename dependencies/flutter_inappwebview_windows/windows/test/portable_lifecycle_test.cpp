// Uses Flutter's real C++ interfaces with a controlled engine boundary. This
// executable also runs on non-Windows hosts, without loading WebView2/WinRT.
// The test defines its engine boundary locally, rather than importing a DLL.
#include <flutter_export.h>
#undef FLUTTER_EXPORT
#define FLUTTER_EXPORT
#include <atomic>
#include <chrono>
#include <cstdlib>
#include <iostream>
#include <mutex>
#include <thread>

#include "types/plugin_messenger.h"
#include "custom_platform_view/texture_unregister.h"

struct FlutterDesktopMessenger {
  std::mutex mutex;
  bool available = true;
  std::atomic_int references{1};
};

FlutterDesktopMessengerRef FlutterDesktopMessengerAddRef(FlutterDesktopMessengerRef messenger) {
  ++messenger->references;
  return messenger;
}
void FlutterDesktopMessengerRelease(FlutterDesktopMessengerRef messenger) { --messenger->references; }
bool FlutterDesktopMessengerIsAvailable(FlutterDesktopMessengerRef messenger) { return messenger->available; }
FlutterDesktopMessengerRef FlutterDesktopMessengerLock(FlutterDesktopMessengerRef messenger) {
  messenger->mutex.lock();
  return messenger;
}
void FlutterDesktopMessengerUnlock(FlutterDesktopMessengerRef messenger) { messenger->mutex.unlock(); }

void check(bool value, const char* message) {
  if (!value) {
    std::cerr << message << std::endl;
    std::exit(EXIT_FAILURE);
  }
}

class Messenger : public flutter::BinaryMessenger {
public:
  mutable int sends = 0;
  int registrations = 0;
  flutter::BinaryMessageHandler handler;
  mutable flutter::BinaryReply response;
  void Send(const std::string&, const uint8_t*, size_t, flutter::BinaryReply reply) const override {
    ++sends;
    response = std::move(reply);
  }
  void SetMessageHandler(const std::string&, flutter::BinaryMessageHandler callback) override {
    ++registrations;
    handler = std::move(callback);
  }
};

void testMessengerTeardown() {
  FlutterDesktopMessenger engine;
  Messenger delegate;
  auto alive = std::make_shared<std::atomic_bool>(true);
  int calls = 0;
  int replies = 0;
  {
    flutter_inappwebview_plugin::PluginMessenger messenger(&delegate, &engine, alive);
    messenger.SetMessageHandler("view", [&](const uint8_t*, size_t, flutter::BinaryReply reply) {
      ++calls;
      // Both re-entrant Send and Flutter's locking reply must be allowed.
      messenger.Send("nested", nullptr, 0);
      reply(nullptr, 0);
    });
    auto reply = [&engine, &replies](const uint8_t*, size_t) {
      std::lock_guard<std::mutex> lock(engine.mutex);
      if (engine.available) ++replies;
    };
    delegate.handler(nullptr, 0, reply);
    check(calls == 1 && replies == 1 && delegate.sends == 1, "live handler/reply failed");
    int responses = 0;
    messenger.Send("request", nullptr, 0, [&](const uint8_t*, size_t) { ++responses; });
    // Engine destruction precedes plugin destruction. The owner token alone
    // is not sufficient during this interval.
    engine.available = false;
    messenger.SetMessageHandler("view", nullptr);
    messenger.Send("closed", nullptr, 0);
    delegate.handler(nullptr, 0, reply);
    delegate.response(nullptr, 0);
    check(delegate.registrations == 1 && delegate.sends == 2, "called an unavailable engine");
    check(calls == 1 && responses == 0, "called a handler after engine shutdown");

    engine.available = true;
    *alive = false;
    delegate.handler(nullptr, 0, reply);
    delegate.response(nullptr, 0);
    messenger.SetMessageHandler("view", nullptr);
    check(calls == 1 && responses == 0 && delegate.registrations == 1, "called a disposed plugin");
  }
  // The engine can retain a queued callback beyond the plugin/wrapper.
  delegate.handler(nullptr, 0, [](const uint8_t*, size_t) {});
  delegate.response(nullptr, 0);
  delegate.handler = nullptr;
  delegate.response = nullptr;
  check(engine.references == 1, "leaked a native messenger reference");

  *alive = true;
  flutter_inappwebview_plugin::PluginMessenger messenger(&delegate, &engine, alive);
  messenger.SetMessageHandler("view", [](const uint8_t*, size_t, flutter::BinaryReply) {});
  messenger.SetMessageHandler("view", nullptr);
  check(!delegate.handler && delegate.registrations == 3, "live channel was not unregistered");
}

class Textures : public flutter::TextureRegistrar {
public:
  std::promise<void> called;
  std::promise<void> allowCompletion;
  std::thread raster;
  bool inlineCompletion = false;
  int64_t RegisterTexture(flutter::TextureVariant*) override { return 1; }
  bool MarkTextureFrameAvailable(int64_t) override { return true; }
  bool UnregisterTexture(int64_t) override { std::abort(); }
  void UnregisterTexture(int64_t, std::function<void()> callback) override {
    if (inlineCompletion) { callback(); return; }
    raster = std::thread([this, callback = std::move(callback)] {
      allowCompletion.get_future().wait();
      callback();
    });
    called.set_value();
  }
};

void testTextureFence() {
  Textures registrar;
  std::promise<void> released;
  auto finished = released.get_future();
  std::thread platform([&] {
    flutter_inappwebview_plugin::unregisterTextureAndWait(&registrar, 1);
    released.set_value();
  });
  registrar.called.get_future().wait();
  check(finished.wait_for(std::chrono::milliseconds(20)) == std::future_status::timeout,
    "released texture backing before raster removal completed");
  registrar.allowCompletion.set_value();
  check(finished.wait_for(std::chrono::seconds(2)) == std::future_status::ready,
    "texture removal did not finish without pumping platform messages");
  platform.join();
  registrar.raster.join();
  registrar.inlineCompletion = true;
  flutter_inappwebview_plugin::unregisterTextureAndWait(&registrar, 2);
}

int main() {
  testMessengerTeardown();
  testTextureFence();
  std::cout << "Messenger teardown and async texture removal tests passed." << std::endl;
}
