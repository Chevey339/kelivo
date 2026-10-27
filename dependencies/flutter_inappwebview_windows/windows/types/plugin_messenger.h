#pragma once

#include <flutter/binary_messenger.h>
#include <flutter_messenger.h>
#include <atomic>
#include <memory>

namespace flutter_inappwebview_plugin
{
  // Flutter invalidates its messenger before destroying registered plugins.
  // Channels must therefore check the engine as well as their plugin owner.
  class PluginMessenger : public flutter::BinaryMessenger {
  public:
    PluginMessenger(flutter::BinaryMessenger* delegate,
      FlutterDesktopMessengerRef messenger, std::shared_ptr<std::atomic_bool> alive)
      : delegate_(delegate), messenger_(FlutterDesktopMessengerAddRef(messenger),
          FlutterDesktopMessengerRelease), alive_(std::move(alive)) {}

    void Send(const std::string& channel, const uint8_t* message,
      size_t size, flutter::BinaryReply reply = nullptr) const override
    {
      auto lock = lockMessenger(messenger_.get());
      if (!*alive_ || !FlutterDesktopMessengerIsAvailable(messenger_.get())) return;
      if (reply) {
        reply = [reply = std::move(reply), messenger = messenger_, alive = alive_](
          const uint8_t* data, size_t size) {
          if (available(messenger.get(), alive)) reply(data, size);
        };
      }
      delegate_->Send(channel, message, size, std::move(reply));
    }

    void SetMessageHandler(const std::string& channel,
      flutter::BinaryMessageHandler handler) override
    {
      auto lock = lockMessenger(messenger_.get());
      if (!*alive_ || !FlutterDesktopMessengerIsAvailable(messenger_.get())) return;
      if (handler) {
        handler = [handler = std::move(handler), messenger = messenger_, alive = alive_](
          const uint8_t* data, size_t size, flutter::BinaryReply reply) {
          // Do not hold the messenger lock across a handler/reply: either can
          // re-enter the messenger. Platform callbacks run on the owning STA.
          if (available(messenger.get(), alive)) {
            auto callback = handler;
            callback(data, size, std::move(reply));
          }
          else if (reply) reply(nullptr, 0);
        };
      }
      delegate_->SetMessageHandler(channel, std::move(handler));
    }

  private:
    using Lock = std::unique_ptr<FlutterDesktopMessenger, decltype(&FlutterDesktopMessengerUnlock)>;
    static Lock lockMessenger(FlutterDesktopMessengerRef messenger)
    {
      return Lock(FlutterDesktopMessengerLock(messenger), FlutterDesktopMessengerUnlock);
    }
    static bool available(FlutterDesktopMessengerRef messenger,
      const std::shared_ptr<std::atomic_bool>& alive)
    {
      auto lock = lockMessenger(messenger);
      return *alive && FlutterDesktopMessengerIsAvailable(messenger);
    }
    flutter::BinaryMessenger* delegate_;
    std::shared_ptr<FlutterDesktopMessenger> messenger_;
    std::shared_ptr<std::atomic_bool> alive_;
  };
}
