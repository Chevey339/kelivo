#include <cassert>
#include <iostream>
#include "../../dependencies/flutter_inappwebview_windows/windows/in_app_webview/workspace_bridge_message.h"

int main() {
  using flutter_inappwebview_plugin::workspaceBridgeAllowed;
  const std::string origin = "kelivo://ws-fixture.kelivo.invalid";
  assert(workspaceBridgeAllowed(origin, "main", "main", 1024));
  assert(!workspaceBridgeAllowed(origin, "child", "main", 1024));
  assert(!workspaceBridgeAllowed(origin, "", "", 1024));
  assert(!workspaceBridgeAllowed("", "main", "main", 1024));
  assert(!workspaceBridgeAllowed(origin, "main", "main", 13 * 1024 * 1024));
  // The helper does not parse/re-encode caller JSON on the WebView UI thread.
  // Dart tests separately verify that caller fields cannot replace native
  // provenance and malformed decoded payloads never reach the app callback.
  std::cout << "Windows workspace bridge provenance checks passed\n";
}
