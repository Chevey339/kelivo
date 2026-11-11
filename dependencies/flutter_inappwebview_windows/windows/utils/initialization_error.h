#pragma once

#include <flutter/method_result.h>
#include <flutter/standard_message_codec.h>
#include <iomanip>
#include <cstdint>
#include <sstream>

#include "log.h"

namespace flutter_inappwebview_plugin
{
  inline std::string hresultCode(HRESULT result)
  {
    std::ostringstream value;
    value << "0x" << std::uppercase << std::hex << std::setfill('0')
      << std::setw(8) << static_cast<uint32_t>(result);
    return value.str();
  }

  inline void reportInitializationError(
    flutter::MethodResult<flutter::EncodableValue>* result,
    HRESULT error, const std::string& stage,
    const std::string& userDataFolder = "")
  {
    const auto code = hresultCode(error);
    const auto message = getHRMessage(error);
    flutter::EncodableMap details = {
      { flutter::EncodableValue("stage"), flutter::EncodableValue(stage) },
      { flutter::EncodableValue("hresult"), flutter::EncodableValue(static_cast<int64_t>(error)) },
      { flutter::EncodableValue("hresultHex"), flutter::EncodableValue(code) }
    };
    if (!userDataFolder.empty()) {
      details.emplace(flutter::EncodableValue("userDataFolder"), flutter::EncodableValue(userDataFolder));
    }
    result->Error(code, stage + " failed (" + code + "): " + message,
      flutter::EncodableValue(details));
  }
}
