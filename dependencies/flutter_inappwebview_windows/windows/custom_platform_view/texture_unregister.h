#pragma once

#include <flutter/texture_registrar.h>
#include <future>
#include <memory>

namespace flutter_inappwebview_plugin
{
  // Called on the platform thread. Flutter completes removal on its raster
  // thread (or inline if it cannot post), so this does not pump platform work
  // or allow a half-destroyed view to be re-entered. Release STA resources only
  // after the raster thread can no longer invoke the texture's callbacks.
  inline void unregisterTextureAndWait(flutter::TextureRegistrar* registrar, int64_t id)
  {
    auto completion = std::make_shared<std::promise<void>>();
    auto finished = completion->get_future();
    registrar->UnregisterTexture(id, [completion] { completion->set_value(); });
    finished.wait();
  }
}
