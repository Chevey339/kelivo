#ifndef FLUTTER_INAPPWEBVIEW_WORKSPACE_BRIDGE_MESSAGE_H_
#define FLUTTER_INAPPWEBVIEW_WORKSPACE_BRIDGE_MESSAGE_H_

#include <cstddef>
#include <string>

namespace flutter_inappwebview_plugin {
  // Origin/frame inputs come only from CDP metadata. Leave the potentially
  // large JSON body to Dart's bounded worker instead of parsing it on the UI
  // thread merely to attach trusted metadata.
  inline bool workspaceBridgeAllowed(
    const std::string& origin, const std::string& frameId,
    const std::string& pageFrameId, std::size_t argumentBytes)
  {
    return !origin.empty() && !pageFrameId.empty() && frameId == pageFrameId &&
      argumentBytes <= 6 * 2 * 1024 * 1024 + 4096;
  }
}
#endif
